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

    // Tab completion state
    @State private var tabCycleIndex = 0
    @State private var tabOriginalText: String?

    var body: some View {
        HStack(spacing: 8) {
            TextField("Message \(currentTarget ?? "")...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .focused($isFocused)
                .onSubmit {
                    sendInput()
                }
                #if os(macOS)
                .onKeyPress(.tab) {
                    performTabCompletion()
                    return .handled
                }
                #endif
                .onChange(of: inputText) { oldValue, newValue in
                    // Reset tab state when user types manually (not from tab completion)
                    if tabOriginalText != nil && newValue != oldValue {
                        // Only reset if this wasn't a tab-triggered change
                        // We detect this by checking if the new value doesn't match
                        // what tab completion would have produced
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
        .onAppear {
            isFocused = true
        }
    }

    private func sendInput() {
        resetTabState()
        guard let action = CommandRouter.parse(inputText, currentTarget: currentTarget) else {
            return
        }
        onAction(action)
        inputText = ""
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
            inputText = result.text
        }
    }

    private func resetTabState() {
        tabOriginalText = nil
        tabCycleIndex = 0
    }
}
