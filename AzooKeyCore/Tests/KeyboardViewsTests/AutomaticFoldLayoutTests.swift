import Combine
import CustardKit
import KanaKanjiConverterModule
@testable import KeyboardViews
import XCTest

@MainActor
final class AutomaticFoldLayoutTests: XCTestCase {
    private struct Custards: CustardManagerProtocol {
        func custard(identifier: String) throws -> Custard { .errorMessage }
        func tabbar(identifier: Int) throws -> TabBarData { throw CocoaError(.fileNoSuchFile) }
    }

    private struct Tabs: TabManagerConfiguration {
        var japaneseLayout: LanguageLayout = .flick
        var englishLayout: LanguageLayout = .qwerty
        var custardManager: any CustardManagerProtocol { Custards() }
    }

    private struct Clipboard: ClipboardHistoryManagerConfiguration {
        var enabled: Bool { false }
        var saveDirectory: URL? { nil }
        var maxCount: Int { 0 }
    }

    private func states(japaneseLayout: LanguageLayout = .flick) -> VariableStates {
        let defaults = UserDefaults(suiteName: "AutomaticFoldLayoutTests.\(UUID().uuidString)")!
        return VariableStates(
            clipboardHistoryManagerConfig: Clipboard(),
            tabManagerConfig: Tabs(japaneseLayout: japaneseLayout),
            userDefaults: defaults,
            layoutIdiom: .phone
        )
    }

    func testCoverDisplayStaysFlickInEitherOrientation() {
        for size in [CGSize(width: 466, height: 678), CGSize(width: 678, height: 466)] {
            XCTAssertEqual(DuoKeyboardLayout.layout(screenSize: size, modelIdentifier: "iPhone19,4"), .flick)
        }
    }

    func testInnerDisplayStaysQwertyInEitherOrientation() {
        for size in [CGSize(width: 669, height: 951), CGSize(width: 951, height: 669)] {
            XCTAssertEqual(DuoKeyboardLayout.layout(screenSize: size, modelIdentifier: "iPhone19,4"), .qwerty)
        }
    }

    func testOtherDevicesDoNotGetAnOverride() {
        for model in ["iPhone19,2", "iPad16,1", "unknown"] {
            XCTAssertNil(DuoKeyboardLayout.layout(screenSize: CGSize(width: 669, height: 951), modelIdentifier: model))
        }
    }

    func testMissingAndInvalidDisplaySizesDoNotMeanClosed() {
        for size in [CGSize.zero, CGSize(width: -1, height: 951), CGSize(width: CGFloat.infinity, height: 951), CGSize(width: CGFloat.nan, height: 951)] {
            XCTAssertNil(DuoKeyboardLayout.layout(screenSize: size, modelIdentifier: "iPhone19,4"))
        }
    }

    func testRepeatedLayoutPassDoesNotPublishAnotherUpdate() {
        let state = states()
        state.setAutomaticJapaneseLayout(.qwerty)
        var updates = 0
        let subscription = state.objectWillChange.sink { updates += 1 }
        state.setAutomaticJapaneseLayout(.qwerty)
        XCTAssertEqual(updates, 0)
        withExtendedLifetime(subscription) {}
    }

    func testOpenCloseAndDisableRestoreSavedLayout() {
        let state = states(japaneseLayout: .qwerty)
        state.initialize()
        state.setAutomaticJapaneseLayout(.flick)
        XCTAssertEqual(state.tabManager.existentialTab(), .flick_hira)
        XCTAssertEqual(state.inputStyle, .direct)
        state.setAutomaticJapaneseLayout(.qwerty)
        XCTAssertEqual(state.tabManager.existentialTab(), .qwerty_hira)
        XCTAssertEqual(state.inputStyle, .roman2kana)
        state.setAutomaticJapaneseLayout(.flick)
        state.setAutomaticJapaneseLayout(nil)
        XCTAssertEqual(state.tabManager.existentialTab(), .qwerty_hira)
        XCTAssertEqual(state.inputStyle, .roman2kana)
    }

