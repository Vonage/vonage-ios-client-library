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
                                        queryParameters: ["query-param" : "value"]
                                        maxRedirectCount: 10)
        
let response = try await client.startCellularRequest(params: params, debug: true)
```

* `maxRedirectCount` in `VGCellularRequestParameters` is an optional and defaults to 10.
* `debug` parameter for `startCellularRequest` is optional and defaults to false.

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
        "url_trace" : string
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
        "url_trace" : string
    }
}
```

Potential error codes: `sdk_no_data_connectivity`, `sdk_connection_error`, `sdk_redirect_error`, `sdk_error`.