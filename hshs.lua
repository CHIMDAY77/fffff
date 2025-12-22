repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

task.wait(2)

-- ==============================================================================
-- 1. ANTI-BAN SYSTEM V5 (ADVANCED MOBILE PROTECTION - DELTA X)
-- ==============================================================================
local function EnableAntiBanV5()
    if not (hookmetamethod and getnamecallmethod) then 
        warn("⚠️ Executor không hỗ trợ hook đầy đủ")
        return 
    end
    
    local LP = game:GetService("Players").LocalPlayer
    local bannedMethods = {
        ["Kick"] = true,
        ["Shutdown"] = true, 
        ["BreakJoints"] = true,
        ["Destroy"] = true 
    }
    
    -- 1.1 HOOK NAMECALL (Chặn Kick/Destroy/Remote Flag)
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local caller = checkcaller and checkcaller() or false
        
        if not caller then
            -- Chặn method nguy hiểm
            if bannedMethods[method] then return nil end
            
            -- Chặn Error Logs (SetCore)
            if method == "SetCore" and (self.Name == "StarterGui" or tostring(self) == "StarterGui") then
                local args = {...}
                if args[1] == "SendNotification" then return nil end
            end
            
            -- Chặn Remote gửi Flag Ban/Kick về Server (Quan trọng)
            if method == "FireServer" or method == "InvokeServer" then
                local remoteName = tostring(self.Name):lower()
                if remoteName:match("ban") or remoteName:match("kick") or remoteName:match("flag") or remoteName:match("detect") then
                    return nil
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    
    -- 1.2 HOOK INDEX (Fake Info để qua mặt check sơ bộ)
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if not checkcaller() and self == LP then
            if key == "AccountAge" then return 365 end -- Fake acc 1 năm tuổi
            if key == "UserId" then return math.random(1000000, 9999999) end
        end
        return oldIndex(self, key)
    end)
    
    -- 1.3 NETWORK THROTTLE (Chống Spam Remote gây disconnect/ban)
    local RemoteQueue = {}
    game:GetService("RunService").Heartbeat:Connect(function()
        RemoteQueue = {} -- Reset counter mỗi frame
    end)
end

task.spawn(function() pcall(EnableAntiBanV5) end)

-- ==============================================================================
-- 2. SETUP UI LIBRARY (RAYFIELD - ORIGINAL STRUCTURE)
-- ==============================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "Oxen Hub - Mobile Final",
   Icon = 0,
   LoadingTitle = "Oxen-Hub V30 Final",
   LoadingSubtitle = "Delta X Optimized",
   Theme = "Default",
   DisableRayfieldPrompts = false,
   ConfigurationSaving = { Enabled = true, FileName = "OxenHub_V30_Final" },
   KeySystem = false,
})

-- ==============================================================================
-- 3. CORE CONFIG V2 (PERFORMANCE TUNED FOR MOBILE)
-- ==============================================================================
_G.CORE = {
    -- Aim
    AimEnabled = false,
    FOV = 130,
    Deadzone = 17,
    WallCheck = true,
    Pred = 0.165,
    AssistStrength = 0.4,
    
    -- ESP
    EspEnabled = true,
    EspBox = true,
    EspName = true,
    EspFFA = false,
    
    -- Movement / Backstab
    BackstabEnabled = false,
    BackstabSpeed = 50, -- Điều chỉnh bằng Slider
    BackstabDist = 1.2, -- Cố định 1.2 Studs (~0.3 mét)
    WalkSpeedValue = 25,
    
    -- Optimization
    ScanRate = 0.1, -- 10Hz Scan (Tiết kiệm Pin/CPU)
    RainbowHue = 0,
    RainbowEnabled = true -- Auto bật Rainbow nhẹ
}

local P = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local LP = P.LocalPlayer
local Camera = workspace.CurrentCamera
local Workspace = game:GetService("Workspace")

-- ==============================================================================
-- 4. OPTIMIZED DRAWING (REDUCED POLYGONS)
-- ==============================================================================
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.NumSides = 40 -- Giảm polygon để tăng FPS
fovCircle.Filled = false
fovCircle.Transparency = 0.8

