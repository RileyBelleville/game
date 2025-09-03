--!strict
-- ClientMain: builds all client‑side UI and wires up remote events for
-- Obby Universe Ultimate.  This script runs in each player's client and
-- manages the HUD, voting interface, shop, inventory, leaderboard and
-- spectating.  It listens for server broadcasts via RemoteEvents and
-- updates the UI accordingly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundUpdate = Remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local FinishEvent = Remotes:WaitForChild("FinishEvent") :: RemoteEvent
local VoteEvent = Remotes:WaitForChild("VoteEvent") :: RemoteEvent
local VoteUpdate = Remotes:WaitForChild("VoteUpdate") :: RemoteEvent
local ShopPurchase = Remotes:WaitForChild("ShopPurchase") :: RemoteEvent
local EquipTrail   = Remotes:WaitForChild("EquipTrail") :: RemoteEvent
local InventoryQuery = Remotes:WaitForChild("InventoryQuery") :: RemoteFunction
local ScoreUpdate = Remotes:WaitForChild("ScoreUpdate") :: RemoteEvent
local LeaderboardUpdate = Remotes:WaitForChild("LeaderboardUpdate") :: RemoteEvent

-- Additional remotes
local SetAFK = Remotes:WaitForChild("SetAFK") :: RemoteEvent
local GlobalBoardQuery = Remotes:WaitForChild("GlobalBoardQuery") :: RemoteFunction
local GlobalCoinsBoardQuery = Remotes:WaitForChild("GlobalCoinsBoardQuery") :: RemoteFunction
local AchievementUnlocked = Remotes:WaitForChild("AchievementUnlocked") :: RemoteEvent

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Util   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Util"))

-- Helper to determine a player's title based on their total wins.  Titles
-- are defined in Config.Titles in descending threshold order.  The
-- first entry whose threshold is less than or equal to the wins value
-- will be used.
local function getTitleFromWins(wins: number): string
    for _, t in ipairs(Config.Titles) do
        if wins >= t.threshold then
            return t.name
        end
    end
    return ""
end

-- Attach or update a BillboardGui showing the player's title above
-- their head.  This runs on the client and works for all players in
-- the server.  It listens for changes to the Wins leaderstat so the
-- title updates dynamically when a player earns more wins.
local function attachTitleGui(plr: Player)
    local function updateTitle()
        local winsVal = 0
        local ls = plr:FindFirstChild("leaderstats")
        if ls then
            local w = ls:FindFirstChild("Wins")
            if w and typeof(w.Value) == "number" then
                winsVal = w.Value
            end
        end
        local title = getTitleFromWins(winsVal)
        local char = plr.Character
        if char and char:FindFirstChild("Head") then
            local head = char.Head
            local bb = head:FindFirstChild("TitleBillboard")
            if not bb then
                bb = Instance.new("BillboardGui")
                bb.Name = "TitleBillboard"
                bb.Adornee = head
                bb.Size = UDim2.new(0, 200, 0, 40)
                bb.StudsOffset = Vector3.new(0, 2.6, 0)
                bb.AlwaysOnTop = true
                local label = Instance.new("TextLabel")
                label.Name = "TitleLabel"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(1,0,1,0)
                label.Font = Enum.Font.GothamBold
                label.TextScaled = true
                label.TextColor3 = Color3.fromRGB(255,255,255)
                label.TextStrokeTransparency = 0.3
                label.Parent = bb
                bb.Parent = head
            end
            -- update text
            local label = bb:FindFirstChild("TitleLabel")
            if label and label:IsA("TextLabel") then
                label.Text = title
            end
        end
    end
    -- Update now
    updateTitle()
    -- Listen for changes to wins
    local ls = plr:FindFirstChild("leaderstats")
    if ls then
        local w = ls:FindFirstChild("Wins")
        if w then
            w.Changed:Connect(function()
                updateTitle()
            end)
        end
    end
    -- Update on respawn
    plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        updateTitle()
    end)
end

