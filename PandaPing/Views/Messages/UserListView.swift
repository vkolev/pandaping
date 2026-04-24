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
    var currentUserIsOp: Bool = false
    var onNicknameClicked: ((String) -> Void)? = nil
    var onKick: ((String) -> Void)? = nil
    var onBan: ((String) -> Void)? = nil
    var onKickBan: ((String) -> Void)? = nil
    var onWhois: ((String) -> Void)? = nil

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
                        UserRow(
                            user: user,
                            currentUserIsOp: currentUserIsOp,
                            prefixColor: prefixColor(user.modePrefix ?? ""),
                            onNicknameClicked: onNicknameClicked,
                            onKick: onKick,
                            onBan: onBan,
                            onKickBan: onKickBan,
                            onWhois: onWhois,
                        )
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

    private func prefixColor(_ prefix: String) -> Color {
        switch prefix {
        case "@": return .red
        case "%": return .orange
        case "+": return .green
        default: return .secondary
        }
    }
}

private struct UserRow: View {
    let user: ChannelUser
    let currentUserIsOp: Bool
    let prefixColor: Color
    var onNicknameClicked: ((String) -> Void)?
    var onKick: ((String) -> Void)?
    var onBan: ((String) -> Void)?
    var onKickBan: ((String) -> Void)?
    var onWhois: ((String) -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 2) {
            if let prefix = user.modePrefix {
                Text(prefix)
                    .foregroundStyle(prefixColor)
                    .fontWeight(.bold)
            }
            Text(user.nickname)
                .foregroundStyle(NicknameColor.color(for: user.nickname))
        }
        .font(.system(.body, design: .monospaced))
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Private Message") {
                onNicknameClicked?(user.nickname)
            }
            Button("Whois") {
                onWhois?(user.nickname)
            }
            if currentUserIsOp {
                Divider()
                Button("Kick") {
                    onKick?(user.nickname)
                }
                Button("Ban") {
                    onBan?(user.nickname)
                }
                Divider()
                Button("Kick & Ban") {
                    onKickBan?(user.nickname)
                }
            }
        }
    }
}
