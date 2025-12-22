

-- Wait for Game
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer

-- ==============================================================================
-- SERVICES & OPTIMIZATION
-- ==============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Cache Functions for Speed (Lua optimization)
local Vector2_new = Vector2.new
local Vector3_new = Vector3.new
local CFrame_new = CFrame.new
local Color3_fromRGB = Color3.fromRGB
local math_floor = math.floor
local math_rad = math.rad
local math_tan = math.tan
local FindFirstChild = game.FindFirstChild
local FindFirstChildOfClass = game.FindFirstChildOfClass
local WaitForChild = game.WaitForChild
local WorldToViewportPoint = Camera.WorldToViewportPoint

-- ==============================================================================
-- CUSTOM VISUAL LIBRARY (REPLACES DRAWING.NEW)
-- ==============================================================================
-- This library uses ScreenGui, which is native to Roblox and NEVER glitches on Delta.
local OxenVisualLib = {}
local VisFolder = Instance.new("ScreenGui")
VisFolder.Name = "OxenVisuals_V45"
VisFolder.IgnoreGuiInset = true
VisFolder.ResetOnSpawn = false
VisFolder.Parent = CoreGui

-- Function to create a circle using UIStroke
function OxenVisualLib.CreateCircle()
    local CircleObj = {}
    
    local Frame = Instance.new("Frame")
    Frame.Name = "VisualCircle"
    Frame.BackgroundTransparency = 1
    Frame.AnchorPoint = Vector2_new(0.5, 0.5)
    Frame.BorderSizePixel = 0
    Frame.Visible = false
    Frame.Parent = VisFolder
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(1, 0) -- Make it round
    Corner.Parent = Frame
    
    local Stroke = Instance.new("UIStroke")
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.LineJoinMode = Enum.LineJoinMode.Round
    Stroke.Transparency = 0
    Stroke.Parent = Frame
    
    -- Properties Interface
    local props = {
        Visible = false,
        Position = Vector2_new(0, 0),
        Radius = 100,
        Color = Color3_fromRGB(255, 255, 255),
        Thickness = 1,
        Filled = false -- UIStroke acts as outline
    }
    
    function CircleObj:SetVisible(bool)
        props.Visible = bool
        Frame.Visible = bool
    end
    
    function CircleObj:Update(pos, radius, color, thickness)
        -- Update Position
        Frame.Position = UDim2.new(0, pos.X, 0, pos.Y)
        -- Update Size (Radius * 2 = Diameter)
        Frame.Size = UDim2.new(0, radius * 2, 0, radius * 2)
        -- Update Color & Thickness
        Stroke.Color = color
        Stroke.Thickness = thickness
        Stroke.Transparency = 0.3 -- Slight transparency for aesthetics
    end
    
    function CircleObj:Remove()
        Frame:Destroy()
    end
    
    return CircleObj
end

-- ==============================================================================
-- CORE CONFIGURATION
-- ==============================================================================
_G.CORE = {
    -- Aimbot
    AimEnabled = false,
    AimPart = "HumanoidRootPart",
    FOV = 120,
    ShowFOV = false,
    Deadzone = 25, -- Vùng chết ở giữa
    ShowDeadzone = false,
    Smoothness = 0.1, -- 0 = Instant, 1 = Very Slow
    WallCheck = true,
    TeamCheck = false,
    
    -- ESP
    EspEnabled = true,
    EspBox = true,
    EspName = true,
    EspHealth = true,
    EspTracer = false,
    
    -- Backstab (Sticky)
    Backstab = false,
    BackstabDist = 4, -- Studs behind
    BackstabSpeed = 0.15, -- Seconds
    
    -- Misc
    WalkSpeed = 16,
    JumpPower = 50,
    NoRecoil = false,
    Fly = false,
    FlySpeed = 20,
    InfiniteJump = false
}

