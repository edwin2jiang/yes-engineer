import XCTest
@testable import SlapToYes

final class AppConfigTests: XCTestCase {
    func testDefaultSlapActionInputsYesAndPressesReturn() {
        let config = AppConfig()
        let action = config.action(id: config.slapActionID)

        XCTAssertEqual(config.slapActionID, TextAction.defaultSlapActionID)
        XCTAssertEqual(action.input, "yes")
        XCTAssertTrue(action.autoPressReturn)
    }

    func testAccessibilityPromptingDefaultsToEnabled() throws {
        XCTAssertTrue(AppConfig().autoRequestAccessibility)

        let decoded = try JSONDecoder().decode(AppConfig.self, from: Data("{}".utf8))
        XCTAssertTrue(decoded.autoRequestAccessibility)
    }

    func testAccessibilityPromptingCanBeDisabled() throws {
        let data = Data(#"{"autoRequestAccessibility":false}"#.utf8)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertFalse(decoded.autoRequestAccessibility)
    }
}
