--[[
    MM2 - peque yitzchak
    Optimizado + Get Gun + Silent Aim fuerte + Fling
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local S = {
    PlayerESP = false,
    GunESP = false,
    AutoGrabGun = false,
    SilentAim = false,
    AutoStab = false,
    AutoCoins = false,
    Fly = false,
    Noclip = false,
    FlySpeed = 50
}

local ESPFolder = Instance.new("Folder", CoreGui)
ESPFolder.Name = "MM2ESP"
local Highlights = {}
local Flying = false
local BV, BG, NoclipConn
local LastCoin, LastGun = 0, 0

--// Role helpers
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

local function getChar(plr)
    return plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character
end

--// ESP
local function clearESP()
    for _, h in pairs(Highlights) do if h and h.Parent then h:Destroy() end end
    table.clear(Highlights)
end

local function updateESP()
    if not S.PlayerESP then clearESP() return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getChar(plr) then
            local role = getRole(plr)
            local color = roleColor(role)
            if not Highlights[plr] or not Highlights[plr].Parent then
                local h = Instance.new("Highlight")
                h.FillTransparency = 0.6
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

--// Gun handle
local function handleGun()
    if tick() - LastGun < 0.35 then return end
    LastGun = tick()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") and obj.Name == "Gun" then
            if S.GunESP and not obj:FindFirstChild("MM2GunHL") then
                local h = Instance.new("Highlight")
                h.Name = "MM2GunHL"
                h.FillColor = Color3.fromRGB(255, 200, 0)
                h.OutlineColor = Color3.fromRGB(255, 255, 80)
                h.FillTransparency = 0.35
                h.Adornee = obj
                h.Parent = obj
            end
            if S.AutoGrabGun and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local handle = obj:FindFirstChild("Handle")
                if handle then
                    pcall(function()
                        firetouchinterest(LocalPlayer.Character.HumanoidRootPart, handle, 0)
                        task.wait(0.03)
                        firetouchinterest(LocalPlayer.Character.HumanoidRootPart, handle, 1)
                    end)
                end
            end
        end
    end
end

--// Strong Silent Aim
local function getMurdererRoot()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getRole(plr) == "Murderer" then
            local char = getChar(plr)
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    return char.HumanoidRootPart
                end
            end
        end
    end
end

pcall(function()
    local old
    old = hookmetamethod(game, "__index", function(self, key)
        if S.SilentAim and not checkcaller() then
            if key == "Hit" and self == Mouse then
                local t = getMurdererRoot()
                if t then return t.Position end
            elseif key == "Target" and self == Mouse then
                local t = getMurdererRoot()
                if t then return t end
            end
        end
        return old(self, key)
    end)
end)

-- Also redirect camera slightly for better hit chance
RunService.RenderStepped:Connect(function()
    if S.SilentAim and LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("Gun") or LocalPlayer.Backpack:FindFirstChild("Gun")) then
        local target = getMurdererRoot()
        if target then
            -- soft aim assist
            local cam = Camera.CFrame
            local dir = (target.Position - cam.Position).Unit
            Camera.CFrame = CFrame.new(cam.Position, cam.Position + cam.LookVector:Lerp(dir, 0.15))
        end
    end
end)

--// Fling (mucho más fuerte)
local function flingPlayer(roleName)
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return end
    local myHRP = myChar.HumanoidRootPart

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getRole(plr) == roleName then
            local char = getChar(plr)
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                local hum = char:FindFirstChildOfClass("Humanoid")

                pcall(function()
                    -- 1. Traerlo y pegarlo a ti
                    if hum then
                        hum.PlatformStand = true
                        hum:ChangeState(Enum.HumanoidStateType.Physics)
                    end

                    -- Acercarlo varias veces
                    for i = 1, 6 do
                        hrp.CFrame = myHRP.CFrame * CFrame.new(0, 0, -1.5)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        task.wait(0.03)
                    end

                    -- 2. Ahora lanzarlo con fuerza extrema
                    for i = 1, 15 do
                        hrp.CFrame = myHRP.CFrame * CFrame.new(0, 0, -1)
                        
                        local bv = Instance.new("BodyVelocity")
                        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bv.Velocity = Vector3.new(
                            math.random(-2e5, 2e5),
                            2e5,
                            math.random(-2e5, 2e5)
                        )
                        bv.Parent = hrp

                        hrp.AssemblyLinearVelocity = Vector3.new(
                            math.random(-1e6, 1e6),
                            1e6,
                            math.random(-1e6, 1e6)
                        )
                        hrp.AssemblyAngularVelocity = Vector3.new(9e9, 9e9, 9e9)

                        task.wait(0.04)
                        bv:Destroy()
                    end

                    -- Empujón final lejos
                    hrp.CFrame = CFrame.new(math.random(-2000, 2000), 5000, math.random(-2000, 2000))
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 1e6, 0)
                end)
            end
        end
    end
end

