import XCTest
@testable import VonageClientLibrary

final class CellularConnectionManagerRedirectTests: XCTestCase {

    private var manager: CellularConnectionManager!

    override func setUp() {
        super.setUp()
        manager = CellularConnectionManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    private func response(location: String) -> String {
        "HTTP/1.1 302 Found\r\nLocation: \(location)\r\nContent-Length: 0\r\n\r\n"
    }

    private func redirect(from requestUrl: String, to location: String) -> RedirectResult? {
        manager.parseRedirect(
            requestUrl: URL(string: requestUrl)!,
            response: response(location: location),
            cookies: nil
        )
    }

    /// A secure request must not be followed onto plaintext. Android already blocks this.
    func testHttpsToHttpDowngradeIsRefused() {
        XCTAssertNil(redirect(from: "https://api.vonage.com/auth", to: "http://operator.example/step2"))
    }

    func testHttpsToHttpsIsFollowed() {
        let result = redirect(from: "https://api.vonage.com/auth", to: "https://operator.example/step2")

        XCTAssertEqual(result?.url?.absoluteString, "https://operator.example/step2")
    }

    /// The request was already plaintext, so there is nothing to downgrade.
    func testHttpToHttpIsFollowed() {
        let result = redirect(from: "http://operator.example/one", to: "http://operator.example/two")

        XCTAssertEqual(result?.url?.absoluteString, "http://operator.example/two")
    }

    func testHttpToHttpsUpgradeIsFollowed() {
        let result = redirect(from: "http://operator.example/one", to: "https://operator.example/two")

        XCTAssertEqual(result?.url?.absoluteString, "https://operator.example/two")
    }

    /// A relative Location inherits the scheme, so it stays secure and must still be followed.
    func testRelativeRedirectFromHttpsIsFollowedAndStaysSecure() {
        let result = redirect(from: "https://api.vonage.com/auth", to: "/oauth2/callback")

        XCTAssertEqual(result?.url?.scheme, "https")
        XCTAssertEqual(result?.url?.host, "api.vonage.com")
        XCTAssertEqual(result?.url?.path, "/oauth2/callback")
    }

    func testMalformedLocationIsStillRejected() {
        XCTAssertNil(redirect(from: "https://api.vonage.com/auth", to: ""))
    }
}