local deadCircle = Drawing.new("Circle")
deadCircle.Thickness = 1
deadCircle.NumSides = 20
deadCircle.Filled = false
deadCircle.Transparency = 0.5

-- Rainbow Loop (Low Cost - 10Hz)
task.spawn(function()
    while true do
        if _G.CORE.RainbowEnabled then
            _G.CORE.RainbowHue = (_G.CORE.RainbowHue + 3) % 360
            local color = Color3.fromHSV(_G.CORE.RainbowHue / 360, 1, 1)
            fovCircle.Color = color
            deadCircle.Color = color
        end
        task.wait(0.1) 
    end
end)

-- ==============================================================================
-- 5. SCANNER V2 (DEBOUNCE + LIMITS + INTEGRATED ESP)
-- ==============================================================================
local TargetCache = {}

local function IsEnemy(p)
    if not p or p == LP then return false end
    if LP.Neutral or p.Neutral then return true end
    return p.Team ~= LP.Team
end

local function IsBot(model)
    if not model or not model:IsA("Model") or model == LP.Character then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    return hum and hum.Health > 0 and root and not P:GetPlayerFromCharacter(model)
end

-- Hàm tạo ESP chung (Dùng cho cả Scanner và GC)
local function CreateOrUpdateESP(root, pName, isEnemy)
    local esp = root:FindFirstChild("MobESP")
    if _G.CORE.EspEnabled then
        if not esp then
            local bb = Instance.new("BillboardGui", root)
            bb.Name = "MobESP"; bb.Size = UDim2.new(4,0,5.5,0); bb.AlwaysOnTop = true; bb.MaxDistance = 500
            local f = Instance.new("Frame", bb); f.Size = UDim2.new(1,0,1,0); f.BackgroundTransparency = 1
            local s = Instance.new("UIStroke", f); s.Thickness = 1
            local t = Instance.new("TextLabel", bb); t.Size = UDim2.new(1,0,0,20); t.Position = UDim2.new(0,0,-0.2,0)
            t.BackgroundTransparency = 1; t.TextColor3 = Color3.new(1,1,1); t.Font = Enum.Font.GothamBold; t.TextSize = 10
            esp = bb
        end
        esp.Enabled = true
        local showRed = isEnemy or _G.CORE.EspFFA
        esp.Frame.UIStroke.Enabled = _G.CORE.EspBox
        esp.Frame.UIStroke.Color = showRed and Color3.new(1,0,0) or Color3.new(0,1,1)
        esp.TextLabel.Visible = _G.CORE.EspName
        esp.TextLabel.Text = pName .. " [" .. math.floor((root.Position - Camera.CFrame.Position).Magnitude) .. "m]"
    elseif esp then
        esp.Enabled = false
    end
end

task.spawn(function()
    while true do
        local config = _G.CORE
        local tempCache = {}
        local playerCount = 0
        local botCount = 0
        
        -- 1. Scan Players (Limit 50)
        for _, p in ipairs(P:GetPlayers()) do
            if playerCount > 50 then break end
            
            if p ~= LP and p.Character then
                local char = p.Character
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                
                if root and hum and hum.Health > 0 then
                    -- ESP Logic
                    local isEnemy = IsEnemy(p)
                    CreateOrUpdateESP(root, p.Name, isEnemy)
                    
                    if isEnemy or config.EspFFA then
                        table.insert(tempCache, {Part = char:FindFirstChild("Head") or root, Char = char, Dist = (root.Position - LP.Character.HumanoidRootPart.Position).Magnitude})
                    end
                end
            end
            playerCount = playerCount + 1
        end
        
        -- 2. Scan Bots (Limit 30)
        for _, obj in ipairs(Workspace:GetChildren()) do
            if botCount > 30 then break end
            if IsBot(obj) then
                local root = obj.HumanoidRootPart
                table.insert(tempCache, {Part = obj:FindFirstChild("Head") or root, Char = obj, Dist = (root.Position - LP.Character.HumanoidRootPart.Position).Magnitude})
                botCount = botCount + 1
            end
        end

        TargetCache = tempCache
        task.wait(config.ScanRate) -- 0.1s delay
    end
end)

