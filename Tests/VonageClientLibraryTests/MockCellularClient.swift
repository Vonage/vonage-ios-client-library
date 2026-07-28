//
//  MockCellularClient.swift
//  
//
//  Created by Abdulhakim Ajetunmobi on 03/12/2024.
//

import Foundation
@testable import VonageClientLibrary


class MockCellularClient: CellularClient {
    var urlString: String = ""
    
    func get(url: URL, headers: [String : String], maxRedirectCount: Int, debug: Bool, timeout: TimeInterval, logger: VGLogger?) async -> [String : Any] {
        self.urlString = url.absoluteString
        return [:]
    }
}

class MockCellularClientWithConnectivityError: CellularClient {
    func get(url: URL, headers: [String : String], maxRedirectCount: Int, debug: Bool, timeout: TimeInterval, logger: VGLogger?) async -> [String : Any] {
        // Simulate the sdk_no_data_connectivity error response
        // (mirrors the Android SDK's "Data connectivity not available" error)
        var json: [String: Any] = [:]
        json["error"] = "sdk_no_data_connectivity"
        json["error_description"] = "Data connectivity not available"
        return json
    }
}

/// Mock that forwards to a real debug-enabled response including operator_headers
class MockCellularClientWithDebugResponse: CellularClient {
    /// The logger passed to the last `get` call, for inspection in tests.
    var capturedLogger: VGLogger?

    func get(url: URL, headers: [String : String], maxRedirectCount: Int, debug: Bool, timeout: TimeInterval, logger: VGLogger?) async -> [String : Any] {
        capturedLogger = logger
        logger?.log("Test SDK log message", level: .debug)
        var json: [String: Any] = [:]
        json["http_status"] = 200
        if debug {
            var debugJson: [String: Any] = [:]
            debugJson["device_info"] = "iOS/17.0"
            debugJson["url_trace"] = ""
            debugJson["operator_headers"] = ["x-orange-trace-id": ["abc123"], "x-custom-op": ["val1", "val2"]]
            json["debug"] = debugJson
        }
        return json
    }
}

/// A test logger that records received messages.
class SpyLogger: NSObject, VGLogger {
    var messages: [(message: String, level: VGLogLevel)] = []

    func log(_ message: String, level: VGLogLevel) {
        messages.append((message, level))
    }
}
