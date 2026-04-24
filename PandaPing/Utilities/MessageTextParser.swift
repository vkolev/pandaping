//
//  MessageTextParser.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Foundation
import SwiftUI

/// A segment of parsed message text, tagged with its kind and IRC formatting.
struct TextSegment: Equatable {
    let text: String
    let kind: Kind
    var bold: Bool = false
    var italic: Bool = false
    var underline: Bool = false
    var foregroundColor: Int? = nil
    var backgroundColor: Int? = nil

    enum Kind: Equatable {
        case plain
        case channel   // #channel
        case mention   // @nick
        case link(URL)
    }
}

/// Parses IRC message text into segments of plain text, channel references,
/// mentions, and URLs — with support for mIRC formatting codes.
enum MessageTextParser {

    // MARK: - IRC Control Characters

    private static let boldChar: Character = "\u{02}"
    private static let italicChar: Character = "\u{1D}"
    private static let underlineChar: Character = "\u{1F}"
    private static let colorChar: Character = "\u{03}"
    private static let resetChar: Character = "\u{0F}"
    private static let reverseChar: Character = "\u{16}"

    // MARK: - mIRC Color Palette (0–15)

    static let mircColors: [Color] = [
        .white,
        .black,
        Color(red: 0.0, green: 0.0, blue: 0.5),       // 2 - Navy
        Color(red: 0.0, green: 0.5, blue: 0.0),       // 3 - Green
        .red,                                           // 4
        Color(red: 0.5, green: 0.0, blue: 0.0),       // 5 - Maroon
        .purple,                                        // 6
        .orange,                                        // 7
        .yellow,                                        // 8
        Color(red: 0.0, green: 1.0, blue: 0.0),       // 9 - Lime
        Color(red: 0.0, green: 0.5, blue: 0.5),       // 10 - Teal
        .cyan,                                          // 11
        Color(red: 0.0, green: 0.0, blue: 1.0),       // 12 - Royal Blue
        .pink,                                          // 13
        .gray,                                          // 14
        Color(red: 0.75, green: 0.75, blue: 0.75),    // 15 - Silver
    ]

    static func mircColor(_ index: Int) -> Color {
        let safeIndex = ((index % 16) + 16) % 16
        return mircColors[safeIndex]
    }

    // MARK: - Internal Types

    private struct FormatState {
        var bold = false
        var italic = false
        var underline = false
        var foreground: Int? = nil
        var background: Int? = nil

        mutating func reset() {
            bold = false
            italic = false
            underline = false
            foreground = nil
            background = nil
        }
    }

    private struct StyledRun {
        let text: String
        let bold: Bool
        let italic: Bool
        let underline: Bool
        let foreground: Int?
        let background: Int?

        init(text: String, state: FormatState) {
            self.text = text
            self.bold = state.bold
            self.italic = state.italic
            self.underline = state.underline
            self.foreground = state.foreground
            self.background = state.background
        }
    }

    // MARK: - Public API

    /// Parse a message string into tagged segments with IRC formatting.
    static func parse(_ text: String) -> [TextSegment] {
        guard !text.isEmpty else { return [] }

        let styledRuns = parseFormattingCodes(text)

        var segments: [TextSegment] = []
        for run in styledRuns {
            segments.append(contentsOf: detectEntities(in: run))
        }

        return segments
    }

    /// Build a styled `AttributedString` from parsed segments.
    static func attributedString(from segments: [TextSegment]) -> AttributedString {
        var result = AttributedString()

        for segment in segments {
            var attrs = AttributedString(segment.text)

            // Bold / Italic via inline presentation intent
            var intent: InlinePresentationIntent = []
            if segment.bold { intent.insert(.stronglyEmphasized) }
            if segment.italic { intent.insert(.emphasized) }
            if !intent.isEmpty {
                attrs.inlinePresentationIntent = intent
            }

            if segment.underline {
                attrs.underlineStyle = .single
            }

            // IRC foreground / background colors
            if let fg = segment.foregroundColor {
                attrs.foregroundColor = mircColor(fg)
            }
            if let bg = segment.backgroundColor {
                attrs.backgroundColor = mircColor(bg)
            }

            // Entity-specific styling and links
            switch segment.kind {
            case .channel:
                if segment.foregroundColor == nil {
                    attrs.foregroundColor = .cyan
                }
                let name = String(segment.text.dropFirst())
                if let url = URL(string: "pandaping://channel/\(name)") {
                    attrs.link = url
                }

            case .mention:
                if segment.foregroundColor == nil {
                    attrs.foregroundColor = .orange
                }
                let name = String(segment.text.dropFirst())
                if let url = URL(string: "pandaping://mention/\(name)") {
                    attrs.link = url
                }

            case .link(let url):
                attrs.link = url

            case .plain:
                break
            }

            result.append(attrs)
        }

        return result
    }

