-- MM2 AutoShoot + ESP (solo Murderer)
-- RightShift = mostrar/ocultar menu

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

local ESP = true
local AutoShoot = false
local FOV = 220
local Delay = 0.12
local lastShot = 0
local Highlights = {}

local function getRole(plr)
    if not plr or not plr.Character then return "Innocent" end
    local c, b = plr.Character, plr:FindFirstChild("Backpack")
    if c:FindFirstChild("Knife") or (b and b:FindFirstChild("Knife")) then return "Murderer" end
    if c:FindFirstChild("Gun") or (b and b:FindFirstChild("Gun")) then return "Sheriff" end
    return "Innocent"
end

local function color(r)
    if r == "Murderer" then return Color3.fromRGB(255, 40, 40) end
    if r == "Sheriff" then return Color3.fromRGB(50, 140, 255) end
    return Color3.fromRGB(60, 220, 80)
end

local function hasGun()
    local c = LocalPlayer.Character
    if not c then return false end
    if c:FindFirstChild("Gun") then return true end
    local b = LocalPlayer:FindFirstChild("Backpack")
    return b and b:FindFirstChild("Gun")
end

local function equipGun()
    local c = LocalPlayer.Character
    if not c or c:FindFirstChild("Gun") then return end
    local b = LocalPlayer:FindFirstChild("Backpack")
    local g = b and b:FindFirstChild("Gun")
    if g then g.Parent = c end
end

local function clearESP()
    for _, h in pairs(Highlights) do if h then h:Destroy() end end
    table.clear(Highlights)
end

local function updateESP()
    if not ESP then clearESP() return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local r = getRole(plr)
            local col = color(r)
            if not Highlights[plr] or not Highlights[plr].Parent then
                local h = Instance.new("Highlight")
                h.FillTransparency = 0.55
                h.OutlineTransparency = 0
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent = CoreGui
                Highlights[plr] = h
            end
            Highlights[plr].Adornee = plr.Character
            Highlights[plr].FillColor = col
            Highlights[plr].OutlineColor = col
        end
    end
end

local function getMurderer()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getRole(plr) == "Murderer" then
            local ch = plr.Character
            if ch and ch:FindFirstChild("HumanoidRootPart") then
                local hum = ch:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    return ch.HumanoidRootPart, ch:FindFirstChild("Head")
                end
            end
        end
    end
end

local function shoot()
    if not AutoShoot or not hasGun() then return end
    if tick() - lastShot < Delay then return end
    local root, head = getMurderer()
    if not root then return end
    local pos = head and head.Position or root.Position
    local sp, on = Camera:WorldToViewportPoint(pos)
    if not on then return end
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    if (center - Vector2.new(sp.X, sp.Y)).Magnitude > FOV then return end
    pcall(function() Camera.CFrame = CFrame.new(Camera.CFrame.Position, pos) end)
    equipGun()
    lastShot = tick()
    pcall(mouse1click)
end

pcall(function()
    local old
    old = hookmetamethod(game, "__index", function(self, key)
        if AutoShoot and not checkcaller() and self == Mouse then
            local root, head = getMurderer()
            if root then
                if key == "Hit" then return head and head.CFrame or root.CFrame end
                if key == "Target" then return head or root end
            end
        end
        return old(self, key)
    end)
end)

task.spawn(function()
    while true do
        task.wait(0.08)
        pcall(updateESP)
        pcall(shoot)
    end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "MM2AS"
sg.ResetOnSpawn = false
pcall(function() sg.Parent = CoreGui end)
if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 210, 0, 145)
Main.Position = UDim2.new(0.5, -105, 0.35, 0)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Main.Active = true
Main.Draggable = true
Main.Parent = sg
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local t = Instance.new("TextLabel")
t.Size = UDim2.new(1, 0, 0, 30)
t.BackgroundTransparency = 1
t.Text = "MM2 AutoShoot"
t.TextColor3 = Color3.new(1,1,1)
t.Font = Enum.Font.GothamBold
t.TextSize = 16
t.Parent = Main

local function makeBtn(txt, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 32)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    b.Text = txt
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    b.Parent = Main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local espB = makeBtn("ESP: ON", 38)
espB.BackgroundColor3 = Color3.fromRGB(40, 120, 70)
espB.MouseButton1Click:Connect(function()
    ESP = not ESP
    espB.Text = ESP and "ESP: ON" or "ESP: OFF"
    espB.BackgroundColor3 = ESP and Color3.fromRGB(40, 120, 70) or Color3.fromRGB(40, 40, 52)
    if not ESP then clearESP() end
end)

local asB = makeBtn("AutoShoot Murderer: OFF", 78)
asB.MouseButton1Click:Connect(function()
    AutoShoot = not AutoShoot
    asB.Text = AutoShoot and "AutoShoot Murderer: ON" or "AutoShoot Murderer: OFF"
    asB.BackgroundColor3 = AutoShoot and Color3.fromRGB(150, 40, 40) or Color3.fromRGB(40, 40, 52)
end)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, -16, 0, 24)
info.Position = UDim2.new(0, 8, 0, 116)
info.BackgroundTransparency = 1
info.Text = "Rojo = Murderer | solo le dispara a el"
info.TextColor3 = Color3.fromRGB(140, 140, 160)
info.Font = Enum.Font.Gotham
info.TextSize = 11
info.Parent = Main

UserInputService.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end)

print("Loaded! | MM2 AutoShoot + ESP")
