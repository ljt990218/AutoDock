import Foundation
import XCTest

final class RuleEngineTests: XCTestCase {
    private let engine = RuleEngine()

    func testSingleMatchingRuleApplies() {
        let monitor = display(id: 1, serial: 10)
        let rule = rule(for: monitor, position: .right)
        XCTAssertEqual(evaluate([monitor], [rule]), .apply(position: .right, ruleID: rule.id))
    }

    func testHighestPriorityWins() {
        let company = display(id: 1, serial: 10)
        let home = display(id: 2, serial: 20)
        let low = rule(for: company, position: .right, priority: -1)
        let high = rule(for: home, position: .left, priority: 2)
        XCTAssertEqual(evaluate([company, home], [low, high]), .apply(position: .left, ruleID: high.id))
    }

    func testEqualHighestPriorityKeepsPositionEvenWhenTargetsAgree() {
        let first = display(id: 1, serial: 10)
        let second = display(id: 2, serial: 20)
        let a = rule(for: first, position: .left)
        let b = rule(for: second, position: .left)
        let ids = [a.id, b.id].sorted { $0.uuidString < $1.uuidString }
        XCTAssertEqual(evaluate([first, second], [a, b]), .keep(.priorityConflict(ids)))
    }

    func testLowerPriorityTieDoesNotBlockUniqueWinner() {
        let a = display(id: 1, serial: 10)
        let b = display(id: 2, serial: 20)
        let c = display(id: 3, serial: 30)
        let winner = rule(for: c, position: .bottom, priority: 5)
        XCTAssertEqual(
            evaluate([a, b, c], [rule(for: a), rule(for: b), winner]),
            .apply(position: .bottom, ruleID: winner.id)
        )
    }

    func testUnknownDisplayKeepsPosition() {
        XCTAssertEqual(evaluate([display(id: 1, serial: 10)], []), .keep(.unknownDisplay))
    }

    func testUnknownDisplayDoesNotBlockKnownRule() {
        let known = display(id: 1, serial: 10)
        let unknown = display(id: 2, serial: 20)
        let saved = rule(for: known)
        XCTAssertEqual(evaluate([known, unknown], [saved]), .apply(position: .left, ruleID: saved.id))
    }

    func testDisabledRuleDoesNotApply() {
        let monitor = display(id: 1, serial: 10)
        var disabled = rule(for: monitor)
        disabled.enabled = false
        XCTAssertEqual(evaluate([monitor], [disabled]), .keep(.unknownDisplay))
    }

    func testBuiltInDisplayUsesNoExternalSetting() {
        let builtIn = display(id: 1, serial: 10, builtIn: true)
        var settings = AppSettings()
        settings.noExternalDisplayAction = .bottom
        XCTAssertEqual(
            engine.evaluate(displays: [builtIn], rules: [rule(for: builtIn)], settings: settings),
            .apply(position: .bottom, ruleID: nil)
        )
    }

    func testNoExternalDisplayKeepIsDefault() {
        XCTAssertEqual(evaluate([], []), .keep(.noExternalDisplays))
    }

    func testAllExplicitNoExternalPositions() {
        for action in [NoExternalDisplayAction.left, .bottom, .right] {
            var settings = AppSettings()
            settings.noExternalDisplayAction = action
            XCTAssertEqual(
                engine.evaluate(displays: [], rules: [], settings: settings),
                .apply(position: action.position!, ruleID: nil)
            )
        }
    }

    func testMonitoringDisabledPreventsAllAutomaticActions() {
        var settings = AppSettings()
        settings.monitoringEnabled = false
        settings.noExternalDisplayAction = .left
        XCTAssertEqual(
            engine.evaluate(displays: [], rules: [], settings: settings),
            .keep(.monitoringDisabled)
        )
    }

    func testDuplicatePhysicalIdentitiesDoNotGuessBySessionID() {
        let first = display(id: 1, serial: 10)
        let second = display(id: 2, serial: 10)
        XCTAssertEqual(evaluate([first, second], [rule(for: first)]), .keep(.ambiguousIdentity))
    }

    func testMirrorWithSeparateIdentityDoesNotDuplicateSingleRule() {
        let first = display(id: 1, serial: 10)
        var mirrored = display(id: 2, serial: 20)
        mirrored = DetectedDisplay(
            id: mirrored.id,
            identity: mirrored.identity,
            isBuiltIn: false,
            mirrorsDisplayID: first.id
        )
        let saved = rule(for: first)
        XCTAssertEqual(evaluate([first, mirrored], [saved]), .apply(position: .left, ruleID: saved.id))
    }

    private func evaluate(_ displays: [DetectedDisplay], _ rules: [DisplayRule]) -> RuleDecision {
        engine.evaluate(displays: displays, rules: rules, settings: AppSettings())
    }

    private func display(id: UInt32, serial: UInt32, builtIn: Bool = false) -> DetectedDisplay {
        DetectedDisplay(
            id: id,
            identity: DisplayIdentity(
                cgDisplayID: id,
                vendorID: 100,
                productID: 200,
                serialNumber: serial,
                displayUUID: nil,
                displayName: "显示器 \(serial)"
            ),
            isBuiltIn: builtIn,
            mirrorsDisplayID: nil
        )
    }

    private func rule(
        for display: DetectedDisplay,
        position: DockPosition = .left,
        priority: Int = 0
    ) -> DisplayRule {
        DisplayRule(
            displayIdentity: display.identity,
            displayName: display.name,
            dockPosition: position,
            priority: priority
        )
    }
}
