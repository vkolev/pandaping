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

### 3. Build Plugin Manager (Application Preferences)
- [ ] Scan a local `Plugins` directory for `.lua` files
- [ ] Load each plugin in an isolated Lua state
- [ ] Register plugin commands with the app's command router
- [ ] Implement enable/disable toggle and basic sandboxing

### 4. Write Example Plugins
- [ ] `/time` - Posts the current time in the current channel/conversation
- [ ] `/dice` - Rolls a dice (e.g. `/dice 6`)
- [ ] `/echo` - Repeats the last user's input

### 5. Plugin UI
- [ ] Add a `Plugin Management` screen in settings
  - [ ] List of loaded plugins (enable/disable)
  - [ ] Brief descriptions and version info
- [ ] Support per-plugin configuration (e.g. time format for `/time`)

### 6. Security & Sandboxing
- [ ] Disable unsafe Lua functions (`os.execute`, `io.popen`)
- [ ] Limit plugin access to the filesystem/network
- [ ] Add timeouts for long-running scripts

---

## Notes
- Each plugin runs in its own isolated Lua state
- Plugin API should be well-documented and stable before Phase 3
