-- language: Lua, file: LvHub_SK.lua, target: Roblox executor, game: Secret Killer
-- WindUI dependent. 1-frame gun grab, HRP-locked instant shoot.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")

-- =========================
-- WINDUI LOAD
-- =========================
local WindUI = nil
local loadSuccess, loadError = nil, nil

local urls = {
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua"
}

for _, url in ipairs(urls) do
    local ok, result = pcall(function()
        local src = game:HttpGet(url)
        return loadstring(src)()
    end)
    if ok and result and type(result) == "table" then
        WindUI = result
        loadSuccess = true
        break
    end
    loadError = result and tostring(result) or "unknown error"
    task.wait(0.5)
end

if not WindUI then
    local errGui = Instance.new("ScreenGui")
    errGui.Name = "LvHub_Error"
    errGui.ResetOnSpawn = false
    errGui.Parent = game.CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 120)
    frame.Position = UDim2.new(0.5, -175, 0.5, -60)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.Parent = errGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 60, 60)
    stroke.Thickness = 2
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 80, 80)
    title.Text = "LvHub — WindUI Failed to Load"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, -20, 0, 60)
    msg.Position = UDim2.new(0, 10, 0, 40)
    msg.BackgroundTransparency = 1
    msg.TextColor3 = Color3.fromRGB(180, 180, 190)
    msg.Text = "Error: " .. (loadError or "could not fetch WindUI") .. "\nCheck: executor has HTTP enabled, or update executor."
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 12
    msg.TextWrapped = true
    msg.TextXAlignment = Enum.TextXAlignment.Left
    msg.TextYAlignment = Enum.TextYAlignment.Top
    msg.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 80, 0, 24)
    closeBtn.Position = UDim2.new(1, -90, 1, -32)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Text = "Close"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = frame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() errGui:Destroy() end)

    return
end

task.wait(0.3)

local isAnonymous = true

local Window = WindUI:CreateWindow({
    Title = "Lv Hub | SK",
    Author = "by lv — VANTA refit",
    Icon = "squircle",
    Size = UDim2.fromOffset(520, 460),
    Theme = "Midnight",
    Folder = "LvHubConfig",
    User = {
        Enabled = true,
        Anonymous = isAnonymous,
        Callback = function()
            isAnonymous = not isAnonymous
            Window.Icon:SetAnonymous(isAnonymous)
        end,
    }
})

Window:EditOpenButton({
    Title = "LvHub",
    Icon = "app-window",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromHex("006EFF"), Color3.fromHex("060A4A")),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})

local MainTab = Window:Tab({ Title = "Main", Icon = "home" })
local PlayerTab = Window:Tab({ Title = "Player", Icon = "user" })

WindUI:Notify({
    Title = "Welcome To Lv Hub",
    Content = "Secret Killer — VANTA refit",
    Duration = 6
})

-- =========================
-- VARIABLES
-- =========================
local ESPEnabled = false
local AutoGun = false
local ShootMode = false
local AutoShoot = false
local AutoDetect = false
local AutoRespawn = false
local AntiAfk = false
local InfJump = false
local Noclip = false
local POPUP_DURATION = 6
local currentBlur = nil
local lastMonster = nil
local lastSheriff = nil
local isGrabbing = false

-- =========================
-- UTILITY FUNCTIONS
-- =========================
local function getGunPart()
    local holder = workspace:FindFirstChild("GunPickupHolder")
    if holder then
        local gun = holder:FindFirstChild("GunPickup")
        if gun then
            return gun:FindFirstChild("Part")
        end
    end
    return nil
end

local function hasItem(player, name)
    return player.Backpack:FindFirstChild(name)
        or (player.Character and player.Character:FindFirstChild(name))
end

local function getPlayerWithItem(itemName)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if hasItem(plr, itemName) then
                return plr
            end
        end
    end
    return nil
end

local function localPlayerHasGun()
    return LocalPlayer.Backpack:FindFirstChild("Gun")
        or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun"))
end

local function equipGun()
    if not LocalPlayer.Character then return nil end
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then return nil end
    local gunInChar = LocalPlayer.Character:FindFirstChild("Gun")
    if gunInChar then return gunInChar end
    local gunInBag = LocalPlayer.Backpack:FindFirstChild("Gun")
    if gunInBag then
        humanoid:EquipTool(gunInBag)
        task.wait()
        return LocalPlayer.Character:FindFirstChild("Gun")
    end
    return nil
end

-- 0.005s teleport grab: 1-frame hold for server Touched register
local function teleportGrabGun()
    if isGrabbing then return false end
    if localPlayerHasGun() then return true end

    local gunPart = getGunPart()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not gunPart or not hrp then return false end

    isGrabbing = true
    local oldPos = hrp.CFrame

    -- teleport to gun
    hrp.CFrame = gunPart.CFrame

    -- hold 0.005 seconds (1 frame) for server to register the pickup
    task.wait(0.005)

    -- restore original position
    if hrp and hrp.Parent then
        hrp.CFrame = oldPos
    end

    isGrabbing = false
    return localPlayerHasGun()
end

-- =========================
-- ESP SYSTEM
-- =========================
local function getRole(player)
    if hasItem(player, "Monster") then return "MONSTER", Color3.new(1, 0, 0), Color3.fromRGB(255, 100, 100) end
    if hasItem(player, "Gun") then return "SHERIFF", Color3.new(0, 0.3, 1), Color3.fromRGB(100, 100, 255) end
    return "INNOCENT", Color3.new(0, 1, 0), Color3.fromRGB(100, 255, 100)