-- Build a ScreenGui to hold everything.  ResetOnSpawn=false so UI persists
local gui = Instance.new("ScreenGui")
gui.Name = "ObbyGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- [[ HUD ]] --
local hudFrame = Instance.new("Frame")
hudFrame.BackgroundTransparency = 1
hudFrame.Size = UDim2.new(1,0,0,80)
hudFrame.Position = UDim2.new(0,0,0,0)
hudFrame.Parent = gui

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.BackgroundTransparency = 1
timerLabel.Position = UDim2.new(0.5,-100,0,5)
timerLabel.Size = UDim2.new(0,200,0,30)
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextSize = 24
timerLabel.TextColor3 = Color3.fromRGB(255,255,255)
timerLabel.TextStrokeTransparency = 0.5
timerLabel.Text = ""
timerLabel.Parent = hudFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.new(0,10,0,5)
statusLabel.Size = UDim2.new(0,400,0,30)
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.TextSize = 20
statusLabel.TextColor3 = Color3.fromRGB(255,255,255)
statusLabel.TextStrokeTransparency = 0.5
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = ""
statusLabel.Parent = hudFrame

local winnersLabel = Instance.new("TextLabel")
winnersLabel.Name = "Winners"
winnersLabel.BackgroundTransparency = 1
winnersLabel.Position = UDim2.new(0,10,0,38)
winnersLabel.Size = UDim2.new(0,600,0,30)
winnersLabel.Font = Enum.Font.Gotham
winnersLabel.TextSize = 18
winnersLabel.TextColor3 = Color3.fromRGB(220,220,220)
winnersLabel.TextXAlignment = Enum.TextXAlignment.Left
winnersLabel.Text = ""
winnersLabel.Parent = hudFrame

-- Coin display at top right
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "Coins"
coinsLabel.BackgroundTransparency = 0.25
coinsLabel.BackgroundColor3 = Color3.fromRGB(30,30,30)
coinsLabel.Position = UDim2.new(1,-160,0,5)
coinsLabel.Size = UDim2.new(0,150,0,30)
coinsLabel.Font = Enum.Font.GothamSemibold
coinsLabel.TextSize = 20
coinsLabel.TextColor3 = Color3.fromRGB(255,215,0)
coinsLabel.Text = "Coins: 0"
coinsLabel.Parent = hudFrame

-- AFK indicator: shows whether the local player is AFK.  Press "K" to toggle.
local afkLabel = Instance.new("TextLabel")
afkLabel.Name = "AFKLabel"
afkLabel.BackgroundTransparency = 0.35
afkLabel.BackgroundColor3 = Color3.fromRGB(40,40,40)
afkLabel.Position = UDim2.new(0, 10, 0, 68)
afkLabel.Size = UDim2.new(0, 80, 0, 22)
afkLabel.Font = Enum.Font.GothamSemibold
afkLabel.TextSize = 14
afkLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
afkLabel.Text = "AFK: OFF"
afkLabel.Parent = hudFrame

-- [[ Voting UI ]] --
local voteFrame = Instance.new("Frame")
voteFrame.Name = "VoteFrame"
voteFrame.Visible = false
voteFrame.BackgroundTransparency = 0.2
voteFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
voteFrame.Position = UDim2.new(0.5,-200,1,-180)
voteFrame.Size = UDim2.new(0,400,0,160)
voteFrame.BorderSizePixel = 0
voteFrame.Parent = gui

local voteTitle = Instance.new("TextLabel")
voteTitle.BackgroundTransparency = 1
voteTitle.Position = UDim2.new(0,0,0,0)
voteTitle.Size = UDim2.new(1,0,0,30)
voteTitle.Font = Enum.Font.GothamBold
voteTitle.TextSize = 22
voteTitle.TextColor3 = Color3.fromRGB(255,255,255)
voteTitle.Text = "Vote for the next course"
voteTitle.Parent = voteFrame

