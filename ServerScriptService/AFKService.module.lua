--!strict
-- AFKService: tracks whether players have set themselves as AFK.
--
-- Clients can toggle their AFK state via the `SetAFK` RemoteEvent.  When a
-- player is marked AFK they will not be teleported to the start of the
-- course, nor will their votes count in course selection.  This service
-- exposes a simple `IsAFK` method for other server scripts to query.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local rem = ReplicatedStorage:WaitForChild("Remotes")
local SetAFK = rem:WaitForChild("SetAFK") :: RemoteEvent

local AFKService = {}

-- Table of userId → boolean indicating AFK state.  Missing entries are
-- treated as not AFK (false).
local states: {[number]: boolean} = {}

-- Return true if the given userId is currently marked AFK.
function AFKService.IsAFK(userId: number): boolean
    return states[userId] == true
end

-- Toggle or set AFK for a player.  If `state` is nil the state will
-- toggle; otherwise it will be set explicitly to the boolean value.  This
-- event is fired from the client when the player presses the AFK key.
SetAFK.OnServerEvent:Connect(function(plr: Player, state: boolean?)
    local uid = plr.UserId
    if state == nil then
        states[uid] = not AFKService.IsAFK(uid)
    else
        states[uid] = state
    end
end)

-- Clean up state when a player leaves the game
Players.PlayerRemoving:Connect(function(plr)
    states[plr.UserId] = nil
end)

return AFKService