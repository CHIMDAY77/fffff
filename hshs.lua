repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

task.wait(3)

-- ==============================================================================
-- 1. TITAN V3 (LITE): ANTI-BAN HOOK (GIỮ NGUYÊN)
-- ==============================================================================
local function EnableTitanV3()
    if not hookmetamethod then return end
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local BlacklistedNames = {"Ban", "Kick", "Punish", "Admin", "Detection", "Security", "Report", "Log", "Cheat", "Exploit", "Flag"}
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() then
            if method == "Kick" or method == "Shutdown" then
                if self == LocalPlayer or self == game then return nil end
            end
            if method == "BreakJoints" and (self == LocalPlayer.Character) then return nil end
            if method == "FireServer" then
                local name = self.Name
                for _, keyword in ipairs(BlacklistedNames) do
                    if string.find(name, keyword) then return nil end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    print("🛡️ TITAN V3: ACTIVE")
end
task.spawn(function() pcall(EnableTitanV3) end)

if getgenv().OxenHub_Loaded then
    game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Oxen Hub", Text = "Already running!", Duration = 3})
    return
end
getgenv().OxenHub_Loaded = true

-- ==============================================================================
-- 2. SETUP UI LIBRARY (RAYFIELD)
-- ==============================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Combat Arena (Mobile Final)",
   Icon = 0,
   LoadingTitle = "Oxen-Hub",
   LoadingSubtitle = "Optimized by K2PN",
   Theme = "Default",
   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,
   ConfigurationSaving = { Enabled = true, FileName = "OxenHub_Mobile_FixUI" }, -- Đổi tên file config để fix lỗi mất nút
   Discord = { Enabled = false, Invite = "", RememberJoins = true },
   KeySystem = false,
})

-- ==============================================================================
-- 3. CẤU HÌNH LOGIC MỚI (V23 ALL-IN-ONE)
-- ==============================================================================
_G.CORE = {
    -- Aim Config
    AimEnabled = false,
    AimReady = false,
    FOV = 130,
    Deadzone = 17, -- Logic mới (17) nhưng dùng Slider cũ để chỉnh
    WallCheck = true,
    Pred = 0.165,
    AssistStrength = 0.4,
    
    -- ESP Config
    EspEnabled = true,
    EspBox = true,
    EspName = true,
    EspFFA = false,
    
    -- System
    ScanRate = 0.05
}

-- Services
local P = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = P.LocalPlayer
local Camera = workspace.CurrentCamera
local Workspace = game:GetService("Workspace")

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- Visuals
local fovCircle = Drawing.new("Circle"); fovCircle.Thickness = 1; fovCircle.NumSides = 40; fovCircle.Filled = false; fovCircle.Color = Color3.fromRGB(255, 255, 255)
local deadCircle = Drawing.new("Circle"); deadCircle.Thickness = 1.5; deadCircle.NumSides = 20; deadCircle.Filled = false; deadCircle.Color = Color3.fromRGB(255, 0, 0)

-- ==============================================================================
-- 4. LOGIC HOẠT ĐỘNG (GIỮ NGUYÊN BẢN MỚI NHẤT)
-- ==============================================================================

-- [HELPERS]
local function CreateESP(char)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not root then return end
    if root:FindFirstChild("MobESP") then root.MobESP:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = "MobESP"; bb.Adornee = root
    bb.Size = UDim2.new(4, 0, 5.5, 0); bb.AlwaysOnTop = true; bb.Parent = root

    local frame = Instance.new("Frame", bb)
    frame.Size = UDim2.new(1, 0, 1, 0); frame.BackgroundTransparency = 1
    local stroke = Instance.new("UIStroke", frame); stroke.Thickness = 1.5

    local txt = Instance.new("TextLabel", bb)
    txt.Size = UDim2.new(1, 0, 0, 20); txt.Position = UDim2.new(0, 0, -0.25, 0)
    txt.BackgroundTransparency = 1; txt.TextColor3 = Color3.new(1, 1, 1)
    txt.TextStrokeTransparency = 0; txt.TextSize = 12; txt.Font = Enum.Font.GothamBold
    bb.Enabled = false 
end

local function IsEnemyPlayer(p)
    if LP.Neutral or p.Neutral then return true end
    if p.Team == nil or LP.Team == nil then return true end
    if p.Team == LP.Team then return false end
    return true
