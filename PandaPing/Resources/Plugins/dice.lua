-- Plugin: dice
-- Description: Rolls a dice (e.g. /dice 6, /dice 20)
-- Version: 1.0

register_command("dice", function(args, target)
    if not target then return end
    local sides = tonumber(args) or 6
    if sides < 1 then sides = 6 end
    local result = math.random(1, sides)
    send_action(target, "Rolled a d" .. sides .. ": " .. result)
end)
