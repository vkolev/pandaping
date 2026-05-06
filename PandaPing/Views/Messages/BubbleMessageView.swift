//
//  BubbleMessageView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 06.05.26.
//

import SwiftUI

struct BubbleMessageView: View {
    let messages: [IRCMessage]
    let title: String
    let subtitle: String?
    let currentNickname: String
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
                        LazyVStack(spacing: 4) {
                            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                let isOwn = message.senderUser?.nickname == currentNickname
                                let showSender = shouldShowSender(at: index)
                                BubbleRow(
                                    message: message,
                                    isOwn: isOwn,
                                    showSender: showSender,
                                    font: appSettings.messageFont,
                                    onNicknameClicked: onNicknameClicked
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: messages.count) {
                        withAnimation {
                            proxy.scrollTo(messages.count - 1, anchor: .bottom)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(messages.count - 1, anchor: .bottom)
                    }
                }
            }

            // Input field
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

    private func shouldShowSender(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index]
        let previous = messages[index - 1]
        return current.senderUser?.nickname != previous.senderUser?.nickname
    }
}

// MARK: - Bubble Row

private struct BubbleRow: View {
    let message: IRCMessage
    let isOwn: Bool
    let showSender: Bool
    let font: Font
    var onNicknameClicked: ((String) -> Void)? = nil

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        let hasBody = message.senderUser != nil

        if hasBody {
            HStack(alignment: .bottom, spacing: 6) {
                if isOwn { Spacer(minLength: 60) }

                VStack(alignment: isOwn ? .trailing : .leading, spacing: 2) {
                    if showSender, let sender = message.senderUser?.nickname, !isOwn {
                        Button {
                            onNicknameClicked?(sender)
                        } label: {
                            Text(sender)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(NicknameColor.color(for: sender))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        if message.isAction {
                            Text(actionText)
                                .font(font)
                                .italic()
                        } else {
                            Text(messageAttributedString)
                                .font(font)
                                .textSelection(.enabled)
                        }

                        Text(Self.timeFormatter.string(from: message.receivedAt))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if !isOwn { Spacer(minLength: 60) }
            }
            .padding(.top, showSender ? 4 : 0)
        } else {
            // System/server messages — centered, no bubble
            Text(message.parameters.last ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if isOwn {
            return AnyShapeStyle(Color.accentColor.opacity(0.25))
        } else {
            return AnyShapeStyle(Color.primary.opacity(0.08))
        }
    }

    private var actionText: AttributedString {
        guard let sender = message.senderUser?.nickname else {
            return MessageTextParser.styledAttributedString(for: messageText)
        }
        var senderAttr = AttributedString(sender)
        senderAttr.foregroundColor = NicknameColor.color(for: sender)
        senderAttr.inlinePresentationIntent = .stronglyEmphasized
        return senderAttr + AttributedString(" ") + MessageTextParser.styledAttributedString(for: messageText)
    }

    private var messageAttributedString: AttributedString {
        MessageTextParser.styledAttributedString(for: messageText)
    }

    private var messageText: String {
        let isNumericReply = message.command.count == 3
            && message.command.allSatisfy(\.isNumber)
        if isNumericReply && message.parameters.count > 1 {
            return message.parameters.dropFirst().joined(separator: " ")
        }
        if message.parameters.count >= 2 {
            return message.parameters.last ?? ""
        }
        return message.parameters.joined(separator: " ")
    }
}
