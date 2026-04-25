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

    func testPythonInsideAppBundleIsStillRuntime() {
        // Xcode ships its own Python at
        //   /Applications/Xcode.app/.../Python.app/Contents/MacOS/Python
        // The `.app/Contents/MacOS/` path used to falsely classify it
        // as .appHelper, hiding the user's Django dev server. Runtime
        // detection must win.
        let xcodePython = "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python"
        XCTAssertEqual(
            CategoryClassifier.classify(processName: "Python", executablePath: xcodePython, framework: nil),
            .runtime
        )
        // Same shape, lowercase invocation.
        XCTAssertEqual(
            CategoryClassifier.classify(processName: "python3.11", executablePath: xcodePython, framework: nil),
            .runtime
        )
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

    func testVersionedRuntimeNamesClassifyAsRuntime() {
        // The big practical bug: `python3.10` from Homebrew, `ruby2.7`,
        // `node20`, etc. should all bucket as .runtime, not .unknown.
        // Otherwise the "show only real servers" filter hides them.
        let cases = [
            "python3.10", "python3.11", "python3.12",
            "python3.12.4",
            "ruby2.7", "ruby3.0",
            "node20", "node-20",
            "java21",
        ]
        for name in cases {
            XCTAssertEqual(
                CategoryClassifier.classify(processName: name, executablePath: nil, framework: nil),
                .runtime,
                "expected \(name) to be .runtime"
            )
        }
    }

    func testIsRuntimePureFunction() {
        // Direct unit test of the matcher.
        XCTAssertTrue(CategoryClassifier.isRuntime("python"))
        XCTAssertTrue(CategoryClassifier.isRuntime("python3"))
        XCTAssertTrue(CategoryClassifier.isRuntime("python3.11"))
        XCTAssertTrue(CategoryClassifier.isRuntime("Ruby2.7"))   // case-insensitive
        XCTAssertTrue(CategoryClassifier.isRuntime("node20"))
        XCTAssertFalse(CategoryClassifier.isRuntime("pythonz"))   // letter suffix
        XCTAssertFalse(CategoryClassifier.isRuntime("nodemon"))   // letter suffix
        XCTAssertFalse(CategoryClassifier.isRuntime("pythonista")) // contains base but with letters
    }

    func testTotallyUnknownFallsThrough() {
        XCTAssertEqual(
            CategoryClassifier.classify(processName: "weird-binary", executablePath: "/opt/weird", framework: nil),
            .unknown
        )
    }

    func testIsRealServerFlag() {
        // Only positively-noise categories are hidden by the filter.
        // .unknown is treated as visible so rare dev servers (gunicorn,
        // uvicorn, custom binaries) aren't accidentally suppressed.
        XCTAssertTrue(ProcessCategory.devServer.isRealServer)
        XCTAssertTrue(ProcessCategory.database.isRealServer)
        XCTAssertTrue(ProcessCategory.runtime.isRealServer)
        XCTAssertTrue(ProcessCategory.unknown.isRealServer)
        XCTAssertFalse(ProcessCategory.appHelper.isRealServer)
        XCTAssertFalse(ProcessCategory.system.isRealServer)
    }
}
