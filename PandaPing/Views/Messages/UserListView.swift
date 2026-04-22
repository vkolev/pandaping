//
//  UserListView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import SwiftUI

/// Displays the list of users in a channel, sorted by privilege level.
struct UserListView: View {
    let users: [ChannelUser]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "person.2")
                    .foregroundStyle(.secondary)
                Text("Users (\(users.count))")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // User list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(sortedUsers) { user in
                        userRow(user)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .frame(width: 180)
    }

    private var sortedUsers: [ChannelUser] {
        users.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
        }
    }

    private func userRow(_ user: ChannelUser) -> some View {
        HStack(spacing: 2) {
            if let prefix = user.modePrefix {
                Text(prefix)
                    .foregroundStyle(prefixColor(prefix))
                    .fontWeight(.bold)
            }
            Text(user.nickname)
                .foregroundStyle(NicknameColor.color(for: user.nickname))
        }
        .font(.system(.body, design: .monospaced))
        .padding(.vertical, 1)
    }

    private func prefixColor(_ prefix: String) -> Color {
        switch prefix {
        case "@": return .red
        case "%": return .orange
        case "+": return .green
        default: return .secondary
        }
    }
}