-- ==============================================================================
-- ANTI-BAN TITAN V4 (STABLE HOOK)
-- ==============================================================================
local function InitTitanV4()
    -- Check support
    if not hookmetamethod then 
        warn("Executor does not support HookMetamethod!")
        return 
    end

    local OldNamecall
    OldNamecall = hookmetamethod(game, "__namecall", function(Self,...)
        local Method = getnamecallmethod()
        local Args = {...}
        
        -- Block Kicks & Bans from Game Scripts
        if not checkcaller() then
            if Method == "Kick" or Method == "Ban" or Method == "Shutdown" then
                return nil -- Pretend we kicked, but do nothing
            end
            
            -- Prevent Error Logging
            if Method == "FireServer" and tostring(Self) == "ErrorLog" then
                return nil
            end
            
            -- Block WalkSpeed detection if game reads it via Attribute
            if Method == "GetAttribute" and Args[1] == "WalkSpeed" then
                return 16 
            end
        end
        
        return OldNamecall(Self,...)
    end)
    
    -- Hook Index for extra safety (Properties)
    local OldIndex
    OldIndex = hookmetamethod(game, "__index", function(Self, Key)
        if not checkcaller() and Self == LocalPlayer.Character and Key == "HumanoidRootPart" then
            -- Optional: Return fake CFrame if needed (Anti-Teleport logs)
        end
        return OldIndex(Self, Key)
    end)
    
    print("Titan V4: Protection Active")
end
task.spawn(InitTitanV4)

-- ==============================================================================
-- HIGH-SPEED SCANNER (ATOMIC CACHE)
-- ==============================================================================
-- GLOBAL CACHE VARIABLE
_G.TargetCache = {} 

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

-- Utility: Is Valid Target
local function IsValidTarget(Player)
    if not Player or Player == LocalPlayer then return false end
    if _G.CORE.TeamCheck and Player.Team == LocalPlayer.Team then return false end
    
    local Char = Player.Character
    if not Char then return false end
    
    local Hum = FindFirstChild(Char, "Humanoid")
    local Root = FindFirstChild(Char, "HumanoidRootPart")
    
    if not Hum or Hum.Health <= 0 or not Root then return false end
    
    -- Check ForceField (Immunity)
    if FindFirstChildOfClass(Char, "ForceField") then return false end
    
    return true, Char, Root, Hum
end

-- HEARTBEAT SCANNER LOOP (Runs every physics frame - Super Fast)
RunService.Heartbeat:Connect(function()
    local StartTime = os.clock()
    local NewCache = {} -- Temporary table
    local MousePos = UserInputService:GetMouseLocation()
    
    -- Update Filter for WallCheck
    local FilterList = {LocalPlayer.Character, Camera}
    
    for _, Plr in ipairs(Players:GetPlayers()) do
        local Valid, Char, Root, Hum = IsValidTarget(Plr)
        
        if Valid then
            -- Calculate Screen Position HERE (Once per frame for all modules)
            local ScreenPos, OnScreen = WorldToViewportPoint(Camera, Root.Position)
            local Vector2Pos = Vector2_new(ScreenPos.X, ScreenPos.Y)
            local DistFromMouse = (Vector2Pos - MousePos).Magnitude
            local DistFromChar = (Root.Position - Camera.CFrame.Position).Magnitude
            
            -- Determine if Visible (WallCheck)
            local IsVisible = true
            if _G.CORE.WallCheck then
                RayParams.FilterDescendantsInstances = {LocalPlayer.Character, Char}
                local Dir = (Root.Position - Camera.CFrame.Position)
                local Result = Workspace:Raycast(Camera.CFrame.Position, Dir, RayParams)
                if Result then IsVisible = false end
            end
            
            -- Insert into New Cache
            table.insert(NewCache, {
                Player = Plr,
                Character = Char,
                Root = Root,
                Humanoid = Hum,
                ScreenPos = Vector2Pos,
                OnScreen = OnScreen,
                DistMouse = DistFromMouse,
                Dist3D = DistFromChar,
                Visible = IsVisible
            })
        end
    end
    
    -- ATOMIC SWAP: Replace old cache with new one instantly
    -- Lua Garbage Collector will handle the old table automatically
    _G.TargetCache = NewCache
end)