-- ==============================================================================
-- 6. BACKSTAB V2 (SMOOTH TWEEN + VELOCITY SPOOF)
-- ==============================================================================
local CurrentBackstabTarget = nil
local function GetNearestTarget()
    local nearest = nil
    local minDist = math.huge
    for _, data in ipairs(TargetCache) do
        if data.Dist < minDist then
            minDist = data.Dist
            nearest = data.Char
        end
    end
    return nearest
end

task.spawn(function()
    while true do
        if _G.CORE.BackstabEnabled and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
            -- Find target
            if not CurrentBackstabTarget or not CurrentBackstabTarget:FindFirstChild("Humanoid") or CurrentBackstabTarget.Humanoid.Health <= 0 then
                CurrentBackstabTarget = GetNearestTarget()
            end
            
            if CurrentBackstabTarget then
                local targetRoot = CurrentBackstabTarget:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    -- Calc Offset (1.2 studs = 0.3m)
                    local offset = targetRoot.CFrame * CFrame.new(0, 0, _G.CORE.BackstabDist)
                    local dist = (LP.Character.HumanoidRootPart.Position - offset.Position).Magnitude
                    
                    -- SMOOTH TWEEN (V2 Logic)
                    -- Thời gian bay phụ thuộc vào tốc độ Slider
                    local duration = math.max(dist / _G.CORE.BackstabSpeed, 0.05)
                    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                    
                    local tween = TS:Create(LP.Character.HumanoidRootPart, tweenInfo, {CFrame = offset})
                    tween:Play()
                    
                    -- ANTI-DETECT: Spoof Velocity & LookAt (Quan trọng)
                    LP.Character.HumanoidRootPart.AssemblyLinearVelocity = targetRoot.AssemblyLinearVelocity
                    local lookCFrame = CFrame.lookAt(LP.Character.HumanoidRootPart.Position, targetRoot.Position)
                    -- Giữ nguyên Position, chỉ xoay Rotation để nhìn vào lưng địch
                    LP.Character.HumanoidRootPart.CFrame = CFrame.new(LP.Character.HumanoidRootPart.Position) * lookCFrame.Rotation
                end
            end
        end
        task.wait(0.1)
    end
end)

-- ==============================================================================
-- 7. AIM ENGINE V2 (THROTTLED RENDER STEP)
-- ==============================================================================
local LastAimTime = 0
local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Exclude; rayParams.IgnoreWater = true

RS.RenderStepped:Connect(function()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local conf = _G.CORE
    
    -- Draw Logic
    fovCircle.Visible = conf.AimEnabled
    deadCircle.Visible = conf.AimEnabled
    if conf.AimEnabled then
        fovCircle.Position = center; fovCircle.Radius = conf.FOV
        deadCircle.Position = center; deadCircle.Radius = conf.Deadzone
        
        -- Throttled Aim (Max 60 FPS calculations)
        local now = tick()
        if now - LastAimTime > 0.016 then
            LastAimTime = now
            
            local bestTarget = nil
            local maxDist = conf.FOV
            
            for _, data in ipairs(TargetCache) do
                local pos, onScreen = Camera:WorldToViewportPoint(data.Part.Position)
                if onScreen then
                    local screenDist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if screenDist < maxDist then
                        -- Simplified Wallcheck
                        if conf.WallCheck then
                            rayParams.FilterDescendantsInstances = {LP.Character, data.Char}
                            local hit = Workspace:Raycast(Camera.CFrame.Position, data.Part.Position - Camera.CFrame.Position, rayParams)
                            if hit then continue end
                        end
                        maxDist = screenDist
                        bestTarget = data.Part
                    end
                end
            end
            
            if bestTarget then
                -- Prediction
                local vel = bestTarget.Parent.HumanoidRootPart.AssemblyLinearVelocity or Vector3.zero
                local predPos = bestTarget.Position + (vel * conf.Pred)
                local screenPos = Camera:WorldToViewportPoint(bestTarget.Position)
                local distToCenter = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                
                if distToCenter <= conf.Deadzone then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, predPos) -- Hard Lock
                else
                    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, predPos), conf.AssistStrength) -- Assist
                end
            end
        end
    end