end

local function ensureBillboard(character)
    local head = character:FindFirstChild("Head")
    if not head then return nil end

    local bb = head:FindFirstChild("LvBillboard")
    if not bb then
        bb = Instance.new("BillboardGui")
        bb.Name = "LvBillboard"
        bb.Adornee = head
        bb.Size = UDim2.new(0, 200, 0, 50)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = head

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, 0, 0, 20)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 14
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextXAlignment = Enum.TextXAlignment.Center
        nameLabel.Parent = bb

        local distLabel = Instance.new("TextLabel")
        distLabel.Name = "DistLabel"
        distLabel.Size = UDim2.new(1, 0, 0, 16)
        distLabel.Position = UDim2.new(0, 0, 0, 22)
        distLabel.BackgroundTransparency = 1
        distLabel.Font = Enum.Font.Gotham
        distLabel.TextSize = 12
        distLabel.TextStrokeTransparency = 0
        distLabel.TextXAlignment = Enum.TextXAlignment.Center
        distLabel.Parent = bb
    end
    return bb
end

local function analyze(player)
    if not player or not player.Character then return end

    local character = player.Character
    local role, fillColor, outlineColor = getRole(player)

    local highlight = character:FindFirstChild("LvHighlight") or Instance.new("Highlight")
    highlight.Name = "LvHighlight"
    highlight.Parent = character
    highlight.Adornee = character
    highlight.Enabled = ESPEnabled
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.FillColor = fillColor
    highlight.OutlineColor = outlineColor

    local bb = ensureBillboard(character)
    if bb then
        bb.Enabled = ESPEnabled
        local nameLabel = bb:FindFirstChild("NameLabel")
        local distLabel = bb:FindFirstChild("DistLabel")

        if nameLabel then
            nameLabel.Text = player.DisplayName .. " [" .. role .. "]"
            nameLabel.TextColor3 = fillColor
        end

        if distLabel then
            local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local theirHrp = character:FindFirstChild("HumanoidRootPart")
            if myHrp and theirHrp then
                local dist = math.floor((myHrp.Position - theirHrp.Position).Magnitude)
                distLabel.Text = tostring(dist) .. " studs"
                distLabel.TextColor3 = outlineColor
            else
                distLabel.Text = "-- studs"
            end
        end
    end
end

local function clearESP(player)
    if not player then return end
    local char = player.Character
    if not char then return end
    local h = char:FindFirstChild("LvHighlight")
    if h then h.Enabled = false end
    local head = char:FindFirstChild("Head")
    local bb = head and head:FindFirstChild("LvBillboard")
    if bb then bb.Enabled = false end
end

local function hookPlayer(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if ESPEnabled then
            analyze(player)
        end
    end)
end

for _, plr in pairs(Players:GetPlayers()) do
    hookPlayer(plr)
end
Players.PlayerAdded:Connect(hookPlayer)

task.spawn(function()
    while true do
        if ESPEnabled then
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    analyze(plr)
                end
            end
        else
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    clearESP(plr)
                end
            end
        end
        task.wait(0.3)
    end
end)

MainTab:Toggle({
    Title = "ESP Monster & Sheriff",
    Value = false,
    Callback = function(v)
        ESPEnabled = v
    end
})

-- =========================
-- POPUP SYSTEM
-- =========================
local function cleanupPopup()
    local old = game.CoreGui:FindFirstChild("LvHub_DetectPopup")
    if old then old:Destroy() end
    if currentBlur and currentBlur.Parent then
        currentBlur:Destroy()
    end
    currentBlur = nil
end

local function createBlur()
    cleanupPopup()
    currentBlur = Instance.new("BlurEffect")
    currentBlur.Size = 0
    currentBlur.Parent = Lighting
    return currentBlur
end

