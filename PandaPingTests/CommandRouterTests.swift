//
//  CommandRouterTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Testing
@testable import PandaPing

@Suite("Command Router")
struct CommandRouterTests {

    // MARK: - Regular Messages

    @Test("Regular text becomes sendMessage to current target")
    func regularMessage() {
        let action = CommandRouter.parse("Hello world", currentTarget: "#swift")

        #expect(action == .sendMessage(target: "#swift", text: "Hello world"))
    }

    @Test("Returns nil for regular text with no current target")
    func regularMessageNoTarget() {
        let action = CommandRouter.parse("Hello world", currentTarget: nil)

        #expect(action == nil)
    }

    @Test("Returns nil for empty input")
    func emptyInput() {
        let action = CommandRouter.parse("", currentTarget: "#swift")

        #expect(action == nil)
    }

    // MARK: - /join

    @Test("Parses /join command")
    func joinCommand() {
        let action = CommandRouter.parse("/join #swift", currentTarget: nil)

        #expect(action == .join(channel: "#swift"))
    }

    @Test("Parses /JOIN (case insensitive)")
    func joinCaseInsensitive() {
        let action = CommandRouter.parse("/JOIN #general", currentTarget: nil)

        #expect(action == .join(channel: "#general"))
    }

    @Test("Returns nil for /join with no channel")
    func joinNoChannel() {
        let action = CommandRouter.parse("/join", currentTarget: nil)

        #expect(action == nil)
    }

    // MARK: - /part

    @Test("Parses /part with channel")
    func partWithChannel() {
        let action = CommandRouter.parse("/part #swift", currentTarget: nil)

        #expect(action == .part(channel: "#swift", message: nil))
    }

    @Test("Parses /part with channel and message")
    func partWithMessage() {
        let action = CommandRouter.parse("/part #swift Goodbye everyone!", currentTarget: nil)

        #expect(action == .part(channel: "#swift", message: "Goodbye everyone!"))
    }

    @Test("/part with no args uses current channel target")
    func partCurrentChannel() {
        let action = CommandRouter.parse("/part", currentTarget: "#swift")

        #expect(action == .part(channel: "#swift", message: nil))
    }

    @Test("/part with no args and no channel target returns nil")
    func partNoTarget() {
        let action = CommandRouter.parse("/part", currentTarget: nil)

        #expect(action == nil)
    }

    // MARK: - /msg

    @Test("Parses /msg command")
    func msgCommand() {
        let action = CommandRouter.parse("/msg alice Hey there!", currentTarget: nil)

        #expect(action == .privateMessage(target: "alice", text: "Hey there!"))
    }

    @Test("Returns nil for /msg with no text")
    func msgNoText() {
        let action = CommandRouter.parse("/msg alice", currentTarget: nil)

        #expect(action == nil)
    }

    @Test("Returns nil for /msg with no args")
    func msgNoArgs() {
        let action = CommandRouter.parse("/msg", currentTarget: nil)

        #expect(action == nil)
    }

    // MARK: - /nick

    @Test("Parses /nick command")
    func nickCommand() {
        let action = CommandRouter.parse("/nick newnick", currentTarget: nil)

        #expect(action == .changeNick("newnick"))
    }

    @Test("Returns nil for /nick with no name")
    func nickNoName() {
        let action = CommandRouter.parse("/nick", currentTarget: nil)

        #expect(action == nil)
    }

    // MARK: - /quit

    @Test("Parses /quit with no message")
    func quitNoMessage() {
        let action = CommandRouter.parse("/quit", currentTarget: nil)

        #expect(action == .quit(message: nil))
    }

    @Test("Parses /quit with message")
    func quitWithMessage() {
        let action = CommandRouter.parse("/quit See you later!", currentTarget: nil)

        #expect(action == .quit(message: "See you later!"))
    }

    // MARK: - /me

    @Test("Parses /me command")
    func meCommand() {
        let action = CommandRouter.parse("/me waves hello", currentTarget: "#swift")

        #expect(action == .action(target: "#swift", text: "waves hello"))
    }

    @Test("Returns nil for /me with no text")
    func meNoText() {
        let action = CommandRouter.parse("/me", currentTarget: "#swift")

        #expect(action == nil)
    }

    @Test("Returns nil for /me with no current target")
    func meNoTarget() {
        let action = CommandRouter.parse("/me waves", currentTarget: nil)

        #expect(action == nil)
    }

    // MARK: - Unknown Commands

    @Test("Unknown command returns unknown action")
    func unknownCommand() {
        let action = CommandRouter.parse("/foobar something", currentTarget: nil)

        #expect(action == .unknown(command: "foobar"))
    }
}
