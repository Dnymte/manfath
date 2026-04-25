import XCTest
@testable import ManfathCore

final class ProcessArgsServiceTests: XCTestCase {

    /// Build a synthetic KERN_PROCARGS2 buffer matching the kernel's
    /// real layout: argc (Int32 LE) + exec path (NUL) + padding NULs +
    /// argv NUL-separated + envp.
    private func buffer(argc: Int32, exec: String, args: [String], env: [String] = []) -> [UInt8] {
        var bytes = [UInt8]()
        withUnsafeBytes(of: argc.littleEndian) { bytes.append(contentsOf: $0) }
        bytes.append(contentsOf: exec.utf8)
        bytes.append(0)
        // align to 8-byte boundary like xnu does
        while bytes.count % 8 != 0 { bytes.append(0) }
        for arg in args {
            bytes.append(contentsOf: arg.utf8)
            bytes.append(0)
        }
        for e in env {
            bytes.append(contentsOf: e.utf8)
            bytes.append(0)
        }
        return bytes
    }

    func testParseExtractsExecAndArgs() {
        let buf = buffer(
            argc: 3,
            exec: "/usr/local/bin/node",
            args: ["node", "server.js", "--port=3000"],
            env: ["PATH=/usr/bin"]
        )
        let result = ProcessArgsService.parse(buffer: buf, length: buf.count)
        XCTAssertEqual(result?.executablePath, "/usr/local/bin/node")
        XCTAssertEqual(result?.arguments, ["node", "server.js", "--port=3000"])
    }

    func testParseStopsAtArgcEvenIfMoreNullsFollow() {
        // env section sits right after argv; we must not consume it.
        let buf = buffer(
            argc: 2,
            exec: "/bin/ruby",
            args: ["ruby", "rails server"],
            env: ["RACK_ENV=development", "BUNDLE_GEMFILE=/Users/me/Gemfile"]
        )
        let result = ProcessArgsService.parse(buffer: buf, length: buf.count)
        XCTAssertEqual(result?.arguments.count, 2)
        XCTAssertFalse(result?.arguments.contains(where: { $0.contains("RACK_ENV") }) ?? true)
    }

    func testParseRejectsTruncatedBuffer() {
        XCTAssertNil(ProcessArgsService.parse(buffer: [0, 0], length: 2))
        XCTAssertNil(ProcessArgsService.parse(buffer: [], length: 0))
    }

    func testParseRejectsZeroArgc() {
        var buf = [UInt8](repeating: 0, count: 8)
        // argc = 0
        XCTAssertNil(ProcessArgsService.parse(buffer: buf, length: buf.count))
        _ = buf.withUnsafeMutableBufferPointer { _ in }
    }

    func testParseHandlesArgWithSpacesAndUnicode() {
        let buf = buffer(
            argc: 2,
            exec: "/Applications/Adobe XD.app/Contents/MacOS/Adobe XD",
            args: ["Adobe XD", "--διαγραφή"]
        )
        let result = ProcessArgsService.parse(buffer: buf, length: buf.count)
        XCTAssertEqual(result?.executablePath, "/Applications/Adobe XD.app/Contents/MacOS/Adobe XD")
        XCTAssertEqual(result?.arguments, ["Adobe XD", "--διαγραφή"])
    }

    /// End-to-end smoke test against the kernel: read this very test
    /// process's argv. We can't predict the exact contents, but we can
    /// assert we got back something non-empty and including the
    /// executable path.
    func testReadCurrentProcessReturnsSomething() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let result = ProcessArgsService.read(pid: pid)
        let r = try XCTUnwrap(result)
        XCTAssertFalse(r.executablePath.isEmpty)
        XCTAssertFalse(r.arguments.isEmpty)
    }
}