end

local function IsGameBot(model)
    if not model or not model:IsA("Model") or model == LP.Character then return false end
    local hum = model:FindFirstChild("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not root then return false end
    if P:GetPlayerFromCharacter(model) then return false end 
    if model:FindFirstChildOfClass("ForceField") then return false end
    return true
end

local function GetAimPart(char)
    if not char then return nil end
    return char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end

local TargetCache = {} 

-- [THREAD: SCANNER]
task.spawn(function()
    while true do
        local tempAimCache = {}
        local config = _G.CORE
        
        -- Quét Player
        local allPlayers = P:GetPlayers()
        for i = 1, #allPlayers do
            local p = allPlayers[i]
            if p ~= LP and p.Character then
                local char = p.Character
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                
                if root and hum and hum.Health > 0 then
                    -- ESP Logic
                    local espBox = root:FindFirstChild("MobESP")
                    if not espBox then 
                        CreateESP(char)
                    else
                        if config.EspEnabled then
                            espBox.Enabled = true
                            local txt = espBox:FindFirstChild("TextLabel")
                            local frame = espBox:FindFirstChild("Frame")
                            local stroke = frame and frame:FindFirstChild("UIStroke")
                            
                            if txt and stroke then
                                local dist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)
                                txt.Visible = config.EspName
                                txt.Text = string.format("%s\n[%dm]", p.Name, dist)
                                stroke.Enabled = config.EspBox
                                
                                local isEnemy = IsEnemyPlayer(p)
                                local color = Color3.fromRGB(0, 170, 255)
                                if config.EspFFA or isEnemy then
                                    if dist < 15 then color = Color3.fromRGB(255, 255, 0)
                                    else color = Color3.fromRGB(255, 0, 0) end
                                end
                                stroke.Color = color
                                txt.TextColor3 = (config.EspFFA or isEnemy) and Color3.new(1,1,1) or color
                            end
                        else
                            espBox.Enabled = false
                        end
                    end
                    
                    -- Aim Logic
                    if config.AimEnabled and IsEnemyPlayer(p) then
                        local part = GetAimPart(char)
                        if part then tempAimCache[#tempAimCache + 1] = {Part = part, Char = char} end
                    end
                end
            end
        end

        -- Quét Bot
        if config.AimEnabled then
            local wsChildren = Workspace:GetChildren()
            for i = 1, #wsChildren do
                local obj = wsChildren[i]
                if IsGameBot(obj) then
                    local part = GetAimPart(obj)
                    if part then tempAimCache[#tempAimCache + 1] = {Part = part, Char = obj} end
                end
            end
        end

        -- Update Cache
        if config.AimEnabled then
            if not config.AimReady then
                TargetCache = tempAimCache
                task.wait(1.5) 
                config.AimReady = true
            else
                TargetCache = tempAimCache
            end
        else
            config.AimReady = false
            table.clear(TargetCache)
        end
        task.wait(config.ScanRate) 
    end
end)
P.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(CreateESP) end)

-- [RENDER: AIM ENGINE]
local function GetBestTarget()
    local bestPart, bestHRP = nil, nil
    local shortestDist = math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for i = 1, #TargetCache do
        local entry = TargetCache[i]
        local part = entry.Part
        local char = entry.Char
        
        if part and part.Parent then 
            local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                if dist <= _G.CORE.FOV then
                    local visible = true
                    if _G.CORE.WallCheck then
                        rayParams.FilterDescendantsInstances = {LP.Character, char}
                        local hit = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rayParams)
                        if hit and hit.Instance and not hit.Instance:IsDescendantOf(char) then visible = false end
                    end
                    if visible and dist < shortestDist then
                        shortestDist = dist
                        bestPart = part
                        bestHRP = char:FindFirstChild("HumanoidRootPart")
                    end
                end
            end
        end
    end
    return bestPart, bestHRP
end

