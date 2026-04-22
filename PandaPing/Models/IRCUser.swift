//
//  IRCUser.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation

/// Represents an IRC user parsed from a message prefix.
/// A full prefix has the form `nick!user@host`.
struct IRCUser {
    let nickname: String
    let username: String?
    let hostname: String?

    /// Parses a user from an IRC prefix string.
    /// Returns `nil` if the prefix is empty.
    ///
    /// Supports formats:
    /// - `nick!user@host` (full)
    /// - `nick` (nick only)
    init?(prefix: String) {
        guard !prefix.isEmpty else { return nil }

        if let bangIndex = prefix.firstIndex(of: "!"),
           let atIndex = prefix.firstIndex(of: "@"),
           bangIndex < atIndex {
            self.nickname = String(prefix[prefix.startIndex..<bangIndex])
            self.username = String(prefix[prefix.index(after: bangIndex)..<atIndex])
            self.hostname = String(prefix[prefix.index(after: atIndex)...])
        } else {
            self.nickname = prefix
            self.username = nil
            self.hostname = nil
        }
    }
}
