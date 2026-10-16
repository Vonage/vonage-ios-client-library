import XCTest
@testable import VonageClientLibrary

final class SDKVersionSyncTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testPodspecVersionMatchesSDKVersionConstant() throws {
        let podspecURL = repoRoot.appendingPathComponent("VonageClientLibrary.podspec")
        let podspecContents = try String(contentsOf: podspecURL, encoding: .utf8)
        XCTAssertTrue(
            podspecContents.contains("SDKVersion.swift"),
            "Podspec must derive s.version from SDKVersion.swift, not a hardcoded literal"
        )
    }

    func testSDKVersionIsValidSemver() {
        let semverRegex = #"^\d+\.\d+\.\d+(-[A-Za-z0-9.]+)?$"#
        XCTAssertNotNil(
            SDKVersion.current.range(of: semverRegex, options: .regularExpression),
            "SDKVersion.current (\(SDKVersion.current)) is not valid semver"
        )
    }

    func testUserAgentContainsSDKVersion() {
        let ua = DebugInfo().userAgent(sdkVersion: SDKVersion.current)
        XCTAssertTrue(ua.hasPrefix("vonage-client-library-ios/\(SDKVersion.current) "))
    }
}
