--[[
    SCRIPT NAME: Oxen Hub - Mobile Final
    VERSION: V42 (Restored Aim & Anti-Ban Logic)
    EXECUTOR: Delta X / Hydrogen / Fluxus
    
    [ RESTORATION LOG ]
    1. AIMBOT ENGINE:
       - Reverted to `obfasl.lua` Logic completely.
       - Fixed FOV/Deadzone Circle visibility issues on Delta X.
       - Colors: FOV = Blue, Deadzone = Green (Ready) / Red (Locked).
       
    2. ANTI-BAN (TITAN V4):
       - Restored original Titan V4 Hooking logic.
       - Removed V5 experimental hooks causing conflicts.
       
    3. BACKSTAB (STICKY V3):
       - Kept the improved sticky tracking & auto-switch logic.
       
    4. OPTIMIZATION:
       - Shared Cache architecture.
       - Garbage Collector included.
]]

repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer
task.wait(2)

-- ==============================================================================
-- [SECTION 1] SERVICES
-- ==============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Cache
local FindFirstChild = game.FindFirstChild
local FindFirstChildOfClass = game.FindFirstChildOfClass
local WaitForChild = game.WaitForChild
local WorldToViewportPoint = Camera.WorldToViewportPoint

-- ==============================================================================
-- [SECTION 2] CORE CONFIGURATION
-- ==============================================================================
_G.CORE = {
    -- Aim Config
    AimEnabled = false,
    AimReady = false,
    FOV = 110,
    Deadzone = 17,
    WallCheck = true,
    Pred = 0.165,
    AssistStrength = 0.4,
    
    -- Visuals
    EspEnabled = true,
    EspBox = true,
    EspName = true,
    EspFFA = false,
    
    -- Backstab
    BackstabEnabled = false,
    BackstabSpeed = 50,
    BackstabDist = 1.2,
    
    -- Movement
    WalkSpeedValue = 25,
    InfiniteJump = false,
    
    -- System
    ScanRate = 0.05
}

-- ==============================================================================
-- [SECTION 3] ANTI-BAN TITAN V4 (RESTORED FROM OBFASL.LUA)
-- ==============================================================================
local function EnableTitanV4()
    if not hookmetamethod then return end

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()

        if not checkcaller() then
            -- 1. CHẶN KICK/SHUTDOWN
            if method == "Kick" or method == "Shutdown" then
                return nil 
            end
            
            -- 2. CHẶN TỰ HỦY (BreakJoints)
            if method == "BreakJoints" and self == LocalPlayer.Character then
                return nil
            end
            
            -- 3. CHẶN BÁO LỖI (Error Logging)
            if method == "SetCore" and self.Name == "StarterGui" then
                local args = {...}
                if args[1] == "SendNotification" then
                    return nil
                end
            end
        end

        return oldNamecall(self, ...)
    end)
end
task.spawn(function() pcall(EnableTitanV4) end)

-- ==============================================================================
-- [SECTION 4] DRAWING LOGIC (RESTORED FROM OBFASL.LUA)
-- ==============================================================================
-- Khai báo trực tiếp, không wrap, đảm bảo hiện trên Delta X
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.NumSides = 40
fovCircle.Filled = false
fovCircle.Color = Color3.fromRGB(0, 170, 255) -- Xanh Dương
fovCircle.Transparency = 1
fovCircle.Visible = false

local deadCircle = Drawing.new("Circle")
deadCircle.Thickness = 1.5
deadCircle.NumSides = 24
deadCircle.Filled = false
deadCircle.Color = Color3.fromRGB(0, 255, 0) -- Xanh Lá
deadCircle.Transparency = 1
deadCircle.Visible = false

-- ==============================================================================
-- [SECTION 5] SCANNER SYSTEM (HYBRID V3)
-- ==============================================================================
local TargetCache = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- Helper Functions
local function IsEnemy(p)
    if not p or p == LocalPlayer then return false end
    if LocalPlayer.Neutral or p.Neutral then return true end
    if not p.Team or not LocalPlayer.Team then return true end
    return p.Team ~= LocalPlayer.Team
end

