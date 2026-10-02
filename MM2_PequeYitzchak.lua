--[[
    MM2 - peque yitzchak
    Script para Murder Mystery 2
    Compatible con Xeno (lo más estable posible)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--// Settings
local Settings = {
    PlayerESP = false,
    DroppedGunESP = false,
    TrapESP = false,
    AutoGrabGun = false,
    AutoStab = false,
    AutoCoins = false,
    Fly = false,
    Noclip = false,
    FlySpeed = 50
}

local ESPObjects = {}
local Connections = {}
local Flying = false
local BodyVelocity, BodyGyro

--// Utility
local function safeCall(fn, ...)
    local success, result = pcall(fn, ...)
    return success, result
end

local function getRole(player)
    if not player or not player.Character then return "Innocent" end
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")

    if (char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))) then
        return "Murderer"
    elseif (char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun"))) then
        return "Sheriff"
    end
    return "Innocent"
end

local function getRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 50, 50)
    elseif role == "Sheriff" then return Color3.fromRGB(50, 150, 255)
    else return Color3.fromRGB(80, 255, 80) end
end

--// ESP
local function clearESP()
    for _, v in pairs(ESPObjects) do
        if v and v.Parent then v:Destroy() end
    end
    table.clear(ESPObjects)
end

local function createESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "MM2ESP"
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.Parent = player.Character or player

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MM2Role"
    billboard.Size = UDim2.new(0, 120, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = player.Character and player.Character:FindFirstChild("HumanoidRootPart") or player.Character

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0.5
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard

    ESPObjects[player] = {Highlight = highlight, Billboard = billboard, Label = label}

    local function update()
        if not Settings.PlayerESP then return end
        local role = getRole(player)
        local color = getRoleColor(role)
        if highlight and highlight.Parent then
            highlight.FillColor = color
            highlight.OutlineColor = color
            highlight.Adornee = player.Character
        end
        if label then
            label.Text = player.Name .. " [" .. role .. "]"
            label.TextColor3 = color
        end
        if billboard and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            billboard.Adornee = player.Character.HumanoidRootPart
        end
    end

    update()
    table.insert(Connections, player.CharacterAdded:Connect(function()
        task.wait(0.5)
        update()
    end))
end

local function updateAllESP()
    if not Settings.PlayerESP then
        clearESP()
        return
    end
    for _, player in pairs(Players:GetPlayers()) do
        createESP(player)
        if ESPObjects[player] then
            local role = getRole(player)
            local color = getRoleColor(role)
            local data = ESPObjects[player]
            if data.Highlight then
                data.Highlight.FillColor = color
                data.Highlight.OutlineColor = color
                data.Highlight.Enabled = true
            end
            if data.Label then
                data.Label.Text = player.Name .. " [" .. role .. "]"
                data.Label.TextColor3 = color
            end
        end
    end
end

--// Dropped Gun ESP
local GunESPFolder = Instance.new("Folder")
GunESPFolder.Name = "MM2GunESP"
GunESPFolder.Parent = Workspace

local function updateGunESP()
    for _, v in pairs(GunESPFolder:GetChildren()) do v:Destroy() end
    if not Settings.DroppedGunESP then return end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name:lower():find("gun")) and not obj.Parent:IsA("Model") then
            local h = Instance.new("Highlight")
            h.FillColor = Color3.fromRGB(255, 215, 0)
            h.OutlineColor = Color3.fromRGB(255, 255, 100)
            h.FillTransparency = 0.4
            h.Adornee = obj
            h.Parent = GunESPFolder
        end
    end
end

--// Auto Grab Gun
local function grabGun()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name:lower():find("gun")) then
            if obj:FindFirstChild("Handle") then
                firetouchinterest(LocalPlayer.Character.HumanoidRootPart, obj.Handle, 0)
                task.wait(0.1)
                firetouchinterest(LocalPlayer.Character.HumanoidRootPart, obj.Handle, 1)
            end
        end
    end
end

