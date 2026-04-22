# Phase 1: Core IRC Client & UI

**Goal**: Build the basic IRC client with server/channel management and message display.

**Status**: Complete

---

## Tasks

### 1. Set Up Project Structure
- [x] Organize code into modules: `Networking`, `Models`, `Views`, `Utilities`, `Plugins`
- [x] Configure project for macOS and iPadOS targets

### 2. Implement IRC Protocol
- [x] Use `Network.framework` for raw IRC socket communication (implemented in Step 3 as `NWIRCTransport`)
- [x] Parse IRC messages (RFC 1459, IRCv3) into Swift structs (`IRCMessage`, `IRCUser`, `IRCChannel`, `IRCServer`)
- [x] Handle basic IRC commands: `JOIN`, `PART`, `PRIVMSG`, `NICK`, `PING/PONG`
- [x] Unit tests: 30 tests across IRCParserTests, IRCUserTests, IRCCommandTests — all passing

### 3. Build Server/Channel Management
- [x] Design a `ServerManager` to handle multiple IRC server connections
- [x] Implement `IRCConnection` with `IRCTransport` protocol + `NWIRCTransport`
- [x] Implement a `ChannelList` sidebar with:
  - [x] Servers as top-level items (expandable)
  - [x] Channels as sub-items to servers
  - [x] Visual indicators for connection status and unread messages
  - [x] Dedicated "Private Messages" section for active DMs below servers
- [x] `ChatSelection` enum for unified channel/PM selection model
- [x] Unit tests: IRCConnectionTests (including DM tracking), ServerManagerTests — all passing

### 4. Design Message Views
- [x] Implement classic text view:
  - [x] Monospace font, timestamps, nickname coloring
  - [x] Support for channel hashtags (`#channel`) and mentions (`@nick`)
- [x] Server console view for NOTICE, MOTD, numeric replies
- [x] Add Server form (hostname, port, SSL, nickname, channels)
- [x] Unit tests: NicknameColorTests, MessageTextParserTests, server message tests — all passing
- ~~Bubble view~~ — deferred to Phase 4
- ~~Settings toggle between views~~ — deferred to Phase 4

### 5. User Input and Commands
- [x] Create a chat input field with:
  - [x] Support for `/commands` (`/join`, `/part`, `/msg`, `/nick`, `/quit`, `/me`)
  - [x] Tab completion for nicks/channels (macOS `onKeyPress(.tab)`)
- [x] Route commands via `CommandRouter` → `UserAction` → `IRCConnection.executeAction()`
- [x] Local echo for outgoing messages (IRC servers don't echo your own PRIVMSG)
- [x] CTCP ACTION support (`/me`) with italic display
- [x] Channel user list panel (right side, sorted by privilege: @, %, +)
- [x] `ChannelUser` model with mode prefix parsing from NAMES replies
- [x] Handle 353/366 (NAMES), QUIT, KICK in `IRCConnection`
- [x] NICK changes propagated to channel user lists
- [x] Disconnect/reconnect/remove context menu on server headers
- [x] Unit tests: CommandRouterTests, TabCompleterTests, ChannelUserTests, + extended IRCConnectionTests — 134 total, all passing

### 6. Local Testing Setup
- [x] Set up a Docker-based IRC server for development
- [ ] Write a simple test bot to simulate user interactions

---

## Notes
- Prefer `Network.framework` over third-party socket libraries
- Avoid Combine; use Swift async/await
- Target macOS and iPadOS
