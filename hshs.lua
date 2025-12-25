--[[
    PROJECT: OXEN HUB - ULTIMATE REMASTER
    BASE: K2PN (Original V55)
    MODIFIED: AI (Smart Trigger Aimbot + Highlight ESP)
    TARGET: Mobile (Delta, Fluxus, Hydrogen)
]]

--------------------------------------------------------------------------------
-- // [PHẦN 0] KHỞI TẠO & MÔI TRƯỜNG (INIT - GIỮ NGUYÊN BẢN GỐC)
--------------------------------------------------------------------------------

local executor = identifyexecutor and identifyexecutor() or "Unknown"

if not getgenv().OxenInit then
    warn("[OXEN BOOT] System Initialized on: " .. executor)
    getgenv().OxenInit = true
end

if not getgenv then
    getgenv = function() return _G end
end

if getgenv().OxenLoaded then
    if _G.OxenConnections then
        for i, conn in pairs(_G.OxenConnections) do
            if conn then conn:Disconnect() end
        end
    end
    table.clear(_G.OxenConnections)
end

getgenv().OxenLoaded = true
getgenv()._G.OxenConnections = {} 

--------------------------------------------------------------------------------
-- // [PHẦN 1] CẤU HÌNH (SETTINGS)
--------------------------------------------------------------------------------

getgenv()._G.OXEN_SETTINGS = {
    CORE = {
        ScanRate = 0.05,
        TeamCheck = true,
        TargetPart = "HumanoidRootPart"
    },
    AIM = {
        Enabled = false,
        FOV_Radius = 150,
        Smoothness = 0.2, -- 0.1 (Rất mượt) -> 1 (Khóa cứng)
        TriggerBot = true, -- Chỉ aim khi bắn
        WallCheck = true
    },
    HBE = {
        Enabled = false,
        Size = 15,
        Transparency = 0.6,
        Color = Color3.fromRGB(255, 0, 0)
    },
    BACKSTAB = {
        Enabled = false,
        Distance = 4.5,
        GhostMode = true,
        FFA = false
    },
    VISUALS = {
        ESP_Enabled = true,
        Highlight = true, -- Dùng công nghệ mới
        FillColor = Color3.fromRGB(255, 0, 0),
        OutlineColor = Color3.fromRGB(255, 255, 255)
    },
    MOVEMENT = {
        SpeedEnabled = false,
        WalkSpeed = 16,
        JumpEnabled = false,
        JumpPower = 50,
        Fly = { Enabled = false, Speed = 60 },
        NoRecoil = { Enabled = false }
    }
}

--------------------------------------------------------------------------------
-- // [PHẦN 2] DỊCH VỤ (SERVICES)
--------------------------------------------------------------------------------

local Services = {
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    GuiService = game:GetService("GuiService"),
    CoreGui = game:GetService("CoreGui")
}

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

-- Cache lưu trữ
getgenv()._G.TargetCache = {}
local ScreenSize = Camera.ViewportSize

local ViewportConn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    ScreenSize = Camera.ViewportSize
end)
table.insert(_G.OxenConnections, ViewportConn)

--------------------------------------------------------------------------------
-- // [PHẦN 3] BẢO MẬT & HOOK (GIỮ NGUYÊN TITAN V5 TỪ BẢN GỐC)
--------------------------------------------------------------------------------

task.spawn(function()
    pcall(function()
        if not getrawmetatable then return end
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local oldIndex = mt.__index
        local oldNamecall = mt.__namecall
        
        -- Hook __index: Fake Size cho HBE (Tránh Anti-Cheat quét size nhân vật)
        mt.__index = newcclosure(function(self, key)
            if not checkcaller() then
                if key == "Size" and self:IsA("BasePart") and self.Name == "HumanoidRootPart" then
                    return Vector3.new(2, 2, 1) -- Luôn trả về size chuẩn
                end
                if key == "WalkSpeed" and self:IsA("Humanoid") then return 16 end
                if key == "JumpPower" and self:IsA("Humanoid") then return 50 end
            end
            return oldIndex(self, key)
        end)
        
        -- Hook __namecall: Anti-Kick
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "Kick" or method == "kick" or method == "Shutdown" then
                return nil 
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end)
end)

