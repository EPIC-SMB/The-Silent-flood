-- Silent Flood — BloxClient (LocalScript, StarterPlayer/StarterCharacterScripts)
-- HUD, store, targeting, FX. Never decides money or purchases.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("BloxConfig"))

-- Remotes
local remotes = {}
local function getRemote(name)
    local r = ReplicatedStorage:WaitForChild(name, 10)
    return r
end

task.delay(1, function()
    remotes.GameStart = getRemote("GameStartRemote")
    remotes.GameEnd = getRemote("GameEndRemote")
    remotes.EntityDamage = getRemote("EntityDamageRemote")
    remotes.DoorOpened = getRemote("DoorOpenedRemote")
    remotes.CoinUpdate = getRemote("CoinUpdateRemote")
    remotes.RepUpdate = getRemote("RepUpdateRemote")
    remotes.Toast = getRemote("ToastRemote")
    remotes.StoreUpdate = getRemote("StoreUpdateRemote")
    remotes.SocialProof = getRemote("SocialProofRemote")
    remotes.DailyReward = getRemote("DailyRewardRemote")
    remotes.LootResult = getRemote("LootResultRemote")
    remotes.QuickChat = getRemote("QuickChatRemote")
    remotes.BuyUpgrade = getRemote("BuyUpgradeRemote")
    remotes.ClaimDaily = getRemote("ClaimDailyRemote")
    remotes.PromptPurchase = getRemote("PromptPurchaseRemote")
    remotes.ThrowPebble = getRemote("ThrowPebbleRemote")
    remotes.OpenValve = getRemote("OpenValveRemote")
    remotes.ReviveRequest = getRemote("ReviveRequestRemote")
end)

-- ============================================================
-- State
-- ============================================================
local state = {
    coins = 0,
    rep = 0,
    repTier = 1,
    pebbles = 5,
    pebbleCap = 5,
    alive = true,
    currentFloor = 1,
    currentRoom = 0,
    totalRooms = #Config.ROOMS,
    speedBoostExpiry = 0,
    sprinting = false,
    currentFloorDisplay = 1,
}

-- ============================================================
-- HUD helpers
-- ============================================================
local function makeLabel(parent, text, pos, size)
    local l = Instance.new("TextLabel")
    l.Text = text
    l.Position = pos or UDim2.new(0, 10, 0, 10)
    l.Size = size or UDim2.new(0, 200, 0, 30)
    l.BackgroundTransparency = 0.5
    l.BackgroundColor3 = Color3.new(0, 0, 0)
    l.TextColor3 = Color3.new(1, 1, 1)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 16
    l.Parent = parent
    return l
end

-- Build HUD
local gui = Instance.new("ScreenGui")
gui.Name = "SilentFloodHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Top bar: coins, rep, floor
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundTransparency = 0.3
topBar.BackgroundColor3 = Color3.new(0, 0, 0)
topBar.Parent = gui

local coinsLabel = makeLabel(topBar, "Coins: 0", UDim2.new(0, 10, 0, 5), UDim2.new(0, 120, 0, 30))
local repLabel = makeLabel(topBar, "Rep: 0 (Tier 1)", UDim2.new(0, 140, 0, 5), UDim2.new(0, 160, 0, 30))
local floorLabel = makeLabel(topBar, "Floor 1/8", UDim2.new(0, 310, 0, 5), UDim2.new(0, 120, 0, 30))
local pebblesLabel = makeLabel(topBar, "Pebbles: 5/5", UDim2.new(0, 440, 0, 5), UDim2.new(0, 140, 0, 30))
local roomLabel = makeLabel(topBar, "Door 0/8", UDim2.new(0, 590, 0, 5), UDim2.new(0, 120, 0, 30))

-- Health bar
local healthBar = Instance.new("Frame")
healthBar.Size = UDim2.new(0, 200, 0, 20)
healthBar.Position = UDim2.new(0, 10, 1, -30)
healthBar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
healthBar.Parent = gui
local healthFill = Instance.new("Frame")
healthFill.Size = UDim2.new(1, 0, 1, 0)
healthFill.BackgroundColor3 = Color3.new(0, 0.8, 0)
healthFill.Parent = healthBar

-- Near-miss / toast
local toastLabel = makeLabel(gui, "", UDim2.new(0.5, -150, 0.8, 0), UDim2.new(0, 300, 0, 40))
toastLabel.TextWrapped = true
toastLabel.Visible = false

-- Social proof banner
local socialLabel = makeLabel(gui, "", UDim2.new(0.5, -200, 0, 45), UDim2.new(0, 400, 0, 25))
socialLabel.TextSize = 12
socialLabel.TextColor3 = Color3.new(0.8, 0.8, 1)

