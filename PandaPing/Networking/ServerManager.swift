//
//  ServerManager.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation
import Observation

// MARK: - Chat Selection

/// Identifies what the user has selected in the sidebar.
enum ChatSelection: Hashable {
    case channel(serverIndex: Int, name: String)
    case privateMessage(serverIndex: Int, nickname: String)
    case serverConsole(serverIndex: Int)

    var serverIndex: Int {
        switch self {
        case .channel(let index, _), .privateMessage(let index, _), .serverConsole(let index):
            return index
        }
    }
}

// MARK: - Server Manager

/// Manages multiple IRC server connections and tracks the user's current selection.
@MainActor
@Observable
class ServerManager {
    private(set) var connections: [IRCConnection] = []

    /// The user's current sidebar selection.
    var selection: ChatSelection?

    /// Shared plugin manager. Set externally after creation.
    var pluginManager: PluginManager?

    private let transportFactory: @Sendable (IRCServer) -> any IRCTransport

    init(transportFactory: @escaping @Sendable (IRCServer) -> any IRCTransport) {
        self.transportFactory = transportFactory
    }

    convenience init() {
        self.init(transportFactory: { NWIRCTransport(server: $0) })
    }

    // MARK: - Server Management

    func addServer(_ config: IRCServer) {
        let transport = transportFactory(config)
        let connection = IRCConnection(server: config, transport: transport)
        connection.pluginManager = pluginManager
        connections.append(connection)
    }

    /// Add a server and immediately connect to it.
    func addAndConnect(_ config: IRCServer) {
        addServer(config)
        let index = connections.count - 1
        selection = .serverConsole(serverIndex: index)
        Task {
            await connections[index].connect()
        }
    }

    func removeServer(at index: Int) {
        guard connections.indices.contains(index) else { return }
        connections[index].disconnect()
        connections.remove(at: index)

        guard let current = selection else { return }
        if current.serverIndex == index {
            selection = nil
        } else if current.serverIndex > index {
            // Adjust the index to account for the removed server
            switch current {
            case .channel(let idx, let name):
                selection = .channel(serverIndex: idx - 1, name: name)
            case .privateMessage(let idx, let nick):
                selection = .privateMessage(serverIndex: idx - 1, nickname: nick)
            case .serverConsole(let idx):
                selection = .serverConsole(serverIndex: idx - 1)
            }
        }
    }

    /// The connection for the currently selected item, if any.
    var selectedConnection: IRCConnection? {
        guard let selection,
              connections.indices.contains(selection.serverIndex) else {
            return nil
        }
        return connections[selection.serverIndex]
    }
}
