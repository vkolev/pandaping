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