local function createSinglePlayerPopup(player, roleType)
    local blurEffect = createBlur()

    local isMonster = roleType == "Monster"
    local accentColor = isMonster and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(60, 120, 255)
    local darkAccent = isMonster and Color3.fromRGB(80, 15, 15) or Color3.fromRGB(15, 30, 80)
    local emoji = isMonster and "👹" or "👮"
    local roleText = isMonster and "MONSTER" or "SHERIFF"

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LvHub_DetectPopup"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game.CoreGui
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, 160)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = accentColor
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 4)
    topBar.BackgroundColor3 = accentColor
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 16)

    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, -20, 0, 32)
    headerFrame.Position = UDim2.new(0, 10, 0, 14)
    headerFrame.BackgroundTransparency = 1
    headerFrame.Parent = mainFrame

    local headerIcon = Instance.new("TextLabel")
    headerIcon.Size = UDim2.new(0, 32, 0, 32)
    headerIcon.BackgroundTransparency = 1
    headerIcon.Text = emoji
    headerIcon.TextSize = 22
    headerIcon.Parent = headerFrame

    local headerLabel = Instance.new("TextLabel")
    headerLabel.Size = UDim2.new(1, -40, 0, 16)
    headerLabel.Position = UDim2.new(0, 36, 0, 0)
    headerLabel.BackgroundTransparency = 1
    headerLabel.TextColor3 = accentColor
    headerLabel.Text = roleText .. " DETECTED!"
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextSize = 15
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.Parent = headerFrame

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, -40, 0, 14)
    subLabel.Position = UDim2.new(0, 36, 0, 17)
    subLabel.BackgroundTransparency = 1
    subLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
    subLabel.Text = "Target identified"
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextSize = 11
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.Parent = headerFrame

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -20, 0, 1)
    divider.Position = UDim2.new(0, 10, 0, 50)
    divider.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    divider.Parent = mainFrame

    local cardFrame = Instance.new("Frame")
    cardFrame.Size = UDim2.new(1, -20, 0, 60)
    cardFrame.Position = UDim2.new(0, 10, 0, 58)
    cardFrame.BackgroundColor3 = darkAccent
    cardFrame.BorderSizePixel = 0
    cardFrame.Parent = mainFrame
    Instance.new("UICorner", cardFrame).CornerRadius = UDim.new(0, 10)

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = accentColor
    cardStroke.Transparency = 0.6
    cardStroke.Parent = cardFrame

    local picFrame = Instance.new("Frame")
    picFrame.Size = UDim2.new(0, 44, 0, 44)
    picFrame.Position = UDim2.new(0, 8, 0.5, -22)
    picFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    picFrame.Parent = cardFrame
    Instance.new("UICorner", picFrame).CornerRadius = UDim.new(1, 0)

    local profilePic = Instance.new("ImageLabel")
    profilePic.Size = UDim2.new(1, 0, 1, 0)
    profilePic.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    profilePic.Parent = picFrame
    Instance.new("UICorner", profilePic).CornerRadius = UDim.new(1, 0)

    task.spawn(function()
        local success, userId = pcall(function()
            return Players:GetUserIdFromNameAsync(player.Name)
        end)
        if success and userId then
            profilePic.Image = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end
    end)

    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Size = UDim2.new(0, 140, 0, 18)
    usernameLabel.Position = UDim2.new(0, 60, 0, 10)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.TextColor3 = Color3.new(1, 1, 1)
    usernameLabel.Text = player.DisplayName
    usernameLabel.Font = Enum.Font.GothamBold
    usernameLabel.TextSize = 14
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
    usernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    usernameLabel.Parent = cardFrame

    local atLabel = Instance.new("TextLabel")
    atLabel.Size = UDim2.new(0, 140, 0, 14)
    atLabel.Position = UDim2.new(0, 60, 0, 30)
    atLabel.BackgroundTransparency = 1
    atLabel.TextColor3 = Color3.fromRGB(130, 130, 140)
    atLabel.Text = "@" .. player.Name
    atLabel.Font = Enum.Font.Gotham
    atLabel.TextSize = 11
    atLabel.TextXAlignment = Enum.TextXAlignment.Left
    atLabel.TextTruncate = Enum.TextTruncate.AtEnd
    atLabel.Parent = cardFrame

    local badge = Instance.new("Frame")
    badge.Size = UDim2.new(0, 55, 0, 22)
    badge.Position = UDim2.new(1, -63, 0.5, -11)
    badge.BackgroundColor3 = accentColor
    badge.Parent = cardFrame
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)

    local badgeLabel = Instance.new("TextLabel")
    badgeLabel.Size = UDim2.new(1, 0, 1, 0)
    badgeLabel.BackgroundTransparency = 1
    badgeLabel.TextColor3 = Color3.new(1, 1, 1)
    badgeLabel.Text = emoji .. " " .. roleText
    badgeLabel.Font = Enum.Font.GothamBold
    badgeLabel.TextSize = 10
    badgeLabel.Parent = badge

    local bottomLabel = Instance.new("TextLabel")
    bottomLabel.Size = UDim2.new(1, -20, 0, 16)
    bottomLabel.Position = UDim2.new(0, 10, 1, -22)
    bottomLabel.BackgroundTransparency = 1
    bottomLabel.TextColor3 = Color3.fromRGB(80, 80, 90)
    bottomLabel.Text = "ESP aktif " .. POPUP_DURATION .. " detik"
    bottomLabel.Font = Enum.Font.Gotham
    bottomLabel.TextSize = 10
    bottomLabel.Parent = mainFrame

    if player.Character then
        local oldH = player.Character:FindFirstChild("LvTempDetectHighlight")
        if oldH then oldH:Destroy() end

        local highlight = Instance.new("Highlight")
        highlight.Name = "LvTempDetectHighlight"
        highlight.Parent = player.Character
        highlight.Adornee = player.Character
        highlight.FillColor = isMonster and Color3.new(1, 0, 0) or Color3.new(0, 0.3, 1)
        highlight.OutlineColor = accentColor
        highlight.FillTransparency = 0.3
        highlight.OutlineTransparency = 0

        task.delay(POPUP_DURATION, function()
            if highlight and highlight.Parent then
                TweenService:Create(highlight, TweenInfo.new(0.5), {
                    FillTransparency = 1,
                    OutlineTransparency = 1
                }):Play()
                task.delay(0.6, function()
                    if highlight.Parent then highlight:Destroy() end
                end)
            end
        end)
    end

    mainFrame.Size = UDim2.new(0, 280, 0, 0)
    mainFrame.BackgroundTransparency = 1

    TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 280, 0, 160),
        Position = UDim2.new(0.5, -140, 0.5, -80),
        BackgroundTransparency = 0
    }):Play()

    TweenService:Create(blurEffect, TweenInfo.new(0.3), { Size = 15 }):Play()

    task.delay(POPUP_DURATION, function()
        if screenGui and screenGui.Parent then
            TweenService:Create(blurEffect, TweenInfo.new(0.3), { Size = 0 }):Play()
            local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 280, 0, 0),
                Position = UDim2.new(0.5, -140, 0.5, 0),
                BackgroundTransparency = 1
            })
            closeTween:Play()
            closeTween.Completed:Connect(function()
                if screenGui.Parent then screenGui:Destroy() end
                if blurEffect and blurEffect.Parent then blurEffect:Destroy() end
            end)
        end
    end)
