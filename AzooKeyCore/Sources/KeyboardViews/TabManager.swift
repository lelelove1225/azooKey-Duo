//
//  TabManager.swift
//  azooKey
//
//  Created by ensan on 2021/02/20.
//  Copyright © 2021 ensan. All rights reserved.
//

import CustardKit
import Foundation
import enum KanaKanjiConverterModule.InputStyle
import enum KanaKanjiConverterModule.KeyboardLanguage
import SwiftUI

extension TabData {
    func tab(config: any TabManagerConfiguration) -> KeyboardTab {
        switch self {
        case let .system(tab):
            switch tab {
            case .flick_japanese:
                return .existential(.flick_hira)
            case .flick_english:
                return .existential(.flick_abc)
            case .flick_numbersymbols:
                return .existential(.flick_numbersymbols)
            case .qwerty_japanese:
                return .existential(.qwerty_hira)
            case .qwerty_english:
                return .existential(.qwerty_abc)
            case .qwerty_numbers:
                return .existential(.qwerty_numbers)
            case .qwerty_symbols:
                return .existential(.qwerty_symbols)
            case .user_japanese:
                return .user_dependent(.japanese)
            case .user_english:
                return .user_dependent(.english)
            case .last_tab:
                return .last_tab
            case .clipboard_history_tab:
                return .existential(.special(.clipboard_history_tab))
            case .emoji_tab:
                return .existential(.special(.emoji))
            }
        case let .custom(identifier):
            if let custard = try? config.custardManager.custard(identifier: identifier) {
                return .existential(.custard(custard))
            } else {
                return .existential(.custard(.errorMessage))
            }
        }
    }
}

public struct TabManager {
    var config: any TabManagerConfiguration
    public var tab: ManagerTab {
        if let temporalTab {
            return temporalTab
        } else {
            return currentTab
        }
    }

    @MainActor init(config: any TabManagerConfiguration) {
        self.config = config
        self.currentTab = Self.getDefaultTab(config: config).managerTab
    }
    /// メインのタブ。
    private var currentTab: ManagerTab
    /// 一時的に表示を切り替えるタブ。lastTabに反映されない。
    private var temporalTab: ManagerTab?
    private var lastTab: ManagerTab?
    // Runtime-only override: never overwrite the user's saved layout.
    private(set) var automaticJapaneseLayout: LanguageLayout?

    @MainActor mutating func setAutomaticJapaneseLayout(_ layout: LanguageLayout?, variableStates: VariableStates) {
        guard automaticJapaneseLayout != layout else { return }
        automaticJapaneseLayout = layout
        let actualTab = existentialTab()
        variableStates.setInputStyle(actualTab.inputStyle)
        if let language = actualTab.language {
            variableStates.keyboardLanguage = language
        }
    }

    public enum ManagerTab {
        case existential(KeyboardTab.ExistentialTab)
        case user_dependent(KeyboardTab.UserDependentTab)
    }

    @MainActor func inputStyle(of tab: KeyboardTab) -> InputStyle {
        switch tab {
        case let .existential(tab):
            return Self.existentialTab(of: .existential(tab), config: config, japaneseLayoutOverride: automaticJapaneseLayout).inputStyle
        case let .user_dependent(tab):
            let actualTab = Self.actualTab(of: tab, config: config, japaneseLayoutOverride: automaticJapaneseLayout)
            return actualTab.inputStyle
        case .last_tab:
            fatalError()
        }
    }

    @MainActor func language(of tab: KeyboardTab) -> KeyboardLanguage? {
        switch tab {
        case let .existential(tab):
            return Self.existentialTab(of: .existential(tab), config: config, japaneseLayoutOverride: automaticJapaneseLayout).language
        case let .user_dependent(tab):
            let actualTab = Self.actualTab(of: tab, config: config, japaneseLayoutOverride: automaticJapaneseLayout)
            return actualTab.language
        case .last_tab:
            fatalError()
        }
    }

