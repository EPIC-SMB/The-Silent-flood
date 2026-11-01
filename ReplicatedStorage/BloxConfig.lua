-- Silent Flood — BloxConfig (ModuleScript, ReplicatedStorage)
-- All prices, loot tables, rewards, map layout, combat numbers, maturity answers.
-- Data-driven so balance changes never touch a script.

local Config = {}

-- ============================================================
-- Maturity / compliance answers (mirror the Creator Dashboard questionnaire)
-- ============================================================
Config.Maturity = {
    Violence = "Mild",          -- monster chases; no gore, no realistic blood
    Blood = "None",
    Fear = "Moderate",          -- horror atmosphere, jumpscares via audio
    CrudeHumor = "None",
    Gambling = "Unplayable",     -- paid random items disclosed, not gambling
    AlcoholDrugs = "None",
    Romantic = "None",
    Language = "None",
}

-- ============================================================
-- Game constants
-- ============================================================
Config.GAME_NAME = "Silent Flood"
Config.MAX_PLAYERS_PER_SERVER = 10
Config.ROUND_TIME = 300
Config.INTERMISSION = 10
Config.MAX_FLOOR = 8
Config.RESPAWN_DELAY = 5

-- ============================================================
-- Passes (one-time, permanent privileges)
-- ============================================================
Config.PASSES = {
    VIP = { Id = 0, Price = 99, Name = "VIP Pass", Grants = { CoinBoost = 1.5, Trail = "VIPTrail", RespawnShield = true, ChatTag = "VIP" } },
    AutoSprint = { Id = 0, Price = 49, Name = "Auto-Sprint Pass", Grants = { SprintMult = 1.25 } },
    ExtraPebbleSlot = { Id = 0, Price = 29, Name = "Extra Pebble Slot", Grants = { PebbleCap = 4 } },
}

-- ============================================================
-- Developer Products (repeatable)
-- ============================================================
Config.PRODUCTS = {
    Coins250 = { Id = 0, Price = 25, Grant = { Coins = 250 } },
    Coins800 = { Id = 0, Price = 75, Grant = { Coins = 800 } },
    Coins2000 = { Id = 0, Price = 150, Grant = { Coins = 2000 } },
    Coins5000 = { Id = 0, Price = 300, Grant = { Coins = 5000 } },
    ReviveToken = { Id = 0, Price = 15, Grant = { Revive = 1 } },
    SpeedBoost5 = { Id = 0, Price = 20, Grant = { SpeedBoost = 300 } },
    LuckyPebble = { Id = 0, Price = 30, Grant = { LuckyRoll = 1 } },
    NeonTrail = { Id = 0, Price = 50, Grant = { Cosmetic = "NeonTrail" } },
    GoldenPebble = { Id = 0, Price = 40, Grant = { Cosmetic = "GoldenPebble" } },
}

-- ============================================================
-- Paid random item loot table (Lucky Pebble) — odds disclosed, sum 100
-- ============================================================
Config.LOOT_TABLES = {
    LuckyPebble = {
        { Outcome = "Common Pebble x3", Weight = 50, DisplayPct = 50 },
        { Outcome = "Rare Pebble x1", Weight = 30, DisplayPct = 30 },
        { Outcome = "Epic Pebble x1", Weight = 15, DisplayPct = 15 },
        { Outcome = "Legendary Pebble x1", Weight = 5, DisplayPct = 5 },
    },
}

-- ============================================================
-- Gear (every entry declares exactly one Source)
-- ============================================================
Config.Gear = {
    -- Free via rep tiers (real gameplay effects)
    RepSpeedBoost = { Source = "rep", Tier = 1, Name = "Rep Speed +5%", Effect = { WalkSpeed = 5 } },
    RepPickupRadius = { Source = "rep", Tier = 2, Name = "Pickup Radius +2", Effect = { PickupRadius = 2 } },
    RepThrowRange = { Source = "rep", Tier = 3, Name = "Throw Range +5", Effect = { ThrowRange = 5 } },
    -- Free via coins (spendable sink)
    ThrowRange1 = { Source = "coils", Price = 50, Name = "Throwing Range I", Effect = { ThrowRange = 3 } },
    ThrowRange2 = { Source = "coils", Price = 150, Name = "Throwing Range II", Effect = { ThrowRange = 5 } },
    PebbleCap8 = { Source = "coils", Price = 75, Name = "Pebble Pouch (8)", Effect = { PebbleCap = 8 } },
    PebbleCap12 = { Source = "coils", Price = 200, Name = "Pebble Satchel (12)", Effect = { PebbleCap = 12 } },
    RescueSpeed = { Source = "coils", Price = 100, Name = "Rescue Speed", Effect = { RescueSpeed = 1.5 } },
    ValveSpeed = { Source = "coils", Price = 120, Name = "Valve Speed", Effect = { ValveSpeed = 1.5 } },
    -- Robux only (cosmetics / convenience)
    VIPTrail = { Source = "robux", Name = "VIP Trail", Cosmetic = true },
    NeonTrail = { Source = "robux", Name = "Neon Trail", Cosmetic = true },
    GoldenPebble = { Source = "robux", Name = "Golden Pebble", Cosmetic = true },
}

