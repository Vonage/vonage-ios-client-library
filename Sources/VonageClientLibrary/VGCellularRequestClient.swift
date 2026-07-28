//
//  VGCellularRequestClient.swift
//
//
//  Created by Abdulhakim Ajetunmobi on 03/12/2024.
//

import Foundation

enum VGCellularRequestError: Error {
    case invalidUrl
}

@objc public class VGCellularRequestParameters: NSObject {
    let url: String
    let headers: [String: String]
    let queryParameters: [String: String]
    let maxRedirectCount: Int
    let timeout: TimeInterval
    
    @objc public init(url: String, headers: [String : String], queryParameters: [String : String], maxRedirectCount: Int = 10, timeout: TimeInterval = 5.0) {
        self.url = url
        self.headers = headers
        self.queryParameters = queryParameters
        self.maxRedirectCount = maxRedirectCount
        self.timeout = timeout
    }
}

@objc public final class VGCellularRequestClient: NSObject {
    var cellularClient: CellularClient

    /// Assign a custom logger to receive SDK log messages through your preferred logging framework.
    @objc public weak var logger: VGLogger?
    
    override public init() {
        self.cellularClient = VGCellularClient()
        super.init()
    }
    
    convenience init(cellularClient: CellularClient) {
        self.init()
        self.cellularClient = cellularClient
    }
    
    /// Checks whether cellular data connectivity is currently available, without performing a request.
    ///
    /// Use this to pre-check connectivity before crafting a request or workflow. For example, when
    /// building a Vonage Verify workflow, you can skip Silent Auth Advanced (which requires cellular
    /// data) when this returns `false`, since it is expected to fail without a cellular data path.
    ///
    /// This runs the same check that `startCellularGetRequest(params:debug:)` performs internally.
    /// - Returns: `true` if a cellular data path is available (or dormant but activatable), `false`
    ///   if only WiFi, no connectivity, or cellular data is disabled. Always returns `true` on the
    ///   simulator, which has no cellular interface.
    @objc public func checkCellularConnectivity() async -> Bool {
        return await cellularClient.checkCellularConnectivity(logger: logger)
    }

    /// This method performs a GET request given a URL with cellular connectivity
    /// - Parameters:
    ///   - params: Parameters to configure your GET request
    ///   - debug: A flag to include or not the url trace and operator headers in the response, defaults to false
    @objc public func startCellularGetRequest(params: VGCellularRequestParameters, debug: Bool = false) async throws -> [String: Any] {
        if let url = constructURL(params: params) {
            let response = await cellularClient.get(url: url, headers: params.headers, maxRedirectCount: params.maxRedirectCount, debug: debug, timeout: params.timeout, logger: logger)
            return response
        } else {
            throw VGCellularRequestError.invalidUrl
        }
    }
    
    private func constructURL(params: VGCellularRequestParameters) -> URL? {
        var urlComponents = URLComponents()
        urlComponents.queryItems = params.queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        let urlString: String
        if let queryParameterString = urlComponents.percentEncodedQuery, !queryParameterString.isEmpty {
            urlString = "\(params.url)?\(queryParameterString)"
        } else {
            urlString = "\(params.url)"
        }
        
        return URL(string: urlString)
    }
}
