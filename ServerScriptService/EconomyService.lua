--!strict
-- EconomyService: manages player coin balances and persistence via DataStore.
-- Coins are awarded for finishing courses and can be spent in the shop.  This
-- module caches balances in memory and writes them back asynchronously.  In
-- Studio, DataStores may not save, but the API calls are wrapped in pcall to
-- avoid errors.

local DataStoreService = game:GetService("DataStoreService")

local coinsStore = DataStoreService:GetDataStore("ObbyUniverse_Coins")

-- Ordered DataStore for global coins leaderboard.  Keys are userId strings
-- and values are the maximum coin total seen for that user.  Updating
-- this store allows retrieval of the top coin holders across all servers.
local orderedCoins: OrderedDataStore = DataStoreService:GetOrderedDataStore("ObbyUniverse_GlobalCoins")

local EconomyService = {}

-- In‑memory cache of balances.  Use userId (number) as key.
local balances: {[number]: number} = {}

-- Load a player's balance from the DataStore if not cached.
local function loadBalance(userId: number): number
    if balances[userId] ~= nil then
        return balances[userId]
    end
    local ok, data = pcall(function()
        return coinsStore:GetAsync(tostring(userId))
    end)
    if ok and type(data) == "number" then
        balances[userId] = data
    else
        balances[userId] = 0
    end
    return balances[userId]
end

-- Save a player's balance back to the DataStore.  Called asynchronously.
local function saveBalance(userId: number)
    local value = balances[userId]
    if value == nil then return end
    task.spawn(function()
        pcall(function()
            coinsStore:SetAsync(tostring(userId), value)
        end)
    end)
end

-- Public API: get current coin balance.
function EconomyService.Get(userId: number): number
    return loadBalance(userId)
end

-- Award coins to a player.  Positive amounts add coins, negative amounts
-- subtract (useful for purchases).  Returns the new balance.
function EconomyService.Award(userId: number, amount: number): number
    local bal = loadBalance(userId)
    bal += amount
    if bal < 0 then bal = 0 end
    balances[userId] = bal
    saveBalance(userId)

    -- Update global coins leaderboard if this new balance exceeds the stored
    -- value for the user.  We run this update asynchronously to avoid
    -- blocking gameplay if DataStore requests are slow or fail.  The
    -- update function returns the larger of the previous value and the
    -- current balance.
    task.spawn(function()
        pcall(function()
            orderedCoins:UpdateAsync(tostring(userId), function(prev)
                local prevNum = tonumber(prev) or 0
                if bal > prevNum then
                    return bal
                else
                    return prevNum
                end
            end)
        end)
    end)
    return bal
end

-- Attempt to spend coins.  Returns true if the user had enough and the
-- deduction succeeded, false otherwise.
function EconomyService.TrySpend(userId: number, amount: number): boolean
    local bal = loadBalance(userId)
    if bal >= amount then
        bal -= amount
        balances[userId] = bal
        saveBalance(userId)
        return true
    else
        return false
    end
end

return EconomyService