-- ==============================================================================
-- AIMBOT ENGINE (HYBRID CALCULATION)
-- ==============================================================================
local function GetBestTarget()
    local BestTarget = nil
    local ShortestDist = _G.CORE.FOV -- Start with Max FOV
    
    for _, Data in pairs(_G.TargetCache) do
        -- Only target if OnScreen and Visible (if check enabled)
        if Data.OnScreen then
            if not _G.CORE.WallCheck or Data.Visible then
                -- Check Deadzone
                if Data.DistMouse > _G.CORE.Deadzone then
                    if Data.DistMouse < ShortestDist then
                        ShortestDist = Data.DistMouse
                        BestTarget = Data
                    end
                end
            end
        end
    end
    
    return BestTarget
end

RunService.RenderStepped:Connect(function()
    if _G.CORE.AimEnabled then
        local Target = GetBestTarget()
        if Target then
            local AimPos = Target.Root.Position
            -- Simple prediction
            local Velocity = Target.Root.AssemblyLinearVelocity
            AimPos = AimPos + (Velocity * 0.05) -- Light prediction
            
            -- Camera Smoothing
            local CurrentCF = Camera.CFrame
            local TargetCF = CFrame_new(CurrentCF.Position, AimPos)
            
            Camera.CFrame = CurrentCF:Lerp(TargetCF, _G.CORE.Smoothness)
        end
    end
end)

-- ==============================================================================
-- VISUAL ENGINE (USING CUSTOM LIB)
-- ==============================================================================
-- Create Persistent Visual Objects
local FOV_Circle = OxenVisualLib.CreateCircle()
local DZ_Circle = OxenVisualLib.CreateCircle()

RunService.RenderStepped:Connect(function()
    local MouseLoc = UserInputService:GetMouseLocation()
    
    -- Update FOV Circle
    if _G.CORE.ShowFOV and _G.CORE.AimEnabled then
        FOV_Circle:SetVisible(true)
        FOV_Circle:Update(
            MouseLoc, 
            _G.CORE.FOV, 
            Color3_fromRGB(0, 170, 255), -- Blue
            1.5
        )
    else
        FOV_Circle:SetVisible(false)
    end
    
    -- Update Deadzone Circle
    if _G.CORE.ShowDeadzone and _G.CORE.AimEnabled then
        DZ_Circle:SetVisible(true)
        DZ_Circle:Update(
            MouseLoc,
            _G.CORE.Deadzone,
            Color3_fromRGB(255, 50, 50), -- Red
            1
        )
    else
        DZ_Circle:SetVisible(false)
    end
end)

-- ==============================================================================
-- ESP ENGINE (OPTIMIZED POOLING)
-- ==============================================================================
-- Handling ESP without creating objects every frame
local ESP_Holder = Instance.new("Folder", CoreGui)
ESP_Holder.Name = "OxenESP_Storage"

local function UpdateESP()
    -- Clear Invalid ESPs
    for _, Child in pairs(ESP_Holder:GetChildren()) do
        if not Players:GetPlayerByUserId(tonumber(Child.Name)) then
            Child:Destroy()
        end
    end
    
    if not _G.CORE.EspEnabled then 
        ESP_Holder:ClearAllChildren()
        return 
    end
    
    -- Iterate Cache
    for _, Data in pairs(_G.TargetCache) do
        local UserId = tostring(Data.Player.UserId)
        local Box = ESP_Holder:FindFirstChild(UserId)
        
        if not Box then
            -- Create New Box if not exists
            Box = Instance.new("Frame")
            Box.Name = UserId
            Box.Parent = ESP_Holder
            Box.BackgroundTransparency = 1
            
            local Stroke = Instance.new("UIStroke", Box)
            Stroke.Thickness = 1.5
            Stroke.Color = Color3_fromRGB(0, 255, 0)
            
            local NameTag = Instance.new("TextLabel", Box)
            NameTag.BackgroundTransparency = 1
            NameTag.TextColor3 = Color3_fromRGB(255, 255, 255)
            NameTag.TextSize = 12
            NameTag.TextStrokeTransparency = 0
            NameTag.Position = UDim2.new(0, 0, 0, -15)
            NameTag.Size = UDim2.new(1, 0, 0, 15)
        end
        
        -- Update Box Logic
        if Data.OnScreen then
            Box.Visible = true
            
            -- Calculate Box Size (Perspective)
            local ScaleFactor = 3000 / Data.Dist3D
            local Width = 2.5 * ScaleFactor
            local Height = 4.5 * ScaleFactor
            
            Box.Position = UDim2.new(0, Data.ScreenPos.X - Width/2, 0, Data.ScreenPos.Y - Height/2)
            Box.Size = UDim2.new(0, Width, 0, Height)
            
            local NameLabel = Box:FindFirstChild("TextLabel")
            if NameLabel then
                NameLabel.Text = string.format("%s [%dm]", Data.Player.Name, math_floor(Data.Dist3D))
                NameLabel.Visible = _G.CORE.EspName
            end
            
            Box:FindFirstChild("UIStroke").Enabled = _G.CORE.EspBox
        else
            Box.Visible = false
        end
    end
