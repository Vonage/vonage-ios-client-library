import XCTest
@testable import VonageClientLibrary

final class CellularConnectionManagerDecodingTests: XCTestCase {

    private var manager: CellularConnectionManager!

    override func setUp() {
        super.setUp()
        manager = CellularConnectionManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    /// `google.com`, which was used during testing, serves ISO-8859-1. Byte 0xF3 is not valid UTF-8, and the previous `.ascii`
    /// fallback also rejected it, so a 200 was reported as "Response has no data or corrupt".
    func testLatin1ResponseIsDecodedRatherThanRejected() {
        var bytes = Data("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=ISO-8859-1\r\n\r\n".utf8)
        bytes.append(0xF3)

        let decoded = manager.decodeResponse(data: bytes)

        XCTAssertNotNil(decoded, "a Latin-1 response must still decode")
        XCTAssertTrue(decoded?.hasPrefix("HTTP/1.1 200 OK") == true)
    }

    func testUtf8ResponseStillDecodes() {
        let bytes = Data("HTTP/1.1 200 OK\r\n\r\n{\"city\":\"Málaga\"}".utf8)

        XCTAssertEqual(
            manager.decodeResponse(data: bytes),
            "HTTP/1.1 200 OK\r\n\r\n{\"city\":\"Málaga\"}"
        )
    }

    /// ISO-8859-1 maps all 256 byte values, so decoding can no longer return nil.
    func testEveryByteValueDecodes() {
        for byte in UInt8.min...UInt8.max {
            XCTAssertNotNil(
                manager.decodeResponse(data: Data([byte])),
                "byte \(byte) should decode"
            )
        }
    }
}
