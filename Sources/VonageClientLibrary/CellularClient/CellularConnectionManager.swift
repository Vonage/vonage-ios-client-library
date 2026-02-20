//
//  CellularConnectionManager.swift
//
//
//  Created by Abdulhakim Ajetunmobi on 03/12/2024.
//

import Foundation
import Network
import os

typealias ResultHandler = (ConnectionResult) -> Void


class CellularConnectionManager {
    private var connection: NWConnection?
    
    // Mitigation for tcp timeout not triggering any events.
    private var timer: Timer?
    private var connectionTimeout: TimeInterval = 5.0
    private var pathMonitor: NWPathMonitor?
    private var checkResponseHandler: ResultHandler!
    private var debugInfo = DebugInfo()
    private let sdkVersion = "1.0.5-beta"
    
    lazy var traceCollector: TraceCollector = {
        TraceCollector()
    }()
    
    func get(url: URL, headers: [String: String], maxRedirectCount: Int, debug: Bool, timeout: TimeInterval, completion: @escaping ([String : Any]) -> Void) {
        self.connectionTimeout = timeout
        
        if (debug) {
            traceCollector.isDebugInfoCollectionEnabled = true
            traceCollector.isConsoleLogsEnabled = true
            traceCollector.startTrace()
        }
        
        let requestId = UUID().uuidString
        
        guard let _ = url.scheme, let _ = url.host else {
            completion(convertNetworkErrorToDictionary(err:NetworkError.other("No scheme or host found"), debug: debug))
            return
        }
        
        var redirectCount = 0
        // This closure will be called on main thread
        checkResponseHandler = { [weak self] (response) -> Void in
            
            guard let self = self else {
                var json = [String : Any]()
                json["error"] = "sdk_error"
                json["error_description"] = "Unable to carry on"
                completion(json)
                return
            }
            
            switch response {
            case .follow(let redirectResult):
                if let url = redirectResult.url {
                    redirectCount+=1
                    if redirectCount <= maxRedirectCount {
                        self.traceCollector.addDebug(log: "Redirect found: \(url.absoluteString)")
                        self.traceCollector.addTrace(log: "\nfound redirect: \(url) - \(self.traceCollector.now())")
                        self.createTimer()
                        self.activateConnectionForDataFetch(url: url, headers: headers, cookies: redirectResult.cookies, requestId: requestId, completion: self.checkResponseHandler)
                    } else {
                        self.traceCollector.addDebug(log: "MAX Redirects reached \(String(maxRedirectCount))")
                        self.cleanUp()
                        completion(self.convertNetworkErrorToDictionary(err: NetworkError.tooManyRedirects, debug: debug))
                    }
                } else {
                    self.traceCollector.addDebug(log: "Redirect NOT FOUND")
                    self.cleanUp()
                }
            case .err(let error):
                self.cleanUp()
                self.traceCollector.addDebug(log: "Open completed with \(error.localizedDescription)")
                completion(self.convertNetworkErrorToDictionary(err: error, debug: debug))
            case .dataOK(let connResp):
                self.cleanUp()
                self.traceCollector.addDebug(log: "Data Ok received")
                completion(self.convertConnectionResponseToDictionary(resp: connResp, debug: debug))
            case .dataErr(let connResp):
                self.cleanUp()
                self.traceCollector.addDebug(log: "Data err received")
                completion(self.convertConnectionResponseToDictionary(resp: connResp, debug: debug))
            }
        }
        self.traceCollector.addDebug(log: "url: \(url) - \(self.traceCollector.now())")
        //Initiating on the main thread to synch, as all connection update/state events will also be called on main thread
        DispatchQueue.main.async {
            self.startMonitoring()
            self.createTimer()
//            let cookie = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "key=value"], for: url)
            
            self.activateConnectionForDataFetch(url: url, headers: headers, cookies: nil, requestId: requestId, completion: self.checkResponseHandler)
        }
    }
    
