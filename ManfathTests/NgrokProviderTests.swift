import XCTest
@testable import ManfathCore

final class NgrokProviderTests: XCTestCase {

    // MARK: - Inspector API JSON parsing

    func testParsesPublicURLWhenPortMatches() {
        let json = #"""
        {
          "tunnels": [
            {
              "name": "command_line",
              "public_url": "https://abc-123.ngrok-free.app",
              "proto": "https",
              "config": { "addr": "http://localhost:3000", "inspect": true }
            }
          ]
        }
        """#
        let url = NgrokProvider.parsePublicURL(from: Data(json.utf8), localPort: 3000)
        XCTAssertEqual(url?.absoluteString, "https://abc-123.ngrok-free.app")
    }

    func testIgnoresTunnelsForOtherPorts() {
        let json = #"""
        {
          "tunnels": [
            { "public_url": "https://other.ngrok-free.app", "config": { "addr": "http://localhost:8080" } }
          ]
        }
        """#
        XCTAssertNil(NgrokProvider.parsePublicURL(from: Data(json.utf8), localPort: 3000))
    }

    func testPicksHTTPSEvenWhenHTTPListedFirst() {
        // ngrok exposes both http:// and https:// tunnels for the same
        // address; we want the secure one.
        let json = #"""
        {
          "tunnels": [
            { "public_url": "http://abc.ngrok-free.app",  "config": { "addr": "http://localhost:5000" } },
            { "public_url": "https://abc.ngrok-free.app", "config": { "addr": "http://localhost:5000" } }
          ]
        }
        """#
        let url = NgrokProvider.parsePublicURL(from: Data(json.utf8), localPort: 5000)
        XCTAssertEqual(url?.absoluteString, "https://abc.ngrok-free.app")
    }

    func testHandlesAddrAsBarePort() {
        let json = #"""
        {
          "tunnels": [
            { "public_url": "https://x.ngrok.app", "config": { "addr": "3000" } }
          ]
        }
        """#
        XCTAssertEqual(
            NgrokProvider.parsePublicURL(from: Data(json.utf8), localPort: 3000)?.absoluteString,
            "https://x.ngrok.app"
        )
    }

    func testHandlesEmptyTunnelsArray() {
        XCTAssertNil(NgrokProvider.parsePublicURL(from: Data(#"{"tunnels": []}"#.utf8), localPort: 3000))
    }

    func testHandlesMalformedJSON() {
        XCTAssertNil(NgrokProvider.parsePublicURL(from: Data("not json".utf8), localPort: 3000))
    }

    // MARK: - Auth-failure detection

    func testDetectsAuthFailureByErrorCode() {
        let line = "ERR_NGROK_4018 authentication failed: Usage of ngrok requires a verified account"
        XCTAssertTrue(NgrokProvider.indicatesAuthFailure(line))
    }

    func testDetectsAuthFailureByPhrase() {
        XCTAssertTrue(NgrokProvider.indicatesAuthFailure("ERROR: authentication failed"))
        XCTAssertTrue(NgrokProvider.indicatesAuthFailure("authtoken is required for tunneling"))
    }

    func testDoesNotFlagBenignAuthtokenMentions() {
        // We only want to flag failures, not informational lines that
        // happen to mention authtoken (e.g. on successful start).
        XCTAssertFalse(NgrokProvider.indicatesAuthFailure("running tunnel http://localhost:3000"))
        XCTAssertFalse(NgrokProvider.indicatesAuthFailure("loaded authtoken from config"))
    }
}