local function IsGameBot(model)
    if not model or not model:IsA("Model") or model == LocalPlayer.Character then return false end
    local hum = FindFirstChild(model, "Humanoid")
    local root = FindFirstChild(model, "HumanoidRootPart")
    if not hum or hum.Health <= 0 or not root then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    if FindFirstChildOfClass(model, "ForceField") then return false end
    return true
end

local function GetAimPart(char)
    if not char then return nil end
    return FindFirstChild(char, "Head") or 
           FindFirstChild(char, "UpperTorso") or 
           FindFirstChild(char, "HumanoidRootPart") or 
           FindFirstChild(char, "Torso")
end

local function CreateESP(char)
    local root = WaitForChild(char, "HumanoidRootPart", 5)
    if not root then return end
    if root:FindFirstChild("MobESP") then root.MobESP:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = "MobESP"; bb.Adornee = root
    bb.Size = UDim2.new(4, 0, 5.5, 0); bb.AlwaysOnTop = true; bb.Parent = root
    bb.MaxDistance = 500

    local frame = Instance.new("Frame", bb)
    frame.Size = UDim2.new(1, 0, 1, 0); frame.BackgroundTransparency = 1
    local stroke = Instance.new("UIStroke", frame); stroke.Thickness = 1.5

    local txt = Instance.new("TextLabel", bb)
    txt.Size = UDim2.new(1, 0, 0, 20); txt.Position = UDim2.new(0, 0, -0.25, 0)
    txt.BackgroundTransparency = 1; txt.TextColor3 = Color3.new(1, 1, 1)
    txt.TextStrokeTransparency = 0; txt.TextSize = 10; txt.Font = Enum.Font.GothamBold
    bb.Enabled = false 
end

-- Scanner Loop
task.spawn(function()
    while true do
        local tempCache = {}
        local config = _G.CORE
        local lpPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.zero
        
        -- 1. Scan Players
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local char = p.Character
                local root = FindFirstChild(char, "HumanoidRootPart")
                local hum = FindFirstChild(char, "Humanoid")
                
                if root and hum and hum.Health > 0 then
                    -- ESP Logic
                    local espBox = FindFirstChild(root, "MobESP")
                    if not espBox then CreateESP(char)
                    else
                        if config.EspEnabled then
                            espBox.Enabled = true
                            local txt = FindFirstChild(espBox, "TextLabel")
                            local frame = FindFirstChild(espBox, "Frame")
                            local stroke = frame and FindFirstChild(frame, "UIStroke")
                            
                            if txt and stroke then
                                local dist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)
                                txt.Visible = config.EspName
                                txt.Text = string.format("%s\n[%dm]", p.Name, dist)
                                stroke.Enabled = config.EspBox
                                
                                local isE = IsEnemy(p)
                                local col = Color3.fromRGB(0, 255, 255)
                                if config.EspFFA or isE then col = Color3.fromRGB(255, 0, 0) end
                                stroke.Color = col
                                txt.TextColor3 = (config.EspFFA or isE) and Color3.new(1,1,1) or col
                            end
                        else
                            espBox.Enabled = false
                        end
                    end
                    
                    -- Aim Cache
                    if IsEnemy(p) or config.EspFFA then
                        local part = GetAimPart(char)
                        if part then
                            table.insert(tempCache, {
                                Part = part, Char = char, Root = root, Humanoid = hum, Dist = (root.Position - lpPos).Magnitude
                            })
                        end
                    end
                end
            end
        end
        
        -- 2. Scan Bots
        for _, obj in ipairs(Workspace:GetChildren()) do
            if IsGameBot(obj) then
                local root = FindFirstChild(obj, "HumanoidRootPart")
                local hum = FindFirstChild(obj, "Humanoid")
                if root and hum then
                    local part = GetAimPart(obj)
                    if part then
                        table.insert(tempCache, {
                            Part = part, Char = obj, Root = root, Humanoid = hum, Dist = (root.Position - lpPos).Magnitude
                        })
                    end
                end
            end
        end

        TargetCache = tempCache
        
        -- Warmup Check
        if config.AimEnabled then
            if not config.AimReady then
                task.wait(1.5)
                config.AimReady = true
            end
        else
            config.AimReady = false
        end
        task.wait(config.ScanRate)
    end
