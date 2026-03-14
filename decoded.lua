-- ADC Hub - Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Suppress all Rayfield notifications/prompts
Rayfield.Notify = function() end


local Window = Rayfield:CreateWindow({
    Name             = "ADC Hub",
    LoadingTitle     = "ADC Hub",
    LoadingSubtitle  = "Loading...",
    ConfigurationSaving = { Enabled = true, FileName = "ADCHub" },
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
    KeySystem        = false,
    KeySettings      = {
        Title           = "ADC Hub",
        Subtitle        = "Key Required",
        Note            = "Get fucked",
        FileName        = "ADCHub",
        SaveKey         = true,
        GrabKeyFromSite = false,
        Key             = { "adchub1" },
    },
})

-- Services
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Tabs
local MiscTab   = Window:CreateTab("Misc",   4483345998)
local EspTab    = Window:CreateTab("ESP",    4483345998)
local HitboxTab = Window:CreateTab("Hitbox", 4483345998)
local SpeedTab  = Window:CreateTab("Speed",  4483345998)

-- ============================================================
--  MISC
-- ============================================================

local autoDeleteConn
MiscTab:CreateToggle({
    Name         = "Auto Delete Dead Bodies",
    CurrentValue = false,
    Flag         = "AutoDeleteDeadBodies",
    Callback     = function(on)
        if on then
            autoDeleteConn = RunService.Heartbeat:Connect(function()
                local folder = workspace:FindFirstChild("DeadBodies")
                if folder then
                    for _, m in ipairs(folder:GetChildren()) do
                        m:Destroy()
                    end
                end
            end)
        else
            if autoDeleteConn then autoDeleteConn:Disconnect(); autoDeleteConn = nil end
        end
    end,
})

local promptDescConn
MiscTab:CreateToggle({
    Name         = "Instant Proximity Prompts",
    CurrentValue = false,
    Flag         = "InstantProxPrompts",
    Callback     = function(on)
        if on then
            for _, v in ipairs(game:GetDescendants()) do
                if v:IsA("ProximityPrompt") then v.HoldDuration = 0 end
            end
            promptDescConn = game.DescendantAdded:Connect(function(v)
                if v:IsA("ProximityPrompt") then v.HoldDuration = 0 end
            end)
        else
            if promptDescConn then promptDescConn:Disconnect(); promptDescConn = nil end
        end
    end,
})

-- ============================================================
--  ESP HELPERS
-- ============================================================

local function makeHighlight(adornee, fillColor, outlineColor)
    local h = Instance.new("Highlight")
    h.FillColor           = fillColor
    h.OutlineColor        = outlineColor or fillColor
    h.FillTransparency    = 0.65
    h.OutlineTransparency = 0
    h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee             = adornee
    h.Parent              = game:GetService("CoreGui")
    return h
end

local function makeBillboard(adornee, text, color)
    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 120, 0, 18)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Adornee     = adornee
    bb.Parent      = game:GetService("CoreGui")

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = color
    lbl.Text                   = text
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 13
    lbl.Parent                 = bb
    return bb
end

-- ============================================================
--  KEYCARD ESP
-- ============================================================

local keycardHighlights = {}
local keycardConn

local function refreshKeycardEsp()
    for key, data in pairs(keycardHighlights) do
        if not data.part or not data.part.Parent then
            if data.hl then data.hl:Destroy() end
            if data.bb then data.bb:Destroy() end
            keycardHighlights[key] = nil
        end
    end
    local ppd = workspace:FindFirstChild("ParisiusPoliceDepartment_2003")
    if not ppd then return end
    local ks = ppd:FindFirstChild("KeycardSpawns")
    if not ks then return end
    for _, child in ipairs(ks:GetChildren()) do
        -- Handle is a direct part under KeycardSpawns
        local handle = (child.Name == "Handle" and child:IsA("BasePart")) and child
            or child:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            local key = handle:GetDebugId()
            if not keycardHighlights[key] then
                keycardHighlights[key] = {
                    part = handle,
                    hl   = makeHighlight(handle, Color3.fromRGB(255, 220, 0), Color3.fromRGB(255, 255, 0)),
                    bb   = makeBillboard(handle, "Keycard", Color3.fromRGB(255, 220, 0)),
                }
            end
        end
    end
