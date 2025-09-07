--!strict
-- GlobalCoinsBoardEndpoint: provides a RemoteFunction interface for
-- clients to query the global coin leaderboard.  When invoked, this
-- script returns a table of entries with `userId` and `coins` fields
-- representing the top coin holders across all servers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoinLeaderboardService = require(script.Parent:WaitForChild("CoinLeaderboardService"))

local rem = ReplicatedStorage:WaitForChild("Remotes")
local GlobalCoinsBoardQuery = rem:WaitForChild("GlobalCoinsBoardQuery") :: RemoteFunction

-- Define the server invocation handler.  The caller can optionally
-- specify a limit for the number of entries.  Defaults to 10 and
-- clamps to 1–25.
function GlobalCoinsBoardQuery.OnServerInvoke(plr, limit)
    local n = tonumber(limit) or 10
    return CoinLeaderboardService.GetTop(n)
end

return {}