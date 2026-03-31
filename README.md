## SimpleApiCaller Salesforce Project

This project provides a generic, flow-invocable Apex class for making HTTP requests to external APIs from Salesforce, along with comprehensive unit tests.

### Apex Classes

#### 1. SimpleApiCaller.cls
**Purpose:**
Provides a flow-invocable method to make HTTP requests (GET, POST, etc.) to external APIs with custom headers, body, and retry logic. Designed for use in Salesforce Flows or programmatically.

**Key Features:**
- Supports custom HTTP methods, headers, and body
- Handles configurable timeouts (via custom setting) and retry logic (via invocable input only, with exponential backoff)
- Timeout is read from the custom setting object `apiSettings__c` (field: `TimeoutMilliseconds__c`). Retry logic is controlled only by the invocable method input variables (`enableRetries`, `retryCount`).
- Returns structured responses:
	- apiResponse contains the raw HTTP response body, or if an exception occurs, the exception message.
	- On exception, apiStatus is "Exception", apiStatusCode is the exception type (e.g., System.CalloutException), and apiResponse contains the exception message.
	- If the request is invalid (missing url or method), apiResponse will be null and error details will be in apiStatus and apiStatusCode.


**Main Components:**
- `APIRequest` inner class: Represents an API request (url, method, contentType, headersJson, body, enableRetries, retryCount)
- `APIResponse` inner class: Represents an API response (apiResponse: raw HTTP response body or null, apiStatus: status string, apiStatusCode: HTTP status code or error code)
- `callApi(List<APIRequest>)`: Flow-invocable method to send requests and return responses

**Example Usage in Flow:**
1. Add an Apex Action to your Flow and select `Simple External API Call`.
2. Provide the required fields: `url`, `method`, and any optional headers/body.
3. The response will include `apiStatus`, `apiStatusCode`, and `apiResponse`.
	- If the request is invalid (missing url or method), `apiResponse` will be null. If an exception occurs, `apiResponse` will contain the exception message. In both cases, check `apiStatus` and `apiStatusCode` for error details.

**Example Usage in Apex:**
```apex
SimpleApiCaller.APIRequest req = new SimpleApiCaller.APIRequest();
req.url = 'https://api.example.com/resource';
req.method = 'POST';
req.contentType = 'application/json';
req.body = '{"foo":"bar"}';
// Set headers as a JSON string
req.headersJson = '{"x-api-client-token":"abc123","x-functions-key":"xyz456"}';
// Optionally enable retries
req.enableRetries = true;
req.retryCount = 2;
List<SimpleApiCaller.APIResponse> resp = SimpleApiCaller.callApi(new List<SimpleApiCaller.APIRequest>{req});
System.debug(resp[0].apiStatus);
System.debug(resp[0].apiStatusCode);
System.debug(resp[0].apiResponse);
// If the request is invalid (missing url or method), apiResponse will be null. If an exception occurs, apiResponse will contain the exception message. In both cases, check apiStatus and apiStatusCode for error details.
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
All major code paths are tested, including:
- Successful API call (200 response)
- Error handling (400 response)
- Retry logic (multiple 500s, then 200)
- Invalid input (missing required fields; expects apiResponse to be null)
- Bulk requests (multiple API calls in one invocation)

---

**Configuration Details:**

- **Timeout:** Controlled by the custom setting object `apiSettings__c` (field: `TimeoutMilliseconds__c`). If not set, defaults to 10,000 ms (10 seconds).
- **Retry Logic:** Controlled only by the invocable method input variables:
	- `enableRetries` (Boolean): Set to true to enable retry logic.
	- `retryCount` (Integer): Number of retry attempts if retries are enabled.
	- No retry configuration is read from any custom setting.


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


**Error Handling:**
- If the request is invalid (missing url or method), `apiResponse` will be null. Error details will be in `apiStatus` and `apiStatusCode`.
- If an exception occurs, `apiStatus` will be "Exception", `apiStatusCode` will be the exception type (e.g., System.CalloutException), and `apiResponse` will contain the exception message.

For more details, see the source code in `force-app/main/default/classes/`.
