//
//  IRCCommand.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation

/// Represents outgoing IRC commands and serializes them to raw IRC protocol strings.
enum IRCCommand {
    case join(channel: String)
    case part(channel: String, message: String? = nil)
    case privmsg(target: String, message: String)
    case nick(String)
    case pong(server: String)
    case kick(channel: String, nickname: String, reason: String? = nil)
    case mode(target: String, flags: String, parameter: String? = nil)
    case quit(message: String? = nil)
    case user(username: String, realname: String)
    case raw(String)

    /// The raw IRC protocol string ready to send over the wire.
    var rawString: String {
        switch self {
        case .join(let channel):
            return "JOIN \(channel)"

        case .part(let channel, let message):
            if let message {
                return "PART \(channel) :\(message)"
            }
            return "PART \(channel)"

        case .privmsg(let target, let message):
            return "PRIVMSG \(target) :\(message)"

        case .kick(let channel, let nickname, let reason):
            if let reason {
                return "KICK \(channel) \(nickname) :\(reason)"
            }
            return "KICK \(channel) \(nickname)"

        case .mode(let target, let flags, let parameter):
            if let parameter {
                return "MODE \(target) \(flags) \(parameter)"
            }
            return "MODE \(target) \(flags)"

        case .nick(let nickname):
            return "NICK \(nickname)"

        case .pong(let server):
            return "PONG :\(server)"

        case .quit(let message):
            if let message {
                return "QUIT :\(message)"
            }
            return "QUIT"

        case .user(let username, let realname):
            return "USER \(username) 0 * :\(realname)"

        case .raw(let line):
            return line
        }
    }
}
