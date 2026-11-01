-- Silent Flood — BloxServer (Script, ServerScriptService)
-- Server-authoritative economy, ProcessReceipt, pass grants, round loop, combat.
-- Clients send intents; server decides outcomes and pushes filtered snapshots.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BloxConfig"))

-- ============================================================
local function contains(t, v)
    for _, x in ipairs(t) do
        if x == v then return true end
    end
    return false
end
-- ============================================================
local saveProfile
local checkRepTier
local checkAchievements
local grantProduct
local grantPass
local giveCoins
local giveRep
local spawnEntity
local damagePlayer
local startRound
local endRound
local tryAutoStart

-- ============================================================
-- State
-- ============================================================
local store = DataStoreService:GetDataStore("SilentFlood_v1")
local sessions = {}          -- [player] = session table
local gameState = {
    Phase = "Lobby",          -- "Lobby" | "Playing" | "Results"
    CurrentFloor = 1,
    Players = {},             -- [userId] = { player, alive, ... }
    Entity = nil,
    HeartbeatConn = nil,
    RoundStart = 0,
    AllFloorsCleared = false,
    LastRoundAllCleared = false,
    EscapesToday = 0,
    OnlineCount = 0,
}

-- Pass / product ID maps (set to 0 until created in Creator Dashboard)
local PASS_IDS = {
    VIP = 0,
    AutoSprint = 0,
    ExtraPebbleSlot = 0,
}
local PRODUCT_IDS = {
    Coins250 = 0,
    Coins800 = 0,
    Coins2000 = 0,
    Coins5000 = 0,
    ReviveToken = 0,
    SpeedBoost5 = 0,
    LuckyPebble = 0,
    NeonTrail = 0,
    GoldenPebble = 0,
}

-- Reverse maps
local PASS_BY_ID = {}
local PRODUCT_BY_ID = {}
for k, v in pairs(Config.PASSES) do
    if v.Id and v.Id ~= 0 then PASS_BY_ID[v.Id] = k end
end
for k, v in pairs(Config.PRODUCTS) do
    if v.Id and v.Id ~= 0 then PRODUCT_BY_ID[v.Id] = k end
end

-- Rate limiting
local rateLimits = {}  -- [player] = { [action] = { times = {} } }
local function rateLimit(player, action, maxPerSec)
    maxPerSec = maxPerSec or 10
    rateLimits[player] = rateLimits[player] or {}
    rateLimits[player][action] = rateLimits[player][action] or { times = {} }
    local t = rateLimits[player][action].times
    local now = tick()
    -- prune old
    local i = 1
    while i <= #t do
        if now - t[i] > 1 then table.remove(t, i) else i = i + 1 end
    end
    if #t >= maxPerSec then return false end
    table.insert(t, now)
    return true
end

-- ============================================================
-- Remotes
-- ============================================================
local remotes = {}
local function setupRemotes()
    local function mk(name, cls)
        local r = Instance.new(cls or "RemoteEvent")
        r.Name = name
        r.Parent = ReplicatedStorage
        return r
    end
    remotes.GameStart = mk("GameStartRemote")
    remotes.GameEnd = mk("GameEndRemote")
    remotes.EntityDamage = mk("EntityDamageRemote")
    remotes.DoorOpened = mk("DoorOpenedRemote")
    remotes.CoinUpdate = mk("CoinUpdateRemote")
    remotes.RepUpdate = mk("RepUpdateRemote")
    remotes.Toast = mk("ToastRemote")
    remotes.StoreUpdate = mk("StoreUpdateRemote")
    remotes.SocialProof = mk("SocialProofRemote")
    remotes.DailyReward = mk("DailyRewardRemote")
    remotes.LootResult = mk("LootResultRemote")
    remotes.QuickChat = mk("QuickChatRemote")
    remotes.BuyUpgrade = mk("BuyUpgradeRemote", "RemoteFunction")
    remotes.ClaimDaily = mk("ClaimDailyRemote", "RemoteFunction")
    remotes.PromptPurchase = mk("PromptPurchaseRemote", "RemoteFunction")
    remotes.ThrowPebble = mk("ThrowPebbleRemote")
    remotes.OpenValve = mk("OpenValveRemote")
    remotes.ReviveRequest = mk("ReviveRequestRemote")
end

setupRemotes()

