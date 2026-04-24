//
//  TabCompleterTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Testing
@testable import PandaPing

@Suite("Tab Completer")
struct TabCompleterTests {

    let nicknames = ["alice", "alice2", "bob", "charlie"]
    let channels = ["#swift", "#general", "#swiftui"]

    @Test("Completes @mention at start of line")
    func mentionAtStartOfLine() {
        let result = TabCompleter.complete(
            text: "@al",
            cursorOffset: 3,
            nicknames: nicknames,
            channels: channels
        )

        #expect(result?.text == "@alice ")
        #expect(result?.cursorOffset == 7)
    }

    @Test("Completes @mention mid-line")
    func mentionMidLine() {
        let result = TabCompleter.complete(
            text: "Hey @al",
            cursorOffset: 7,
            nicknames: nicknames,
            channels: channels
        )

        #expect(result?.text == "Hey @alice ")
        #expect(result?.cursorOffset == 11)
    }

    @Test("Completes channel name with ' ' suffix")
    func channelCompletion() {
        let result = TabCompleter.complete(
            text: "/join #sw",
            cursorOffset: 9,
            nicknames: nicknames,
            channels: channels
        )

        #expect(result?.text == "/join #swift ")
    }

    @Test("Returns nil for plain text without @ or #")
    func plainTextNoCompletion() {
        let result = TabCompleter.complete(
            text: "al",
            cursorOffset: 2,
            nicknames: nicknames,
            channels: channels
        )

        #expect(result == nil)
    }

    @Test("Returns nil for bare @ with no characters after")
    func bareAtSign() {
        let result = TabCompleter.complete(
            text: "@",
            cursorOffset: 1,
            nicknames: nicknames,
            channels: channels
        )

        #expect(result == nil)
    }

    @Test("Returns nil for no matches")
    func noMatches() {
        let result = TabCompleter.complete(
            text: "@xyz",
            cursorOffset: 4,
            nicknames: nicknames,
            channels: channels
        )

        #expect(result == nil)
    }

    @Test("Returns nil for empty input")
    func emptyInput() {
        let result = TabCompleter.complete(
            text: "",
            cursorOffset: 0,
            nicknames: nicknames,
            channels: channels
        )

        #expect(result == nil)
    }

    @Test("Cycles through multiple @mention matches")
    func cycling() {
        let result0 = TabCompleter.complete(
            text: "@al",
            cursorOffset: 3,
            nicknames: nicknames,
            channels: channels,
            cycleIndex: 0
        )
        let result1 = TabCompleter.complete(
            text: "@al",
            cursorOffset: 3,
            nicknames: nicknames,
            channels: channels,
            cycleIndex: 1
        )

        #expect(result0?.text == "@alice ")
        #expect(result1?.text == "@alice2 ")
    }

    @Test("Cycle wraps around")
    func cycleWraps() {
        let result = TabCompleter.complete(
            text: "@al",
            cursorOffset: 3,
            nicknames: nicknames,
            channels: channels,
            cycleIndex: 2  // Only 2 matches (alice, alice2) → wraps to 0
        )

        #expect(result?.text == "@alice ")
    }

    @Test("Case insensitive matching")
    func caseInsensitive() {
        let result = TabCompleter.complete(
            text: "@AL",
            cursorOffset: 3,
            nicknames: nicknames,
            channels: channels
        )

        #expect(result?.text == "@alice ")
    }

    @Test("Preserves text after cursor")
    func preservesAfterCursor() {
        let result = TabCompleter.complete(
            text: "@al world",
            cursorOffset: 3,
            nicknames: nicknames,
            channels: channels
        )

        #expect(result?.text == "@alice  world")
    }

    @Test("Cycles through channel matches")
    func channelCycling() {
        let result0 = TabCompleter.complete(
            text: "#sw",
            cursorOffset: 3,
            nicknames: nicknames,
            channels: channels,
            cycleIndex: 0
        )
        let result1 = TabCompleter.complete(
            text: "#sw",
            cursorOffset: 3,
            nicknames: nicknames,
            channels: channels,
            cycleIndex: 1
        )

        #expect(result0?.text == "#swift ")
        #expect(result1?.text == "#swiftui ")
    }
}