--------------------------------------------------------------------------------
-- // [PHẦN 4] HỖ TRỢ & LOGIC MỚI (AIMBOT & ESP)
--------------------------------------------------------------------------------

-- 4.1. Helper Functions
local function IsAlive(player)
    if not player or not player.Character then return false end
    local hum = player.Character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function IsTeam(player)
    if player == LocalPlayer then return true end
    if _G.OXEN_SETTINGS.BACKSTAB.FFA then return false end
    if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then return true end
    return false
end

local function IsVisible(targetChar)
    if not _G.OXEN_SETTINGS.AIM.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end
    
    local parts = Camera:GetPartsObscuringTarget({targetRoot.Position}, {LocalPlayer.Character, targetChar})
    return #parts == 0
end

-- 4.2. ESP Engine Mới (Highlight - Siêu nhẹ)
local HighlightStorage = {}

local function UpdateESP()
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            
            -- Logic Highlight
            if _G.OXEN_SETTINGS.VISUALS.ESP_Enabled then
                local hl = char:FindFirstChild("OxenHighlight")
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "OxenHighlight"
                    hl.Adornee = char
                    hl.Parent = char
                end
                
                if IsTeam(player) then
                    hl.FillColor = Color3.fromRGB(0, 255, 0) -- Đồng đội màu xanh
                else
                    hl.FillColor = _G.OXEN_SETTINGS.VISUALS.FillColor -- Địch màu đỏ
                end
                
                hl.OutlineColor = _G.OXEN_SETTINGS.VISUALS.OutlineColor
                hl.FillTransparency = 0.5
                hl.OutlineTransparency = 0
                hl.Enabled = true
            else
                local hl = char:FindFirstChild("OxenHighlight")
                if hl then hl.Enabled = false end
            end
        end
    end
end

local ESPLoop = Services.RunService.RenderStepped:Connect(UpdateESP)
table.insert(_G.OxenConnections, ESPLoop)

-- 4.3. Trigger Aimbot Engine (Logic Mới)
local isFiring = false

-- Detect input bắn (Mobile Touch + PC Mouse)
Services.UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isFiring = true
    end
end)

Services.UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isFiring = false
    end
end)

local function GetSmartTarget()
    local bestTarget = nil
    local shortestDist = _G.OXEN_SETTINGS.AIM.FOV_Radius
    local mousePos = Services.UserInputService:GetMouseLocation()

    for _, player in pairs(Services.Players:GetPlayers()) do
        if IsAlive(player) and not IsTeam(player) then
            local char = player.Character
            local part = char:FindFirstChild(_G.OXEN_SETTINGS.CORE.TargetPart) or char:FindFirstChild("Head")
            
            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    -- Kiểm tra WallCheck
                    if IsVisible(char) then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            bestTarget = part
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

local AimbotLoop = Services.RunService.RenderStepped:Connect(function()
    -- Logic Trigger: Chỉ Aim khi đang bắn (isFiring) VÀ Aim bật
    if _G.OXEN_SETTINGS.AIM.Enabled and isFiring then
        local targetPart = GetSmartTarget()
        if targetPart then
            local currentCF = Camera.CFrame
            local targetCF = CFrame.new(currentCF.Position, targetPart.Position)
            
            -- Dùng Lerp để xoay mượt, không giật cục
            Camera.CFrame = currentCF:Lerp(targetCF, _G.OXEN_SETTINGS.AIM.Smoothness)
        end
    end
end)
table.insert(_G.OxenConnections, AimbotLoop)

--------------------------------------------------------------------------------
-- // [PHẦN 5] TÍNH NĂNG CỐT LÕI KHÁC (GIỮ NGUYÊN BẢN GỐC)
--------------------------------------------------------------------------------