end
RunService.RenderStepped:Connect(UpdateESP)

-- ==============================================================================
-- BACKSTAB V3 (STICKY & AUTO-SWITCH)
-- ==============================================================================
local CurrentTarget = nil

-- Loop Backstab Logic
task.spawn(function()
    while true do
        if _G.CORE.Backstab then
            -- 1. Validate Current Target
            if CurrentTarget then
                local IsValid = false
                -- Check if target is still in our Cache (Fast check)
                for _, Data in pairs(_G.TargetCache) do
                    if Data.Player == CurrentTarget then
                        IsValid = true
                        break
                    end
                end
                if not IsValid then CurrentTarget = nil end
            end
            
            -- 2. Find New Target if None
            if not CurrentTarget then
                local BestDst = math.huge
                for _, Data in pairs(_G.TargetCache) do
                    if Data.Dist3D < BestDst then
                        BestDst = Data.Dist3D
                        CurrentTarget = Data.Player
                    end
                end
            end
            
            -- 3. Execute Movement
            if CurrentTarget and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local TargetChar = CurrentTarget.Character
                if TargetChar and TargetChar:FindFirstChild("HumanoidRootPart") then
                    local TRoot = TargetChar.HumanoidRootPart
                    local MyRoot = LocalPlayer.Character.HumanoidRootPart
                    
                    -- Calculate Behind Position
                    local BehindCFrame = TRoot.CFrame * CFrame_new(0, 0, _G.CORE.BackstabDist)
                    
                    -- Check Distance
                    local Dist = (MyRoot.Position - BehindCFrame.Position).Magnitude
                    
                    if Dist > 1 then
                        -- Tween for smoothness
                        local TI = TweenInfo.new(_G.CORE.BackstabSpeed, Enum.EasingStyle.Linear)
                        local Tw = TweenService:Create(MyRoot, TI, {CFrame = BehindCFrame})
                        Tw:Play()
                    else
                        -- Stick tight if close
                        MyRoot.CFrame = BehindCFrame
                    end
                    
                    -- Face the enemy
                    MyRoot.CFrame = CFrame.lookAt(MyRoot.Position, TRoot.Position)
                end
            end
        else
            CurrentTarget = nil
        end
        task.wait() -- Run as fast as possible but yield
    end
end)

-- ==============================================================================
-- MISC FEATURES
-- ==============================================================================

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if _G.CORE.InfiniteJump and LocalPlayer.Character then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
    end
end)

-- No Recoil
task.spawn(function()
    while true do
        if _G.CORE.NoRecoil then
            local Cam = workspace.CurrentCamera
            if Cam.CFrame.Rotation.X > 0.1 then 
                 -- Simple recoil compensation logic could go here
                 -- Or hook camera shake scripts
            end
        end
        task.wait(0.1)
    end
end)

-- WalkSpeed Loop (Anti-Overwrite)
task.spawn(function()
    while true do
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            if LocalPlayer.Character.Humanoid.WalkSpeed ~= _G.CORE.WalkSpeed then
                LocalPlayer.Character.Humanoid.WalkSpeed = _G.CORE.WalkSpeed
            end
        end
        task.wait(0.5)
    end
end)

