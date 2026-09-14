import XCTest
@testable import VonageClientLibrary

/// Covers reading a response that arrives across more than one `receive` callback.
final class CellularConnectionManagerReceiveTests: XCTestCase {

    private var manager: CellularConnectionManager!
    private let requestUrl = URL(string: "https://api.vonage.com/oauth2/auth")!

    override func setUp() {
        super.setUp()
        manager = CellularConnectionManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    private func data(_ string: String) -> Data {
        Data(string.utf8)
    }

    // MARK: - Accumulation rule

    func testPartialReadIsCarriedForwardRatherThanTreatedAsComplete() {
        let step = manager.nextReceiveStep(
            accumulated: Data(),
            chunk: data("HTTP/1.1 200 OK\r\n"),
            isComplete: false,
            error: nil
        )

        XCTAssertEqual(step, .needsMore(data("HTTP/1.1 200 OK\r\n")))
    }

    /// The shape of the original failure: no data, `isComplete` false. Must ask for more.
    func testEmptyFirstReadAsksForMoreInsteadOfFailing() {
        let step = manager.nextReceiveStep(
            accumulated: Data(),
            chunk: nil,
            isComplete: false,
            error: nil
        )

        XCTAssertEqual(step, .needsMore(Data()))
    }

    func testCompletionFlagEndsTheRead() {
        let step = manager.nextReceiveStep(
            accumulated: data("HTTP/1.1 200 OK\r\n"),
            chunk: data("\r\nbody"),
            isComplete: true,
            error: nil
        )

        XCTAssertEqual(step, .complete(data("HTTP/1.1 200 OK\r\n\r\nbody")))
    }

    func testResponseSplitAcrossSeveralReadsIsReassembledInOrder() {
        let segments = [
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n",
            "\r\n{\"device_phone_number_ve",
            "rified\":true}"
        ]

        var buffer = Data()
        for (index, segment) in segments.enumerated() {
            let isLast = index == segments.count - 1
            let step = manager.nextReceiveStep(
                accumulated: buffer,
                chunk: data(segment),
                isComplete: isLast,
                error: nil
            )

            switch step {
            case .needsMore(let partial):
                XCTAssertFalse(isLast, "only the final read should complete")
                buffer = partial
            case .complete(let full):
                XCTAssertTrue(isLast, "completed earlier than expected")
                buffer = full
            case .failed(let reason):
                return XCTFail("unexpected failure: \(reason)")
            }
        }

        XCTAssertEqual(String(decoding: buffer, as: UTF8.self), segments.joined())
    }

    func testErrorEndsTheReadImmediately() {
        let error = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "connection reset"]
        )

        let step = manager.nextReceiveStep(
            accumulated: data("partial"),
            chunk: nil,
            isComplete: false,
            error: error
        )

        XCTAssertEqual(step, .failed("connection reset"))
    }

    func testEmptyChunkDoesNotCorruptWhatWasAlreadyRead() {
        let step = manager.nextReceiveStep(
            accumulated: data("HTTP/1.1 200 OK"),
            chunk: Data(),
            isComplete: false,
            error: nil
        )

        XCTAssertEqual(step, .needsMore(data("HTTP/1.1 200 OK")))
    }

    // MARK: - Interpreting the assembled response

    func testAssembledJsonResponseIsReportedAsSuccess() {
        let response = "HTTP/1.1 200 OK\r\n"
            + "Content-Type: application/json\r\n"
            + "\r\n"
            + "{\"device_phone_number_verified\":true}"

        let outcome = handle(responseData: data(response))

        guard case .dataOK(let connectionResponse) = outcome else {
            return XCTFail("expected dataOK but got \(String(describing: outcome))")
        }
        XCTAssertEqual(connectionResponse.status, 200)
        XCTAssertNotNil(connectionResponse.body)
    }

    func testAssembledRedirectResponseIsReportedAsFollow() {
        let response = "HTTP/1.1 302 Found\r\n"
            + "Location: https://operator.example/step2\r\n"
            + "\r\n"

        let outcome = handle(responseData: data(response))

        guard case .follow(let redirect) = outcome else {
            return XCTFail("expected follow but got \(String(describing: outcome))")
        }
        XCTAssertEqual(redirect.url?.absoluteString, "https://operator.example/step2")
    }

    func testEmptyResponseStillReportsNoData() {
        let outcome = handle(responseData: Data())

        guard case .err(let error) = outcome else {
            return XCTFail("expected err but got \(String(describing: outcome))")
        }
        XCTAssertEqual(error, NetworkError.other("Response has no data or corrupt"))
    }

    private func handle(responseData: Data) -> ConnectionResult? {
        var outcome: ConnectionResult?
        manager.handleResponse(
            requestUrl: requestUrl,
            responseData: responseData,
            cookies: nil
        ) { result in
            outcome = result
        }
        return outcome
    }
}