-- 5.1. Hitbox Expander (HBE)
-- Giữ nguyên logic HBE logic vì nó kết hợp tốt với Hook bảo mật
local HBELoop = task.spawn(function()
    while task.wait(0.1) do
        if _G.OXEN_SETTINGS.HBE.Enabled then
            for _, p in pairs(Services.Players:GetPlayers()) do
                if p ~= LocalPlayer and IsAlive(p) and not IsTeam(p) then
                    local root = p.Character:FindFirstChild("HumanoidRootPart")
                    if root and root.Size.X ~= _G.OXEN_SETTINGS.HBE.Size then
                        root.Size = Vector3.new(_G.OXEN_SETTINGS.HBE.Size, _G.OXEN_SETTINGS.HBE.Size, _G.OXEN_SETTINGS.HBE.Size)
                        root.Transparency = _G.OXEN_SETTINGS.HBE.Transparency
                        root.Color = _G.OXEN_SETTINGS.HBE.Color
                        root.CanCollide = false
                        root.Material = Enum.Material.Neon
                    end
                end
            end
        end
    end
end)

-- 5.2. Backstab (Logic V3 - Auto Face)
local BackstabConn = Services.RunService.Heartbeat:Connect(function()
    if not _G.OXEN_SETTINGS.BACKSTAB.Enabled or not LocalPlayer.Character then return end
    
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    
    local closest, minDist = nil, 15 -- Phạm vi kích hoạt backstab
    
    for _, p in pairs(Services.Players:GetPlayers()) do
        if p ~= LocalPlayer and IsAlive(p) and not IsTeam(p) then
            local tRoot = p.Character.HumanoidRootPart
            local dist = (tRoot.Position - myRoot.Position).Magnitude
            if dist < minDist then
                minDist = dist
                closest = tRoot
            end
        end
    end
    
    if closest then
        local backPos = (closest.CFrame * CFrame.new(0, 0, _G.OXEN_SETTINGS.BACKSTAB.Distance)).Position
        local lookAt = Vector3.new(closest.Position.X, backPos.Y, closest.Position.Z)
        
        myRoot.CFrame = CFrame.lookAt(backPos, lookAt)
        myRoot.Velocity = Vector3.zero -- Chống trượt
    end
end)
table.insert(_G.OxenConnections, BackstabConn)

-- 5.3. Mobile Fly UI & Logic
local FlyUI = nil
local function ToggleFly(state)
    if state then
        if not FlyUI then
            local sg = Instance.new("ScreenGui", game:GetService("CoreGui"))
            local fr = Instance.new("Frame", sg)
            fr.Size = UDim2.new(0, 100, 0, 120)
            fr.Position = UDim2.new(0.05, 0, 0.3, 0)
            fr.BackgroundTransparency = 1
            
            local function mkBtn(txt, pos, var)
                local b = Instance.new("TextButton", fr)
                b.Size = UDim2.new(1,0,0.45,0)
                b.Position = pos
                b.Text = txt
                b.BackgroundColor3 = Color3.new(0.1,0.1,0.1)
                b.TextColor3 = Color3.new(1,1,1)
                b.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then _G[var]=true end end)
                b.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then _G[var]=false end end)
            end
            mkBtn("UP", UDim2.new(0,0,0,0), "FlyUp")
            mkBtn("DOWN", UDim2.new(0,0,0.55,0), "FlyDown")
            FlyUI = sg
        end
        FlyUI.Enabled = true
        
        -- Fly Logic
        task.spawn(function()
            while _G.OXEN_SETTINGS.MOVEMENT.Fly.Enabled do
                local rs = Services.RunService.RenderStepped:Wait()
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local root = char.HumanoidRootPart
                    local hum = char.Humanoid
                    hum.PlatformStand = true
                    
                    local vel = Vector3.zero
                    if hum.MoveDirection.Magnitude > 0 then
                        vel = Camera.CFrame.LookVector * _G.OXEN_SETTINGS.MOVEMENT.Fly.Speed
                    end
                    if _G.FlyUp then vel = vel + Vector3.new(0, _G.OXEN_SETTINGS.MOVEMENT.Fly.Speed, 0) end
                    if _G.FlyDown then vel = vel + Vector3.new(0, -_G.OXEN_SETTINGS.MOVEMENT.Fly.Speed, 0) end
                    
                    root.Velocity = vel
                end
            end
        end)
    else
        if FlyUI then FlyUI.Enabled = false end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.PlatformStand = false
        end
    end
