--!strict
-- ObbyLibrary: toolbox for building wipeout‑style courses in Obby Universe Ultimate.
--
-- Each generator accepts a parent folder (`root`), a starting CFrame, and
-- various parameters.  It populates the course with obstacle parts, inserting
-- them into the provided `root` and appending them to the `outParts` table
-- supplied.  Generators return the CFrame at which the next section should
-- begin.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObbyLibrary = {}

export type BuildResult = {
    StartCF: CFrame,
    FinishPart: BasePart,
    AllParts: { BasePart },
}

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

-- Create a part with sensible defaults.  `props` can override any
-- Instance properties.  The part is parented to `parent`.
local function part(props: {[string]: any}, parent: Instance): BasePart
    local p = Instance.new("Part")
    p.Anchored = props.Anchored ~= false
    p.CanCollide = props.CanCollide ~= false
    p.Material = props.Material or Enum.Material.Plastic
    p.Color = props.Color or Color3.fromRGB(230,230,230)
    p.Size = props.Size or Vector3.new(4,1,4)
    p.CFrame = props.CFrame or CFrame.new()
    p.Name = props.Name or "Part"
    p.Transparency = props.Transparency or 0
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function mkFinish(parent: Instance, cf: CFrame): BasePart
    return part({
        CFrame = cf,
        Size = Vector3.new(8,1,8),
        Color = Color3.fromRGB(120,255,120),
        Name = "Finish",
    }, parent)
end

local function mkCheckpoint(parent: Instance, cf: CFrame): BasePart
    return part({
        CFrame = cf,
        Size = Vector3.new(6,1,6),
        Color = Color3.fromRGB(100,200,255),
        Name = "Checkpoint",
    }, parent)
end

local function mkHazard(parent: Instance, cf: CFrame, size: Vector3?, name: string?): BasePart
    return part({
        CFrame = cf,
        Size = size or Vector3.new(6,1,6),
        Color = Color3.fromRGB(255,90,90),
        Name = name or "Hazard",
    }, parent)
end

-- Attach a server‑side kill touch to a part.  When a humanoid touches
-- this part, it will immediately set its health to zero.
local function attachKillTouch(p: BasePart)
    p.Touched:Connect(function(hit)
        local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Health = 0
        end
    end)
end

---------------------------------------------------------------------
-- Generators
---------------------------------------------------------------------

-- 1) Gap Jumps: straight run with evenly spaced platforms.  Every few
-- segments, lava hazards lurk below and checkpoints appear.
local function genGapJumps(root: Instance, startCF: CFrame, segments: number, gap: number, out: {BasePart}): BasePart?
    local cf = startCF
    local lastPlate: BasePart? = nil
    for i=1, segments do
        local plate = part({
            CFrame = cf,
            Size = Vector3.new(6,1,6),
            Color = Color3.fromRGB(245,245,245),
            Name = "Plate_" .. i,
        }, root)
        table.insert(out, plate)
        lastPlate = plate
        cf = cf * CFrame.new(0,0,-(6 + gap))
        -- Lava pits every 4th segment
        if i % 4 == 0 then
            local haz = mkHazard(root, (plate.CFrame * CFrame.new(0,-2.2,-(gap/2))), Vector3.new(6,1,6), "Lava")
            attachKillTouch(haz)
            table.insert(out, haz)
        end
        -- Checkpoints every 5th segment
        if i % 5 == 0 then
            table.insert(out, mkCheckpoint(root, plate.CFrame))
        end
    end
    return lastPlate
end

-- 2) Moving Planks: horizontal platforms that oscillate left and right.
local function genMovingPlanks(root: Instance, startCF: CFrame, count: number, span: number, out: {BasePart}): CFrame
    local cf = startCF
    for i=1, count do
        local p = part({
            CFrame = cf * CFrame.new(0,0,-i*8),
            Size = Vector3.new(6,1,6),
            Color = Color3.fromRGB(180,255,190),
            Name = "Mover_" .. i,
        }, root)
        table.insert(out, p)
        local a0 = p.CFrame * CFrame.new(-span/2, 0, 0)
        local a1 = p.CFrame * CFrame.new( span/2, 0, 0)
        task.spawn(function()
            while p.Parent do
                local t1 = TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = a1})
                t1:Play(); t1.Completed:Wait()
                local t2 = TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = a0})
                t2:Play(); t2.Completed:Wait()
            end
        end)
    end
    return startCF * CFrame.new(0,0,-count*8)
