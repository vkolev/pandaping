//
//  ChannelListView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import SwiftUI

/// Sidebar view showing servers with their channels, plus a dedicated
/// "Private Messages" section at the bottom for active DMs.
struct ChannelListView: View {
    @Bindable var manager: ServerManager
    @Environment(AppSettings.self) private var appSettings
    @State private var showingAddServer = false
    @State private var showingJoinChannel = false
    @State private var currentActionIndex = 0
    @State private var isShowingSettings = false

    var body: some View {
        List {
            // MARK: Servers & Channels
            ForEach(Array(manager.connections.enumerated()), id: \.element.id) { index, connection in
                Section {
                    ForEach(connection.sortedChannels, id: \.name) { channel in
                        channelRow(channel, serverIndex: index)
                    }
                } header: {
                    serverHeader(connection, serverIndex: index)
                        .contextMenu {
                            if connection.state == .connected || isReconnecting(connection.state) {
                                Button {
                                    Task { await connection.gracefulDisconnect(message: appSettings.quitMessage) }
                                } label: {
                                    Label("Disconnect", systemImage: "bolt.slash")
                                }
                            } else {
                                Button {
                                    Task { await connection.connect() }
                                } label: {
                                    Label("Reconnect", systemImage: "bolt")
                                }
                            }
                            
                            Button {
                                currentActionIndex = index
                                showingJoinChannel = true
                            } label: {
                                Label("Join channel", systemImage: "bubble")
                            }

                            Divider()

                            Button(role: .destructive) {
                                manager.removeServer(at: index)
                            } label: {
                                Label("Remove Server", systemImage: "trash")
                            }
                        }
                }
            }

            // MARK: Private Messages
            if hasAnyPrivateChats {
                Section {
                    ForEach(Array(manager.connections.enumerated()), id: \.element.id) { index, connection in
                        ForEach(connection.sortedPrivateChats, id: \.name) { chat in
                            privateChatRow(chat, serverIndex: index, serverHostname: connection.serverConfig.hostname)
                        }
                    }
                } header: {
                    Label("Private Messages", systemImage: "person.2")
                        .font(.headline)
                }
            }

        }
        .listStyle(.sidebar)
        .navigationTitle("Channels")
        .toolbar {
            ToolbarItem {
                Menu {
                    Button {
                        showingAddServer = true
                    } label: {
                        Label("New Server…", systemImage: "plus")
                    }

                    if !appSettings.savedServers.isEmpty {
                        Divider()
                        ForEach(appSettings.savedServers) { saved in
                            Button {
                                manager.addAndConnect(saved.config)
                            } label: {
                                Label(saved.config.hostname, systemImage: "server.rack")
                            }
                        }
                    }
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
            }
            if DeviceInfo.isIPad {
                ToolbarItem(placement: .automatic) {
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddServer) {
            AddServerView { server in
                manager.addAndConnect(server)
            }
        }
        .sheet(isPresented: $showingJoinChannel) {
            JoinChannelView { channelToJoin in
                await manager.connections[currentActionIndex].executeAction(.join(channel: channelToJoin))
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                pluginManager: manager.pluginManager!,
                onConnectServer: { server in
                    manager.addAndConnect(server)
                }
            )
        }
    }

    // MARK: - Helpers

    private var hasAnyPrivateChats: Bool {
        manager.connections.contains { !$0.privateChats.isEmpty }
    }

    // MARK: - Subviews

    private func serverHeader(_ connection: IRCConnection, serverIndex: Int) -> some View {
        HStack {
            Circle()
                .fill(statusColor(for: connection.state))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(connection.serverConfig.hostname)
                    .font(.headline)
                if case .reconnecting(let attempt) = connection.state {
                    Text("Reconnecting (\(attempt)/5)…")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Button {
                if connection.state == .connected {
                    Task { await connection.gracefulDisconnect(message: appSettings.quitMessage) }
                } else {
                    Task { await connection.connect() }
                }
            } label: {
                Image(
                    systemName: connection.state == .connected ? "network.slash" : "network"
                )
            }
            Button {
                Task {
                    showingJoinChannel = true
                }
            } label: {
                Image(systemName: "bubble")
            }
        }
        .onTapGesture {
            manager.selection = .serverConsole(serverIndex: serverIndex)
        }
    }

    private func channelRow(_ channel: IRCChannel, serverIndex: Int) -> some View {
        @State var isHovering = false
        
        let selected = manager.selection == .channel(serverIndex: serverIndex, name: channel.name)
        
        return HStack {
                Text(channel.name)
                    .foregroundStyle(selected ? .primary : .secondary)
                Spacer()
                unreadBadge(channel.unreadCount)
            }
        .padding(2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            manager.selection = .channel(serverIndex: serverIndex, name: channel.name)
            manager.connections[serverIndex].markChannelAsRead(channel.name)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering || selected ? Color.blue.opacity(0.2) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func privateChatRow(_ chat: IRCChannel, serverIndex: Int, serverHostname: String) -> some View {
        @State var isHovering = false
        
        let selected = manager.selection == .privateMessage(serverIndex: serverIndex, nickname: chat.name)
        
        return HStack {
            VStack(alignment: .leading) {
                Text(chat.name)
                    .foregroundStyle(selected ? .primary : .secondary)
                if manager.connections.count > 1 {
                    Text(serverHostname)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            unreadBadge(chat.unreadCount)
        }
        .padding(2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            manager.selection = .privateMessage(serverIndex: serverIndex, nickname: chat.name)
            manager.connections[serverIndex].markPrivateChatAsRead(chat.name)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering || selected ? Color.blue.opacity(0.2) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button(role: .destructive) {
                if manager.selection == .privateMessage(serverIndex: serverIndex, nickname: chat.name) {
                    manager.selection = nil
                }
                manager.connections[serverIndex].closePrivateChat(for: chat.name)
            } label: {
                Label("Close Chat", systemImage: "xmark.circle")
            }
        }
    }

    @ViewBuilder
    private func unreadBadge(_ count: Int) -> some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
    }

    private func isReconnecting(_ state: ConnectionState) -> Bool {
        if case .reconnecting = state { return true }
        return false
    }

    private func statusColor(for state: ConnectionState) -> Color {
        switch state {
        case .connected: return .green
        case .connecting: return .yellow
        case .reconnecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}