RS.RenderStepped:Connect(function()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local conf = _G.CORE
    
    if conf.AimEnabled then
        fovCircle.Visible = true; fovCircle.Position = center; fovCircle.Radius = conf.FOV
        deadCircle.Visible = true; deadCircle.Position = center; deadCircle.Radius = conf.Deadzone
        if not conf.AimReady then deadCircle.Color = Color3.fromRGB(255, 255, 0) return
        else deadCircle.Color = Color3.fromRGB(255, 0, 0) end
    else
        fovCircle.Visible = false; deadCircle.Visible = false
        return
    end

    local aimPart, hrp = GetBestTarget()
    if aimPart then deadCircle.Color = Color3.fromRGB(0, 255, 0) end

    if aimPart and hrp then
        local predPos = aimPart.Position + (hrp.Velocity * conf.Pred)
        local dist = (Vector2.new(Camera:WorldToViewportPoint(aimPart.Position).X, Camera:WorldToViewportPoint(aimPart.Position).Y) - center).Magnitude
        if dist <= conf.Deadzone then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, predPos) 
        else
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, predPos), conf.AssistStrength) 
        end
    end
end)

-- ==============================================================================
-- 5. UI MENU STRUCTURE (CẤU TRÚC MENU CŨ + KẾT NỐI LOGIC MỚI)
-- ==============================================================================
local MainTab = Window:CreateTab("Combat", nil)
local MainSection = MainTab:CreateSection("Aim & Visuals")

-- CÁC NÚT CŨ NHƯNG ĐIỀU KHIỂN LOGIC MỚI (_G.CORE)

MainTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Flag = "Aim",
    Callback = function(v) _G.CORE.AimEnabled = v end,
})

MainTab:CreateSlider({
    Name = "FOV (Assist Range)",
    Range = {50, 300}, Increment = 5, CurrentValue = 130,
    Callback = function(v) _G.CORE.FOV = v end,
})

MainTab:CreateSlider({
    Name = "Deadzone (Lock Range)",
    Range = {5, 50}, Increment = 1, CurrentValue = 17,
    Callback = function(v) _G.CORE.Deadzone = v end,
})

MainTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = true,
    Flag = "ESP",
    Callback = function(v) _G.CORE.EspEnabled = v end,
})

MainTab:CreateToggle({
    Name = "FFA Mode (All Red)",
    CurrentValue = false,
    Flag = "FFAMode",
    Callback = function(v) _G.CORE.EspFFA = v end,
})

-- No Recoil (Giữ nguyên logic cũ vì nó độc lập)
MainTab:CreateToggle({
    Name = "No Recoil (Mobile Fix)",
    CurrentValue = false,
    Flag = "Recoil",
    Callback = function(v) 
        _G.NoRecoil = v 
        local BindName = "OxenNoRecoil"
        if v then
            local LastRot = workspace.CurrentCamera.CFrame.Rotation
            RS:BindToRenderStep(BindName, Enum.RenderPriority.Camera.Value + 1, function()
                if not _G.NoRecoil then return end
                local Cam = workspace.CurrentCamera
                local CurRot = Cam.CFrame.Rotation
                local x, y, z = CurRot:ToOrientation()
                local lx, ly, lz = LastRot:ToOrientation()
                local dX = math.deg(x - lx)
                if dX > 0.5 and dX < 15 then
                    Cam.CFrame = CFrame.new(Cam.CFrame.Position) * CFrame.fromOrientation(lx, y, z)
                    LastRot = CFrame.fromOrientation(lx, y, z)
                else
                    LastRot = CurRot
                end
            end)
        else
            pcall(function() RS:UnbindFromRenderStep(BindName) end)
        end
    end,
})

-- SECTION MOVEMENT (GIỮ NGUYÊN)
local MoveSection = MainTab:CreateSection("Movement")

MainTab:CreateSlider({
   Name = "Walkspeed",
   Range = {16, 100}, Increment = 1, CurrentValue = 25,
   Callback = function(v) 
       getgenv().WalkSpeedValue = v
       if not getgenv().SpeedLoop then
           getgenv().SpeedLoop = RS.RenderStepped:Connect(function()
               if LP.Character and LP.Character:FindFirstChild("Humanoid") then
                   LP.Character.Humanoid.WalkSpeed = getgenv().WalkSpeedValue
               end
           end)
       end
   end,
})

MainTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Callback = function(v) 
       _G.InfJump = v
       if not _G.IJConn then
           _G.IJConn = UIS.JumpRequest:Connect(function()
               if _G.InfJump and LP.Character then 
                   LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) 
               end
           end)
       end
   end,
})