end)

Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function(c) task.wait(1); CreateESP(c) end) end)

-- ==============================================================================
-- [SECTION 6] AIM ENGINE (RESTORED LOGIC)
-- ==============================================================================
local function GetBestTarget()
    local bestPart, bestHRP = nil, nil
    local shortestDist = math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for i = 1, #TargetCache do
        local entry = TargetCache[i]
        local part = entry.Part
        local char = entry.Char
        
        if part and part.Parent then 
            local pos, onScreen = WorldToViewportPoint(Camera, part.Position)
            if onScreen then
                local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                if dist <= _G.CORE.FOV then
                    local visible = true
                    if _G.CORE.WallCheck then
                        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, char}
                        local hit = Workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rayParams)
                        if hit and hit.Instance and not hit.Instance:IsDescendantOf(char) then visible = false end
                    end
                    if visible and dist < shortestDist then
                        shortestDist = dist
                        bestPart = part
                        bestHRP = entry.Root
                    end
                end
            end
        end
    end
    return bestPart, bestHRP
end

RunService.RenderStepped:Connect(function()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local conf = _G.CORE
    
    if conf.AimEnabled then
        fovCircle.Visible = true; fovCircle.Position = center; fovCircle.Radius = conf.FOV
        deadCircle.Visible = true; deadCircle.Position = center; deadCircle.Radius = conf.Deadzone
        
        if not conf.AimReady then 
            deadCircle.Color = Color3.fromRGB(255, 255, 0) -- Yellow (Waiting)
        else 
            deadCircle.Color = Color3.fromRGB(0, 255, 0)   -- Green (Ready)
        end
    else
        fovCircle.Visible = false; deadCircle.Visible = false
        return
    end

    if conf.AimReady then
        local aimPart, hrp = GetBestTarget()
        
        if aimPart and hrp then
            deadCircle.Color = Color3.fromRGB(255, 0, 0) -- Red (Locked)
            
            local predPos = aimPart.Position + (hrp.AssemblyLinearVelocity * conf.Pred)
            local screenPos = WorldToViewportPoint(Camera, aimPart.Position)
            local distToCenter = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            
            if distToCenter <= conf.Deadzone then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, predPos)
            else
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, predPos), conf.AssistStrength)
            end
        end
    end
end)

-- ==============================================================================
-- [SECTION 7] BACKSTAB SYSTEM (STICKY & AUTO SWITCH)
-- ==============================================================================
local CurrentBS_Target = nil

local function GetNearestBackstab()
    local bestChar, minDist = nil, math.huge
    for i = 1, #TargetCache do
        local d = TargetCache[i]
        if d.Dist < minDist then
            minDist = d.Dist
            bestChar = d.Char
        end
    end
    return bestChar
end

RunService.Heartbeat:Connect(function()
    if not _G.CORE.BackstabEnabled then 
        CurrentBS_Target = nil
        return 
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and FindFirstChild(myChar, "HumanoidRootPart")
    
    if not myRoot then return end

    -- Validation
    if CurrentBS_Target then
        local hum = FindFirstChild(CurrentBS_Target, "Humanoid")
        local root = FindFirstChild(CurrentBS_Target, "HumanoidRootPart")
        if not hum or hum.Health <= 0 or not root or not CurrentBS_Target.Parent then
            CurrentBS_Target = nil 
        end
    end
    
    -- Acquisition
    if not CurrentBS_Target then
        CurrentBS_Target = GetNearestBackstab()
    end
    
    -- Execution
    if CurrentBS_Target then
        local tRoot = FindFirstChild(CurrentBS_Target, "HumanoidRootPart")
        if tRoot then
            local backOffset = CFrame.new(0, 0, _G.CORE.BackstabDist)
            local targetCFrame = tRoot.CFrame * backOffset
            local dist = (myRoot.Position - targetCFrame.Position).Magnitude
            local speed = math.max(_G.CORE.BackstabSpeed, 20)
            local duration = math.max(dist / speed, 0.03)
            
            if dist > 0.5 then
                local tInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
                local tween = TweenService:Create(myRoot, tInfo, {CFrame = targetCFrame})
                tween:Play()
            else
                myRoot.CFrame = myRoot.CFrame:Lerp(targetCFrame, 0.5)
            end
            
            myRoot.AssemblyLinearVelocity = tRoot.AssemblyLinearVelocity
            local lookPos = Vector3.new(tRoot.Position.X, myRoot.Position.Y, tRoot.Position.Z)
            myRoot.CFrame = CFrame.lookAt(myRoot.Position, lookPos)
        end
    end
end)

