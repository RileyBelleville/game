--!strict
-- RoundManager: orchestrates the core gameplay loop for Obby Universe Ultimate.
--
-- Handles lobby countdown, voting, course construction, running, result
-- announcements, podium display and cleanup.  It also awards coins,
-- updates leaderboards and teleports players to the start/finish/podium.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local ObbyLibrary = require(Modules:WaitForChild("ObbyLibrary"))

local Economy = require(script.Parent:WaitForChild("EconomyService"))
local Inventory = require(script.Parent:WaitForChild("InventoryService"))
local Leaderboard = require(script.Parent:WaitForChild("LeaderboardService"))
local Podium = require(script.Parent:WaitForChild("ResultsPodium"))

-- Additional services
local AFKService = require(script.Parent:WaitForChild("AFKService"))
local AchievementsService = require(script.Parent:WaitForChild("AchievementsService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundUpdate = Remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local FinishEvent = Remotes:WaitForChild("FinishEvent") :: RemoteEvent
local VoteEvent = Remotes:WaitForChild("VoteEvent") :: RemoteEvent
local VoteUpdate = Remotes:WaitForChild("VoteUpdate") :: RemoteEvent
local ScoreUpdate = Remotes:WaitForChild("ScoreUpdate") :: RemoteEvent
local LeaderboardUpdate = Remotes:WaitForChild("LeaderboardUpdate") :: RemoteEvent

-- Arena and runtime storage
local ArenaCenter = Workspace:WaitForChild("ArenaCenter") :: BasePart
-- Store all course parts under this folder so they can be cleared easily
local ArenaFolder = Workspace:FindFirstChild("ArenaRuntime")
if not ArenaFolder then
    ArenaFolder = Instance.new("Folder")
    ArenaFolder.Name = "ArenaRuntime"
    ArenaFolder.Parent = Workspace
end

-- State variables for the current round
local winners: {number} = {}             -- ordered list of userIds of finishers
local finishedByUser: {[number]: boolean} = {} -- whether a user has finished this round
local votes: {[number]: string} = {}      -- per‑player vote choice
local currentFinish: BasePart? = nil      -- finish pad for the current course
local currentStartCF: CFrame = ArenaCenter.CFrame

-- Broadcast status to all clients.  Includes a textual status, time left
-- (optional) and a list of winner userIds for HUD display.
local function broadcast(status: string, timeLeft: number?)
    RoundUpdate:FireAllClients(status, timeLeft or 0, winners)
end

-- Reset round state between rounds
local function resetRoundState()
    winners = {}
    finishedByUser = {}
    votes = {}
    currentFinish = nil
end

-- Teleport a player to a given CFrame with a small upward offset.
local function teleportTo(cf: CFrame, plr: Player)
    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
        plr.Character.HumanoidRootPart.CFrame = cf + Vector3.new(0,3,0)
    end
end

-- Hook a finish pad so that players who touch it are recorded as winners
local function hookFinishPad(pad: BasePart)
    pad.Touched:Connect(function(hit)
        local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local plr = Players:GetPlayerFromCharacter(hum.Parent)
        if not plr then return end
        if finishedByUser[plr.UserId] then return end
        finishedByUser[plr.UserId] = true
        table.insert(winners, plr.UserId)
        -- Notify clients of individual finish
        FinishEvent:FireAllClients(plr.Name)
        -- Award coins
        local award = Config.COINS_FINISH
        if #winners == 1 then
            award = award + Config.COINS_PODIUM_BONUS
        end
        local newBal = Economy.Award(plr.UserId, award)
        -- Update leaderstats coin value
        local ls = plr:FindFirstChild("leaderstats")
        if ls then
            local c = ls:FindFirstChild("Coins")
            if c then c.Value = newBal end
        end
        -- Tell the client their new coin balance
        ScoreUpdate:FireClient(plr, newBal)
        -- Record win for leaderboard and update wins leaderstat
        local winsCount = Leaderboard.RecordWin(plr.UserId)
        local ls2 = plr:FindFirstChild("leaderstats")
        if ls2 then
            local w = ls2:FindFirstChild("Wins")
            if w then w.Value = winsCount end
        end
        -- Check for achievements now that coins and wins are updated
        AchievementsService.CheckAll(plr.UserId)
        -- Broadcast updated scoreboard
        LeaderboardUpdate:FireAllClients(Leaderboard.GetBoard())
    end)
end

-- Voting handler: update player's choice when they click a vote button
VoteEvent.OnServerEvent:Connect(function(plr: Player, choice: string)
    -- Ignore votes from AFK players
    if AFKService.IsAFK(plr.UserId) then
        return
    end
    -- Validate choice is one of the offered course types
    for _, ct in ipairs(Config.CourseTypes) do
        if ct == choice then
            votes[plr.UserId] = choice
            break
        end
    end
end)

-- Helper to choose a random subset of course types for the vote
local function pickVoteOptions(): {string}
    local pool = table.clone(Config.CourseTypes)
    local options = {}
    for i=1, math.min(3, #pool) do
        local idx = math.random(1, #pool)
        table.insert(options, table.remove(pool, idx))
    end
    return options
end

-- Main loop coroutine
task.spawn(function()
    while true do
        -- LOBBY PHASE
        local t = Config.LOBBY_TIME
        while t > 0 do
            broadcast("Lobby — next round soon…", t)
            task.wait(1)
            t -= 1
        end
        -- Need at least one player
        if #Players:GetPlayers() < 1 then
            broadcast("Waiting for players…", 0)
            task.wait(3)
            continue
        end
        resetRoundState()
        -- VOTING PHASE
        local options = pickVoteOptions()
        local vt = Config.VOTING_TIME
        while vt > 0 do
            VoteUpdate:FireAllClients(options, votes, vt)
            broadcast("Voting — choose the next course", vt)
            task.wait(1)
            vt -= 1
        end
        -- Tally votes
        local counts: {[string]: number} = {}
        for _, opt in ipairs(options) do counts[opt] = 0 end
        for _, choice in pairs(votes) do
            if counts[choice] ~= nil then counts[choice] += 1 end
        end
        local chosen = options[1]
        local bestCount = -1
        for opt, c in pairs(counts) do
            if c > bestCount then
                bestCount = c
                chosen = opt
            end
        end
        -- On a complete tie (no votes), pick random
        if bestCount <= 0 then
            chosen = options[math.random(1, #options)]
        end
        broadcast("Building course: " .. chosen, 0)
        -- BUILD PHASE
        ObbyLibrary.ClearArena(ArenaFolder)
        local build = ObbyLibrary.BuildByType(ArenaFolder, ArenaCenter.CFrame, chosen)
        currentFinish = build.FinishPart
        currentStartCF = build.StartCF
        if currentFinish then
            hookFinishPad(currentFinish)
        end
        -- Teleport all non‑AFK players to the start
        for _, plr in ipairs(Players:GetPlayers()) do
            if not AFKService.IsAFK(plr.UserId) then
                teleportTo(currentStartCF, plr)
            end
        end
        -- RUN PHASE
        local rt = Config.ROUND_TIME
        while rt > 0 do
            broadcast("Run! Reach the green finish pad to win!", rt)
            task.wait(1)
            rt -= 1
        end
        -- RESULTS PHASE
        broadcast("Round over! Showing podium…", 0)
        -- Build podium and place top 3
        Podium.Clear()
        local podiumParts = Podium.Build(ArenaCenter.CFrame)
        for rank, uid in ipairs(winners) do
            if rank > 3 then break end
            local plr = Players:GetPlayerByUserId(uid)
            if plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local target: BasePart? = nil
                if rank == 1 then
                    target = Workspace:FindFirstChild("Podium") and Workspace.Podium:FindFirstChild("P1") or nil
                elseif rank == 2 then
                    target = Workspace:FindFirstChild("Podium") and Workspace.Podium:FindFirstChild("P2") or nil
                else
                    target = Workspace:FindFirstChild("Podium") and Workspace.Podium:FindFirstChild("P3") or nil
                end
                if target then
                    plr.Character.HumanoidRootPart.CFrame = target.CFrame + Vector3.new(0,3,0)
                end
            end
        end
        -- Broadcast leaderboard
        LeaderboardUpdate:FireAllClients(Leaderboard.GetBoard())
        task.wait(Config.CLEANUP_TIME)
        -- CLEANUP PHASE
        Podium.Clear()
        ObbyLibrary.ClearArena(ArenaFolder)
    end
end)

-- Assign leaderstats on join and update coin/win counts
local function setupLeaderstats(plr: Player)
    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = plr
    local coinsVal = Instance.new("IntValue")
    coinsVal.Name = "Coins"
    coinsVal.Value = Economy.Get(plr.UserId)
    coinsVal.Parent = ls
    local winsVal = Instance.new("IntValue")
    winsVal.Name = "Wins"
    winsVal.Value = Leaderboard.GetWins(plr.UserId)
    winsVal.Parent = ls
end

Players.PlayerAdded:Connect(function(plr)
    setupLeaderstats(plr)
    -- Teleport newcomers to start when they spawn
    plr.CharacterAdded:Connect(function()
        task.wait(0.2)
        teleportTo(currentStartCF, plr)
    end)
end)

-- Update leaderstats when players rejoin the server (in case coins loaded late)
for _, plr in ipairs(Players:GetPlayers()) do
    if not plr:FindFirstChild("leaderstats") then
        setupLeaderstats(plr)
    end
end

return {}