import Foundation
import XCTest

final class DisplayIdentityTests: XCTestCase {
    func testSerialSurvivesSessionAndNameChanges() {
        var original = identity(serial: 12, name: "公司显示器")
        original.cgDisplayID = 1
        var reconnected = identity(serial: 12, name: "不同的系统名称")
        reconnected.cgDisplayID = 99
        reconnected.displayUUID = "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"
        XCTAssertTrue(original.matches(reconnected))
    }

    func testSameModelWithDifferentSerialNumbersDoesNotMatch() {
        XCTAssertFalse(identity(serial: 1).matches(identity(serial: 2)))
    }

    func testSerialRequiresMatchingVendorAndProduct() {
        var other = identity(serial: 12)
        other.vendorID = 200
        XCTAssertFalse(identity(serial: 12).matches(other))
        other = identity(serial: 12)
        other.productID = 300
        XCTAssertFalse(identity(serial: 12).matches(other))
    }

    func testMissingSerialUsesUUIDWithoutRequiringName() {
        var original = identity(serial: nil, name: nil)
        var other = original
        original.displayUUID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        other.displayUUID = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        XCTAssertTrue(original.matches(other))
    }

    func testInvalidSerialUsesUUID() {
        XCTAssertTrue(identity(serial: 0).matches(identity(serial: UInt32.max)))
    }

    func testStrongIdentityDoesNotDowngradeToName() {
        var weak = identity(serial: nil)
        weak.displayUUID = nil
        XCTAssertFalse(identity(serial: 12).matches(weak))
    }

    func testNameFallbackOnlyUsesDocumentedCombination() {
        var original = identity(serial: nil, name: "同型号显示器")
        original.displayUUID = nil
        var other = original
        other.cgDisplayID = 100
        XCTAssertTrue(original.matches(other))
        other.displayName = "另一名称"
        XCTAssertFalse(original.matches(other))
    }

    func testNoIdentityNeverMatchesAnotherUnknownDisplay() {
        let unknown = DisplayIdentity(
            vendorID: 0,
            productID: 0,
            serialNumber: nil,
            displayUUID: nil,
            displayName: "未提供名称的外接显示器"
        )
        XCTAssertNil(unknown.matchKey)
        XCTAssertFalse(unknown.matches(unknown))
    }

    func testSessionIDIsNotPersisted() throws {
        var original = identity(serial: 12)
        original.cgDisplayID = 77
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DisplayIdentity.self, from: data)
        XCTAssertNil(decoded.cgDisplayID)
        XCTAssertTrue(decoded.matches(original))
    }

    func testAllZeroUUIDCannotIdentifyDevice() {
        var original = identity(serial: nil, name: nil)
        original.displayUUID = "00000000-0000-0000-0000-000000000000"
        XCTAssertNil(original.matchKey)
    }

    private func identity(serial: UInt32?, name: String? = "显示器") -> DisplayIdentity {
        DisplayIdentity(
            vendorID: 100,
            productID: 200,
            serialNumber: serial,
            displayUUID: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            displayName: name
        )
    }
}
