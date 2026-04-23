//
//  LuaEngine.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Foundation
import Lua

// MARK: - Delegate Protocol

/// Callbacks that LuaEngine uses to interact with the IRC system.
/// Implemented by IRCConnection (or a test mock) to keep LuaEngine decoupled.
@MainActor
protocol LuaEngineDelegate: AnyObject {
    /// Send a message to a channel or user.
    func luaEngine(_ engine: LuaEngine, sendMessage text: String, to target: String)
    /// Send a CTCP ACTION (/me) to a channel or user.
    func luaEngine(_ engine: LuaEngine, sendAction text: String, to target: String)
    /// Return the current nickname on this connection.
    func luaEngineCurrentNickname(_ engine: LuaEngine) -> String
    /// Return the users in a channel, or nil if not joined.
    func luaEngine(_ engine: LuaEngine, usersInChannel channel: String) -> [ChannelUser]?
    /// Log a message from a plugin.
    func luaEngine(_ engine: LuaEngine, log message: String)
}

// MARK: - Lua Engine

/// Wraps a single sandboxed Lua state and exposes the PandaPing plugin API.
///
/// Each engine maintains its own command registry. When a user runs a
/// plugin command (e.g. `/dice 6`), the engine looks up the Lua handler
/// and calls it with the arguments string.
@MainActor
final class LuaEngine {

    weak var delegate: LuaEngineDelegate?

    /// Commands registered by plugins: command name -> Lua function reference.
    private(set) var registeredCommands: [String: LuaValue] = [:]

    /// Accumulated log messages (useful for testing and debugging).
    private(set) var logMessages: [String] = []

    private var L: LuaState?

    // MARK: - Lifecycle

    init() {
        let state = LuaState(libraries: .safe)
        self.L = state
        registerBridgeFunctions()
    }

    /// Shut down the Lua state. Must be called when done.
    func close() {
        registeredCommands.removeAll()
        L?.close()
        L = nil
    }

    // MARK: - Script Loading

    /// Load and execute a Lua script from a string.
    /// This is how plugins register their commands at load time.
    func loadScript(_ source: String, name: String = "<script>") throws {
        guard let L else { throw LuaEngineError.engineClosed }
        try L.load(string: source, name: name)
        try L.pcall(nargs: 0, nret: 0)
    }

    // MARK: - Command Execution

    /// Returns true if this engine handles the given command name.
    func hasCommand(_ name: String) -> Bool {
        registeredCommands[name] != nil
    }

    /// Execute a registered plugin command.
    /// - Parameters:
    ///   - name: The command name (without leading slash), e.g. "dice"
    ///   - args: The arguments string (everything after the command name)
    ///   - target: The current channel or DM target, if any
    func executeCommand(_ name: String, args: String, target: String? = nil) throws {
        guard let L else { throw LuaEngineError.engineClosed }
        guard let handler = registeredCommands[name] else {
            throw LuaEngineError.unknownCommand(name)
        }
        handler.push(onto: L)
        L.push(args)
        if let target {
            L.push(target)
        } else {
            L.pushnil()
        }
        try L.pcall(nargs: 2, nret: 0)
    }

    // MARK: - Bridge Functions

    private func registerBridgeFunctions() {
        guard let L else { return }

        // register_command(name, handler_function)
        L.push({ [weak self] state in
            let name = state.tostring(1) ?? ""
            guard !name.isEmpty, state.type(2) == .function else { return 0 }
            state.push(index: 2)
            let ref = state.popref()
            self?.registeredCommands[name] = ref
            return 0
        })
        L.setglobal(name: "register_command")

        // send_message(target, text)
        L.push({ [weak self] state in
            guard let self else { return 0 }
            let target = state.tostring(1) ?? ""
            let text = state.tostring(2) ?? ""
            guard !target.isEmpty, !text.isEmpty else { return 0 }
            self.delegate?.luaEngine(self, sendMessage: text, to: target)
            return 0
        })
        L.setglobal(name: "send_message")

        // send_action(target, text) — CTCP ACTION (/me)
        L.push({ [weak self] state in
            guard let self else { return 0 }
            let target = state.tostring(1) ?? ""
            let text = state.tostring(2) ?? ""
            guard !target.isEmpty, !text.isEmpty else { return 0 }
            self.delegate?.luaEngine(self, sendAction: text, to: target)
            return 0
        })
        L.setglobal(name: "send_action")

        // get_current_nick() -> string
        L.push({ [weak self] state in
            guard let self else {
                state.push("")
                return 1
            }
            let nick = self.delegate?.luaEngineCurrentNickname(self) ?? ""
            state.push(nick)
            return 1
        })
        L.setglobal(name: "get_current_nick")

        // get_channel_users(channel) -> table of {nickname, prefix} or nil
        L.push({ [weak self] state in
            guard let self else {
                state.pushnil()
                return 1
            }
            let channel = state.tostring(1) ?? ""
            guard let users = self.delegate?.luaEngine(self, usersInChannel: channel) else {
                state.pushnil()
                return 1
            }
            let usersData = users.map { user -> [String: String] in
                ["nickname": user.nickname, "prefix": user.modePrefix ?? ""]
            }
            state.push(usersData)
            return 1
        })
        L.setglobal(name: "get_channel_users")

        // log(message)
        L.push({ [weak self] state in
            let message = state.tostring(1) ?? ""
            self?.logMessages.append(message)
            if let self {
                self.delegate?.luaEngine(self, log: message)
            }
            return 0
        })
        L.setglobal(name: "log")

        // get_time(format?) -> string
        L.push({ state in
            let format = state.tostring(1) ?? "HH:mm:ss"
            let formatter = DateFormatter()
            formatter.dateFormat = format
            state.push(formatter.string(from: Date()))
            return 1
        })
        L.setglobal(name: "get_time")

        // Disable require() for sandboxing
        L.push({ state in
            state.push("require() is disabled in PandaPing plugins")
            return 1
        })
        L.setglobal(name: "require")
    }
}

// MARK: - Errors

enum LuaEngineError: Error, Equatable {
    case engineClosed
    case unknownCommand(String)
}