local voteButtons: {TextButton} = {}
for i=1,3 do
    local btn = Instance.new("TextButton")
    btn.Name = "VoteButton" .. i
    btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
    btn.BorderSizePixel = 0
    btn.Position = UDim2.new(0.1,0,0,30 + (i-1)*40)
    btn.Size = UDim2.new(0.8,0,0,30)
    btn.AutoButtonColor = true
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 20
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Text = ""
    btn.Parent = voteFrame
    voteButtons[i] = btn
end

-- Keep track of the current vote options
local currentOptions: {string} = {}

-- When a button is clicked, send the vote to the server
for i, btn in ipairs(voteButtons) do
    btn.MouseButton1Click:Connect(function()
        local choice = currentOptions[i]
        if choice then
            VoteEvent:FireServer(choice)
            -- Provide visual feedback by highlighting
            for j, other in ipairs(voteButtons) do
                if j == i then
                    other.BackgroundColor3 = Color3.fromRGB(80,120,80)
                else
                    other.BackgroundColor3 = Color3.fromRGB(40,40,40)
                end
            end
        end
    end)
end

-- [[ Shop / Inventory UI ]] --
local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.Visible = false
shopFrame.BackgroundTransparency = 0.2
shopFrame.BackgroundColor3 = Color3.fromRGB(15,15,15)
shopFrame.Position = UDim2.new(0.5,-200,0.5,-200)
shopFrame.Size = UDim2.new(0,400,0,360)
shopFrame.BorderSizePixel = 0
shopFrame.Parent = gui

local shopTitle = Instance.new("TextLabel")
shopTitle.BackgroundTransparency = 1
shopTitle.Position = UDim2.new(0,0,0,0)
shopTitle.Size = UDim2.new(1,0,0,40)
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextSize = 24
shopTitle.TextColor3 = Color3.fromRGB(255,255,255)
shopTitle.Text = "Shop"
shopTitle.Parent = shopFrame

-- Container for items
local itemsScrolling = Instance.new("ScrollingFrame")
itemsScrolling.BackgroundTransparency = 1
itemsScrolling.Position = UDim2.new(0,0,0,40)
itemsScrolling.Size = UDim2.new(1,0,1,-40)
itemsScrolling.CanvasSize = UDim2.new(0,0,0,0)
itemsScrolling.ScrollBarThickness = 6
itemsScrolling.Parent = shopFrame

-- Template for item entries
local function createItemEntry(item: {id: string, name: string, cost: number, color: Color3}, owned: boolean)
    local entry = Instance.new("Frame")
    entry.Size = UDim2.new(1,0,0,50)
    entry.BackgroundTransparency = 0.3
    entry.BackgroundColor3 = Color3.fromRGB(30,30,30)
    -- Item name
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0,10,0,5)
    lbl.Size = UDim2.new(0.5,0,0,40)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 20
    lbl.TextColor3 = item.color
    lbl.Text = item.name
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = entry
    -- Price / equip button
    local btn = Instance.new("TextButton")
    btn.Position = UDim2.new(0.6,0,0,10)
    btn.Size = UDim2.new(0.35,0,0,30)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 18
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.AutoButtonColor = true
    if owned then
        btn.BackgroundColor3 = Color3.fromRGB(60,120,60)
        btn.Text = "Equip"
    else
        btn.BackgroundColor3 = Color3.fromRGB(80,80,120)
        btn.Text = tostring(item.cost) .. "c"
    end
    btn.Parent = entry
    btn.MouseButton1Click:Connect(function()
        if owned then
            EquipTrail:FireServer(item.id)
        else
            ShopPurchase:FireServer(item.id)
        end
    end)
    return entry
end

-- Populate shop UI based on player's inventory and Config.Shop
local function populateShop(inv: {string})
    -- Clear existing entries
    itemsScrolling:ClearAllChildren()
    -- Build entries
    local y = 0
    for _, item in ipairs(Config.Shop) do
        local owned = false
        for _, id in ipairs(inv) do
            if id == item.id then owned = true break end
        end
        local entry = createItemEntry(item, owned)
        entry.Position = UDim2.new(0,0,0,y)
        entry.Parent = itemsScrolling
        y += 50
    end
    itemsScrolling.CanvasSize = UDim2.new(0,0,0,y)
