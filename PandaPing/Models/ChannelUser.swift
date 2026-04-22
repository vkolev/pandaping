//
//  ChannelUser.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Foundation

/// Represents a user in an IRC channel with their mode prefix (e.g. @, +, %).
struct ChannelUser: Equatable, Identifiable {
    var id: String { nickname }

    /// The user's nickname without any mode prefix.
    var nickname: String

    /// The user's mode prefix character, if any:
    /// `@` (operator), `%` (halfop), `+` (voice).
    var modePrefix: String?

    /// Creates a ChannelUser from a prefixed nickname string (e.g. "@alice", "+bob").
    init(prefixedNick: String) {
        if let first = prefixedNick.first, "@%+".contains(first) {
            self.modePrefix = String(first)
            self.nickname = String(prefixedNick.dropFirst())
        } else {
            self.modePrefix = nil
            self.nickname = prefixedNick
        }
    }

    /// Creates a ChannelUser with just a nickname (no mode prefix).
    init(nickname: String) {
        self.nickname = nickname
        self.modePrefix = nil
    }

    /// Sort order by privilege level: ops (0), halfops (1), voice (2), regular (3).
    var sortOrder: Int {
        switch modePrefix {
        case "@": return 0
        case "%": return 1
        case "+": return 2
        default: return 3
        }
    }

    /// Display name with mode prefix, e.g. "@alice".
    var displayName: String {
        if let prefix = modePrefix {
            return prefix + nickname
        }
        return nickname
    }
}
