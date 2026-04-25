import XCTest
@testable import ManfathCore

final class CategoryClassifierTests: XCTestCase {

    func testFrameworkHintWinsRegardlessOfProcessName() {
        // `node` would normally be .runtime, but a Vite framework hint
        // upgrades it.
        let cat = CategoryClassifier.classify(
            processName: "node",
            executablePath: "/usr/local/bin/node",
            framework: .vite
        )
        XCTAssertEqual(cat, .devServer)
    }

    func testUnknownFrameworkDoesNotCount() {
        // FrameworkHint.unknown means "we couldn't identify it" — it
        // shouldn't promote a runtime to dev-server.
        let cat = CategoryClassifier.classify(
            processName: "node",
            executablePath: "/usr/local/bin/node",
            framework: .unknown
        )
        XCTAssertEqual(cat, .runtime)
    }

    func testDatabaseProcessNamesArePinned() {
        for name in ["postgres", "redis-server", "mongod", "mysqld", "memcached", "elasticsearch"] {
            XCTAssertEqual(
                CategoryClassifier.classify(processName: name, executablePath: nil, framework: nil),
                .database,
                "expected \(name) to be .database"
            )
        }
    }

    func testDatabaseMatchIsCaseInsensitive() {
        XCTAssertEqual(
            CategoryClassifier.classify(processName: "Postgres", executablePath: nil, framework: nil),
            .database
        )
    }

    func testAppHelperByExecutablePath() {
        let cat = CategoryClassifier.classify(
            processName: "Slack Helper",
            executablePath: "/Applications/Slack.app/Contents/MacOS/Slack Helper (Renderer)",
            framework: nil
        )
        XCTAssertEqual(cat, .appHelper)
    }

    func testKnownSystemServicesGoToSystem() {
        for name in ["rapportd", "ControlCenter", "mDNSResponder", "sharingd"] {
            XCTAssertEqual(
                CategoryClassifier.classify(processName: name, executablePath: nil, framework: nil),
                .system,
                "expected \(name) to be .system"
            )
        }
    }

    func testRuntimeWithoutFrameworkIsRuntime() {
        XCTAssertEqual(
            CategoryClassifier.classify(processName: "python3", executablePath: nil, framework: nil),
            .runtime
        )
    }

    func testTotallyUnknownFallsThrough() {
        XCTAssertEqual(
            CategoryClassifier.classify(processName: "weird-binary", executablePath: "/opt/weird", framework: nil),
            .unknown
        )
    }

    func testIsRealServerFlag() {
        XCTAssertTrue(ProcessCategory.devServer.isRealServer)
        XCTAssertTrue(ProcessCategory.database.isRealServer)
        XCTAssertTrue(ProcessCategory.runtime.isRealServer)
        XCTAssertFalse(ProcessCategory.appHelper.isRealServer)
        XCTAssertFalse(ProcessCategory.system.isRealServer)
        XCTAssertFalse(ProcessCategory.unknown.isRealServer)
    }
}
