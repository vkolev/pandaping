//
//  MessageTextParser.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Foundation

/// A segment of parsed message text, tagged with its kind.
struct TextSegment: Equatable {
    let text: String
    let kind: Kind

    enum Kind: Equatable {
        case plain
        case channel   // #channel
        case mention   // @nick
    }
}

/// Parses IRC message text into segments of plain text, channel references, and mentions.
enum MessageTextParser {

    // Matches #channel or @nick at a word boundary.
    // Channels: start with # followed by one or more non-whitespace chars
    // Mentions: start with @ followed by one or more word chars
    private static let pattern = try! NSRegularExpression(
        pattern: #"(?:(?<=\s)|^)(#\S+|@\w+)"#,
        options: []
    )

    /// Parse a message string into tagged segments.
    static func parse(_ text: String) -> [TextSegment] {
        guard !text.isEmpty else { return [] }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = pattern.matches(in: text, options: [], range: nsRange)

        guard !matches.isEmpty else {
            return [TextSegment(text: text, kind: .plain)]
        }

        var segments: [TextSegment] = []
        var currentIndex = text.startIndex

        for match in matches {
            guard let matchRange = Range(match.range(at: 1), in: text) else { continue }

            // Plain text before this match
            if currentIndex < matchRange.lowerBound {
                let plain = String(text[currentIndex..<matchRange.lowerBound])
                segments.append(TextSegment(text: plain, kind: .plain))
            }

            let matched = String(text[matchRange])
            let kind: TextSegment.Kind = matched.hasPrefix("#") ? .channel : .mention
            segments.append(TextSegment(text: matched, kind: kind))

            currentIndex = matchRange.upperBound
        }

        // Trailing plain text
        if currentIndex < text.endIndex {
            let plain = String(text[currentIndex...])
            segments.append(TextSegment(text: plain, kind: .plain))
        }

        return segments
    }
}
