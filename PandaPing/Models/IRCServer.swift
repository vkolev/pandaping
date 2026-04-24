//
//  IRCServer.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation

/// How the client should authenticate after connecting.
enum AuthMethod: String, CaseIterable, Identifiable {
    case none
    case sasl
    case nickserv

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:     return "None"
        case .sasl:     return "SASL"
        case .nickserv: return "NickServ"
        }
    }
}

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

    // MARK: - Authentication

    var authMethod: AuthMethod = .none

    /// Server password sent via PASS before registration.
    var serverPassword: String?

    /// Username for SASL PLAIN authentication (defaults to nickname if nil).
    var saslUsername: String?

    /// Password for SASL PLAIN authentication.
    var saslPassword: String?

    /// Password sent to NickServ after registration completes.
    var nickservPassword: String?
}
