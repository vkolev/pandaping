//
//  IRCParserTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Testing
@testable import PandaPing

// MARK: - Basic Message Parsing

@Suite("IRC Message Parsing")
struct IRCParserTests {

    // MARK: Standard Messages

    @Test("Parses PRIVMSG with user prefix")
    func parsePrivmsg() {
        let raw = ":nick!user@host PRIVMSG #channel :Hello, world!"
        let message = IRCParser.parse(raw)

        #expect(message.command == "PRIVMSG")
        #expect(message.parameters == ["#channel", "Hello, world!"])
        #expect(message.prefix == "nick!user@host")
        #expect(message.raw == raw)
    }

    @Test("Parses JOIN message")
    func parseJoin() {
        let raw = ":nick!user@host JOIN #channel"
        let message = IRCParser.parse(raw)

        #expect(message.command == "JOIN")
        #expect(message.parameters == ["#channel"])
        #expect(message.prefix == "nick!user@host")
    }

    @Test("Parses PART message with reason")
    func parsePartWithReason() {
        let raw = ":nick!user@host PART #channel :Leaving now"
        let message = IRCParser.parse(raw)

        #expect(message.command == "PART")
        #expect(message.parameters == ["#channel", "Leaving now"])
    }

    @Test("Parses PING from server")
    func parsePing() {
        let raw = "PING :irc.example.com"
        let message = IRCParser.parse(raw)

        #expect(message.command == "PING")
        #expect(message.parameters == ["irc.example.com"])
        #expect(message.prefix == nil)
    }

    @Test("Parses NICK change")
    func parseNickChange() {
        let raw = ":oldnick!user@host NICK :newnick"
        let message = IRCParser.parse(raw)

        #expect(message.command == "NICK")
        #expect(message.parameters == ["newnick"])
        #expect(message.prefix == "oldnick!user@host")
    }

    // MARK: Numeric Replies

    @Test("Parses numeric reply (001 welcome)")
    func parseNumericReply() {
        let raw = ":irc.server.com 001 mynick :Welcome to the IRC Network"
        let message = IRCParser.parse(raw)

        #expect(message.command == "001")
        #expect(message.parameters == ["mynick", "Welcome to the IRC Network"])
        #expect(message.prefix == "irc.server.com")
    }

    // MARK: Edge Cases

    @Test("Parses message with no prefix")
    func parseMessageNoPrefix() {
        let raw = "NOTICE AUTH :*** Looking up your hostname"
        let message = IRCParser.parse(raw)

        #expect(message.command == "NOTICE")
        #expect(message.prefix == nil)
        #expect(message.parameters == ["AUTH", "*** Looking up your hostname"])
    }

    @Test("Parses message with no trailing parameter")
    func parseMessageNoTrailing() {
        let raw = ":nick!user@host JOIN #channel"
        let message = IRCParser.parse(raw)

        #expect(message.command == "JOIN")
        #expect(message.parameters == ["#channel"])
    }

    @Test("Parses message with multiple middle parameters")
    func parseMultipleMiddleParams() {
        let raw = ":server 005 nick CHANTYPES=# PREFIX=(ov)@+ :are supported"
        let message = IRCParser.parse(raw)

        #expect(message.command == "005")
        #expect(message.parameters == ["nick", "CHANTYPES=#", "PREFIX=(ov)@+", "are supported"])
    }

    @Test("Parses message with empty trailing parameter")
    func parseEmptyTrailing() {
        let raw = ":nick!user@host PRIVMSG #channel :"
        let message = IRCParser.parse(raw)

        #expect(message.command == "PRIVMSG")
        #expect(message.parameters == ["#channel", ""])
    }

    @Test("Parses trailing parameter with colons inside")
    func parseTrailingWithColons() {
        let raw = ":nick!user@host PRIVMSG #channel :Check this: http://example.com"
        let message = IRCParser.parse(raw)

        #expect(message.parameters == ["#channel", "Check this: http://example.com"])
    }

    @Test("Parses server-only prefix")
    func parseServerPrefix() {
        let raw = ":irc.example.com NOTICE * :Server restarting"
        let message = IRCParser.parse(raw)

        #expect(message.prefix == "irc.example.com")
        #expect(message.command == "NOTICE")
    }

    // MARK: CTCP ACTION (/me)

    @Test("Parses CTCP ACTION as isAction with stripped markers")
    func parseCTCPAction() {
        let raw = ":nick!user@host PRIVMSG #channel :\u{01}ACTION dances around\u{01}"
        let message = IRCParser.parse(raw)

        #expect(message.isAction == true)
        #expect(message.command == "PRIVMSG")
        #expect(message.parameters == ["#channel", "dances around"])
    }

    @Test("Regular PRIVMSG is not marked as action")
    func regularPrivmsgNotAction() {
        let raw = ":nick!user@host PRIVMSG #channel :Hello there!"
        let message = IRCParser.parse(raw)

        #expect(message.isAction == false)
    }

    @Test("Non-PRIVMSG commands default to isAction false")
    func nonPrivmsgDefaultsNotAction() {
        let raw = ":nick!user@host JOIN #channel"
        let message = IRCParser.parse(raw)

        #expect(message.isAction == false)
    }

    @Test("Defaults: isHighlighted is false, channel is nil")
    func defaultFields() {
        let raw = ":nick!user@host PRIVMSG #channel :Hello"
        let message = IRCParser.parse(raw)

        #expect(message.isHighlighted == false)
        #expect(message.channel == nil)
    }
}
