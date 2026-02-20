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
    
    func get(url: URL, headers: [String : String], maxRedirectCount: Int, debug: Bool, timeout: TimeInterval) async -> [String : Any] {
        self.urlString = url.absoluteString
        return [:]
    }
}

class MockCellularClientWithConnectivityError: CellularClient {
    func get(url: URL, headers: [String : String], maxRedirectCount: Int, debug: Bool, timeout: TimeInterval) async -> [String : Any] {
        // Simulate the sdk_no_data_connectivity error response
        // (mirrors the Android SDK's "Data connectivity not available" error)
        var json: [String: Any] = [:]
        json["error"] = "sdk_no_data_connectivity"
        json["error_description"] = "Data connectivity not available"
        return json
    }
}