    /// Convenience: parse text and return a fully styled `AttributedString`.
    static func styledAttributedString(for text: String) -> AttributedString {
        attributedString(from: parse(text))
    }

    // MARK: - IRC Formatting Parser

    private static func parseFormattingCodes(_ text: String) -> [StyledRun] {
        let chars = Array(text)
        guard !chars.isEmpty else { return [] }

        var runs: [StyledRun] = []
        var state = FormatState()
        var currentText = ""
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            switch ch {
            case boldChar:
                if !currentText.isEmpty {
                    runs.append(StyledRun(text: currentText, state: state))
                    currentText = ""
                }
                state.bold.toggle()
                i += 1

            case italicChar:
                if !currentText.isEmpty {
                    runs.append(StyledRun(text: currentText, state: state))
                    currentText = ""
                }
                state.italic.toggle()
                i += 1

            case underlineChar:
                if !currentText.isEmpty {
                    runs.append(StyledRun(text: currentText, state: state))
                    currentText = ""
                }
                state.underline.toggle()
                i += 1

            case reverseChar:
                if !currentText.isEmpty {
                    runs.append(StyledRun(text: currentText, state: state))
                    currentText = ""
                }
                swap(&state.foreground, &state.background)
                i += 1

            case colorChar:
                if !currentText.isEmpty {
                    runs.append(StyledRun(text: currentText, state: state))
                    currentText = ""
                }
                i += 1
                let (fg, nextI) = parseColorNumber(chars, from: i)
                i = nextI
                if let fg {
                    state.foreground = fg
                    if i < chars.count && chars[i] == "," {
                        i += 1
                        let (bg, nextI2) = parseColorNumber(chars, from: i)
                        i = nextI2
                        state.background = bg
                    }
                } else {
                    state.foreground = nil
                    state.background = nil
                }

            case resetChar:
                if !currentText.isEmpty {
                    runs.append(StyledRun(text: currentText, state: state))
                    currentText = ""
                }
                state.reset()
                i += 1

            default:
                currentText.append(ch)
                i += 1
            }
        }

        if !currentText.isEmpty {
            runs.append(StyledRun(text: currentText, state: state))
        }

        return runs
    }

    private static func parseColorNumber(_ chars: [Character], from index: Int) -> (Int?, Int) {
        var i = index
        var digits = ""
        while i < chars.count && digits.count < 2 && chars[i].isASCII && chars[i].isNumber {
            digits.append(chars[i])
            i += 1
        }
        if let num = Int(digits) {
            return (num, i)
        }
        return (nil, index)
    }

    // MARK: - Entity Detection (channels, mentions, URLs)

    private static let entityPattern = try! NSRegularExpression(
        pattern: #"(?:(?<=\s)|^)(#\S+|@\w+)"#,
        options: []
    )

    private static func detectEntities(in run: StyledRun) -> [TextSegment] {
        let text = run.text
        guard !text.isEmpty else { return [] }

        var entities: [(range: Range<String.Index>, kind: TextSegment.Kind)] = []

        let nsRange = NSRange(text.startIndex..., in: text)

        // Channels and mentions
        for match in entityPattern.matches(in: text, range: nsRange) {
            if let range = Range(match.range(at: 1), in: text) {
                let matched = String(text[range])
                let kind: TextSegment.Kind = matched.hasPrefix("#") ? .channel : .mention
                entities.append((range, kind))
            }
        }

        // URLs
        if let urlDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for match in urlDetector.matches(in: text, range: nsRange) {
                if let range = Range(match.range, in: text),
                   let url = match.url {
                    let overlaps = entities.contains { $0.range.overlaps(range) }
                    if !overlaps {
                        entities.append((range, .link(url)))
                    }
                }
            }
        }

        entities.sort { $0.range.lowerBound < $1.range.lowerBound }

        guard !entities.isEmpty else {
            return [makeSegment(text: text, kind: .plain, run: run)]
        }

        var segments: [TextSegment] = []
        var currentIndex = text.startIndex

        for entity in entities {
            if currentIndex < entity.range.lowerBound {
                let plain = String(text[currentIndex..<entity.range.lowerBound])
                segments.append(makeSegment(text: plain, kind: .plain, run: run))
            }
            let entityText = String(text[entity.range])
            segments.append(makeSegment(text: entityText, kind: entity.kind, run: run))
            currentIndex = entity.range.upperBound
        }

        if currentIndex < text.endIndex {
            let plain = String(text[currentIndex...])
            segments.append(makeSegment(text: plain, kind: .plain, run: run))
        }

        return segments
    }

    private static func makeSegment(text: String, kind: TextSegment.Kind, run: StyledRun) -> TextSegment {
        TextSegment(
            text: text,
            kind: kind,
            bold: run.bold,
            italic: run.italic,
            underline: run.underline,
            foregroundColor: run.foreground,
            backgroundColor: run.background
        )
    }
}
