# Phase 3: Advanced Features and Polish

**Goal**: Add polish, user customization, and advanced IRC features.

**Status**: Not Started

**Depends on**: Phase 1, Phase 2

---

## Tasks

### 1. Message Formatting
- [x] Highlight mentions (`@nick`) and hashtags (`#channel`)
- [x] Clickable nicks and channels in messages
- [x] Support for IRC formatting (bold, italics, colors)
- [x] Add clickable links and inline images (optional)

### 2. Notifications
- [ ] Use `UserNotifications` for mentions and private messages
- [ ] Add badge icons for unread channels

### 3. Multi-Window Support (iPadOS/macOS)
- [ ] Allow channels to open in separate windows
- [ ] Sync state between windows (e.g. read/unread status)

### 4. User Customization
- [ ] Themes: Dark/light mode, custom colors
- [ ] Font size and line spacing adjustments
- [ ] Plugin-specific settings

### 5. IRCv3 & Advanced Features
- [ ] Support SASL authentication
- [ ] Message tags and server-time (IRCv3)
- [ ] Away messages and user statuses

### 6. Error Handling and Logging
- [ ] Graceful reconnection on network errors
- [ ] Log IRC traffic for debugging (optional toggle)

---

## Notes
- Multi-window support should leverage SwiftUI's `WindowGroup` / `openWindow`
- Use `os.log` or SwiftLog for structured logging