Config.FreeGearRep = {
    [1] = "RepSpeedBoost",
    [2] = "RepPickupRadius",
    [3] = "RepThrowRange",
}

Config.RobuxOnlyGear = { "VIPTrail", "NeonTrail", "GoldenPebble" }

-- ============================================================
-- Coin shop (free currency sink)
-- ============================================================
Config.UPGRADES = {
    { Id = "ThrowRange1", Price = 50, Name = "Throwing Range I" },
    { Id = "ThrowRange2", Price = 150, Name = "Throwing Range II" },
    { Id = "PebbleCap8", Price = 75, Name = "Pebble Pouch (8)" },
    { Id = "PebbleCap12", Price = 200, Name = "Pebble Satchel (12)" },
    { Id = "RescueSpeed", Price = 100, Name = "Rescue Speed" },
    { Id = "ValveSpeed", Price = 120, Name = "Valve Speed" },
}

-- ============================================================
-- Rep tiers
-- ============================================================
Config.REP_TIERS = {
    { Tier = 1, Rep = 0, Name = "Newcomer" },
    { Tier = 2, Rep = 100, Name = "Survivor" },
    { Tier = 3, Rep = 300, Name = "Veteran" },
    { Tier = 4, Rep = 700, Name = "Expert" },
    { Tier = 5, Rep = 1500, Name = "Master" },
}

-- ============================================================
-- Daily login rewards (escalating over 7 days)
-- ============================================================
Config.DAILY_REWARDS = {
    { Day = 1, Coins = 10, Item = nil },
    { Day = 2, Coins = 20, Item = nil },
    { Day = 3, Coins = 30, Item = "Pebble x2" },
    { Day = 4, Coins = 50, Item = nil },
    { Day = 5, Coins = 75, Item = "Pebble x3" },
    { Day = 6, Coins = 100, Item = nil },
    { Day = 7, Coins = 200, Item = "Rare Pebble" },
}
Config.STREAK_RESET_HOURS = 36
Config.STREAK_CAP = 3

Config.STREAK_MILESTONES = { 7, 14, 30, 60, 100 }

-- ============================================================
-- Rooms (data-driven layout)
-- ============================================================
Config.ROOMS = {
    { Index = 1, Name = "Entry Hall", Platforms = 8, Hazards = "basic" },
    { Index = 2, Name = "Sinking Floor", Platforms = 10, Hazards = "sinking" },
    { Index = 3, Name = "Rotating Bridge", Platforms = 6, Hazards = "rotating" },
    { Index = 4, Name = "Crushing Walls", Platforms = 12, Hazards = "crushing" },
    { Index = 5, Name = "Memory Bridge", Platforms = 9, Hazards = "memory" },
    { Index = 6, Name = "Drifting Platforms", Platforms = 11, Hazards = "drifting" },
    { Index = 7, Name = "Dark Passage", Platforms = 13, Hazards = "dark" },
    { Index = 8, Name = "Maintenance Lock", Platforms = 5, Hazards = "valves" },
}

-- ============================================================
-- Entity (the sound-hunting monster)
-- ============================================================
Config.ENTITY = {
    Name = "The Listener",
    WalkSpeed = 8,
    HearingRadius = 30,
    Damage = 25,
    DamageRange = 5,
}

-- ============================================================
-- Validation (run from harness / assert at load)
-- ============================================================
function Config.validateGearSources()
    for name, entry in pairs(Config.Gear) do
        assert(entry.Source, "Gear entry without Source: " .. name)
    end
    for _, name in ipairs(Config.RobuxOnlyGear) do
        assert(Config.Gear[name] and Config.Gear[name].Source == "robux", "RobuxOnlyGear not robux source: " .. name)
    end
    for tier, name in pairs(Config.FreeGearRep) do
        assert(Config.Gear[name] and Config.Gear[name].Source == "rep", "FreeGearRep not rep source: " .. name)
        assert(Config.Gear[name].Tier == tier, "FreeGearRep tier mismatch: " .. name)
    end
end

function Config.validateLootTables()
    for name, tbl in pairs(Config.LOOT_TABLES) do
        local w, p = 0, 0
        for _, e in ipairs(tbl) do
            w = w + (e.Weight or 0)
            p = p + (e.DisplayPct or 0)
        end
        assert(w == 100, name .. " weights sum to " .. w)
        assert(p == 100, name .. " display pct sums to " .. p)
    end
end

function Config.validateMonetization()
    for k, v in pairs(Config.PASSES) do
        assert(v.Price, "Pass without price: " .. k)
        assert(v.Id ~= nil, "Pass without Id: " .. k)
    end
    for k, v in pairs(Config.PRODUCTS) do
        assert(v.Price, "Product without price: " .. k)
        assert(v.Id ~= nil, "Product without Id: " .. k)
    end
end

return Config