end

-- 3) Rotating Sweeper: central rotating arms that knock players off.
local function genSweeper(root: Instance, centerCF: CFrame, radius: number, arms: number, height: number, out: {BasePart}): BasePart
    local base = part({
        CFrame = centerCF,
        Size = Vector3.new(4,1,4),
        Color = Color3.fromRGB(180,180,180),
        Name = "SweeperBase",
    }, root)
    table.insert(out, base)
    local armParts: {BasePart} = {}
    for i=1, arms do
        local arm = Instance.new("Part")
        arm.Anchored = true
        arm.CanCollide = true
        arm.Shape = Enum.PartType.Cylinder
        arm.Size = Vector3.new(1, 0.8, radius)
        arm.Color = Color3.fromRGB(255,170,0)
        arm.CFrame = centerCF * CFrame.new(0,height,-radius/2) * CFrame.Angles(0,0,math.rad(90))
        arm.Name = "Arm_" .. i
        arm.Parent = root
        table.insert(armParts, arm)
        table.insert(out, arm)
    end
    -- Rotate arms continuously
    task.spawn(function()
        local rot = 0
        local speed = (math.random(25,55)/100) -- radians per heartbeat
        while base.Parent do
            rot += speed
            for _,arm in ipairs(armParts) do
                arm.CFrame = centerCF * CFrame.Angles(0,rot,0) * CFrame.new(0,height,-radius/2) * CFrame.Angles(0,0,math.rad(90))
            end
            RunService.Heartbeat:Wait()
        end
    end)
    return base
end

-- 4) Popup Pillars: pillars that rise and sink periodically.
local function genPopupPillars(root: Instance, startCF: CFrame, count: number, spacing: number, out: {BasePart}): CFrame
    local cf = startCF
    for i=1, count do
        local p = part({
            CFrame = cf * CFrame.new(0,0,-i*spacing),
            Size = Vector3.new(6,2,6),
            Color = Color3.fromRGB(255,200,120),
            Name = "Pillar_" .. i,
        }, root)
        table.insert(out, p)
        task.spawn(function()
            while p.Parent do
                p.CFrame = p.CFrame * CFrame.new(0,2,0)
                task.wait(0.6)
                p.CFrame = p.CFrame * CFrame.new(0,-2,0)
                task.wait(0.6 + math.random()*0.4)
            end
        end)
    end
    return startCF * CFrame.new(0,0,-count*spacing)
end

-- 5) Shrinking Plates: plates that shrink and grow in size.
local function genShrinkPlates(root: Instance, startCF: CFrame, segments: number, out: {BasePart}): CFrame
    local cf = startCF
    for i=1, segments do
        local p = part({
            CFrame = cf,
            Size = Vector3.new(7,1,7),
            Color = Color3.fromRGB(200,240,255),
            Name = "Shrink_" .. i,
        }, root)
        table.insert(out, p)
        task.spawn(function()
            local scale = 1
            while p.Parent do
                scale = (scale == 1) and 0.4 or 1
                local size = Vector3.new(7*scale, 1, 7*scale)
                local t = TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = size})
                t:Play(); t.Completed:Wait();
                task.wait(0.4)
            end
        end)
        cf = cf * CFrame.new(0,0,-8)
    end
    return cf
end

-- 6) Swinging Hammers: swinging pendulums with heavy heads.
local function genSwingHammers(root: Instance, centerCF: CFrame, count: number, radius: number, out: {BasePart}): CFrame
    for i=1, count do
        local angle = (i-1) * ((math.pi * 2) / count)
        local pivot = part({
            CFrame = centerCF * CFrame.Angles(0, angle, 0) * CFrame.new(radius, 6, 0),
            Size = Vector3.new(1,1,1),
            Name = "HammerPivot",
            Transparency = 1,
        }, root)
        local arm = part({
            CFrame = pivot.CFrame * CFrame.new(0,-4,0),
            Size = Vector3.new(1,8,1),
            Color = Color3.fromRGB(90,90,90),
            Name = "HammerArm",
        }, root)
        local head = part({
            CFrame = arm.CFrame * CFrame.new(0,-4.5,0),
            Size = Vector3.new(3,3,3),
            Color = Color3.fromRGB(200,50,50),
            Name = "HammerHead",
        }, root)
        table.insert(out, arm)
        table.insert(out, head)
        task.spawn(function()
            local t = 0
            while root.Parent do
                t += 0.03
                local swing = math.sin(t) * math.rad(45)
                arm.CFrame = pivot.CFrame * CFrame.Angles(swing, 0, 0) * CFrame.new(0,-4,0)
                head.CFrame = arm.CFrame * CFrame.new(0,-4.5,0)
                task.wait(0.03)
            end
        end)
    end
    return centerCF