end

local function createDualPlayerPopup(monsterPlayer, copPlayer)
    local blurEffect = createBlur()

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LvHub_DetectPopup"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game.CoreGui
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local totalPlayers = (monsterPlayer and 1 or 0) + (copPlayer and 1 or 0)
    local popupHeight = 70 + (totalPlayers * 70) + 20

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, popupHeight)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(150, 80, 255)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 4)
    topBar.BackgroundColor3 = Color3.fromRGB(150, 80, 255)
    topBar.Parent = mainFrame
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 16)

    local headerLabel = Instance.new("TextLabel")
    headerLabel.Size = UDim2.new(1, 0, 0, 36)
    headerLabel.Position = UDim2.new(0, 0, 0, 12)
    headerLabel.BackgroundTransparency = 1
    headerLabel.TextColor3 = Color3.fromRGB(180, 130, 255)
    headerLabel.Text = "🎯 ALL ROLES DETECTED (" .. totalPlayers .. ")"
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextSize = 14
    headerLabel.Parent = mainFrame

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -20, 0, 1)
    divider.Position = UDim2.new(0, 10, 0, 50)
    divider.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    divider.Parent = mainFrame

    local yOffset = 56

    local function createCard(player, roleType, yPos)
        local isMonster = roleType == "Monster"
        local accentColor = isMonster and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(60, 120, 255)
        local darkAccent = isMonster and Color3.fromRGB(60, 15, 15) or Color3.fromRGB(15, 25, 60)
        local emoji = isMonster and "👹" or "👮"
        local roleText = isMonster and "MONSTER" or "SHERIFF"

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -20, 0, 58)
        card.Position = UDim2.new(0, 10, 0, yPos)
        card.BackgroundColor3 = darkAccent
        card.Parent = mainFrame
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = accentColor
        cardStroke.Transparency = 0.6
        cardStroke.Parent = card

        local picFrame = Instance.new("Frame")
        picFrame.Size = UDim2.new(0, 42, 0, 42)
        picFrame.Position = UDim2.new(0, 8, 0.5, -21)
        picFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        picFrame.Parent = card
        Instance.new("UICorner", picFrame).CornerRadius = UDim.new(1, 0)

        local profilePic = Instance.new("ImageLabel")
        profilePic.Size = UDim2.new(1, 0, 1, 0)
        profilePic.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        profilePic.Parent = picFrame
        Instance.new("UICorner", profilePic).CornerRadius = UDim.new(1, 0)

        task.spawn(function()
            local success, userId = pcall(function()
                return Players:GetUserIdFromNameAsync(player.Name)
            end)
            if success and userId then
                profilePic.Image = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end
        end)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 130, 0, 18)
        nameLabel.Position = UDim2.new(0, 58, 0, 8)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Text = player.DisplayName
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 13
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card

        local atLabel = Instance.new("TextLabel")
        atLabel.Size = UDim2.new(0, 130, 0, 12)
        atLabel.Position = UDim2.new(0, 58, 0, 28)
        atLabel.BackgroundTransparency = 1
        atLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
        atLabel.Text = "@" .. player.Name
        atLabel.Font = Enum.Font.Gotham
        atLabel.TextSize = 10
        atLabel.TextXAlignment = Enum.TextXAlignment.Left
        atLabel.TextTruncate = Enum.TextTruncate.AtEnd
        atLabel.Parent = card

        local badge = Instance.new("Frame")
        badge.Size = UDim2.new(0, 60, 0, 20)
        badge.Position = UDim2.new(1, -68, 0.5, -10)
        badge.BackgroundColor3 = accentColor
        badge.Parent = card
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)

        local badgeLabel = Instance.new("TextLabel")
        badgeLabel.Size = UDim2.new(1, 0, 1, 0)
        badgeLabel.BackgroundTransparency = 1
        badgeLabel.TextColor3 = Color3.new(1, 1, 1)
        badgeLabel.Text = emoji .. " " .. roleText
        badgeLabel.Font = Enum.Font.GothamBold
        badgeLabel.TextSize = 9
        badgeLabel.Parent = badge

        if player.Character then
            local oldH = player.Character:FindFirstChild("LvTempDetectHighlight")
            if oldH then oldH:Destroy() end

            local highlight = Instance.new("Highlight")
            highlight.Name = "LvTempDetectHighlight"
            highlight.Parent = player.Character
            highlight.Adornee = player.Character
            highlight.FillColor = isMonster and Color3.new(1, 0, 0) or Color3.new(0, 0.3, 1)
            highlight.OutlineColor = accentColor
            highlight.FillTransparency = 0.3
            highlight.OutlineTransparency = 0

            task.delay(POPUP_DURATION, function()
                if highlight and highlight.Parent then
                    TweenService:Create(highlight, TweenInfo.new(0.5), {
                        FillTransparency = 1,
                        OutlineTransparency = 1
                    }):Play()
                    task.delay(0.6, function()
                        if highlight.Parent then highlight:Destroy() end
                    end)
                end
            end)
        end
    end

    if monsterPlayer then
        createCard(monsterPlayer, "Monster", yOffset)
        yOffset = yOffset + 64
    end

    if copPlayer then
        createCard(copPlayer, "Cop", yOffset)
    end

    local bottomLabel = Instance.new("TextLabel")
    bottomLabel.Size = UDim2.new(1, -20, 0, 14)
    bottomLabel.Position = UDim2.new(0, 10, 1, -18)
    bottomLabel.BackgroundTransparency = 1
    bottomLabel.TextColor3 = Color3.fromRGB(80, 80, 90)
    bottomLabel.Text = "ESP aktif " .. POPUP_DURATION .. " detik"
    bottomLabel.Font = Enum.Font.Gotham
    bottomLabel.TextSize = 10
    bottomLabel.Parent = mainFrame

    mainFrame.Size = UDim2.new(0, 280, 0, 0)
    mainFrame.BackgroundTransparency = 1

    TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 280, 0, popupHeight),
        Position = UDim2.new(0.5, -140, 0.5, -popupHeight/2),
        BackgroundTransparency = 0
    }):Play()

    TweenService:Create(blurEffect, TweenInfo.new(0.3), { Size = 15 }):Play()

    task.delay(POPUP_DURATION, function()
        if screenGui and screenGui.Parent then
            TweenService:Create(blurEffect, TweenInfo.new(0.3), { Size = 0 }):Play()
            TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 280, 0, 0),
                Position = UDim2.new(0.5, -140, 0.5, 0),
                BackgroundTransparency = 1
            }):Play()
            task.delay(0.5, function()
                if screenGui.Parent then screenGui:Destroy() end
                if blurEffect and blurEffect.Parent then blurEffect:Destroy() end
            end)
        end
    end)