    func convertConnectionResponseToDictionary(resp: ConnectionResponse, debug: Bool)  -> [String : Any] {
        var json: [String : Any] = [:]
        json["http_status"] = resp.status
        if (debug) {
            let ti = self.traceCollector.traceInfo()
            var json_debug: [String : Any] = [:]
            json_debug["device_info"] = ti.debugInfo.deviceString()
            json_debug["url_trace"] = ti.trace
            json["debug"] = json_debug
            self.traceCollector.stopTrace()
        }
        do {
            // load JSON response into a dictionary
            if let body = resp.body, let dictionary = try JSONSerialization.jsonObject(with: body, options: .mutableContainers) as? [String : Any] {
                json["response_body"] = dictionary
            }
        } catch {
            if let body = resp.body {
                json["response_raw_body"] = body
            } else {
                return convertNetworkErrorToDictionary(err: NetworkError.other("JSON deserializarion"), debug: debug)
            }
            
        }
        return json
    }
    
    func convertNetworkErrorToDictionary(err: NetworkError, debug: Bool) -> [String : Any] {
        var json = [String : Any]()
        switch err {
        case .invalidRedirectURL(let string):
            json["error"] = "sdk_redirect_error"
            json["error_description"] = string
        case .tooManyRedirects:
            json["error"] = "sdk_redirect_error"
            json["error_description"] = "Too many redirects"
        case .connectionFailed(let string):
            json["error"] = "sdk_connection_error"
            json["error_description"] = string
        case .connectionCantBeCreated(let string):
            json["error"] = "sdk_connection_error"
            json["error_description"] = string
        case .sdkNoDataConnectivity(let string):
            json["error"] = "sdk_no_data_connectivity"
            json["error_description"] = string
        case .other(let string):
            json["error"] = "sdk_error"
            json["error_description"] = string
        }
        if (debug) {
            let ti = self.traceCollector.traceInfo()
            var json_debug: [String : Any] = [:]
            json_debug["device_info"] = ti.debugInfo.deviceString()
            json_debug["url_trace"] = ti.trace
            json["debug"] = json_debug
            self.traceCollector.stopTrace()
        }
        return json
    }
    
    // MARK: - Internal
    func cancelExistingConnection() {
        if self.connection != nil {
            self.connection?.cancel() // This should trigger a state update
            self.connection = nil
        }
    }
    
    func createConnectionUpdateHandler(completion: @escaping ResultHandler, readyStateHandler: @escaping ()-> Void) -> (NWConnection.State) -> Void {
        return { [weak self] (newState) in
            switch (newState) {
            case .setup:
                self?.traceCollector.addDebug(log: "Connection State: Setup\n")
            case .preparing:
                self?.traceCollector.addDebug(log: "Connection State: Preparing\n")
            case .ready:
                if let tlsMetadata = self?.connection?.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata {
                    // Extract the underlying sec_protocol_metadata_t
                    let secMeta = tlsMetadata.securityProtocolMetadata

                    // Query the negotiated TLS version
                    let version = sec_protocol_metadata_get_negotiated_tls_protocol_version(secMeta)

                    let versionString: String
                    version.rawValue
                       switch version {
                       case .TLSv12: versionString = "TLS 1.2"
                       case .TLSv13: versionString = "TLS 1.3"
                       default: versionString = "Unknown TLS version (\(version.rawValue))"
                       }
                    print("using TLS version \(versionString)")
                }
                let msg = self?.connection.debugDescription ?? "No connection details"
                self?.traceCollector.addDebug(log: "Connection State: Ready \(msg)\n")
                readyStateHandler() //Send and Receive
            case .waiting(let error):
                self?.traceCollector.addDebug(log: "Connection State: Waiting \(error.localizedDescription) \n")
            case .cancelled:
                self?.traceCollector.addDebug(log: "Connection State: Cancelled\n")
            case .failed(let error):
                self?.traceCollector.addDebug(type:.error, log:"Connection State: Failed ->\(error.localizedDescription)")
                completion(.err(NetworkError.other("Connection State: Failed \(error.localizedDescription)")))
            @unknown default:
                self?.traceCollector.addDebug(log: "Connection ERROR State not defined\n")
                completion(.err(NetworkError.other("Connection State: Unknown \(newState)")))
            }
        }
    }
    
