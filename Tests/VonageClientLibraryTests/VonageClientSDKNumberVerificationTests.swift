import XCTest
@testable import VonageClientLibrary

final class VonageClientLibraryTests: XCTestCase {
        
    func testUrlGeneration_noParams() async throws {
        let params = VGCellularRequestParameters(url: "http://www.vonage.com", headers: ["x-my-header": "My Value"], queryParameters: [:])
        
        let cellularClient = MockCellularClient()
        let client = VGCellularRequestClient(cellularClient: cellularClient)
        _ = try await client.startCellularGetRequest(params: params)
        
        XCTAssertEqual(cellularClient.urlString, "http://www.vonage.com")
    }
    
    func testUrlGeneration_validParams() async throws {
        let params = VGCellularRequestParameters(url: "http://www.vonage.com", headers: ["x-my-header": "My Value"], queryParameters: ["query-param" : "value"])
        
        let cellularClient = MockCellularClient()
        let client = VGCellularRequestClient(cellularClient: cellularClient)
        _ = try await client.startCellularGetRequest(params: params)
        
        XCTAssertEqual(cellularClient.urlString, "http://www.vonage.com?query-param=value")
    }
    
    func testUrlGeneration_encodedParams() async throws {
        let params = VGCellularRequestParameters(url: "http://www.vonage.com", headers: ["x-my-header": "My Value"], queryParameters: ["query-param" : "my value"])
        
        let cellularClient = MockCellularClient()
        let client = VGCellularRequestClient(cellularClient: cellularClient)
        _ = try await client.startCellularGetRequest(params: params)
        
        XCTAssertEqual(cellularClient.urlString, "http://www.vonage.com?query-param=my%20value")
    }
}
