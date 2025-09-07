--!strict
-- ResultsPodium: builds and clears a simple podium for the top three finishers.
-- The podium consists of three platforms at different heights and colours.  It
-- is spawned in Workspace under a folder named "Podium".  The RoundManager
-- teleports winners to the appropriate platforms.

local Workspace = game:GetService("Workspace")

local Podium = {}

-- Build the podium at a position relative to the arena center.  Returns a
-- table of parts (though only used for teleporting players in RoundManager).
function Podium.Build(center: CFrame): {BasePart}
    local folder = Instance.new("Folder")
    folder.Name = "Podium"
    folder.Parent = Workspace
    -- Helper to create a platform part
    local function platform(size: Vector3, cf: CFrame, color: Color3, name: string)
        local p = Instance.new("Part")
        p.Anchored = true
        p.Size = size
        p.CFrame = cf
        p.Color = color
        p.Name = name
        p.Parent = folder
        return p
    end
    -- Base location offset forward from center
    local baseCF = center * CFrame.new(0,1,18)
    -- Second place (middle height)
    local p2 = platform(Vector3.new(6,2,6), baseCF, Color3.fromRGB(200,200,200), "P2")
    -- First place (highest)
    local p1 = platform(Vector3.new(6,3,6), baseCF * CFrame.new(-7,0.5,0), Color3.fromRGB(255,220,120), "P1")
    -- Third place (lowest)
    local p3 = platform(Vector3.new(6,1.5,6), baseCF * CFrame.new(7,-0.25,0), Color3.fromRGB(200,200,200), "P3")
    return {p1,p2,p3}
end

-- Destroy the podium if it exists
function Podium.Clear()
    local existing = Workspace:FindFirstChild("Podium")
    if existing then
        existing:Destroy()
    end
end

return Podium