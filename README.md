# VonageClientLibrary

A library to support using the Vonage APIs on iOS. Features:

* Force a cellular network request for use with [Vonage Number Verification](https://developer.vonage.com/en/number-verification/overview) and [Vonage Verify Silent Authentication](https://developer.vonage.com/en/verify/guides/silent-authentication) 

## Installation

### Swift Package Manager 

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/Vonage/vonage-ios-client-library.git")
    ]
)
```

### Cocoapods

```ruby
pod 'VonageClientLibrary'
```

## Compatibility

iOS 13+

## Usage

### Force a Cellular Network Request

```swift
import VonageClientLibrary

let client = VGCellularRequestClient()
let params = VGCellularRequestParameters(url: "http://www.vonage.com",
                                        headers: ["x-my-header": "My Value"],
                                        queryParameters: ["query-param" : "value"],
                                        maxRedirectCount: 10)
        
let response = try await client.startCellularGetRequest(params: params, debug: true)
```

* `maxRedirectCount` in `VGCellularRequestParameters` is an optional and defaults to 10.
* `debug` parameter for `startCellularRequest` is optional and defaults to false.

### Cellular Connectivity Pre-Check

Before crafting a request or workflow, you can check whether cellular data connectivity is available. `startCellularGetRequest` already performs this check internally (returning an `sdk_no_data_connectivity` error when unavailable), but exposing it as a standalone call lets you branch your logic *before* making a request.

```swift
import VonageClientLibrary

let client = VGCellularRequestClient()

let hasCellular = await client.checkCellularConnectivity()
if !hasCellular {
    // Cellular data is not available (WiFi only, no connectivity, or cellular data disabled).
    // Handle accordingly before attempting a request.
}
```

`checkCellularConnectivity()` returns `true` when a cellular data path is available (or dormant but activatable), and `false` when only WiFi is available, there is no connectivity, or cellular data is disabled. It always returns `true` on the simulator, which has no cellular interface.

#### Using the Pre-Check with Vonage Verify

This is especially useful when building a [Vonage Verify](https://developer.vonage.com/en/verify/overview) workflow. Silent Authentication (Advanced) requires cellular data, so if the pre-check returns `false` you can omit it from your requested workflow, since it is guaranteed to fail, and fall back to another channel such as SMS.

```swift
let client = VGCellularRequestClient()

// Decide which Verify workflow to request based on cellular availability.
var workflow: [[String: String]] = []

if await client.checkCellularConnectivity() {
    // Cellular data available — Silent Auth Advanced can succeed.
    workflow.append(["channel": "silent_auth"])
}

// Always include a fallback channel.
workflow.append(["channel": "sms"])

// Send `workflow` to your backend to start the Verify request.
```

### Custom Logging

Assign a logger to receive SDK log messages through your preferred logging framework. Implement the `VGLogger` protocol and set it on the client:

```swift
import VonageClientLibrary

class MyLogger: NSObject, VGLogger {
    func log(_ message: String, level: VGLogLevel) {
        // Forward to your preferred logging framework, e.g. OSLog, CocoaLumberjack, etc.
        print("[\(level)] \(message)")
    }
}

let client = VGCellularRequestClient()
client.logger = MyLogger()
```

The logger receives all SDK messages regardless of whether `debug` is enabled. `VGLogLevel` values are `.debug`, `.info`, `.warning`, and `.error`.

### Operator Headers

When `debug: true`, any `X-*` headers returned in redirect responses (such as operator trace IDs like `X-Orange-Trace-Id`) are captured and returned in the response under `debug.operator_headers`. Multiple values for the same header (across redirect hops) are preserved as an array.

```swift
let response = try await client.startCellularGetRequest(params: params, debug: true)

if let debug = response["debug"] as? [String: Any],
   let operatorHeaders = debug["operator_headers"] as? [String: [String]] {
    print(operatorHeaders) // e.g. ["x-orange-trace-id": ["abc123"]]
}
```

#### Responses

* Success - When the data connectivity has been achieved, and a response has been received from the url endpoint:
```
{
    "http_status": string, // HTTP status related to the url
    "response_body" : { // Optional depending on the HTTP status
        ... // The response body of the opened url
    },
    "debug" : {
        "device_info": string, 
        "url_trace" : string,
        "operator_headers": { // X-* headers seen across all hops
            "X-Orange-Trace-Id": [string]
        }
    }
}
```

* Error - When data connectivity is not available and/or an internal SDK error occurred:

```
{
    "error" : string,
    "error_description": string,
    "debug" : {
        "device_info": string, 
        "url_trace" : string,
        "operator_headers": { // X-* headers seen across all hops
            "X-Orange-Trace-Id": [string]
        }
    }
}
```

Potential error codes: `sdk_no_data_connectivity`, `sdk_connection_error`, `sdk_redirect_error`, `sdk_error`.

## Migrating from `VonageClientSDKNumberVerification` or `VonageClientSDKSilentAuth`

`VonageClientLibrary` replaces both `VonageClientSDKNumberVerification` and `VonageClientSDKSilentAuth`
. To migrate from them do the following:

### Update your Dependencies:

You will need to add `VonageClientLibrary` as a [dependency](#installation) and remove either `VonageClientSDKNumberVerification` or `VonageClientSDKSilentAuth`
 depending on which one you were using. 

### Update the Imports:

```swift
// VonageClientSDKNumberVerification
import VonageClientSDKNumberVerification
``` 

or

```swift
// VonageClientSDKSilentAuth
import VonageClientSDKSilentAuth
``` 
 
should be replaced with:

```swift
import VonageClientLibrary
```

### Use the new Client:

```swift
// VonageClientSDKNumberVerification
let client = VGNumberVerificationClient()
``` 

or

```swift
// VonageClientSDKSilentAuth
let client = VGSilentAuthClient()
``` 
 
should be replaced with:

```swift
let client = VGCellularRequestClient()
```

### Make the new Network Call:

`VonageClientLibrary` uses a params object to pass information to the function that makes the network call. This is a similar approach to `VonageClientSDKNumberVerification`, but new if you are using `VonageClientSDKSilentAuth`.

```swift
// VonageClientSDKNumberVerification
let params = VGNumberVerificationParameters(url: "http://www.vonage.com",
                                            headers: ["x-my-header": "My Value"],
                                            queryParameters: ["query-param" : "value"]
                                            maxRedirectCount: 10
                )
        
let response = try await client.startNumberVerification(params: params)
```

or 

```swift
// VonageClientSDKSilentAuth
client.openWithDataCellular(url: url, debug: true) { response in
    ...
}
```

should be replaced with the `VonageClientLibrary` [example](#force-a-cellular-network-request) above.
