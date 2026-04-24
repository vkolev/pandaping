//
//  CommandRouter.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Foundation

/// Actions that result from parsing user input in the message field.
enum UserAction: Equatable {
    case sendMessage(target: String, text: String)
    case action(target: String, text: String)
    case join(channel: String)
    case part(channel: String, message: String?)
    case privateMessage(target: String, text: String)
    case changeNick(String)
    case kick(channel: String, nickname: String, reason: String?)
    case ban(channel: String, nickname: String)
    case kickBan(channel: String, nickname: String, reason: String?)
    case quit(message: String?)
    case away(message: String?)
    case pluginCommand(command: String, args: String, target: String?)
    case serverCommand(raw: String)
}

/// Parses user input into `UserAction`s.
///
/// Slash commands (e.g. `/join #swift`) are parsed into their respective actions.
/// Plain text is routed as a `sendMessage` to the current target (channel or DM).
enum CommandRouter {

    /// Plugin command names that should be routed to the Lua engine.
    /// Updated by the plugin system when plugins are loaded/unloaded.
    static var pluginCommands: Set<String> = []

    /// Parse a raw input string into a `UserAction`, if possible.
    ///
    /// - Parameters:
    ///   - input: The raw text the user typed.
    ///   - currentTarget: The channel or nickname the user is currently viewing (nil if none).
    /// - Returns: A `UserAction`, or `nil` if the input is empty or invalid.
    static func parse(_ input: String, currentTarget: String?) -> UserAction? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Slash commands
        if trimmed.hasPrefix("/") {
            return parseCommand(trimmed, currentTarget: currentTarget)
        }

        // Regular message — requires a current target
        guard let target = currentTarget else { return nil }
        return .sendMessage(target: target, text: trimmed)
    }

    // MARK: - Private

    private static func parseCommand(_ input: String, currentTarget: String?) -> UserAction? {
        // Drop the leading "/" and split into command + args
        let withoutSlash = String(input.dropFirst())
        let parts = withoutSlash.split(separator: " ", maxSplits: 1)
        guard let commandPart = parts.first else { return nil }

        let command = commandPart.lowercased()
        let args = parts.count > 1 ? String(parts[1]) : nil

        switch command {
        case "join":
            guard let channel = args?.trimmingCharacters(in: .whitespaces),
                  !channel.isEmpty else { return nil }
            return .join(channel: channel)

        case "part":
            if let args {
                let argParts = args.split(separator: " ", maxSplits: 1)
                let channel = String(argParts[0])
                let message = argParts.count > 1 ? String(argParts[1]) : nil
                return .part(channel: channel, message: message)
            }
            // No args — use current target if it's a channel
            guard let target = currentTarget else { return nil }
            return .part(channel: target, message: nil)

        case "msg":
            guard let args else { return nil }
            let argParts = args.split(separator: " ", maxSplits: 1)
            guard argParts.count == 2 else { return nil }
            return .privateMessage(target: String(argParts[0]), text: String(argParts[1]))

        case "me":
            guard let actionText = args?.trimmingCharacters(in: .whitespaces),
                  !actionText.isEmpty,
                  let target = currentTarget else { return nil }
            return .action(target: target, text: actionText)

        case "nick":
            guard let newNick = args?.trimmingCharacters(in: .whitespaces),
                  !newNick.isEmpty else { return nil }
            return .changeNick(newNick)

        case "kick":
            guard let args else { return nil }
            let argParts = args.split(separator: " ", maxSplits: 1)
            guard !argParts.isEmpty else { return nil }
            let nick = String(argParts[0])
            let reason = argParts.count > 1 ? String(argParts[1]) : nil
            guard let target = currentTarget else { return nil }
            return .kick(channel: target, nickname: nick, reason: reason)

        case "ban":
            guard let nick = args?.trimmingCharacters(in: .whitespaces),
                  !nick.isEmpty,
                  let target = currentTarget else { return nil }
            return .ban(channel: target, nickname: nick)

        case "kickban":
            guard let args else { return nil }
            let argParts = args.split(separator: " ", maxSplits: 1)
            guard !argParts.isEmpty else { return nil }
            let nick = String(argParts[0])
            let reason = argParts.count > 1 ? String(argParts[1]) : nil
            guard let target = currentTarget else { return nil }
            return .kickBan(channel: target, nickname: nick, reason: reason)

        case "quit":
            return .quit(message: args)

        case "away":
            return .away(message: args)

        case "back":
            return .away(message: nil)

        default:
            if pluginCommands.contains(command) {
                return .pluginCommand(command: command, args: args ?? "", target: currentTarget)
            }
            let raw = args.map { "\(command.uppercased()) \($0)" } ?? command.uppercased()
            return .serverCommand(raw: raw)
        }
    }
}