-- ============================================================
-- Profile helpers
-- ============================================================
local function defaultProfile()
    return {
        Coins = 0,
        Rep = 0,
        RepTier = 1,
        Gear = {},
        Passes = {},
        Receipts = {},
        DailyStreak = 0,
        LastLogin = 0,
        TotalEscapes = 0,
        TotalDeaths = 0,
        BestFloor = 0,
        Cosmetics = {},
        Achievements = {},
        Stats = { throws = 0, valves = 0, revives = 0 },
    }
end

local function loadProfile(player)
    local ok, data = pcall(function()
        return store:GetAsync("player_" .. player.UserId)
    end)
    if not ok or not data then data = defaultProfile() end
    -- forward-fill new fields
    local d = defaultProfile()
    for k, v in pairs(d) do
        if data[k] == nil then data[k] = v end
    end
    if type(data.Receipts) ~= "table" then data.Receipts = {} end
    if type(data.Gear) ~= "table" then data.Gear = {} end
    if type(data.Passes) ~= "table" then data.Passes = {} end
    if type(data.Cosmetics) ~= "table" then data.Cosmetics = {} end
    if type(data.Achievements) ~= "table" then data.Achievements = {} end
    if type(data.Stats) ~= "table" then data.Stats = {} end
    local s = defaultProfile()
    for k, v in pairs(s) do
        if data.Stats[k] == nil then data.Stats[k] = v end
    end
    data.Stats = data.Stats
    return data
end

saveProfile = function(player)
    local s = sessions[player]
    if not s then return end
    pcall(function()
        store:SetAsync("player_" .. player.UserId, s.Profile)
    end)
end

-- ============================================================
-- Pass / product grant logic
-- ============================================================
local function hasPass(player, passKey)
    local s = sessions[player]
    if not s then return false end
    if s.Profile.Passes[passKey] then return true end
    -- also check MarketplaceService for already-owned (pass may have been bought outside)
    local passId = Config.PASSES[passKey] and Config.PASSES[passKey].Id or 0
    if passId ~= 0 then
        local ok, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
        end)
        if ok and owns then
            s.Profile.Passes[passKey] = true
            return true
        end
    end
    return false
end

grantPass = function(player, passKey)
    local s = sessions[player]
    if not s then return false end
    -- PolicyService: pass grants don't need random-item check, but check eligibility
    local cfg = Config.PASSES[passKey]
    if not cfg then return false end
    s.Profile.Passes[passKey] = true
    -- apply grants
    if cfg.Grants.CoinBoost then
        s.CoinBoost = cfg.Grants.CoinBoost
    end
    if cfg.Grants.Trail then
        table.insert(s.Profile.Cosmetics, cfg.Grants.Trail)
    end
    if cfg.Grants.RespawnShield then
        s.RespawnShield = true
    end
    if cfg.Grants.SprintMult then
        s.SprintMult = (s.SprintMult or 1) * cfg.Grants.SprintMult
    end
    if cfg.Grants.PebbleCap then
        s.PebbleCapBonus = (s.PebbleCapBonus or 0) + cfg.Grants.PebbleCap
    end
    saveProfile(player)
    remotes.Toast:FireClient(player, "Pass granted: " .. passKey)
    return true
end

grantProduct = function(player, productKey)
    local s = sessions[player]
    if not s then return false end
    local cfg = Config.PRODUCTS[productKey]
    if not cfg then return false end
    local g = cfg.Grant or {}
    -- PolicyService check for paid random items
    if productKey == "LuckyPebble" then
        local paidRandomAllowed = player:GetAttribute("PaidRandomAllowed")
        if paidRandomAllowed == false then
            remotes.Toast:FireClient(player, "Paid random items not available for your account.")
            return false
        end
    end
    if g.Coins then
        local mult = s.CoinBoost or 1
        if hasPass(player, "VIP") then mult = mult * 1.5 end
        -- VIP boost already in CoinBoost? apply once
        giveCoins(player, math.floor(g.Coins * mult))
    end
    if g.Revive then
        s.ReviveTokens = (s.ReviveTokens or 0) + g.Revive
    end
    if g.SpeedBoost then
        s.SpeedBoostExpiry = tick() + g.SpeedBoost
    end
    if g.LuckyRoll then
        -- paid random item: roll with disclosed odds
        local tbl = Config.LOOT_TABLES.LuckyPebble
        local roll = math.random(1, 100)
        local acc = 0
        local outcome = tbl[1].Outcome
        for _, e in ipairs(tbl) do
            acc = acc + e.Weight
            if roll <= acc then outcome = e.Outcome break end
        end
        -- grant outcome
        if string.find(outcome, "Pebble") then
            s.Pebbles = (s.Pebbles or 0) + 1
        end
        remotes.LootResult:FireClient(player, outcome)
    end
    if g.Cosmetic then
        if not contains(s.Profile.Cosmetics, g.Cosmetic) then
            table.insert(s.Profile.Cosmetics, g.Cosmetic)
        end
    end
    saveProfile(player)
    return true