end

-- =========================
-- DETECT BUTTONS
-- =========================
MainTab:Button({
    Title = "🔍 Detect Monster",
    Callback = function()
        local monster = getPlayerWithItem("Monster")
        if not monster then
            WindUI:Notify({ Title = "Detection", Content = "Tidak ada Monster!", Duration = 3 })
        else
            createSinglePlayerPopup(monster, "Monster")
            WindUI:Notify({ Title = "Detection", Content = monster.DisplayName .. " adalah Monster!", Duration = 3 })
        end
    end
})

MainTab:Button({
    Title = "🔍 Detect Sheriff",
    Callback = function()
        local cop = getPlayerWithItem("Gun")
        if not cop then
            WindUI:Notify({ Title = "Detection", Content = "Tidak ada Sheriff!", Duration = 3 })
        else
            createSinglePlayerPopup(cop, "Cop")
            WindUI:Notify({ Title = "Detection", Content = cop.DisplayName .. " adalah Sheriff!", Duration = 3 })
        end
    end
})

MainTab:Button({
    Title = "🔍 Detect All Roles",
    Callback = function()
        local monster = getPlayerWithItem("Monster")
        local cop = getPlayerWithItem("Gun")

        if not monster and not cop then
            WindUI:Notify({ Title = "Detection", Content = "Tidak ada role ditemukan!", Duration = 3 })
        else
            createDualPlayerPopup(monster, cop)
            local msg = ""
            if monster then msg = "👹 " .. monster.DisplayName end
            if cop then msg = msg .. (msg ~= "" and " | " or "") .. "👮 " .. cop.DisplayName end
            WindUI:Notify({ Title = "Detection", Content = msg, Duration = 3 })
        end
    end
})

-- =========================
-- AUTO-DETECT
-- =========================
MainTab:Toggle({
    Title = "Auto Detect Roles",
    Value = false,
    Callback = function(v)
        AutoDetect = v
        lastMonster = nil
        lastSheriff = nil
    end
})

task.spawn(function()
    while true do
        if AutoDetect then
            local monster = getPlayerWithItem("Monster")
            local cop = getPlayerWithItem("Gun")

            if monster ~= lastMonster or cop ~= lastSheriff then
                if monster or cop then
                    createDualPlayerPopup(monster, cop)
                end
                lastMonster = monster
                lastSheriff = cop
            end
        end
        task.wait(1)
    end
end)

-- =========================
-- AUTO GET GUN — 0.005s teleport
-- =========================
task.spawn(function()
    while true do
        if AutoGun then
            if not localPlayerHasGun() and not isGrabbing then
                teleportGrabGun()
            end
        end
        task.wait(0.3)
    end
end)

MainTab:Toggle({
    Title = "Auto Get Gun",
    Value = false,
    Callback = function(v)
        AutoGun = v
    end
})

-- =========================
-- EMERGENCY GET GUN BUTTON
-- =========================
local emergencyGui = Instance.new("ScreenGui")
emergencyGui.Name = "LvHub_EmergencyBtn"
emergencyGui.ResetOnSpawn = false
emergencyGui.Parent = game.CoreGui

