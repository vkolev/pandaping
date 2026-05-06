//
//  ContentView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var serverManager: ServerManager
    @Environment(AppSettings.self) private var appSettings
    @State private var showUserList = true

    var body: some View {
        NavigationSplitView {
            ChannelListView(manager: serverManager)
                .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 400)
        } detail: {
            if let selection = serverManager.selection,
               let connection = serverManager.selectedConnection {
                detailView(for: selection, connection: connection)
                    .id(selection)
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
            messageView(
                messages: channel?.messages ?? [],
                title: name,
                subtitle: "Connected to \(connection.serverConfig.hostname)",
                currentNickname: connection.nickname,
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
            .inspector(isPresented: $showUserList) {
                UserListView(
                    users: channel?.users ?? [],
                    currentUserIsOp: channel?.users.first { $0.nickname == connection.nickname
 }?.modePrefix == "@",
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
                    },
                    onWhois: { nick in
                        Task {
                            await connection
                                .executeAction(.serverCommand(raw: "WHOIS \(nick)"))
                        }
                    }
                )
                .inspectorColumnWidth(min: 150, ideal: 180, max: 300)
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        withAnimation {
                            showUserList.toggle()
                        }
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .help(showUserList ? "Hide User List" : "Show User List")
                }
            }

        case .privateMessage(_, let nickname):
            messageView(
                messages: connection.privateChats[nickname]?.messages ?? [],
                title: nickname,
                subtitle: "Private message on \(connection.serverConfig.hostname)",
                currentNickname: connection.nickname,
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

    @ViewBuilder
    private func messageView(
        messages: [IRCMessage],
        title: String,
        subtitle: String?,
        currentNickname: String,
        currentTarget: String? = nil,
        onAction: ((UserAction) -> Void)? = nil,
        onNicknameClicked: ((String) -> Void)? = nil,
        nicknames: [String] = [],
        channelNames: [String] = [],
        topic: String? = nil
    ) -> some View {
        switch appSettings.messageViewStyle {
        case .classic:
            ClassicMessageView(
                messages: messages,
                title: title,
                subtitle: subtitle,
                currentTarget: currentTarget,
                onAction: onAction,
                onNicknameClicked: onNicknameClicked,
                nicknames: nicknames,
                channelNames: channelNames,
                topic: topic
            )
        case .bubbles:
            BubbleMessageView(
                messages: messages,
                title: title,
                subtitle: subtitle,
                currentNickname: currentNickname,
                currentTarget: currentTarget,
                onAction: onAction,
                onNicknameClicked: onNicknameClicked,
                nicknames: nicknames,
                channelNames: channelNames,
                topic: topic
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
    .environment(AppSettings())
}

/// Minimal transport for SwiftUI previews.
private final class PreviewTransport: IRCTransport, @unchecked Sendable {
    let lines = AsyncStream<String> { $0.finish() }
    func connect() async throws {}
    func disconnect() {}
    func sendLine(_ line: String) async throws {}
}