end

-- Toggle shop visibility and refresh content
local shopVisible = false
local function toggleShop()
    shopVisible = not shopVisible
    shopFrame.Visible = shopVisible
    if shopVisible then
        -- Query inventory and update entries
        local inv = InventoryQuery:InvokeServer()
        populateShop(inv)
    end
end

-- [[ Leaderboard UI ]] --
local boardFrame = Instance.new("Frame")
boardFrame.Name = "LeaderboardFrame"
boardFrame.Visible = false
boardFrame.BackgroundTransparency = 0.25
boardFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
boardFrame.Position = UDim2.new(1,-220,0.3,0)
boardFrame.Size = UDim2.new(0,200,0,250)
boardFrame.BorderSizePixel = 0
boardFrame.Parent = gui

local boardTitle = Instance.new("TextLabel")
boardTitle.BackgroundTransparency = 1
boardTitle.Position = UDim2.new(0,0,0,0)
boardTitle.Size = UDim2.new(1,0,0,30)
boardTitle.Font = Enum.Font.GothamBold
boardTitle.TextSize = 22
boardTitle.TextColor3 = Color3.fromRGB(255,255,255)
boardTitle.Text = "Wins Leaderboard"
boardTitle.Parent = boardFrame

local boardList = Instance.new("Frame")
boardList.BackgroundTransparency = 1
boardList.Position = UDim2.new(0,0,0,30)
boardList.Size = UDim2.new(1,0,1,-30)
boardList.Parent = boardFrame

-- Track which board is currently displayed.  "wins" shows the wins
-- leaderboard; "coins" shows the global coins leaderboard.
local boardMode = "wins"

-- Update the coins leaderboard UI.  Accepts a list of entries with
-- `userId` and `coins` fields.  Similar to updateLeaderboard but uses
-- the coins property.
local function updateCoinsLeaderboard(list: {{userId: number, coins: number}})
    boardList:ClearAllChildren()
    local y = 0
    for index, entry in ipairs(list) do
        if index > 5 then break end
        local plrEntry = Players:GetPlayerByUserId(entry.userId)
        local name = plrEntry and plrEntry.Name or ("User" .. tostring(entry.userId))
        local row = Instance.new("TextLabel")
        row.BackgroundTransparency = 1
        row.Position = UDim2.new(0, 0, 0, y)
        row.Size = UDim2.new(1, 0, 0, 24)
        row.Font = Enum.Font.Gotham
        row.TextSize = 18
        row.TextColor3 = Color3.fromRGB(255, 255, 255)
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Text = tostring(index) .. ". " .. name .. " - " .. tostring(entry.coins)
        row.Parent = boardList
        y += 24
    end
end

-- Update leaderboard UI
local function updateLeaderboard(list: {{userId: number, wins: number}})
    boardList:ClearAllChildren()
    local y = 0
    for index, entry in ipairs(list) do
        if index > 5 then break end
        local plr = Players:GetPlayerByUserId(entry.userId)
        local name = plr and plr.Name or ("User" .. tostring(entry.userId))
        local row = Instance.new("TextLabel")
        row.BackgroundTransparency = 1
        row.Position = UDim2.new(0,0,0,y)
        row.Size = UDim2.new(1,0,0,24)
        row.Font = Enum.Font.Gotham
        row.TextSize = 18
        row.TextColor3 = Color3.fromRGB(255,255,255)
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Text = tostring(index) .. ". " .. name .. " - " .. tostring(entry.wins)
        row.Parent = boardList
        y += 24
    end
end

