import XCTest
@testable import ManfathCore

final class ProcessControllerTests: XCTestCase {

    // MARK: - Inspect

    func testInspectAgainstSelfReturnsDetails() async throws {
        let controller = ProcessController()
        let selfPid = getpid()

        let details = try await controller.inspect(pid: selfPid)

        XCTAssertEqual(details.pid, selfPid)
        XCTAssertGreaterThan(
            details.openFileCount, 0,
            "Self has at least stdin/stdout/stderr open"
        )
        // commandPath and workingDirectory should resolve for ourselves,
        // though their exact values vary by how the test bundle is run.
        XCTAssertNotNil(details.workingDirectory)
    }

    // MARK: - Kill

    func testKillNonexistentPidReturnsNotFound() async {
        let controller = ProcessController()
        // PIDs are 32-bit on macOS; 2^31-1 is essentially guaranteed unused.
        let result = await controller.kill(pid: Int32.max)

        XCTAssertEqual(result, .notFound)
    }

    // MARK: - Parser (pure)

    func testParseInspectOutputExtractsCwdAndTxt() {
        let sample = """
        p1234
        ccmd
        fcwd
        n/Users/me/project
        ftxt
        n/usr/bin/swift
        f3
        tCHR
        n/dev/ttys000
        f4
        tIPv4
        n127.0.0.1:1234
        """

        let details = ProcessController.parseInspectOutput(sample, pid: 1234)

        XCTAssertEqual(details.pid, 1234)
        XCTAssertEqual(details.workingDirectory, "/Users/me/project")
        XCTAssertEqual(details.commandPath, "/usr/bin/swift")
        XCTAssertEqual(details.openFileCount, 4)
    }

    func testParseInspectOutputHandlesEmptyOutput() {
        let details = ProcessController.parseInspectOutput("", pid: 99)
        XCTAssertEqual(details.pid, 99)
        XCTAssertNil(details.workingDirectory)
        XCTAssertNil(details.commandPath)
        XCTAssertEqual(details.openFileCount, 0)
    }
}