    // MARK: - Utility methods
    func createHttpCommand(url: URL, headers: [String: String], cookies: [HTTPCookie]?) -> String? {
        guard let host = url.host, let scheme = url.scheme  else {
            return nil
        }
        var path = url.path
        // the path method is stripping ending / so adding it back
        if (url.absoluteString.hasSuffix("/") && !url.path.hasSuffix("/")) {
            path += "/"
        }
        
        if (path.count == 0) {
            path = "/"
        }
        
        var cmd = String(format: "GET %@", path)
        
        if let q = url.query {
            cmd += String(format:"?%@", q)
        }
        
        cmd += String(format:" HTTP/1.1\r\nHost: %@", host)
        if (scheme.starts(with:"https") && url.port != nil && url.port != 443) {
            cmd += String(format:":%d", url.port!)
        } else if (scheme.starts(with:"http") && url.port != nil && url.port != 80) {
            cmd += String(format:":%d", url.port!)
        }
        
        for (key, value) in headers {
               cmd += "\r\n\(key): \(value)"
        }
        
        if let cookies = cookies {
            var cookieCount = 0
            var cookieString = String()
            for i in 0..<cookies.count {
                if (((cookies[i].isSecure && scheme == "https") || (!cookies[i].isSecure)) && (cookies[i].domain == "" || (cookies[i].domain != "" && host.contains(cookies[i].domain))) && (cookies[i].path == "" ||  path.starts(with: cookies[i].path))) {
                    if (cookieCount > 0) {
                        cookieString += "; "
                    }
                    cookieString += String(format:"%@=%@", cookies[i].name, cookies[i].value)
                    cookieCount += 1
                }
            }
            if (cookieString.count > 0) {
                cmd += "\r\nCookie: \(String(describing: cookieString))"
            }
        }
        
        cmd += "\r\nUser-Agent: \(debugInfo.userAgent(sdkVersion: sdkVersion)) "
        cmd += "\r\nAccept: text/html,application/xhtml+xml,application/xml,*/*"
        cmd += "\r\nConnection: close\r\n\r\n"
        return cmd
    }
    