end

local function clearKeycardEsp()
    for _, data in pairs(keycardHighlights) do
        if data.hl then data.hl:Destroy() end
        if data.bb then data.bb:Destroy() end
    end
    keycardHighlights = {}
end

EspTab:CreateToggle({
    Name         = "Keycard ESP",
    CurrentValue = false,
    Flag         = "KeycardEsp",
    Callback     = function(on)
        if on then
            refreshKeycardEsp()
            keycardConn = RunService.Heartbeat:Connect(refreshKeycardEsp)
        else
            if keycardConn then keycardConn:Disconnect(); keycardConn = nil end
            clearKeycardEsp()
        end
    end,
})

-- ============================================================
--  DROPS ESP
-- ============================================================

local dropsHighlights = {}
local dropsConn

local function refreshDropsEsp()
    for key, data in pairs(dropsHighlights) do
        if not data.part or not data.part.Parent then
            if data.hl then data.hl:Destroy() end
            if data.bb then data.bb:Destroy() end
            dropsHighlights[key] = nil
        end
    end
    local drops = workspace:FindFirstChild("Drops")
    if not drops then return end
    for _, item in ipairs(drops:GetChildren()) do
        local adornee = item:IsA("BasePart") and item
            or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildOfClass("BasePart")))
        if adornee then
            local key = adornee:GetDebugId()
            if not dropsHighlights[key] then
                dropsHighlights[key] = {
                    part = adornee,
                    hl   = makeHighlight(item, Color3.fromRGB(0, 230, 230), Color3.fromRGB(0, 255, 255)),
                    bb   = makeBillboard(adornee, item.Name, Color3.fromRGB(0, 230, 230)),
                }
            end
        end
    end
end

local function clearDropsEsp()
    for _, data in pairs(dropsHighlights) do
        if data.hl then data.hl:Destroy() end
        if data.bb then data.bb:Destroy() end
    end
    dropsHighlights = {}
end

EspTab:CreateToggle({
    Name         = "Drops ESP",
    CurrentValue = false,
    Flag         = "DropsEsp",
    Callback     = function(on)
        if on then
            refreshDropsEsp()
            dropsConn = RunService.Heartbeat:Connect(refreshDropsEsp)
        else
            if dropsConn then dropsConn:Disconnect(); dropsConn = nil end
            clearDropsEsp()
        end
    end,
})

-- ============================================================
--  PLAYER ESP
-- ============================================================

local TEAM_COLORS = {
    { key = "bystander", color = Color3.fromRGB(0,   200,   0) },
    { key = "killer",    color = Color3.fromRGB(255,   0,   0) },
    { key = "team 1",    color = Color3.fromRGB(0,    0,  180) },
    { key = "team 2",    color = Color3.fromRGB(0,  130,   0) },
    { key = "robber",    color = Color3.fromRGB(40,   40,  40) },
    { key = "white",     color = Color3.fromRGB(255, 255, 255) },
    { key = "purple",    color = Color3.fromRGB(128,   0, 128) },
    { key = "police",    color = Color3.fromRGB(0,     0, 255) },
}

local function getTeamColor(player)
    if player.Team then
        local name = player.Team.Name:lower()
        for _, entry in ipairs(TEAM_COLORS) do
            if name:find(entry.key) then return entry.color end
        end
    end
    return Color3.fromRGB(200, 200, 200)
end

local playerHighlights = {}
local playerEspConn
local playerEspEnabled = false

local function removePlayerEsp(name)
    if playerHighlights[name] then
        if playerHighlights[name].hl then playerHighlights[name].hl:Destroy() end
        if playerHighlights[name].bb then playerHighlights[name].bb:Destroy() end
        playerHighlights[name] = nil
    end
end

