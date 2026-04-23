//
//  PluginManagerTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 23.04.26.
//

import Testing
import Foundation
@testable import PandaPing

// MARK: - Tests

@Suite("Plugin Manager")
struct PluginManagerTests {

    /// Create a temporary directory with plugin files for testing.
    private func makeTempPluginsDir(files: [String: String]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PandaPingTests-\(UUID().uuidString)")
            .appendingPathComponent("Plugins")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for (name, content) in files {
            let fileURL = dir.appendingPathComponent(name)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        return dir
    }

    /// Clean up a temporary directory.
    private func cleanup(_ dir: URL) {
        // Go up to the UUID directory and remove it entirely
        let parent = dir.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: parent)
    }

    // MARK: - PluginInfo Metadata Parsing

    @Test("Parses plugin metadata from header comments")
    func parseMetadata() {
        let source = """
        -- Plugin: dice
        -- Description: Roll a dice
        -- Version: 1.0

        register_command("dice", function(args, target)
            send_message(target, "rolled")
        end)
        """

        let url = URL(fileURLWithPath: "/tmp/dice.lua")
        let info = PluginInfo.parseMetadata(from: source, fileURL: url)

        #expect(info.id == "dice.lua")
        #expect(info.name == "dice")
        #expect(info.description == "Roll a dice")
        #expect(info.version == "1.0")
        #expect(info.isEnabled == true)
        #expect(info.commands.isEmpty)
        #expect(info.error == nil)
    }

    @Test("Uses filename when no metadata headers present")
    func parseMetadataFallback() {
        let source = """
        register_command("test", function() end)
        """

        let url = URL(fileURLWithPath: "/tmp/my_plugin.lua")
        let info = PluginInfo.parseMetadata(from: source, fileURL: url)

        #expect(info.name == "my_plugin")
        #expect(info.description == "")
        #expect(info.version == "")
    }

    // MARK: - Scanning

    @Test("Scans directory and discovers plugin files")
    @MainActor
    func scanFindsPlugins() throws {
        let dir = try makeTempPluginsDir(files: [
            "dice.lua": """
            -- Plugin: dice
            -- Description: Roll a dice
            register_command("dice", function(args) end)
            """,
            "time.lua": """
            -- Plugin: time
            register_command("time", function(args) end)
            """,
            "readme.txt": "not a plugin"
        ])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        #expect(manager.plugins.count == 2)
        // Sorted by filename
        #expect(manager.plugins[0].id == "dice.lua")
        #expect(manager.plugins[1].id == "time.lua")
    }

    @Test("Scan handles empty directory")
    @MainActor
    func scanEmptyDirectory() throws {
        let dir = try makeTempPluginsDir(files: [:])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        #expect(manager.plugins.isEmpty)
    }

    // MARK: - Loading

    @Test("Loads plugins and registers their commands")
    @MainActor
    func loadRegistersCommands() throws {
        let dir = try makeTempPluginsDir(files: [
            "dice.lua": """
            -- Plugin: dice
            register_command("dice", function(args) end)
            register_command("roll", function(args) end)
            """
        ])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        #expect(manager.plugins.count == 1)
        #expect(manager.plugins[0].commands.contains("dice"))
        #expect(manager.plugins[0].commands.contains("roll"))
        #expect(manager.plugins[0].error == nil)
    }

    @Test("Records error for plugins with syntax errors")
    @MainActor
    func loadWithSyntaxError() throws {
        let dir = try makeTempPluginsDir(files: [
            "bad.lua": """
            -- Plugin: bad
            this is not valid lua {{{
            """
        ])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        #expect(manager.plugins.count == 1)
        #expect(manager.plugins[0].error != nil)
        #expect(manager.plugins[0].commands.isEmpty)
    }

    // MARK: - Unloading

    @Test("Unloading a plugin removes its commands")
    @MainActor
    func unloadRemovesCommands() throws {
        let dir = try makeTempPluginsDir(files: [
            "dice.lua": """
            register_command("dice", function(args) end)
            """
        ])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        #expect(CommandRouter.pluginCommands.contains("dice"))

        manager.unloadPlugin("dice.lua")

        #expect(manager.plugins[0].commands.isEmpty)
        #expect(!CommandRouter.pluginCommands.contains("dice"))
    }

    // MARK: - Enable/Disable

    @Test("Toggling a plugin disables and unloads it")
    @MainActor
    func toggleDisable() throws {
        let dir = try makeTempPluginsDir(files: [
            "dice.lua": """
            register_command("dice", function(args) end)
            """
        ])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }
        let savedDefaults = UserDefaults.standard.stringArray(forKey: PluginManager.disabledPluginsKey)
        defer { UserDefaults.standard.set(savedDefaults, forKey: PluginManager.disabledPluginsKey) }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        #expect(manager.plugins[0].isEnabled == true)
        #expect(CommandRouter.pluginCommands.contains("dice"))

        manager.togglePlugin("dice.lua")

        #expect(manager.plugins[0].isEnabled == false)
        #expect(!CommandRouter.pluginCommands.contains("dice"))

