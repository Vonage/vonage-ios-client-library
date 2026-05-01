# Vonage iOS Client Library – AI Agent Guide

## Overview

This library enables iOS apps to interact with Vonage Network APIs that require redirection and cellular connection forcing, focusing on cellular network requests for number verification and silent authentication. It is compatible with iOS 13+ and supports both Swift Package Manager and CocoaPods for installation.

---

## Installation

### Swift Package Manager
```swift
.package(url: "https://github.com/Vonage/vonage-ios-client-library.git")
```

### CocoaPods
```ruby
pod 'VonageClientLibrary'
```

---

## Main Components

### 1. VGCellularRequestClient
- **Purpose:** Main entry point for making cellular GET requests.
- **Usage:**
  ```swift
  import VonageClientLibrary
  let client = VGCellularRequestClient()
  let params = VGCellularRequestParameters(
      url: "http://www.vonage.com",
      headers: ["x-my-header": "My Value"],
      queryParameters: ["query-param": "value"],
      maxRedirectCount: 10
  )
  let response = try await client.startCellularGetRequest(params: params, debug: true)
  ```
- **Parameters:**
  - `url`: Target URL
  - `headers`: HTTP headers
  - `queryParameters`: URL query params
  - `maxRedirectCount`: Optional, default 10
  - `timeout`: Optional, default 5.0 seconds
  - `debug`: Optional, default false

### 2. VGCellularRequestParameters
- **Purpose:** Encapsulates request configuration.
- **Fields:** url, headers, queryParameters, maxRedirectCount, timeout

### 3. CellularClient (protocol) & VGCellularClient (implementation)
- **Purpose:** Handles the actual network request logic, including cellular connectivity enforcement and redirect handling.

### 4. CellularConnectionManager
- **Purpose:** Manages low-level network connections, enforces cellular-only paths, handles redirects, errors, and debug tracing.

### 5. TraceCollector & DebugInfo
- **Purpose:** Collects trace/debug info for requests, including device info and URL traces.

---

## Error Handling
- Errors are returned as dictionaries with `error`, `error_description`, and optional `debug` info.
- Common error codes:
  - `sdk_no_data_connectivity`
  - `sdk_connection_error`
  - `sdk_redirect_error`
  - `sdk_error`

---

## Migrating from Previous SDKs
- Replace imports of `VonageClientSDKNumberVerification` or `VonageClientSDKSilentAuth` with `VonageClientLibrary`.
- Replace client instantiations with `VGCellularRequestClient()`.
- Use `VGCellularRequestParameters` for request configuration.

---

## Testing
- Tests are located in `Tests/VonageClientLibraryTests/`.
- Includes tests for URL generation and error handling using a `MockCellularClient`.

---

## Project Structure
- `Sources/VonageClientLibrary/` – Main library code
- `Sources/VonageClientLibrary/CellularClient/` – Core networking logic
- `Tests/VonageClientLibraryTests/` – Unit tests

---

## Example Response
**Success:**
```json
{
  "http_status": "200",
  "response_body": { ... },
  "debug": {
    "device_info": "iOS/17.0",
    "url_trace": "..."
  }
}
```
**Error:**
```json
{
  "error": "sdk_no_data_connectivity",
  "error_description": "No cellular data connectivity available.",
  "debug": { ... }
}
```

---

## Additional Notes for AI Agents
- All network requests are forced over cellular (not WiFi) when possible.
- Debugging and trace collection can be enabled via the `debug` parameter.
- The library is written in Swift and uses Apple's Network framework for low-level connectivity.
- The codebase is modular, with clear separation between request configuration, network logic, and trace/debug utilities.
- Error handling is robust and returns structured dictionaries for easy parsing.
- Tests use a mock client for isolation and coverage of edge cases.
- For migration, update imports and client instantiations as described above.
- See the README and inline code documentation for further details on usage and extension.
- This library uses Semantic Versioning. Make sure all changes are regulated to MINOR or PATCH changes - if a change would introduce a MAJOR version bump, discuss with the user first.

---

## References
- [Vonage Number Verification](https://developer.vonage.com/en/number-verification/overview)
- [Vonage Verify Silent Authentication](https://developer.vonage.com/en/verify/guides/silent-authentication)
- [GitHub Repository](https://github.com/Vonage/vonage-ios-client-library)

---

*This file is intended for use by AI agents (e.g., GitHub Copilot, future LLMs) to understand, maintain, and extend the Vonage iOS Client Library codebase efficiently.*