-- Toggle leaderboard
local boardVisible = false
local function toggleLeaderboard()
    boardVisible = not boardVisible
    boardFrame.Visible = boardVisible
    -- When showing the leaderboard, refresh its contents based on the current mode
    if boardVisible then
        if boardMode == "coins" then
            -- Fetch and display the global coins board
            local ok, data = pcall(function()
                return GlobalCoinsBoardQuery:InvokeServer(10)
            end)
            if ok and type(data) == "table" then
                updateCoinsLeaderboard(data)
            end
            boardTitle.Text = "Coins Leaderboard"
        else
            -- Fetch and display the wins leaderboard
            local ok, data = pcall(function()
                return GlobalBoardQuery:InvokeServer(10)
            end)
            if ok and type(data) == "table" then
                updateLeaderboard(data)
            end
            boardTitle.Text = "Wins Leaderboard"
        end
    end
end

-- Cycle between wins and coins leaderboard.  Ensures the leaderboard UI
-- is visible before toggling.  Calling this will fetch the appropriate
-- leaderboard and update the display.
local function toggleBoardMode()
    -- If the board is hidden, show it
    if not boardVisible then
        boardVisible = true
        boardFrame.Visible = true
    end
    if boardMode == "wins" then
        boardMode = "coins"
        boardTitle.Text = "Coins Leaderboard"
        local ok, data = pcall(function()
            return GlobalCoinsBoardQuery:InvokeServer(10)
        end)
        if ok and type(data) == "table" then
            updateCoinsLeaderboard(data)
        end
    else
        boardMode = "wins"
        boardTitle.Text = "Wins Leaderboard"
        local ok, data = pcall(function()
            return GlobalBoardQuery:InvokeServer(10)
        end)
        if ok and type(data) == "table" then
            updateLeaderboard(data)
        end
    end
end

-- [[ Spectate ]] -- simple camera cycle through alive players
local spectating = false
local spectateIndex = 1
local spectateTargets: {Player} = {}
local camera = workspace.CurrentCamera
local originalCamSubject: any = nil

local function updateSpectateTargets()
    spectateTargets = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                table.insert(spectateTargets, plr)
            end
        end
    end
end

local function toggleSpectate()
    if not spectating then
        updateSpectateTargets()
        if #spectateTargets == 0 then return end
        spectating = true
        spectateIndex = 1
        originalCamSubject = camera.CameraSubject
        camera.CameraType = Enum.CameraType.Scriptable
        -- set camera CFrame to follow target
        local target = spectateTargets[spectateIndex]
        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            camera.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0,10,15) * CFrame.new(0,0,0).Rotation -- just behind
        end
    else
        -- advance to next target or exit
        updateSpectateTargets()
        if #spectateTargets == 0 then
            -- exit
            spectating = false
            camera.CameraType = Enum.CameraType.Custom
            if originalCamSubject then
                camera.CameraSubject = originalCamSubject
            end
            return
        end
        spectateIndex += 1
        if spectateIndex > #spectateTargets then spectateIndex = 1 end
        local target = spectateTargets[spectateIndex]
        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            camera.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0,10,15)
        end
    end
end

-- [[ Remote Event Handlers ]] --
-- Round status updates: status string, time left and winners list
RoundUpdate.OnClientEvent:Connect(function(status: string, timeLeft: number, winnerIds: {number})
    statusLabel.Text = status
    if timeLeft and timeLeft > 0 then
        timerLabel.Text = "⏱ " .. tostring(timeLeft) .. "s"
    else
        timerLabel.Text = ""
    end
    -- Build winner list text
    if winnerIds and #winnerIds > 0 then
        local names = {}
        for _, uid in ipairs(winnerIds) do
            local plr = Players:GetPlayerByUserId(uid)
            table.insert(names, plr and plr.Name or ("User" .. tostring(uid)))
        end
        winnersLabel.Text = "Winners: " .. table.concat(names, ", ")
    else
        winnersLabel.Text = "Winners: —"
    end
end)

-- Individual finish announcements (can be used for flair)
FinishEvent.OnClientEvent:Connect(function(name: string)
    -- Could show a message like "🏁 NAME finished!" but keep HUD clean for now
end)

