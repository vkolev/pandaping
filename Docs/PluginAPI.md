# PandaPing Plugin API

Plugins for PandaPing are written in Lua. Each plugin is a `.lua` file that registers one or more commands using the API functions described below.

## Plugin Structure

A plugin file typically registers commands at load time:

```lua
-- Plugin: dice
-- Description: Roll a dice
-- Version: 1.0

register_command("dice", function(args, target)
    local sides = tonumber(args) or 6
    local result = math.random(1, sides)
    if target then
        send_message(target, "Rolled a d" .. sides .. ": " .. result)
    end
end)
```

### Command Handlers

Command handlers are Lua functions with the signature:

```lua
function(args, target)
```

- **args** (`string`) — Everything the user typed after the command name. For `/dice 6`, args is `"6"`. May be an empty string.
- **target** (`string` or `nil`) — The channel or nickname the user is currently viewing (e.g. `"#swift"`, `"alice"`). `nil` if no target is selected.

## API Functions

### register_command(name, handler)

Registers a slash command that users can invoke.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Command name without the leading `/` |
| `handler` | function | Handler function `(args, target)` |

```lua
register_command("greet", function(args, target)
    send_message(target, "Hello, " .. args .. "!")
end)
```

Users invoke this by typing `/greet world` in the chat input.

### send_message(target, text)

Sends a message to a channel or user.

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | string | Channel name (e.g. `"#swift"`) or nickname |
| `text` | string | The message text to send |

```lua
send_message("#general", "Hello everyone!")
send_message("alice", "Hey Alice!")
```

### send_action(target, text)

Sends a CTCP ACTION (`/me`) to a channel or user.

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | string | Channel name (e.g. `"#swift"`) or nickname |
| `text` | string | The action text (without `/me` prefix) |

```lua
send_action("#general", "waves hello")
-- Appears as: * YourNick waves hello
```

### get_current_nick()

Returns the current nickname on the active IRC connection.

| Returns | Type | Description |
|---------|------|-------------|
| nick | string | The current nickname |

```lua
local nick = get_current_nick()
log("I am " .. nick)
```

### get_channel_users(channel)

Returns the list of users in a channel, or `nil` if not joined.

| Parameter | Type | Description |
|-----------|------|-------------|
| `channel` | string | Channel name (e.g. `"#swift"`) |

| Returns | Type | Description |
|---------|------|-------------|
| users | table or nil | Array of user tables, or nil |

Each user table has:
- `nickname` (`string`) — The user's nick
- `prefix` (`string`) — Mode prefix: `"@"` (op), `"%"` (halfop), `"+"` (voice), or `""` (none)

```lua
local users = get_channel_users("#swift")
if users then
    for i, user in ipairs(users) do
        log(user.prefix .. user.nickname)
    end
end
```

### get_time(format?)

Returns the current time as a formatted string.

| Parameter | Type | Description |
|-----------|------|-------------|
| `format` | string (optional) | Date format string. Default: `"HH:mm:ss"` |

| Returns | Type | Description |
|---------|------|-------------|
| time | string | Formatted time string |

Format uses standard date format patterns:
- `HH:mm:ss` — 24-hour time (e.g. `"14:30:05"`)
- `hh:mm a` — 12-hour time (e.g. `"02:30 PM"`)
- `yyyy-MM-dd` — Date (e.g. `"2026-04-23"`)
- `yyyy-MM-dd HH:mm:ss` — Full date and time

```lua
local time = get_time()              -- "14:30:05"
local full = get_time("yyyy-MM-dd HH:mm:ss")  -- "2026-04-23 14:30:05"
```

### log(message)

Logs a message for debugging. Output appears in the Xcode console.

| Parameter | Type | Description |
|-----------|------|-------------|
| `message` | string | The message to log |

```lua
log("Plugin loaded successfully")
```

## Available Lua Standard Libraries

Plugins have access to the following standard Lua libraries:

| Library | Available | Notes |
|---------|-----------|-------|
| base | Yes | `print`, `type`, `tostring`, `tonumber`, `pairs`, `ipairs`, `error`, etc. |
| string | Yes | `string.format`, `string.sub`, `string.find`, `string.match`, etc. |
| math | Yes | `math.random`, `math.floor`, `math.abs`, etc. |
| table | Yes | `table.insert`, `table.remove`, `table.sort`, etc. |
| coroutine | Yes | Coroutine support |
| utf8 | Yes | UTF-8 string handling |
| os | **No** | Disabled for security |
| io | **No** | Disabled for security |
| debug | **No** | Disabled for security |
| package | **No** | Disabled for security |

`require()` is also disabled — plugins cannot load external modules.

## Example Plugins

### /time — Post current time

```lua
register_command("time", function(args, target)
    if not target then return end
    local fmt = args ~= "" and args or "HH:mm:ss"
    local time = get_time(fmt)
    send_message(target, "Current time: " .. time)
end)
```

### /dice — Roll a dice

```lua
register_command("dice", function(args, target)
    if not target then return end
    local sides = tonumber(args) or 6
    if sides < 1 then sides = 6 end
    local result = math.random(1, sides)
    send_message(target, "Rolled a d" .. sides .. ": " .. result)
end)
```

### /echo — Repeat input

```lua
register_command("echo", function(args, target)
    if not target then return end
    if args == "" then
        send_message(target, "Usage: /echo <text>")
    else
        send_message(target, args)
    end
end)
```
