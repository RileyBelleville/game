--!strict
-- GlobalBoardEndpoint: provides a RemoteFunction handler that returns the
-- global wins leaderboard.  Clients can call this to fetch the top
-- players across all servers.  The result is a table of entries with
-- `userId` and `wins` fields, sorted descending by wins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

local rem = ReplicatedStorage:WaitForChild("Remotes")
local GlobalBoardQuery = rem:WaitForChild("GlobalBoardQuery") :: RemoteFunction

function GlobalBoardQuery.OnServerInvoke(plr: Player, limit: number?)
    local n = tonumber(limit) or 10
    return LeaderboardService.GetBoard(n)
end

return {}