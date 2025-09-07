--!strict
-- AchievementsService: awards achievements based on wins and coins.
--
-- This service defines a set of achievements with thresholds for
-- accumulated wins or coins.  When a player qualifies for an
-- achievement, the service records the achievement, awards a coin
-- bonus and notifies the client via a remote event.  Achievements are
-- persisted per user using a DataStore.  It is safe to call
-- `CheckAll(userId)` multiple times; unlocked achievements will not be
-- re-awarded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Economy = require(script.Parent:WaitForChild("EconomyService"))
local Leaderboard = require(script.Parent:WaitForChild("LeaderboardService"))

-- Import Players service for lookup and remote events for score updates
local Players = game:GetService("Players")

-- Remote event to notify clients when an achievement is unlocked
local rem = ReplicatedStorage:WaitForChild("Remotes")
local AchievementUnlocked = rem:WaitForChild("AchievementUnlocked") :: RemoteEvent

-- Remote to update a player's coin display.  Achievements may grant
-- bonus coins, so inform the client of their new balance.
local ScoreUpdate = rem:WaitForChild("ScoreUpdate") :: RemoteEvent

-- DataStore to persist unlocked achievements per user.  The value is a
-- table mapping achievement IDs to true.  Keys are userId strings.
local achStore = DataStoreService:GetDataStore("ObbyUniverse_Achievements")

-- Define achievements.  Each entry may have a wins threshold and/or a
-- coins threshold.  When both are present, both conditions must be
-- satisfied.  Rewards are coins awarded once upon unlocking.
local ACHIEVEMENTS = {
    {
        id = "first_win",
        name = "First Win",
        wins = 1,
        coins = nil,
        reward = 10,
    },
    {
        id = "five_wins",
        name = "Strider",
        wins = 5,
        coins = nil,
        reward = 25,
    },
    {
        id = "hundred_coins",
        name = "Wealthy",
        wins = nil,
        coins = 100,
        reward = 30,
    },
    {
        id = "ten_wins",
        name = "Champion",
        wins = 10,
        coins = nil,
        reward = 50,
    },
}

local AchievementsService = {}

-- Get or load the unlocked achievements table for a user.
local function getUnlocked(userId: number): {[string]: boolean}
    local key = tostring(userId)
    -- Cache in memory per session
    AchievementsService._cache = AchievementsService._cache or {}
    if AchievementsService._cache[userId] then
        return AchievementsService._cache[userId]
    end
    local unlocked: {[string]: boolean} = {}
    local ok, data = pcall(function()
        return achStore:GetAsync(key)
    end)
    if ok and type(data) == "table" then
        unlocked = data
    end
    AchievementsService._cache[userId] = unlocked
    return unlocked
end

-- Save the unlocked table back to the DataStore (asynchronously)
local function saveUnlocked(userId: number, unlocked: {[string]: boolean})
    local key = tostring(userId)
    AchievementsService._cache[userId] = unlocked
    task.spawn(function()
        pcall(function()
            achStore:SetAsync(key, unlocked)
        end)
    end)
end

-- Check all achievements for a given user.  Awards any achievements
-- whose conditions are newly satisfied.  Should be called after wins
-- and coins are updated (e.g. after finishing a course).
function AchievementsService.CheckAll(userId: number)
    local unlocked = getUnlocked(userId)
    local wins = Leaderboard.GetWins(userId)
    local coins = Economy.Get(userId)
    for _, ach in ipairs(ACHIEVEMENTS) do
        if not unlocked[ach.id] then
            local winOK = (ach.wins == nil) or (wins >= ach.wins)
            local coinOK = (ach.coins == nil) or (coins >= ach.coins)
            if winOK and coinOK then
                -- Mark as unlocked
                unlocked[ach.id] = true
                saveUnlocked(userId, unlocked)
                -- Award reward coins and inform client of their new balance
                local reward = ach.reward or 0
                local plr = Players:GetPlayerByUserId(userId)
                if reward > 0 then
                    -- Award coins and get the new balance
                    local newBal = Economy.Award(userId, reward)
                    -- Inform client of new coin total
                    if plr then
                        ScoreUpdate:FireClient(plr, newBal)
                    end
                end
                -- Notify client of the unlocked achievement
                if plr then
                    AchievementUnlocked:FireClient(plr, ach.name, reward)
                end
            end
        end
    end
end

return AchievementsService