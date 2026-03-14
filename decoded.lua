-- Gun ESP + Silent Aim - SPH Framework
-- Role detection: BackgroundColor3 of TextButtons in PlayerGui.Spectate.ScrollingFrame
-- Seeker [231,76,60] Red | Police [52,152,219] Blue | Bystander [46,204,113] Green | Unknown Orange
-- ESP: CoreGui parent (undetected) | All items shown
-- Aim: FastCast hook | Role-aware targeting | Wallbang via PierceMod

-- ============================================================
-- MANUAL PERSISTENCE
-- Rayfield's built-in save is unreliable on most executors.
-- We handle key + config ourselves with writefile/readfile.
-- ============================================================
local SAVE_FOLDER = "ADCHub"
local KEY_FILE    = SAVE_FOLDER .. "/key.txt"
local CFG_FILE    = SAVE_FOLDER .. "/ADCHubUT.json"

-- Ensure folder exists
if not isfolder(SAVE_FOLDER) then makefolder(SAVE_FOLDER) end

-- ── Key check ────────────────────────────────────────────
local VALID_KEYS = { adchub1 = true }
local keyPassed  = false

if isfile(KEY_FILE) then
    local saved = readfile(KEY_FILE):gsub("%s+", "")
    if VALID_KEYS[saved] then
        keyPassed = true
    end
end

if not keyPassed then
    -- Show a simple prompt via Rayfield key system on first run
    -- after passing we'll save it ourselves
end

-- ── Config helpers ───────────────────────────────────────
local function loadConfig()
    if not isfile(CFG_FILE) then return {} end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile(CFG_FILE))
    end)
    return (ok and type(data) == "table") and data or {}
end

local function saveConfig(tbl)
    pcall(function()
        writefile(CFG_FILE, game:GetService("HttpService"):JSONEncode(tbl))
    end)
end

local Config = loadConfig()

local function cfgGet(key, default)
    local v = Config[key]
    if v == nil then return default end
    return v
end

local function cfgSet(key, value)
    Config[key] = value
    saveConfig(Config)
end

-- ============================================================
-- RAYFIELD
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name                   = "ADC Hub — UT",
    Icon                   = 0,
    LoadingTitle           = "ADC Hub",
    LoadingSubtitle        = "Loading...",
    Theme                  = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
    ConfigurationSaving    = {
        Enabled    = false,  -- handled manually
    },
    KeySystem   = false,  -- skip if already validated
    KeySettings = {
        Title    = "ADC Hub",
        Subtitle = "Key System",
        Note     = "Join the discord and get the key from the key channel!",
        FileName = "ADCHubUT",
        SaveKey  = false,   -- we save it ourselves
        GrabKeyFromSite = false,
        Key      = {"adchub1"},
    },
})

-- If Rayfield just validated the key, save it now
-- (Rayfield:CreateWindow blocks until key is accepted when KeySystem = true)
if not keyPassed then
    pcall(function() writefile(KEY_FILE, "adchub1") end)
end

-- Startup guard: callbacks don't apply game effects for 1 second
-- so the game has time to load characters, backpacks, etc.
local _cfgApplying = true

local ESPTab     = Window:CreateTab("ESP",             "eye")
local AimbotTab  = Window:CreateTab("Aimbot",          "crosshair")
local AutoAimTab = Window:CreateTab("Auto Aim",        "target")
local HitboxTab  = Window:CreateTab("Hitbox Expander", "maximize-2")
local MiscTab    = Window:CreateTab("Misc",            "settings")

-- ============================================================
-- SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")

local lp     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- ROLE COLORS  (matched from BackgroundColor3 in Dex)
-- ============================================================
local ROLE_SEEKER    = Color3.fromRGB(231, 76,  60)   -- Red
local ROLE_POLICE    = Color3.fromRGB(52,  152, 219)  -- Blue
local ROLE_BYSTANDER = Color3.fromRGB(46,  204, 113)  -- Green
local ROLE_UNKNOWN   = Color3.fromRGB(255, 165, 0)    -- Orange

local ROLE_TOLERANCE = 15  -- tolerance for color comparison

local function colorMatches(c, r, g, b)
    return (math.abs(c.R * 255 - r) < ROLE_TOLERANCE
        and math.abs(c.G * 255 - g) < ROLE_TOLERANCE
        and math.abs(c.B * 255 - b) < ROLE_TOLERANCE)
end

local function colorToRole(bgColor)
    if colorMatches(bgColor, 231, 76,  60)  then return "Seeker"    end
    if colorMatches(bgColor, 52,  152, 219) then return "Police"    end
    if colorMatches(bgColor, 46,  204, 113) then return "Bystander" end
    return nil
end

local function roleColor(role)
    if role == "Seeker"    then return ROLE_SEEKER    end
    if role == "Police"    then return ROLE_POLICE    end
    if role == "Bystander" then return ROLE_BYSTANDER end
    return ROLE_UNKNOWN
end

-- ============================================================
-- ROLE DETECTION
-- Path: PlayerGui → Spectator → ScrollingFrame → [PlayerName buttons]
-- Role determined by BackgroundColor3 of each button
-- ============================================================

local _cachedScrollFrame = nil

local function getScrollFrame()
    if _cachedScrollFrame and _cachedScrollFrame.Parent then
        return _cachedScrollFrame
    end
    _cachedScrollFrame = nil

    local pg   = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local spec = pg:FindFirstChild("Spectator")
    if not spec then return nil end
    local sf   = spec:FindFirstChild("ScrollingFrame")
    if not sf  then return nil end

    _cachedScrollFrame = sf
    return sf
end