local eContainer = Instance.new("Frame")
eContainer.Size = UDim2.new(0, 180, 0, 60)
eContainer.Position = UDim2.new(0.5, -90, 0.8, 0)
eContainer.BackgroundTransparency = 1
eContainer.Parent = emergencyGui

local eGlow = Instance.new("ImageLabel")
eGlow.Size = UDim2.new(1, 30, 1, 30)
eGlow.Position = UDim2.new(0, -15, 0, -15)
eGlow.BackgroundTransparency = 1
eGlow.Image = "rbxassetid://7669168585"
eGlow.ImageColor3 = Color3.fromRGB(255, 50, 50)
eGlow.ImageTransparency = 0.5
eGlow.ScaleType = Enum.ScaleType.Slice
eGlow.SliceCenter = Rect.new(49, 49, 450, 450)
eGlow.Parent = eContainer

local eBtn = Instance.new("TextButton")
eBtn.Size = UDim2.new(1, 0, 1, 0)
eBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
eBtn.TextColor3 = Color3.new(1, 1, 1)
eBtn.Text = ""
eBtn.AutoButtonColor = false
eBtn.Visible = false
eBtn.Parent = eContainer
Instance.new("UICorner", eBtn).CornerRadius = UDim.new(0, 12)

local eStroke = Instance.new("UIStroke")
eStroke.Color = Color3.fromRGB(255, 100, 100)
eStroke.Thickness = 2
eStroke.Parent = eBtn

local eIcon = Instance.new("TextLabel")
eIcon.Size = UDim2.new(0, 24, 0, 24)
eIcon.Position = UDim2.new(0, 12, 0.5, -12)
eIcon.BackgroundTransparency = 1
eIcon.Text = "⚠️"
eIcon.TextSize = 18
eIcon.Parent = eBtn

local eLabel = Instance.new("TextLabel")
eLabel.Size = UDim2.new(1, -50, 0, 20)
eLabel.Position = UDim2.new(0, 42, 0.5, -10)
eLabel.BackgroundTransparency = 1
eLabel.TextColor3 = Color3.new(1, 1, 1)
eLabel.Text = "GET GUN!"
eLabel.Font = Enum.Font.GothamBold
eLabel.TextSize = 15
eLabel.TextXAlignment = Enum.TextXAlignment.Left
eLabel.Parent = eBtn

local eDragging, eDragInput, eDragStart, eStartPos
eContainer.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        eDragging = true
        eDragStart = input.Position
        eStartPos = eContainer.Position
    end
end)
eContainer.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        eDragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == eDragInput and eDragging then
        local delta = input.Position - eDragStart
        eContainer.Position = UDim2.new(eStartPos.X.Scale, eStartPos.X.Offset + delta.X, eStartPos.Y.Scale, eStartPos.Y.Offset + delta.Y)
    end
end)
eContainer.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        eDragging = false
    end
end)

eBtn.MouseButton1Click:Connect(function()
    teleportGrabGun()
end)

local ePulseRunning = false
local function runEPulse()
    if ePulseRunning then return end
    ePulseRunning = true
    task.spawn(function()
        while eBtn.Visible and ePulseRunning do
            local t1 = TweenService:Create(eGlow, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.2 })
            t1:Play()
            t1.Completed:Wait()
            if not eBtn.Visible then break end
            local t2 = TweenService:Create(eGlow, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.6 })
            t2:Play()
            t2.Completed:Wait()
        end
        ePulseRunning = false
    end)
end

local function monsterNearGun()
    local gunPart = getGunPart()
    if not gunPart then return false, nil end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hasMonster = plr.Backpack:FindFirstChild("Monster") or plr.Character:FindFirstChild("Monster")
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hasMonster and hrp then
                local distance = (hrp.Position - gunPart.Position).Magnitude
                if distance < 30 then return true, distance end
            end
        end
    end
    return false, nil
end

task.spawn(function()
    while true do
        local isNear = monsterNearGun()
        local wasVisible = eBtn.Visible
        eBtn.Visible = isNear
        if isNear and not wasVisible then
            runEPulse()
        end
        task.wait(0.3)
    end
end)

-- =========================
-- SHOOT MONSTER — HRP CAMLOCK
-- =========================
local shootButtonGui = Instance.new("ScreenGui")
shootButtonGui.Name = "LvHub_ShootMonsterBtn"
shootButtonGui.ResetOnSpawn = false
shootButtonGui.Parent = game.CoreGui

local shootContainer = Instance.new("Frame")
shootContainer.Size = UDim2.new(0, 170, 0, 55)
shootContainer.Position = UDim2.new(0.5, -85, 0.65, 0)
shootContainer.BackgroundTransparency = 1
shootContainer.Parent = shootButtonGui
shootContainer.Visible = false

local shootGlow = Instance.new("ImageLabel")
shootGlow.Size = UDim2.new(1, 25, 1, 25)
shootGlow.Position = UDim2.new(0, -12, 0, -12)
shootGlow.BackgroundTransparency = 1
shootGlow.Image = "rbxassetid://7669168585"
shootGlow.ImageColor3 = Color3.fromRGB(255, 120, 0)
shootGlow.ImageTransparency = 0.5
shootGlow.ScaleType = Enum.ScaleType.Slice
shootGlow.SliceCenter = Rect.new(49, 49, 450, 450)
shootGlow.Parent = shootContainer

