//
//  IRCConnection.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation
import Observation

// MARK: - Connection State

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

// MARK: - IRC Connection

/// Manages a single IRC server connection. Handles the IRC protocol handshake,
/// automatic PING/PONG, channel auto-join, and tracks channel/message state.
@MainActor
@Observable
class IRCConnection: Identifiable {
    let id = UUID()
    let serverConfig: IRCServer

    private(set) var state: ConnectionState = .disconnected
    private(set) var joinedChannels: [String: IRCChannel] = [:]
    private(set) var privateChats: [String: IRCChannel] = [:]
    private(set) var serverMessages: [IRCMessage] = []
    private(set) var nickname: String

    private let transport: any IRCTransport
    private var processingTask: Task<Void, Never>?
    private var pendingNames: [String: [ChannelUser]] = [:]

    init(server: IRCServer, transport: any IRCTransport) {
        self.serverConfig = server
        self.nickname = server.nickname
        self.transport = transport
    }

    // MARK: - Connection Lifecycle

    func connect() async {
        state = .connecting
        do {
            try await transport.connect()
            try await transport.sendLine(IRCCommand.nick(nickname).rawString)
            try await transport.sendLine(IRCCommand.user(username: nickname, realname: "PandaPing").rawString)
            startProcessing()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func disconnect() {
        processingTask?.cancel()
        processingTask = nil
        transport.disconnect()
        state = .disconnected
    }

    func send(_ command: IRCCommand) async {
        try? await transport.sendLine(command.rawString)
    }

    /// Sorted list of joined channels for UI display.
    var sortedChannels: [IRCChannel] {
        joinedChannels.values.sorted { $0.name < $1.name }
    }

    /// Sorted list of active private chats for UI display.
    var sortedPrivateChats: [IRCChannel] {
        privateChats.values.sorted { $0.name < $1.name }
    }

    /// Reset the unread count for a specific channel.
    func markChannelAsRead(_ channelName: String) {
        joinedChannels[channelName]?.unreadCount = 0
    }

    /// Reset the unread count for a private chat.
    func markPrivateChatAsRead(_ nickname: String) {
        privateChats[nickname]?.unreadCount = 0
    }

    // MARK: - User Actions

    /// Send a chat message to a target (channel or nickname) and add a local echo,
    /// since IRC servers don't echo our own PRIVMSG back to us.
    func sendUserMessage(_ text: String, to target: String) async {
        try? await transport.sendLine(IRCCommand.privmsg(target: target, message: text).rawString)

        // Build a local echo message that looks like it came from us
        let echoRaw = ":\(nickname)!local@host PRIVMSG \(target) :\(text)"
        var echoMessage = IRCParser.parse(echoRaw)

        if joinedChannels[target] != nil {
            echoMessage.channel = joinedChannels[target]
            joinedChannels[target]?.messages.append(echoMessage)
            // Don't increment unread for our own messages
        } else {
            // Private message — create the DM entry if needed
            if privateChats[target] == nil {
                privateChats[target] = IRCChannel(name: target)
            }
            echoMessage.channel = privateChats[target]
            privateChats[target]?.messages.append(echoMessage)
        }
    }

    /// Send a CTCP ACTION (/me) to a target and add a local echo.
    func sendAction(_ text: String, to target: String) async {
        let ctcpMessage = "\u{01}ACTION \(text)\u{01}"
        try? await transport.sendLine(IRCCommand.privmsg(target: target, message: ctcpMessage).rawString)

        // Build a local echo with isAction flag
        let echoRaw = ":\(nickname)!local@host PRIVMSG \(target) :\(ctcpMessage)"
        var echoMessage = IRCParser.parse(echoRaw)
        // Parser already detects CTCP ACTION and sets isAction + strips markers

        if joinedChannels[target] != nil {
            echoMessage.channel = joinedChannels[target]
            joinedChannels[target]?.messages.append(echoMessage)
        } else {
            if privateChats[target] == nil {
                privateChats[target] = IRCChannel(name: target)
            }
            echoMessage.channel = privateChats[target]
            privateChats[target]?.messages.append(echoMessage)
        }
    }

    /// Execute a parsed user action (from CommandRouter).
    func executeAction(_ action: UserAction) async {
        switch action {
        case .sendMessage(let target, let text):
            await sendUserMessage(text, to: target)

        case .action(let target, let text):
            await sendAction(text, to: target)

        case .join(let channel):
            await send(.join(channel: channel))

        case .part(let channel, let message):
            await send(.part(channel: channel, message: message))

        case .privateMessage(let target, let text):
            await sendUserMessage(text, to: target)

        case .changeNick(let newNick):
            await send(.nick(newNick))

        case .quit(let message):
            await send(.quit(message: message))
            disconnect()

        case .unknown:
            break
        }
    }

    // MARK: - Line Processing (internal for testability)

    func processLine(_ line: String) async {
        let message = IRCParser.parse(line)
        await handleMessage(message)
    }

    // MARK: - Private

    private func startProcessing() {
        processingTask = Task { [weak self, transport] in
            for await line in transport.lines {
                guard !Task.isCancelled else { break }
                await self?.processLine(line)
            }
            if let self, self.state != .disconnected {
                self.state = .disconnected
            }
        }
    }

    private func handleMessage(_ message: IRCMessage) async {
        switch message.command {
        case "PING":
            // Auto-respond, don't log
            let server = message.parameters.first ?? ""
            try? await transport.sendLine(IRCCommand.pong(server: server).rawString)

        case "001":
            state = .connected
            serverMessages.append(message)
            for channel in serverConfig.channels {
                try? await transport.sendLine(IRCCommand.join(channel: channel).rawString)
            }

        case "JOIN":
            guard let channel = message.parameters.first else { break }
            let sender = message.senderUser
            if sender?.nickname == nickname {
                joinedChannels[channel] = IRCChannel(name: channel)
            } else if let senderNick = sender?.nickname {
                joinedChannels[channel]?.users.append(ChannelUser(nickname: senderNick))
            }

        case "PART":
            guard let channel = message.parameters.first else { break }
            let sender = message.senderUser
            if sender?.nickname == nickname {
                joinedChannels.removeValue(forKey: channel)
            } else if let senderNick = sender?.nickname {
                joinedChannels[channel]?.users.removeAll { $0.nickname == senderNick }
            }

        case "353":
            // RPL_NAMREPLY — accumulate user list for a channel
            guard message.parameters.count >= 4 else { break }
            let channel = message.parameters[2]
            let nicks = message.parameters[3].split(separator: " ").map { ChannelUser(prefixedNick: String($0)) }
            pendingNames[channel, default: []].append(contentsOf: nicks)

        case "366":
            // RPL_ENDOFNAMES — move accumulated names into channel
            guard message.parameters.count >= 2 else { break }
            let channel = message.parameters[1]
            if let users = pendingNames.removeValue(forKey: channel) {
                joinedChannels[channel]?.users = users
            }

        case "332":
            // RPL_TOPIC — server sends the channel topic on join
            guard message.parameters.count >= 3 else { break }
            let channel = message.parameters[1]
            joinedChannels[channel]?.topic = message.parameters[2]

        case "TOPIC":
            // A user changed the channel topic
            guard let channel = message.parameters.first,
                  message.parameters.count >= 2 else { break }
            joinedChannels[channel]?.topic = message.parameters[1]

        case "QUIT":
            guard let senderNick = message.senderUser?.nickname else { break }
            for key in joinedChannels.keys {
                joinedChannels[key]?.users.removeAll { $0.nickname == senderNick }
            }

        case "KICK":
            guard let channel = message.parameters.first,
                  message.parameters.count >= 2 else { break }
            let kickedNick = message.parameters[1]
            if kickedNick == nickname {
                joinedChannels.removeValue(forKey: channel)
            } else {
                joinedChannels[channel]?.users.removeAll { $0.nickname == kickedNick }
            }

        case "PRIVMSG":
            guard let target = message.parameters.first else { break }
            var enriched = message
            // Check if the message text mentions our nickname
            let body = message.parameters.last ?? ""
            enriched.isHighlighted = body.localizedCaseInsensitiveContains(nickname)

            if joinedChannels[target] != nil {
                // Channel message
                enriched.channel = joinedChannels[target]
                joinedChannels[target]?.messages.append(enriched)
                joinedChannels[target]?.unreadCount += 1
            } else if target == nickname, let senderNick = message.senderUser?.nickname {
                // Private message to us — file under sender's nickname
                if privateChats[senderNick] == nil {
                    privateChats[senderNick] = IRCChannel(name: senderNick)
                }
                enriched.channel = privateChats[senderNick]
                privateChats[senderNick]?.messages.append(enriched)
                privateChats[senderNick]?.unreadCount += 1
            }

        case "NICK":
            guard let newNick = message.parameters.first else { break }
            let oldNick = message.senderUser?.nickname
            if oldNick == nickname {
                nickname = newNick
            }
            // Update in all channel user lists
            if let oldNick {
                for key in joinedChannels.keys {
                    if let idx = joinedChannels[key]?.users.firstIndex(where: { $0.nickname == oldNick }) {
                        joinedChannels[key]?.users[idx].nickname = newNick
                    }
                }
            }

        default:
            // All other messages (NOTICE, numeric replies, MOTD, errors) → server log
            serverMessages.append(message)
        }
    }
}
