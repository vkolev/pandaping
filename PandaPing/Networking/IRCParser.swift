//
//  IRCParser.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 21.04.26.
//

import Foundation

/// Stateless parser for raw IRC protocol lines (RFC 1459).
///
/// IRC message format: `[:prefix SPACE] command [SPACE params] [SPACE :trailing]`
enum IRCParser {

    /// Parses a raw IRC line into an `IRCMessage`.
    static func parse(_ raw: String) -> IRCMessage {
        var remainder = raw[raw.startIndex...]
        var prefix: String?

        // 1. Extract optional prefix (starts with ':')
        if remainder.hasPrefix(":") {
            remainder = remainder.dropFirst() // drop the leading ':'
            if let spaceIndex = remainder.firstIndex(of: " ") {
                prefix = String(remainder[remainder.startIndex..<spaceIndex])
                remainder = remainder[remainder.index(after: spaceIndex)...]
            } else {
                // Entire line is just a prefix — unusual but handle gracefully
                return IRCMessage(prefix: String(remainder), command: "", parameters: [], raw: raw)
            }
        }

        // 2. Extract command
        let command: String
        if let spaceIndex = remainder.firstIndex(of: " ") {
            command = String(remainder[remainder.startIndex..<spaceIndex])
            remainder = remainder[remainder.index(after: spaceIndex)...]
        } else {
            // Command with no parameters
            return IRCMessage(prefix: prefix, command: String(remainder), parameters: [], raw: raw)
        }

        // 3. Extract parameters
        var parameters: [String] = []

        while !remainder.isEmpty {
            if remainder.hasPrefix(":") {
                // Trailing parameter — everything after the ':' is one parameter
                parameters.append(String(remainder.dropFirst()))
                break
            }

            if let spaceIndex = remainder.firstIndex(of: " ") {
                parameters.append(String(remainder[remainder.startIndex..<spaceIndex]))
                remainder = remainder[remainder.index(after: spaceIndex)...]
            } else {
                // Last parameter (no trailing colon, no more spaces)
                parameters.append(String(remainder))
                break
            }
        }

        // 4. Detect CTCP ACTION (/me) — format: \x01ACTION text\x01
        var isAction = false
        if command == "PRIVMSG", let trailing = parameters.last {
            let ctcpPrefix = "\u{01}ACTION "
            let ctcpSuffix = "\u{01}"
            if trailing.hasPrefix(ctcpPrefix) && trailing.hasSuffix(ctcpSuffix) {
                isAction = true
                let actionText = String(trailing.dropFirst(ctcpPrefix.count).dropLast(ctcpSuffix.count))
                var strippedParams = parameters
                strippedParams[strippedParams.count - 1] = actionText
                return IRCMessage(prefix: prefix, command: command, parameters: strippedParams, raw: raw, isAction: true)
            }
        }

        return IRCMessage(prefix: prefix, command: command, parameters: parameters, raw: raw, isAction: isAction)
    }
}
