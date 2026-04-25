import XCTest
@testable import ManfathCore

final class LsofParserTests: XCTestCase {

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Fixture loading

    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: name,
                withExtension: "txt",
                subdirectory: "Fixtures"
            ),
            "Missing fixture: Fixtures/\(name).txt"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Typical

    func testTypicalOutputProducesThreePorts() throws {
        let input = try fixture("lsof-typical")
        let ports = LsofParser.parse(input, now: fixedDate)

        XCTAssertEqual(ports.count, 3)

        XCTAssertEqual(ports[0].port, 3000)
        XCTAssertEqual(ports[0].pid, 1234)
        XCTAssertEqual(ports[0].processName, "node")
        XCTAssertEqual(ports[0].user, "user")
        XCTAssertEqual(ports[0].protocolKind, .ipv6)
        XCTAssertEqual(ports[0].firstSeenAt, fixedDate)

        XCTAssertEqual(ports[1].port, 8000)
        XCTAssertEqual(ports[1].pid, 5678)
        XCTAssertEqual(ports[1].processName, "Python")
        XCTAssertEqual(ports[1].protocolKind, .ipv4)

        XCTAssertEqual(ports[2].port, 5432)
        XCTAssertEqual(ports[2].processName, "com.docker.backend")
        XCTAssertEqual(ports[2].user, "root")
    }

    // MARK: - Empty

    func testEmptyInputProducesNoPorts() throws {
        let input = try fixture("lsof-empty")
        let ports = LsofParser.parse(input, now: fixedDate)
        XCTAssertTrue(ports.isEmpty)
    }

    func testWhitespaceOnlyInputProducesNoPorts() {
        let ports = LsofParser.parse("\n\n\n", now: fixedDate)
        XCTAssertTrue(ports.isEmpty)
    }

    // MARK: - IPv6-only

    func testIPv6OnlyNameIsParsedCorrectly() throws {
        let input = try fixture("lsof-ipv6-only")
        let ports = LsofParser.parse(input, now: fixedDate)

        XCTAssertEqual(ports.count, 1)
        XCTAssertEqual(ports[0].port, 3000)
        XCTAssertEqual(ports[0].protocolKind, .ipv6)
    }

    // MARK: - IPv4 + IPv6 merge

    func testSamePidPortWithBothProtocolsMerges() throws {
        let input = try fixture("lsof-both-v4-v6")
        let ports = LsofParser.parse(input, now: fixedDate)

        XCTAssertEqual(ports.count, 1, "Expected merge of IPv4+IPv6 to a single entry")
        XCTAssertEqual(ports[0].port, 3000)
        XCTAssertEqual(ports[0].pid, 1234)
        XCTAssertEqual(ports[0].protocolKind, .both)
    }

    // MARK: - Truncated

    func testTruncatedFileRecordIsSkippedGracefully() throws {
        let input = try fixture("lsof-truncated")
        let ports = LsofParser.parse(input, now: fixedDate)

        XCTAssertTrue(
            ports.isEmpty,
            "A file record missing its 'n' field must be dropped, not crash"
        )
    }

    // MARK: - Unicode command

    func testUnicodeCommandNameIsPreserved() throws {
        let input = try fixture("lsof-unicode-command")
        let ports = LsofParser.parse(input, now: fixedDate)

        XCTAssertEqual(ports.count, 1)
        XCTAssertEqual(ports[0].processName, "منفذ-server")
    }

    // MARK: - Port extraction direct unit tests

    func testExtractPortFromVariousNameShapes() {
        XCTAssertEqual(LsofParser.extractPort(from: "*:3000"), 3000)
        XCTAssertEqual(LsofParser.extractPort(from: "127.0.0.1:8080"), 8080)
        XCTAssertEqual(LsofParser.extractPort(from: "[::1]:5173"), 5173)
        XCTAssertEqual(LsofParser.extractPort(from: "[::]:22"), 22)
        XCTAssertEqual(LsofParser.extractPort(from: "[fe80::1%en0]:3000"), 3000)

        XCTAssertNil(LsofParser.extractPort(from: "no-colons-here"))
        XCTAssertNil(LsofParser.extractPort(from: "*:notanumber"))
        XCTAssertNil(LsofParser.extractPort(from: "*:"))
    }

    // MARK: - Stable identity

    func testIDIsStableAcrossParsesForSamePidPortProto() throws {
        let input = try fixture("lsof-typical")
        let a = LsofParser.parse(input, now: fixedDate)
        let b = LsofParser.parse(input, now: fixedDate.addingTimeInterval(10))

        XCTAssertEqual(a.map(\.id), b.map(\.id))
    }
}