    @MainActor static func existentialTab(of tab: ManagerTab, config: any TabManagerConfiguration, japaneseLayoutOverride: LanguageLayout? = nil) -> KeyboardTab.ExistentialTab {
        switch tab {
        case let .existential(actual) where japaneseLayoutOverride != nil && (actual == .flick_hira || actual == .qwerty_hira):
            return actualTab(of: .japanese, config: config, japaneseLayoutOverride: japaneseLayoutOverride)
        case let .existential(tab):
            return tab
        case let .user_dependent(tab):
            return actualTab(of: tab, config: config, japaneseLayoutOverride: japaneseLayoutOverride)
        }
    }

    @MainActor public func existentialTab() -> KeyboardTab.ExistentialTab {
        Self.existentialTab(of: self.tab, config: config, japaneseLayoutOverride: automaticJapaneseLayout)
    }

    @MainActor static func actualTab(of tab: KeyboardTab.UserDependentTab, config: any TabManagerConfiguration, japaneseLayoutOverride: LanguageLayout? = nil) -> KeyboardTab.ExistentialTab {
        // ユーザの設定に合わせて遷移先のタブ(非user_dependent)を返す
        switch tab {
        case .english:
            switch config.englishLayout {
            case .flick:
                return .flick_abc
            case .qwerty:
                return .qwerty_abc
            case let .custard(identifier):
                return .custard((try? config.custardManager.custard(identifier: identifier)) ?? .errorMessage)
            }
        case .japanese:
            switch japaneseLayoutOverride ?? config.japaneseLayout {
            case .flick:
                return .flick_hira
            case .qwerty:
                return .qwerty_hira
            case let .custard(identifier):
                return .custard((try? config.custardManager.custard(identifier: identifier)) ?? .errorMessage)
            }
        }
    }

    @MainActor func isCurrentTab(tab: KeyboardTab) -> Bool {
        switch tab {
        case let .existential(actualTab):
            return Self.existentialTab(of: self.tab, config: config, japaneseLayoutOverride: automaticJapaneseLayout) == Self.existentialTab(of: .existential(actualTab), config: config, japaneseLayoutOverride: automaticJapaneseLayout)
        case let .user_dependent(type):
            return Self.actualTab(of: type, config: config, japaneseLayoutOverride: automaticJapaneseLayout) == Self.existentialTab(of: self.tab, config: config, japaneseLayoutOverride: automaticJapaneseLayout)
        case .last_tab:
            return false
        }
    }

    @MainActor mutating func initialize(variableStates: VariableStates) {
        switch lastTab {
        case .none:
            self.moveTab(to: .user_dependent(.japanese), variableStates: variableStates)
        case let .existential(tab):
            self.moveTab(to: tab, variableStates: variableStates)
        case let .user_dependent(tab):
            self.moveTab(to: .user_dependent(tab), variableStates: variableStates)
        }
    }

    mutating func closeKeyboard() {
        self.lastTab = self.currentTab
    }

    @MainActor mutating private func moveTab(to destination: KeyboardTab.ExistentialTab, variableStates: VariableStates) {
        // VariableStateの状態を遷移先のタブに合わせて適切に変更する
        let resolved = Self.existentialTab(of: .existential(destination), config: config, japaneseLayoutOverride: automaticJapaneseLayout)
        variableStates.setInputStyle(resolved.inputStyle)
        if let language = resolved.language {
            variableStates.keyboardLanguage = language
        }

        // selfの状態を更新する
        self.temporalTab = nil
        self.lastTab = self.currentTab
        self.currentTab = .existential(destination)
    }

    @MainActor private func updateVariableStates(_ variableStates: VariableStates, inputStyle: InputStyle, language: KeyboardLanguage?) {
        // VariableStateの状態を遷移先のタブに合わせて適切に変更する
        variableStates.setInputStyle(inputStyle)
        if let language {
            variableStates.keyboardLanguage = language
        }
        variableStates.updateResizingState()
    }

