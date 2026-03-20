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
        req.headers = new List<SimpleApiCaller.Header>{
            new SimpleApiCaller.Header(name='x-api-client-token', value='abc123'),
            new SimpleApiCaller.Header(name='x-functions-key', value='xyz456')
        };
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
        Test.setMock(HttpCalloutMock.class, new HttpCalloutMock() {
            Integer callCount = 0;
            public HTTPResponse respond(HTTPRequest req) {
                HttpResponse res = new HttpResponse();
                res.setHeader('Content-Type', 'application/json');
                res.setBody(bodies[callCount]);
                res.setStatusCode(codes[callCount]);
                callCount++;
                return res;
            }
        });
        SimpleApiCaller.APIRequest req = new SimpleApiCaller.APIRequest();
        req.url = 'https://api.example.com/resource';
        req.method = 'GET';
        List<SimpleApiCaller.APIResponse> resp = SimpleApiCaller.callApi(new List<SimpleApiCaller.APIRequest>{req});
        System.assertEquals('Success', resp[0].apiStatus);
        System.assertEquals('200', resp[0].apiStatusCode);
        System.assertEquals('ok', resp[0].apiResponse);
    }

    @IsTest static void testInvalidInput() {
        SimpleApiCaller.APIRequest req = new SimpleApiCaller.APIRequest();
        // Missing url and method
        List<SimpleApiCaller.APIResponse> resp = SimpleApiCaller.callApi(new List<SimpleApiCaller.APIRequest>{req});
        System.assertEquals('Error', resp[0].apiStatus);
        System.assertEquals('400', resp[0].apiStatusCode);
        System.assert(resp[0].apiResponse.contains('Missing required fields'));
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