    func testNumbersRemainVisibleAndReturnToNewJapaneseLayout() {
        let state = states()
        state.initialize()
        state.setTab(.system(.flick_numbersymbols))
        state.setAutomaticJapaneseLayout(.qwerty)
        XCTAssertEqual(state.tabManager.existentialTab(), .flick_numbersymbols)
        state.setTab(.system(.last_tab))
        XCTAssertEqual(state.tabManager.existentialTab(), .qwerty_hira)
        XCTAssertEqual(state.inputStyle, .roman2kana)
        state.setAutomaticJapaneseLayout(nil)
        XCTAssertEqual(state.tabManager.existentialTab(), .flick_hira)
    }

    func testEmojiAndEnglishAreNotReplacedByJapanese() {
        let state = states()
        state.setTab(.system(.emoji_tab))
        state.setAutomaticJapaneseLayout(.qwerty)
        guard case .special(.emoji) = state.tabManager.existentialTab() else {
            return XCTFail("Opening must not dismiss the emoji tab")
        }
        state.setTab(.system(.user_english))
        state.setAutomaticJapaneseLayout(.flick)
        XCTAssertEqual(state.tabManager.existentialTab(), .qwerty_abc)
        state.setTab(.system(.user_japanese))
        XCTAssertEqual(state.tabManager.existentialTab(), .flick_hira)
    }

    func testExplicitJapaneseTabsAndReinitializationRespectPosture() {
        let state = states()
        state.setAutomaticJapaneseLayout(.qwerty)
        state.setTab(.system(.flick_japanese))
        XCTAssertEqual(state.tabManager.existentialTab(), .qwerty_hira)
        XCTAssertEqual(state.inputStyle, .roman2kana)
        state.closeKeyboard()
        state.initialize()
        XCTAssertEqual(state.tabManager.existentialTab(), .qwerty_hira)
        XCTAssertEqual(state.inputStyle, .roman2kana)
        state.setAutomaticJapaneseLayout(.flick)
        state.setTab(.system(.qwerty_japanese))
        XCTAssertEqual(state.tabManager.existentialTab(), .flick_hira)
        XCTAssertEqual(state.inputStyle, .direct)
    }

    func testTemporaryNumberPadSurvivesOpenClose() {
        let state = states()
        state.initialize()
        state.setKeyboardType(.numberPad)
        state.setAutomaticJapaneseLayout(.qwerty)
        XCTAssertEqual(state.tabManager.existentialTab(), .custard(.numberPad))
        state.setAutomaticJapaneseLayout(.flick)
        XCTAssertEqual(state.tabManager.existentialTab(), .custard(.numberPad))
        state.setTab(.system(.user_japanese))
        XCTAssertEqual(state.tabManager.existentialTab(), .flick_hira)
    }

    func testCompositionCanContinueAcrossBothInputStyles() {
        let state = states()
        state.initialize()
        var composingText = ComposingText()
        composingText.insertAtCursorPosition("にほん", inputStyle: state.inputStyle)
        state.setAutomaticJapaneseLayout(.qwerty)
        composingText.insertAtCursorPosition("go", inputStyle: state.inputStyle)
        XCTAssertEqual(composingText.convertTarget, "にほんご")
        state.setAutomaticJapaneseLayout(.flick)
        composingText.insertAtCursorPosition("です", inputStyle: state.inputStyle)
        XCTAssertEqual(composingText.convertTarget, "にほんごです")
    }

    func testUnfinishedRomanSyllableIsNotLostOnClose() {
        let state = states()
        state.setAutomaticJapaneseLayout(.qwerty)
        var composingText = ComposingText()
        composingText.insertAtCursorPosition("nihonk", inputStyle: state.inputStyle)
        let before = composingText.convertTarget
        state.setAutomaticJapaneseLayout(.flick)
        composingText.insertAtCursorPosition("あ", inputStyle: state.inputStyle)
        XCTAssertEqual(composingText.convertTarget, before + "あ")
    }
}
