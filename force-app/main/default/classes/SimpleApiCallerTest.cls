@IsTest
public with sharing class SimpleApiCallerTest {

    // Mock for HTTP callouts
    class MockHttpResponseGenerator implements HttpCalloutMock {
        public Integer statusCode;
        public String responseBody;
        public MockHttpResponseGenerator(Integer code, String body) {
            statusCode = code;
            responseBody = body;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            res.setStatusCode(statusCode);
            return res;
        }
    }

    @IsTest static void testSuccess200() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"result":"ok"}'));
        SimpleApiCaller.APIRequest req = new SimpleApiCaller.APIRequest();
        req.url = 'https://api.example.com/resource';
        req.method = 'POST';
        req.contentType = 'application/json';
        req.body = '{"foo":"bar"}';
        List<SimpleApiCaller.Header> headers = new List<SimpleApiCaller.Header>();
        SimpleApiCaller.Header h1 = new SimpleApiCaller.Header();
        h1.name = 'x-api-client-token';
        h1.value = 'abc123';
        headers.add(h1);
        SimpleApiCaller.Header h2 = new SimpleApiCaller.Header();
        h2.name = 'x-functions-key';
        h2.value = 'xyz456';
        headers.add(h2);
        req.headers = headers;
        List<SimpleApiCaller.APIResponse> resp = SimpleApiCaller.callApi(new List<SimpleApiCaller.APIRequest>{req});
        System.assertEquals(1, resp.size());
        System.assertEquals('Success', resp[0].apiStatus);
        System.assertEquals('200', resp[0].apiStatusCode);
        System.assertEquals('{"result":"ok"}', resp[0].apiResponse);
    }

    @IsTest static void testError400() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(400, '{"error":"bad request"}'));
        SimpleApiCaller.APIRequest req = new SimpleApiCaller.APIRequest();
        req.url = 'https://api.example.com/resource';
        req.method = 'POST';
        List<SimpleApiCaller.APIResponse> resp = SimpleApiCaller.callApi(new List<SimpleApiCaller.APIRequest>{req});
        System.assertEquals('Error', resp[0].apiStatus);
        System.assertEquals('400', resp[0].apiStatusCode);
    }

    @IsTest static void testRetryLogic() {
        // First two responses are 500, third is 200
        List<Integer> codes = new List<Integer>{500, 500, 200};
        List<String> bodies = new List<String>{'fail1', 'fail2', 'ok'};
        Test.setMock(HttpCalloutMock.class, new MockRetryHttpResponseGenerator(codes, bodies));
        SimpleApiCaller.APIRequest req = new SimpleApiCaller.APIRequest();
        req.url = 'https://api.example.com/resource';
        req.method = 'GET';
        req.enableRetries = true;
        req.retryCount = 2;
        List<SimpleApiCaller.APIResponse> resp = SimpleApiCaller.callApi(new List<SimpleApiCaller.APIRequest>{req});
        System.assertEquals('Success', resp[0].apiStatus);
        System.assertEquals('200', resp[0].apiStatusCode);
        System.assertEquals('ok', resp[0].apiResponse);

    }

    // Helper mock for retry test
    class MockRetryHttpResponseGenerator implements HttpCalloutMock {
        private List<Integer> codes;
        private List<String> bodies;
        private Integer callCount = 0;
        public MockRetryHttpResponseGenerator(List<Integer> codes, List<String> bodies) {
            this.codes = codes;
            this.bodies = bodies;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(bodies[callCount]);
            res.setStatusCode(codes[callCount]);
            callCount++;
            return res;
        }
    }

    @IsTest static void testInvalidInput() {
        SimpleApiCaller.APIRequest req = new SimpleApiCaller.APIRequest();
        // Missing url and method
        List<SimpleApiCaller.APIResponse> resp = SimpleApiCaller.callApi(new List<SimpleApiCaller.APIRequest>{req});
        System.assertEquals('Error', resp[0].apiStatus);
        System.assertEquals('400', resp[0].apiStatusCode);
        System.assertEquals(null, resp[0].apiResponse);
    }

    @IsTest static void testBulkRequests() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'ok-bulk'));
        List<SimpleApiCaller.APIRequest> reqs = new List<SimpleApiCaller.APIRequest>();
        for (Integer i = 0; i < 3; i++) {
            SimpleApiCaller.APIRequest req = new SimpleApiCaller.APIRequest();
            req.url = 'https://api.example.com/resource/' + i;
            req.method = 'GET';
            reqs.add(req);
        }
        List<SimpleApiCaller.APIResponse> resp = SimpleApiCaller.callApi(reqs);
        System.assertEquals(3, resp.size());
        for (SimpleApiCaller.APIResponse r : resp) {
            System.assertEquals('Success', r.apiStatus);
            System.assertEquals('200', r.apiStatusCode);
            System.assertEquals('ok-bulk', r.apiResponse);
        }
    }
}