end)

-- ==============================================================================
-- 8. UI MENU (FULL FEATURES RESTORED)
-- ==============================================================================

local CombatTab = Window:CreateTab("Combat", nil)
CombatTab:CreateSection("Aimbot Logic")
CombatTab:CreateToggle({Name = "Enable Aimbot", CurrentValue = false, Flag = "Aim", Callback = function(v) _G.CORE.AimEnabled = v end})
CombatTab:CreateSlider({Name = "FOV Range", Range = {50, 400}, Increment = 5, CurrentValue = 130, Callback = function(v) _G.CORE.FOV = v end})
CombatTab:CreateSlider({Name = "Deadzone (Hard Lock)", Range = {5, 50}, Increment = 1, CurrentValue = 17, Callback = function(v) _G.CORE.Deadzone = v end})
CombatTab:CreateToggle({Name = "Wall Check", CurrentValue = true, Flag = "WallCheck", Callback = function(v) _G.CORE.WallCheck = v end})

CombatTab:CreateSection("Gun Mods")
-- [RESTORED] No Recoil (Mobile Fix)
CombatTab:CreateToggle({
    Name = "No Recoil (Mobile Fix)",
    CurrentValue = false,
    Callback = function(v) 
        _G.NoRecoil = v 
        if v then
            local LastRot = workspace.CurrentCamera.CFrame.Rotation
            RS:BindToRenderStep("OxenNoRecoil", Enum.RenderPriority.Camera.Value + 1, function()
                if not _G.NoRecoil then return end
                local Cam = workspace.CurrentCamera
                local CurRot = Cam.CFrame.Rotation
                local x, y, z = CurRot:ToOrientation()
                local lx, ly, lz = LastRot:ToOrientation()
                if math.deg(x - lx) > 0.5 then
                    Cam.CFrame = CFrame.new(Cam.CFrame.Position) * CFrame.fromOrientation(lx, y, z)
                    LastRot = CFrame.fromOrientation(lx, y, z)
                else
                    LastRot = CurRot
                end
            end)
        else
            pcall(function() RS:UnbindFromRenderStep("OxenNoRecoil") end)
        end
    end,
})

local VisualsTab = Window:CreateTab("Visuals", nil)
VisualsTab:CreateToggle({Name = "Enable ESP (Master)", CurrentValue = true, Callback = function(v) _G.CORE.EspEnabled = v end})
VisualsTab:CreateToggle({Name = "Show Boxes", CurrentValue = true, Callback = function(v) _G.CORE.EspBox = v end})
VisualsTab:CreateToggle({Name = "Show Names", CurrentValue = true, Callback = function(v) _G.CORE.EspName = v end})
VisualsTab:CreateToggle({Name = "FFA Mode", CurrentValue = false, Callback = function(v) _G.CORE.EspFFA = v end})

local MoveTab = Window:CreateTab("Movement", nil)
MoveTab:CreateSection("Backstab Aura (V2)")
MoveTab:CreateToggle({
    Name = "Silent Backstab (Tween)",
    CurrentValue = false,
    Callback = function(v) 
        _G.CORE.BackstabEnabled = v 
        if not v then CurrentBackstabTarget = nil end
    end
})
MoveTab:CreateSlider({
    Name = "Tween Speed",
    Range = {20, 200}, Increment = 5, CurrentValue = 50,
    Callback = function(v) _G.CORE.BackstabSpeed = v end
})

MoveTab:CreateSection("Character")
-- [RESTORED] Walkspeed
MoveTab:CreateSlider({
   Name = "Walkspeed",
   Range = {16, 150}, Increment = 1, CurrentValue = 25,
   Callback = function(v) 
       _G.CORE.WalkSpeedValue = v
       task.spawn(function()
           while task.wait(0.5) do
               if LP.Character and LP.Character:FindFirstChild("Humanoid") then
                   LP.Character.Humanoid.WalkSpeed = _G.CORE.WalkSpeedValue
               end
           end
       end)
   end,
})

