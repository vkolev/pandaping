//
//  ContentView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var serverManager: ServerManager

    var body: some View {
        NavigationSplitView {
            ChannelListView(manager: serverManager)
        } detail: {
            if let selection = serverManager.selection,
               let connection = serverManager.selectedConnection {
                detailView(for: selection, connection: connection)
            } else {
                ContentUnavailableView(
                    "No Channel Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Select a channel or conversation from the sidebar.")
                )
            }
        }
    }

    @ViewBuilder
    private func detailView(for selection: ChatSelection, connection: IRCConnection) -> some View {
        let serverIndex = selection.serverIndex
        switch selection {
        case .channel(_, let name):
            let channel = connection.joinedChannels[name]
            HStack(spacing: 0) {
                ClassicMessageView(
                    messages: channel?.messages ?? [],
                    title: name,
                    subtitle: "Connected to \(connection.serverConfig.hostname)",
                    currentTarget: name,
                    onAction: { action in
                        Task { await connection.executeAction(action) }
                    },
                    onNicknameClicked: { nick in
                        openPrivateChat(nick, serverIndex: serverIndex, connection: connection)
                    },
                    nicknames: (channel?.users ?? []).map(\.nickname),
                    channelNames: Array(connection.joinedChannels.keys),
                    topic: channel?.topic
                )
                Divider()
                UserListView(
                    users: channel?.users ?? [],
                    currentUserIsOp: channel?.users.first { $0.nickname == connection.nickname }?.modePrefix == "@",
                    onNicknameClicked: { nick in
                        openPrivateChat(nick, serverIndex: serverIndex, connection: connection)
                    },
                    onKick: { nick in
                        Task { await connection.executeAction(.kick(channel: name, nickname: nick, reason: nil)) }
                    },
                    onBan: { nick in
                        Task { await connection.executeAction(.ban(channel: name, nickname: nick)) }
                    },
                    onKickBan: { nick in
                        Task { await connection.executeAction(.kickBan(channel: name, nickname: nick, reason: nil)) }
                    }
                )
            }

        case .privateMessage(_, let nickname):
            ClassicMessageView(
                messages: connection.privateChats[nickname]?.messages ?? [],
                title: nickname,
                subtitle: "Private message on \(connection.serverConfig.hostname)",
                currentTarget: nickname,
                onAction: { action in
                    Task { await connection.executeAction(action) }
                },
                onNicknameClicked: { nick in
                    openPrivateChat(nick, serverIndex: serverIndex, connection: connection)
                },
                channelNames: Array(connection.joinedChannels.keys)
            )

        case .serverConsole:
            ClassicMessageView(
                messages: connection.serverMessages,
                title: connection.serverConfig.hostname,
                subtitle: "Server Console",
                onAction: { action in
                    Task { await connection.executeAction(action) }
                },
                channelNames: Array(connection.joinedChannels.keys)
            )
        }
    }

    private func openPrivateChat(_ nickname: String, serverIndex: Int, connection: IRCConnection) {
        connection.ensurePrivateChat(for: nickname)
        serverManager.selection = .privateMessage(serverIndex: serverIndex, nickname: nickname)
    }
}

#Preview {
    ContentView(serverManager: ServerManager(transportFactory: { _ in
        PreviewTransport()
    }))
}

/// Minimal transport for SwiftUI previews.
private final class PreviewTransport: IRCTransport, @unchecked Sendable {
    let lines = AsyncStream<String> { $0.finish() }
    func connect() async throws {}
    func disconnect() {}
    func sendLine(_ line: String) async throws {}
}
