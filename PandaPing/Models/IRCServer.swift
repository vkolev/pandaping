//
//  IRCServer.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation

/// Configuration for an IRC server connection.
struct IRCServer {
    /// Server hostname, e.g. "irc.libera.chat"
    let hostname: String

    /// Server port (typically 6667 or 6697 for SSL)
    var port: Int = 6667

    /// The nickname to use when connecting
    var nickname: String

    /// Whether to use SSL/TLS
    var useSSL: Bool = false

    /// Channels to auto-join on connect
    var channels: [String] = []
}
