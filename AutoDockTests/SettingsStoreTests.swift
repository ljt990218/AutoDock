import Foundation
import XCTest

final class SettingsStoreTests: XCTestCase {
    @MainActor
    func testRulesAndSettingsRoundTrip() throws {
        let suite = "AutoDockTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        let identity = DisplayIdentity(
            vendorID: 100, productID: 200, serialNumber: 10,
            displayUUID: nil, displayName: "公司显示器"
        )
        let rule = DisplayRule(displayIdentity: identity, displayName: "公司", dockPosition: .right)
        var settings = AppSettings()
        settings.noExternalDisplayAction = .left
        try store.save(rules: [rule], settings: settings)

        let loaded = try SettingsStore(defaults: defaults).load()
        XCTAssertEqual(loaded.rules, [rule])
        XCTAssertEqual(loaded.settings, settings)
    }

    @MainActor
    func testInvalidDataIsPreservedAndCannotBeOverwritten() throws {
        let suite = "AutoDockTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = Data("invalid json".utf8)
        defaults.set(original, forKey: "displayRules")
        let store = SettingsStore(defaults: defaults)

        XCTAssertThrowsError(try store.load())
        XCTAssertTrue(store.isBlocked)
        XCTAssertThrowsError(try store.save(rules: [], settings: AppSettings()))
        XCTAssertEqual(defaults.data(forKey: "displayRules"), original)
    }

    @MainActor
    func testExplicitResetRestoresDefaults() throws {
        let suite = "AutoDockTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("wrong type", forKey: "appSettings")
        let store = SettingsStore(defaults: defaults)
        XCTAssertThrowsError(try store.load())

        store.reset()
        let loaded = try store.load()
        XCTAssertEqual(loaded.rules, [])
        XCTAssertEqual(loaded.settings, AppSettings())
    }
}
