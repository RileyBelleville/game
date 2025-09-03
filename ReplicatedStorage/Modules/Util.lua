--!strict
-- Miscellaneous helper functions used throughout Obby Universe Ultimate.

local Util = {}

-- Tween helper that automatically plays the tween.  Returns the tween object.
function Util.SafeTween(inst: Instance, ti: TweenInfo, props: {[string]: any})
    local TweenService = game:GetService("TweenService")
    local tw = TweenService:Create(inst, ti, props)
    tw:Play()
    return tw
end

-- Count the number of entries in a table (non‑array safe).
function Util.TableCount(t: {[any]: any}): number
    local n = 0
    for _ in pairs(t) do
        n += 1
    end
    return n
end

-- Choose a random element from a list.  Assumes list is non‑empty.
function Util.ChooseRandom<T>(list: {T}): T
    return list[math.random(1, #list)]
end

-- Create a colorized trail given an id and color.  Used by the shop.
function Util.CreateTrail(id: string, color: Color3): Trail
    local trail = Instance.new("Trail")
    trail.Name = id
    trail.Color = ColorSequence.new(color)
    trail.LightEmission = 1
    trail.Lifetime = 1.5
    trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
    return trail
end

return Util