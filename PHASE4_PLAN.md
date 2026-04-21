# Phase 4: Testing & Release

**Goal**: Ensure stability, performance, and usability before release.

**Status**: Not Started

**Depends on**: Phase 1, Phase 2, Phase 3

---

## Tasks

### 1. Unit & Integration Testing
- [ ] Test IRC parsing, server/channel management, and message display
- [ ] Verify plugin loading, command routing, and sandboxing
- [ ] Use the Swift Testing framework for unit tests
- [ ] Use XCUIAutomation for UI tests

### 2. User Testing
- [ ] Test with real IRC servers (e.g. Libera Chat, OFTC)
- [ ] Gather feedback on UI/UX and plugin usability

### 3. Performance Optimization
- [ ] Profile memory usage with many channels/messages
- [ ] Optimize message rendering (e.g. `LazyVStack`)

### 4. Documentation
- [ ] Write user guides for basic usage and plugins
- [ ] Document the Lua plugin API for developers

---

## Notes
- Real-server testing should cover edge cases (netsplits, high-traffic channels)
- Performance profiling with Instruments
