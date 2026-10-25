import AzooKeyUtils
import CustardKit
@testable import KeyboardViews
import SwiftUI
import SwiftUIUtils
import UIKit
import XCTest

@available(iOS 27.0, *)
@MainActor
final class CandidateHitTestingTests: XCTestCase {
    private struct Custards: CustardManagerProtocol {
        func custard(identifier: String) throws -> Custard { .errorMessage }
        func tabbar(identifier: Int) throws -> TabBarData { throw CocoaError(.fileNoSuchFile) }
    }
    private struct Tabs: TabManagerConfiguration {
        var japaneseLayout: LanguageLayout = .qwerty
        var englishLayout: LanguageLayout = .qwerty
        var custardManager: any CustardManagerProtocol { Custards() }
    }
    private struct Clipboard: ClipboardHistoryManagerConfiguration {
        var enabled: Bool { false }
        var saveDirectory: URL? { nil }
        var maxCount: Int { 0 }
    }
    private enum Messages: ApplicationSpecificKeyboardViewMessageProvider {
        typealias MessageID = AzooKeyMessageProvider.MessageID
        static var messages: [MessageData<MessageID>] { [] }
        static var userDefaults: UserDefaults { .standard }
    }
    private enum Extension: ApplicationSpecificKeyboardViewExtension {
        typealias ThemeExtension = AzooKeySpecificTheme
        typealias SettingProvider = AzooKeySettingProvider
        typealias MessageProvider = Messages
    }
    private struct Candidate: ResultViewItemData {
        var text = "日本語"
        var label: ResultViewItemLabelStyle { .text(text) }
        var inputable: Bool { true }
        func getDebugInformation() -> String { "test" }
    }

    private final class Actions: UserActionManager, @unchecked Sendable {
        var completed: [String] = []
        override func notifyComplete(_ candidate: any ResultViewItemData, variableStates: VariableStates) {
            completed.append(candidate.textualRepresentation ?? "")
        }
    }

    func testCandidateButtonReceivesTapAndUsesCurrentCandidate() async throws {
        let defaults = UserDefaults(suiteName: "CandidateHitTestingTests")!
        defaults.removePersistentDomain(forName: "CandidateHitTestingTests")
        defer { defaults.removePersistentDomain(forName: "CandidateHitTestingTests") }
        let state = VariableStates(clipboardHistoryManagerConfig: Clipboard(), tabManagerConfig: Tabs(), userDefaults: defaults, layoutIdiom: .phone)
        state.setContainerWidth(669, orientation: .vertical)
        state.initialize()
        state.resultModel.setResults([Candidate()])
        let actions = Actions()
        let content = KeyboardView<Extension>()
            .environmentObject(state)
            .themeEnvironment(AzooKeySpecificTheme.default)
            .environment(\.showMessage, false)
            .environment(\.userActionManager, actions)
            .ignoresSafeArea()
        let host = UIHostingController(rootView: content)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 669, height: state.interfaceSize.height + Design.keyboardScreenBottomPadding))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(200))

        func buttons(_ view: UIView) -> [NativeResultButton.TouchSurface] {
            var found: [NativeResultButton.TouchSurface] = []
            if let button = view as? NativeResultButton.TouchSurface { found.append(button) }
            return found + view.subviews.flatMap { buttons($0) }
        }
        func isInsideScrollView(_ view: UIView) -> Bool {
            guard let parent = view.superview else { return false }
            return parent is UIScrollView || isInsideScrollView(parent)
        }
        func candidateButton() throws -> NativeResultButton.TouchSurface {
            let candidates = buttons(host.view).filter { isInsideScrollView($0) }
            XCTAssertEqual(candidates.count, 1)
            return try XCTUnwrap(candidates.first)
        }
        // Package tests have no UIApplication to dispatch UIControl actions.
        // Invoke the registered targets so wiring and SwiftUI's trigger are still tested.
        func dispatch(_ button: UIButton, for event: UIControl.Event) {
            var count = 0
            for target in button.allTargets {
                for action in button.actions(forTarget: target, forControlEvent: event) ?? [] {
                    _ = (target as? NSObject)?.perform(NSSelectorFromString(action))
                    count += 1
                }
            }
            XCTAssertGreaterThan(count, 0)
        }
        let button = try candidateButton()
        XCTAssertGreaterThan(button.bounds.width, 0)
        XCTAssertGreaterThan(button.bounds.height, 0)
        let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: host.view)
        XCTAssertTrue(host.view.hitTest(center, with: nil) === button, "The candidate must receive taps instead of a key/overlay")
        dispatch(button, for: .touchUpInside)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(actions.completed, ["日本語"])
        // Cancelling a press for a scroll or a context menu must not select it.
        dispatch(button, for: .touchDown)
        dispatch(button, for: .touchCancel)
        XCTAssertEqual(actions.completed, ["日本語"])

        state.resultModel.setResults([Candidate(text: "更新後")])
        try await Task.sleep(for: .milliseconds(200))
        let updated = try candidateButton()
        dispatch(updated, for: .touchUpInside)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(actions.completed, ["日本語", "更新後"])
        updated.isEnabled = false
        dispatch(updated, for: .touchUpInside)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(actions.completed, ["日本語", "更新後"])
    }
}
