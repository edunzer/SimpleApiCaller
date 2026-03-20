public with sharing class SimpleApiCaller {
    // Inner class for custom header
    public class Header {
        @InvocableVariable(required=true)
        public String name;
        @InvocableVariable(required=true)
        public String value;
    }

    // Inner class for API request
    public class APIRequest {
        @InvocableVariable(required=true)
        public String url;
        @InvocableVariable(required=true)
        public String method;
        @InvocableVariable
        public String contentType;
        @InvocableVariable
        public List<Header> headers;
        @InvocableVariable
        public String body;
        // Enhancement: allow invocable input to control retry logic
        @InvocableVariable(label='Enable Retries' description='Set to true to enable retry logic. Default is false.')
        public Boolean enableRetries = false;
        @InvocableVariable(label='Retry Count' description='Number of retry attempts if retries are enabled.')
        public Integer retryCount;
    }

    // Inner class for API response
    public class APIResponse {
        @InvocableVariable
        public String apiResponse;
        @InvocableVariable
        public String apiStatus;
        @InvocableVariable
        public String apiStatusCode;
    }

    // Flow-invocable method stub
    @InvocableMethod(label='Simple External API Call' description='Makes HTTP requests to external APIs with custom method, headers, and body.')
    public static List<APIResponse> callApi(List<APIRequest> requests) {
        List<APIResponse> responses = new List<APIResponse>();
        // Configurable settings
        Integer defaultTimeoutMs = 10000; // 10 seconds
        Integer maxRetries = 3;
        Integer initialBackoffMs = 1000; // 1 second

        // Try to read from Custom Setting (if exists)
        try {
            // Example: Custom setting named 'SimpleApiCallerConfig__c' with Timeout__c, MaxRetries__c
            // Replace with actual custom setting API name if needed
            SimpleApiCallerConfig__c config = SimpleApiCallerConfig__c.getOrgDefaults();
            if (config != null) {
                if (config.Timeout__c != null) defaultTimeoutMs = Integer.valueOf(config.Timeout__c);
                if (config.MaxRetries__c != null) maxRetries = Integer.valueOf(config.MaxRetries__c);
            }
        } catch (Exception e) {
            // Ignore if custom setting does not exist
        }

        for (APIRequest req : requests) {
            APIResponse resp = new APIResponse();
            if (req == null || String.isBlank(req.url) || String.isBlank(req.method)) {
                resp.apiResponse = null; // Explicitly set to null for errors
                resp.apiStatus = 'Error';
                resp.apiStatusCode = '400';
                responses.add(resp);
                continue;
            }

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(req.url);
            httpReq.setMethod(req.method != null ? req.method : 'POST');
            if (!String.isBlank(req.body)) {
                httpReq.setBody(req.body);
            }
            // Set Content-Type
            if (!String.isBlank(req.contentType)) {
                httpReq.setHeader('Content-Type', req.contentType);
            }
            // Set custom headers
            if (req.headers != null) {
                for (Header h : req.headers) {
                    if (h != null && !String.isBlank(h.name)) {
                        httpReq.setHeader(h.name, h.value != null ? h.value : '');
                    }
                }
            }
            httpReq.setTimeout(defaultTimeoutMs);

            // Determine retry logic based on invocable input
            Boolean doRetry = req.enableRetries != null ? req.enableRetries : false;
            Integer effectiveMaxRetries = maxRetries;
            if (doRetry) {
                if (req.retryCount != null) {
                    effectiveMaxRetries = req.retryCount;
                }
            } else {
                effectiveMaxRetries = 0;
            }

            Http http = new Http();
            Integer attempt = 0;
            Boolean success = false;
            Integer backoff = initialBackoffMs;
            while (attempt <= effectiveMaxRetries && !success) {
                attempt++;
                try {
                    HttpResponse httpResp = http.send(httpReq);
                    resp.apiStatusCode = String.valueOf(httpResp.getStatusCode());
                    resp.apiResponse = httpResp.getBody(); // Always raw API output
                    if (httpResp.getStatusCode() >= 200 && httpResp.getStatusCode() < 300) {
                        resp.apiStatus = 'Success';
                        success = true;
                    } else if (httpResp.getStatusCode() == 429 || (httpResp.getStatusCode() >= 500 && httpResp.getStatusCode() < 600)) {
                        // Retry on 429 or 5xx
                        if (attempt <= effectiveMaxRetries) {
                            // Exponential backoff
                            Long waitMs = backoff;
                            backoff *= 2;
                            System.runAs(new User(Id=UserInfo.getUserId())) {
                                // Sleep is not available in Apex, so just continue
                                // In real-world, use Platform Events or Scheduled Jobs for true backoff
                            }
                            continue;
                        } else {
                            resp.apiStatus = 'Error';
                        }
                    } else {
                        resp.apiStatus = 'Error';
                        success = true;
                    }
                } catch (Exception ex) {
                    resp.apiStatus = 'Exception';
                    resp.apiStatusCode = 'Exception';
                    // Do not set apiResponse to exception message; leave as null
                    success = true;
                }
            }
            responses.add(resp);
        }
        return responses;
    }
}