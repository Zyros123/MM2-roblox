--[[
    MM2 - peque yitzchak
    Optimizado para Xeno + bajo lag
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--// Settings
local S = {
    PlayerESP = false,
    GunESP = false,
    AutoGrabGun = false,
    SilentAim = false,
    AutoStab = false,
    AutoCoins = false,
    Fly = false,
    Noclip = false,
    FlySpeed = 45
}

local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "MM2ESP"
ESPFolder.Parent = CoreGui

local Highlights = {}
local Flying = false
local BV, BG
local NoclipConn
local LastCoin = 0
local LastGun = 0

--// Roles
local function getRole(plr)
    if not plr or not plr.Character then return "Innocent" end
    local c, b = plr.Character, plr:FindFirstChild("Backpack")
    if c:FindFirstChild("Knife") or (b and b:FindFirstChild("Knife")) then return "Murderer" end
    if c:FindFirstChild("Gun") or (b and b:FindFirstChild("Gun")) then return "Sheriff" end
    return "Innocent"
end

local function roleColor(r)
    if r == "Murderer" then return Color3.fromRGB(255, 40, 40) end
    if r == "Sheriff" then return Color3.fromRGB(40, 140, 255) end
    return Color3.fromRGB(60, 220, 60)
end

--// ESP (optimizado)
local function clearESP()
    for _, h in pairs(Highlights) do
        if h and h.Parent then h:Destroy() end
    end
    table.clear(Highlights)
    for _, v in pairs(ESPFolder:GetChildren()) do v:Destroy() end
end

local function updateESP()
    if not S.PlayerESP then
        clearESP()
        return
    end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local role = getRole(plr)
            local color = roleColor(role)

            if not Highlights[plr] or not Highlights[plr].Parent then
                local h = Instance.new("Highlight")
                h.FillTransparency = 0.65
                h.OutlineTransparency = 0
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent = ESPFolder
                Highlights[plr] = h
            end

            local h = Highlights[plr]
            h.Adornee = plr.Character
            h.FillColor = color
            h.OutlineColor = color
            h.Enabled = true
        end
    end
end

--// Gun ESP + Auto Grab (throttled)
local function handleGun()
    local now = tick()
    if now - LastGun < 0.4 then return end
    LastGun = now

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") and obj.Name == "Gun" then
            -- ESP
            if S.GunESP and not obj:FindFirstChild("MM2GunHL") then
                local h = Instance.new("Highlight")
                h.Name = "MM2GunHL"
                h.FillColor = Color3.fromRGB(255, 200, 0)
                h.OutlineColor = Color3.fromRGB(255, 255, 100)
                h.FillTransparency = 0.4
                h.Adornee = obj
                h.Parent = obj
            end

            -- Auto Grab
            if S.AutoGrabGun and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local handle = obj:FindFirstChild("Handle")
                if handle then
                    pcall(function()
                        firetouchinterest(LocalPlayer.Character.HumanoidRootPart, handle, 0)
                        task.wait(0.05)
                        firetouchinterest(LocalPlayer.Character.HumanoidRootPart, handle, 1)
                    end)
                end
            end
        end
    end
end

--// Silent Aim
local function getMurderer()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getRole(plr) == "Murderer" and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                return plr.Character.HumanoidRootPart
            end
        end
    end
end

local oldIndex
pcall(function()
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if S.SilentAim and key == "Hit" and self == Mouse then
            local target = getMurderer()
            if target then
                return target.Position
            end
        end
        return oldIndex(self, key)
    end)
end)

--// AutoStab (throttled)
local function doStab()
    if not S.AutoStab or getRole(LocalPlayer) ~= "Murderer" then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    local knife = LocalPlayer.Character:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
    if not knife then return end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (plr.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            if dist < 14 then
                knife.Parent = LocalPlayer.Character
                pcall(mouse1click)
                break
            end
        end
    end
end

--// Coins (throttled)
local function collectCoins()
    if not S.AutoCoins then return end
    local now = tick()
    if now - LastCoin < 0.6 then return end
    LastCoin = now

    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = LocalPlayer.Character.HumanoidRootPart

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name == "Coin" or (obj:IsA("BasePart") and obj.Name:lower():find("coin")) then
            pcall(function()
                firetouchinterest(hrp, obj, 0)
                firetouchinterest(hrp, obj, 1)
            end)
        end
    end
end

--// Fly
local function startFly()
    if Flying then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    Flying = true
    local hrp = char.HumanoidRootPart

    BV = Instance.new("BodyVelocity")
    BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    BV.Velocity = Vector3.zero
    BV.Parent = hrp

    BG = Instance.new("BodyGyro")
    BG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    BG.P = 9999
    BG.Parent = hrp

    char.Humanoid.PlatformStand = true
end

local function stopFly()
    Flying = false
    if BV then BV:Destroy() BV = nil end
    if BG then BG:Destroy() BG = nil end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.PlatformStand = false
    end
end

local function updateFly()
    if not Flying or not BV or not BG then return end
    local cam = Camera.CFrame
    local move = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move + Vector3.new(0,-1,0) end

    if move.Magnitude > 0 then
        BV.Velocity = move.Unit * S.FlySpeed
    else
        BV.Velocity = Vector3.zero
    end
    BG.CFrame = cam
end

--// Noclip
local function setNoclip(on)
    if NoclipConn then NoclipConn:Disconnect() NoclipConn = nil end
    if on then
        NoclipConn = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, p in pairs(LocalPlayer.Character:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    end
end

--// Teleport Lobby
local function tpLobby()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local lobby = Workspace:FindFirstChild("Lobby")
    if lobby then
        char.HumanoidRootPart.CFrame = lobby:GetPivot() + Vector3.new(0, 5, 0)
    else
        char.HumanoidRootPart.CFrame = CFrame.new(0, 120, 0)
    end
end

--// GUI (ligera + minimizable)
local function createGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "MM2_PY"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- Mini button
    local Mini = Instance.new("TextButton")
    Mini.Name = "MiniBtn"
    Mini.Size = UDim2.new(0, 42, 0, 42)
    Mini.Position = UDim2.new(0, 15, 0.5, -21)
    Mini.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    Mini.Text = "MM2"
    Mini.TextColor3 = Color3.fromRGB(255, 255, 255)
    Mini.Font = Enum.Font.GothamBold
    Mini.TextSize = 11
    Mini.Visible = false
    Mini.Parent = sg
    Instance.new("UICorner", Mini).CornerRadius = UDim.new(0, 10)

    -- Main Frame
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 420, 0, 300)
    Main.Position = UDim2.new(0.5, -210, 0.5, -150)
    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = sg
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

    -- Sidebar
    local Side = Instance.new("Frame")
    Side.Size = UDim2.new(0, 130, 1, 0)
    Side.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    Side.BorderSizePixel = 0
    Side.Parent = Main
    Instance.new("UICorner", Side).CornerRadius = UDim.new(0, 10)

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 28)
    Title.BackgroundTransparency = 1
    Title.Text = "MM2"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.Parent = Side

    local Sub = Instance.new("TextLabel")
    Sub.Size = UDim2.new(1, 0, 0, 16)
    Sub.Position = UDim2.new(0, 0, 0, 26)
    Sub.BackgroundTransparency = 1
    Sub.Text = "peque yitzchak"
    Sub.TextColor3 = Color3.fromRGB(130, 130, 150)
    Sub.Font = Enum.Font.Gotham
    Sub.TextSize = 11
    Sub.Parent = Side

    -- Content
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -140, 1, -15)
    Content.Position = UDim2.new(0, 135, 0, 8)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local function clear()
        for _, v in pairs(Content:GetChildren()) do v:Destroy() end
    end

    local function addToggle(txt, key, y)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -8, 0, 30)
        f.Position = UDim2.new(0, 4, 0, y)
        f.BackgroundTransparency = 1
        f.Parent = Content

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.7, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = Color3.fromRGB(210, 210, 220)
        l.Font = Enum.Font.Gotham
        l.TextSize = 13
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = f

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(0, 36, 0, 20)
        bg.Position = UDim2.new(1, -42, 0.5, -10)
        bg.BackgroundColor3 = S[key] and Color3.fromRGB(70, 160, 255) or Color3.fromRGB(45, 45, 55)
        bg.Parent = f
        Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

        local c = Instance.new("Frame")
        c.Size = UDim2.new(0, 16, 0, 16)
        c.Position = S[key] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        c.BackgroundColor3 = Color3.new(1,1,1)
        c.Parent = bg
        Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = f

        btn.MouseButton1Click:Connect(function()
            S[key] = not S[key]
            bg.BackgroundColor3 = S[key] and Color3.fromRGB(70, 160, 255) or Color3.fromRGB(45, 45, 55)
            c.Position = S[key] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)

            if key == "PlayerESP" then
                if S.PlayerESP then updateESP() else clearESP() end
            elseif key == "Fly" then
                if S.Fly then startFly() else stopFly() end
            elseif key == "Noclip" then
                setNoclip(S.Noclip)
            end
        end)
    end

    local function addBtn(txt, y, fn)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -16, 0, 28)
        b.Position = UDim2.new(0, 8, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        b.Text = txt
        b.TextColor3 = Color3.fromRGB(220, 220, 230)
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.Parent = Content
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(fn)
    end

    local tabs = {"Visuals", "Sheriff", "Murderer", "Utils", "Coins", "Misc"}
    local tabBtns = {}

    local function load(tab)
        clear()
        if tab == "Visuals" then
            addToggle("Player ESP", "PlayerESP", 10)
            addToggle("Dropped Gun ESP", "GunESP", 45)
        elseif tab == "Sheriff" then
            addToggle("Auto Grab Gun", "AutoGrabGun", 10)
            addToggle("Silent Aim (Murderer)", "SilentAim", 45)
            addBtn("Agarrar Arma Ahora", 90, function()
                S.AutoGrabGun = true
                handleGun()
                task.wait(0.5)
                S.AutoGrabGun = false
            end)
            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -16, 0, 50)
            info.Position = UDim2.new(0, 8, 0, 130)
            info.BackgroundTransparency = 1
            info.Text = "Silent Aim: con el arma, los tiros van al Murderer.\nAuto Grab: recoge el arma cuando cae."
            info.TextColor3 = Color3.fromRGB(140, 140, 160)
            info.Font = Enum.Font.Gotham
            info.TextSize = 11
            info.TextWrapped = true
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.Parent = Content
        elseif tab == "Murderer" then
            addToggle("AutoStab", "AutoStab", 10)
        elseif tab == "Utils" then
            addBtn("Teleport Lobby", 10, tpLobby)
        elseif tab == "Coins" then
            addToggle("Auto Coins", "AutoCoins", 10)
        elseif tab == "Misc" then
            addToggle("Fly", "Fly", 10)
            addToggle("Noclip", "Noclip", 45)
        end
    end

    for i, name in ipairs(tabs) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -14, 0, 28)
        b.Position = UDim2.new(0, 7, 0, 50 + (i-1)*32)
        b.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        b.Text = "  " .. name
        b.TextColor3 = Color3.fromRGB(200, 200, 215)
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Parent = Side
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

        b.MouseButton1Click:Connect(function()
            for _, tb in pairs(tabBtns) do tb.BackgroundColor3 = Color3.fromRGB(28, 28, 36) end
            b.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
            load(name)
        end)
        tabBtns[name] = b
    end

    tabBtns["Visuals"].BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    load("Visuals")

    -- Minimize / Close
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 26, 0, 26)
    MinBtn.Position = UDim2.new(1, -55, 0, 6)
    MinBtn.BackgroundTransparency = 1
    MinBtn.Text = "–"
    MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 18
    MinBtn.Parent = Main
    MinBtn.MouseButton1Click:Connect(function()
        Main.Visible = false
        Mini.Visible = true
    end)

    local Close = Instance.new("TextButton")
    Close.Size = UDim2.new(0, 26, 0, 26)
    Close.Position = UDim2.new(1, -28, 0, 6)
    Close.BackgroundTransparency = 1
    Close.Text = "×"
    Close.TextColor3 = Color3.fromRGB(200, 200, 200)
    Close.Font = Enum.Font.GothamBold
    Close.TextSize = 18
    Close.Parent = Main
    Close.MouseButton1Click:Connect(function()
        sg.Enabled = false
    end)

    Mini.MouseButton1Click:Connect(function()
        Main.Visible = true
        Mini.Visible = false
    end)

    -- RightShift toggle
    UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == Enum.KeyCode.RightShift then
            if Main.Visible then
                Main.Visible = false
                Mini.Visible = true
            else
                Main.Visible = true
                Mini.Visible = false
                sg.Enabled = true
            end
        end
    end)
end

--// Main
createGUI()
print("MM2 | peque yitzchak | Loaded (Optimized)")

-- Loops optimizados (no cada frame)
task.spawn(function()
    while true do
        task.wait(0.35)
        if S.PlayerESP then updateESP() end
        handleGun()
        if S.AutoStab then doStab() end
        if S.AutoCoins then collectCoins() end
    end
end)

RunService.RenderStepped:Connect(function()
    if S.Fly then updateFly() end
end)

Players.PlayerRemoving:Connect(function(plr)
    if Highlights[plr] then
        Highlights[plr]:Destroy()
        Highlights[plr] = nil
    end
end)
