--!strict
-- LeaderboardService: tracks per‑session wins for players.  Wins are not
-- persisted across servers; if desired you could save them to a DataStore.
-- Provides functions to record wins, query a player's wins and obtain a
-- sorted leaderboard.  A win is recorded when a player reaches the finish
-- pad.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- Ordered DataStore for cross‑server wins leaderboard.  Keys are
-- userId strings and values are total wins.  Using an ordered store
-- allows retrieval of the top players globally.  Operations on
-- DataStores may fail silently in Studio; all calls are wrapped in
-- pcall to avoid runtime errors.
local orderedWins: OrderedDataStore = DataStoreService:GetOrderedDataStore("ObbyUniverse_GlobalWins")

local LeaderboardService = {}

-- Map of userId → wins count for this session
local wins: {[number]: number} = {}

-- Record a win for a userId.  Returns the new total.
function LeaderboardService.RecordWin(userId: number): number
    -- Increment the in‑memory session wins
    wins[userId] = (wins[userId] or 0) + 1
    -- Update the ordered DataStore to persist the win globally
    local key = tostring(userId)
    pcall(function()
        orderedWins:IncrementAsync(key, 1)
    end)
    return wins[userId]
end

-- Get total wins for a player
function LeaderboardService.GetWins(userId: number): number
    return wins[userId] or 0
end

-- Return a sorted leaderboard table.  Each entry is a table with
-- `userId` and `wins` fields.  Sorted descending by wins.
function LeaderboardService.GetBoard(maxEntries: number?): {{userId: number, wins: number}}
    -- Number of entries to fetch from the global leaderboard (default 10)
    local n = maxEntries or 10
    local list: {{userId: number, wins: number}} = {}
    -- Try to fetch the top entries from the ordered DataStore.  DataStores
    -- are subject to limits and may fail in Studio; wrap in pcall.
    local success, pages = pcall(function()
        return orderedWins:GetSortedAsync(false, n)
    end)
    if success and pages then
        local data = pages:GetCurrentPage()
        for _, entry in ipairs(data) do
            local uidNum = tonumber(entry.key)
            if uidNum then
                table.insert(list, { userId = uidNum, wins = entry.value })
            end
        end
        return list
    end
    -- Fallback: use the in‑memory session leaderboard if the DataStore call failed
    for uid, count in pairs(wins) do
        table.insert(list, { userId = uid, wins = count })
    end
    table.sort(list, function(a, b) return a.wins > b.wins end)
    -- Trim to n entries
    while #list > n do table.remove(list) end
    return list
end

return LeaderboardService