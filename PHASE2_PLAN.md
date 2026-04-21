# Phase 2: Plugin System with Lua

**Goal**: Design and implement a Lua-based plugin system for custom commands.

**Status**: Not Started

**Depends on**: Phase 1

---

## Tasks

### 1. Integrate Lua Runtime
- [ ] Embed the Lua interpreter using LuaSwift or the Lua C API
- [ ] Expose Swift functions to Lua (e.g. `send_message`, `get_channel_users`)

### 2. Define Plugin API
- [ ] Specify Lua functions for plugins:
  - [ ] `register_command(command, handler)`
  - [ ] `send_message(channel, text)`
  - [ ] `get_current_nick()`
  - [ ] `log(message)`
- [ ] Document the API for plugin developers

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