-- Voting updates: options, current votes, time left
VoteUpdate.OnClientEvent:Connect(function(options: {string}, votesTbl: {[number]: string}, timeLeft: number)
    currentOptions = options
    -- Show or hide voting frame based on presence of options
    voteFrame.Visible = (options ~= nil)
    if options then
        for i=1,#voteButtons do
            local text = options[i]
            if text then
                voteButtons[i].Text = text
                voteButtons[i].Visible = true
                voteButtons[i].BackgroundColor3 = Color3.fromRGB(40,40,40)
            else
                voteButtons[i].Visible = false
            end
        end
    end
end)

-- Score updates: update coin display
ScoreUpdate.OnClientEvent:Connect(function(newBalance: number)
    coinsLabel.Text = "Coins: " .. tostring(newBalance)
end)

-- Leaderboard updates: update board UI
LeaderboardUpdate.OnClientEvent:Connect(function(board: {{userId: number, wins: number}})
    -- Only refresh if showing wins leaderboard
    if boardMode == "wins" then
        updateLeaderboard(board)
    end
end)

-- Achievement notifications: display a temporary message when the player
-- unlocks an achievement.  The server passes the achievement name and
-- coin reward.  The message will fade after a few seconds.
local achievementLabel = Instance.new("TextLabel")
achievementLabel.BackgroundTransparency = 0.4
achievementLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
achievementLabel.Position = UDim2.new(0.5, -200, 0.2, 0)
achievementLabel.Size = UDim2.new(0, 400, 0, 40)
achievementLabel.Font = Enum.Font.GothamBold
achievementLabel.TextSize = 20
achievementLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
achievementLabel.TextStrokeTransparency = 0.4
achievementLabel.Text = ""
achievementLabel.Visible = false
achievementLabel.Parent = gui

local function showAchievement(name: string, reward: number)
    achievementLabel.Text = "🏆 Achievement: " .. name
    if reward and reward > 0 then
        achievementLabel.Text = achievementLabel.Text .. "  +" .. tostring(reward) .. " coins"
    end
    achievementLabel.Visible = true
    -- Hide after a short duration
    task.spawn(function()
        task.wait(4)
        achievementLabel.Visible = false
    end)
end

AchievementUnlocked.OnClientEvent:Connect(function(name: string, reward: number)
    showAchievement(name, reward)
end)

-- [[ Input Handling ]] --
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.O then
        toggleShop()
    elseif input.KeyCode == Enum.KeyCode.L then
        toggleLeaderboard()
    elseif input.KeyCode == Enum.KeyCode.C then
        toggleBoardMode()
    elseif input.KeyCode == Enum.KeyCode.V then
        toggleSpectate()
    elseif input.KeyCode == Enum.KeyCode.K then
        -- Toggle AFK state on the server.  No argument toggles the state.
        SetAFK:FireServer()
        -- Optimistically update label; actual state will be confirmed on next toggle
        if afkLabel.Text == "AFK: OFF" then
            afkLabel.Text = "AFK: ON"
        else
            afkLabel.Text = "AFK: OFF"
        end
    end
end)

-- On character respawn, reset spectate and update inventory/coins
local function onCharacterAdded()
    spectating = false
    camera.CameraType = Enum.CameraType.Custom
    -- Refresh shop inventory after respawn
    if shopVisible then
        local inv = InventoryQuery:InvokeServer()
        populateShop(inv)
    end
end

if player.Character then
    onCharacterAdded()
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Initial coin load
-- The server sets leaderstats Coins, but ScoreUpdate may not fire until later.
task.defer(function()
    -- Try to read leaderstats if available
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local c = ls:FindFirstChild("Coins")
        if c then
            coinsLabel.Text = "Coins: " .. tostring(c.Value)
        end
    end
end)

-- Attach title GUI to all current players and future players.  Titles
-- reflect the number of wins a player has achieved and update
-- automatically when wins change.
for _, other in ipairs(Players:GetPlayers()) do
    attachTitleGui(other)
end
Players.PlayerAdded:Connect(function(plr)
    attachTitleGui(plr)
end)

return nil