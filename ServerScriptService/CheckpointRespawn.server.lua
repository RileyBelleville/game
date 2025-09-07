--!strict
-- CheckpointRespawn: remembers the last checkpoint a player touched and
-- respawns them there after death or reconnecting mid‑round.  Checkpoints
-- are parts named "Checkpoint" spawned by ObbyLibrary.  Whenever a new
-- course is built, checkpoint data is cleared.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ARENA_FOLDER_NAME = "ArenaRuntime"
local COURSE_FOLDER_NAME = "Course"
local CHECKPOINT_NAME   = "Checkpoint"
local TELEPORT_OFFSET_Y = 4

-- Remember the last checkpoint CFrame for each player
local lastCheckpointByUser: {[number]: CFrame} = {}

local function safeTeleport(cf: CFrame?, plr: Player)
    if not cf then return end
    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
        plr.Character.HumanoidRootPart.CFrame = cf + Vector3.new(0, TELEPORT_OFFSET_Y, 0)
    end
end

-- Attach a Touched listener to a checkpoint part to record the checkpoint
local function hookCheckpointTouch(part: BasePart)
    if part:GetAttribute("CheckpointHook") then return end
    part:SetAttribute("CheckpointHook", true)
    part.Touched:Connect(function(hit)
        local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local plr = Players:GetPlayerFromCharacter(hum.Parent)
        if not plr then return end
        lastCheckpointByUser[plr.UserId] = part.CFrame
    end)
end

-- Set up watchers on the arena folder to hook checkpoints and clear on new courses
local function watchArena(arenaFolder: Folder)
    -- Hook existing checkpoints
    for _, desc in ipairs(arenaFolder:GetDescendants()) do
        if desc:IsA("BasePart") and desc.Name == CHECKPOINT_NAME then
            hookCheckpointTouch(desc)
        end
    end
    -- Hook future checkpoints
    arenaFolder.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") and desc.Name == CHECKPOINT_NAME then
            hookCheckpointTouch(desc)
        end
    end)
    -- Clear checkpoints when a new course is inserted
    arenaFolder.ChildAdded:Connect(function(child)
        if child:IsA("Folder") and child.Name == COURSE_FOLDER_NAME then
            -- Reset all checkpoints at the start of a new course
            lastCheckpointByUser = {}
        end
    end)
end

-- Initialize watcher when the ArenaRuntime folder is available
local function init()
    local arenaFolder = Workspace:FindFirstChild(ARENA_FOLDER_NAME)
    if arenaFolder then
        watchArena(arenaFolder)
    else
        Workspace.ChildAdded:Connect(function(child)
            if child.Name == ARENA_FOLDER_NAME and child:IsA("Folder") then
                watchArena(child)
            end
        end)
    end
end

init()

-- When players respawn, teleport them to their checkpoint if available
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        safeTeleport(lastCheckpointByUser[plr.UserId], plr)
    end)
end)

return {}