//
//  PluginManager.swift
//  PandaPing
//
//  Created by Vladimir Kolev on 23.04.26.
//

import Foundation
import Observation

/// Manages the discovery, loading, and lifecycle of Lua plugins.
///
/// Scans a local directory for `.lua` files, loads each enabled plugin in its own
/// isolated `LuaEngine`, and coordinates command execution across all loaded plugins.
@MainActor
@Observable
final class PluginManager {

    /// All discovered plugins (enabled and disabled).
    private(set) var plugins: [PluginInfo] = []

    /// Lua engines for enabled, successfully loaded plugins.  plugin ID → engine.
    private var engines: [String: LuaEngine] = [:]

    /// The directory on disk where plugin `.lua` files are stored.
    let pluginsDirectory: URL

    /// Whether to install bundled example plugins on first launch.
    private let installBundledPlugins: Bool

    /// UserDefaults key for persisting the set of disabled plugin filenames.
    static let disabledPluginsKey = "disabledPlugins"

    // MARK: - Lifecycle

    init(pluginsDirectory: URL? = nil) {
        self.pluginsDirectory = pluginsDirectory ?? Self.defaultPluginsDirectory
        // Only install bundled plugins when using the default directory (i.e. real app usage)
        self.installBundledPlugins = (pluginsDirectory == nil)
    }

    /// The default plugins directory for the current platform.
    static var defaultPluginsDirectory: URL {
        #if os(iOS)
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #else
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PandaPing")
        #endif
        return base.appendingPathComponent("Plugins")
    }

    // MARK: - Scanning & Loading

    /// Scan the plugins directory for `.lua` files and load all enabled plugins.
    func scanAndLoad() {
        ensureDirectoryExists()
        if installBundledPlugins {
            installBundledPluginsIfNeeded()
        }

        let fileManager = FileManager.default
        let disabledSet = disabledPluginIDs()

        guard let contents = try? fileManager.contentsOfDirectory(
            at: pluginsDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            plugins = []
            return
        }

        let luaFiles = contents.filter { $0.pathExtension == "lua" }

        // Unload all existing engines first
        for id in engines.keys {
            engines[id]?.close()
        }
        engines.removeAll()
        plugins.removeAll()

        for fileURL in luaFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let isEnabled = !disabledSet.contains(fileURL.lastPathComponent)
            var info = PluginInfo.parseMetadata(from: source, fileURL: fileURL, isEnabled: isEnabled)

            if isEnabled {
                do {
                    let engine = LuaEngine()
                    try engine.loadScript(source, name: info.id)
                    info.commands = Array(engine.registeredCommands.keys).sorted()
                    engines[info.id] = engine
                } catch {
                    info.error = error.localizedDescription
                }
            }

            plugins.append(info)
        }

        updateRouterCommands()
    }

    /// Load (or reload) a single plugin by ID.
    func loadPlugin(_ id: String) throws {
        guard let index = plugins.firstIndex(where: { $0.id == id }) else { return }

        // Close existing engine if any
        engines[id]?.close()
        engines.removeValue(forKey: id)
        plugins[index].error = nil
        plugins[index].commands = []

        let source = try String(contentsOf: plugins[index].fileURL, encoding: .utf8)
        let engine = LuaEngine()
        try engine.loadScript(source, name: id)
        plugins[index].commands = Array(engine.registeredCommands.keys).sorted()
        engines[id] = engine

        updateRouterCommands()
    }

    /// Unload a plugin, closing its engine.
    func unloadPlugin(_ id: String) {
        engines[id]?.close()
        engines.removeValue(forKey: id)

        if let index = plugins.firstIndex(where: { $0.id == id }) {
            plugins[index].commands = []
            plugins[index].error = nil
        }

        updateRouterCommands()
    }

    /// Toggle a plugin's enabled state, persisting the change.
    func togglePlugin(_ id: String) {
        guard let index = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[index].isEnabled.toggle()

        // Persist
        var disabled = disabledPluginIDs()
        if plugins[index].isEnabled {
            disabled.remove(id)
        } else {
            disabled.insert(id)
        }
        UserDefaults.standard.set(Array(disabled), forKey: Self.disabledPluginsKey)

        // Load or unload
        if plugins[index].isEnabled {
            try? loadPlugin(id)
        } else {
            unloadPlugin(id)
        }
    }

    /// Import a plugin from an external URL into the plugins directory.
    ///
    /// Copies the file, then rescans so the new plugin is immediately available.
    /// Overwrites any existing plugin with the same filename.
    func importPlugin(from sourceURL: URL) throws {
        guard sourceURL.pathExtension == "lua" else {
            throw PluginImportError.notLuaFile
        }

        let filename = sourceURL.lastPathComponent
        let destination = pluginsDirectory.appendingPathComponent(filename)
        let fm = FileManager.default

        // Remove existing file if present (overwrite)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }

        try fm.copyItem(at: sourceURL, to: destination)
        reloadAll()
    }

    /// Unload all plugins, rescan directory, and reload enabled ones.
    func reloadAll() {
        for engine in engines.values {
            engine.close()
        }
        engines.removeAll()
        plugins.removeAll()
        scanAndLoad()
    }

    // MARK: - Command Execution

    /// Execute a plugin command by name.
    ///
    /// Finds the engine that registered the command, temporarily sets its delegate
    /// to the provided connection, executes the command, then clears the delegate.
    func executeCommand(
        _ name: String,
        args: String,
        target: String?,
        delegate: LuaEngineDelegate
    ) throws {
        guard let (_, engine) = engines.first(where: { $0.value.hasCommand(name) }) else {
            throw LuaEngineError.unknownCommand(name)
        }
        engine.delegate = delegate
        defer { engine.delegate = nil }
        try engine.executeCommand(name, args: args, target: target)
    }

    // MARK: - Private

    /// Sync `CommandRouter.pluginCommands` from all loaded engines.
    private func updateRouterCommands() {
        var commands = Set<String>()
        for engine in engines.values {
            commands.formUnion(engine.registeredCommands.keys)
        }
        CommandRouter.pluginCommands = commands
    }

    /// Ensure the plugins directory exists on disk.
    private func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: pluginsDirectory.path) {
            try? fm.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)
        }
    }

    /// Read the set of disabled plugin IDs from UserDefaults.
    private func disabledPluginIDs() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: Self.disabledPluginsKey) ?? []
        return Set(array)
    }

    /// Copy bundled example plugins into the plugins directory if it's empty.
    private func installBundledPluginsIfNeeded() {
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: pluginsDirectory, includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "lua" } ?? []
        guard existing.isEmpty else { return }

        let bundledPlugins = ["dice", "echo", "time"]
        for name in bundledPlugins {
            guard let sourceURL = Bundle.main.url(forResource: name, withExtension: "lua") else { continue }
            let dest = pluginsDirectory.appendingPathComponent("\(name).lua")
            try? fm.copyItem(at: sourceURL, to: dest)
        }
    }
}

/// Errors that can occur when importing a plugin file.
enum PluginImportError: LocalizedError {
    case notLuaFile

    var errorDescription: String? {
        switch self {
        case .notLuaFile:
            return "Only .lua files can be imported as plugins."
        }
    }
}
