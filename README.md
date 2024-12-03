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
        
let response = try await client.startCellularGetRequest(params: params)
```
