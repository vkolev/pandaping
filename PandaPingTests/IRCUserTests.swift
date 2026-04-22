//
//  IRCUserTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Testing
@testable import PandaPing

@Suite("IRC User Parsing")
struct IRCUserTests {

    @Test("Parses full nick!user@host prefix")
    func parseFullPrefix() {
        let user = IRCUser(prefix: "nick!user@host")

        #expect(user?.nickname == "nick")
        #expect(user?.username == "user")
        #expect(user?.hostname == "host")
    }

    @Test("Parses nick with complex hostname")
    func parseComplexHostname() {
        let user = IRCUser(prefix: "john!~john@192.168.1.100")

        #expect(user?.nickname == "john")
        #expect(user?.username == "~john")
        #expect(user?.hostname == "192.168.1.100")
    }

    @Test("Parses nick-only prefix")
    func parseNickOnly() {
        let user = IRCUser(prefix: "nick")

        #expect(user?.nickname == "nick")
        #expect(user?.username == nil)
        #expect(user?.hostname == nil)
    }

    @Test("Returns nil for empty prefix")
    func parseEmptyPrefix() {
        let user = IRCUser(prefix: "")

        #expect(user == nil)
    }

    @Test("Parses prefix with hostname containing dots")
    func parseDottedHostname() {
        let user = IRCUser(prefix: "bot!service@services.irc.example.com")

        #expect(user?.nickname == "bot")
        #expect(user?.username == "service")
        #expect(user?.hostname == "services.irc.example.com")
    }

    @Test("Returns nil for server-only prefix (no ! or @)")
    func serverPrefixReturnsNilUsernameHostname() {
        let user = IRCUser(prefix: "irc.example.com")

        // A server prefix looks like a hostname; without ! it's treated as nick-only
        #expect(user?.nickname == "irc.example.com")
        #expect(user?.username == nil)
        #expect(user?.hostname == nil)
    }

    @Test("Extracts user from a parsed IRCMessage")
    func extractUserFromMessage() {
        let raw = ":nick!user@host PRIVMSG #channel :Hello"
        let message = IRCParser.parse(raw)
        let user = message.senderUser

        #expect(user?.nickname == "nick")
        #expect(user?.username == "user")
        #expect(user?.hostname == "host")
    }

    @Test("Returns nil sender for message with no prefix")
    func noSenderForPrefixlessMessage() {
        let raw = "PING :server"
        let message = IRCParser.parse(raw)

        #expect(message.senderUser == nil)
    }
}
