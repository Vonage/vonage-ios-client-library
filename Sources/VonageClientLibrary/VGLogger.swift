//
//  VGLogger.swift
//
//
//  Created by Vonage.
//

import Foundation

/// Log severity levels used by the Vonage SDK.
@objc public enum VGLogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
}

/// Conform to this protocol and set it on ``VGCellularRequestClient/logger`` to receive
/// SDK log messages through your preferred logging framework.
///
/// Example:
/// ```swift
/// class MyLogger: NSObject, VGLogger {
///     func log(_ message: String, level: VGLogLevel) {
///         // forward to CocoaLumberjack, OSLog, etc.
///     }
/// }
/// let client = VGCellularRequestClient()
/// client.logger = MyLogger()
/// ```
@objc public protocol VGLogger: NSObjectProtocol {
    /// Called by the SDK whenever it emits a log message.
    /// - Parameters:
    ///   - message: The log message.
    ///   - level: The severity level of the message.
    func log(_ message: String, level: VGLogLevel)
}
