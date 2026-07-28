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
    
    func testSdkNoDataConnectivityError() async throws {
        let params = VGCellularRequestParameters(url: "http://www.vonage.com", headers: ["x-my-header": "My Value"], queryParameters: [:])
        
        let cellularClient = MockCellularClientWithConnectivityError()
        let client = VGCellularRequestClient(cellularClient: cellularClient)
        let result = try await client.startCellularGetRequest(params: params)
        
        XCTAssertEqual(result["error"] as? String, "sdk_no_data_connectivity")
        XCTAssertEqual(result["error_description"] as? String, "Data connectivity not available")
    }

    // MARK: - Logger tests

    func testCustomLogger_receivesMessages() async throws {
        let params = VGCellularRequestParameters(url: "http://www.vonage.com", headers: [:], queryParameters: [:])
        let spyLogger = SpyLogger()
        let mockClient = MockCellularClientWithDebugResponse()
        let client = VGCellularRequestClient(cellularClient: mockClient)
        client.logger = spyLogger

        _ = try await client.startCellularGetRequest(params: params, debug: true)

        XCTAssertFalse(spyLogger.messages.isEmpty, "Logger should have received at least one message")
        XCTAssertNotNil(mockClient.capturedLogger, "Logger should have been passed to the cellular client")
    }

    func testCustomLogger_isPassedToClient() async throws {
        let params = VGCellularRequestParameters(url: "http://www.vonage.com", headers: [:], queryParameters: [:])
        let spyLogger = SpyLogger()
        let mockClient = MockCellularClientWithDebugResponse()
        let client = VGCellularRequestClient(cellularClient: mockClient)
        client.logger = spyLogger

        _ = try await client.startCellularGetRequest(params: params)

        XCTAssertTrue(mockClient.capturedLogger === spyLogger, "The exact logger instance should be forwarded to the cellular client")
    }

    func testDebugResponse_containsOperatorHeaders() async throws {
        let params = VGCellularRequestParameters(url: "http://www.vonage.com", headers: [:], queryParameters: [:])
        let mockClient = MockCellularClientWithDebugResponse()
        let client = VGCellularRequestClient(cellularClient: mockClient)

        let result = try await client.startCellularGetRequest(params: params, debug: true)

        let debug = result["debug"] as? [String: Any]
        XCTAssertNotNil(debug, "debug dict should be present when debug: true")
        let operatorHeaders = debug?["operator_headers"] as? [String: [String]]
        XCTAssertNotNil(operatorHeaders, "operator_headers should be present in debug dict")
        XCTAssertEqual(operatorHeaders?["x-orange-trace-id"], ["abc123"])
        XCTAssertEqual(operatorHeaders?["x-custom-op"], ["val1", "val2"])
    }

    func testDebugResponse_operatorHeadersAbsentWhenDebugFalse() async throws {
        let params = VGCellularRequestParameters(url: "http://www.vonage.com", headers: [:], queryParameters: [:])
        let mockClient = MockCellularClientWithDebugResponse()
        let client = VGCellularRequestClient(cellularClient: mockClient)

        let result = try await client.startCellularGetRequest(params: params, debug: false)

        XCTAssertNil(result["debug"], "debug dict should not be present when debug: false")
    }
}
