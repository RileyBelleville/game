--!strict
-- Admin script for Obby Universe Ultimate.  Currently this is a placeholder
-- showing how to designate an owner and grant special commands.  Replace
-- OWNER_ID with your Roblox user id.  You can expand this module with
-- admin commands such as skipping votes, granting coins, or kicking players.

local Players = game:GetService("Players")

local Admin = {}

-- Set this to your own Roblox user id to enable owner privileges
local OWNER_ID = 0 -- TODO: update this value

-- Example command: print when the owner chats "!skip" (no functionality yet)
Players.PlayerAdded:Connect(function(plr)
    if plr.UserId == OWNER_ID then
        plr.Chatted:Connect(function(msg)
            if msg:lower() == "!skip" then
                print("Admin skip command received (not implemented)")
            end
        end)
    end
end)

return Admin