end

-- 7) Conveyor Field: floor tiles that push players along the negative Z axis.
local function genConveyorField(root: Instance, startCF: CFrame, width: number, length: number, force: number, out: {BasePart}): CFrame
    local cf = startCF
    for z=1, length do
        for x=1, width do
            local xOffset = (x - (width/2 + 0.5)) * 7
            local tile = part({
                CFrame = cf * CFrame.new(xOffset, 0, -z*7),
                Size = Vector3.new(6,1,6),
                Color = Color3.fromRGB(160,200,255),
                Name = "Conveyor",
            }, root)
            table.insert(out, tile)
            tile.Touched:Connect(function(hit)
                local hrp = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
                if hrp and hrp:IsA("BasePart") then
                    local dir = (startCF.LookVector * -1) -- push along -Z from start
                    -- Add velocity gently; preserving existing velocity
                    hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + dir * force
                end
            end)
        end
    end
    return startCF * CFrame.new(0,0,-length*7)
end

-- 8) Wind Tunnel: corridor that pushes players sideways along the X axis.
local function genWindTunnel(root: Instance, startCF: CFrame, width: number, length: number, force: number, out: {BasePart}): CFrame
    local cf = startCF
    for z=1, length do
        for x=1, width do
            local xOffset = (x - (width/2 + 0.5)) * 7
            local tile = part({
                CFrame = cf * CFrame.new(xOffset, 0, -z*7),
                Size = Vector3.new(6,1,6),
                Color = Color3.fromRGB(180,220,255),
                Name = "Wind",
            }, root)
            table.insert(out, tile)
            tile.Touched:Connect(function(hit)
                local hrp = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
                if hrp and hrp:IsA("BasePart") then
                    -- Push along local X axis relative to startCF
                    local dir = (startCF.RightVector) -- rightwards from start
                    hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + dir * force
                end
            end)
        end
    end
    return startCF * CFrame.new(0,0,-length*7)
end

-- 9) Spinner Blades: rotating thin blades positioned above the floor.
local function genSpinnerBlades(root: Instance, startCF: CFrame, count: number, out: {BasePart}): CFrame
    local cf = startCF
    for i=1, count do
        local pivot = part({
            CFrame = cf * CFrame.new(0,3,-i*6),
            Size = Vector3.new(1,1,1),
            Name = "SpinPivot",
            Transparency = 1,
        }, root)
        local blade = part({
            CFrame = pivot.CFrame,
            Size = Vector3.new(8,0.5,1),
            Color = Color3.fromRGB(230,100,80),
            Name = "SpinBlade_" .. i,
        }, root)
        table.insert(out, blade)
        task.spawn(function()
            local angle = 0
            local speed = (math.random(50,90)/100)
            while root.Parent do
                angle += speed
                blade.CFrame = pivot.CFrame * CFrame.Angles(0, angle, 0)
                RunService.Heartbeat:Wait()
            end
        end)
        -- floor piece so players have something to stand on
        local floor = part({
            CFrame = cf * CFrame.new(0,0,-i*6),
            Size = Vector3.new(6,1,6),
            Color = Color3.fromRGB(240,240,240),
            Name = "SpinFloor_" .. i,
        }, root)
        table.insert(out, floor)
    end
    return startCF * CFrame.new(0,0,-count*6)
end