    @MainActor private static func getDefaultTab(config: any TabManagerConfiguration, japaneseLayoutOverride: LanguageLayout? = nil) -> (existentialTab: KeyboardTab.ExistentialTab, managerTab: ManagerTab) {
        (actualTab(of: KeyboardTab.UserDependentTab.japanese, config: config, japaneseLayoutOverride: japaneseLayoutOverride), .user_dependent(.japanese))
    }

    @MainActor mutating func setTemporalTab(_ destination: KeyboardTab, variableStates: VariableStates) {
        let actualTab: KeyboardTab.ExistentialTab
        switch destination {
        case let .existential(tab):
            let resolved = Self.existentialTab(of: .existential(tab), config: config, japaneseLayoutOverride: automaticJapaneseLayout)
            self.updateVariableStates(variableStates, inputStyle: resolved.inputStyle, language: resolved.language)
            self.temporalTab = .existential(tab)
        case let .user_dependent(tab):
            actualTab = Self.actualTab(of: tab, config: config, japaneseLayoutOverride: automaticJapaneseLayout)
            self.updateVariableStates(variableStates, inputStyle: actualTab.inputStyle, language: actualTab.language)
            self.temporalTab = .user_dependent(tab)
        case .last_tab:
            if let lastTab {
                actualTab = Self.existentialTab(of: lastTab, config: config, japaneseLayoutOverride: automaticJapaneseLayout)
                self.temporalTab = lastTab
            } else {
                (actualTab, self.temporalTab) = Self.getDefaultTab(config: config, japaneseLayoutOverride: automaticJapaneseLayout)
            }
            self.updateVariableStates(variableStates, inputStyle: actualTab.inputStyle, language: actualTab.language)
        }
    }

    @MainActor mutating func moveTab(to destination: KeyboardTab, variableStates: VariableStates) {
        switch destination {
        case let .existential(tab):
            let resolved = Self.existentialTab(of: .existential(tab), config: config, japaneseLayoutOverride: automaticJapaneseLayout)
            self.updateVariableStates(variableStates, inputStyle: resolved.inputStyle, language: resolved.language)
            self.lastTab = self.currentTab
            self.currentTab = .existential(tab)
        // Custard内の変数の初期化を実行
        //            if case let .custard(custard) = tab {
        //                for value in custard.logics.initial_values {
        //                    if case let .bool(bool) = value.value {
        //                        variableStates.boolStates.initializeState(value.name, with: bool)
        //                    }
        //                }
        //            }
        case let .user_dependent(tab):
            let actualTab = Self.actualTab(of: tab, config: config, japaneseLayoutOverride: automaticJapaneseLayout)
            self.updateVariableStates(variableStates, inputStyle: actualTab.inputStyle, language: actualTab.language)
            self.lastTab = self.currentTab
            self.currentTab = .user_dependent(tab)

        case .last_tab:
            // 適切なタブを取得する
            let actualTab: KeyboardTab.ExistentialTab
            if let lastTab,
               Self.existentialTab(of: lastTab, config: config, japaneseLayoutOverride: automaticJapaneseLayout) != Self.existentialTab(of: currentTab, config: config, japaneseLayoutOverride: automaticJapaneseLayout) {
                actualTab = Self.existentialTab(of: lastTab, config: config, japaneseLayoutOverride: automaticJapaneseLayout)
                self.currentTab = lastTab
            } else {
                (actualTab, self.currentTab) = Self.getDefaultTab(config: config, japaneseLayoutOverride: automaticJapaneseLayout)
            }
            self.updateVariableStates(variableStates, inputStyle: actualTab.inputStyle, language: actualTab.language)
            self.lastTab = nil
        }
        self.temporalTab = nil
    }
}

public protocol TabManagerConfiguration {
    @MainActor var japaneseLayout: LanguageLayout { get }
    @MainActor var englishLayout: LanguageLayout { get }
    var custardManager: any CustardManagerProtocol { get }
}