local function getPlayerRole(targetPlayer)
    local sf = getScrollFrame()
    if not sf then return nil end

    local child = sf:FindFirstChild(targetPlayer.Name)
    if child and child:IsA("GuiObject") then
        return colorToRole(child.BackgroundColor3)
    end
    return nil
end

-- Invalidate cache if Spectator GUI gets rebuilt between rounds
local _pg = lp:FindFirstChild("PlayerGui")
if _pg then
    local _spec = _pg:FindFirstChild("Spectator")
    if _spec then
        _spec.ChildAdded:Connect(function() _cachedScrollFrame = nil end)
        _spec.DescendantAdded:Connect(function() _cachedScrollFrame = nil end)
    end
end

-- ============================================================
-- MANUAL TARGET GROUP
-- User picks which side to shoot — no local role detection needed
-- "Seeker + Unknown"   → Seeker and nil (Orange)
-- "Bystander + Police" → Bystander and Police
-- "All"               → everyone
-- ============================================================
local targetGroup = "All"  -- default

local function isValidTarget(targetPlayer)
    if targetGroup == "All" then return true end

    local role = getPlayerRole(targetPlayer)  -- "Seeker","Police","Bystander", or nil

    if targetGroup == "Seeker + Unknown" then
        return (role == "Seeker" or role == nil)
    elseif targetGroup == "Bystander + Police" then
        return (role == "Bystander" or role == "Police")
    end

    return false
end

-- ============================================================
-- CHARACTER FINDER
-- Matches workspace Model names to player names (as the devs use custom chars)
-- Falls back to player.Character
-- ============================================================
local function getCharacter(player)
    -- Try workspace model with matching name first
    local wsModel = Workspace:FindFirstChild(player.Name)
    if wsModel and wsModel:IsA("Model") and wsModel:FindFirstChild("HumanoidRootPart") then
        return wsModel
    end
    -- Fallback to standard character
    return player.Character
end

