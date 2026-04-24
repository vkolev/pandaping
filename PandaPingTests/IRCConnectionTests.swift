//
//  IRCConnectionTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Testing
@testable import PandaPing

@Suite("IRC Connection")
struct IRCConnectionTests {

    @Test("State is disconnected initially")
    @MainActor
    func initialState() {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        #expect(connection.state == .disconnected)
        #expect(connection.nickname == "testbot")
        #expect(connection.joinedChannels.isEmpty)
        #expect(connection.privateChats.isEmpty)
    }

    @Test("Sends NICK and USER on connect")
    @MainActor
    func sendsRegistrationOnConnect() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.connect()

        #expect(mock.sentLines.count >= 2)
        #expect(mock.sentLines[0] == "NICK testbot")
        #expect(mock.sentLines[1] == "USER testbot 0 * :PandaPing")
    }

    @Test("Sets state to connecting during connect")
    @MainActor
    func setsConnectingState() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.connect()

        #expect(connection.state == .connecting)
    }

    @Test("Responds to PING with PONG")
    @MainActor
    func respondsToPing() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine("PING :irc.test.com")

        #expect(mock.sentLines.contains("PONG :irc.test.com"))
    }

    @Test("Sets state to connected on 001 welcome")
    @MainActor
    func setsConnectedOnWelcome() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":irc.test.com 001 testbot :Welcome to the network")

        #expect(connection.state == .connected)
    }

    @Test("Auto-joins configured channels on 001 welcome")
    @MainActor
    func autoJoinsOnWelcome() async {
        let mock = MockIRCTransport()
        var server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        server.channels = ["#swift", "#general"]
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":irc.test.com 001 testbot :Welcome to the network")

        #expect(mock.sentLines.contains("JOIN #swift"))
        #expect(mock.sentLines.contains("JOIN #general"))
    }

    @Test("Tracks channel join from self")
    @MainActor
    func tracksOwnJoin() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")

        #expect(connection.joinedChannels["#swift"] != nil)
        #expect(connection.joinedChannels["#swift"]?.name == "#swift")
    }

    @Test("Tracks channel part from self")
    @MainActor
    func tracksOwnPart() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":testbot!user@host PART #swift :Goodbye")

        #expect(connection.joinedChannels["#swift"] == nil)
    }

    @Test("Adds other users to channel on their JOIN")
    @MainActor
    func tracksOtherUserJoin() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":alice!alice@host JOIN #swift")

        #expect(connection.joinedChannels["#swift"]?.users.contains { $0.nickname == "alice" } == true)
    }

    @Test("Stores PRIVMSG in channel messages")
    @MainActor
    func storesPrivmsg() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":alice!user@host PRIVMSG #swift :Hello there!")

        #expect(connection.joinedChannels["#swift"]?.messages.count == 1)
    }

    @Test("Increments unread count for channel messages")
    @MainActor
    func incrementsUnread() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":alice!user@host PRIVMSG #swift :Hello!")
        await connection.processLine(":alice!user@host PRIVMSG #swift :World!")

        #expect(connection.joinedChannels["#swift"]?.unreadCount == 2)
    }

    @Test("Updates nickname on self NICK change")
    @MainActor
    func updatesNickname() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host NICK :newbot")

        #expect(connection.nickname == "newbot")
    }

    // MARK: - Private Message Tests

    @Test("Creates a private chat on incoming DM")
    @MainActor
    func createsPrivateChatOnDM() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":alice!user@host PRIVMSG testbot :Hey there!")

        #expect(connection.privateChats["alice"] != nil)
        #expect(connection.privateChats["alice"]?.name == "alice")
        #expect(connection.privateChats["alice"]?.messages.count == 1)
    }

    @Test("Increments unread count for private messages")
    @MainActor
    func incrementsPrivateChatUnread() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":alice!user@host PRIVMSG testbot :Hello!")
        await connection.processLine(":alice!user@host PRIVMSG testbot :Are you there?")

        #expect(connection.privateChats["alice"]?.unreadCount == 2)
    }

    @Test("Keeps separate private chats per sender")
    @MainActor
    func separatePrivateChatsPerSender() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":alice!user@host PRIVMSG testbot :Hello from Alice")
        await connection.processLine(":bob!user@host PRIVMSG testbot :Hello from Bob")

        #expect(connection.privateChats.count == 2)
        #expect(connection.privateChats["alice"]?.messages.count == 1)
        #expect(connection.privateChats["bob"]?.messages.count == 1)
    }

    @Test("Does not create private chat for channel messages")
    @MainActor
    func channelMessageDoesNotCreatePrivateChat() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":alice!user@host PRIVMSG #swift :Hello channel!")

        #expect(connection.privateChats.isEmpty)
        #expect(connection.joinedChannels["#swift"]?.messages.count == 1)
    }

    // MARK: - Server Message Tests

    @Test("Stores NOTICE as server message")
    @MainActor
    func storesNoticeAsServerMessage() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":irc.test.com NOTICE * :*** Looking up your hostname")

        #expect(connection.serverMessages.count == 1)
        #expect(connection.serverMessages[0].command == "NOTICE")
    }

    @Test("Stores numeric replies as server messages")
    @MainActor
    func storesNumericReplies() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":irc.test.com 375 testbot :- irc.test.com Message of the Day -")
        await connection.processLine(":irc.test.com 372 testbot :- Welcome to the server!")
        await connection.processLine(":irc.test.com 376 testbot :End of /MOTD command.")

        #expect(connection.serverMessages.count == 3)
    }

    @Test("Stores 001 welcome in server messages while also changing state")
    @MainActor
    func welcomeStoredAndChangesState() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":irc.test.com 001 testbot :Welcome to the network")

        #expect(connection.state == .connected)
        #expect(connection.serverMessages.count == 1)
    }

    @Test("Does not store PING in server messages")
    @MainActor
    func doesNotStorePing() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine("PING :irc.test.com")

        #expect(connection.serverMessages.isEmpty)
    }

    // MARK: - Send User Message (Local Echo)

    @Test("sendUserMessage sends PRIVMSG and adds local echo to channel")
    @MainActor
    func sendUserMessageToChannel() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.sendUserMessage("Hello world", to: "#swift")

        #expect(mock.sentLines.contains("PRIVMSG #swift :Hello world"))
        #expect(connection.joinedChannels["#swift"]?.messages.count == 1)
        #expect(connection.joinedChannels["#swift"]?.messages.first?.senderUser?.nickname == "testbot")
    }

    @Test("sendUserMessage sends PRIVMSG and adds local echo to DM")
    @MainActor
    func sendUserMessageToDM() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.sendUserMessage("Hey alice!", to: "alice")

        #expect(mock.sentLines.contains("PRIVMSG alice :Hey alice!"))
        #expect(connection.privateChats["alice"]?.messages.count == 1)
        #expect(connection.privateChats["alice"]?.messages.first?.senderUser?.nickname == "testbot")
    }

    @Test("sendUserMessage does not increment unread count for own messages")
    @MainActor
    func localEchoDoesNotIncrementUnread() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.sendUserMessage("Hello", to: "#swift")

        #expect(connection.joinedChannels["#swift"]?.unreadCount == 0)
    }

    // MARK: - Execute User Action

    @Test("executeAction join sends JOIN command")
    @MainActor
    func executeJoin() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.executeAction(.join(channel: "#swift"))

        #expect(mock.sentLines.contains("JOIN #swift"))
    }

    @Test("executeAction part sends PART command")
    @MainActor
    func executePart() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.executeAction(.part(channel: "#swift", message: "Goodbye"))

        #expect(mock.sentLines.contains("PART #swift :Goodbye"))
    }

    @Test("executeAction privateMessage sends PRIVMSG and adds local echo")
    @MainActor
    func executePrivateMessage() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.executeAction(.privateMessage(target: "alice", text: "Hey!"))

        #expect(mock.sentLines.contains("PRIVMSG alice :Hey!"))
        #expect(connection.privateChats["alice"]?.messages.count == 1)
    }

    @Test("executeAction changeNick sends NICK command")
    @MainActor
    func executeChangeNick() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.executeAction(.changeNick("newbot"))

        #expect(mock.sentLines.contains("NICK newbot"))
    }

    @Test("executeAction quit sends QUIT and disconnects")
    @MainActor
    func executeQuit() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.executeAction(.quit(message: "Bye!"))

        #expect(mock.sentLines.contains("QUIT :Bye!"))
        #expect(connection.state == .disconnected)
    }

    @Test("executeAction serverCommand sends raw line to server")
    @MainActor
    func executeServerCommand() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.executeAction(.serverCommand(raw: "WHOIS alice"))

        #expect(mock.sentLines.contains("WHOIS alice"))
    }

    // MARK: - Highlight and Channel Enrichment

    @Test("Sets isHighlighted when message mentions our nickname")
    @MainActor
    func highlightsOwnNickname() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":alice!user@host PRIVMSG #swift :Hey testbot, how are you?")

        let msg = connection.joinedChannels["#swift"]?.messages.first
        #expect(msg?.isHighlighted == true)
    }

    @Test("Does not highlight when nickname not mentioned")
    @MainActor
    func doesNotHighlightUnrelated() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":alice!user@host PRIVMSG #swift :Hello everyone!")

        let msg = connection.joinedChannels["#swift"]?.messages.first
        #expect(msg?.isHighlighted == false)
    }

    @Test("Sets channel on stored PRIVMSG")
    @MainActor
    func setsChannelOnMessage() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":alice!user@host PRIVMSG #swift :Hello!")

        let msg = connection.joinedChannels["#swift"]?.messages.first
        #expect(msg?.channel?.name == "#swift")
    }

    @Test("Stores CTCP ACTION with isAction flag in channel")
    @MainActor
    func storesCTCPAction() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":alice!user@host PRIVMSG #swift :\u{01}ACTION waves hello\u{01}")

        let msg = connection.joinedChannels["#swift"]?.messages.first
        #expect(msg?.isAction == true)
        #expect(msg?.parameters.last == "waves hello")
    }

    @Test("sendAction sends CTCP ACTION and creates local echo with isAction")
    @MainActor
    func sendActionLocalEcho() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.sendAction("dances", to: "#swift")

        #expect(mock.sentLines.contains("PRIVMSG #swift :\u{01}ACTION dances\u{01}"))
        let msg = connection.joinedChannels["#swift"]?.messages.first
        #expect(msg?.isAction == true)
        #expect(msg?.parameters.last == "dances")
        #expect(msg?.senderUser?.nickname == "testbot")
    }

    // MARK: - NAMES (353/366) Tests

    @Test("Populates user list from 353 + 366 NAMES reply")
    @MainActor
    func namesReply() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":irc.test.com 353 testbot = #swift :@alice +bob charlie")
        await connection.processLine(":irc.test.com 366 testbot #swift :End of /NAMES list")

        let users = connection.joinedChannels["#swift"]?.users ?? []
        #expect(users.count == 3)
        #expect(users.contains { $0.nickname == "alice" && $0.modePrefix == "@" })
        #expect(users.contains { $0.nickname == "bob" && $0.modePrefix == "+" })
        #expect(users.contains { $0.nickname == "charlie" && $0.modePrefix == nil })
    }

    @Test("Accumulates multiple 353 batches before 366")
    @MainActor
    func namesMultipleBatches() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":irc.test.com 353 testbot = #swift :@alice +bob")
        await connection.processLine(":irc.test.com 353 testbot = #swift :charlie dave")
        await connection.processLine(":irc.test.com 366 testbot #swift :End of /NAMES list")

        #expect(connection.joinedChannels["#swift"]?.users.count == 4)
    }

    // MARK: - QUIT Tests

    @Test("QUIT removes user from all channels")
    @MainActor
    func quitRemovesFromAll() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":testbot!user@host JOIN #general")
        await connection.processLine(":alice!user@host JOIN #swift")
        await connection.processLine(":alice!user@host JOIN #general")

        await connection.processLine(":alice!user@host QUIT :Leaving")

        #expect(connection.joinedChannels["#swift"]?.users.contains { $0.nickname == "alice" } == false)
        #expect(connection.joinedChannels["#general"]?.users.contains { $0.nickname == "alice" } == false)
    }

    // MARK: - KICK Tests

    @Test("KICK removes other user from channel")
    @MainActor
    func kickOtherUser() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":alice!user@host JOIN #swift")
        await connection.processLine(":op!user@host KICK #swift alice :Bye")

        #expect(connection.joinedChannels["#swift"]?.users.contains { $0.nickname == "alice" } == false)
    }

    @Test("KICK of self removes channel")
    @MainActor
    func kickSelfRemovesChannel() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":op!user@host KICK #swift testbot :Bye")

        #expect(connection.joinedChannels["#swift"] == nil)
    }

    // MARK: - NICK Update in Channel Users

    @Test("NICK change updates user in all channel lists")
    @MainActor
    func nickChangeUpdatesChannelUsers() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":irc.test.com 353 testbot = #swift :@alice testbot")
        await connection.processLine(":irc.test.com 366 testbot #swift :End of /NAMES list")

        await connection.processLine(":alice!user@host NICK :alice2")

        let users = connection.joinedChannels["#swift"]?.users ?? []
        #expect(users.contains { $0.nickname == "alice2" && $0.modePrefix == "@" })
        #expect(users.contains { $0.nickname == "alice" } == false)
    }

    // MARK: - JOIN Adds ChannelUser

    @Test("JOIN from other user adds ChannelUser with no prefix")
    @MainActor
    func joinAddsChannelUser() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":alice!user@host JOIN #swift")

        let user = connection.joinedChannels["#swift"]?.users.first { $0.nickname == "alice" }
        #expect(user != nil)
        #expect(user?.modePrefix == nil)
    }

    // MARK: - Topic Tests

    @Test("332 sets channel topic on join")
    @MainActor
    func topicOnJoin() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":irc.test.com 332 testbot #swift :Welcome to #swift!")

        #expect(connection.joinedChannels["#swift"]?.topic == "Welcome to #swift!")
    }

    @Test("TOPIC command updates channel topic")
    @MainActor
    func topicChange() async {
        let mock = MockIRCTransport()
        let server = IRCServer(hostname: "irc.test.com", nickname: "testbot")
        let connection = IRCConnection(server: server, transport: mock)

        await connection.processLine(":testbot!user@host JOIN #swift")
        await connection.processLine(":irc.test.com 332 testbot #swift :Old topic")
        await connection.processLine(":alice!user@host TOPIC #swift :New topic here")

        #expect(connection.joinedChannels["#swift"]?.topic == "New topic here")
    }
}
