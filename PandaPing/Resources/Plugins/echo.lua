-- Plugin: echo
-- Description: Repeats your input back to the channel
-- Version: 1.0

register_command("echo", function(args, target)
    if not target then return end
    if args == "" then
        send_message(target, "Usage: /echo <text>")
    else
        send_message(target, args)
    end
end)
