## SimpleApiCaller Salesforce Project

This project provides a generic, flow-invocable Apex class for making HTTP requests to external APIs from Salesforce, along with comprehensive unit tests.

### Apex Classes

#### 1. SimpleApiCaller.cls
**Purpose:**
Provides a flow-invocable method to make HTTP requests (GET, POST, etc.) to external APIs with custom headers, body, and retry logic. Designed for use in Salesforce Flows or programmatically.

**Key Features:**
- Supports custom HTTP methods, headers, and body
- Handles configurable timeouts and retry logic (with exponential backoff)
- Reads optional configuration from a custom setting (`SimpleApiCallerConfig__c`)
- Returns structured responses with status, code, and body

**Main Components:**
- `Header` inner class: Represents a custom HTTP header (name, value)
- `APIRequest` inner class: Represents an API request (url, method, contentType, headers, body)
- `APIResponse` inner class: Represents an API response (apiResponse, apiStatus, apiStatusCode)
- `callApi(List<APIRequest>)`: Flow-invocable method to send requests and return responses

**Example Usage in Flow:**
1. Add an Apex Action to your Flow and select `Simple External API Call`.
2. Provide the required fields: `url`, `method`, and any optional headers/body.
3. The response will include `apiStatus`, `apiStatusCode`, and `apiResponse`.

**Example Usage in Apex:**
```apex
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
System.debug(resp[0].apiStatus);
System.debug(resp[0].apiStatusCode);
System.debug(resp[0].apiResponse);
```

#### 2. SimpleApiCallerTest.cls
**Purpose:**
Contains unit tests for `SimpleApiCaller`, including:
- Successful API call (200 response)
- Error handling (400 response)
- Retry logic (multiple 500s, then 200)
- Invalid input (missing required fields)
- Bulk requests (multiple API calls in one invocation)

**Test Coverage:**
All major code paths are tested, including exception handling and retry logic.

**How to Run Tests:**
Run all tests in Salesforce Setup > Apex Test Execution, or use the Salesforce CLI:
```
sfdx force:apex:test:run -c -r human -w 10
```

---

**Metadata**
- API Version: 66.0
- Status: Active

---
For more details, see the source code in `force-app/main/default/classes/`.