end

-- ============================================================
-- Economy helpers
-- ============================================================
giveCoins = function(player, amount)
    local s = sessions[player]
    if not s then return end
    s.Profile.Coins = (s.Profile.Coins or 0) + amount
    remotes.CoinUpdate:FireClient(player, s.Profile.Coins)
end

giveRep = function(player, amount)
    local s = sessions[player]
    if not s then return end
    s.Profile.Rep = (s.Profile.Rep or 0) + amount
    checkRepTier(player)
    remotes.RepUpdate:FireClient(player, s.Profile.Rep, s.Profile.RepTier)
end

checkRepTier = function(player)
    local s = sessions[player]
    if not s then return end
    local newTier = 1
    for _, rt in ipairs(Config.REP_TIERS) do
        if s.Profile.Rep >= rt.Rep then newTier = rt.Tier end
    end
    if newTier > (s.Profile.RepTier or 1) then
        s.Profile.RepTier = newTier
        -- grant free gear for new tiers
        for t = (s.Profile.RepTier or 1), newTier do
            local gearName = Config.FreeGearRep[t]
            if gearName and not s.Profile.Gear[gearName] then
                s.Profile.Gear[gearName] = true
                remotes.Toast:FireClient(player, "Unlocked: " .. Config.Gear[gearName].Name)
            end
        end
        checkAchievements(player)
    end
end

checkAchievements = function(player)
    local s = sessions[player]
    if not s then return end
    -- milestone achievements
    if s.Profile.TotalEscapes >= 1 and not s.Profile.Achievements["FirstEscape"] then
        s.Profile.Achievements["FirstEscape"] = true
        giveRep(player, 10)
        remotes.Toast:FireClient(player, "Achievement: First Escape! (+10 Rep)")
    end
    if s.Profile.TotalEscapes >= 10 and not s.Profile.Achievements["TenEscapes"] then
        s.Profile.Achievements["TenEscapes"] = true
        giveRep(player, 50)
        remotes.Toast:FireClient(player, "Achievement: 10 Escapes! (+50 Rep)")
    end
end

-- ============================================================
-- ProcessReceipt
-- ============================================================
local function processReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
    local s = sessions[player]
    if not s then return Enum.ProductPurchaseDecision.NotProcessedYet end

    -- map ProductId -> config key
    local key = nil
    for k, id in pairs(PRODUCT_IDS) do
        if id ~= 0 and id == receiptInfo.ProductId then key = k break end
    end
    if not key then return Enum.ProductPurchaseDecision.NotProcessedYet end

    -- idempotency
    local receiptId = receiptInfo.PurchaseId
    if s.Profile.Receipts[receiptId] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- status: 1 = Open -> grant; others acknowledged, grant nothing
    local status = receiptInfo.ProductPurchaseDecision
    if status == nil then status = 1 end
    if status ~= 1 then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    if grantProduct(player, key) then
        s.Profile.Receipts[receiptId] = true
        saveProfile(player)
        remotes.Toast:FireClient(player, "product:" .. key)
    end
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

-- Pass purchase finished
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, purchasedPassId, purchaseSuccess)
    if not purchaseSuccess then return end
    for key, cfg in pairs(Config.PASSES) do
        if cfg.Id ~= 0 and cfg.Id == purchasedPassId then
            grantPass(player, key)
            return
        end
    end
end)