-- Daily reward popup (hidden)
local dailyFrame = Instance.new("Frame")
dailyFrame.Size = UDim2.new(0, 300, 0, 200)
dailyFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
dailyFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
dailyFrame.Visible = false
dailyFrame.Parent = gui
local dailyTitle = makeLabel(dailyFrame, "Daily Reward!", UDim2.new(0, 10, 0, 10), UDim2.new(1, -20, 0, 30))
local dailyInfo = makeLabel(dailyFrame, "", UDim2.new(0, 10, 0, 50), UDim2.new(1, -20, 0, 60))
dailyInfo.TextWrapped = true

-- Store frame (hidden)
local storeFrame = Instance.new("Frame")
storeFrame.Size = UDim2.new(0, 420, 0, 400)
storeFrame.Position = UDim2.new(0.5, -210, 0.5, -200)
storeFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
storeFrame.Visible = false
storeFrame.Parent = gui
local storeTitle = makeLabel(storeFrame, "Store", UDim2.new(0, 10, 0, 10), UDim2.new(1, -20, 0, 30))

-- Store tabs: Upgrades (coins), Passes, Products (Robux)
local storeTabs = Instance.new("Frame")
storeTabs.Size = UDim2.new(1, -20, 0, 30)
storeTabs.Position = UDim2.new(0, 10, 0, 45)
storeTabs.BackgroundTransparency = 1
storeTabs.Parent = storeFrame

local storeContent = Instance.new("ScrollingFrame")
storeContent.Size = UDim2.new(1, -20, 1, -90)
storeContent.Position = UDim2.new(0, 10, 0, 80)
storeContent.BackgroundTransparency = 1
storeContent.Parent = storeFrame

local function clearStore()
    for _, c in ipairs(storeContent:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function addStoreRow(text, btnText, onClick)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundTransparency = 0.8
    row.BackgroundColor3 = Color3.new(0.2, 0.2, 0.3)
    row.Parent = storeContent
    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.Parent = row
    local btn = Instance.new("TextButton")
    btn.Text = btnText
    btn.Size = UDim2.new(0.35, 0, 0.8, 0)
    btn.Position = UDim2.new(0.62, 0, 0.1, 0)
    btn.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Parent = row
    btn.MouseButton1Click:Connect(onClick)
    return row
end

local function populateUpgrades()
    clearStore()
    for _, u in ipairs(Config.UPGRADES) do
        local gear = Config.Gear[u.Id]
        addStoreRow(u.Name .. " — " .. u.Price .. " coins", "Buy", function()
            local ok, msg = remotes.BuyUpgrade:InvokeServer(u.Id)
            if not ok then
                showToast(msg or "Failed")
            end
        end)
    end
end

local function populatePasses()
    clearStore()
    for key, cfg in pairs(Config.PASSES) do
        addStoreRow(cfg.Name or key .. " — " .. cfg.Price .. " R$", "Buy Robux", function()
            remotes.PromptPurchase:InvokeServer(key, true)
        end)
    end
end

local function populateProducts()
    clearStore()
    for key, cfg in pairs(Config.PRODUCTS) do
        local label = key .. " — " .. cfg.Price .. " R$"
        if key == "LuckyPebble" then
            label = label .. " (odds: 50/30/15/5%)"
        end
        addStoreRow(label, "Buy Robux", function()
            remotes.PromptPurchase:InvokeServer(key, false)
        end)
    end
end

-- Tab buttons
local function makeTab(text, x, onClick)
    local b = Instance.new("TextButton")
    b.Text = text
    b.Size = UDim2.new(0, 120, 1, 0)
    b.Position = UDim2.new(0, x, 0, 0)
    b.Parent = storeTabs
    b.MouseButton1Click:Connect(onClick)
    return b
end
makeTab("Upgrades", 0, populateUpgrades)
makeTab("Passes", 130, populatePasses)
makeTab("Robux", 260, populateProducts)

-- ============================================================
-- Toast helper
-- ============================================================
local toastTimer = 0
local function showToast(msg)
    toastLabel.Text = msg
    toastLabel.Visible = true
    toastTimer = 3
end

-- ============================================================
-- Remote handlers
-- ============================================================
local function setupHandlers()
    remotes.GameStart.OnClientEvent:Connect(function(floor)
        state.currentFloorDisplay = floor
        state.currentRoom = 0
        state.alive = true
        floorLabel.Text = "Floor " .. floor .. "/" .. Config.MAX_FLOOR
        roomLabel.Text = "Door 0/" .. state.totalRooms
        showToast("Floor " .. floor .. " — stay quiet!")
    end)

    remotes.GameEnd.OnClientEvent:Connect(function(reason, allCleared)
        if reason == "Escape" then
            showToast("Escaped! +" .. (50 * state.currentFloorDisplay) .. " coins")
            if allCleared then
                showToast("ALL FLOORS CLEARED! Victory!")
            end
        elseif reason == "Death" then
            showToast("Caught! Try again.")
        elseif reason == "TimeUp" then
            showToast("Time's up! You were " .. (state.totalRooms - state.currentRoom) .. " doors away.")
        end
    end)

    remotes.EntityDamage.OnClientEvent:Connect(function(damageTaken, maxHp)
        local pct = 1 - (damageTaken / maxHp)
        if pct < 0 then pct = 0 end
        healthFill.Size = UDim2.new(pct, 0, 1, 0)
        if pct < 0.3 then
            healthFill.BackgroundColor3 = Color3.new(0.9, 0.1, 0.1)
        elseif pct < 0.6 then
            healthFill.BackgroundColor3 = Color3.new(0.9, 0.7, 0.1)
        else
            healthFill.BackgroundColor3 = Color3.new(0, 0.8, 0)
        end
        -- screen flash
        healthBar.BackgroundColor3 = Color3.new(0.8, 0.1, 0.1)
        task.delay(0.2, function() healthBar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2) end)
    end)

    remotes.CoinUpdate.OnClientEvent:Connect(function(coins)
        state.coins = coins
        coinsLabel.Text = "Coins: " .. coins
    end)

    remotes.RepUpdate.OnClientEvent:Connect(function(rep, tier)
        state.rep = rep
        state.repTier = tier
        repLabel.Text = "Rep: " .. rep .. " (Tier " .. tier .. ")"
    end)

    remotes.Toast.OnClientEvent:Connect(function(msg)
        showToast(msg)
    end)

    remotes.SocialProof.OnClientEvent:Connect(function(escapes, online)
        socialLabel.Text = escapes .. " players escaped today · " .. online .. " online now"
    end)

    remotes.DailyReward.OnClientEvent:Connect(function(dayIndex, reward)
        dailyFrame.Visible = true
        dailyInfo.Text = "Day " .. dayIndex .. ": +" .. reward.Coins .. " coins" ..
            (reward.Item and ("\n+ " .. reward.Item) or "")
        task.delay(5, function() dailyFrame.Visible = false end)
    end)

    remotes.LootResult.OnClientEvent:Connect(function(outcome)
        showToast("Lucky Pebble: " .. outcome)
    end)

    remotes.QuickChat.OnClientEvent:Connect(function(sender, line)
        showToast(sender .. ": " .. line)
    end)