--// AutoStab
local function doAutoStab()
    if not Settings.AutoStab then return end
    if getRole(LocalPlayer) ~= "Murderer" then return end

    local knife = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
    if not knife then return end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (player.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            if dist < 12 then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    knife.Parent = LocalPlayer.Character
                    -- Simple attack simulation
                    mouse1click()
                end
            end
        end
    end
end

--// Auto Coins
local function collectCoins()
    if not Settings.AutoCoins then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name == "Coin" or obj.Name == "CoinContainer" or (obj:IsA("BasePart") and obj.Name:lower():find("coin")) then
            pcall(function()
                firetouchinterest(LocalPlayer.Character.HumanoidRootPart, obj, 0)
                task.wait()
                firetouchinterest(LocalPlayer.Character.HumanoidRootPart, obj, 1)
            end)
        end
    end
end

--// Fly
local function startFly()
    if Flying then return end
    Flying = true
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local hrp = char.HumanoidRootPart
    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.Parent = hrp

    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    BodyGyro.P = 10000
    BodyGyro.Parent = hrp

    char.Humanoid.PlatformStand = true
end

local function stopFly()
    Flying = false
    if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
    if BodyGyro then BodyGyro:Destroy() BodyGyro = nil end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.PlatformStand = false
    end
end

local function updateFly()
    if not Flying or not BodyVelocity or not BodyGyro then return end
    local cam = Camera.CFrame
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end

    BodyVelocity.Velocity = dir.Unit * Settings.FlySpeed
    if dir.Magnitude < 0.1 then BodyVelocity.Velocity = Vector3.zero end
    BodyGyro.CFrame = cam
end

--// Noclip
local NoclipConnection
local function setNoclip(state)
    if NoclipConnection then NoclipConnection:Disconnect() NoclipConnection = nil end
    if state then
        NoclipConnection = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

--// Teleports
local function tpToLobby()
    local lobby = Workspace:FindFirstChild("Lobby") or Workspace:FindFirstChild("LobbySpawn")
    if lobby then
        LocalPlayer.Character.HumanoidRootPart.CFrame = lobby.CFrame + Vector3.new(0, 5, 0)
    else
        -- Fallback common lobby position (approximate)
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 100, 0)
    end
end

