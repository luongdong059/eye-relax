import XCTest
@testable import EyeRelaxCore

final class AppVersionTests: XCTestCase {

    func testParsing() {
        XCTAssertEqual(AppVersion("1.2.3"), AppVersion(major: 1, minor: 2, patch: 3))
        XCTAssertEqual(AppVersion("v1.2.3"), AppVersion(major: 1, minor: 2, patch: 3))
        XCTAssertEqual(AppVersion("V0.1.0"), AppVersion(major: 0, minor: 1, patch: 0))
        XCTAssertEqual(AppVersion("1.2"), AppVersion(major: 1, minor: 2, patch: 0))
        XCTAssertEqual(AppVersion("2"), AppVersion(major: 2, minor: 0, patch: 0))
        XCTAssertEqual(AppVersion("1.2.3-beta.1"), AppVersion(major: 1, minor: 2, patch: 3))
        XCTAssertEqual(AppVersion(" v1.0.0 "), AppVersion(major: 1, minor: 0, patch: 0))
    }

    func testInvalidStrings() {
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("abc"))
        XCTAssertNil(AppVersion("1.x.3"))
        XCTAssertNil(AppVersion("1.2.3.4"))
        XCTAssertNil(AppVersion("-1.0.0"))
        XCTAssertNil(AppVersion("v"))
    }

    func testComparison() {
        XCTAssertLessThan(AppVersion("0.1.0")!, AppVersion("0.1.1")!)
        XCTAssertLessThan(AppVersion("0.9.9")!, AppVersion("1.0.0")!)
        XCTAssertLessThan(AppVersion("1.2.3")!, AppVersion("1.10.0")!)
        XCTAssertGreaterThan(AppVersion("2.0.0")!, AppVersion("1.99.99")!)
        XCTAssertEqual(AppVersion("v1.2.3")!, AppVersion("1.2.3")!)
        XCTAssertFalse(AppVersion("1.0.0")! < AppVersion("1.0.0")!)
    }

    func testDescription() {
        XCTAssertEqual(AppVersion("v1.2")!.description, "1.2.0")
    }
}
