//
//  IRCMessage.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation

/// A parsed IRC protocol message following RFC 1459 format:
/// `[:prefix] command [params] [:trailing]`
struct IRCMessage {
    /// The optional prefix (sender), e.g. "nick!user@host" or "irc.server.com"
    let prefix: String?

    /// The IRC command, e.g. "PRIVMSG", "JOIN", "001"
    let command: String

    /// The message parameters, including the trailing parameter if present
    let parameters: [String]

    /// The original raw IRC line
    let raw: String

    /// When the message was received (or created for local echoes).
    let receivedAt: Date = Date()

    /// True when the message is a CTCP ACTION (/me). The action text is stored
    /// in `parameters` with the CTCP markers stripped.
    var isAction: Bool = false

    /// True when the message contains a mention of the current user's nickname.
    /// Set by `IRCConnection` after parsing, not by the parser itself.
    var isHighlighted: Bool = false

    /// The channel this message was received in, if applicable.
    /// Set by `IRCConnection` when storing the message; `nil` for server messages
    /// or messages not yet associated with a channel.
    var channel: IRCChannel? = nil

    /// Extracts an `IRCUser` from the prefix, if present and parseable
    var senderUser: IRCUser? {
        guard let prefix else { return nil }
        return IRCUser(prefix: prefix)
    }
}