--// GUI Creation
local function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MM2_PequeYitzchak"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = game:GetService("CoreGui")

    -- Main Frame
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 480, 0, 340)
    Main.Position = UDim2.new(0.5, -240, 0.5, -170)
    Main.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = Main

    -- Left Sidebar
    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 150, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = Main

    local SideCorner = Instance.new("UICorner")
    SideCorner.CornerRadius = UDim.new(0, 10)
    SideCorner.Parent = Sidebar

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundTransparency = 1
    Title.Text = "MM2"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 20
    Title.Parent = Sidebar

    local SubTitle = Instance.new("TextLabel")
    SubTitle.Size = UDim2.new(1, 0, 0, 20)
    SubTitle.Position = UDim2.new(0, 0, 0, 32)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Text = "peque yitzchak"
    SubTitle.TextColor3 = Color3.fromRGB(140, 140, 160)
    SubTitle.Font = Enum.Font.Gotham
    SubTitle.TextSize = 12
    SubTitle.Parent = Sidebar

    -- Tabs
    local Tabs = {"Visuals", "Sheriff / Gun", "Murderer / Knife", "Round Utils", "Coins", "Misc"}
    local TabButtons = {}
    local CurrentTab = "Visuals"

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -160, 1, -20)
    Content.Position = UDim2.new(0, 155, 0, 10)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local function clearContent()
        for _, v in pairs(Content:GetChildren()) do
            v:Destroy()
        end
    end

    local function createToggle(name, settingKey, yPos)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 35)
        frame.Position = UDim2.new(0, 5, 0, yPos)
        frame.BackgroundTransparency = 1
        frame.Parent = Content

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(220, 220, 230)
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local toggleBg = Instance.new("Frame")
        toggleBg.Size = UDim2.new(0, 40, 0, 22)
        toggleBg.Position = UDim2.new(1, -50, 0.5, -11)
        toggleBg.BackgroundColor3 = Settings[settingKey] and Color3.fromRGB(80, 180, 255) or Color3.fromRGB(50, 50, 60)
        toggleBg.Parent = frame

        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(1, 0)
        toggleCorner.Parent = toggleBg

        local circle = Instance.new("Frame")
        circle.Size = UDim2.new(0, 18, 0, 18)
        circle.Position = Settings[settingKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        circle.Parent = toggleBg

        local circleCorner = Instance.new("UICorner")
        circleCorner.CornerRadius = UDim.new(1, 0)
        circleCorner.Parent = circle

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = frame

        btn.MouseButton1Click:Connect(function()
            Settings[settingKey] = not Settings[settingKey]
            toggleBg.BackgroundColor3 = Settings[settingKey] and Color3.fromRGB(80, 180, 255) or Color3.fromRGB(50, 50, 60)
            circle.Position = Settings[settingKey] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)

            if settingKey == "PlayerESP" then updateAllESP() end
            if settingKey == "Fly" then
                if Settings.Fly then startFly() else stopFly() end
            end
            if settingKey == "Noclip" then setNoclip(Settings.Noclip) end
        end)
    end

    local function createButton(name, yPos, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 32)
        btn.Position = UDim2.new(0, 10, 0, yPos)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(220, 220, 230)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.Parent = Content

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn

        btn.MouseButton1Click:Connect(callback)
    end

    local function loadTab(tabName)
        clearContent()
        CurrentTab = tabName

        if tabName == "Visuals" then
            local desc = Instance.new("TextLabel")
            desc.Size = UDim2.new(1, -10, 0, 40)
            desc.Position = UDim2.new(0, 5, 0, 5)
            desc.BackgroundTransparency = 1
            desc.Text = "Player ESP, Dropped Gun ESP y Trap ESP para MM2."
            desc.TextColor3 = Color3.fromRGB(160, 160, 180)
            desc.Font = Enum.Font.Gotham
            desc.TextSize = 12
            desc.TextWrapped = true
            desc.TextXAlignment = Enum.TextXAlignment.Left
            desc.Parent = Content

            createToggle("Player ESP", "PlayerESP", 55)
            createToggle("Dropped Gun ESP", "DroppedGunESP", 95)
            createToggle("Trap ESP", "TrapESP", 135)

        elseif tabName == "Sheriff / Gun" then
            createToggle("Auto Grab Gun", "AutoGrabGun", 20)
            createButton("Agarrar Arma Ahora", 70, function()
                grabGun()
            end)
            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -20, 0, 60)
            info.Position = UDim2.new(0, 10, 0, 120)
            info.BackgroundTransparency = 1
            info.Text = "Si eres Innocent y el Sheriff muere, activa Auto Grab o usa el botón para tomar el arma y matar al Murderer."
            info.TextColor3 = Color3.fromRGB(150, 150, 170)
            info.Font = Enum.Font.Gotham
            info.TextSize = 12
            info.TextWrapped = true
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.Parent = Content

        elseif tabName == "Murderer / Knife" then
            createToggle("AutoStab (Knife)", "AutoStab", 20)
            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -20, 0, 50)
            info.Position = UDim2.new(0, 10, 0, 70)
            info.BackgroundTransparency = 1
            info.Text = "Solo funciona si tienes el cuchillo (rol Murderer). Ataca automáticamente cerca."
            info.TextColor3 = Color3.fromRGB(150, 150, 170)
            info.Font = Enum.Font.Gotham
            info.TextSize = 12
            info.TextWrapped = true
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.Parent = Content

        elseif tabName == "Round Utils" then
            createButton("Teleport al Lobby", 20, tpToLobby)
            createButton("Teleport a Zona Segura", 60, function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 50, 0)
                end
            end)

        elseif tabName == "Coins" then
            createToggle("Auto Recolectar Monedas", "AutoCoins", 20)
            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -20, 0, 40)
            info.Position = UDim2.new(0, 10, 0, 70)
            info.BackgroundTransparency = 1
            info.Text = "Recolecta monedas automáticamente por el mapa."
            info.TextColor3 = Color3.fromRGB(150, 150, 170)
            info.Font = Enum.Font.Gotham
            info.TextSize = 12
            info.TextWrapped = true
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.Parent = Content

        elseif tabName == "Misc" then
            createToggle("Fly", "Fly", 20)
            createToggle("Noclip", "Noclip", 60)
            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -20, 0, 50)
            info.Position = UDim2.new(0, 10, 0, 110)
            info.BackgroundTransparency = 1
            info.Text = "Fly: WASD + Espacio / Ctrl\nNoclip: atravesar paredes"
            info.TextColor3 = Color3.fromRGB(150, 150, 170)
            info.Font = Enum.Font.Gotham
            info.TextSize = 12
            info.TextWrapped = true
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.Parent = Content
        end
    end

    -- Create tab buttons
    for i, tabName in ipairs(Tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 32)
        btn.Position = UDim2.new(0, 10, 0, 60 + (i-1)*38)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        btn.Text = "  " .. tabName
        btn.TextColor3 = Color3.fromRGB(200, 200, 220)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = Sidebar

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn

        btn.MouseButton1Click:Connect(function()
            for _, b in pairs(TabButtons) do
                b.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
            end
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
            loadTab(tabName)
        end)
        TabButtons[tabName] = btn
    end

    -- Default tab
    TabButtons["Visuals"].BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    loadTab("Visuals")

    -- Close button
    local Close = Instance.new("TextButton")
    Close.Size = UDim2.new(0, 30, 0, 30)
    Close.Position = UDim2.new(1, -35, 0, 5)
    Close.BackgroundTransparency = 1
    Close.Text = "×"
    Close.TextColor3 = Color3.fromRGB(200, 200, 200)
    Close.Font = Enum.Font.GothamBold
    Close.TextSize = 20
    Close.Parent = Main
    Close.MouseButton1Click:Connect(function()
        ScreenGui.Enabled = false
    end)

    -- Toggle GUI with RightShift
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
    end)

    return ScreenGui
end

--// Main Loop
local function main()
    createGUI()
    print("MM2 | peque yitzchak loaded!")

    -- Player added
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            task.wait(1)
            if Settings.PlayerESP then createESP(player) end
        end)
    end)

    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            createESP(player)
        end
    end

    RunService.RenderStepped:Connect(function()
        if Settings.PlayerESP then updateAllESP() end
        if Settings.DroppedGunESP then updateGunESP() end
        if Settings.AutoGrabGun then grabGun() end
        if Settings.AutoStab then doAutoStab() end
        if Settings.AutoCoins then collectCoins() end
        if Settings.Fly then updateFly() end
    end)
end

main()