--// AutoStab
local function doStab()
    if not S.AutoStab or getRole(LocalPlayer) ~= "Murderer" then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local knife = char:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
    if not knife then return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getChar(plr) then
            local dist = (plr.Character.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude
            if dist < 15 then
                knife.Parent = char
                pcall(mouse1click)
                break
            end
        end
    end
end

--// Coins
local function collectCoins()
    if not S.AutoCoins or tick() - LastCoin < 0.5 then return end
    LastCoin = tick()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
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
    local m = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then m = m + cam.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then m = m - cam.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then m = m - cam.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then m = m + cam.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then m = m + Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then m = m + Vector3.new(0,-1,0) end
    BV.Velocity = m.Magnitude > 0 and m.Unit * S.FlySpeed or Vector3.zero
    BG.CFrame = cam
end

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

local function tpLobby()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    -- Buscar partes reales del lobby
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = v.Name:lower()
            if n:find("lobby") or n:find("spawnpad") or n:find("votepad") or n:find("voting") then
                hrp.CFrame = v.CFrame + Vector3.new(0, 4, 0)
                return
            end
        end
    end

    -- Fallback: modelo Lobby
    local lobby = Workspace:FindFirstChild("Lobby") or Workspace:FindFirstChild("lobby")
    if lobby then
        hrp.CFrame = lobby:GetPivot() + Vector3.new(0, 5, 0)
        return
    end

    -- Último recurso
    hrp.CFrame = CFrame.new(hrp.Position.X, 150, hrp.Position.Z)
end

local function tpMap()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    -- Teleport cerca de otros jugadores que estén en el mapa
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local other = plr.Character.HumanoidRootPart
            if other.Position.Y > 5 and other.Position.Y < 130 then
                hrp.CFrame = other.CFrame + Vector3.new(math.random(-10, 10), 3, math.random(-10, 10))
                return
            end
        end
    end

    -- Fallback: subir un poco desde donde estás
    hrp.CFrame = hrp.CFrame + Vector3.new(0, 15, 0)
end

--// GUI
local function createGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "MM2_PY"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local Mini = Instance.new("TextButton")
    Mini.Size = UDim2.new(0, 44, 0, 44)
    Mini.Position = UDim2.new(0, 12, 0.5, -22)
    Mini.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    Mini.Text = "MM2"
    Mini.TextColor3 = Color3.new(1,1,1)
    Mini.Font = Enum.Font.GothamBold
    Mini.TextSize = 12
    Mini.Visible = false
    Mini.Parent = sg
    Instance.new("UICorner", Mini).CornerRadius = UDim.new(0, 10)

    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 430, 0, 320)
    Main.Position = UDim2.new(0.5, -215, 0.5, -160)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = sg
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

    local Side = Instance.new("Frame")
    Side.Size = UDim2.new(0, 125, 1, 0)
    Side.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    Side.BorderSizePixel = 0
    Side.Parent = Main
    Instance.new("UICorner", Side).CornerRadius = UDim.new(0, 10)

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 26)
    Title.BackgroundTransparency = 1
    Title.Text = "MM2"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.Parent = Side

    local Sub = Instance.new("TextLabel")
    Sub.Size = UDim2.new(1, 0, 0, 16)
    Sub.Position = UDim2.new(0, 0, 0, 24)
    Sub.BackgroundTransparency = 1
    Sub.Text = "peque yitzchak"
    Sub.TextColor3 = Color3.fromRGB(120, 120, 140)
    Sub.Font = Enum.Font.Gotham
    Sub.TextSize = 11
    Sub.Parent = Side

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -135, 1, -12)
    Content.Position = UDim2.new(0, 130, 0, 6)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local function clear() for _, v in pairs(Content:GetChildren()) do v:Destroy() end end

    local function addToggle(txt, key, y)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -8, 0, 28)
        f.Position = UDim2.new(0, 4, 0, y)
        f.BackgroundTransparency = 1
        f.Parent = Content

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.68, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = Color3.fromRGB(210, 210, 220)
        l.Font = Enum.Font.Gotham
        l.TextSize = 13
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = f

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(0, 34, 0, 18)
        bg.Position = UDim2.new(1, -40, 0.5, -9)
        bg.BackgroundColor3 = S[key] and Color3.fromRGB(70, 150, 255) or Color3.fromRGB(40, 40, 50)
        bg.Parent = f
        Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

        local c = Instance.new("Frame")
        c.Size = UDim2.new(0, 14, 0, 14)
        c.Position = S[key] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
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
            bg.BackgroundColor3 = S[key] and Color3.fromRGB(70, 150, 255) or Color3.fromRGB(40, 40, 50)
            c.Position = S[key] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
            if key == "PlayerESP" then if S.PlayerESP then updateESP() else clearESP() end end
            if key == "Fly" then if S.Fly then startFly() else stopFly() end end
            if key == "Noclip" then setNoclip(S.Noclip) end
        end)
    end

    local function addBtn(txt, y, fn)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -14, 0, 26)
        b.Position = UDim2.new(0, 7, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
        b.Text = txt
        b.TextColor3 = Color3.fromRGB(220, 220, 230)
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.Parent = Content
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(fn)
    end

    local tabs = {"Visuals", "Sheriff Arm", "Murderer", "Fling", "Utils", "Misc"}
    local tabBtns = {}

    local function load(tab)
        clear()
        if tab == "Visuals" then
            addToggle("Player ESP", "PlayerESP", 8)
            addToggle("Dropped Gun ESP", "GunESP", 40)
        elseif tab == "Sheriff Arm" then
            addToggle("Auto Grab Gun", "AutoGrabGun", 8)
            addToggle("Silent Aim (Fuerte)", "SilentAim", 40)
            addBtn("Conseguir Arma (Innocent)", 80, function()
                -- Intenta agarrar cualquier gun en el mapa + forzar
                S.AutoGrabGun = true
                handleGun()
                -- También busca en el mapa y toca
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("Tool") and obj.Name == "Gun" and obj:FindFirstChild("Handle") then
                        pcall(function()
                            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                firetouchinterest(hrp, obj.Handle, 0)
                                task.wait(0.05)
                                firetouchinterest(hrp, obj.Handle, 1)
                            end
                        end)
                    end
                end
                task.delay(1, function() S.AutoGrabGun = false end)
            end)
            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -14, 0, 70)
            info.Position = UDim2.new(0, 7, 0, 120)
            info.BackgroundTransparency = 1
            info.Text = "Si eres Innocent:\n1. Activa Silent Aim\n2. Usa 'Conseguir Arma' cuando el Sheriff muera\n3. Dispara y el tiro irá al Murderer"
            info.TextColor3 = Color3.fromRGB(130, 130, 150)
            info.Font = Enum.Font.Gotham
            info.TextSize = 11
            info.TextWrapped = true
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.Parent = Content
        elseif tab == "Murderer" then
            addToggle("AutoStab", "AutoStab", 8)
        elseif tab == "Fling" then
            addBtn("Fling Murderer (Fuerte)", 10, function() flingPlayer("Murderer") end)
            addBtn("Fling Sheriff (Fuerte)", 45, function() flingPlayer("Sheriff") end)
            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -14, 0, 40)
            info.Position = UDim2.new(0, 7, 0, 90)
            info.BackgroundTransparency = 1
            info.Text = "Los manda MUY lejos del mapa de una sola vez."
            info.TextColor3 = Color3.fromRGB(130, 130, 150)
            info.Font = Enum.Font.Gotham
            info.TextSize = 11
            info.TextWrapped = true
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.Parent = Content
        elseif tab == "Utils" then
            addBtn("Teleport Lobby", 10, tpLobby)
            addBtn("Teleport Mapa", 45, tpMap)
            addToggle("Auto Coins", "AutoCoins", 85)
        elseif tab == "Misc" then
            addToggle("Fly", "Fly", 8)
            addToggle("Noclip", "Noclip", 40)
        end
    end

    for i, name in ipairs(tabs) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -12, 0, 26)
        b.Position = UDim2.new(0, 6, 0, 48 + (i-1)*30)
        b.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
        b.Text = "  " .. name
        b.TextColor3 = Color3.fromRGB(200, 200, 215)
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Parent = Side
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function()
            for _, tb in pairs(tabBtns) do tb.BackgroundColor3 = Color3.fromRGB(26, 26, 34) end
            b.BackgroundColor3 = Color3.fromRGB(42, 42, 58)
            load(name)
        end)
        tabBtns[name] = b
    end

    tabBtns["Visuals"].BackgroundColor3 = Color3.fromRGB(42, 42, 58)
    load("Visuals")

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 26, 0, 26)
    MinBtn.Position = UDim2.new(1, -54, 0, 5)
    MinBtn.BackgroundTransparency = 1
    MinBtn.Text = "–"
    MinBtn.TextColor3 = Color3.fromRGB(190, 190, 190)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 18
    MinBtn.Parent = Main
    MinBtn.MouseButton1Click:Connect(function()
        Main.Visible = false
        Mini.Visible = true
    end)

    local Close = Instance.new("TextButton")
    Close.Size = UDim2.new(0, 26, 0, 26)
    Close.Position = UDim2.new(1, -28, 0, 5)
    Close.BackgroundTransparency = 1
    Close.Text = "×"
    Close.TextColor3 = Color3.fromRGB(190, 190, 190)
    Close.Font = Enum.Font.GothamBold
    Close.TextSize = 18
    Close.Parent = Main
    Close.MouseButton1Click:Connect(function() sg.Enabled = false end)

    Mini.MouseButton1Click:Connect(function()
        Main.Visible = true
        Mini.Visible = false
    end)

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

--// Start
createGUI()
print("Loaded! | MM2 - peque yitzchak")

task.spawn(function()
    while true do
        task.wait(0.3)
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