        // Check UserDefaults
        let disabled = UserDefaults.standard.stringArray(forKey: PluginManager.disabledPluginsKey) ?? []
        #expect(disabled.contains("dice.lua"))
    }

    @Test("Toggling a disabled plugin re-enables and reloads it")
    @MainActor
    func toggleEnable() throws {
        let dir = try makeTempPluginsDir(files: [
            "dice.lua": """
            register_command("dice", function(args) end)
            """
        ])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }
        let savedDefaults = UserDefaults.standard.stringArray(forKey: PluginManager.disabledPluginsKey)
        defer { UserDefaults.standard.set(savedDefaults, forKey: PluginManager.disabledPluginsKey) }

        // Pre-disable via UserDefaults
        UserDefaults.standard.set(["dice.lua"], forKey: PluginManager.disabledPluginsKey)

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        #expect(manager.plugins[0].isEnabled == false)
        #expect(!CommandRouter.pluginCommands.contains("dice"))

        manager.togglePlugin("dice.lua")

        #expect(manager.plugins[0].isEnabled == true)
        #expect(CommandRouter.pluginCommands.contains("dice"))
    }

    // MARK: - Command Execution

    @Test("Executes a plugin command through the correct engine")
    @MainActor
    func executeCommand() throws {
        let dir = try makeTempPluginsDir(files: [
            "greet.lua": """
            register_command("greet", function(args, target)
                if target then
                    send_message(target, "Hello " .. args)
                end
            end)
            """
        ])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        let delegate = MockLuaEngineDelegate()
        try manager.executeCommand("greet", args: "world", target: "#test", delegate: delegate)

        #expect(delegate.sentMessages.count == 1)
        #expect(delegate.sentMessages[0].text == "Hello world")
        #expect(delegate.sentMessages[0].target == "#test")
    }

    @Test("Throws when executing an unknown command")
    @MainActor
    func executeUnknownCommand() throws {
        let dir = try makeTempPluginsDir(files: [:])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        let delegate = MockLuaEngineDelegate()
        #expect(throws: LuaEngineError.unknownCommand("nope")) {
            try manager.executeCommand("nope", args: "", target: nil, delegate: delegate)
        }
    }

    @Test("Routes commands to the correct engine with multiple plugins")
    @MainActor
    func routesToCorrectEngine() throws {
        let dir = try makeTempPluginsDir(files: [
            "alpha.lua": """
            register_command("alpha", function(args, target)
                send_message(target, "from alpha")
            end)
            """,
            "beta.lua": """
            register_command("beta", function(args, target)
                send_message(target, "from beta")
            end)
            """
        ])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        let delegate = MockLuaEngineDelegate()

        try manager.executeCommand("alpha", args: "", target: "#ch", delegate: delegate)
        try manager.executeCommand("beta", args: "", target: "#ch", delegate: delegate)

        #expect(delegate.sentMessages.count == 2)
        #expect(delegate.sentMessages[0].text == "from alpha")
        #expect(delegate.sentMessages[1].text == "from beta")
    }

    // MARK: - CommandRouter Sync

    @Test("Updates CommandRouter.pluginCommands on load")
    @MainActor
    func routerCommandsSync() throws {
        let dir = try makeTempPluginsDir(files: [
            "tools.lua": """
            register_command("dice", function() end)
            register_command("time", function() end)
            """
        ])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        #expect(CommandRouter.pluginCommands.contains("dice"))
        #expect(CommandRouter.pluginCommands.contains("time"))
    }

    // MARK: - Reload

    @Test("reloadAll rescans and reloads plugins")
    @MainActor
    func reloadAll() throws {
        let dir = try makeTempPluginsDir(files: [
            "dice.lua": """
            register_command("dice", function() end)
            """
        ])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()
        #expect(manager.plugins.count == 1)

        // Add a new plugin file
        let newURL = dir.appendingPathComponent("echo.lua")
        try """
        register_command("echo", function(args, target)
            send_message(target, args)
        end)
        """.write(to: newURL, atomically: true, encoding: .utf8)

        manager.reloadAll()

        #expect(manager.plugins.count == 2)
        #expect(CommandRouter.pluginCommands.contains("dice"))
        #expect(CommandRouter.pluginCommands.contains("echo"))
    }

    // MARK: - Import

    @Test("Imports a .lua file into the plugins directory")
    @MainActor
    func importPlugin() throws {
        let dir = try makeTempPluginsDir(files: [:])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        // Create a .lua file outside the plugins directory
        let externalFile = dir.deletingLastPathComponent()
            .appendingPathComponent("custom.lua")
        try """
        -- Plugin: custom
        -- Description: A custom plugin
        register_command("custom", function(args, target)
            send_message(target, "custom: " .. args)
        end)
        """.write(to: externalFile, atomically: true, encoding: .utf8)

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()
        #expect(manager.plugins.isEmpty)

        try manager.importPlugin(from: externalFile)

        #expect(manager.plugins.count == 1)
        #expect(manager.plugins[0].name == "custom")
        #expect(manager.plugins[0].commands.contains("custom"))
        #expect(CommandRouter.pluginCommands.contains("custom"))

        // Verify file was copied
        let copied = dir.appendingPathComponent("custom.lua")
        #expect(FileManager.default.fileExists(atPath: copied.path))
    }

    @Test("Rejects non-.lua files on import")
    @MainActor
    func importRejectsNonLua() throws {
        let dir = try makeTempPluginsDir(files: [:])
        defer { cleanup(dir) }

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let textFile = dir.deletingLastPathComponent()
            .appendingPathComponent("readme.txt")
        try "not a plugin".write(to: textFile, atomically: true, encoding: .utf8)

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        #expect(throws: PluginImportError.notLuaFile) {
            try manager.importPlugin(from: textFile)
        }
        #expect(manager.plugins.isEmpty)
    }

    // MARK: - Directory Creation

    @Test("Creates plugins directory if it doesn't exist")
    @MainActor
    func createsDirectory() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PandaPingTests-\(UUID().uuidString)")
            .appendingPathComponent("Plugins")
        defer {
            try? FileManager.default.removeItem(at: dir.deletingLastPathComponent())
        }

        #expect(!FileManager.default.fileExists(atPath: dir.path))

        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        let manager = PluginManager(pluginsDirectory: dir)
        manager.scanAndLoad()

        #expect(FileManager.default.fileExists(atPath: dir.path))
    }
}
