//
//  IRCChannel.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation

/// Represents a joined IRC channel.
struct IRCChannel {
    /// Channel name, e.g. "#swift"
    let name: String

    /// The channel topic, if set
    var topic: String?

    /// Users currently in the channel
    var users: [ChannelUser] = []

    /// Users sorted by privilege level, then alphabetically.
    var sortedUsers: [ChannelUser] {
        users.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
        }
    }

    /// Buffer of messages received in this channel
    var messages: [IRCMessage] = []

    /// Number of unread messages in this channel
    var unreadCount: Int = 0
}