    func createConnection(scheme: String, host: String, port: Int? = nil) -> NWConnection? {
        if scheme.isEmpty ||
            host.isEmpty ||
            !(scheme.hasPrefix("http") ||
              scheme.hasPrefix("https")) {
            return nil
        }
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = Int(connectionTimeout) //Secs
        tcpOptions.enableKeepalive = false
        
        var tlsOptions: NWProtocolTLS.Options?
        var fport = (port != nil ? NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port!)) : NWEndpoint.Port.http)
        
        if (scheme.starts(with:"https")) {
            fport = (port != nil ? NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port!)) : NWEndpoint.Port.https)

            // tlsOptions = .init()
            tlsOptions = NWProtocolTLS.Options()

            // Force TLS 1.2
            if let secOptions = tlsOptions?.securityProtocolOptions {
                sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)
                sec_protocol_options_set_max_tls_protocol_version(secOptions, .TLSv12)
            }

            tcpOptions.enableFastOpen = true //Save on tcp round trip by using first tls packet
        }
        
        let params = NWParameters(tls: tlsOptions , tcp: tcpOptions)
        params.serviceClass = .responsiveData
        
        #if !targetEnvironment(simulator)
        // force network connection to cellular only
        params.requiredInterfaceType = .cellular
        params.prohibitExpensivePaths = false
        params.prohibitedInterfaceTypes = [.wifi, .loopback, .wiredEthernet]
        self.traceCollector.addTrace(log: "Start connection \(host) \(fport.rawValue) \(scheme) \(self.traceCollector.now())\n")
        self.traceCollector.addDebug(log: "connection scheme \(scheme) \(String(fport.rawValue))")
        #else
        self.traceCollector.addTrace(log: "Start connection on simulator \(host) \(fport.rawValue) \(scheme) \(self.traceCollector.now())\n")
        self.traceCollector.addDebug(log: "connection scheme on simulator \(scheme) \(String(fport.rawValue))")
        #endif
        
        connection = NWConnection(host: NWEndpoint.Host(host), port: fport, using: params)
        
        return connection
    }
    
    func parseHttpStatusCode(response: String) -> Int {
        let status = response[response.index(response.startIndex, offsetBy: 9)..<response.index(response.startIndex, offsetBy: 12)]
        return Int(status) ?? 0
    }
    
    /// Decodes a response, first attempting with UTF8 and then fallback to ascii
    /// - Parameter data: Data which contains the response
    /// - Returns: decoded response as String
    func decodeResponse(data: Data) -> String? {
        guard let response = String(data: data, encoding: .utf8) else {
            return String(data: data, encoding: .ascii)
        }
        return response
    }
    
    func parseRedirect(requestUrl: URL, response: String, cookies: [HTTPCookie]?) -> RedirectResult? {
        guard let _ = requestUrl.host else {
            return nil
        }
        //header could be named "Location" or "location"
        if let range = response.range(of: #"ocation: (.*)\r\n"#, options: .regularExpression) {
            let location = response[range]
            let redirect = location[location.index(location.startIndex, offsetBy: 9)..<location.index(location.endIndex, offsetBy: -1)]
            // some location header are not properly encoded
            let cleanRedirect = redirect.replacingOccurrences(of: " ", with: "+")
            if let redirectURL =  URL(string: String(cleanRedirect)) {
                return RedirectResult(url: redirectURL.host == nil ? URL(string: redirectURL.description, relativeTo: requestUrl)! : redirectURL, cookies: self.parseCookies(url:requestUrl, response: response, existingCookies: cookies))
            } else {
                self.traceCollector.addDebug(log: "URL malformed \(cleanRedirect)")
                return nil
            }
        }
        return nil
    }
    
    func createTimer() {
        if let timer = self.timer, timer.isValid {
            os_log("Invalidating the existing timer", type: .debug)
            timer.invalidate()
        }
        
        os_log("Starting a new timer", type: .debug)
        self.timer = Timer.scheduledTimer(timeInterval: self.connectionTimeout,
                                          target: self,
                                          selector: #selector(self.fireTimer),
                                          userInfo: nil,
                                          repeats: false)
    }
    
    @objc func fireTimer() {
        self.traceCollector.addDebug(log: "Connection time out.")
        timer?.invalidate()
        checkResponseHandler(.err(NetworkError.connectionCantBeCreated("Connection cancelled - time out")))
    }
    
    /// Asynchronously checks if cellular data connectivity is available.
    /// Offloads the blocking NWPathMonitor + semaphore check to a GCD queue so that
    /// Swift's cooperative thread pool is never blocked.
    func checkCellularConnectivityAsync() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.checkCellularConnectivity()
                continuation.resume(returning: result)
            }
        }
    }

    /// Checks if cellular data connectivity is available.
    /// Mirrors the Android SDK's `forceCellular` check: requests a cellular-only network path
    /// and verifies it is satisfied before proceeding. Returns true if cellular data is available
    /// and usable, false if only WiFi, no connectivity, or cellular data is disabled.
    ///
    /// - Important: This method blocks the calling thread for up to 2 seconds.
    ///   Prefer ``checkCellularConnectivityAsync()`` when called from an async context.
    private func checkCellularConnectivity() -> Bool {
        #if targetEnvironment(simulator)
        // Simulator has no cellular interface; skip the check so requests can proceed
        // over whatever interface the simulator provides (mirrors createConnection behaviour).
        self.traceCollector.addDebug(log: "Running on simulator – skipping cellular connectivity check")
        return true
        #else
        // Use a cellular-specific path monitor (analogous to Android's
        // NetworkRequest with TRANSPORT_CELLULAR + NET_CAPABILITY_INTERNET).
        let cellularMonitor = NWPathMonitor(requiredInterfaceType: .cellular)
        var hasCellularPath = false

        // Semaphore to synchronously wait for the first path update.
        let semaphore = DispatchSemaphore(value: 0)

        cellularMonitor.pathUpdateHandler = { path in
            defer { semaphore.signal() }

            if path.status == .satisfied {
                hasCellularPath = true
                self.traceCollector.addDebug(log: "Cellular path is satisfied – data connectivity available")
            } else if path.status == .unsatisfied {
                self.traceCollector.addDebug(log: "Cellular path unsatisfied – no cellular data connectivity")
            } else if path.status == .requiresConnection {
                // The interface exists but isn't active yet; treat as unavailable.
                self.traceCollector.addDebug(log: "Cellular path requires connection – treating as unavailable")
            }
        }

        cellularMonitor.start(queue: .global(qos: .userInitiated))

        // Wait up to 2 seconds for the path update (Android uses a 5-second timeout
        // for the full network request; here we only need to discover the path status).
        let timeoutResult = semaphore.wait(timeout: .now() + 2.0)
        cellularMonitor.cancel()

        if timeoutResult == .timedOut {
            self.traceCollector.addDebug(log: "Cellular connectivity check timed out – no path available")
            return false
        }

        return hasCellularPath
        #endif
    }

    func startMonitoring() {
        if let monitor = pathMonitor { monitor.cancel() }
        
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { path in
            let interfaceTypes = path.availableInterfaces.map { $0.type }
            for interfaceType in interfaceTypes {
                switch interfaceType {
                case .wifi:
                    self.traceCollector.addDebug(log: "Path is Wi-Fi")
                    
                case .cellular:
                    self.traceCollector.addDebug(log: "Path is Cellular ipv4 \(path.supportsIPv4.description) ipv6 \(path.supportsIPv6.description)")
                    
                case .wiredEthernet:
                    self.traceCollector.addDebug(log: "Path is Wired Ethernet")
                    
                case .loopback:
                    self.traceCollector.addDebug(log: "Path is Loopback")
                    
                case .other:
                    self.traceCollector.addDebug(log: "Path is other")
                    
                default:
                    self.traceCollector.addDebug(log: "Path is unknown")
                    
                }
            }
        }
        pathMonitor?.start(queue: .main)
    }
    
    func stopMonitoring() {
        if let monitor = pathMonitor {
            monitor.cancel()
            pathMonitor = nil
        }
    }
    
    func cleanUp() {
        self.traceCollector.addDebug(log: "Performing clean-up.")
        self.timer?.invalidate()
        self.stopMonitoring()
        self.cancelExistingConnection()
    }
    
    func activateConnectionForDataFetch(url: URL, headers: [String : String], cookies: [HTTPCookie]?, requestId: String?, completion: @escaping ResultHandler) {self.cancelExistingConnection()
        guard let scheme = url.scheme,
              let host = url.host else {
            completion(.err(NetworkError.other("URL has no Host or Scheme")))
            return
        }
        
        guard let command = createHttpCommand(url: url, headers: headers, cookies: cookies),
              let data = command.data(using: .utf8) else {
            completion(.err(NetworkError.other("Unable to create HTTP Request command")))
            return
        }
        
        self.traceCollector.addDebug(log: "sending data:\n\(command)")
        self.traceCollector.addTrace(log: "\ncommand:\n\(command)")
        
        connection = createConnection(scheme: scheme, host: host, port: url.port)
        if let connection = connection {
            connection.stateUpdateHandler = createConnectionUpdateHandler(completion: completion, readyStateHandler: { [weak self] in
                self?.sendAndReceiveWithBody(requestUrl: url, data: data, cookies: cookies, completion: completion)
            })
            // All connection events will be delivered on the main thread.
            connection.start(queue: .main)
        } else {
            os_log("Problem creating a connection ", url.absoluteString)
            completion(.err(NetworkError.connectionCantBeCreated("Problem creating a connection \(url.absoluteString)")))
        }
    }
    
    func sendAndReceiveWithBody(requestUrl: URL, data: Data, cookies: [HTTPCookie]?, completion: @escaping ResultHandler) {
        connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                os_log("Sending error %s", type: .error, err.localizedDescription)
                completion(.err(NetworkError.other(err.localizedDescription)))
                
            }
        }))
        
        timer?.invalidate()
        
        //Read the entire response body
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, context, isComplete, error in
            
            os_log("Receive isComplete: %s", isComplete.description)
            if let err = error {
                completion(.err(NetworkError.other(err.localizedDescription)))
                return
            }
            
            if let d = data, !d.isEmpty, let response = self.decodeResponse(data: d) {
                
                os_log("Response:\n %s", response)
                
                // Log all response headers if debug mode is enabled
                if self.traceCollector.isDebugInfoCollectionEnabled {
                    self.logResponseHeaders(response: response)
                }
                
                let status = self.parseHttpStatusCode(response: response)
                os_log("\n----\nHTTP status: %s", String(status))
                
                switch status {
                case 200...202:
                    if let r = self.getResponseBody(response: response) {
                        completion(.dataOK(ConnectionResponse(status: status, body: r)))
                    } else {
                        completion(.dataOK(ConnectionResponse(status: status, body: nil)))
                    }
                case 204:
                    completion(.dataOK(ConnectionResponse(status: status, body: nil)))
                case 301...303, 307...308:
                    guard let ru = self.parseRedirect(requestUrl: requestUrl, response: response, cookies: cookies) else {
                        completion(.err(NetworkError.invalidRedirectURL("Invalid URL - unable to parseRedirect")))
                        return
                    }
                    completion(.follow(ru))
                case 309...399:
                    completion(.err(NetworkError.other("Unexpected HTTP Status \(status)")))
                case 400...451:
                    if let r = self.getResponseBody(response: response) {
                        completion(.dataErr(ConnectionResponse(status: status, body:r)))
                    } else {
                        completion(.err(NetworkError.other("Unexpected HTTP Status \(status)")))
                    }
                case 500...511:
                    if let r = self.getResponseBody(response: response) {
                        completion(.dataErr(ConnectionResponse(status: status, body:r)))
                    } else {
                        completion(.err(NetworkError.other("Unexpected HTTP Status \(status)")))
                    }
                default:
                    completion(.err(NetworkError.other("Unexpected HTTP Status \(status)")))
                }
            } else {
                completion(.err(NetworkError.other("Response has no data or corrupt")))
            }
        }
    }
    
    func getResponseBody(response: String) -> Data? {
        if let rangeContentType = response.range(of: #"Content-Type: (.*)\r\n"#, options: .regularExpression) {
            // retrieve content type
            let contentType = response[rangeContentType]
            let type = contentType[contentType.index(contentType.startIndex, offsetBy: 9)..<contentType.index(contentType.endIndex, offsetBy: -1)]
            if (type.contains("application/json") || type.contains("application/hal+json") || type.contains("application/problem+json")) {
                if let range = response.range(of: "\r\n\r\n") {
                    if let rangeTransferEncoding = response.range(of: #"Transfer-Encoding: chunked\r\n"#, options: .regularExpression) {
                        if (!rangeTransferEncoding.isEmpty) {
                            if let r1 = response.range(of: "\r\n\r\n") , let r2 = response.range(of:"\r\n0\r\n") {
                                let c = response[r1.upperBound..<r2.lowerBound]
                                if let start = c.firstIndex(of: "{") {
                                    let json = c[start..<c.index(c.endIndex, offsetBy: 0)]
                                    os_log("json: %s",  String(json))
                                    let jsonString = String(json)
                                    guard let data = jsonString.data(using: .utf8) else {
                                        return nil
                                    }
                                    return data
                                }
                            }
                        }
                    }
                    let content = response[range.upperBound..<response.index(response.endIndex, offsetBy: 0)]
                    if let start = content.firstIndex(of: "{") {
                        let json = content[start..<response.index(response.endIndex, offsetBy: 0)]
                        os_log("json: %s",  String(json))
                        let jsonString = String(json)
                        guard let data = jsonString.data(using: .utf8) else {
                            return nil
                        }
                        return data
                    }
                }
            }
        }
        return nil
    }
    
    func parseCookies(url: URL, response: String, existingCookies: [HTTPCookie]?) -> [HTTPCookie]? {
        var cookies = [HTTPCookie]()
        if let existing = existingCookies {
            for i in 0..<existing.count {
                cookies.append(existing[i])
            }
        }
        var position = response.startIndex
        while let range = response.range(of: #"ookie: (.*)\r\n"#, options: .regularExpression, range: position..<response.endIndex) {
            let line = response[range]
            let optCookieString:Substring? = line[line.index(line.startIndex, offsetBy: 7)..<line.index(line.endIndex, offsetBy: -1)]
            if let cookieString = optCookieString {
                self.traceCollector.addDebug(log:"parseCookies \(cookieString)")
                let optCs: [HTTPCookie]? = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie" : String(cookieString)], for: url)
                if let cs = optCs  {
                    if (!cs.isEmpty) {
                    cookies.append((cs.first)!)
                    self.traceCollector.addDebug(log:"cookie=> \((cs.first)!)")
                    }
                } else {
                    self.traceCollector.addDebug(log:"cannot parse cookie \(cookieString)")
                }
            }
            position = range.upperBound
        }
        return (!cookies.isEmpty) ? cookies : nil
    }
    
    func logResponseHeaders(response: String) {
        // Find the end of headers section (indicated by \r\n\r\n)
        guard let headerEndRange = response.range(of: "\r\n\r\n") else {
            self.traceCollector.addDebug(log: "Could not find header section in response")
            return
        }
        
        let headerSection = response[..<headerEndRange.lowerBound]
        self.traceCollector.addDebug(log: "=== Response Headers ===")
        
        // Split by \r\n to get individual header lines
        let lines = headerSection.components(separatedBy: "\r\n")
        for line in lines {
            if !line.isEmpty {
                self.traceCollector.addDebug(log: line)
            }
        }
        self.traceCollector.addDebug(log: "========================")
    }
    
}
