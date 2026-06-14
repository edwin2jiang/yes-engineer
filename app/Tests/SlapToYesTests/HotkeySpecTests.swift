import XCTest
@testable import SlapToYes

final class HotkeySpecTests: XCTestCase {
    func testParsesDisplayedSymbolHotkeys() {
        XCTAssertEqual(HotkeySpec.parse("⌥⇧↩"), .confirm)
        XCTAssertEqual(HotkeySpec.parse("⌥⇧Y"), .yes)
        XCTAssertEqual(HotkeySpec.parse("⇧⌥C"), .continuePrompt)
    }

    func testParsesTextAliasesAsWholeTokens() {
        XCTAssertEqual(HotkeySpec.parse("option+shift+y"), .yes)
        XCTAssertEqual(HotkeySpec.parse("opt-shift-y"), .yes)
        XCTAssertEqual(HotkeySpec.parse("alt shift y"), .yes)
        XCTAssertEqual(HotkeySpec.parse("control+option+return"),
                       HotkeySpec(keyCode: 0x24,
                                  modifiers: HotkeyModifier.control | HotkeyModifier.option))
    }

}
