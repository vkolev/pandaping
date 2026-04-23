//
//  LuaEngineTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Testing
@testable import PandaPing

// MARK: - Mock Delegate

@MainActor
final class MockLuaEngineDelegate: LuaEngineDelegate {
    var sentMessages: [(text: String, target: String)] = []
    var sentActions: [(text: String, target: String)] = []
    var nickname: String = "testbot"
    var channelUsers: [String: [ChannelUser]] = [:]
    var loggedMessages: [String] = []

    func luaEngine(_ engine: LuaEngine, sendMessage text: String, to target: String) {
        sentMessages.append((text: text, target: target))
    }

    func luaEngine(_ engine: LuaEngine, sendAction text: String, to target: String) {
        sentActions.append((text: text, target: target))
    }

    func luaEngineCurrentNickname(_ engine: LuaEngine) -> String {
        nickname
    }

    func luaEngine(_ engine: LuaEngine, usersInChannel channel: String) -> [ChannelUser]? {
        channelUsers[channel]
    }

    func luaEngine(_ engine: LuaEngine, log message: String) {
        loggedMessages.append(message)
    }
}

// MARK: - Tests

@Suite("Lua Engine")
struct LuaEngineTests {

    // MARK: - Lifecycle

    @Test("Creates engine and closes without error")
    @MainActor
    func lifecycle() {
        let engine = LuaEngine()
        engine.close()
    }

    // MARK: - Script Loading

    @Test("Loads and executes a simple Lua script")
    @MainActor
    func loadSimpleScript() throws {
        let engine = LuaEngine()
        defer { engine.close() }

        try engine.loadScript("log('hello from lua')")
        #expect(engine.logMessages == ["hello from lua"])
    }

