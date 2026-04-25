//
//  IRCLogger.swift
//  PandaPing
//

import Foundation
import os

enum IRCLogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pandaping",
        category: "IRC"
    )

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "pp_ircLoggingEnabled")
    }

    static func incoming(_ line: String, server: String) {
        guard isEnabled else { return }
        logger.debug("[\(server, privacy: .public)] ← \(line, privacy: .public)")
    }

    static func outgoing(_ line: String, server: String) {
        guard isEnabled else { return }
        logger.debug("[\(server, privacy: .public)] → \(line, privacy: .public)")
    }

    static func event(_ message: String, server: String) {
        logger.info("[\(server, privacy: .public)] \(message, privacy: .public)")
    }
}
