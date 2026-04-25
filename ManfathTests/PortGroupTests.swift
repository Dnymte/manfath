import XCTest
@testable import ManfathCore

final class PortGroupTests: XCTestCase {

    func testRangeNormalizesReversedBounds() {
        let r = PortRange(min: 8000, max: 3000)
        XCTAssertEqual(r.min, 3000)
        XCTAssertEqual(r.max, 8000)
    }

    func testRangeContainsIsInclusive() {
        let r = PortRange(min: 3000, max: 4000)
        XCTAssertTrue(r.contains(3000))
        XCTAssertTrue(r.contains(4000))
        XCTAssertTrue(r.contains(3500))
        XCTAssertFalse(r.contains(2999))
        XCTAssertFalse(r.contains(4001))
    }

    func testGroupContainsExactPort() {
        let g = PortGroup(name: "Frontend", ports: [3000, 5173], ranges: [])
        XCTAssertTrue(g.contains(3000))
        XCTAssertTrue(g.contains(5173))
        XCTAssertFalse(g.contains(8080))
    }

    func testGroupContainsViaRange() {
        let g = PortGroup(
            name: "App",
            ports: [],
            ranges: [PortRange(min: 8000, max: 8999)]
        )
        XCTAssertTrue(g.contains(8000))
        XCTAssertTrue(g.contains(8500))
        XCTAssertTrue(g.contains(8999))
        XCTAssertFalse(g.contains(7999))
    }

    func testGroupContainsCombinesPortsAndRanges() {
        let g = PortGroup(
            name: "Mixed",
            ports: [3000],
            ranges: [PortRange(min: 5000, max: 5999)]
        )
        XCTAssertTrue(g.contains(3000))
        XCTAssertTrue(g.contains(5500))
        XCTAssertFalse(g.contains(4000))
    }

    func testGroupRoundtripsThroughCodable() throws {
        let g = PortGroup(
            name: "Frontend",
            ports: [3000, 5173],
            ranges: [PortRange(min: 8000, max: 8999)]
        )
        let data = try JSONEncoder().encode([g])
        let back = try JSONDecoder().decode([PortGroup].self, from: data)
        XCTAssertEqual(back, [g])
    }
}