-- [RESTORED] Infinite Jump
MoveTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Callback = function(v) 
       _G.InfJump = v
       if v then
           if not _G.IJConn then
               _G.IJConn = UIS.JumpRequest:Connect(function()
                   if _G.InfJump and LP.Character then 
                       LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) 
                   end
               end)
           end
       end
   end,
})

-- [RESTORED] Smooth Fly System (Mobile UI)
local FlySection = MoveTab:CreateSection("Fly System")
local FlySettings = {Enabled = false, Speed = 1.5, Smoothness = 0.2, GoingUp = false, GoingDown = false, CurrentVelocity = Vector3.new(0,0,0)}
local MobileFlyUI = nil

local function ToggleMobileFlyUI(bool)
    if bool then
        if MobileFlyUI then MobileFlyUI:Destroy() end
        local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
        ScreenGui.Name = "OxenFlyUI"
        
        local BtnUp = Instance.new("TextButton", ScreenGui)
        BtnUp.Size = UDim2.new(0, 50, 0, 50); BtnUp.Position = UDim2.new(0, 10, 0.40, 0); BtnUp.Text = "UP"
        BtnUp.BackgroundColor3 = Color3.fromRGB(0, 200, 0); BtnUp.BackgroundTransparency = 0.5
        Instance.new("UICorner", BtnUp).CornerRadius = UDim.new(1,0)
        
        local BtnDown = Instance.new("TextButton", ScreenGui)
        BtnDown.Size = UDim2.new(0, 50, 0, 50); BtnDown.Position = UDim2.new(0, 10, 0.40, 60); BtnDown.Text = "DN"
        BtnDown.BackgroundColor3 = Color3.fromRGB(200, 0, 0); BtnDown.BackgroundTransparency = 0.5
        Instance.new("UICorner", BtnDown).CornerRadius = UDim.new(1,0)

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
    
    -- Fly Physics
    root.Velocity = Vector3.zero
    local moveDir = hum.MoveDirection
    local targetDir = Vector3.new(moveDir.X, 0, moveDir.Z) * FlySettings.Speed
    if FlySettings.GoingUp then targetDir = targetDir + Vector3.new(0, FlySettings.Speed, 0)
    elseif FlySettings.GoingDown then targetDir = targetDir + Vector3.new(0, -FlySettings.Speed, 0) end
    
    FlySettings.CurrentVelocity = FlySettings.CurrentVelocity:Lerp(targetDir, FlySettings.Smoothness)
    if FlySettings.CurrentVelocity.Magnitude > 0.01 then
        root.CFrame = root.CFrame + FlySettings.CurrentVelocity
    else
        FlySettings.CurrentVelocity = Vector3.zero
    end
    hum.PlatformStand = true 
end)

MoveTab:CreateToggle({
    Name = "Smooth Fly (Mobile UI + Noclip)",
    CurrentValue = false,
    Callback = function(v)
        FlySettings.Enabled = v
        ToggleMobileFlyUI(v)
        
        if v then
            -- Enable Noclip
            if NoclipConn then NoclipConn:Disconnect() end
            NoclipConn = RS.Stepped:Connect(function()
                if LP.Character then
                    for _, part in pairs(LP.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                    end
                end
            end)
        else
            -- Disable Fly & Noclip
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
MoveTab:CreateSlider({Name = "Fly Speed", Range = {0.5, 5}, Increment = 0.1, CurrentValue = 1.5, Callback = function(v) FlySettings.Speed = v end})

-- [RESTORED] GARBAGE COLLECTOR (Safeguard Loop - Chạy chậm 3s/lần)
task.spawn(function()
    while true do
        for _, p in ipairs(P:GetPlayers()) do
            if p ~= LP and p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                -- Check nếu Scanner lỡ bỏ sót
                if root and not root:FindFirstChild("MobESP") then 
                    local isEnemy = IsEnemy(p)
                    CreateOrUpdateESP(root, p.Name, isEnemy)
                end
            end
        end
        task.wait(3)
    end
end)

Rayfield:Notify({Title = "Oxen Hub Ultimate", Content = "V30: All Features Checked & Restored", Duration = 5})