local function addPlayerEsp(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- always recreate on new character
    removePlayerEsp(player.Name)

    local color = getTeamColor(player)
    local label = player.Name .. " [" .. (player.Team and player.Team.Name or "?") .. "]"
    playerHighlights[player.Name] = {
        hl   = makeHighlight(char, color, color),
        bb   = makeBillboard(root, label, color),
        char = char,
    }
end

local function refreshPlayerEsp()
    local existing = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        existing[player.Name] = true

        local data = playerHighlights[player.Name]

        -- respawn detection: character changed, recreate
        if data and data.char ~= char then
            removePlayerEsp(player.Name)
            data = nil
        end

        if not data then
            addPlayerEsp(player)
        else
            -- update color/label live
            local color = getTeamColor(player)
            local label = player.Name .. " [" .. (player.Team and player.Team.Name or "?") .. "]"
            if data.hl and data.hl.Parent then
                data.hl.FillColor    = color
                data.hl.OutlineColor = color
            end
            if data.bb and data.bb.Parent then
                local lbl = data.bb:FindFirstChildOfClass("TextLabel")
                if lbl then lbl.TextColor3 = color; lbl.Text = label end
            end
        end
    end

    -- clean up players who left
    for name in pairs(playerHighlights) do
        if not existing[name] then
            removePlayerEsp(name)
        end
    end
end

local function clearPlayerEsp()
    for name in pairs(playerHighlights) do
        removePlayerEsp(name)
    end
end

-- Hook new players joining and respawning
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if playerEspEnabled then
            task.wait(0.1) -- brief wait for char to load
            addPlayerEsp(player)
        end
    end)
end)

-- Hook existing players' respawns
for _, player in ipairs(Players:GetPlayers()) do
    if player == LocalPlayer then continue end
    player.CharacterAdded:Connect(function()
        if playerEspEnabled then
            task.wait(0.1)
            addPlayerEsp(player)
        end
    end)
end

EspTab:CreateToggle({
    Name         = "Player ESP",
    CurrentValue = false,
    Flag         = "PlayerEsp",
    Callback     = function(on)
        playerEspEnabled = on
        if on then
            playerEspConn = RunService.Heartbeat:Connect(refreshPlayerEsp)
        else
            if playerEspConn then playerEspConn:Disconnect(); playerEspConn = nil end
            clearPlayerEsp()
        end
    end,
})

-- ============================================================
--  HITBOX EXPANDER
-- ============================================================

local hitboxEnabled = false
local hitboxSize    = 10
local hitboxConn
local hitboxKey     = Enum.KeyCode.L
local originalSizes = {}
local teamCheckEnabled = true  -- when true, teammates are excluded

-- Per-part toggles
local hitboxParts = {
    Head             = true,
    Torso            = true,
    HumanoidRootPart = true,
}

-- Per-team toggles
local hitboxTeams = {
    bystander  = true,
    killer     = true,
    ["team 1"] = true,
    ["team 2"] = true,
    robber     = true,
    white      = true,
    purple     = true,
    police     = true,
}

local function getLocalTeamKey()
    if LocalPlayer.Team then
        local name = LocalPlayer.Team.Name:lower()
        for key in pairs(hitboxTeams) do
            if name:find(key) then return key end
        end
    end
    return nil
end

local function getPlayerTeamKey(player)
    if player.Team then
        local name = player.Team.Name:lower()
        for key in pairs(hitboxTeams) do
            if name:find(key) then return key end
        end
    end
    return nil
end

-- Returns true if Head should be blocked for this target based on cross-team rules
local function isHeadProtected(targetPlayer)
    local localKey  = getLocalTeamKey()
    local targetKey = getPlayerTeamKey(targetPlayer)
    if not localKey or not targetKey then return false end
    -- Bystanders can't expand Police heads, and vice versa
    if (localKey == "bystander" and targetKey == "police") then return true end
    if (localKey == "police"    and targetKey == "bystander") then return true end
    return false
end

local function isTeammate(player)
    return LocalPlayer.Team ~= nil
        and player.Team ~= nil
        and player.Team == LocalPlayer.Team
end

