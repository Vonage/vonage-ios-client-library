//
//  CellularClientModels.swift
//
//
//  Created by Abdulhakim Ajetunmobi on 03/12/2024.
//

import UIKit
import Foundation

public class DebugInfo {
    internal let dateUtils = DateUtils()
    private var bufferMap = Dictionary<String, String>()
    
    internal func add(tag: String? = nil, log: String) {
        guard let tag = tag else {
            self.bufferMap[dateUtils.now()] = "\(log)"
            return
        }
        self.bufferMap[dateUtils.now()] = "\(tag) - \(log)"
    }
    
    internal func clear() {
        bufferMap.removeAll()
    }
    
    public func toString() -> String {
        var stringBuffer = ""
        for key in bufferMap.keys.sorted() {
            guard let value = bufferMap[key] else { break }
            stringBuffer += "\(key): \(value)"
        }
        return stringBuffer
    }
    
    public func userAgent(sdkVersion: String) -> String {
        return "vonage-client-library-ios/\(sdkVersion) \(deviceString())"
    }
    
    public func deviceString() -> String {
        var device: String = ""
        device = UIDevice.current.systemName + "/" + UIDevice.current.systemVersion
        return device
    }
}

public struct TraceInfo {
    public let trace: String
    public let debugInfo: DebugInfo
}

func isoTimestampUsingCurrentTimeZone() -> String {
    let isoDateFormatter = ISO8601DateFormatter()
    isoDateFormatter.timeZone = TimeZone.current
    let timestamp = isoDateFormatter.string(from: Date())
    return timestamp
}

class DateUtils {
    lazy var df: ISO8601DateFormatter = {
        let d = ISO8601DateFormatter()
        d.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withFullDate,
            .withFractionalSeconds,
            .withColonSeparatorInTimeZone
        ]
        return d
    }()
    
    func now() -> String {
        df.string(from: Date())
    }
}

public struct RedirectResult {
    public var url: URL?
    public let cookies: [HTTPCookie]?
}

enum NetworkError: Error, Equatable {
    case invalidRedirectURL(String)
    case tooManyRedirects
    case connectionFailed(String)
    case connectionCantBeCreated(String)
    case sdkNoDataConnectivity(String)
    case other(String)
}

public struct ConnectionResponse {
    public var status: Int
    public let body: Data?
}

enum ConnectionResult {
    case err(NetworkError)
    case dataOK(ConnectionResponse)
    case dataErr(ConnectionResponse)
    case follow(RedirectResult)
}

