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
    
    @objc public init(url: String, headers: [String : String], queryParameters: [String : String], maxRedirectCount: Int = 10) {
        self.url = url
        self.headers = headers
        self.queryParameters = queryParameters
        self.maxRedirectCount = maxRedirectCount
    }
}

@objc public final class VGCellularRequestClient: NSObject {
    var cellularClient: CellularClient
    
    override public init() {
        self.cellularClient = VGCellularClient()
        super.init()
    }
    
    convenience init(cellularClient: CellularClient) {
        self.init()
        self.cellularClient = cellularClient
    }
    
    /// This method performs a GET request given a URL with cellular connectivity
    /// - Parameters:
    ///   - params: Parameters to configure your GET request
    ///   - debug: A flag to include or not the url trace in the response, defaults to false
    @objc public func startCellularGetRequest(params: VGCellularRequestParameters, debug: Bool = false) async throws -> [String: Any] {
        if let url = constructURL(params: params) {
            let response = await cellularClient.get(url: url, headers: params.headers, maxRedirectCount: params.maxRedirectCount, debug: debug)
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
