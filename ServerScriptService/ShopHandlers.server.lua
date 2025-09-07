--!strict
-- ShopHandlers: processes client requests for purchasing and equipping trails.
-- Requires EconomyService and InventoryService for persistence and coins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Util   = require(Modules:WaitForChild("Util"))

local Economy   = require(script.Parent:WaitForChild("EconomyService"))
local Inventory = require(script.Parent:WaitForChild("InventoryService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShopPurchase = Remotes:WaitForChild("ShopPurchase") :: RemoteEvent
local EquipTrail   = Remotes:WaitForChild("EquipTrail") :: RemoteEvent
local InventoryQuery = Remotes:WaitForChild("InventoryQuery") :: RemoteFunction
local ScoreUpdate = Remotes:WaitForChild("ScoreUpdate") :: RemoteEvent

-- Find a shop item by its id
local function findShopItem(itemId: string)
    for _, item in ipairs(Config.Shop) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

-- Handle purchase requests from clients
ShopPurchase.OnServerEvent:Connect(function(plr: Player, itemId: string)
    local item = findShopItem(itemId)
    if not item then return end
    -- Already owned?  Do nothing.
    if Inventory.HasItem(plr.UserId, itemId) then
        return
    end
    -- Attempt to spend coins
    if Economy.TrySpend(plr.UserId, item.cost) then
        -- Add item to inventory
        Inventory.AddItem(plr.UserId, itemId)
        -- Update coins in leaderstats
        local ls = plr:FindFirstChild("leaderstats")
        if ls then
            local c = ls:FindFirstChild("Coins")
            if c then c.Value = Economy.Get(plr.UserId) end
        end
        -- Notify client of new balance
        ScoreUpdate:FireClient(plr, Economy.Get(plr.UserId))
    else
        -- Insufficient funds; could send feedback but no action
    end
end)

-- Handle equip requests from clients
EquipTrail.OnServerEvent:Connect(function(plr: Player, itemId: string)
    -- Only allow equipping items the player owns
    if not Inventory.HasItem(plr.UserId, itemId) then
        return
    end
    -- Remove any existing trail attachments
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- Remove old trails on both attachments if present
    for _, att in ipairs(hrp:GetChildren()) do
        if att:IsA("Attachment") then
            for _, existing in ipairs(att:GetChildren()) do
                if existing:IsA("Trail") then existing:Destroy() end
            end
        end
    end
    -- Create or get attachments on HRP
    local attach0 = hrp:FindFirstChild("TrailAttachment0")
    if not attach0 then
        attach0 = Instance.new("Attachment")
        attach0.Name = "TrailAttachment0"
        attach0.Position = Vector3.new(0,1,0)
        attach0.Parent = hrp
    end
    local attach1 = hrp:FindFirstChild("TrailAttachment1")
    if not attach1 then
        attach1 = Instance.new("Attachment")
        attach1.Name = "TrailAttachment1"
        attach1.Position = Vector3.new(0,-1,0)
        attach1.Parent = hrp
    end
    -- Find color from shop list
    local item = findShopItem(itemId)
    if not item then return end
    local trail = Util.CreateTrail(itemId, item.color)
    trail.Attachment0 = attach0
    trail.Attachment1 = attach1
    trail.Parent = hrp
end)

-- Provide inventory list to client upon request
function InventoryQuery.OnServerInvoke(plr: Player)
    return Inventory.GetInventory(plr.UserId)
end

return {}