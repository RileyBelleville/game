--!strict
-- CoinLeaderboardService: manages retrieval of global coin leaderboards.
--
-- Uses an OrderedDataStore to store the maximum coin balance seen for
-- each user.  The leaderboard can be queried to obtain the top coin
-- holders across all servers.  Note that coins themselves are saved in
-- EconomyService; this service only deals with the global leaderboard.

local DataStoreService = game:GetService("DataStoreService")

-- Ordered DataStore for global coins.  Keys are userId strings and
-- values are numbers representing the maximum coins earned by that
-- player at any point.  Because OrderedDataStore values must be
-- numbers, negative values will not appear.
local orderedCoins: OrderedDataStore = DataStoreService:GetOrderedDataStore("ObbyUniverse_GlobalCoins")

local CoinLeaderboardService = {}

-- Fetch the top `limit` entries from the global coins leaderboard.  The
-- returned table contains entries with `userId` and `coins` fields.  If
-- the DataStore request fails (e.g. in Studio offline mode), an empty
-- table is returned.
function CoinLeaderboardService.GetTop(limit: number?): {{userId: number, coins: number}}
    local n = math.clamp(limit or 10, 1, 25)
    local results: {{userId: number, coins: number}} = {}
    local ok, pages = pcall(function()
        return orderedCoins:GetSortedAsync(false, n)
    end)
    if ok and pages then
        local data = pages:GetCurrentPage()
        for _, entry in ipairs(data) do
            local uid = tonumber(entry.key)
            local amt = tonumber(entry.value)
            if uid then
                table.insert(results, { userId = uid, coins = amt or 0 })
            end
        end
    end
    return results
end

return CoinLeaderboardService