local function shouldHitbox(player)
    if player == LocalPlayer then return false end
    -- always protect teammates regardless of team check toggle
    if isTeammate(player) then return false end
    -- team check toggle: extra protection when on
    if teamCheckEnabled and isTeammate(player) then return false end
    -- per-team toggle
    local teamKey = getPlayerTeamKey(player)
    if teamKey then
        return hitboxTeams[teamKey]
    end
    return true
end

local function restorePlayerHitbox(player)
    local char = player.Character
    if not char then return end
    for partName in pairs(hitboxParts) do
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local key = player.Name .. "_" .. partName
            if originalSizes[key] then
                part.Size = originalSizes[key]
                originalSizes[key] = nil
            end
            part.Transparency = (partName == "HumanoidRootPart") and 1 or 0
        end
    end
end

local function expandHitboxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end

        -- if player is now a teammate, restore them immediately
        if isTeammate(player) then
            restorePlayerHitbox(player)
            continue
        end

        if not shouldHitbox(player) then
            restorePlayerHitbox(player)
            continue
        end

        for partName, enabled in pairs(hitboxParts) do
            local part = char:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                local key = player.Name .. "_" .. partName
                -- cross-team head protection
                local blocked = (partName == "Head") and isHeadProtected(player)
                if enabled and not blocked then
                    if not originalSizes[key] then
                        originalSizes[key] = part.Size
                    end
                    part.Size         = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                    part.Transparency = (partName == "HumanoidRootPart") and 1 or 0.85
                else
                    if originalSizes[key] then
                        part.Size = originalSizes[key]
                        originalSizes[key] = nil
                        part.Transparency = (partName == "HumanoidRootPart") and 1 or 0
                    end
                end
            end
        end
    end
end

-- Hook new players + respawns for hitbox
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        -- clear stale original sizes for this player on respawn
        for partName in pairs(hitboxParts) do
            originalSizes[player.Name .. "_" .. partName] = nil
        end
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player == LocalPlayer then continue end
    player.CharacterAdded:Connect(function()
        for partName in pairs(hitboxParts) do
            originalSizes[player.Name .. "_" .. partName] = nil
        end
    end)
end

local function restoreHitboxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        restorePlayerHitbox(player)
    end
    originalSizes = {}
end

local function setHitbox(on)
    hitboxEnabled = on
    if on then
        if not hitboxConn then
            hitboxConn = RunService.Heartbeat:Connect(expandHitboxes)
        end
    else
        if hitboxConn then hitboxConn:Disconnect(); hitboxConn = nil end
        restoreHitboxes()
    end
end

-- Main toggle
HitboxTab:CreateToggle({
    Name         = "Hitbox Expander",
    CurrentValue = false,
    Flag         = "HitboxExpander",
    Callback     = function(on) setHitbox(on) end,
})

-- Team check toggle
HitboxTab:CreateToggle({
    Name         = "Team Check (Protect Teammates)",
    CurrentValue = true,
    Flag         = "HitboxTeamCheck",
    Callback     = function(on) teamCheckEnabled = on end,
})

-- Size slider
HitboxTab:CreateSlider({
    Name         = "Hitbox Size",
    Range        = { 4, 10 },
    Increment    = 1,
    CurrentValue = 10,
    Flag         = "HitboxSize",
    Callback     = function(v) hitboxSize = v end,
})

-- Keybind
HitboxTab:CreateKeybind({
    Name           = "Hitbox Toggle Keybind",
    CurrentKeybind = "L",
    HoldToInteract = false,
    Flag           = "HitboxKeybind",
    Callback       = function(keybind)
        hitboxKey = Enum.KeyCode[keybind] or Enum.KeyCode.L
    end,
})

-- Part toggles
HitboxTab:CreateSection("Parts")

HitboxTab:CreateToggle({
    Name         = "Expand Head",
    CurrentValue = true,
    Flag         = "HitboxHead",
    Callback     = function(on) hitboxParts.Head = on end,
})

HitboxTab:CreateToggle({
    Name         = "Expand Torso",
    CurrentValue = true,
    Flag         = "HitboxTorso",
    Callback     = function(on) hitboxParts.Torso = on end,
})