    @Test("Throws on invalid Lua syntax")
    @MainActor
    func loadInvalidScript() {
        let engine = LuaEngine()
        defer { engine.close() }

        #expect(throws: (any Error).self) {
            try engine.loadScript("this is not valid lua {{{}}")
        }
    }

    @Test("Throws when engine is closed")
    @MainActor
    func loadAfterClose() {
        let engine = LuaEngine()
        engine.close()

        #expect(throws: LuaEngineError.engineClosed) {
            try engine.loadScript("log('should fail')")
        }
    }

    // MARK: - register_command

    @Test("Registers a command from Lua and can execute it")
    @MainActor
    func registerAndExecuteCommand() throws {
        let engine = LuaEngine()
        let delegate = MockLuaEngineDelegate()
        engine.delegate = delegate
        defer { engine.close() }

        try engine.loadScript("""
            register_command("greet", function(args)
                send_message("#test", "Hello " .. args)
            end)
        """)

        #expect(engine.hasCommand("greet"))

        try engine.executeCommand("greet", args: "world")

        #expect(delegate.sentMessages.count == 1)
        #expect(delegate.sentMessages[0].text == "Hello world")
        #expect(delegate.sentMessages[0].target == "#test")
    }

    @Test("Returns false for unregistered command")
    @MainActor
    func hasCommandReturnsFalse() {
        let engine = LuaEngine()
        defer { engine.close() }

        #expect(engine.hasCommand("nonexistent") == false)
    }

    @Test("Throws unknownCommand for unregistered command")
    @MainActor
    func executeUnknownCommand() {
        let engine = LuaEngine()
        defer { engine.close() }

        #expect(throws: LuaEngineError.unknownCommand("nope")) {
            try engine.executeCommand("nope", args: "")
        }
    }

    // MARK: - send_message

    @Test("send_message calls delegate with correct target and text")
    @MainActor
    func sendMessage() throws {
        let engine = LuaEngine()
        let delegate = MockLuaEngineDelegate()
        engine.delegate = delegate
        defer { engine.close() }

        try engine.loadScript("""
            send_message("#swift", "Hello channel!")
        """)

        #expect(delegate.sentMessages.count == 1)
        #expect(delegate.sentMessages[0].target == "#swift")
        #expect(delegate.sentMessages[0].text == "Hello channel!")
    }

    // MARK: - get_current_nick

    @Test("get_current_nick returns the delegate's nickname")
    @MainActor
    func getCurrentNick() throws {
        let engine = LuaEngine()
        let delegate = MockLuaEngineDelegate()
        delegate.nickname = "pandabot"
        engine.delegate = delegate
        defer { engine.close() }

        try engine.loadScript("""
            local nick = get_current_nick()
            log("my nick is " .. nick)
        """)

        #expect(engine.logMessages == ["my nick is pandabot"])
    }

    // MARK: - get_channel_users

    @Test("get_channel_users returns user table with nicknames and prefixes")
    @MainActor
    func getChannelUsers() throws {
        let engine = LuaEngine()
        let delegate = MockLuaEngineDelegate()
        delegate.channelUsers["#swift"] = [
            ChannelUser(prefixedNick: "@alice"),
            ChannelUser(prefixedNick: "+bob"),
            ChannelUser(nickname: "charlie"),
        ]
        engine.delegate = delegate
        defer { engine.close() }

        try engine.loadScript("""
            local users = get_channel_users("#swift")
            log(tostring(#users))
            log(users[1].nickname)
            log(users[1].prefix)
            log(users[2].nickname)
            log(users[3].prefix)
        """)

        #expect(engine.logMessages[0] == "3")
        #expect(engine.logMessages[1] == "alice")
        #expect(engine.logMessages[2] == "@")
        #expect(engine.logMessages[3] == "bob")
        #expect(engine.logMessages[4] == "")
    }

    @Test("get_channel_users returns nil for unknown channel")
    @MainActor
    func getChannelUsersUnknown() throws {
        let engine = LuaEngine()
        let delegate = MockLuaEngineDelegate()
        engine.delegate = delegate
        defer { engine.close() }

        try engine.loadScript("""
            local users = get_channel_users("#nonexistent")
            if users == nil then
                log("nil")
            end
        """)

        #expect(engine.logMessages == ["nil"])
    }

    // MARK: - log

    @Test("log stores messages in engine and forwards to delegate")
    @MainActor
    func logFunction() throws {
        let engine = LuaEngine()
        let delegate = MockLuaEngineDelegate()
        engine.delegate = delegate
        defer { engine.close() }

        try engine.loadScript("""
            log("first")
            log("second")
        """)

        #expect(engine.logMessages == ["first", "second"])
        #expect(delegate.loggedMessages == ["first", "second"])
    }

    // MARK: - Sandboxing

    @Test("os library is not available")
    @MainActor
    func osNotAvailable() throws {
        let engine = LuaEngine()
        defer { engine.close() }

        try engine.loadScript("""
            if os == nil then
                log("os is nil")
            else
                log("os exists")
            end
        """)

        #expect(engine.logMessages == ["os is nil"])
    }

    @Test("io library is not available")
    @MainActor
    func ioNotAvailable() throws {
        let engine = LuaEngine()
        defer { engine.close() }

        try engine.loadScript("""
            if io == nil then
                log("io is nil")
            else
                log("io exists")
            end
        """)

        #expect(engine.logMessages == ["io is nil"])
    }

    @Test("require is disabled")
    @MainActor
    func requireDisabled() throws {
        let engine = LuaEngine()
        defer { engine.close() }

        try engine.loadScript("""
            local result = require("os")
            log(tostring(result))
        """)

        #expect(engine.logMessages.first?.contains("disabled") == true)
    }

    // MARK: - Multiple Commands

    @Test("Can register and execute multiple commands")
    @MainActor
    func multipleCommands() throws {
        let engine = LuaEngine()
        let delegate = MockLuaEngineDelegate()
        engine.delegate = delegate
        defer { engine.close() }

        try engine.loadScript("""
            register_command("hello", function(args)
                send_message("#test", "Hello!")
            end)
            register_command("bye", function(args)
                send_message("#test", "Goodbye!")
            end)
        """)

        #expect(engine.hasCommand("hello"))
        #expect(engine.hasCommand("bye"))

        try engine.executeCommand("hello", args: "")
        try engine.executeCommand("bye", args: "")

        #expect(delegate.sentMessages.count == 2)
        #expect(delegate.sentMessages[0].text == "Hello!")
        #expect(delegate.sentMessages[1].text == "Goodbye!")
    }

    // MARK: - Error Handling

    @Test("Lua runtime error in command is thrown as Swift error")
    @MainActor
    func luaRuntimeError() throws {
        let engine = LuaEngine()
        defer { engine.close() }

        try engine.loadScript("""
            register_command("bad", function(args)
                error("something went wrong")
            end)
        """)

        #expect(throws: (any Error).self) {
            try engine.executeCommand("bad", args: "")
        }
    }

    // MARK: - CommandRouter Integration

    @Test("Plugin command routes through CommandRouter")
    func pluginCommandRouting() {
        // Save and restore
        let saved = CommandRouter.pluginCommands
        defer { CommandRouter.pluginCommands = saved }

        CommandRouter.pluginCommands = ["dice", "time"]

        let action = CommandRouter.parse("/dice 6", currentTarget: "#test")
        #expect(action == .pluginCommand(command: "dice", args: "6", target: "#test"))

        let noTarget = CommandRouter.parse("/dice 6", currentTarget: nil)
        #expect(noTarget == .pluginCommand(command: "dice", args: "6", target: nil))

        let unknown = CommandRouter.parse("/foobar", currentTarget: nil)
        #expect(unknown == .unknown(command: "foobar"))
    }

    // MARK: - Target Passing

    @Test("Command handler receives current target as second argument")
    @MainActor
    func handlerReceivesTarget() throws {
        let engine = LuaEngine()
        let delegate = MockLuaEngineDelegate()
        engine.delegate = delegate
        defer { engine.close() }

        try engine.loadScript("""
            register_command("reply", function(args, target)
                if target then
                    send_message(target, "Reply: " .. args)
                else
                    log("no target")
                end
            end)
        """)

        try engine.executeCommand("reply", args: "hello", target: "#swift")

        #expect(delegate.sentMessages.count == 1)
        #expect(delegate.sentMessages[0].target == "#swift")
        #expect(delegate.sentMessages[0].text == "Reply: hello")
    }

    @Test("Command handler receives nil target when none is set")
    @MainActor
    func handlerReceivesNilTarget() throws {
        let engine = LuaEngine()
        defer { engine.close() }

        try engine.loadScript("""
            register_command("check", function(args, target)
                if target == nil then
                    log("target is nil")
                else
                    log("target is " .. target)
                end
            end)
        """)

        try engine.executeCommand("check", args: "", target: nil)
        #expect(engine.logMessages == ["target is nil"])
    }

    // MARK: - get_time

    @Test("get_time returns a non-empty time string")
    @MainActor
    func getTimeDefault() throws {
        let engine = LuaEngine()
        defer { engine.close() }

        try engine.loadScript("""
            local t = get_time()
            log(t)
        """)

        #expect(engine.logMessages.count == 1)
        // Default format HH:mm:ss produces something like "14:30:05"
        #expect(engine.logMessages[0].contains(":"))
    }

    @Test("get_time with custom format")
    @MainActor
    func getTimeCustomFormat() throws {
        let engine = LuaEngine()
        defer { engine.close() }

        try engine.loadScript("""
            local t = get_time("yyyy")
            log(t)
        """)

        #expect(engine.logMessages.count == 1)
        // Should return a 4-digit year string
        #expect(engine.logMessages[0].count == 4)
    }

    // MARK: - send_action

    @Test("send_action calls delegate with correct target and text")
    @MainActor
    func sendAction() throws {
        let engine = LuaEngine()
        let delegate = MockLuaEngineDelegate()
        engine.delegate = delegate
        defer { engine.close() }

        try engine.loadScript("""
            send_action("#swift", "waves hello")
        """)

        #expect(delegate.sentActions.count == 1)
        #expect(delegate.sentActions[0].target == "#swift")
        #expect(delegate.sentActions[0].text == "waves hello")
    }
}
