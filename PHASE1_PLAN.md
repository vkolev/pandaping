# Phase 1: Core IRC Client & UI

**Goal**: Build the basic IRC client with server/channel management and message display.

**Status**: Not Started

---

## Tasks

### 1. Set Up Project Structure
- [ ] Organize code into modules: `Networking`, `Models`, `Views`, `Utilities`, `Plugins`
- [ ] Configure project for macOS and iPadOS targets

### 2. Implement IRC Protocol
- [ ] Use `Network.framework` for raw IRC socket communication
- [ ] Parse IRC messages (RFC 1459, IRCv3) into Swift structs (`IRCMessage`, `IRCUser`, `IRCChannel`, `IRCServer`)
- [ ] Handle basic IRC commands: `JOIN`, `PART`, `PRIVMSG`, `NICK`, `PING/PONG`

### 3. Build Server/Channel Management
- [ ] Design a `ServerManager` to handle multiple IRC server connections
- [ ] Implement a `ChannelList` sidebar with:
  - [ ] Servers as top-level items (expandable)
  - [ ] Channels as sub-items to servers
  - [ ] Visual indicators for connection status and unread messages

### 4. Design Message Views
- [ ] Implement classic text view:
  - [ ] Monospace font, timestamps, nickname coloring
  - [ ] Support for channel hashtags (`#channel`) and mentions (`@nick`)
- [ ] Implement bubble view:
  - [ ] Rounded message bubbles, avatars, rich text
  - [ ] Group consecutive messages from the same user
- [ ] Add a toggle in settings to switch between views

### 5. User Input and Commands
- [ ] Create a chat input field with:
  - [ ] Support for `/commands` (e.g. `/join`, `/msg`)
  - [ ] Tab completion for nicks/channels
- [ ] Route commands to the IRC client or plugin manager

### 6. Local Testing Setup
- [ ] Set up a Docker-based IRC server (InspIRCd) for development
- [ ] Write a simple test bot to simulate user interactions

---

## Notes
- Prefer `Network.framework` over third-party socket libraries
- Avoid Combine; use Swift async/await
- Target macOS and iPadOS
