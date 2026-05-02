//
//  ClassicMessageView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import SwiftUI

/// Displays IRC messages in a classic text-based style:
/// `[HH:MM:SS] <nick> message text`
///
/// Used for channel messages, private chats, and server console logs.
struct ClassicMessageView: View {
    let messages: [IRCMessage]
    let title: String
    let subtitle: String?
    var currentTarget: String? = nil
    var onAction: ((UserAction) -> Void)? = nil
    var onNicknameClicked: ((String) -> Void)? = nil
    var nicknames: [String] = []
    var channelNames: [String] = []
    var topic: String? = nil

    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    if let topic, !topic.isEmpty {
                        Text("—")
                            .foregroundStyle(.tertiary)
                        ClickableTextView(text: topic)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Messages
            if messages.isEmpty {
                Spacer()
                Text("No messages yet")
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: appSettings.messageLineSpacing) {
                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                ClassicMessageRow(
                                    message: message,
                                    onNicknameClicked: onNicknameClicked
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        if !messages.isEmpty {
                            proxy.scrollTo(messages.count - 1, anchor: .bottom)
                        }
                    }
                    .onChange(of: messages.count) { _, newCount in
                        if newCount > 0 {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                }
            }

            // Input field (not shown for server console)
            if let onAction {
                Divider()
                MessageInputView(
                    currentTarget: currentTarget,
                    onAction: onAction,
                    nicknames: nicknames,
                    channelNames: channelNames
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .font(appSettings.messageFont)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "pandaping",
                  let name = url.pathComponents.last else {
                return .systemAction
            }
            switch url.host {
            case "channel":
                onAction?(.join(channel: "#\(name)"))
                return .handled
            case "mention":
                onNicknameClicked?(name)
                return .handled
            default:
                return .systemAction
            }
        })
    }
}

// MARK: - Message Row

private struct ClassicMessageRow: View {
    let message: IRCMessage
    var onNicknameClicked: ((String) -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // Timestamp
            Text(timestamp)
                .foregroundStyle(.secondary)

            if message.isAction {
                // Action format: [HH:mm:ss] nick action text (all italic)
                if let sender = senderText {
                    Text(" ")
                    nickButton(sender)
                        .italic()
                    Text(" ")
                }
                messageBody
                    .italic()
            } else {
                // Normal format: [HH:mm:ss] <nick> message text
                if let sender = senderText {
                    Text(" <")
                        .foregroundStyle(.secondary)
                    nickButton(sender)
                    Text("> ")
                        .foregroundStyle(.secondary)
                } else {
                    Text(" ")
                }
                messageBody
            }
        }
    }

    private func nickButton(_ nick: String) -> some View {
        Text(nick)
            .foregroundStyle(NicknameColor.color(for: nick))
            .fontWeight(.medium)
            .onTapGesture {
                onNicknameClicked?(nick)
            }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "[HH:mm:ss]"
        return formatter
    }()

    private var timestamp: String {
        Self.timeFormatter.string(from: message.receivedAt)
    }

    private var senderText: String? {
        message.senderUser?.nickname
    }

    private var isNumericReply: Bool {
        message.command.count == 3 && message.command.allSatisfy(\.isNumber)
    }

    private var messageText: String {
        if isNumericReply && message.parameters.count > 1 {
            return message.parameters.dropFirst().joined(separator: " ")
        }
        if message.parameters.count >= 2 {
            return message.parameters.last ?? ""
        }
        return message.parameters.joined(separator: " ")
    }

    private var messageBody: Text {
        let attributed = MessageTextParser.styledAttributedString(for: messageText)
        return Text(attributed)
    }
}
