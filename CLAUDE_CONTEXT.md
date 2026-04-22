# Project Plan: Panda Ping IRC Chat App with Lua Plugins

## Phase 1: Core IRC Client & UI Function

**Goal**: Build the basic IRC client with server/channel management and message display.

**Steps:**

1. Set Up Project Structure

 - Create a SwiftUI-basec XCode project for MacOS and iPadOS if it does not exists.
 - Organize code into modules: `Networking`, `Models`, `Views`, `Utilities`, `Plugins`

2. Implement IRC Protocol

 - Use `SwiftSocket` or `Network.framework` for raw IRC communication.
 - Parse IRC messages (RFC 1459, IRCv3) into Swift structs (`IRCMessage`, `IRCUser`, `IRCChannel`, `IRCServer`).
 - Handle basic IRC commands: `JOIN`, `PART`, `PRIVMSG`, `NICK`, `PING/PONG`.

3. Build Server/Channel management

  - Design a `ServerManager` to handle multiple IRC server connections.
  - Implement a `ChannelList` sidebar with:
    - Servers as top-level items (expandable)
    - Channels as sub-items to servers
    - Visual indicators for connection status and unread messages.

4. Design Message Views

  - Implement **classic text view**:
    - Monospace font, timestamps, nickname coloring.
    - Support for channel hashtags (`#channel` and mentions `@nick`).
  - Implement bubble view:
    - Rounded message bubbles, avatars, rich text.
    - Group consecutive messages from the same user.
  - Add a toggle in settings to switch between views.

5. User Input and Commands

  - Create a chat input field with:
    - Support for `/commands` (e.g. `/join`, `/msg`).
    - Tab completion for nicks/channels.
  - Route commands to the IRC client or plugin manager.

6. Local Testing Setup

 - Set up a docker-based IRC server (InspIRCd) for development.
 - Write a simple test bot to simulate user interactions.


## Phase 2: Plugin System with Lua

**Goal:** Design and implement a Lua-based plugin system for custom commands.

**Steps:**

1. Integrate Lua Runtime

  - Embed the Lua interpreter using LuaSwift or the Lua C API.
  - Expose Swift functions to Lua (e.g. `send_message`, `get_channel_users`).

2. Define Plugin API 

   - Specify Lua functions for plugins:
     - `register_command(command, handler)`
     - `send_message(channel, text)`
     - `get_current_nick()`
     - `log(message)`
   - Document the API for plugin developers.

3. Build Plugin manager as part of Application Preferences

  - Scan a local `Plugins` director for `.lua` files.
  - Load each plugin in an isolated Lua state.
  - Register plugin commands with the app's command router.
  - Implement enable/disable toggle and basic sandboxing.

4. Write Example Plugins

  - `/time`: Posts the current time in the current channel/conversation.
  - `/dice`: Rolls a dice (e.g. `/dice 6`).
  - `/echo`: Repeats the last user's input.

5. Plugin UI 

  - Add a `Plugin Management` screen in settings.
    - List of loaded plugins (enable/disable).
    - Brief descriptions and version info.
  - Support per-plugin configuration (e.g. time format for `/time`).

6. Security & sandboxing

   - Disable unsafe Lua function (`os.execute`, `io.popen`).
   - Limit plugin access to the filesystem/netweok.
   - Add timeouts for long-running scripts.

## Phase 3: Advanced Features and Polish

**Goal:** Add polish, user customization and advanced IRC features.

**Steps:**

1. Message Formatting

  - Highlight mentions (`@nick`) and hashtags (`#channel`).
  - Clickable nicks and channels in messages.
  - Support for IRC formatting (bold italics, colors).
  - Add clickable links and inline images (optional)

2. Notifications

  - Use `UserNotifications` for mentions and private messages.
  - Add badge icons for unread channels.

3. Multi-Window Support (iPadOS/MacOS)

  - Allow channels to open in separate windows.
  - Sync state between windows (e.g. read/unread status).

4. User Customization 

  - Themes: Dark/light mode, custom colors.
  - Font size and line spacing adjustments.
  - Plugin-specific settings.

5. IRCv3 & Advanced Features

  - Support SASL authentication.
  - Message tags and server-time (IRCv3).
  - Away messages and user statuses.

6. Error Handling and Logging 

  - Graceful reconnection on network errors.
  - Log IRC traffic for debugging (optional toggle).

## Phase 4: Testing & Release 

**Goal:** Ensure stability, performace and usability before release 

**Steps:** 

1. Unit & Integration Testing 

 - Test IRC parsing, server/channel management, and message display.
 - Verify plugin loading, command routing and sandboxing.

2. User Testing 

 - Test with real IRC server (e.g. Libera Chat, OFTC).
 - Gather feedback on UI/UX and plugin usability.

3. Performance Optimization 

 - Profile memory usage with many channels/messages.
 - Optimize message rendering (e.g. LazyVStack).

4. Documentation 

 - Write user guides for basic usage and plugins.
 - Document the Lua plugin API for developers.

# Documentation & Tools 

IRC Protocol - SwiftSocket, Network.framework 
Lua Plugins - LuaSwift, Lua C API 
UI - SwiftUI, Combine 
Local Testing - Docker, InspIRCd 
Persistence - UserDefaults, Code Data (optional)
Networking - URLSession, Network.framework 
Logging - os.log, SwiftLog 