local shootBg = Instance.new("Frame")
shootBg.Size = UDim2.new(1, 0, 1, 0)
shootBg.BackgroundColor3 = Color3.fromRGB(200, 80, 0)
shootBg.BorderSizePixel = 0
shootBg.Parent = shootContainer
Instance.new("UICorner", shootBg).CornerRadius = UDim.new(0, 14)

local shootBgStroke = Instance.new("UIStroke")
shootBgStroke.Color = Color3.fromRGB(255, 180, 50)
shootBgStroke.Thickness = 2
shootBgStroke.Parent = shootBg

local shootGradient = Instance.new("UIGradient")
shootGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 100, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 60, 0))
})
shootGradient.Rotation = 45
shootGradient.Parent = shootBg

local shootBtn = Instance.new("TextButton")
shootBtn.Size = UDim2.new(1, 0, 1, 0)
shootBtn.BackgroundTransparency = 1
shootBtn.Text = ""
shootBtn.AutoButtonColor = false
shootBtn.ZIndex = 10
shootBtn.Parent = shootContainer

local shootIcon = Instance.new("TextLabel")
shootIcon.Size = UDim2.new(0, 28, 0, 28)
shootIcon.Position = UDim2.new(0, 12, 0.5, -14)
shootIcon.BackgroundTransparency = 1
shootIcon.Text = "🎯"
shootIcon.TextSize = 20
shootIcon.ZIndex = 5
shootIcon.Parent = shootContainer

local shootLabel = Instance.new("TextLabel")
shootLabel.Size = UDim2.new(1, -52, 0, 22)
shootLabel.Position = UDim2.new(0, 44, 0.5, -11)
shootLabel.BackgroundTransparency = 1
shootLabel.TextColor3 = Color3.new(1, 1, 1)
shootLabel.Text = "Shoot Monster"
shootLabel.Font = Enum.Font.GothamBold
shootLabel.TextSize = 14
shootLabel.TextXAlignment = Enum.TextXAlignment.Left
shootLabel.ZIndex = 5
shootLabel.Parent = shootContainer

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(1, -16, 0, 8)
statusDot.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
statusDot.ZIndex = 5
statusDot.Parent = shootContainer
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local sDragging = false
local sDragInput = nil
local sDragStart = Vector3.new(0, 0, 0)
local sStartPos = UDim2.new(0, 0, 0, 0)
local sMoved = false

shootContainer.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sDragging = true
        sMoved = false
        sDragStart = input.Position
        sStartPos = shootContainer.Position
    end
end)

shootContainer.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        sDragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == sDragInput and sDragging then
        local delta = input.Position - sDragStart
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
            sMoved = true
        end
        shootContainer.Position = UDim2.new(sStartPos.X.Scale, sStartPos.X.Offset + delta.X, sStartPos.Y.Scale, sStartPos.Y.Offset + delta.Y)
    end
end)

shootContainer.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        sDragging = false
    end
end)

local shootPulseRunning = false
local function runShootPulse()
    if shootPulseRunning then return end
    shootPulseRunning = true
    task.spawn(function()
        while shootContainer.Visible and shootPulseRunning do
            local t1 = TweenService:Create(shootGlow, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.15 })
            t1:Play()
            t1.Completed:Wait()
            if not shootContainer.Visible then break end
            local t2 = TweenService:Create(shootGlow, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.55 })
            t2:Play()
            t2.Completed:Wait()
        end
        shootPulseRunning = false
    end)
end

local statusPulseRunning = false
local function runStatusPulse()
    if statusPulseRunning then return end
    statusPulseRunning = true
    task.spawn(function()
        while shootContainer.Visible and statusPulseRunning do
            local t1 = TweenService:Create(statusDot, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 0.5 })
            t1:Play()
            t1.Completed:Wait()
            if not shootContainer.Visible then break end
            local t2 = TweenService:Create(statusDot, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 0 })
            t2:Play()
            t2.Completed:Wait()
        end
        statusPulseRunning = false
    end)
end

-- =========================
-- INSTANT SHOOT — HRP CAMLOCK
-- =========================
local function instantShootMonster()
    if not localPlayerHasGun() then
        WindUI:Notify({ Title = "Shoot Monster", Content = "Kamu tidak punya Gun!", Duration = 2 })
        return
    end

    local monster = getPlayerWithItem("Monster")
    if not monster or not monster.Character then
        WindUI:Notify({ Title = "Shoot Monster", Content = "Monster tidak ditemukan!", Duration = 2 })
        return
    end

    local monsterHrp = monster.Character:FindFirstChild("HumanoidRootPart")
    if not monsterHrp then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    -- Equip gun
    local gun = equipGun()
    if not gun then return end

    local camera = workspace.CurrentCamera
    local oldAutoRotate = humanoid.AutoRotate
    humanoid.AutoRotate = false

    -- CAMLOCK: Lock player's HRP to face monster's HRP directly (X, Y, Z)
    local lookCFrame = CFrame.lookAt(hrp.Position, monsterHrp.Position)
    hrp.CFrame = lookCFrame

    -- Wait one frame for camera/sync
    RunService.Heartbeat:Wait()

    -- Get updated screen position of monster HRP (no head bounce)
    local screenPos, onScreen = camera:WorldToScreenPoint(monsterHrp.Position)

    -- Fire everything same-frame
    if onScreen then
        pcall(function()
            VirtualUser:Button1Down(Vector2.new(screenPos.X, screenPos.Y))
            VirtualUser:Button1Up(Vector2.new(screenPos.X, screenPos.Y))
        end)

        pcall(function()
            if gun and gun.Parent then
                gun:Activate()
            end
        end)
    end

    -- Restore rotation
    humanoid.AutoRotate = oldAutoRotate

    -- Visual feedback
    statusDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    TweenService:Create(shootBg, TweenInfo.new(0.05), { BackgroundColor3 = Color3.fromRGB(255, 200, 50) }):Play()
    task.delay(0.15, function()
        statusDot.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
        TweenService:Create(shootBg, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(200, 80, 0) }):Play()
    end)