-- ==============================================================================
-- MOBILE FLY UI & LOGIC
-- ==============================================================================
local FlyUI = nil
local FlyBodyVal = nil

local function ToggleFly(State)
    if State then
        -- 1. Create UI
        if not FlyUI then
            FlyUI = Instance.new("ScreenGui", CoreGui)
            FlyUI.Name = "OxenFlyUI"
            
            local UpBtn = Instance.new("TextButton", FlyUI)
            UpBtn.Size = UDim2.new(0, 60, 0, 60)
            UpBtn.Position = UDim2.new(0.85, 0, 0.6, 0)
            UpBtn.BackgroundColor3 = Color3_fromRGB(0, 200, 0)
            UpBtn.Text = "UP"
            Instance.new("UICorner", UpBtn).CornerRadius = UDim.new(1,0)
            
            local DnBtn = Instance.new("TextButton", FlyUI)
            DnBtn.Size = UDim2.new(0, 60, 0, 60)
            DnBtn.Position = UDim2.new(0.85, 0, 0.75, 0)
            DnBtn.BackgroundColor3 = Color3_fromRGB(200, 0, 0)
            DnBtn.Text = "DN"
            Instance.new("UICorner", DnBtn).CornerRadius = UDim.new(1,0)
            
            -- Bind Events
            local FlyingUp = false
            local FlyingDn = false
            
            UpBtn.MouseButton1Down:Connect(function() FlyingUp = true end)
            UpBtn.MouseButton1Up:Connect(function() FlyingUp = false end)
            DnBtn.MouseButton1Down:Connect(function() FlyingDn = true end)
            DnBtn.MouseButton1Up:Connect(function() FlyingDn = false end)
            
            -- Fly Loop
            task.spawn(function()
                while FlyUI and _G.CORE.Fly do
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local Root = LocalPlayer.Character.HumanoidRootPart
                        local CamCF = Camera.CFrame
                        local Vel = Vector3.zero
                        
                        -- Horizontal
                        local MoveDir = LocalPlayer.Character.Humanoid.MoveDirection
                        Vel = Vel + (MoveDir * _G.CORE.FlySpeed)
                        
                        -- Vertical
                        if FlyingUp then Vel = Vel + Vector3.new(0, _G.CORE.FlySpeed, 0) end
                        if FlyingDn then Vel = Vel - Vector3.new(0, _G.CORE.FlySpeed, 0) end
                        
                        -- Apply Velocity
                        local BV = Root:FindFirstChild("OxenFlyVel") or Instance.new("BodyVelocity", Root)
                        BV.Name = "OxenFlyVel"
                        BV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                        BV.Velocity = Vel
                        
                        LocalPlayer.Character.Humanoid.PlatformStand = true
                    end
                    RunService.Heartbeat:Wait()
                end
            end)
        end
    else
        if FlyUI then FlyUI:Destroy() FlyUI = nil end
        if LocalPlayer.Character then
            local BV = LocalPlayer.Character:FindFirstChild("HumanoidRootPart"):FindFirstChild("OxenFlyVel")
            if BV then BV:Destroy() end
            LocalPlayer.Character.Humanoid.PlatformStand = false
        end
    end
end

-- ==============================================================================
-- RAYFIELD UI (EXACT STRUCTURE PRESERVED)
-- ==============================================================================
local Rayfield = loadstring(game:HttpGet('[https://sirius.menu/rayfield](https://sirius.menu/rayfield)'))()

local Window = Rayfield:CreateWindow({
   Name = "Oxen Hub",
   LoadingTitle = "Oxen Hub Optimized",
   LoadingSubtitle = "K2PN",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "OxenHubV45",
      FileName = "MobileConfig"
   },
   KeySystem = false,
})

-- === TAB 1: COMBAT ===
local CombatTab = Window:CreateTab("Combat", 4483362458)
CombatTab:CreateSection("Aimbot System")

CombatTab:CreateToggle({
   Name = "Enable Aimbot",
   CurrentValue = false,
   Flag = "AimEnabled",
   Callback = function(Value) _G.CORE.AimEnabled = Value end,
})

