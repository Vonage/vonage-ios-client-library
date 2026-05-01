//
//  TraceCollector.swift
//  
//
//  Created by Abdulhakim Ajetunmobi on 03/12/2024.
//

import os
import UIKit
import Foundation

/// Collects trace and debugging information for each 'check' session.
final class TraceCollector {
    let queue = DispatchQueue(label: "vgnv.tracecollector.queue")

    private var trace = ""
    private var isTraceEnabled = false
    private var body: [String : Any]? = nil

    private var debugInfo = DebugInfo()
    var isDebugInfoCollectionEnabled = false
    var isConsoleLogsEnabled = false

    /// Optional custom logger. When set, SDK log messages are forwarded here
    /// regardless of whether debug mode is enabled.
    var logger: VGLogger?

    /// Accumulates X-* operator headers seen across all hops (header name → array of values).
    private var _operatorHeaders: [String: [String]] = [:]

    /// Stops trace and clears the internal buffer
    func startTrace() {
        queue.sync() {
            if !isTraceEnabled {
                isTraceEnabled = true
                trace.removeAll()
                debugInfo.clear()
                _operatorHeaders.removeAll()
                trace.append("\(debugInfo.deviceString())\n")
                debugInfo.add(log:"\(debugInfo.deviceString())\n")
            } else {
                os_log("%s", type:.error, "Trace already started. Use stopTrace before restaring..")
            }
        }
    }

    /// Stops trace and clears the internal buffer. Collection of debug information also stops, if enabled prior to startTrace().
    func stopTrace() {
        queue.sync() {
            isTraceEnabled = false
            isDebugInfoCollectionEnabled = false
            isConsoleLogsEnabled = false
            trace.removeAll()
            debugInfo.clear()
            _operatorHeaders.removeAll()
        }
    }

    /// Provides the TraceInfo recorded
    func traceInfo() -> TraceInfo {
        queue.sync() {
            return TraceInfo(trace: trace, debugInfo: debugInfo)
        }
    }

    /// Records a trace. Add a newline at the end of the log.
    func addTrace(log: String) {
        queue.async {
            if self.isTraceEnabled {
                self.trace.append("\(log)\n")
            }
        }
    }

    func addDebug(type: OSLogType = .debug, tag: String? = "vgnv", log: String) {
        queue.async {
            if self.isDebugInfoCollectionEnabled {
                self.debugInfo.add(tag: tag, log: log)
            }
        }
        if self.isConsoleLogsEnabled {
            os_log("%s", type:type, log)
        }
        let level: VGLogLevel
        switch type {
        case .error: level = .error
        case .info: level = .info
        default: level = .debug
        }
        logger?.log(log, level: level)
    }

    /// Accumulates an `X-*` operator header value. Thread-safe.
    func addOperatorHeader(name: String, value: String) {
        queue.sync {
            var values = _operatorHeaders[name] ?? []
            values.append(value)
            _operatorHeaders[name] = values
        }
    }

    /// Returns a snapshot of all accumulated operator headers. Thread-safe.
    func operatorHeaders() -> [String: [String]] {
        queue.sync { _operatorHeaders }
    }
    
    func addBody(body: [String : Any]?) {
        self.body = body
    }

    func now() -> String {
        debugInfo.dateUtils.now()
    }

}