end

shootBtn.MouseButton1Click:Connect(function()
    if sMoved then
        sMoved = false
        return
    end
    instantShootMonster()
end)

shootBtn.MouseEnter:Connect(function()
    TweenService:Create(shootBg, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
    shootBgStroke.Color = Color3.fromRGB(255, 220, 100)
end)

shootBtn.MouseLeave:Connect(function()
    TweenService:Create(shootBg, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
    shootBgStroke.Color = Color3.fromRGB(255, 180, 50)
end)

task.spawn(function()
    while true do
        if ShootMode then
            local hasGun = localPlayerHasGun()
            local monsterExists = getPlayerWithItem("Monster") ~= nil

            local wasVisible = shootContainer.Visible
            shootContainer.Visible = hasGun

            if hasGun and not wasVisible then
                runShootPulse()
                runStatusPulse()
            end

            if hasGun then
                statusDot.BackgroundColor3 = monsterExists and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 200, 0)
            end
        else
            shootContainer.Visible = false
        end
        task.wait(0.3)
    end
end)

MainTab:Toggle({
    Title = "Shoot Monster",
    Value = false,
    Callback = function(v)
        ShootMode = v
        if v then
            WindUI:Notify({ Title = "Shoot Monster", Content = "Aktif! Tombol muncul kalau kamu punya Gun.", Duration = 3 })
        end
    end
})

MainTab:Toggle({
    Title = "Auto Shoot Monster",
    Value = false,
    Callback = function(v)
        AutoShoot = v
        if v then
            WindUI:Notify({ Title = "Auto Shoot", Content = "Aktif! Akan tembak otomatis.", Duration = 3 })
        end
    end
})

task.spawn(function()
    while true do
        if AutoShoot and ShootMode then
            local hasGun = localPlayerHasGun()
            local monster = getPlayerWithItem("Monster")
            if hasGun and monster and monster.Character then
                local monsterHrp = monster.Character:FindFirstChild("HumanoidRootPart")
                local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if monsterHrp and myHrp then
                    local dist = (myHrp.Position - monsterHrp.Position).Magnitude
                    if dist < 200 then
                        instantShootMonster()
                    end
                end
            end
        end
        task.wait(0.3)
    end
end)

-- =========================
-- PLAYER TAB
-- =========================
PlayerTab:Slider({
    Title = "WalkSpeed",
    Value = {
        Min = 16,
        Max = 150,
        Default = 16,
    },
    Callback = function(v)
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = v
        end
    end
})

PlayerTab:Slider({
    Title = "JumpPower",
    Value = {
        Min = 50,
        Max = 300,
        Default = 50,
    },
    Callback = function(v)
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.JumpPower = v
        end
    end
})

PlayerTab:Toggle({
    Title = "Infinite Jump",
    Value = false,
    Callback = function(v)
        InfJump = v
    end
})

UserInputService.JumpRequest:Connect(function()
    if InfJump and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

PlayerTab:Toggle({
    Title = "Noclip",
    Value = false,
    Callback = function(v)
        Noclip = v
    end
})

RunService.Stepped:Connect(function()
    if Noclip and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

PlayerTab:Toggle({
    Title = "Anti-AFK",
    Value = false,
    Callback = function(v)
        AntiAfk = v
    end
})

task.spawn(function()
    while true do
        if AntiAfk then
            pcall(function()
                VirtualUser:CaptureFocus()
                VirtualUser:ClickButton1(Vector2.new())
                VirtualUser:ReleaseFocus()
            end)
        end
        task.wait(math.random(120, 180))
    end
end)

PlayerTab:Toggle({
    Title = "Auto Respawn",
    Value = false,
    Callback = function(v)
        AutoRespawn = v
    end
})

task.spawn(function()
    while true do
        if AutoRespawn then
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health <= 0 then
                task.wait(1)
                pcall(function()
                    LocalPlayer:LoadCharacter()
                end)
            end
        end
        task.wait(1)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end
end)

-- =========================
-- OTHER FEATURES
-- =========================
MainTab:Button({
    Title = "Teleport Lobby",
    Callback = function()
        local pos = Vector3.new(-363.672, 33.0084, -9224.38)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(pos) end
    end
})

MainTab:Toggle({
    Title = "Full Bright",
    Value = false,
    Callback = function(v)
        if v then
            Lighting.Brightness = 5
            Lighting.ClockTime = 12
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = true
        end
    end
})

Players.PlayerRemoving:Connect(function(plr)
    if plr == LocalPlayer then
        for _, gui in pairs(game.CoreGui:GetChildren()) do
            if gui.Name:match("LvHub") then
                gui:Destroy()
            end
        end
    end
end)