-- ============================================================
-- Player join / leave
-- ============================================================
local function onPlayerAdded(player)
    local profile = loadProfile(player)
    local s = {
        Player = player,
        Profile = profile,
        Coins = profile.Coins,
        Pebbles = 5,
        PebbleCap = 5,
        Alive = true,
        CurrentRoom = 0,
        SpeedBoostExpiry = 0,
        ReviveTokens = 0,
        CoinBoost = 1,
        SprintMult = 1,
        RespawnShield = false,
        PebbleCapBonus = 0,
        DamageTaken = 0,
    }
    sessions[player] = s

    -- PolicyService attributes
    pcall(function()
        local policy = PolicyService:GetPolicyInfoForPlayerAsync(player)
        player:SetAttribute("PaidRandomAllowed", not (policy.ArePaidRandomItemsRestricted == true))
        player:SetAttribute("PaidTradingAllowed", policy.IsPaidItemTradingAllowed == true)
    end)

    -- pass ownership check
    for key, cfg in pairs(Config.PASSES) do
        if cfg.Id ~= 0 then
            local ok, owns = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, cfg.Id)
            end)
            if ok and owns then
                s.Profile.Passes[key] = true
                -- apply grants
                if cfg.Grants.CoinBoost then s.CoinBoost = cfg.Grants.CoinBoost end
                if cfg.Grants.SprintMult then s.SprintMult = (s.SprintMult or 1) * cfg.Grants.SprintMult end
                if cfg.Grants.PebbleCap then s.PebbleCapBonus = (s.PebbleCapBonus or 0) + cfg.Grants.PebbleCap end
                if cfg.Grants.RespawnShield then s.RespawnShield = true end
                if cfg.Grants.Trail then
                    if not contains(s.Profile.Cosmetics, cfg.Grants.Trail) then
                        table.insert(s.Profile.Cosmetics, cfg.Grants.Trail)
                    end
                end
            end
        end
    end

    -- rep tier check on join (grant free gear for old saves)
    checkRepTier(player)

    -- daily reward check
    local now = os.time()
    local lastLogin = s.Profile.LastLogin or 0
    local hoursSince = (now - lastLogin) / 3600
    if hoursSince >= 24 then
        -- streak
        if hoursSince <= Config.STREAK_RESET_HOURS then
            s.Profile.DailyStreak = (s.Profile.DailyStreak or 0) + 1
        else
            s.Profile.DailyStreak = 1
        end
        if s.Profile.DailyStreak > 100 then s.Profile.DailyStreak = 100 end
        s.Profile.LastLogin = now
        -- milestone check
        for _, m in ipairs(Config.STREAK_MILESTONES) do
            if s.Profile.DailyStreak == m then
                giveRep(player, m)
                remotes.Toast:FireClient(player, "Streak milestone: " .. m .. " days! (+" .. m .. " Rep)")
            end
        end
        -- daily reward
        local dayIndex = ((s.Profile.DailyStreak - 1) % 7) + 1
        local reward = Config.DAILY_REWARDS[dayIndex]
        if reward then
            giveCoins(player, reward.Coins)
            remotes.DailyReward:FireClient(player, dayIndex, reward)
        end
        saveProfile(player)
    end

    -- social proof counter
    gameState.OnlineCount = gameState.OnlineCount + 1
    remotes.SocialProof:FireAllClients(gameState.EscapesToday, gameState.OnlineCount)

    -- try auto start
    tryAutoStart()
end

