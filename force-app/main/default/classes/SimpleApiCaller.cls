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
        // Removed: List<Header> headers (use headersJson instead)
        // New: JSON string for headers
        @InvocableVariable(label='Headers JSON' description='JSON string of headers, e.g. {"Authorization":"Bearer xyz","Accept":"application/json"}')
        public String headersJson;
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
        Integer defaultTimeoutMs = 10000; // fallback default
        Integer initialBackoffMs = 1000; // 1 second

        // Read timeout from custom setting apiSettings__c.TimeoutMilliseconds__c
        try {
            apiSettings__c config = apiSettings__c.getOrgDefaults();
            if (config != null && config.TimeoutMilliseconds__c != null) {
                defaultTimeoutMs = Integer.valueOf(config.TimeoutMilliseconds__c);
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
            // Set custom headers from JSON string if provided
            if (!String.isBlank(req.headersJson)) {
                try {
                    Map<String, Object> headerMap = (Map<String, Object>)JSON.deserializeUntyped(req.headersJson);
                    for (String key : headerMap.keySet()) {
                        Object val = headerMap.get(key);
                        httpReq.setHeader(key, val != null ? String.valueOf(val) : '');
                    }
                } catch (Exception e) {
                    // If JSON is invalid, ignore and proceed
                }
            }
            httpReq.setTimeout(defaultTimeoutMs);

            // Determine retry logic based only on invocable input
            Boolean doRetry = req.enableRetries != null ? req.enableRetries : false;
            Integer effectiveMaxRetries = 0;
            if (doRetry && req.retryCount != null) {
                effectiveMaxRetries = req.retryCount;
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
                            success = true;
                        }
                    } else {
                        resp.apiStatus = 'Error';
                        success = true;
                    }
                } catch (Exception ex) {
                    resp.apiStatus = 'Exception';
                    resp.apiStatusCode = ex.getTypeName();
                    resp.apiResponse = ex.getMessage();
                    success = true;
                }
            }
            responses.add(resp);
        }
        return responses;
    }
}