-- 11) Push Walls: floor tiles with sliding walls that move left and
-- right across the path.  Each wall moves back and forth on a loop
-- using TweenService.  Walls are hazards and will kill players on
-- contact.  The path extends along the negative Z axis.
local function genPushWalls(root: Instance, startCF: CFrame, count: number, out: {BasePart}): CFrame
    local cf = startCF
    for i=1, count do
        -- Floor tile for the segment
        local base = part({
            CFrame = cf * CFrame.new(0,0,-i*8),
            Size = Vector3.new(6,1,6),
            Color = Color3.fromRGB(200,200,200),
            Name = "PushBase_" .. i,
        }, root)
        table.insert(out, base)
        -- Wall that will slide across this tile
        local wall = part({
            CFrame = base.CFrame * CFrame.new(-4,1.5,0),
            Size = Vector3.new(1,3,6),
            Color = Color3.fromRGB(200,100,100),
            Name = "PushWall_" .. i,
        }, root)
        table.insert(out, wall)
        attachKillTouch(wall)
        -- Set up tween loop for sliding motion
        task.spawn(function()
            -- Two end positions relative to the base tile
            local posLeft  = base.CFrame * CFrame.new(-4,1.5,0)
            local posRight = base.CFrame * CFrame.new( 4,1.5,0)
            while root.Parent do
                -- Move wall from left to right
                local t1 = TweenService:Create(wall, TweenInfo.new(0.7, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {CFrame = posRight})
                t1:Play(); t1.Completed:Wait()
                -- Move back from right to left
                local t2 = TweenService:Create(wall, TweenInfo.new(0.7, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {CFrame = posLeft})
                t2:Play(); t2.Completed:Wait()
                task.wait(0.3 + math.random()*0.4)
            end
        end)
    end
    return startCF * CFrame.new(0,0,-count*8)
end

-- 10) Cannon Run: a straight section with side cannons that launch
-- spherical projectiles across the path.  Players must dodge the
-- incoming cannonballs as they make their way to the finish.  Each
-- cannon spawns balls at random intervals.  Balls are given a
-- BodyVelocity to move horizontally across the course and will kill
-- players on contact.  Cannons clean themselves up automatically via
-- Debris service.
local function genCannonRun(root: Instance, startCF: CFrame, segments: number, out: {BasePart}): CFrame
    -- Build a straight path comprised of multiple plates.  The path
    -- extends along the negative Z axis from startCF.  Each plate is
    -- 6x1x6 studs, with a light gray color for visibility.
    local cf = startCF
    local lastPlate: BasePart? = nil
    for i=1, segments do
        local plate = part({
            CFrame = cf,
            Size = Vector3.new(6,1,6),
            Color = Color3.fromRGB(230,230,230),
            Name = "CannonPlate_" .. i,
        }, root)
        table.insert(out, plate)
        lastPlate = plate
        cf = cf * CFrame.new(0,0,-7)
    end
    -- Determine the approximate midpoint of the run to position cannons.
    -- Place cannons slightly above the ground so cannonballs spawn at
    -- character height.  Cannons are placed to the left and right of
    -- the path and fire towards its center.
    local midOffset = segments * 3.5 -- half of 7 stud spacing
    local leftSpawn = startCF * CFrame.new(-12, 3, -midOffset)
    local rightSpawn = startCF * CFrame.new(12, 3, -midOffset)
    -- Helper to spawn cannonballs from a given CFrame with a given
    -- horizontal velocity direction.  The spawner loops until the
    -- parent folder is destroyed.  Cannonballs clean up after a few
    -- seconds via Debris and kill any humanoids they touch.
    local function spawnCannonBalls(spawnCF: CFrame, velocity: Vector3)
        task.spawn(function()
            while root.Parent do
                -- Create ball
                local ball = Instance.new("Part")
                ball.Shape = Enum.PartType.Ball
                ball.Size = Vector3.new(2,2,2)
                ball.Color = Color3.fromRGB(255, 80, 80)
                ball.Material = Enum.Material.Neon
                ball.CanCollide = true
                ball.CFrame = spawnCF
                ball.Parent = root
                -- BodyVelocity to propel ball across path
                local bv = Instance.new("BodyVelocity")
                bv.Velocity = velocity
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Parent = ball
                -- Kill players on touch
                ball.Touched:Connect(function(hit)
                    local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum.Health = 0
                    end
                end)
                -- Auto destroy after 6 seconds
                game.Debris:AddItem(ball, 6)
                -- Wait random interval before spawning next ball
                task.wait(1.5 + math.random())
            end
        end)
    end
    -- Launchers: left fires to the right (+X), right fires to the left (-X)
    spawnCannonBalls(leftSpawn, Vector3.new(35, 0, 0))
    spawnCannonBalls(rightSpawn, Vector3.new(-35, 0, 0))
    -- Return the CFrame at the end of this section
    return cf
end

-- 11) Maze Run: a simple branching maze consisting of rows of platforms.  Each
-- row has multiple positions along the X axis, but only one is safe.  Players
-- must follow the safe path; stepping onto the wrong platform results in a
-- fall or a hazard kill.  The safe path may veer left or right between
-- adjacent rows to create a winding path.  The maze extends along the
-- negative Z axis from the starting frame.  `rows` controls the number of
-- segments.  Returns the CFrame at the end of the maze.
local function genMazeRun(root: Instance, startCF: CFrame, rows: number, out: {BasePart}): CFrame
    -- Possible X offsets for each column (left, center, right).  These
    -- correspond to positions -7, 0 and 7 studs relative to the starting
    -- CFrame.
    local cols = { -7, 0, 7 }
    -- Choose an initial column randomly so that the maze isn't always the same.
    local colIndex = math.random(1, #cols)
    local cf = startCF
    for r=1, rows do
        -- Compute Z offset for this row
        local zOff = - (r * 7)
        -- Determine which column is safe for this row.  Allow the safe
        -- column to shift left/right by at most one index to avoid abrupt
        -- jumps across multiple columns.  At each step we pick either the
        -- same index or an adjacent one.
        local possible = { colIndex }
        if colIndex > 1 then table.insert(possible, colIndex - 1) end
        if colIndex < #cols then table.insert(possible, colIndex + 1) end
        colIndex = possible[ math.random(1, #possible) ]
        -- Create platforms for each column
        for i=1, #cols do
            local xOff = cols[i]
            local pos = cf * CFrame.new(xOff, 0, zOff)
            if i == colIndex then
                -- Safe platform
                local plate = part({
                    CFrame = pos,
                    Size = Vector3.new(6,1,6),
                    Color = Color3.fromRGB(230,230,230),
                    Name = "MazeSafe_" .. r .. "_" .. i,
                }, root)
                table.insert(out, plate)
            else
                -- Hazard platform: either leave a gap (no part) or use a
                -- hazard tile.  We'll spawn a red hazard tile that kills on
                -- touch so players are punished immediately.
                local hazard = part({
                    CFrame = pos,
                    Size = Vector3.new(6,1,6),
                    Color = Color3.fromRGB(200,80,80),
                    Name = "MazeHazard_" .. r .. "_" .. i,
                }, root)
                attachKillTouch(hazard)
                table.insert(out, hazard)
            end
        end
    end
    -- Return the CFrame of the last safe platform so subsequent sections
    -- can begin from there.  Compute the world CFrame for the final safe
    -- column in the last row.
    local finalZ = - (rows * 7)
    local finalX = cols[colIndex]
    return cf * CFrame.new(finalX, 0, finalZ)
end

---------------------------------------------------------------------
-- Course construction
---------------------------------------------------------------------

-- Remove all existing course parts from the arena folder.
function ObbyLibrary.ClearArena(arenaFolder: Folder)
    for _, obj in ipairs(arenaFolder:GetChildren()) do
        obj:Destroy()
    end
end

-- Build a course of a given type.  Returns a BuildResult containing the
-- start location, the finish part and a list of all parts spawned.
function ObbyLibrary.BuildByType(arenaFolder: Folder, centerCF: CFrame, courseType: string): ObbyLibrary.BuildResult
    local all: {BasePart} = {}
    local root = Instance.new("Folder")
    root.Name = "Course"
    root.Parent = arenaFolder
    -- Starting frame is offset forward from the center so players face -Z
    local startCF = centerCF * CFrame.new(0,2,22)
    local lastCF = startCF
    if courseType == "GapRun" then
        local last = genGapJumps(root, startCF, 14, 3, all)
        lastCF = ((last and last.CFrame) or startCF) * CFrame.new(0,0,-6)
        lastCF = genShrinkPlates(root, lastCF, 4, all)
    elseif courseType == "Sweeper" then
        genSweeper(root, centerCF, 18, 2, 3, all)
        local after = centerCF * CFrame.new(0,2,-10)
        local last = genGapJumps(root, after, 8, 4, all)
        lastCF = (last and last.CFrame) or after
    elseif courseType == "Planks" then
        lastCF = genMovingPlanks(root, startCF, 8, 12, all)
        local after = lastCF * CFrame.new(0,0,-6)
        genPopupPillars(root, after, 6, 8, all)
        lastCF = after * CFrame.new(0,0,-6*6)
    elseif courseType == "Mix" then
        local last = genGapJumps(root, startCF, 8, 3, all)
        local mid = ((last and last.CFrame) or startCF) * CFrame.new(0,0,-8)
        genSweeper(root, centerCF * CFrame.new(0,0,-8),16,3,2, all)
        lastCF = genMovingPlanks(root, mid, 5, 10, all)
    elseif courseType == "Conveyor" then
        lastCF = genConveyorField(root, startCF, 3, 8, 12, all)
        local after = lastCF * CFrame.new(0,0,-8)
        local last = genGapJumps(root, after, 6, 4, all)
        lastCF = (last and last.CFrame) or after
    elseif courseType == "Hammer" then
        genSwingHammers(root, centerCF, 4, 14, all)
        local after = centerCF * CFrame.new(0,2,-14)
        local last = genGapJumps(root, after, 10, 3, all)
        lastCF = (last and last.CFrame) or after
    elseif courseType == "Wind" then
        lastCF = genWindTunnel(root, startCF, 3, 8, 16, all)
        local after = lastCF * CFrame.new(0,0,-6)
        local last = genGapJumps(root, after, 6, 3, all)
        lastCF = (last and last.CFrame) or after
    elseif courseType == "Spin" then
        lastCF = genSpinnerBlades(root, startCF, 6, all)
        local after = lastCF * CFrame.new(0,0,-6)
        lastCF = genShrinkPlates(root, after, 4, all)
    elseif courseType == "Chaos" then
        lastCF = genWindTunnel(root, startCF, 3, 6, 14, all)
        genSwingHammers(root, centerCF * CFrame.new(0,0,-8), 3, 12, all)
        local after = startCF * CFrame.new(0,0,-18)
        lastCF = genSpinnerBlades(root, after, 4, all)
        local after2 = lastCF * CFrame.new(0,0,-6)
        lastCF = genMovingPlanks(root, after2, 4, 12, all)
    elseif courseType == "Cannon" then
        -- Cannon run: straight path with side cannons firing projectiles.
        lastCF = genCannonRun(root, startCF, 12, all)
        -- End with a short gap jump section for variety
        local after = lastCF * CFrame.new(0,0,-8)
        local last = genGapJumps(root, after, 6, 3, all)
        lastCF = (last and last.CFrame) or after
    elseif courseType == "Push" then
         -- Push walls: sliding walls across a narrow path
         lastCF = genPushWalls(root, startCF, 10, all)
         local after = lastCF * CFrame.new(0,0,-6)
         local last = genShrinkPlates(root, after, 3, all)
         lastCF = (last and last.CFrame) or after
    elseif courseType == "Maze" then
        -- Maze: branching path with only one safe route.  Players must
        -- choose wisely or fall into hazards.  Ends with a small gap run.
        lastCF = genMazeRun(root, startCF, 8, all)
        local after = lastCF * CFrame.new(0,0,-8)
        local last = genGapJumps(root, after, 4, 3, all)
        lastCF = (last and last.CFrame) or after
    else
        -- Default fallback: simple gap run
        local last = genGapJumps(root, startCF, 10, 3, all)
        lastCF = ((last and last.CFrame) or startCF) * CFrame.new(0,0,-6)
        lastCF = genShrinkPlates(root, lastCF, 3, all)
    end
    -- Create finish pad
    local finish = mkFinish(root, lastCF * CFrame.new(0,0,-10))
    table.insert(all, finish)
    -- Attach kill touch to all hazards
    for _,p in ipairs(all) do
        if p:IsA("BasePart") and (p.Name == "Hazard" or p.Name == "Lava") then
            attachKillTouch(p)
        end
    end
    return {
        StartCF = startCF,
        FinishPart = finish,
        AllParts = all,
    }
end

-- Build a random course chosen from Config.CourseTypes.
function ObbyLibrary.BuildRandom(arenaFolder: Folder, centerCF: CFrame): ObbyLibrary.BuildResult
    -- Load Config lazily to avoid circular dependency
    local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
    local choice = Config.CourseTypes[math.random(1, #Config.CourseTypes)]
    return ObbyLibrary.BuildByType(arenaFolder, centerCF, choice)
end

return ObbyLibrary