end

task.delay(1.5, setupHandlers)

-- ============================================================
-- Input handling
-- ============================================================
-- Throw pebble on click (raycast not needed; send intent)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if remotes.ThrowPebble then
            remotes.ThrowPebble:FireServer({ x = 0, y = 0, z = 1 })
        end
    end
    if input.KeyCode == Enum.KeyCode.E then
        -- open valve (client sends intent; server validates)
        if remotes.OpenValve then
            remotes.OpenValve:FireServer(1)
        end
    end
    if input.KeyCode == Enum.KeyCode.F then
        -- revive request
        if remotes.ReviveRequest then
            remotes.ReviveRequest:FireServer()
        end
    end
    if input.KeyCode == Enum.KeyCode.Tab then
        storeFrame.Visible = not storeFrame.Visible
        if storeFrame.Visible then populateUpgrades() end
    end
    -- Sprint
    if input.KeyCode == Enum.KeyCode.LeftShift then
        state.sprinting = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        state.sprinting = false
    end
end)

-- Sprint speed apply
local function applySprint()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local base = 16
    if state.sprinting then
        hum.WalkSpeed = base * 1.5
    else
        hum.WalkSpeed = base
    end
end

-- ============================================================
-- Door progress (client tracks room, reports to server)
-- ============================================================
local function onDoorTouched(doorIndex)
    if remotes.DoorOpened then
        remotes.DoorOpened:FireServer(doorIndex)
    end
    state.currentRoom = doorIndex
    roomLabel.Text = "Door " .. doorIndex .. "/" .. state.totalRooms
    -- Zeigarnik progress
    if doorIndex < state.totalRooms then
        showToast("Door " .. doorIndex .. "/" .. state.totalRooms .. " — keep going!")
    end
end

-- ============================================================
-- Update loop
-- ============================================================
local function updateLoop()
    while true do
        task.wait(0.1)
        applySprint()
        -- speed boost expiry
        if state.speedBoostExpiry > 0 and tick() > state.speedBoostExpiry then
            state.speedBoostExpiry = 0
            showToast("Speed boost expired")
        end
        -- pebbles label
        pebblesLabel.Text = "Pebbles: " .. state.pebbles .. "/" .. state.pebbleCap
    end
end

task.spawn(updateLoop)

-- ============================================================
-- Near-miss messaging on death/timeout handled in GameEnd
-- ============================================================

-- ============================================================
-- Claim daily on join
-- ============================================================
task.delay(3, function()
    if remotes.ClaimDaily then
        remotes.ClaimDaily:InvokeServer()
    end
end)

print("Silent Flood client loaded")
