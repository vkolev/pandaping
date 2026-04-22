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
    var nicknames: [String] = []
    var channelNames: [String] = []
    var topic: String? = nil

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
                        Text(topic)
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
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                ClassicMessageRow(message: message)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
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
        .font(.system(.body, design: .monospaced))
    }
}

// MARK: - Message Row

private struct ClassicMessageRow: View {
    let message: IRCMessage

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // Timestamp
            Text(timestamp)
                .foregroundStyle(.secondary)

            if message.isAction {
                // Action format: [HH:mm:ss] nick action text (all italic)
                if let sender = senderText {
                    Text(" ")
                    Text(sender)
                        .foregroundStyle(NicknameColor.color(for: sender))
                        .fontWeight(.medium)
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
                    Text(sender)
                        .foregroundStyle(NicknameColor.color(for: sender))
                        .fontWeight(.medium)
                    Text("> ")
                        .foregroundStyle(.secondary)
                } else {
                    Text(" ")
                }
                messageBody
            }
        }
    }

    private var timestamp: String {
        // IRC messages don't carry a local timestamp in our model,
        // so we show the current time when displayed.
        // In Phase 3 we'll add server-time (IRCv3) support.
        let formatter = DateFormatter()
        formatter.dateFormat = "[HH:mm:ss]"
        return formatter.string(from: Date())
    }

    private var senderText: String? {
        message.senderUser?.nickname
    }

    private var messageText: String {
        // For PRIVMSG, the message body is the last parameter.
        // For NOTICE and other commands, use the last parameter too.
        if message.parameters.count >= 2 {
            return message.parameters.last ?? ""
        }
        // Fallback: show all parameters joined
        return message.parameters.joined(separator: " ")
    }

    private var messageBody: some View {
        let segments = MessageTextParser.parse(messageText)
        return segments.reduce(Text("")) { result, segment in
            switch segment.kind {
            case .plain:
                return result + Text(segment.text)
            case .channel:
                return result + Text(segment.text).foregroundColor(.cyan).bold()
            case .mention:
                return result + Text(segment.text).foregroundColor(.orange).bold()
            }
        }
    }
}