-- ==============================================================================
-- [SECTION 8] UI INTERFACE (RAYFIELD)
-- ==============================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "Oxen Hub - Mobile Final",
   Icon = 0,
   LoadingTitle = "Oxen-Hub V42",
   LoadingSubtitle = "Restored Edition",
   Theme = "Default",
   DisableRayfieldPrompts = false,
   ConfigurationSaving = { Enabled = true, FileName = "OxenHub_V42_Restored" },
   KeySystem = false,
})

-- === TAB 1: COMBAT ===
local CombatTab = Window:CreateTab("Combat", nil)
CombatTab:CreateSection("Aimbot")

CombatTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Flag = "Aim",
    Callback = function(v) _G.CORE.AimEnabled = v end,
})

CombatTab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = true,
    Flag = "WallCheck",
    Callback = function(v) _G.CORE.WallCheck = v end,
})

CombatTab:CreateSection("Gun Mods")
CombatTab:CreateToggle({
    Name = "No Recoil (Mobile Fix)",
    CurrentValue = false,
    Flag = "Recoil",
    Callback = function(v) 
        _G.NoRecoil = v 
        if v then
            local LastRot = workspace.CurrentCamera.CFrame.Rotation
            RunService:BindToRenderStep("OxenNoRecoil", Enum.RenderPriority.Camera.Value + 1, function()
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
            pcall(function() RunService:UnbindFromRenderStep("OxenNoRecoil") end)
        end
    end,
})

-- === TAB 2: VISUALS ===
local VisualsTab = Window:CreateTab("Visuals", nil)
VisualsTab:CreateSection("ESP Settings")

VisualsTab:CreateToggle({
    Name = "Bật ESP (Master)",
    CurrentValue = true,
    Flag = "ESP",
    Callback = function(v) _G.CORE.EspEnabled = v; _G.CORE.EspBox = v; _G.CORE.EspName = v end,
})

VisualsTab:CreateToggle({Name = "Show Boxes", CurrentValue = true, Callback = function(v) _G.CORE.EspBox = v end})
VisualsTab:CreateToggle({Name = "Show Names", CurrentValue = true, Callback = function(v) _G.CORE.EspName = v end})
VisualsTab:CreateToggle({Name = "FFA Mode", CurrentValue = false, Callback = function(v) _G.CORE.EspFFA = v end})

-- === TAB 3: MOVEMENT ===
local MoveTab = Window:CreateTab("Movement", nil)

MoveTab:CreateSection("Backstab (Sticky)")
MoveTab:CreateToggle({
    Name = "Silent Backstab",
    CurrentValue = false,
    Callback = function(v) _G.CORE.BackstabEnabled = v; if not v then CurrentBS_Target = nil end end
})
MoveTab:CreateSlider({
    Name = "Tween Speed",
    Range = {20, 200}, Increment = 5, CurrentValue = 50,
    Callback = function(v) _G.CORE.BackstabSpeed = v end
})

MoveTab:CreateSection("Character")
MoveTab:CreateSlider({
   Name = "Walkspeed",
   Range = {16, 150}, Increment = 1, CurrentValue = 25,
   Callback = function(v) 
       _G.CORE.WalkSpeedValue = v
       task.spawn(function()
           while task.wait(0.5) do
               if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                   LocalPlayer.Character.Humanoid.WalkSpeed = v
               end
           end
       end)
   end,
})

MoveTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Callback = function(v) 
       _G.InfJump = v
       if v and not _G.IJConn then
           _G.IJConn = UserInputService.JumpRequest:Connect(function()
               if _G.InfJump and LocalPlayer.Character then 
                   LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) 
               end
           end)
       end
   end,
})

