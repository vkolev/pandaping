//
//  ServerManagerTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Testing
@testable import PandaPing

@Suite("Server Manager")
struct ServerManagerTests {

    @Test("Starts with no connections and no selection")
    @MainActor
    func startsEmpty() {
        let manager = ServerManager(transportFactory: { _ in MockIRCTransport() })

        #expect(manager.connections.isEmpty)
        #expect(manager.selection == nil)
    }

    @Test("Can add a server")
    @MainActor
    func addServer() {
        let manager = ServerManager(transportFactory: { _ in MockIRCTransport() })
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")

        manager.addServer(server)

        #expect(manager.connections.count == 1)
        #expect(manager.connections[0].serverConfig.hostname == "irc.test.com")
    }

    @Test("Can add multiple servers")
    @MainActor
    func addMultipleServers() {
        let manager = ServerManager(transportFactory: { _ in MockIRCTransport() })

        manager.addServer(IRCServer(hostname: "server1.com", nickname: "bot1"))
        manager.addServer(IRCServer(hostname: "server2.com", nickname: "bot2"))

        #expect(manager.connections.count == 2)
    }

    @Test("Can remove a server")
    @MainActor
    func removeServer() {
        let manager = ServerManager(transportFactory: { _ in MockIRCTransport() })
        manager.addServer(IRCServer(hostname: "irc.test.com", nickname: "testbot"))

        manager.removeServer(at: 0)

        #expect(manager.connections.isEmpty)
    }

    @Test("Clears selection when selected server is removed")
    @MainActor
    func clearsSelectionOnRemove() {
        let manager = ServerManager(transportFactory: { _ in MockIRCTransport() })
        manager.addServer(IRCServer(hostname: "irc.test.com", nickname: "testbot"))
        manager.selection = .channel(serverIndex: 0, name: "#test")

        manager.removeServer(at: 0)

        #expect(manager.selection == nil)
    }

    @Test("Adjusts channel selection index when an earlier server is removed")
    @MainActor
    func adjustsChannelSelectionOnRemove() {
        let manager = ServerManager(transportFactory: { _ in MockIRCTransport() })
        manager.addServer(IRCServer(hostname: "server1.com", nickname: "bot1"))
        manager.addServer(IRCServer(hostname: "server2.com", nickname: "bot2"))
        manager.selection = .channel(serverIndex: 1, name: "#swift")

        manager.removeServer(at: 0)

        #expect(manager.selection == .channel(serverIndex: 0, name: "#swift"))
        #expect(manager.connections[0].serverConfig.hostname == "server2.com")
    }

    @Test("Adjusts PM selection index when an earlier server is removed")
    @MainActor
    func adjustsPMSelectionOnRemove() {
        let manager = ServerManager(transportFactory: { _ in MockIRCTransport() })
        manager.addServer(IRCServer(hostname: "server1.com", nickname: "bot1"))
        manager.addServer(IRCServer(hostname: "server2.com", nickname: "bot2"))
        manager.selection = .privateMessage(serverIndex: 1, nickname: "alice")

        manager.removeServer(at: 0)

        #expect(manager.selection == .privateMessage(serverIndex: 0, nickname: "alice"))
    }

    @Test("Preserves selection when a later server is removed")
    @MainActor
    func preservesSelectionWhenLaterRemoved() {
        let manager = ServerManager(transportFactory: { _ in MockIRCTransport() })
        manager.addServer(IRCServer(hostname: "server1.com", nickname: "bot1"))
        manager.addServer(IRCServer(hostname: "server2.com", nickname: "bot2"))
        manager.selection = .channel(serverIndex: 0, name: "#swift")

        manager.removeServer(at: 1)

        #expect(manager.selection == .channel(serverIndex: 0, name: "#swift"))
    }
}
