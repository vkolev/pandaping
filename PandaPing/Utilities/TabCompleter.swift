//
//  TabCompleter.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Foundation

/// Result of a tab completion attempt.
struct CompletionResult: Equatable {
    /// The new full text after applying the completion.
    let text: String
    /// The cursor position within the new text.
    let cursorOffset: Int
}

/// Pure-function tab completer for IRC nicknames and channel names.
enum TabCompleter {

    /// Attempt to complete the word at the cursor position.
    ///
    /// - Parameters:
    ///   - text: The current input text.
    ///   - cursorOffset: The cursor position (index from start).
    ///   - nicknames: Available nicknames to complete against.
    ///   - channels: Available channel names to complete against.
    ///   - cycleIndex: Index into the sorted candidates for cycling (0 = first match).
    /// - Returns: A `CompletionResult` with the completed text, or `nil` if no match.
    static func complete(
        text: String,
        cursorOffset: Int,
        nicknames: [String],
        channels: [String],
        cycleIndex: Int = 0
    ) -> CompletionResult? {
        guard !text.isEmpty, cursorOffset > 0 else { return nil }

        let clampedCursor = min(cursorOffset, text.count)

        // Find the word being completed (from cursor back to nearest space or start)
        let beforeCursor = String(text.prefix(clampedCursor))
        let afterCursor = String(text.suffix(text.count - clampedCursor))

        let wordStart = beforeCursor.lastIndex(of: " ")
            .map { beforeCursor.index(after: $0) }
            ?? beforeCursor.startIndex

        let partial = String(beforeCursor[wordStart...])
        guard !partial.isEmpty else { return nil }

        let prefix = String(beforeCursor[beforeCursor.startIndex..<wordStart])

        // Choose candidate list based on prefix character
        let candidates: [String]
        let completionPrefix: String
        if partial.hasPrefix("#") {
            completionPrefix = ""
            candidates = channels
                .filter { $0.lowercased().hasPrefix(partial.lowercased()) }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } else if partial.hasPrefix("@") {
            completionPrefix = "@"
            let namePrefix = String(partial.dropFirst())
            guard !namePrefix.isEmpty else { return nil }
            candidates = nicknames
                .filter { $0.lowercased().hasPrefix(namePrefix.lowercased()) }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } else {
            return nil
        }

        guard !candidates.isEmpty else { return nil }

        let selected = candidates[cycleIndex % candidates.count]

        let completed = prefix + completionPrefix + selected + " " + afterCursor
        let newCursor = (prefix + completionPrefix + selected + " ").count

        return CompletionResult(text: completed, cursorOffset: newCursor)
    }
}