local function onPlayerRemoving(player)
    saveProfile(player)
    sessions[player] = nil
    rateLimits[player] = nil
    gameState.OnlineCount = math.max(0, gameState.OnlineCount - 1)
    remotes.SocialProof:FireAllClients(gameState.EscapesToday, gameState.OnlineCount)
    -- remove from round players
    gameState.Players[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- ============================================================
-- Round loop
-- ============================================================
spawnEntity = function()
    -- create entity part (server-side, anchored false, CanCollide true)
    local part = Instance.new("Part")
    part.Name = "Entity"
    part.Size = Vector3.new(4, 6, 4)
    part.Position = Vector3.new(0, 3, -50)
    part.Anchored = false
    part.CanCollide = true
    part.BrickColor = BrickColor.new("Really black")
    part.Parent = workspace
    gameState.Entity = part
    return part
end

damagePlayer = function(player, amount)
    local s = sessions[player]
    if not s or not s.Alive then return end
    -- respawn shield
    if s.RespawnShield and s.DamageTaken == 0 then
        s.RespawnShield = false
        remotes.Toast:FireClient(player, "Respawn shield absorbed the hit!")
        return
    end
    s.DamageTaken = s.DamageTaken + amount
    remotes.EntityDamage:FireClient(player, s.DamageTaken, 100)
    if s.DamageTaken >= 100 then
        s.Alive = false
        -- death
        s.Profile.TotalDeaths = (s.Profile.TotalDeaths or 0) + 1
        remotes.Toast:FireClient(player, "You were caught! (+" .. (s.Profile.TotalDeaths) .. " deaths)")
        -- check all dead
        local allDead = true
        for _, ps in pairs(gameState.Players) do
            if ps.alive then allDead = false break end
        end
        if allDead then
            endRound("Death")
        end
    end
end

-- Entity AI module (callback-based damage)
local EntityAI = {}
EntityAI.DamageCallback = damagePlayer

local function entityStep(dt)
    local ent = gameState.Entity
    if not ent or gameState.Phase ~= "Playing" then return end
    -- find nearest alive player
    local target = nil
    local bestDist = math.huge
    for userId, ps in pairs(gameState.Players) do
        if ps.alive and ps.player and ps.player.Character then
            local hrp = ps.player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - ent.Position).Magnitude
                if d < bestDist then bestDist = d target = ps end
            end
        end
    end
    if not target then return end
    -- move toward target if within hearing
    local hrp = target.player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local dir = (hrp.Position - ent.Position)
        local dist = dir.Magnitude
        if dist > 0 and dist < Config.ENTITY.HearingRadius then
            local step = Config.ENTITY.WalkSpeed * dt
            if step > dist then step = dist end
            ent.Position = ent.Position + (dir.Unit * step)
        end
        -- damage if close
        if dist <= Config.ENTITY.DamageRange then
            EntityAI.DamageCallback(target.player, Config.ENTITY.Damage)
        end
    end
end

startRound = function()
    if gameState.Phase ~= "Lobby" then return end
    gameState.Phase = "Playing"
    gameState.RoundStart = tick()
    gameState.AllFloorsCleared = false
    gameState.LastRoundAllCleared = false
    -- reset players
    for userId, ps in pairs(gameState.Players) do
        ps.alive = true
        ps.currentRoom = 0
        ps.damageTaken = 0
        local s = sessions[ps.player]
        if s then
            s.Alive = true
            s.DamageTaken = 0
            s.CurrentRoom = 0
        end
    end
    -- spawn entity
    if gameState.Entity then
        gameState.Entity:Destroy()
        gameState.Entity = nil
    end
    spawnEntity()
    -- fire client
    for _, p in ipairs(Players:GetPlayers()) do
        remotes.GameStart:FireClient(p, gameState.CurrentFloor)
    end
    -- heartbeat
    if gameState.HeartbeatConn then
        gameState.HeartbeatConn:Disconnect()
        gameState.HeartbeatConn = nil
    end
    gameState.HeartbeatConn = RunService.Heartbeat:Connect(function(dt)
        entityStep(dt)
        -- time check
        if tick() - gameState.RoundStart >= Config.ROUND_TIME then
            endRound("TimeUp")
        end
    end)
end

endRound = function(reason)
    if gameState.Phase ~= "Playing" then return end
    gameState.Phase = "Results"
    if gameState.HeartbeatConn then
        gameState.HeartbeatConn:Disconnect()
        gameState.HeartbeatConn = nil
    end
    -- destroy entity
    if gameState.Entity then
        gameState.Entity:Destroy()
        gameState.Entity = nil
    end

    local allCleared = (reason == "Escape" and gameState.CurrentFloor >= Config.MAX_FLOOR)
    if allCleared then
        gameState.LastRoundAllCleared = true
    else
        gameState.LastRoundAllCleared = false
    end

    -- rewards for survivors
    if reason == "Escape" then
        for userId, ps in pairs(gameState.Players) do
            if ps.alive then
                local s = sessions[ps.player]
                if s then
                    local coins = 50 * gameState.CurrentFloor
                    if hasPass(ps.player, "VIP") then coins = math.floor(coins * 1.5) end
                    giveCoins(ps.player, coins)
                    giveRep(ps.player, 10 * gameState.CurrentFloor)
                    s.Profile.TotalEscapes = (s.Profile.TotalEscapes or 0) + 1
                    if gameState.CurrentFloor > (s.Profile.BestFloor or 0) then
                        s.Profile.BestFloor = gameState.CurrentFloor
                    end
                    checkAchievements(ps.player)
                end
            end
        end
        gameState.EscapesToday = gameState.EscapesToday + 1
    end

    -- floor progression
    if reason == "Escape" then
        gameState.CurrentFloor = gameState.CurrentFloor + 1
        if gameState.CurrentFloor > Config.MAX_FLOOR then
            gameState.CurrentFloor = 1
        end
    end
    -- Death and TimeUp do NOT advance floor

    -- fire client
    for _, p in ipairs(Players:GetPlayers()) do
        remotes.GameEnd:FireClient(p, reason, gameState.LastRoundAllCleared)
    end

    remotes.SocialProof:FireAllClients(gameState.EscapesToday, gameState.OnlineCount)

    -- intermission then auto-restart
    task.delay(Config.INTERMISSION, function()
        if gameState.Phase == "Results" then
            gameState.Phase = "Lobby"
            -- auto restart if players present
            if #Players:GetPlayers() >= 1 then
                startRound()
            end
        end
    end)
