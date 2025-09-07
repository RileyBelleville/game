--!strict
-- InventoryService: persists purchased cosmetic items (trails) for players.
-- Trails are identified by string ids (matching entries in Config.Shop).  This
-- module uses DataStore to save and load inventories and provides helper
-- functions for adding items and checking ownership.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local invStore = DataStoreService:GetDataStore("ObbyUniverse_Inventory")

local InventoryService = {}

-- In‑memory cache of inventories.  Each entry is a table of item ids.
local inventories: {[number]: {string}} = {}

-- Internal: load inventory for userId if not cached
local function loadInventory(userId: number): {string}
    if inventories[userId] then return inventories[userId] end
    local ok, data = pcall(function()
        return invStore:GetAsync(tostring(userId))
    end)
    if ok and type(data) == "table" then
        inventories[userId] = data
    else
        inventories[userId] = {}
    end
    return inventories[userId]
end

-- Internal: save inventory back to DataStore
local function saveInventory(userId: number)
    local inv = inventories[userId]
    if not inv then return end
    task.spawn(function()
        pcall(function()
            invStore:SetAsync(tostring(userId), inv)
        end)
    end)
end

-- Get a player's inventory (list of item ids).  Returns a copy to avoid
-- external mutation.
function InventoryService.GetInventory(userId: number): {string}
    local inv = loadInventory(userId)
    return table.clone(inv)
end

-- Add an item id to a player's inventory if they don't already own it.
function InventoryService.AddItem(userId: number, itemId: string)
    local inv = loadInventory(userId)
    for _, id in ipairs(inv) do
        if id == itemId then return end
    end
    table.insert(inv, itemId)
    saveInventory(userId)
end

-- Check whether a user owns an item.
function InventoryService.HasItem(userId: number, itemId: string): boolean
    local inv = loadInventory(userId)
    for _, id in ipairs(inv) do
        if id == itemId then return true end
    end
    return false
end

return InventoryService