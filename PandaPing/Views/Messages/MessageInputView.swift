//
//  MessageInputView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import SwiftUI

/// A text input field for sending IRC messages and commands.
/// Supports `/commands` (e.g. `/join #swift`, `/msg alice Hello`)
/// and Tab completion for nicknames and channels.
struct MessageInputView: View {
    let currentTarget: String?
    let onAction: (UserAction) -> Void
    var nicknames: [String] = []
    var channelNames: [String] = []

    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    // Input history state
    @State private var inputHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var savedCurrentInput: String = ""

    // Tab completion state
    @State private var tabCycleIndex = 0
    @State private var tabOriginalText: String?
    @State private var isTabCompleting = false

    var body: some View {
        VStack(spacing: 0) {
            if !mentionSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(mentionSuggestions, id: \.self) { nick in
                            Button {
                                applyMentionSuggestion(nick)
                            } label: {
                                Text("@\(nick)")
                                    .font(.system(.callout, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.quaternary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                Divider()
            }

            HStack(spacing: 8) {
                TextField("Message \(currentTarget ?? "")...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isFocused)
                    .onSubmit {
                        sendInput()
                    }
                    .onAppear {
                        if DeviceInfo.isIPad {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isFocused = true
                            }
                        }
                    }
                    #if os(macOS)
                    .onKeyPress(.tab) {
                        performTabCompletion()
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        navigateHistory(direction: .up)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        navigateHistory(direction: .down)
                        return .handled
                    }
                    .onKeyPress(phases: .down) { keyPress in
                        guard keyPress.modifiers == .control else { return .ignored }
                        let displayChar: Character? = switch keyPress.key {
                        case KeyEquivalent("b"): "\u{2402}"
                        case KeyEquivalent("k"): "\u{2403}"
                        case KeyEquivalent("o"): "\u{240F}"
                        case KeyEquivalent("i"): "\u{241D}"
                        case KeyEquivalent("u"): "\u{241F}"
                        case KeyEquivalent("r"): "\u{2416}"
                        default: nil
                        }
                        if let displayChar {
                            inputText.append(displayChar)
                            return .handled
                        }
                        return .ignored
                    }
                    #endif
                    .onChange(of: inputText) {
                        if isTabCompleting {
                            isTabCompleting = false
                        } else {
                            resetTabState()
                        }
                    }

                Button {
                    sendInput()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderless)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onAppear {
            isFocused = true
        }
    }

    private var mentionSuggestions: [String] {
        guard let atRange = inputText.range(of: "@", options: .backwards),
              atRange.lowerBound == inputText.startIndex ||
              inputText[inputText.index(before: atRange.lowerBound)] == " " else {
            return []
        }
        let partial = String(inputText[atRange.upperBound...])
        guard !partial.isEmpty, !partial.contains(" ") else { return [] }
        return nicknames
            .filter { $0.lowercased().hasPrefix(partial.lowercased()) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func applyMentionSuggestion(_ nick: String) {
        guard let atRange = inputText.range(of: "@", options: .backwards) else { return }
        let prefix = String(inputText[..<atRange.lowerBound])
        isTabCompleting = true
        inputText = prefix + "@\(nick) "
    }

    private static let displayToControlMap: [(display: String, control: String)] = [
        ("\u{2402}", "\u{02}"),   // ␂ → Bold
        ("\u{2403}", "\u{03}"),   // ␃ → Color
        ("\u{240F}", "\u{0F}"),   // ␏ → Reset
        ("\u{241D}", "\u{1D}"),   // ␝ → Italic
        ("\u{241F}", "\u{1F}"),   // ␟ → Underline
        ("\u{2416}", "\u{16}"),   // ␖ → Reverse
    ]

    private static func displayToIRC(_ text: String) -> String {
        var result = text
        for (display, control) in displayToControlMap {
            result = result.replacingOccurrences(of: display, with: control)
        }
        return result
    }

    private func sendInput() {
        resetTabState()
        let ircText = Self.displayToIRC(inputText)
        guard let action = CommandRouter.parse(ircText, currentTarget: currentTarget) else {
            return
        }
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            inputHistory.append(trimmed)
        }
        historyIndex = -1
        savedCurrentInput = ""
        onAction(action)
        inputText = ""
    }

    private enum HistoryDirection { case up, down }

    private func navigateHistory(direction: HistoryDirection) {
        guard !inputHistory.isEmpty else { return }

        switch direction {
        case .up:
            if historyIndex == -1 {
                savedCurrentInput = inputText
                historyIndex = inputHistory.count - 1
            } else if historyIndex > 0 {
                historyIndex -= 1
            }
            isTabCompleting = true
            inputText = inputHistory[historyIndex]
        case .down:
            if historyIndex == -1 { return }
            if historyIndex < inputHistory.count - 1 {
                historyIndex += 1
                isTabCompleting = true
                inputText = inputHistory[historyIndex]
            } else {
                historyIndex = -1
                isTabCompleting = true
                inputText = savedCurrentInput
            }
        }
    }

    private func performTabCompletion() {
        // On first Tab, save the original text; on subsequent Tabs, cycle
        let sourceText: String
        if let original = tabOriginalText {
            sourceText = original
            tabCycleIndex += 1
        } else {
            sourceText = inputText
            tabOriginalText = inputText
            tabCycleIndex = 0
        }

        if let result = TabCompleter.complete(
            text: sourceText,
            cursorOffset: sourceText.count,
            nicknames: nicknames,
            channels: channelNames,
            cycleIndex: tabCycleIndex
        ) {
            isTabCompleting = true
            inputText = result.text
        }
    }

    private func resetTabState() {
        tabOriginalText = nil
        tabCycleIndex = 0
    }
}