end

tryAutoStart = function()
    if gameState.Phase ~= "Lobby" then return end
    local hasPlayers = #Players:GetPlayers() >= 1
    if not hasPlayers then
        -- fallback: check tracked players
        for _ in pairs(gameState.Players) do hasPlayers = true break end
    end
    if hasPlayers then
        startRound()
    end
end

-- ============================================================
-- Remote handlers (intents)
-- ============================================================
remotes.ThrowPebble.OnServerEvent:Connect(function(player, dir)
    if not rateLimit(player, "throw", 5) then return end
    if type(dir) ~= "table" then return end
    local s = sessions[player]
    if not s or not s.Alive then return end
    if gameState.Phase ~= "Playing" then return end
    if s.Pebbles <= 0 then return end
    s.Pebbles = s.Pebbles - 1
    s.Profile.Stats.throws = (s.Profile.Stats.throws or 0) + 1
    -- notify entity (sound) — handled by client FX; server just counts
end)

remotes.OpenValve.OnServerEvent:Connect(function(player, valveIndex)
    if not rateLimit(player, "valve", 3) then return end
    if type(valveIndex) ~= "number" then return end
    local s = sessions[player]
    if not s or not s.Alive then return end
    if gameState.Phase ~= "Playing" then return end
    if gameState.CurrentFloor ~= 8 then return end
    if valveIndex < 1 or valveIndex > 2 then return end
    s.Profile.Stats.valves = (s.Profile.Stats.valves or 0) + 1
    -- if both valves open, trigger escape
    -- (simplified: client tracks; server validates doorIndex == CurrentRoom+1)
end)

remotes.ReviveRequest.OnServerEvent:Connect(function(player)
    if not rateLimit(player, "revive", 2) then return end
    local s = sessions[player]
    if not s then return end
    if s.Alive then return end
    if (s.ReviveTokens or 0) <= 0 then
        remotes.Toast:FireClient(player, "No revive tokens. Buy one in the store.")
        return
    end
    s.ReviveTokens = s.ReviveTokens - 1
    s.Alive = true
    s.DamageTaken = 0
    s.Profile.Stats.revives = (s.Profile.Stats.revives or 0) + 1
    remotes.Toast:FireClient(player, "Revived!")
end)

remotes.BuyUpgrade.OnServerInvoke = function(player, upgradeId)
    if type(upgradeId) ~= "string" then return false, "invalid" end
    if not rateLimit(player, "buy", 5) then return false, "rate limited" end
    local s = sessions[player]
    if not s then return false, "no session" end
    -- find upgrade
    local upg = nil
    for _, u in ipairs(Config.UPGRADES) do
        if u.Id == upgradeId then upg = u break end
    end
    if not upg then return false, "unknown upgrade" end
    local gear = Config.Gear[upgradeId]
    if not gear or gear.Source ~= "coils" then return false, "not purchasable with coins" end
    if s.Profile.Gear[upgradeId] then return false, "already owned" end
    if (s.Profile.Coins or 0) < upg.Price then return false, "not enough coins" end
    -- deduct
    s.Profile.Coins = s.Profile.Coins - upg.Price
    s.Profile.Gear[upgradeId] = true
    -- apply effect
    if gear.Effect then
        if gear.Effect.ThrowRange then s.ThrowRange = (s.ThrowRange or 0) + gear.Effect.ThrowRange end
        if gear.Effect.PebbleCap then s.PebbleCap = gear.Effect.PebbleCap end
        if gear.Effect.RescueSpeed then s.RescueSpeed = gear.Effect.RescueSpeed end
        if gear.Effect.ValveSpeed then s.ValveSpeed = gear.Effect.ValveSpeed end
        if gear.Effect.WalkSpeed then s.WalkSpeedBonus = (s.WalkSpeedBonus or 0) + gear.Effect.WalkSpeed end
        if gear.Effect.PickupRadius then s.PickupRadius = (s.PickupRadius or 0) + gear.Effect.PickupRadius end
    end
    saveProfile(player)
    remotes.CoinUpdate:FireClient(player, s.Profile.Coins)
    remotes.Toast:FireClient(player, "Purchased: " .. gear.Name)
    return true, "ok"
