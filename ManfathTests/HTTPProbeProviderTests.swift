import XCTest
@testable import ManfathCore

final class HTTPProbeProviderTests: XCTestCase {

    // MARK: - Header normalization

    func testNormalizeHeadersLowercasesKeys() {
        let raw: [AnyHashable: Any] = [
            "Server": "nginx",
            "X-Powered-By": "Next.js",
            "Content-Type": "text/html",
        ]
        let out = HTTPProbeProvider.normalizeHeaders(raw)
        XCTAssertEqual(out["server"], "nginx")
        XCTAssertEqual(out["x-powered-by"], "Next.js")
        XCTAssertEqual(out["content-type"], "text/html")
    }

    // MARK: - Framework detection

    func testDetectNextJs() {
        XCTAssertEqual(
            HTTPProbeProvider.detectFramework(from: ["x-powered-by": "next.js 14.2.5"]),
            .nextjs
        )
    }

    func testDetectExpress() {
        XCTAssertEqual(
            HTTPProbeProvider.detectFramework(from: ["x-powered-by": "Express"]),
            .express
        )
    }

    func testDetectDjangoFromWsgiserver() {
        XCTAssertEqual(
            HTTPProbeProvider.detectFramework(from: ["server": "WSGIServer/0.2 CPython/3.11"]),
            .django
        )
    }

    func testDetectFlaskFromWerkzeug() {
        XCTAssertEqual(
            HTTPProbeProvider.detectFramework(from: ["server": "Werkzeug/2.3.7 Python/3.11"]),
            .flask
        )
    }

    func testDetectCraFromWebpackDevServer() {
        XCTAssertEqual(
            HTTPProbeProvider.detectFramework(from: ["server": "webpack-dev-server/4.15"]),
            .cra
        )
    }

    func testDetectRailsFromPhusion() {
        XCTAssertEqual(
            HTTPProbeProvider.detectFramework(from: ["server": "Phusion Passenger 6.0"]),
            .rails
        )
    }

    func testDetectSpringFromApacheCoyote() {
        XCTAssertEqual(
            HTTPProbeProvider.detectFramework(from: ["server": "Apache-Coyote/1.1"]),
            .spring
        )
    }

    func testDetectRocket() {
        XCTAssertEqual(
            HTTPProbeProvider.detectFramework(from: ["server": "Rocket"]),
            .rustRocket
        )
    }

    func testDetectActix() {
        XCTAssertEqual(
            HTTPProbeProvider.detectFramework(from: ["server": "actix-web/4.4"]),
            .rustActix
        )
    }

    func testUnknownServerReturnsNil() {
        XCTAssertNil(
            HTTPProbeProvider.detectFramework(from: ["server": "SomeUnknownServer/1.0"])
        )
    }

    func testEmptyHeadersReturnsNil() {
        XCTAssertNil(HTTPProbeProvider.detectFramework(from: [:]))
    }
}
