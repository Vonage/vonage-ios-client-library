//
//  CellularClient.swift
//
//
//  Created by Abdulhakim Ajetunmobi on 03/12/2024.
//

import Foundation
import CoreTelephony

protocol CellularClient {
    func get(url: URL, headers: [String: String], maxRedirectCount: Int, debug: Bool, timeout: TimeInterval) async -> [String: Any]
}

class VGCellularClient: CellularClient {
    private let connectionManager: CellularConnectionManager
    private let operators: String?

    init() {
        self.connectionManager = CellularConnectionManager()
        // retrieve operators associated with handset:
        // a commas separated list of mobile operators (MCCMNC)
        let t = CTTelephonyNetworkInfo()
        var ops: Array<String> = Array()
        for (_, carrier) in t.serviceSubscriberCellularProviders ?? [:] {
            let op: String = String(format: "%@%@",carrier.mobileCountryCode ?? "", carrier.mobileNetworkCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if (op.lengthOfBytes(using: .utf8)>0) {
                ops.append(op)
            }
        }
        if (!ops.isEmpty) {
            self.operators = ops.joined(separator: ",")
        } else {
            self.operators = nil
        }
    }
    
    func get(url: URL, headers: [String: String], maxRedirectCount: Int, debug: Bool, timeout: TimeInterval) async -> [String: Any] {
        // Perform the cellular connectivity check asynchronously, off the
        // cooperative thread pool, before entering withCheckedContinuation.
        let hasCellular = await connectionManager.checkCellularConnectivityAsync()
        if !hasCellular {
            var json = [String: Any]()
            json["error"] = "sdk_no_data_connectivity"
            json["error_description"] = "Data connectivity not available"
            if debug {
                var debugJson = [String: Any]()
                debugJson["device_info"] = DebugInfo().deviceString()
                debugJson["url_trace"] = ""
                json["debug"] = debugJson
            }
            return json
        }

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()
            connectionManager.get(url: url, headers: headers, maxRedirectCount: maxRedirectCount, debug: debug, timeout: timeout) { response in
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: response)
                } else {
                    print("⚠️ Continuation already resumed.")
               }
            }
        }
    }
}
