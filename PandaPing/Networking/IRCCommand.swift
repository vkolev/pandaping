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
    case quit(message: String? = nil)
    case user(username: String, realname: String)

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
        }
    }
}
