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
