-- Plugin: time
-- Description: Posts the current time in the current channel/conversation
-- Version: 1.0

register_command("time", function(args, target)
    if not target then return end
    local fmt = args ~= "" and args or "HH:mm:ss"
    local time = get_time(fmt)
    send_message(target, "Current time: " .. time)
end)
