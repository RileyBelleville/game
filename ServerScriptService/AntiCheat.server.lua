--!strict
-- AntiCheat: simple movement sanity checker.  If a player moves an
-- unreasonable distance between heartbeats (e.g. via speed hacks or
-- teleport), their HumanoidRootPart will be softly snapped back toward the
-- previous location.  This is intentionally lenient to avoid false
-- positives during lag spikes.  For more robust anti‑cheat, consider using
-- server‑authoritative movement or specialized solutions.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MAX_DELTA = 120 -- studs per heartbeat; adjust as desired

local lastPos: {[number]: Vector3} = {}

RunService.Heartbeat:Connect(function(dt)
    for _, plr in ipairs(Players:GetPlayers()) do
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local prev = lastPos[plr.UserId]
            if prev then
                local d = (hrp.Position - prev).Magnitude
                if d > MAX_DELTA then
                    -- Snap back partly toward previous position
                    local dir = (hrp.Position - prev).Unit
                    hrp.Position = prev + dir * 5
                end
            end
            lastPos[plr.UserId] = hrp.Position
        end
    end
end)

return {}