-- FLY UI
local FlySettings = {Enabled = false, Speed = 1.5, GoingUp = false, GoingDown = false, CurrentVelocity = Vector3.new(0,0,0)}
local MobileFlyUI = nil

local function ToggleMobileFlyUI(bool)
    if bool then
        if MobileFlyUI then MobileFlyUI:Destroy() end
        local ScreenGui = Instance.new("ScreenGui", CoreGui); ScreenGui.Name = "OxenFlyUI"
        local BtnUp = Instance.new("TextButton", ScreenGui); BtnUp.Size = UDim2.new(0, 50, 0, 50); BtnUp.Position = UDim2.new(0, 10, 0.40, 0); BtnUp.Text = "UP"; BtnUp.BackgroundColor3 = Color3.fromRGB(0, 200, 0); BtnUp.BackgroundTransparency = 0.4; Instance.new("UICorner", BtnUp).CornerRadius = UDim.new(1, 0)
        local BtnDown = Instance.new("TextButton", ScreenGui); BtnDown.Size = UDim2.new(0, 50, 0, 50); BtnDown.Position = UDim2.new(0, 10, 0.40, 60); BtnDown.Text = "DN"; BtnDown.BackgroundColor3 = Color3.fromRGB(200, 0, 0); BtnDown.BackgroundTransparency = 0.4; Instance.new("UICorner", BtnDown).CornerRadius = UDim.new(1, 0)
        BtnUp.InputBegan:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingUp = true end end)
        BtnUp.InputEnded:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingUp = false end end)
        BtnDown.InputBegan:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingDown = true end end)
        BtnDown.InputEnded:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingDown = false end end)
        MobileFlyUI = ScreenGui
    else
        if MobileFlyUI then MobileFlyUI:Destroy() end
        MobileFlyUI = nil; FlySettings.GoingUp = false; FlySettings.GoingDown = false; FlySettings.CurrentVelocity = Vector3.new(0,0,0)
    end
end
local NoclipConn = nil
RunService.RenderStepped:Connect(function()
    if not FlySettings.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return end
    
    root.Velocity = Vector3.zero
    local moveDir = hum.MoveDirection
    local targetDir = Vector3.new(moveDir.X, 0, moveDir.Z) * FlySettings.Speed
    if FlySettings.GoingUp then targetDir = targetDir + Vector3.new(0, FlySettings.Speed, 0)
    elseif FlySettings.GoingDown then targetDir = targetDir + Vector3.new(0, -FlySettings.Speed, 0) end
    FlySettings.CurrentVelocity = FlySettings.CurrentVelocity:Lerp(targetDir, 0.2)
    root.CFrame = root.CFrame + FlySettings.CurrentVelocity
    hum.PlatformStand = true 
end)

MoveTab:CreateSection("Fly System")
MoveTab:CreateToggle({
    Name = "Smooth Fly (Mobile UI + Noclip)",
    CurrentValue = false,
    Callback = function(v)
        FlySettings.Enabled = v; ToggleMobileFlyUI(v) 
        if v then
            if NoclipConn then NoclipConn:Disconnect() end
            NoclipConn = RunService.Stepped:Connect(function()
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                    end
                end
            end)
        else
            if NoclipConn then NoclipConn:Disconnect() end; NoclipConn = nil
            if LocalPlayer.Character then
                local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
                if hum then hum.PlatformStand = false end
                workspace.Gravity = 196.2
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end
    end,
})
MoveTab:CreateSlider({Name = "Fly Speed", Range = {0.5, 5}, Increment = 0.1, CurrentValue = 1.5, Callback = function(v) FlySettings.Speed = v end})

-- GARBAGE COLLECTOR
task.spawn(function()
    while true do
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if root and not root:FindFirstChild("MobESP") then CreateESP(p.Character) end
            end
        end
        task.wait(3) 
    end
end)

Rayfield:Notify({Title = "Oxen Hub Final", Content = "V42: Fully Restored & Optimized", Duration = 5})
