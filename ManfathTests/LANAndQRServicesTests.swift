import XCTest
@testable import ManfathCore

final class LANAddressServiceTests: XCTestCase {

    func testIsPreferredInterfaceRecognizesEnAndBridge() {
        XCTAssertTrue(LANAddressService.isPreferredInterface("en0"))
        XCTAssertTrue(LANAddressService.isPreferredInterface("en1"))
        XCTAssertTrue(LANAddressService.isPreferredInterface("bridge100"))

        XCTAssertFalse(LANAddressService.isPreferredInterface("lo0"))
        XCTAssertFalse(LANAddressService.isPreferredInterface("utun0"))
        XCTAssertFalse(LANAddressService.isPreferredInterface("awdl0"))
        XCTAssertFalse(LANAddressService.isPreferredInterface("llw0"))
    }

    func testIsRoutableRejectsLoopbackAndLinkLocal() {
        XCTAssertTrue(LANAddressService.isRoutable("192.168.1.42"))
        XCTAssertTrue(LANAddressService.isRoutable("10.0.0.1"))
        XCTAssertTrue(LANAddressService.isRoutable("172.16.0.1"))

        XCTAssertFalse(LANAddressService.isRoutable("127.0.0.1"))
        XCTAssertFalse(LANAddressService.isRoutable("127.42.1.1"))
        XCTAssertFalse(LANAddressService.isRoutable("169.254.99.1"))
        XCTAssertFalse(LANAddressService.isRoutable(""))
    }

    /// Smoke test: on any developer machine with Wi-Fi/Ethernet, this
    /// should return something. Skipped with an informative message if
    /// the test host is off-network rather than failing the suite.
    func testPrimaryIPv4SmokeTest() {
        let ip = LANAddressService.primaryIPv4()
        if let ip {
            XCTAssertTrue(LANAddressService.isRoutable(ip), "Got non-routable IP: \(ip)")
        } else {
            // Not a failure — CI runners often have no LAN.
            print("LAN smoke test: no IP found (off-network?)")
        }
    }
}

final class QRCodeServiceTests: XCTestCase {

    func testGeneratesImageForSimpleString() {
        let image = QRCodeService.generate(from: "http://192.168.1.42:3000", size: 160)
        XCTAssertNotNil(image)
        XCTAssertGreaterThan(image!.size.width, 0)
        XCTAssertGreaterThan(image!.size.height, 0)
    }

    func testGeneratesImageForEmptyString() {
        // CIFilter QR accepts empty input and produces a valid (if
        // content-free) code. We just want no crash and a non-nil image.
        let image = QRCodeService.generate(from: "", size: 120)
        XCTAssertNotNil(image)
    }

    func testGeneratesImageForUnicodeString() {
        let image = QRCodeService.generate(from: "منفذ 3000 · test", size: 120)
        XCTAssertNotNil(image)
    }

    func testRespectsRequestedSize() {
        let small = QRCodeService.generate(from: "localhost:3000", size: 60)
        let large = QRCodeService.generate(from: "localhost:3000", size: 240)
        XCTAssertNotNil(small)
        XCTAssertNotNil(large)
        XCTAssertGreaterThan(large!.size.width, small!.size.width)
    }
}
