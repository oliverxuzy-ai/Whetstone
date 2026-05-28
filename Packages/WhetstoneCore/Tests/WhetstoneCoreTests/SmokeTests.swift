// Tests/WhetstoneCoreTests/SmokeTests.swift
import XCTest
@testable import WhetstoneCore

final class SmokeTests: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(WhetstoneCore.version, "0.1.0")
    }
}
