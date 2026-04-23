# Phase 2: Plugin System with Lua

**Goal**: Design and implement a Lua-based plugin system for custom commands.

**Status**: In Progress

**Depends on**: Phase 1

---

## Tasks

### 1. Integrate Lua Runtime (DONE)
- [x] Embed Lua via LuaSwift SPM package
- [x] Created `LuaEngine` class with sandboxed Lua state (`.safe` libraries)
- [x] Exposed Swift bridge functions: `register_command`, `send_message`, `get_current_nick`, `get_channel_users`, `log`
- [x] Added `LuaEngineDelegate` protocol for IRC integration
- [x] Added `pluginCommand` case to `UserAction` and routing in `CommandRouter`
- [x] Added `LuaEngineDelegate` conformance to `IRCConnection`
- [x] 18 unit tests — all passing

### 2. Define Plugin API (DONE)
- [x] Specify Lua functions for plugins:
  - [x] `register_command(command, handler)` — implemented in Step 1
  - [x] `send_message(channel, text)` — implemented in Step 1
  - [x] `get_current_nick()` — implemented in Step 1
  - [x] `get_channel_users(channel)` — implemented in Step 1
  - [x] `log(message)` — implemented in Step 1
  - [x] `get_time(format?)` — added in Step 2 (replaces disabled `os.date`)
- [x] Command handlers now receive `(args, target)` — target is the current channel/DM
- [x] Document the API for plugin developers — `Docs/PluginAPI.md`
- [x] 22 unit tests — all passing

### 3. Build Plugin Manager (Application Preferences) (DONE)
- [x] Created `PluginInfo` model with metadata parsing from `-- Plugin:`, `-- Description:`, `-- Version:` headers
- [x] Created `PluginManager` (`@MainActor @Observable`) that scans `Plugins/` directory for `.lua` files
- [x] Each plugin loads in its own isolated `LuaEngine` state
- [x] Commands registered with `CommandRouter.pluginCommands` on load/unload
- [x] Enable/disable toggle with `UserDefaults` persistence (`"disabledPlugins"` key)
- [x] `IRCConnection.luaEngine` replaced with `IRCConnection.pluginManager`
- [x] `PluginManager` wired through `ServerManager` → `IRCConnection`
- [x] Plugin directory: `Application Support/PandaPing/Plugins/` (macOS) or `Documents/Plugins/` (iPadOS)
- [x] 15 unit tests — all passing (173 total)

### 4. Write Example Plugins (DONE)
- [x] `/time` — Posts the current time (bundled in `Resources/Plugins/time.lua`)
- [x] `/dice` — Rolls a dice, e.g. `/dice 6` (bundled in `Resources/Plugins/dice.lua`)
- [x] `/echo` — Repeats the user's input (bundled in `Resources/Plugins/echo.lua`)
- [x] Bundled plugins auto-installed to user plugins directory on first launch via `installBundledPluginsIfNeeded()`
- [x] 174 unit tests — all passing

### 5. Plugin UI (DONE)
- [x] Created `SettingsView` with Plugins section accessible via macOS Settings scene (⌘,)
- [x] Shows plugin name, version, description, registered commands, and errors
- [x] Enable/disable toggle per plugin (calls `pluginManager.togglePlugin`)
- [x] "Reload All" toolbar button
- [x] Empty state with plugins directory path hint
- [x] `pluginManager` wired through `PandaPingApp` → macOS `Settings` scene

### 6. Security & Sandboxing
- [ ] Disable unsafe Lua functions (`os.execute`, `io.popen`)
- [ ] Limit plugin access to the filesystem/network
- [ ] Add timeouts for long-running scripts

---

## Notes
- Each plugin runs in its own isolated Lua state
- Plugin API should be well-documented and stable before Phase 3
