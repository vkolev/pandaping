//
//  PluginInfo.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 23.04.26.
//

import Foundation

/// Metadata and state for a single loaded plugin.
struct PluginInfo: Identifiable {
    /// Unique identifier — the filename, e.g. "dice.lua".
    let id: String
    /// URL of the `.lua` file on disk.
    let fileURL: URL
    /// Human-readable name, parsed from `-- Plugin:` header or derived from filename.
    var name: String
    /// Brief description, parsed from `-- Description:` header.
    var description: String
    /// Version string, parsed from `-- Version:` header.
    var version: String
    /// Whether the user has enabled this plugin.
    var isEnabled: Bool
    /// Commands this plugin registered after loading.
    var commands: [String]
    /// Load error message, if any.
    var error: String?

    // MARK: - Metadata Parsing

    /// Parse plugin metadata from the Lua source file header comments.
    ///
    /// Expects lines like:
    /// ```
    /// -- Plugin: dice
    /// -- Description: Roll a dice
    /// -- Version: 1.0
    /// ```
    static func parseMetadata(from source: String, fileURL: URL, isEnabled: Bool = true) -> PluginInfo {
        var name = fileURL.deletingPathExtension().lastPathComponent
        var description = ""
        var version = ""

        for line in source.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Stop parsing after the first non-comment, non-empty line
            if !trimmed.isEmpty && !trimmed.hasPrefix("--") {
                break
            }

            if let value = extractHeaderValue(trimmed, key: "Plugin") {
                name = value
            } else if let value = extractHeaderValue(trimmed, key: "Description") {
                description = value
            } else if let value = extractHeaderValue(trimmed, key: "Version") {
                version = value
            }
        }

        return PluginInfo(
            id: fileURL.lastPathComponent,
            fileURL: fileURL,
            name: name,
            description: description,
            version: version,
            isEnabled: isEnabled,
            commands: [],
            error: nil
        )
    }

    /// Extract the value for a `-- Key: value` header line.
    private static func extractHeaderValue(_ line: String, key: String) -> String? {
        let prefix = "-- \(key):"
        guard line.hasPrefix(prefix) else { return nil }
        let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