-- ============================================================
-- ALL ITEMS (not filtered — show everything)
-- ============================================================
local function getAllItems(player)
    local found = {}
    local seen  = {}

    local function scan(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and not seen[item.Name] then
                seen[item.Name] = true
                found[#found + 1] = item.Name
            end
        end
    end

    scan(player:FindFirstChildOfClass("Backpack"))
    local char = getCharacter(player)
    if char then scan(char) end

    return found
end

-- ============================================================
-- ESP  (CoreGui parent — undetected)
-- ============================================================
local espEnabled = false
local espObjects = {}  -- [player] = { highlight, billboard, renderConn }

local function cleanupESP(player)
    local obj = espObjects[player]
    if not obj then return end
    if obj.renderConn then obj.renderConn:Disconnect() end
    if obj.highlight  then obj.highlight:Destroy()     end
    if obj.billboard  then obj.billboard:Destroy()     end
    espObjects[player] = nil
end

local function setupESP(player, character)
    cleanupESP(player)
    if not espEnabled then return end

    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    local hum = character:WaitForChild("Humanoid", 5)
    if not hrp or not hum then return end

    -- Highlight — parented to CoreGui, adorned to character
    local highlight = Instance.new("Highlight")
    highlight.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency    = 0.5
    highlight.OutlineTransparency = 1
    highlight.Adornee             = character
    highlight.Parent              = CoreGui

    -- Billboard — parented to CoreGui, adorned to HRP
    local billboard = Instance.new("BillboardGui")
    billboard.Size        = UDim2.fromOffset(220, 90)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 1500
    billboard.Adornee     = hrp
    billboard.Parent      = CoreGui

    local textLabel = Instance.new("TextLabel")
    textLabel.BackgroundTransparency = 1
    textLabel.Size                   = UDim2.fromScale(1, 1)
    textLabel.RichText               = true
    textLabel.TextWrapped            = true
    textLabel.TextSize               = 13
    textLabel.Font                   = Enum.Font.Gotham
    textLabel.TextStrokeTransparency = 0.4
    textLabel.TextColor3             = Color3.new(1, 1, 1)
    textLabel.Parent                 = billboard

    -- Per-player RenderStepped — live updates
    local renderConn = RunService.RenderStepped:Connect(function()
        if hum.Health <= 0 then
            highlight.Enabled = false
            billboard.Enabled = false
            return
        end

        -- Re-check character in case it swapped (workspace model)
        local currentChar = getCharacter(player)
        if currentChar and currentChar ~= highlight.Adornee then
            highlight.Adornee = currentChar
        end

        highlight.Enabled = true
        billboard.Enabled = true

        local dist   = (Camera.CFrame.Position - hrp.Position).Magnitude
        local role   = getPlayerRole(player)
        local color  = roleColor(role)
        local items  = getAllItems(player)

        local roleStr = role and ("<b>[" .. role:upper() .. "]</b> ") or "<b>[UNKNOWN]</b> "

        highlight.FillColor  = color
        textLabel.TextColor3 = color

        textLabel.Text = string.format(
            "%s<b>%s</b>\nHP: %d  Dist: %.0f\n<font color=\"#ffffff\"><b>Items:</b> %s</font>",
            roleStr,
            player.Name,
            math.floor(hum.Health),
            dist,
            #items > 0 and table.concat(items, ", ") or "None"
        )
    end)

    espObjects[player] = {
        highlight  = highlight,
        billboard  = billboard,
        renderConn = renderConn,
    }
end

local function hookPlayerESP(player)
    if player == lp then return end

    player.CharacterAdded:Connect(function(character)
        task.wait(0.2)
        if espEnabled then setupESP(player, character) end
    end)

    player.AncestryChanged:Connect(function(_, parent)
        if not parent then cleanupESP(player) end
    end)

    local char = getCharacter(player)
    if char and espEnabled then setupESP(player, char) end
end

local function enableAllESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            local char = getCharacter(p)
            if char then setupESP(p, char) end
        end
    end
end

local function disableAllESP()
    for player in pairs(espObjects) do cleanupESP(player) end
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayerESP(p) end
Players.PlayerAdded:Connect(hookPlayerESP)

-- ============================================================
-- ESP TAB UI
-- ============================================================
ESPTab:CreateToggle({
    Name         = "Enable ESP",
    CurrentValue = cfgGet("GunESPEnabled", false),
    Flag         = "GunESPEnabled",
    Callback     = function(val)
        cfgSet("GunESPEnabled", val)
        if _cfgApplying then return end
        espEnabled = val
        if val then enableAllESP() else disableAllESP() end
    end,
})

-- ============================================================
-- AIMBOT CONFIG
-- ============================================================
local AimbotConfig = {
    enabled     = false,
    hitChance   = 100,
    wallCheck   = false,
    targetParts = {"Torso"},
    radius      = 150,
    fovVisible  = true,
}

local run         = run_on_actor or run_on_thread
local getActors   = getactors or getactorthreads
local AimbotActor = getActors and getActors()[1]

-- FOV circle
do
    local circle     = Drawing.new("Circle")
    circle.Filled    = false
    circle.NumSides  = 60
    circle.Thickness = 1.5
    circle.Color     = Color3.new(1, 1, 1)

    RunService.RenderStepped:Connect(function()
        local vp = Camera.ViewportSize
        circle.Radius   = AimbotConfig.radius
        circle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        circle.Visible  = AimbotConfig.fovVisible and AimbotConfig.enabled
    end)
end

-- ============================================================
-- AIMBOT TAB UI
-- ============================================================
AimbotTab:CreateToggle({
    Name         = "Silent Aim Enabled",
    CurrentValue = cfgGet("AimbotEnabled", false),
    Flag         = "AimbotEnabled",
    Callback     = function(val)
        cfgSet("AimbotEnabled", val)
        if _cfgApplying then return end
        AimbotConfig.enabled = val
        if AimbotActor then
            run(AimbotActor, ("getgenv().aimbotEnabled = %s"):format(tostring(val)))
        else
            getgenv().aimbotEnabled = val
        end
    end,
})

AimbotTab:CreateSlider({
    Name         = "Hit Chance",
    Range        = {0, 100},
    Increment    = 1,
    Suffix       = "%",
    CurrentValue = cfgGet("HitChance", 100),
    Flag         = "HitChance",
    Callback     = function(val)
        cfgSet("HitChance", val)
        if _cfgApplying then return end
        AimbotConfig.hitChance = val
        if AimbotActor then
            run(AimbotActor, ("getgenv().hitChance = %d"):format(val))
        else
            getgenv().hitChance = val
        end
    end,
})

AimbotTab:CreateToggle({
    Name         = "Wall Check",
    CurrentValue = cfgGet("WallCheck", false),
    Flag         = "WallCheck",
    Callback     = function(val)
        cfgSet("WallCheck", val)
        if _cfgApplying then return end
        AimbotConfig.wallCheck = val
        if AimbotActor then
            run(AimbotActor, ("getgenv().wallCheck = %s"):format(tostring(val)))
        else
            getgenv().wallCheck = val
        end
    end,
})

AimbotTab:CreateDropdown({
    Name          = "Target Group",
    Options       = {"All", "Seeker + Unknown", "Bystander + Police"},
    CurrentOption = {cfgGet("TargetGroup", "All")},
    Flag          = "TargetGroup",
    Callback      = function(opt)
        cfgSet("TargetGroup", type(opt) == "table" and opt[1] or opt)
        if _cfgApplying then return end
        targetGroup = type(opt) == "table" and opt[1] or opt
    end,
})

AimbotTab:CreateDropdown({
    Name            = "Target Part",
    Options         = {"Head", "Torso", "Neckshot", "Left Leg", "Right Leg", "Left Arm", "Right Arm"},
    CurrentOption   = cfgGet("TargetParts", {"Torso"}),
    MultipleOptions = true,
    Flag            = "TargetParts",
    Callback        = function(opts)
        cfgSet("TargetParts", opts)
        if _cfgApplying then return end
        AimbotConfig.targetParts = opts
        local s = "{"
        for i, p in ipairs(opts) do
            s = s .. '"' .. p .. '"' .. (i == #opts and "" or ",")
        end
        s = s .. "}"
        if AimbotActor then
            run(AimbotActor, ("getgenv().targetParts = %s"):format(s))
        else
            getgenv().targetParts = opts
        end
    end,
})

AimbotTab:CreateSlider({
    Name         = "FOV Radius",
    Range        = {0, 1000},
    Increment    = 5,
    CurrentValue = cfgGet("FOVRadius", 150),
    Flag         = "FOVRadius",
    Callback     = function(val)
        cfgSet("FOVRadius", val)
        if _cfgApplying then return end
        AimbotConfig.radius = val
        if AimbotActor then
            run(AimbotActor, ("getgenv().radius = %d"):format(val))
        else
            getgenv().radius = val
        end
    end,
})

AimbotTab:CreateToggle({
    Name         = "Show FOV Circle",
    CurrentValue = cfgGet("FOVVisible", true),
    Flag         = "FOVVisible",
    Callback     = function(val)
        cfgSet("FOVVisible", val)
        if _cfgApplying then return end
        AimbotConfig.fovVisible = val
    end,
})

-- ============================================================
-- VALID TARGETS SYNC LOOP  (main thread → actor, 0.5s)
-- ============================================================
task.spawn(function()
    while true do
        local valid = {}

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lp and isValidTarget(player) then
                valid[player.Name] = true
            end
        end

        local s = "{"
        for name in pairs(valid) do
            s = s .. '["' .. name .. '"]=true,'
        end
        s = s .. "}"

        if AimbotActor then
            run(AimbotActor, ("getgenv().validTargets = %s"):format(s))
        else
            getgenv().validTargets = valid
        end

        task.wait(0.5)
    end
end)

-- ============================================================
-- AIMBOT CORE
-- ============================================================
local function buildAimbotCode()
    local partsStr = "{"
    for i, p in ipairs(AimbotConfig.targetParts) do
        partsStr = partsStr .. '"' .. p .. '"' .. (i == #AimbotConfig.targetParts and "" or ",")
    end
    partsStr = partsStr .. "}"

    return string.format([[
-- Silent Aim — SPH Framework
-- Role-aware targeting via validTargets table synced from main thread

if getgenv().aimbotEnabled == nil then getgenv().aimbotEnabled = false end
if getgenv().hitChance     == nil then getgenv().hitChance     = %d    end
if getgenv().wallCheck     == nil then getgenv().wallCheck     = %s    end
if getgenv().targetParts   == nil then getgenv().targetParts   = %s    end
if getgenv().radius        == nil then getgenv().radius        = %d    end
if getgenv().validTargets  == nil then getgenv().validTargets  = {}    end

local Players           = cloneref(game:GetService("Players"))
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

-- ── Find module by name ───────────────────────────────────
local function findModule(name)
    local sph = ReplicatedStorage:FindFirstChild("SPH_Assets")
    if sph then
        local mods = sph:FindFirstChild("Modules")
        if mods then
            local m = mods:FindFirstChild(name)
            if m then
                local ok, r = pcall(require, m)
                if ok and r then return r end
            end
        end
    end
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("ModuleScript") and v.Name == name then
            local ok, r = pcall(require, v)
            if ok and r then return r end
        end
    end
    return nil
end

-- ── FastCast ──────────────────────────────────────────────
local FastCast = findModule("FastCast")
if not FastCast then
    warn("Silent Aim: FastCast not found")
    return
end
print("Silent Aim: FastCast loaded at " .. tostring(FastCast))

-- ── Character tracker ─────────────────────────────────────
local Characters = {}

local function findCharacter(player)
    local wsModel = Workspace:FindFirstChild(player.Name)
    if wsModel and wsModel:IsA("Model") and wsModel:FindFirstChild("HumanoidRootPart") then
        return wsModel
    end
    return player.Character
end

local function trackCharacter(player, character)
    local root = character:WaitForChild("HumanoidRootPart", 5)
    local hum  = character:WaitForChild("Humanoid", 5)
    if not root or not hum then return end

    local entry = { instance = character, root = root }
    Characters[player] = entry

    hum.Died:Connect(function()
        if Characters[player] == entry then Characters[player] = nil end
    end)
    character.Destroying:Connect(function()
        if Characters[player] == entry then Characters[player] = nil end
    end)
end

local function onCharAdded(player, character)
    Characters[player] = nil
    task.spawn(trackCharacter, player, character)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        local char = findCharacter(p) or p.Character
        if char then task.spawn(trackCharacter, p, char) end
        p.CharacterAdded:Connect(function(c) onCharAdded(p, c) end)
    end
end

Players.PlayerAdded:Connect(function(p)
    if p == LocalPlayer then return end
    local char = findCharacter(p) or p.Character
    if char then task.spawn(trackCharacter, p, char) end
    p.CharacterAdded:Connect(function(c) onCharAdded(p, c) end)
end)

Players.PlayerRemoving:Connect(function(p)
    Characters[p] = nil
end)

-- ── Raycast params ────────────────────────────────────────
local rayParams = RaycastParams.new()
rayParams.FilterType  = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- ── Target finder ─────────────────────────────────────────
local function getTarget()
    local vp     = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local parts  = getgenv().targetParts
    local valid  = getgenv().validTargets

    local bestEntry, bestPos, bestWeight = nil, nil, -math.huge

    for player, entry in pairs(Characters) do
        if not valid[player.Name] then continue end

        local targetPos
        for _, partName in ipairs(parts) do
            local p = entry.instance:FindFirstChild(partName)
            if p and p:IsA("BasePart") then
                targetPos = p.Position
                break
            end
        end
        if not targetPos then continue end

        local pos    = entry.root.Position
        local vPoint = Camera:WorldToViewportPoint(pos)
        if vPoint.Z < 0 then continue end

        if getgenv().wallCheck then
            rayParams.FilterDescendantsInstances = { entry.instance, LocalPlayer.Character }
            local hit = Workspace:Raycast(Camera.CFrame.Position, pos - Camera.CFrame.Position, rayParams)
            if hit then continue end
        end

        local screenDist = (Vector2.new(vPoint.X, vPoint.Y) - center).Magnitude
        if screenDist > getgenv().radius then continue end

        local w = 1000 - screenDist
        if w > bestWeight then
            bestWeight = w
            bestEntry  = entry
            bestPos    = targetPos
        end
    end

    return bestEntry, bestPos
end

-- ── FastCast.Fire hook ────────────────────────────────────
local oldFire = FastCast.Fire
FastCast.Fire = function(tbl, origin, direction, velocity, behaviour)
    if getgenv().aimbotEnabled then
        local entry, targetPos = getTarget()
        local roll = math.random(1, 100)

        if entry and targetPos and roll <= getgenv().hitChance then
            local newDir = (targetPos - origin).Unit * 1000
            direction    = newDir
            velocity     = newDir * 9e9
        end
    end
    return oldFire(tbl, origin, direction, velocity, behaviour)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera or Camera
end)

print("Silent Aim: Hook active — role-aware targeting enabled")
]],
    AimbotConfig.hitChance,
    tostring(AimbotConfig.wallCheck),
    partsStr,
    AimbotConfig.radius
    )
end

-- ============================================================
-- LOAD AIMBOT
-- ============================================================
local function checkFFlag(name, value)
    local ok, result = pcall(getfflag, name)
    if not ok then return false end
    if type(result) == "boolean" then return result end
    if type(result) == "string"  then return result == tostring(value) end
    return false
end

local aimbotCode = buildAimbotCode()

if AimbotActor and not checkFFlag("DebugRunParallelLuaOnMainThread", true) then
    print("Silent Aim: Running in actor thread")
    run(AimbotActor, aimbotCode)
else
    print("Silent Aim: Running on main thread")
    loadstring(aimbotCode)()
end

-- ============================================================
-- HITBOX EXPANDER
-- Resizes the chosen BasePart client-side so bullets register
-- on the larger collision surface. SelectionBox for visual debug.
-- ============================================================
local hitboxConfig = {
    enabled      = false,
    part         = "HumanoidRootPart",
    size         = 5,
    transparency = 0,
    keybind      = Enum.KeyCode.L,
}

local hitboxObjects = {}  -- [player] = { part, originalSize, box }

local function cleanupHitboxFull(player)
    local obj = hitboxObjects[player]
    if not obj then return end
    pcall(function()
        if obj.part and obj.part.Parent then
            obj.part.Size                       = obj.originalSize
            obj.part.LocalTransparencyModifier  = obj.originalTransparency
        end
    end)
    hitboxObjects[player] = nil
end

local function applyHitbox(player)
    cleanupHitboxFull(player)
    if not hitboxConfig.enabled then return end
    if not isValidTarget(player) then return end

    local char = getCharacter(player)
    if not char then return end

    local target = char:FindFirstChild(hitboxConfig.part)
    if not target or not target:IsA("BasePart") then return end

    local originalSize         = target.Size
    local originalTransparency = target.LocalTransparencyModifier

    target.Size = Vector3.new(
        originalSize.X + hitboxConfig.size,
        originalSize.Y + hitboxConfig.size,
        originalSize.Z + hitboxConfig.size
    )
    target.LocalTransparencyModifier = hitboxConfig.transparency

    hitboxObjects[player] = {
        part                = target,
        originalSize        = originalSize,
        originalTransparency = originalTransparency,
    }
end

local function enableAllHitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then applyHitbox(p) end
    end
end

local function disableAllHitboxes()
    for player in pairs(hitboxObjects) do cleanupHitboxFull(player) end
end

local function refreshHitboxes()
    disableAllHitboxes()
    if hitboxConfig.enabled then enableAllHitboxes() end
end

-- Continuous sync loop — re-evaluates team check every 0.5s
-- so hitboxes are added/removed automatically as roles change mid-round
task.spawn(function()
    while true do
        task.wait(0.5)
        if hitboxConfig.enabled then
            -- Re-apply all: cleanups wrong targets, adds new valid ones
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp then
                    local isValid   = isValidTarget(p)
                    local hasHitbox = hitboxObjects[p] ~= nil

                    if isValid and not hasHitbox then
                        applyHitbox(p)
                    elseif not isValid and hasHitbox then
                        cleanupHitboxFull(p)
                    end
                end
            end
        end
    end
end)

-- Keybind
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == hitboxConfig.keybind then
        hitboxConfig.enabled = not hitboxConfig.enabled
        refreshHitboxes()
    end
end)

-- Hook new characters
Players.PlayerAdded:Connect(function(p)
    if p == lp then return end
    p.CharacterAdded:Connect(function()
        task.wait(0.3)
        if hitboxConfig.enabled then applyHitbox(p) end
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= lp then
        p.CharacterAdded:Connect(function()
            task.wait(0.3)
            if hitboxConfig.enabled then applyHitbox(p) end
        end)
    end
end

-- Hitbox Tab UI
HitboxTab:CreateToggle({
    Name         = "Enable Hitbox Expander",
    CurrentValue = cfgGet("HitboxEnabled", false),
    Flag         = "HitboxEnabled",
    Callback     = function(val)
        cfgSet("HitboxEnabled", val)
        if _cfgApplying then return end
        hitboxConfig.enabled = val
        refreshHitboxes()
    end,
})

HitboxTab:CreateDropdown({
    Name          = "Target Part",
    Options       = {"HumanoidRootPart", "Torso", "Head", "Neckshot"},
    CurrentOption = {cfgGet("HitboxPart", "HumanoidRootPart")},
    Flag          = "HitboxPart",
    Callback      = function(opt)
        cfgSet("HitboxPart", type(opt) == "table" and opt[1] or opt)
        if _cfgApplying then return end
        hitboxConfig.part = type(opt) == "table" and opt[1] or opt
        refreshHitboxes()
    end,
})

HitboxTab:CreateSlider({
    Name         = "Expand Size",
    Range        = {1, 10},
    Increment    = 1,
    CurrentValue = cfgGet("HitboxSize", 5),
    Flag         = "HitboxSize",
    Callback     = function(val)
        cfgSet("HitboxSize", val)
        if _cfgApplying then return end
        hitboxConfig.size = val
        refreshHitboxes()
    end,
})

HitboxTab:CreateSlider({
    Name         = "Part Transparency",
    Range        = {0, 100},
    Increment    = 1,
    Suffix       = "%",
    CurrentValue = cfgGet("HitboxTransparency", 0),
    Flag         = "HitboxTransparency",
    Callback     = function(val)
        cfgSet("HitboxTransparency", val)
        if _cfgApplying then return end
        hitboxConfig.transparency = val / 100
        refreshHitboxes()
    end,
})

-- Keybind is hardcoded to L — toggled via UserInputService

-- ============================================================
-- AUTO AIM TAB
-- Lightweight camera-snap aimbot — no FastCast hook needed
-- Works on weak executors. Mobile: floating button. PC: Q key
-- ============================================================
local AutoAimConfig = {
    enabled    = false,
    fov        = 200,
    part       = "Torso",
    smoothness = 0.35,
}

-- Floating mobile button (ScreenGui in CoreGui)
local autoAimGui    = Instance.new("ScreenGui")
autoAimGui.Name     = "AutoAimBtn"
autoAimGui.ResetOnSpawn = false
autoAimGui.Parent   = CoreGui

local autoAimBtn         = Instance.new("TextButton")
autoAimBtn.Size          = UDim2.fromOffset(70, 70)
autoAimBtn.Position      = UDim2.new(0.1, 0, 0.7, 0)
autoAimBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
autoAimBtn.BackgroundTransparency = 0.3
autoAimBtn.TextColor3    = Color3.new(1, 1, 1)
autoAimBtn.Text          = "AIM\nOFF"
autoAimBtn.TextScaled    = true
autoAimBtn.Font          = Enum.Font.GothamBold
autoAimBtn.Visible       = false   -- hidden until user clicks "Show Button"
autoAimBtn.Parent        = autoAimGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0.5, 0)
uiCorner.Parent = autoAimBtn

-- Drag support for the floating button
do
    local dragging, dragStart, startPos
    autoAimBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = autoAimBtn.Position
        end
    end)
    autoAimBtn.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            autoAimBtn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    autoAimBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function setAutoAim(val)
    AutoAimConfig.enabled = val
    autoAimBtn.Text = val and "AIM\nON" or "AIM\nOFF"
    autoAimBtn.BackgroundColor3 = val
        and Color3.fromRGB(220, 50, 50)
        or  Color3.fromRGB(30, 30, 30)
end

autoAimBtn.MouseButton1Click:Connect(function()
    setAutoAim(not AutoAimConfig.enabled)
end)

-- PC keybind: Q
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Q then
        setAutoAim(not AutoAimConfig.enabled)
    end
end)

-- Auto aim loop — snaps camera toward nearest valid target
local autoAimFovCircle     = Drawing.new("Circle")
autoAimFovCircle.Filled    = false
autoAimFovCircle.NumSides  = 60
autoAimFovCircle.Thickness = 1.5
autoAimFovCircle.Color     = Color3.fromRGB(255, 100, 100)

RunService.RenderStepped:Connect(function()
    local vp = Camera.ViewportSize
    autoAimFovCircle.Radius   = AutoAimConfig.fov
    autoAimFovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
    autoAimFovCircle.Visible  = AutoAimConfig.enabled

    if not AutoAimConfig.enabled then return end

    local center    = Vector2.new(vp.X / 2, vp.Y / 2)
    local bestPart, bestDist = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end
        if not isValidTarget(player) then continue end

        local char = getCharacter(player)
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local part = char:FindFirstChild(AutoAimConfig.part)
        if not part then continue end

        local vPoint = Camera:WorldToViewportPoint(part.Position)
        if vPoint.Z < 0 then continue end

        local screenPos  = Vector2.new(vPoint.X, vPoint.Y)
        local screenDist = (screenPos - center).Magnitude
        if screenDist > AutoAimConfig.fov then continue end

        if screenDist < bestDist then
            bestDist = screenDist
            bestPart = part
        end
    end

    if bestPart then
        local targetCF = CFrame.new(Camera.CFrame.Position, bestPart.Position)
        Camera.CFrame = Camera.CFrame:Lerp(targetCF, AutoAimConfig.smoothness)
    end
end)

-- Auto Aim Tab UI
AutoAimTab:CreateToggle({
    Name         = "Show Mobile Button",
    CurrentValue = cfgGet("AutoAimBtnVisible", false),
    Flag         = "AutoAimBtnVisible",
    Callback     = function(val)
        cfgSet("AutoAimBtnVisible", val)
        if _cfgApplying then return end
        autoAimBtn.Visible = val
    end,
})

AutoAimTab:CreateSlider({
    Name         = "FOV Radius",
    Range        = {50, 800},
    Increment    = 10,
    CurrentValue = cfgGet("AutoAimFOV", 200),
    Flag         = "AutoAimFOV",
    Callback     = function(val)
        cfgSet("AutoAimFOV", val)
        if _cfgApplying then return end
        AutoAimConfig.fov = val
    end,
})

AutoAimTab:CreateSlider({
    Name         = "Smoothness",
    Range        = {1, 100},
    Increment    = 1,
    Suffix       = "%",
    CurrentValue = cfgGet("AutoAimSmoothness", 35),
    Flag         = "AutoAimSmoothness",
    Callback     = function(val)
        cfgSet("AutoAimSmoothness", val)
        if _cfgApplying then return end
        AutoAimConfig.smoothness = val / 100
    end,
})

AutoAimTab:CreateDropdown({
    Name          = "Target Part",
    Options       = {"Head", "Torso", "Neckshot", "HumanoidRootPart"},
    CurrentOption = {cfgGet("AutoAimPart", "Torso")},
    Flag          = "AutoAimPart",
    Callback      = function(opt)
        cfgSet("AutoAimPart", type(opt) == "table" and opt[1] or opt)
        if _cfgApplying then return end
        AutoAimConfig.part = type(opt) == "table" and opt[1] or opt
    end,
})

-- ============================================================
-- MISC TAB
-- ============================================================
local proxConns = {}

local function patchPrompt(pp)
    if pp:IsA("ProximityPrompt") then
        pp.HoldDuration = 0
    end
end

local function enableNoProx()
    for _, v in ipairs(Workspace:GetDescendants()) do
        patchPrompt(v)
    end
    proxConns[#proxConns+1] = Workspace.DescendantAdded:Connect(function(v)
        patchPrompt(v)
    end)
end

local function disableNoProx()
    for _, c in ipairs(proxConns) do c:Disconnect() end
    proxConns = {}
end

MiscTab:CreateToggle({
    Name         = "Instant Proximity Prompts",
    CurrentValue = cfgGet("NoProxPrompt", false),
    Flag         = "NoProxPrompt",
    Callback     = function(val)
        cfgSet("NoProxPrompt", val)
        if _cfgApplying then return end
        if val then enableNoProx() else disableNoProx() end
    end,
})

-- ============================================================
-- INFINITE AMMO
-- Scans ReplicatedStorage.SPH_Assets.WeaponModels for gun names
-- Then watches Backpack for those guns and maxes their ammo values
-- Path: Backpack → [GunName] → Ammo → "Arcade Ammo Pool" / MagAmmo
-- ============================================================
local INF_AMMO    = 999999
local ammoEnabled = false
local ammoConns   = {}  -- connections to disconnect on disable

-- Build weapon name lookup from WeaponModels folder
local weaponNames = {}
local weaponModels = ReplicatedStorage:FindFirstChild("SPH_Assets")
    and ReplicatedStorage.SPH_Assets:FindFirstChild("WeaponModels")

if weaponModels then
    for _, model in ipairs(weaponModels:GetChildren()) do
        weaponNames[model.Name] = true
    end
end

local function patchAmmo(tool)
    if not weaponNames[tool.Name] then return end

    local ammoFolder = tool:FindFirstChild("Ammo")
    if not ammoFolder then return end

    local arcadePool  = ammoFolder:FindFirstChild("ArcadeAmmoPool")
    local infiniteAmmo = ammoFolder:FindFirstChild("InfiniteAmmo")
    local magAmmo     = ammoFolder:FindFirstChild("MagAmmo")

    local function maxAll()
        if arcadePool then
            pcall(function() arcadePool.MaxValue = INF_AMMO end)
            arcadePool.Value = INF_AMMO
        end
        if infiniteAmmo then
            infiniteAmmo.Value = true
        end
        if magAmmo then
            pcall(function() magAmmo.MaxValue = INF_AMMO end)
            magAmmo.Value = INF_AMMO
        end
    end

    maxAll()

    if arcadePool then
        local c = arcadePool.Changed:Connect(function()
            if ammoEnabled and arcadePool.Value < INF_AMMO then
                arcadePool.Value = INF_AMMO
            end
        end)
        ammoConns[#ammoConns+1] = c
    end

    if infiniteAmmo then
        local c = infiniteAmmo.Changed:Connect(function()
            if ammoEnabled and infiniteAmmo.Value == false then
                infiniteAmmo.Value = true
            end
        end)
        ammoConns[#ammoConns+1] = c
    end

    if magAmmo then
        local c = magAmmo.Changed:Connect(function()
            if ammoEnabled and magAmmo.Value < INF_AMMO then
                magAmmo.Value = INF_AMMO
            end
        end)
        ammoConns[#ammoConns+1] = c
    end
end

local function enableInfAmmo()
    -- Patch any guns already in backpack
    local bp = lp:FindFirstChildOfClass("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            patchAmmo(tool)
        end
    end
    -- Patch equipped gun (in character)
    local char = lp.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then patchAmmo(tool) end
        end
    end

    -- Watch for guns being picked up / swapped into backpack
    ammoConns[#ammoConns+1] = lp.Backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.1)  -- let Ammo folder load
            patchAmmo(child)
        end
    end)

    -- Watch for gun being equipped into character
    local function watchChar(character)
        ammoConns[#ammoConns+1] = character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                task.wait(0.1)
                patchAmmo(child)
            end
        end)
    end

    if lp.Character then watchChar(lp.Character) end
    ammoConns[#ammoConns+1] = lp.CharacterAdded:Connect(function(char)
        task.wait(0.3)
        watchChar(char)
        -- Patch any already-held gun after respawn
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then patchAmmo(tool) end
        end
    end)
end

local function disableInfAmmo()
    for _, c in ipairs(ammoConns) do c:Disconnect() end
    ammoConns = {}
end

MiscTab:CreateToggle({
    Name         = "Infinite Ammo",
    CurrentValue = cfgGet("InfAmmo", false),
    Flag         = "InfAmmo",
    Callback     = function(val)
        cfgSet("InfAmmo", val)
        if _cfgApplying then return end
        ammoEnabled = val
        if val then enableInfAmmo() else disableInfAmmo() end
    end,
})

-- ============================================================
-- SPEED BOOST
-- Applies a multiplier on top of whatever WalkSpeed the game sets.
-- Tracks the game's intended speed each frame so running/crouching
-- still scales correctly (e.g. base 16 * 2x = 32, run 20 * 2x = 40).
-- ============================================================
local speedConfig = {
    enabled    = false,
    multiplier = 1.0,
}

local _lastSetSpeed  = nil   -- the speed WE last wrote
local _speedConn     = nil

local function getHumanoid()
    local char = lp.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function applySpeed(hum)
    if not hum then return end
    local current = hum.WalkSpeed
    -- If the speed is one we set, use our stored base instead
    -- so we don't compound-multiply on our own value
    local base
    if _lastSetSpeed and math.abs(current - _lastSetSpeed) < 0.01 then
        base = _lastSetSpeed / speedConfig.multiplier
    else
        base = current  -- game changed the speed (run, crouch etc)
    end

    local newSpeed = base * speedConfig.multiplier
    _lastSetSpeed = newSpeed
    hum.WalkSpeed = newSpeed
end

local function hookSpeedChar(character)
    local hum = character:WaitForChild("Humanoid", 5)
    if not hum then return end

    _lastSetSpeed = nil
    applySpeed(hum)

    -- Watch for game-driven speed changes (running, crouching, etc.)
    if _speedConn then _speedConn:Disconnect() end
    _speedConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not speedConfig.enabled then return end
        -- Only re-apply if the game changed it (not us)
        if _lastSetSpeed and math.abs(hum.WalkSpeed - _lastSetSpeed) < 0.01 then return end
        applySpeed(hum)
    end)
end

local function enableSpeed()
    local char = lp.Character
    if char then
        task.spawn(hookSpeedChar, char)
    end
end

local function disableSpeed()
    if _speedConn then _speedConn:Disconnect(); _speedConn = nil end
    local hum = getHumanoid()
    if hum and _lastSetSpeed then
        -- Restore base speed by reversing our last multiplier
        hum.WalkSpeed = _lastSetSpeed / speedConfig.multiplier
    end
    _lastSetSpeed = nil
end

-- Re-hook on respawn
lp.CharacterAdded:Connect(function(char)
    if speedConfig.enabled then
        task.wait(0.3)
        hookSpeedChar(char)
    end
end)

MiscTab:CreateToggle({
    Name         = "Speed Boost",
    CurrentValue = cfgGet("SpeedEnabled", false),
    Flag         = "SpeedEnabled",
    Callback     = function(val)
        cfgSet("SpeedEnabled", val)
        if _cfgApplying then return end
        speedConfig.enabled = val
        if val then enableSpeed() else disableSpeed() end
    end,
})

MiscTab:CreateSlider({
    Name         = "Speed Multiplier",
    Range        = {100, 120},
    Increment    = 1,
    Suffix       = "%",
    CurrentValue = cfgGet("SpeedMultiplier", 100),
    Flag         = "SpeedMultiplier",
    Callback     = function(val)
        cfgSet("SpeedMultiplier", val)
        if _cfgApplying then return end
        local old = speedConfig.multiplier
        speedConfig.multiplier = val / 100
        if speedConfig.enabled then
            local hum = getHumanoid()
            if hum and _lastSetSpeed then
                -- Rebase from old multiplier then apply new one
                local base = _lastSetSpeed / old
                local newSpeed = base * speedConfig.multiplier
                _lastSetSpeed = newSpeed
                hum.WalkSpeed = newSpeed
            end
        end
    end,
})

-- ============================================================
-- DELAYED CONFIG APPLY (1 second after load)
-- Applies all saved-on features once the game is ready
-- ============================================================
task.delay(1, function()
    _cfgApplying = false

    -- ESP
    if cfgGet("GunESPEnabled", false) then
        espEnabled = true
        enableAllESP()
    end

    -- Silent Aim actor config
    local savedParts = cfgGet("TargetParts", {"Torso"})
    AimbotConfig.targetParts = type(savedParts) == "table" and savedParts or {"Torso"}
    AimbotConfig.hitChance   = cfgGet("HitChance", 100)
    AimbotConfig.wallCheck   = cfgGet("WallCheck", false)
    AimbotConfig.radius      = cfgGet("FOVRadius", 150)
    AimbotConfig.fovVisible  = cfgGet("FOVVisible", true)
    targetGroup              = cfgGet("TargetGroup", "All")

    if AimbotActor then
        run(AimbotActor, ("getgenv().hitChance = %d"):format(AimbotConfig.hitChance))
        run(AimbotActor, ("getgenv().wallCheck = %s"):format(tostring(AimbotConfig.wallCheck)))
        run(AimbotActor, ("getgenv().radius = %d"):format(AimbotConfig.radius))
    else
        getgenv().hitChance = AimbotConfig.hitChance
        getgenv().wallCheck = AimbotConfig.wallCheck
        getgenv().radius    = AimbotConfig.radius
    end

    if cfgGet("AimbotEnabled", false) then
        AimbotConfig.enabled = true
        if AimbotActor then
            run(AimbotActor, "getgenv().aimbotEnabled = true")
        else
            getgenv().aimbotEnabled = true
        end
    end

    -- Hitbox
    hitboxConfig.part         = cfgGet("HitboxPart", "HumanoidRootPart")
    hitboxConfig.size         = cfgGet("HitboxSize", 5)
    hitboxConfig.transparency = cfgGet("HitboxTransparency", 0) / 100
    if cfgGet("HitboxEnabled", false) then
        hitboxConfig.enabled = true
        refreshHitboxes()
    end

    -- Auto Aim
    AutoAimConfig.fov        = cfgGet("AutoAimFOV", 200)
    AutoAimConfig.smoothness = cfgGet("AutoAimSmoothness", 35) / 100
    AutoAimConfig.part       = cfgGet("AutoAimPart", "Torso")
    if cfgGet("AutoAimBtnVisible", false) then
        autoAimBtn.Visible = true
    end

    -- Misc
    if cfgGet("NoProxPrompt", false) then enableNoProx() end
    if cfgGet("InfAmmo", false) then
        ammoEnabled = true
        enableInfAmmo()
    end
    if cfgGet("SpeedEnabled", false) then
        speedConfig.enabled    = true
        speedConfig.multiplier = cfgGet("SpeedMultiplier", 100) / 100
        enableSpeed()
    end
end)