end

--------------------------------------------------------------------------------
-- // [PHẦN 6] UI LIBRARY (RAYFIELD - GIỮ NGUYÊN)
--------------------------------------------------------------------------------

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Oxen Hub | Ultimate Remaster",
    LoadingTitle = "Optimizing...",
    LoadingSubtitle = "AI Powered",
    ConfigurationSaving = { Enabled = true, FolderName = "OxenRemaster", FileName = "Config" },
    KeySystem = false
})

-- TAB 1: COMBAT
local CombatTab = Window:CreateTab("Combat", 4483362458)

CombatTab:CreateSection("Smart Aimbot (Trigger)")
CombatTab:CreateToggle({
    Name = "Enable Trigger Aimbot",
    CurrentValue = false,
    Callback = function(Value) _G.OXEN_SETTINGS.AIM.Enabled = Value end,
})
CombatTab:CreateSlider({
    Name = "Smoothness (0.1 = Fast)",
    Range = {0.05, 1},
    Increment = 0.05,
    CurrentValue = 0.2,
    Callback = function(Value) _G.OXEN_SETTINGS.AIM.Smoothness = Value end,
})
CombatTab:CreateSlider({
    Name = "FOV Radius",
    Range = {50, 500},
    Increment = 10,
    CurrentValue = 150,
    Callback = function(Value) _G.OXEN_SETTINGS.AIM.FOV_Radius = Value end,
})

CombatTab:CreateSection("Hitbox Expander")
CombatTab:CreateToggle({
    Name = "Enable HBE",
    CurrentValue = false,
    Callback = function(Value) _G.OXEN_SETTINGS.HBE.Enabled = Value end,
})
CombatTab:CreateSlider({
    Name = "Hitbox Size",
    Range = {2, 30},
    Increment = 1,
    CurrentValue = 15,
    Callback = function(Value) _G.OXEN_SETTINGS.HBE.Size = Value end,
})

-- TAB 2: VISUALS
local VisualTab = Window:CreateTab("Visuals", 4483362458)
VisualTab:CreateSection("ESP Highlight (No Lag)")
VisualTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = true,
    Callback = function(Value) _G.OXEN_SETTINGS.VISUALS.ESP_Enabled = Value end,
})

-- TAB 3: MOVEMENT
local MoveTab = Window:CreateTab("Movement", 4483362458)
MoveTab:CreateSection("Features")
MoveTab:CreateToggle({
    Name = "Mobile Fly (UI)",
    CurrentValue = false,
    Callback = function(Value) 
        _G.OXEN_SETTINGS.MOVEMENT.Fly.Enabled = Value 
        ToggleFly(Value)
    end,
})
MoveTab:CreateToggle({
    Name = "Auto Backstab",
    CurrentValue = false,
    Callback = function(Value) _G.OXEN_SETTINGS.BACKSTAB.Enabled = Value end,
})
MoveTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 300},
    Increment = 1,
    CurrentValue = 16,
    Callback = function(Value) 
        _G.OXEN_SETTINGS.MOVEMENT.SpeedEnabled = true
        if LocalPlayer.Character then LocalPlayer.Character.Humanoid.WalkSpeed = Value end
    end,
})

Rayfield:LoadConfiguration()
warn("OXEN HUB REMASTER LOADED")
