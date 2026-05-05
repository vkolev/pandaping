//
//  ClassicMessageView.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 22.04.26.
//

import AppKit
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
                SelectableMessageTextView(
                    messages: messages,
                    fontName: appSettings.messageFontName,
                    fontSize: appSettings.messageFontSize,
                    lineSpacing: appSettings.messageLineSpacing,
                    onLinkClicked: { url in
                        guard let name = url.pathComponents.last else { return }
                        switch url.host {
                        case "channel":
                            onAction?(.join(channel: "#\(name)"))
                        case "mention":
                            onNicknameClicked?(name)
                        default:
                            break
                        }
                    }
                )
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

// MARK: - NSTextView Wrapper

private struct SelectableMessageTextView: NSViewRepresentable {
    let messages: [IRCMessage]
    let fontName: String
    let fontSize: Double
    let lineSpacing: Double
    var onLinkClicked: ((URL) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkClicked: onLinkClicked)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.linkTextAttributes = [.cursor: NSCursor.pointingHand]
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.onLinkClicked = onLinkClicked

        let newString = buildFullAttributedString()
        textView.textStorage?.setAttributedString(newString)
        textView.scrollToEndOfDocument(nil)
    }

    // MARK: - Font

    private var nsFont: NSFont {
        switch MessageFont(rawValue: fontName) {
        case .sfMono, .none:
            return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        case .menlo:
            return NSFont(name: "Menlo", size: fontSize)
                ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        case .courier:
            return NSFont(name: "Courier New", size: fontSize)
                ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        case .system:
            return .systemFont(ofSize: fontSize)
        }
    }

    private func fontWithTraits(_ font: NSFont, bold: Bool, italic: Bool) -> NSFont {
        var traits = font.fontDescriptor.symbolicTraits
        if bold { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }

    // MARK: - Attributed String Builder

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "[HH:mm:ss]"
        return formatter
    }()

    private func buildFullAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = nsFont

        for (index, message) in messages.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(buildMessageRow(message, font: font))
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = lineSpacing
        result.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: result.length)
        )

        return result
    }

    private func buildMessageRow(_ message: IRCMessage, font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let secondary = NSColor.secondaryLabelColor

        let timestamp = Self.timeFormatter.string(from: message.receivedAt)
        result.append(NSAttributedString(string: timestamp, attributes: [
            .foregroundColor: secondary,
            .font: font
        ]))

        let sender = message.senderUser?.nickname

        if message.isAction {
            if let sender {
                result.append(NSAttributedString(string: " ", attributes: [.font: font]))
                result.append(nickAttributedString(sender, font: font, italic: true))
                result.append(NSAttributedString(string: " ", attributes: [.font: font]))
            }
            result.append(buildMessageBody(message, font: font, italic: true))
        } else {
            if let sender {
                result.append(NSAttributedString(string: " <", attributes: [
                    .foregroundColor: secondary, .font: font
                ]))
                result.append(nickAttributedString(sender, font: font, italic: false))
                result.append(NSAttributedString(string: "> ", attributes: [
                    .foregroundColor: secondary, .font: font
                ]))
            } else {
                result.append(NSAttributedString(string: " ", attributes: [.font: font]))
            }
            result.append(buildMessageBody(message, font: font, italic: false))
        }

        return result
    }

    private func nickAttributedString(_ nick: String, font: NSFont, italic: Bool) -> NSAttributedString {
        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(NicknameColor.color(for: nick)),
            .font: fontWithTraits(font, bold: true, italic: italic)
        ]
        if let encoded = nick.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: "pandaping://mention/\(encoded)") {
            attrs[.link] = url
        }
        return NSAttributedString(string: nick, attributes: attrs)
    }

    private func buildMessageBody(
        _ message: IRCMessage,
        font: NSFont,
        italic: Bool
    ) -> NSAttributedString {
        let text = Self.messageText(for: message)
        let segments = MessageTextParser.parse(text)
        let result = NSMutableAttributedString()

        for segment in segments {
            var attrs: [NSAttributedString.Key: Any] = [
                .font: fontWithTraits(
                    font,
                    bold: segment.bold,
                    italic: segment.italic || italic
                ),
                .foregroundColor: NSColor.labelColor
            ]

            if segment.underline {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            if let fg = segment.foregroundColor {
                attrs[.foregroundColor] = NSColor(MessageTextParser.mircColor(fg))
            }
            if let bg = segment.backgroundColor {
                attrs[.backgroundColor] = NSColor(MessageTextParser.mircColor(bg))
            }

            switch segment.kind {
            case .channel:
                if segment.foregroundColor == nil {
                    attrs[.foregroundColor] = NSColor(Color.cyan)
                }
                let name = String(segment.text.dropFirst())
                if let url = URL(string: "pandaping://channel/\(name)") {
                    attrs[.link] = url
                }
            case .mention:
                if segment.foregroundColor == nil {
                    attrs[.foregroundColor] = NSColor(Color.orange)
                }
                let name = String(segment.text.dropFirst())
                if let url = URL(string: "pandaping://mention/\(name)") {
                    attrs[.link] = url
                }
            case .link(let url):
                attrs[.link] = url
                attrs[.foregroundColor] = NSColor.linkColor
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            case .plain:
                break
            }

            result.append(NSAttributedString(string: segment.text, attributes: attrs))
        }

        return result
    }

    private static func messageText(for message: IRCMessage) -> String {
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

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var onLinkClicked: ((URL) -> Void)?

        init(onLinkClicked: ((URL) -> Void)?) {
            self.onLinkClicked = onLinkClicked
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL else { return false }
            if url.scheme == "pandaping" {
                onLinkClicked?(url)
                return true
            }
            NSWorkspace.shared.open(url)
            return true
        }
    }
}