HitboxTab:CreateToggle({
    Name         = "Expand HumanoidRootPart",
    CurrentValue = true,
    Flag         = "HitboxHRP",
    Callback     = function(on) hitboxParts.HumanoidRootPart = on end,
})

-- Team toggles
HitboxTab:CreateSection("Teams")

HitboxTab:CreateToggle({
    Name         = "Bystanders",
    CurrentValue = true,
    Flag         = "HitboxBystander",
    Callback     = function(on) hitboxTeams["bystander"] = on end,
})

HitboxTab:CreateToggle({
    Name         = "Killers",
    CurrentValue = true,
    Flag         = "HitboxKiller",
    Callback     = function(on) hitboxTeams["killer"] = on end,
})

HitboxTab:CreateToggle({
    Name         = "Team 1",
    CurrentValue = true,
    Flag         = "HitboxTeam1",
    Callback     = function(on) hitboxTeams["team 1"] = on end,
})

HitboxTab:CreateToggle({
    Name         = "Team 2",
    CurrentValue = true,
    Flag         = "HitboxTeam2",
    Callback     = function(on) hitboxTeams["team 2"] = on end,
})

HitboxTab:CreateToggle({
    Name         = "Robbers",
    CurrentValue = true,
    Flag         = "HitboxRobber",
    Callback     = function(on) hitboxTeams["robber"] = on end,
})

HitboxTab:CreateToggle({
    Name         = "White Team",
    CurrentValue = true,
    Flag         = "HitboxWhite",
    Callback     = function(on) hitboxTeams["white"] = on end,
})

HitboxTab:CreateToggle({
    Name         = "Purple Team",
    CurrentValue = true,
    Flag         = "HitboxPurple",
    Callback     = function(on) hitboxTeams["purple"] = on end,
})

HitboxTab:CreateToggle({
    Name         = "Police",
    CurrentValue = true,
    Flag         = "HitboxPolice",
    Callback     = function(on) hitboxTeams["police"] = on end,
})

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == hitboxKey then
        setHitbox(not hitboxEnabled)
    end
end)

-- ============================================================
--  SPEED BOOST
-- ============================================================

local speedEnabled    = false
local speedMultiplier = 1.0
local baseSpeed       = nil
local speedConn

local function getHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
    local hum = getHumanoid()
    if not hum then return end
    if not baseSpeed then
        baseSpeed = hum.WalkSpeed
    end
    hum.WalkSpeed = baseSpeed * speedMultiplier
end

local function restoreSpeed()
    local hum = getHumanoid()
    if hum and baseSpeed then
        hum.WalkSpeed = baseSpeed
    end
    baseSpeed = nil
end

-- Re-capture base speed on respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    baseSpeed = nil
    if speedEnabled then
        task.wait(0.2)
        applySpeed()
    end
end)

SpeedTab:CreateToggle({
    Name         = "Speed Boost",
    CurrentValue = false,
    Flag         = "SpeedBoost",
    Callback     = function(on)
        speedEnabled = on
        if on then
            applySpeed()
            speedConn = RunService.Heartbeat:Connect(function()
                local hum = getHumanoid()
                if hum and baseSpeed then
                    -- keep reapplying so anticheat corrections get overridden gradually
                    if math.abs(hum.WalkSpeed - baseSpeed * speedMultiplier) > 0.1 then
                        hum.WalkSpeed = baseSpeed * speedMultiplier
                    end
                end
            end)
        else
            if speedConn then speedConn:Disconnect(); speedConn = nil end
            restoreSpeed()
        end
    end,
})

SpeedTab:CreateSlider({
    Name         = "Speed Multiplier",
    Range        = { 100, 160 },
    Increment    = 5,
    CurrentValue = 100,
    Flag         = "SpeedMultiplier",
    Callback     = function(v)
        speedMultiplier = v / 100
        if speedEnabled then applySpeed() end
    end,
})

SpeedTab:CreateLabel("Values: 100 = 1x  |  130 = 1.3x  |  160 = 1.6x")

-- Load saved config
Rayfield:LoadConfiguration()
