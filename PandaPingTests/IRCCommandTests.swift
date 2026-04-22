//
//  IRCCommandTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Testing
@testable import PandaPing

@Suite("IRC Command Serialization")
struct IRCCommandTests {

    @Test("Serializes JOIN command")
    func serializeJoin() {
        let raw = IRCCommand.join(channel: "#swift").rawString

        #expect(raw == "JOIN #swift")
    }

    @Test("Serializes PART command without message")
    func serializePartNoMessage() {
        let raw = IRCCommand.part(channel: "#swift").rawString

        #expect(raw == "PART #swift")
    }

    @Test("Serializes PART command with message")
    func serializePartWithMessage() {
        let raw = IRCCommand.part(channel: "#swift", message: "Goodbye!").rawString

        #expect(raw == "PART #swift :Goodbye!")
    }

    @Test("Serializes PRIVMSG command")
    func serializePrivmsg() {
        let raw = IRCCommand.privmsg(target: "#channel", message: "Hello, world!").rawString

        #expect(raw == "PRIVMSG #channel :Hello, world!")
    }

    @Test("Serializes NICK command")
    func serializeNick() {
        let raw = IRCCommand.nick("PandaBot").rawString

        #expect(raw == "NICK PandaBot")
    }

    @Test("Serializes PONG response")
    func serializePong() {
        let raw = IRCCommand.pong(server: "irc.example.com").rawString

        #expect(raw == "PONG :irc.example.com")
    }

    @Test("Serializes QUIT command without message")
    func serializeQuitNoMessage() {
        let raw = IRCCommand.quit().rawString

        #expect(raw == "QUIT")
    }

    @Test("Serializes QUIT command with message")
    func serializeQuitWithMessage() {
        let raw = IRCCommand.quit(message: "See you later!").rawString

        #expect(raw == "QUIT :See you later!")
    }

    @Test("Serializes USER registration command")
    func serializeUser() {
        let raw = IRCCommand.user(username: "panda", realname: "Panda Ping Client").rawString

        #expect(raw == "USER panda 0 * :Panda Ping Client")
    }

    @Test("Serializes PRIVMSG to a user (DM)")
    func serializeDirectMessage() {
        let raw = IRCCommand.privmsg(target: "otheruser", message: "Hey there").rawString

        #expect(raw == "PRIVMSG otheruser :Hey there")
    }
}
