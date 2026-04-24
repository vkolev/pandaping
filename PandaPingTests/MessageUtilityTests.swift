//
//  MessageUtilityTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Testing
@testable import PandaPing

// MARK: - Nickname Coloring

@Suite("Nickname Color Hashing")
struct NicknameColorTests {

    @Test("Same nickname always produces the same color index")
    func consistentColor() {
        let index1 = NicknameColor.colorIndex(for: "alice")
        let index2 = NicknameColor.colorIndex(for: "alice")

        #expect(index1 == index2)
    }

    @Test("Different nicknames produce different color indices (likely)")
    func differentColors() {
        let index1 = NicknameColor.colorIndex(for: "alice")
        let index2 = NicknameColor.colorIndex(for: "bob")

        // Not guaranteed but extremely likely with a good hash
        #expect(index1 != index2)
    }

    @Test("Color index is within valid palette range")
    func indexInRange() {
        let names = ["alice", "bob", "charlie", "delta", "echo", "foxtrot"]
        for name in names {
            let index = NicknameColor.colorIndex(for: name)
            #expect(index >= 0)
            #expect(index < NicknameColor.palette.count)
        }
    }

    @Test("Empty nickname returns a valid index")
    func emptyNickname() {
        let index = NicknameColor.colorIndex(for: "")
        #expect(index >= 0)
        #expect(index < NicknameColor.palette.count)
    }
}

// MARK: - Message Text Parsing

@Suite("Message Text Pattern Detection")
struct MessageTextParserTests {

    @Test("Detects channel reference in text")
    func detectsChannel() {
        let segments = MessageTextParser.parse("Join us in #swift today")

        #expect(segments.contains { $0.kind == .channel && $0.text == "#swift" })
    }

    @Test("Detects mention in text")
    func detectsMention() {
        let segments = MessageTextParser.parse("Hey @alice check this out")

        #expect(segments.contains { $0.kind == .mention && $0.text == "@alice" })
    }

    @Test("Preserves plain text around patterns")
    func preservesPlainText() {
        let segments = MessageTextParser.parse("Hello #swift world")

        #expect(segments.count == 3)
        #expect(segments[0] == TextSegment(text: "Hello ", kind: .plain))
        #expect(segments[1] == TextSegment(text: "#swift", kind: .channel))
        #expect(segments[2] == TextSegment(text: " world", kind: .plain))
    }

    @Test("Handles text with no patterns")
    func noPatterns() {
        let segments = MessageTextParser.parse("Just a normal message")

        #expect(segments.count == 1)
        #expect(segments[0].kind == .plain)
        #expect(segments[0].text == "Just a normal message")
    }

    @Test("Handles multiple patterns in one message")
    func multiplePatterns() {
        let segments = MessageTextParser.parse("@bob see #general and #help")

        let channels = segments.filter { $0.kind == .channel }
        let mentions = segments.filter { $0.kind == .mention }

        #expect(channels.count == 2)
        #expect(mentions.count == 1)
    }

    @Test("Handles empty text")
    func emptyText() {
        let segments = MessageTextParser.parse("")

        #expect(segments.isEmpty)
    }

    @Test("Channel must follow word boundary")
    func channelWordBoundary() {
        let segments = MessageTextParser.parse("email#tag is not a channel")

        // The # is not at a word boundary, so no channel detected
        let channels = segments.filter { $0.kind == .channel }
        #expect(channels.isEmpty)
    }
}

// MARK: - IRC Formatting

@Suite("IRC Formatting Codes")
struct IRCFormattingTests {

    @Test("Parses bold text")
    func boldText() {
        let segments = MessageTextParser.parse("\u{02}hello\u{02} world")

        #expect(segments.count == 2)
        #expect(segments[0].text == "hello")
        #expect(segments[0].bold == true)
        #expect(segments[1].text == " world")
        #expect(segments[1].bold == false)
    }

    @Test("Parses italic text")
    func italicText() {
        let segments = MessageTextParser.parse("\u{1D}hello\u{1D} world")

        #expect(segments.count == 2)
        #expect(segments[0].text == "hello")
        #expect(segments[0].italic == true)
        #expect(segments[1].text == " world")
        #expect(segments[1].italic == false)
    }

    @Test("Parses underline text")
    func underlineText() {
        let segments = MessageTextParser.parse("\u{1F}hello\u{1F} world")

        #expect(segments.count == 2)
        #expect(segments[0].text == "hello")
        #expect(segments[0].underline == true)
        #expect(segments[1].text == " world")
        #expect(segments[1].underline == false)
    }