CombatTab:CreateToggle({
   Name = "Show FOV (No Glitch)",
   CurrentValue = false,
   Callback = function(Value) _G.CORE.ShowFOV = Value end,
})

CombatTab:CreateSlider({
   Name = "FOV Radius",
   Range = {0, 300},
   Increment = 1,
   CurrentValue = 120,
   Callback = function(Value) 
       _G.CORE.FOV = Value 
       FOV_Circle:Update(Vector2_new(0,0), Value, Color3_fromRGB(0,170,255), 1.5)
   end,
})

CombatTab:CreateSlider({
   Name = "Deadzone (Safe Area)",
   Range = {0, 100},
   Increment = 1,
   CurrentValue = 25,
   Callback = function(Value) 
       _G.CORE.Deadzone = Value 
       _G.CORE.ShowDeadzone = true
   end,
})

CombatTab:CreateSection("Checks")
CombatTab:CreateToggle({
   Name = "Wall Check",
   CurrentValue = true,
   Callback = function(Value) _G.CORE.WallCheck = Value end,
})

CombatTab:CreateToggle({
   Name = "Team Check",
   CurrentValue = false,
   Callback = function(Value) _G.CORE.TeamCheck = Value end,
})

-- === TAB 2: VISUALS ===
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
VisualsTab:CreateSection("ESP Settings")

VisualsTab:CreateToggle({
   Name = "ESP Master Switch",
   CurrentValue = true,
   Callback = function(Value) _G.CORE.EspEnabled = Value end,
})

VisualsTab:CreateToggle({
   Name = "Box ESP",
   CurrentValue = true,
   Callback = function(Value) _G.CORE.EspBox = Value end,
})

VisualsTab:CreateToggle({
   Name = "Name ESP",
   CurrentValue = true,
   Callback = function(Value) _G.CORE.EspName = Value end,
})

VisualsTab:CreateToggle({
   Name = "Health Bar",
   CurrentValue = true,
   Callback = function(Value) _G.CORE.EspHealth = Value end,
})

-- === TAB 3: MOVEMENT ===
local MoveTab = Window:CreateTab("Movement", 4483362458)

MoveTab:CreateSection("Backstab V3")
MoveTab:CreateToggle({
   Name = "Sticky Backstab (Auto-Switch)",
   CurrentValue = false,
   Callback = function(Value) _G.CORE.Backstab = Value end,
})

MoveTab:CreateSlider({
   Name = "Backstab Speed (Lower = Faster)",
   Range = {0.05, 1},
   Increment = 0.05,
   CurrentValue = 0.15,
   Callback = function(Value) _G.CORE.BackstabSpeed = Value end,
})

MoveTab:CreateSection("Mobile Fly")
MoveTab:CreateToggle({
   Name = "Enable Fly (UI Controls)",
   CurrentValue = false,
   Callback = function(Value) 
       _G.CORE.Fly = Value 
       ToggleFly(Value)
   end,
})

MoveTab:CreateSlider({
   Name = "Fly Speed",
   Range = {10, 100},
   Increment = 5,
   CurrentValue = 20,
   Callback = function(Value) _G.CORE.FlySpeed = Value end,
})

MoveTab:CreateSection("Local Player")
MoveTab:CreateSlider({
   Name = "WalkSpeed",
   Range = {16, 200},
   Increment = 1,
   CurrentValue = 16,
   Callback = function(Value) _G.CORE.WalkSpeed = Value end,
})

MoveTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Callback = function(Value) _G.CORE.InfiniteJump = Value end,
})

MoveTab:CreateToggle({
   Name = "No Recoil",
   CurrentValue = false,
   Callback = function(Value) _G.CORE.NoRecoil = Value end,
})

Rayfield:LoadConfiguration()
print("Oxen Hub V45: Loaded & Optimized for Mobile Delta X")

-- Prevent Garbage Collection of Signals
local Signals = {}
table.insert(Signals, RunService.Heartbeat)
table.insert(Signals, RunService.RenderStepped)
-- End of Script