end

remotes.ClaimDaily.OnServerInvoke = function(player)
    if not rateLimit(player, "daily", 2) then return false, "rate limited" end
    local s = sessions[player]
    if not s then return false, "no session" end
    -- daily already handled on join; this is a manual claim fallback
    return true, "claimed"
end

remotes.PromptPurchase.OnServerInvoke = function(player, productIdOrKey, isPass)
    if type(productIdOrKey) ~= "string" and type(productIdOrKey) ~= "number" then return false end
    if isPass then
        -- find pass id
        local cfg = Config.PASSES[productIdOrKey]
        if not cfg or cfg.Id == 0 then
            remotes.Toast:FireClient(player, "Setup pending — pass not configured yet.")
            return false
        end
        MarketplaceService:PromptGamePassPurchase(player, cfg.Id)
    else
        local cfg = Config.PRODUCTS[productIdOrKey]
        if not cfg or cfg.Id == 0 then
            remotes.Toast:FireClient(player, "Setup pending — product not configured yet.")
            return false
        end
        MarketplaceService:PromptProductPurchase(player, cfg.Id)
    end
    return true
end

-- Quick chat (proximity-scoped, fixed list)
local QUICK_CHAT_LINES = {
    "Help!", "Over here!", "Run!", "Wait!", "I found pebbles", "Open the valve!", "Monster incoming!", "Revive me!"
}
remotes.QuickChat.OnServerEvent:Connect(function(player, lineIndex)
    if not rateLimit(player, "chat", 3) then return end
    if type(lineIndex) ~= "number" then return end
    if lineIndex < 1 or lineIndex > #QUICK_CHAT_LINES then return end
    local s = sessions[player]
    if not s or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.Character then
            local ohrp = other.Character:FindFirstChild("HumanoidRootPart")
            if ohrp and (ohrp.Position - hrp.Position).Magnitude <= 50 then
                remotes.QuickChat:FireClient(other, player.Name, QUICK_CHAT_LINES[lineIndex])
            end
        end
    end
end)

-- Door opened validation (client reports door index; server validates sequential)
remotes.DoorOpened.OnServerEvent:Connect(function(player, doorIndex)
    if not rateLimit(player, "door", 5) then return end
    if type(doorIndex) ~= "number" then return end
    local s = sessions[player]
    if not s or not s.Alive then return end
    if gameState.Phase ~= "Playing" then return end
    if doorIndex ~= (s.CurrentRoom or 0) + 1 then
        warn("Invalid door skip attempt by " .. player.Name)
        return
    end
    s.CurrentRoom = doorIndex
    -- if reached last door of floor, escape
    local roomCount = #Config.ROOMS
    if s.CurrentRoom >= roomCount then
        -- escape
        if not s.Profile.Achievements then s.Profile.Achievements = {} end
        endRound("Escape")
    end
end)

-- ============================================================
-- Export test hook (test-only, not shipped behavior)
-- ============================================================
__BLOX_TEST__ = {
    PASS_IDS = PASS_IDS,
    PRODUCT_IDS = PRODUCT_IDS,
    sessions = sessions,
    gameState = gameState,
    getProfile = function(player)
        local s = sessions[player]
        return s and s.Profile or nil
    end,
    grantProduct = grantProduct,
    grantPass = grantPass,
    giveCoins = giveCoins,
    giveRep = giveRep,
    processReceipt = processReceipt,
    startRound = startRound,
    endRound = endRound,
    tryAutoStart = tryAutoStart,
    Config = Config,
}

-- ============================================================
-- Init: ensure players already in server get handled
-- ============================================================
for _, p in ipairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end
