--!strict
-- Configuration module for Obby Universe Ultimate.
-- Tune these constants to adjust gameplay timing, difficulty, rewards and shop.

local Config = {}

-- Round timings (seconds)
Config.LOBBY_TIME   = 12    -- time in lobby before voting starts
Config.VOTING_TIME  = 8     -- time allocated for voting on the next course
Config.ROUND_TIME   = 120   -- duration of each obby run
Config.CLEANUP_TIME = 5     -- time between rounds to clear arena and show podium

-- Rewards
Config.COINS_FINISH       = 25   -- coins awarded for finishing a course
Config.COINS_PODIUM_BONUS = 15   -- additional coins for the first finisher
Config.DAILY_BONUS        = 50   -- coins awarded once per day per player

-- Course types offered in the voting phase.  Each entry must correspond to a
-- builder in ObbyLibrary.BuildByType.  Feel free to add or remove entries.
Config.CourseTypes = {
    "GapRun",
    "Sweeper",
    "Planks",
    "Mix",
    "Conveyor",
    "Hammer",
    "Wind",
    "Spin",
    "Chaos",
    -- New course type: players run down a narrow pathway while dodging
    -- giant cannon balls that are fired from the sides.  See
    -- ObbyLibrary.genCannonRun for implementation.
    "Cannon",

    -- Players traverse a straight path while massive walls periodically
    -- slide across to shove them off.  Implemented by
    -- ObbyLibrary.genPushWalls.
    "Push",

    -- Maze course: players navigate a simple maze of branching paths.
    -- At each row there is only one safe platform; picking the wrong
    -- path drops you into a hazard below.  See ObbyLibrary.genMazeRun
    -- for details.
    "Maze",
}

-- Shop items available for purchase.  Players can buy trails with coins.
Config.Shop = {
    { id = "trail_white", name = "White Trail", cost = 50,  color = Color3.fromRGB(255,255,255) },
    { id = "trail_blue",  name = "Blue Trail",  cost = 75,  color = Color3.fromRGB(100,160,255) },
    { id = "trail_gold",  name = "Gold Trail",  cost = 150, color = Color3.fromRGB(255,210,60) },
    { id = "trail_pink",  name = "Pink Trail",  cost = 120, color = Color3.fromRGB(255,130,190) },
    { id = "trail_green", name = "Green Trail", cost = 85,  color = Color3.fromRGB(120,255,120) },
}

-- Titles based on total wins.  The highest threshold satisfied determines the title.
Config.Titles = {
    { threshold = 50, name = "Legend" },
    { threshold = 20, name = "Pro"    },
    { threshold = 5,  name = "Runner" },
    { threshold = 0,  name = "Rookie" },
}

return Config