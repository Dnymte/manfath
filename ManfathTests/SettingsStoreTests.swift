import XCTest
@testable import ManfathCore

@MainActor
final class SettingsStoreTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "manfath-test-\(UUID().uuidString)")!
    }

    // MARK: - Defaults

    func testDefaultsAreSensible() {
        let defaults = makeDefaults()
        let settings = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(settings.refreshInterval, .s3)
        XCTAssertEqual(settings.minPort, 1024)
        XCTAssertEqual(settings.processBlocklist, ["rapportd", "ControlCenter"])
        XCTAssertEqual(settings.appearance, .system)
        XCTAssertEqual(settings.badgeMode, .count)
    }

    // MARK: - Round-trip

    func testRefreshIntervalPersists() {
        let defaults = makeDefaults()
        let first = SettingsStore(userDefaults: defaults)
        first.refreshInterval = .s10

        let second = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(second.refreshInterval, .s10)
    }

    func testMinPortPersists() {
        let defaults = makeDefaults()
        let first = SettingsStore(userDefaults: defaults)
        first.minPort = 3000

        let second = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(second.minPort, 3000)
    }

    func testBlocklistPersists() {
        let defaults = makeDefaults()
        let first = SettingsStore(userDefaults: defaults)
        first.processBlocklist = ["foo", "bar", "baz"]

        let second = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(second.processBlocklist, ["foo", "bar", "baz"])
    }

    func testAppearancePersists() {
        let defaults = makeDefaults()
        let first = SettingsStore(userDefaults: defaults)
        first.appearance = .dark

        let second = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(second.appearance, .dark)
    }

    func testBadgeModePersists() {
        let defaults = makeDefaults()
        let first = SettingsStore(userDefaults: defaults)
        first.badgeMode = .dot

        let second = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(second.badgeMode, .dot)
    }

    // MARK: - Enum labels sanity

    func testAllRefreshIntervalsHaveLabels() {
        for interval in RefreshInterval.allCases {
            XCTAssertFalse(interval.label.isEmpty)
        }
    }

    func testManualIntervalIsNotAutomatic() {
        XCTAssertFalse(RefreshInterval.manual.isAutomatic)
        XCTAssertTrue(RefreshInterval.s3.isAutomatic)
    }

    // MARK: - Convenience init

    func testConvenienceInitUsesEphemeralDefaults() {
        let settings = SettingsStore(minPort: 5000, processBlocklist: ["a"])
        XCTAssertEqual(settings.minPort, 5000)
        XCTAssertEqual(settings.processBlocklist, ["a"])
        // Must not have touched .standard
        XCTAssertNotEqual(
            UserDefaults.standard.object(forKey: "manfath.minPort") as? Int,
            5000
        )
    }
}