    @Test("Parses combined bold and italic")
    func boldAndItalic() {
        let segments = MessageTextParser.parse("\u{02}\u{1D}hello\u{0F} world")

        #expect(segments.count == 2)
        #expect(segments[0].text == "hello")
        #expect(segments[0].bold == true)
        #expect(segments[0].italic == true)
        #expect(segments[1].text == " world")
        #expect(segments[1].bold == false)
        #expect(segments[1].italic == false)
    }

    @Test("Parses foreground color")
    func foregroundColor() {
        // \x034 = red foreground
        let segments = MessageTextParser.parse("\u{03}4hello\u{03} world")

        #expect(segments.count == 2)
        #expect(segments[0].text == "hello")
        #expect(segments[0].foregroundColor == 4)
        #expect(segments[1].text == " world")
        #expect(segments[1].foregroundColor == nil)
    }

    @Test("Parses foreground and background color")
    func foregroundAndBackgroundColor() {
        // \x034,2 = red on navy
        let segments = MessageTextParser.parse("\u{03}4,2hello\u{0F} world")

        #expect(segments.count == 2)
        #expect(segments[0].text == "hello")
        #expect(segments[0].foregroundColor == 4)
        #expect(segments[0].backgroundColor == 2)
        #expect(segments[1].text == " world")
        #expect(segments[1].foregroundColor == nil)
        #expect(segments[1].backgroundColor == nil)
    }

    @Test("Parses two-digit color codes")
    func twoDigitColors() {
        // \x0312 = royal blue
        let segments = MessageTextParser.parse("\u{03}12hello\u{0F}")

        #expect(segments.count == 1)
        #expect(segments[0].text == "hello")
        #expect(segments[0].foregroundColor == 12)
    }

    @Test("Reset clears all formatting")
    func resetClearsAll() {
        let segments = MessageTextParser.parse("\u{02}\u{1D}\u{03}4bold italic red\u{0F}plain")

        #expect(segments.count == 2)
        #expect(segments[0].bold == true)
        #expect(segments[0].italic == true)
        #expect(segments[0].foregroundColor == 4)
        #expect(segments[1].text == "plain")
        #expect(segments[1].bold == false)
        #expect(segments[1].italic == false)
        #expect(segments[1].foregroundColor == nil)
    }

    @Test("Strips control characters from output text")
    func stripsControlChars() {
        let segments = MessageTextParser.parse("\u{02}bold\u{02}")

        #expect(segments.count == 1)
        #expect(segments[0].text == "bold")
        #expect(!segments[0].text.contains("\u{02}"))
    }

    @Test("Reverse swaps foreground and background")
    func reverseColors() {
        let segments = MessageTextParser.parse("\u{03}4,2hello\u{16}reversed\u{0F}")

        #expect(segments[0].foregroundColor == 4)
        #expect(segments[0].backgroundColor == 2)
        #expect(segments[1].foregroundColor == 2)
        #expect(segments[1].backgroundColor == 4)
    }

    @Test("Formatting applies to channels and mentions")
    func formattingWithEntities() {
        let segments = MessageTextParser.parse("\u{02}join #swift\u{02}")

        let channel = segments.first { $0.kind == .channel }
        #expect(channel != nil)
        #expect(channel?.bold == true)
    }

    @Test("Text with no formatting codes has default attributes")
    func noFormattingCodes() {
        let segments = MessageTextParser.parse("plain text")

        #expect(segments.count == 1)
        #expect(segments[0].bold == false)
        #expect(segments[0].italic == false)
        #expect(segments[0].underline == false)
        #expect(segments[0].foregroundColor == nil)
        #expect(segments[0].backgroundColor == nil)
    }
}

// MARK: - URL Detection

@Suite("URL Detection in Messages")
struct URLDetectionTests {

    @Test("Detects HTTP URL in text")
    func detectsHTTPURL() {
        let segments = MessageTextParser.parse("check https://example.com for info")

        let links = segments.filter { if case .link = $0.kind { return true }; return false }
        #expect(links.count == 1)
        #expect(links[0].text == "https://example.com")
    }

    @Test("Detects URL alongside channel and mention")
    func urlWithChannelAndMention() {
        let segments = MessageTextParser.parse("@alice see https://example.com in #help")

        let links = segments.filter { if case .link = $0.kind { return true }; return false }
        let mentions = segments.filter { $0.kind == .mention }
        let channels = segments.filter { $0.kind == .channel }

        #expect(links.count == 1)
        #expect(mentions.count == 1)
        #expect(channels.count == 1)
    }

    @Test("URL inherits IRC formatting")
    func urlWithFormatting() {
        let segments = MessageTextParser.parse("\u{02}see https://example.com\u{02}")

        let links = segments.filter { if case .link = $0.kind { return true }; return false }
        #expect(links.count == 1)
        #expect(links[0].bold == true)
    }
}