-- SMOOTH FLY (GIỮ NGUYÊN)
local FlySettings = {Enabled = false, Speed = 1.5, Smoothness = 0.2, GoingUp = false, GoingDown = false, CurrentVelocity = Vector3.new(0,0,0)}
local MobileFlyUI = nil
local function ToggleMobileFlyUI(bool)
    if bool then
        if MobileFlyUI then MobileFlyUI:Destroy() end
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "OxenFlyUI"
        ScreenGui.Parent = game.CoreGui

        local BtnUp = Instance.new("TextButton", ScreenGui)
        BtnUp.Size = UDim2.new(0, 50, 0, 50); BtnUp.Position = UDim2.new(0, 10, 0.40, 0) 
        BtnUp.BackgroundColor3 = Color3.fromRGB(0, 200, 0); BtnUp.BackgroundTransparency = 0.4
        BtnUp.Text = "UP"; Instance.new("UICorner", BtnUp).CornerRadius = UDim.new(1, 0)

        local BtnDown = Instance.new("TextButton", ScreenGui)
        BtnDown.Size = UDim2.new(0, 50, 0, 50); BtnDown.Position = UDim2.new(0, 10, 0.40, 60) 
        BtnDown.BackgroundColor3 = Color3.fromRGB(200, 0, 0); BtnDown.BackgroundTransparency = 0.4
        BtnDown.Text = "DN"; Instance.new("UICorner", BtnDown).CornerRadius = UDim.new(1, 0)

        BtnUp.InputBegan:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingUp = true end end)
        BtnUp.InputEnded:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingUp = false end end)
        BtnDown.InputBegan:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingDown = true end end)
        BtnDown.InputEnded:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingDown = false end end)
        MobileFlyUI = ScreenGui
    else
        if MobileFlyUI then MobileFlyUI:Destroy() end
        MobileFlyUI = nil; FlySettings.GoingUp = false; FlySettings.GoingDown = false
        FlySettings.CurrentVelocity = Vector3.new(0,0,0)
    end
end
local NoclipConn = nil
RS.RenderStepped:Connect(function()
    if not FlySettings.Enabled then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return end
    root.Velocity = Vector3.zero
    local moveDir = hum.MoveDirection
    local targetDir = Vector3.new(moveDir.X, 0, moveDir.Z) * FlySettings.Speed
    if FlySettings.GoingUp then targetDir = targetDir + Vector3.new(0, FlySettings.Speed, 0)
    elseif FlySettings.GoingDown then targetDir = targetDir + Vector3.new(0, -FlySettings.Speed, 0) end
    FlySettings.CurrentVelocity = FlySettings.CurrentVelocity:Lerp(targetDir, FlySettings.Smoothness)
    if FlySettings.CurrentVelocity.Magnitude > 0.01 then root.CFrame = root.CFrame + FlySettings.CurrentVelocity
    else FlySettings.CurrentVelocity = Vector3.zero end
    hum.PlatformStand = true 
end)

MainTab:CreateToggle({
    Name = "Smooth Fly (Side UI + Noclip)",
    CurrentValue = false,
    Flag = "FlyMode",
    Callback = function(v)
        FlySettings.Enabled = v
        ToggleMobileFlyUI(v) 
        if v then
            if NoclipConn then NoclipConn:Disconnect() end
            NoclipConn = RS.Stepped:Connect(function()
                if LP.Character then
                    for _, part in pairs(LP.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                    end
                end
            end)
        else
            if NoclipConn then NoclipConn:Disconnect() end
            NoclipConn = nil
            if LP.Character then
                local hum = LP.Character:FindFirstChild("Humanoid")
                if hum then hum.PlatformStand = false end
                workspace.Gravity = 196.2
                for _, part in pairs(LP.Character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end
    end,
})
MainTab:CreateSlider({Name = "Fly Speed", Range = {0.5, 5}, Increment = 0.1, CurrentValue = 1.5, Callback = function(v) FlySettings.Speed = v end})

-- GARBAGE COLLECTOR (QUÉT SÓT)
task.spawn(function()
    while true do
        for _, p in ipairs(P:GetPlayers()) do
            if p ~= LP and p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if root and not root:FindFirstChild("MobESP") then CreateESP(p.Character) end
            end
        end
        task.wait(3)
    end
end)
