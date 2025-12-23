--------------------------------------------------------------------------------------------------------
-- // SECTION 1: INIT & SAFETY CHECKS (KHỞI TẠO AN TOÀN)
--------------------------------------------------------------------------------------------------------

-- Kiểm tra môi trường thực thi (Executor Check)
local executor = identifyexecutor and identifyexecutor() or "Unknown"
warn("[OXEN INIT] Detect Executor: " .. executor)

-- Đảm bảo các hàm hỗ trợ tồn tại
if not getgenv then
    warn("[CRITICAL] Executor không hỗ trợ getgenv(). Script có thể lỗi.")
    getgenv = function() return _G end
end

-- Reset cấu hình cũ nếu có
if getgenv().OxenLoaded then
    warn("[OXEN INIT] Reloading Script...")
    -- Có thể thêm logic cleanup ở đây nếu cần
end
getgenv().OxenLoaded = true

--------------------------------------------------------------------------------------------------------
-- // SECTION 2: GLOBAL CONFIGURATION (CẤU HÌNH TỔNG)
--------------------------------------------------------------------------------------------------------

getgenv()._G.OXEN_SETTINGS = {
    -- Cài đặt lõi (Core System)
    CORE = {
        ScanRate = 0.15,        -- Tốc độ quét (giây). 0.15s là cân bằng nhất cho Mobile.
        TeamCheck = true,       -- Bỏ qua đồng đội (Team/Color).
        AliveCheck = true,      -- Chỉ quét mục tiêu còn sống.
        WallCheck = false,      -- Tắt kiểm tra tường để tăng tối đa FPS.
        TargetPart = "HumanoidRootPart" -- Bộ phận nhắm mặc định.
    },
    
    -- Cài đặt Aimbot Dual-Zone
    AIM = {
        Enabled = false,
        Keybind = Enum.UserInputType.MouseButton1, -- Mặc định chạm màn hình là Aim.
        
        DualZone = {
            Enabled = true,
            FOV_Radius = 110,         -- Bán kính vùng hỗ trợ (Pixel).
            Deadzone_Radius = 17,     -- Bán kính vùng khóa chết (Pixel).
            AssistStrength = 0.45,    -- Độ mạnh hỗ trợ (0.1 - 1.0).
            HardLockMode = true       -- Bật khóa cứng trong Deadzone.
        },
        
        Prediction = {
            Enabled = true,
            Factor = 0.168            -- Hệ số dự đoán chuyển động (Ping ~100ms).
        }
    },
    
    -- Cài đặt Hitbox Expander (HBE)
    HBE = {
        Enabled = false,
        Size = 15,                    -- Kích thước mở rộng (Studs).
        Transparency = 0.6,           -- Độ trong suốt Visual.
        Color = Color3.fromRGB(255, 0, 0), -- Màu cảnh báo.
        SpoofSize = true              -- [QUAN TRỌNG] Giả mạo kích thước để Bypass Anti-Cheat.
    },
    
    -- Cài đặt Backstab V3
    BACKSTAB = {
        Enabled = false,
        Distance = 4.5,               -- Khoảng cách an toàn sau lưng.
        GhostMode = true,             -- Xuyên vật thể khi áp sát.
        Sticky = true                 -- Chế độ bám dính liên tục.
    },
    
    -- Cài đặt Visuals (Drawing API)
    VISUALS = {
        FOV_Color = Color3.fromRGB(0, 170, 255),
        Deadzone_Color_Safe = Color3.fromRGB(0, 255, 0),
        Deadzone_Color_Locked = Color3.fromRGB(255, 0, 0),
        Thickness = 1.5,
        NumSides = 16 -- Giảm số cạnh hình tròn để tối ưu Delta X.
    },
    
    -- Cài đặt Di chuyển (Movement)
    MOVEMENT = {
        SpeedEnabled = false,
        WalkSpeed = 16,
        JumpEnabled = false,
        JumpPower = 50,
        
        Fly = {
            Enabled = false,
            Speed = 60
        },
        
        NoRecoil = {
            Enabled = false,
            Strength = 100
        }
    }
}

--------------------------------------------------------------------------------------------------------
-- // SECTION 3: SERVICES & UTILITIES (DỊCH VỤ & TIỆN ÍCH)
--------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Cache Variables
getgenv()._G.TargetCache = {}
local ScreenSize = Camera.ViewportSize
local CurrentTarget = nil

-- Cập nhật kích thước màn hình (Xoay ngang/dọc)
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    ScreenSize = Camera.ViewportSize
end)

-- Hàm kiểm tra Team (Hỗ trợ đa game)
local function IsTeam(player)
    if player == LocalPlayer then return true end
    if not _G.OXEN_SETTINGS.CORE.TeamCheck then return false end
    
    -- Check 1: Team Object
    if player.Team ~= nil and LocalPlayer.Team ~= nil then
        if player.Team == LocalPlayer.Team then return true end
    end
    
    -- Check 2: TeamColor
    if player.TeamColor and LocalPlayer.TeamColor then
        if player.TeamColor == LocalPlayer.TeamColor then return true end
    end
    
    return false
end

-- Hàm chuyển đổi World -> Screen
local function GetScreenPosition(pos)
    local screen, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screen.X, screen.Y), onScreen
end

--------------------------------------------------------------------------------------------------------
-- // SECTION 4: VISUAL ENGINE FIX (DELTA X / FLUXUS DRAWING)
-- /////////////////////////////////////////////////////////////////////////////////////////////////////
-- LƯU Ý: Khai báo Drawing Global để tránh bị Garbage Collector xóa mất trên Delta.

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Thickness = _G.OXEN_SETTINGS.VISUALS.Thickness
FOVCircle.Color = _G.OXEN_SETTINGS.VISUALS.FOV_Color
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.NumSides = _G.OXEN_SETTINGS.VISUALS.NumSides
FOVCircle.Radius = _G.OXEN_SETTINGS.AIM.DualZone.FOV_Radius

local DeadzoneCircle = Drawing.new("Circle")
DeadzoneCircle.Visible = false
DeadzoneCircle.Thickness = _G.OXEN_SETTINGS.VISUALS.Thickness
DeadzoneCircle.Color = _G.OXEN_SETTINGS.VISUALS.Deadzone_Color_Safe
DeadzoneCircle.Filled = false
DeadzoneCircle.Transparency = 1
DeadzoneCircle.NumSides = _G.OXEN_SETTINGS.VISUALS.NumSides
DeadzoneCircle.Radius = _G.OXEN_SETTINGS.AIM.DualZone.Deadzone_Radius

local function UpdateDrawingVisuals()
    -- Cập nhật vị trí vòng tròn theo tâm màn hình (tính cả inset tai thỏ)
    local inset = GuiService:GetGuiInset()
    local center = Vector2.new(ScreenSize.X / 2, (ScreenSize.Y / 2) + inset.Y)
    
    if FOVCircle then
        FOVCircle.Position = center
        FOVCircle.Radius = _G.OXEN_SETTINGS.AIM.DualZone.FOV_Radius
        FOVCircle.Visible = _G.OXEN_SETTINGS.AIM.Enabled
    end
    
    if DeadzoneCircle then
        DeadzoneCircle.Position = center
        DeadzoneCircle.Radius = _G.OXEN_SETTINGS.AIM.DualZone.Deadzone_Radius
        DeadzoneCircle.Visible = _G.OXEN_SETTINGS.AIM.Enabled and _G.OXEN_SETTINGS.AIM.DualZone.Enabled
    end
end

--------------------------------------------------------------------------------------------------------
-- // SECTION 5: TITAN V5 SECURITY ENGINE (CORE PROTECTION)
-- /////////////////////////////////////////////////////////////////////////////////////////////////////

task.spawn(function()
    -- Sử dụng pcall để đảm bảo script không bao giờ crash kể cả khi hook lỗi
    local success, err = pcall(function()
        if not getrawmetatable then return end
        
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        
        local oldNamecall = mt.__namecall
        local oldIndex = mt.__index
        
        -- [HOOK 1] __NAMECALL: Chặn tín hiệu gửi lên Server
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            -- Anti-Kick / Anti-Shutdown Logic
            if method == "Kick" or method == "kick" or method == "Shutdown" then
                return nil -- Hủy lệnh
            end
            
            -- Anti-Logging (Remote Filter)
            if method == "FireServer" and self:IsA("RemoteEvent") then
                local rName = self.Name:lower()
                -- Từ khóa nhạy cảm
                if string.find(rName, "ban") or 
                   string.find(rName, "detect") or 
                   string.find(rName, "flag") or 
                   string.find(rName, "log") or
                   string.find(rName, "adc") then -- Anti-Damage-Check
                    return nil
                end
            end
            
            return oldNamecall(self, ...)
        end)
        
        -- [HOOK 2] __INDEX: Spoofing Data (Giả mạo dữ liệu)
        -- Đây là lá chắn bảo vệ HBE khỏi bị phát hiện kích thước
        mt.__index = newcclosure(function(self, key)
            -- Nếu checkcaller() trả về false => Game Engine đang đọc dữ liệu
            -- Chúng ta cần trả về dữ liệu giả
            if not checkcaller() then
                
                -- HBE SIZE SPOOF: Luôn trả về kích thước gốc
                if key == "Size" and self:IsA("BasePart") and self.Name == "HumanoidRootPart" then
                    return Vector3.new(2, 2, 1) 
                end
                
                -- SPEED SPOOF
                if key == "WalkSpeed" and self:IsA("Humanoid") then
                    return 16 
                end
                
                -- JUMP SPOOF
                if key == "JumpPower" and self:IsA("Humanoid") then
                    return 50
                end
            end
            
            return oldIndex(self, key)
        end)
        
        setreadonly(mt, true)
        warn("[TITAN V5] Security Hooks Applied Successfully.")
    end)
    
    if not success then
        warn("[TITAN V5] Hook Error: " .. tostring(err))
    end
end)

--------------------------------------------------------------------------------------------------------
-- // SECTION 6: CENTRAL SCANNER V41 & HBE INTEGRATION
-- /////////////////////////////////////////////////////////////////////////////////////////////////////

-- Hàm kiểm tra mục tiêu hợp lệ
local function IsValidTarget(player)
    if not player or player == LocalPlayer then return false end
    if IsTeam(player) then return false end
    
    local char = player.Character
    if not char then return false end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    
    if not root or not hum then return false end
    if _G.OXEN_SETTINGS.CORE.AliveCheck and hum.Health <= 0 then return false end
    
    return true
end

-- Vòng lặp Core Scanner
local function UpdateScanner()
    -- Xóa cache cũ để tránh Memory Leak
    table.clear(_G.TargetCache)
    
    for _, player in pairs(Players:GetPlayers()) do
        if IsValidTarget(player) then
            local char = player.Character
            local root = char.HumanoidRootPart
            local hum = char.Humanoid
            
            local dist = 9999
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                dist = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            end
            
            -- Thêm vào Cache dùng chung
            table.insert(_G.TargetCache, {
                Player = player,
                Character = char,
                Root = root,
                Humanoid = hum,
                Distance = dist
            })
            
            -- [HBE LOGIC - TRỰC TIẾP TRONG SCANNER]
            -- Logic: Nếu bật HBE -> Thay đổi Size. Nếu tắt -> Reset.
            if _G.OXEN_SETTINGS.HBE.Enabled then
                -- Kiểm tra để tránh set lại liên tục gây lag
                if root.Size.X ~= _G.OXEN_SETTINGS.HBE.Size then
                    root.Size = Vector3.new(_G.OXEN_SETTINGS.HBE.Size, _G.OXEN_SETTINGS.HBE.Size, _G.OXEN_SETTINGS.HBE.Size)
                    root.Transparency = _G.OXEN_SETTINGS.HBE.Transparency
                    root.CanCollide = false -- Tắt va chạm để đi xuyên hitbox
                    root.Color = _G.OXEN_SETTINGS.HBE.Color
                    root.Material = Enum.Material.ForceField -- Hiệu ứng đẹp nhẹ
                end
            else
                -- Cơ chế tự phục hồi (Self-Healing)
                if root.Size.X > 5 then -- Chỉ reset nếu nó đang bị to
                    root.Size = Vector3.new(2, 2, 1)
                    root.Transparency = 1 
                    root.CanCollide = true
                    root.Material = Enum.Material.Plastic
                end
            end
        end
    end
end

-- Khởi chạy luồng Scanner độc lập
task.spawn(function()
    while true do
        pcall(UpdateScanner)
        task.wait(_G.OXEN_SETTINGS.CORE.ScanRate)
    end
end)

--------------------------------------------------------------------------------------------------------
-- // SECTION 7: AIM ENGINE (DUAL-ZONE LOGIC)
-- /////////////////////////////////////////////////////////////////////////////////////////////////////

local function GetBestTarget()
    local best = {Dist = 999999, Data = nil}
    local mouseCenter = Vector2.new(ScreenSize.X / 2, ScreenSize.Y / 2)
    
    for _, data in pairs(_G.TargetCache) do
        local screenPos, onScreen = GetScreenPosition(data.Root.Position)
        if onScreen then
            local distMouse = (mouseCenter - screenPos).Magnitude
            
            -- Chỉ chọn mục tiêu trong vùng FOV Xanh
            if distMouse <= _G.OXEN_SETTINGS.AIM.DualZone.FOV_Radius then
                if distMouse < best.Dist then
                    best.Dist = distMouse
                    best.Data = data
                end
            end
        end
    end
    
    return best.Data
end

RunService.RenderStepped:Connect(function()
    UpdateDrawingVisuals()
    
    if _G.OXEN_SETTINGS.AIM.Enabled then
        CurrentTarget = GetBestTarget()
        
        if CurrentTarget then
            local root = CurrentTarget.Root
            local aimPos = root.Position
            
            -- Prediction Logic
            if _G.OXEN_SETTINGS.AIM.Prediction.Enabled then
                aimPos = aimPos + (root.Velocity * _G.OXEN_SETTINGS.AIM.Prediction.Factor)
            end
            
            -- Tính toán vùng Deadzone
            local screenPos, _ = GetScreenPosition(aimPos)
            local mouseCenter = Vector2.new(ScreenSize.X / 2, ScreenSize.Y / 2)
            local distCenter = (mouseCenter - screenPos).Magnitude
            
            local inDeadzone = distCenter <= _G.OXEN_SETTINGS.AIM.DualZone.Deadzone_Radius
            
            -- Visual Feedback
            if inDeadzone then
                DeadzoneCircle.Color = _G.OXEN_SETTINGS.VISUALS.Deadzone_Color_Locked
            else
                DeadzoneCircle.Color = _G.OXEN_SETTINGS.VISUALS.Deadzone_Color_Safe
            end
            
            -- Aim Execution
            -- Kiểm tra: Đang nhấn chuột hoặc Auto-Aim
            local isAiming = UserInputService:IsMouseButtonPressed(_G.OXEN_SETTINGS.AIM.Keybind)
            
            if isAiming or _G.OXEN_SETTINGS.AIM.Keybind == Enum.UserInputType.Touch then
                local camCFrame = CFrame.new(Camera.CFrame.Position, aimPos)
                
                if _G.OXEN_SETTINGS.AIM.DualZone.HardLockMode and inDeadzone then
                    -- LOCK MODE: Khóa cứng
                    Camera.CFrame = camCFrame
                else
                    -- ASSIST MODE: Kéo nhẹ
                    Camera.CFrame = Camera.CFrame:Lerp(camCFrame, _G.OXEN_SETTINGS.AIM.DualZone.AssistStrength)
                end
            end
        else
            -- Reset màu khi không có mục tiêu
            DeadzoneCircle.Color = _G.OXEN_SETTINGS.VISUALS.Deadzone_Color_Safe
        end
    end
end)

--------------------------------------------------------------------------------------------------------
-- // SECTION 8: MOVEMENT & UTILITY (FLY - RECOIL - SPEED - BACKSTAB)
-- /////////////////////////////////////////////////////////////////////////////////////////////////////

-- [A] MOBILE FLY SYSTEM
local FlyVelocity = nil
local function ToggleFly(state)
    if state then
        FlyVelocity = RunService.RenderStepped:Connect(function()
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end
                
                local hum = char:FindFirstChild("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                
                if hum and root then
                    hum.PlatformStand = true -- Trạng thái bay
                    
                    local camLook = Camera.CFrame.LookVector
                    local flySpeed = _G.OXEN_SETTINGS.MOVEMENT.Fly.Speed
                    
                    -- Logic: Nếu nhân vật đang cố di chuyển (MoveDirection > 0) -> Bay theo hướng Camera
                    -- Nếu không -> Đứng yên trên không
                    if hum.MoveDirection.Magnitude > 0 then
                        root.Velocity = camLook * flySpeed
                    else
                        root.Velocity = Vector3.new(0, 0, 0)
                    end
                    
                    -- Noclip (Xuyên vật thể khi bay)
                    root.CanCollide = false
                end
            end)
        end)
    else
        if FlyVelocity then FlyVelocity:Disconnect() end
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hum then hum.PlatformStand = false end
            if root then root.Velocity = Vector3.new(0,0,0) end
        end
    end
end

-- [B] NO RECOIL (CAMERA STABILIZER)
local RecoilLoop = nil
local function ToggleNoRecoil(state)
    if state then
        RecoilLoop = RunService.RenderStepped:Connect(function()
            if Camera then
                -- Ép trục Z (nghiêng) về 0 mỗi khung hình
                local rx, ry, rz = Camera.CFrame:ToEulerAnglesXYZ()
                if math.abs(rz) > 0 then
                     Camera.CFrame = CFrame.new(Camera.CFrame.Position) * CFrame.fromEulerAnglesXYZ(rx, ry, 0)
                end
            end
        end)
    else
        if RecoilLoop then RecoilLoop:Disconnect() end
    end
end

-- [C] SPEED & JUMP LOOP
task.spawn(function()
    while true do
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then
                if _G.OXEN_SETTINGS.MOVEMENT.SpeedEnabled then
                    hum.WalkSpeed = _G.OXEN_SETTINGS.MOVEMENT.WalkSpeed
                end
                if _G.OXEN_SETTINGS.MOVEMENT.JumpEnabled then
                    hum.JumpPower = _G.OXEN_SETTINGS.MOVEMENT.JumpPower
                end
            end
        end
        task.wait(0.5)
    end
end)
-- Infinite Jump Handle
UserInputService.JumpRequest:Connect(function()
    if _G.OXEN_SETTINGS.MOVEMENT.JumpEnabled and LocalPlayer.Character then
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- [D] BACKSTAB V3 ENGINE
task.spawn(function()
    RunService.Heartbeat:Connect(function()
        if _G.OXEN_SETTINGS.BACKSTAB.Enabled and LocalPlayer.Character then
            -- Tìm mục tiêu gần nhất
            local closest = nil
            local minDist = 500
            
            for _, data in pairs(_G.TargetCache) do
                if data.Distance < minDist then
                    minDist = data.Distance
                    closest = data
                end
            end
            
            if closest and closest.Root then
                local tRoot = closest.Root
                local mRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                
                if mRoot then
                    -- Tính vị trí sau lưng
                    local backPos = tRoot.CFrame * CFrame.new(0, 0, _G.OXEN_SETTINGS.BACKSTAB.Distance)
                    
                    -- Sticky Logic (Dịch chuyển CFrame liên tục)
                    mRoot.CFrame = CFrame.new(backPos.Position, tRoot.Position)
                    
                    -- Ghost Mode (Tắt va chạm)
                    if _G.OXEN_SETTINGS.BACKSTAB.GhostMode then
                        mRoot.CanCollide = false
                    end
                end
            end
        end
    end)
end)

--------------------------------------------------------------------------------------------------------
-- // SECTION 9: USER INTERFACE (RAYFIELD UI)
-- /////////////////////////////////////////////////////////////////////////////////////////////////////

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Oxen Hub | V50 Mobile Final",
    LoadingTitle = "Oxen Hub - God Mode",
    LoadingSubtitle = "by Gemini Optimizer",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "OxenHubV50",
        FileName = "Config"
    },
    
    -- [KEY SYSTEM INTEGRATION]
    Discord = {
        Enabled = false, 
        Invite = "noinvitelink", 
        RememberJoins = true 
    },
    
    KeySystem = false, -- Để false theo mặc định, bật true nếu cần bán Key
    KeySettings = {
        Title = "Oxen Hub Key",
        Subtitle = "Key System",
        Note = "Join Discord to get Key", 
        FileName = "OxenKey", 
        SaveKey = true, 
        GrabKeyFromSite = false, 
        Key = {"Hello"} 
    }
})

-- ==================== TAB 1: COMBAT ====================
local CombatTab = Window:CreateTab("Combat", 4483362458)

local AimSection = CombatTab:CreateSection("Dual-Zone Aimbot")

CombatTab:CreateToggle({
    Name = "Enable Aimbot V41",
    CurrentValue = false,
    Flag = "AimEnabled",
    Callback = function(Value)
        _G.OXEN_SETTINGS.AIM.Enabled = Value
        -- Ẩn/Hiện Visual
        if FOVCircle then FOVCircle.Visible = Value end
        if DeadzoneCircle then DeadzoneCircle.Visible = Value end
    end,
})

CombatTab:CreateSlider({
    Name = "FOV Radius (Blue)",
    Range = {10, 400},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 110,
    Flag = "FOVRadius",
    Callback = function(Value)
        _G.OXEN_SETTINGS.AIM.DualZone.FOV_Radius = Value
    end,
})

CombatTab:CreateSlider({
    Name = "Deadzone Radius (Red)",
    Range = {5, 100},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 17,
    Flag = "DeadzoneRadius",
    Callback = function(Value)
        _G.OXEN_SETTINGS.AIM.DualZone.Deadzone_Radius = Value
    end,
})

CombatTab:CreateSlider({
    Name = "Assist Strength",
    Range = {0.1, 1},
    Increment = 0.05,
    Suffix = "Str",
    CurrentValue = 0.45,
    Flag = "AssistStr",
    Callback = function(Value)
        _G.OXEN_SETTINGS.AIM.DualZone.AssistStrength = Value
    end,
})

local HBESection = CombatTab:CreateSection("Hitbox Expander (HBE)")

-- Toggle HBE nằm gọn trong Combat Tab
CombatTab:CreateToggle({
    Name = "Enable HBE (Anti-Ban)",
    CurrentValue = false,
    Flag = "HBEEnabled",
    Callback = function(Value)
        _G.OXEN_SETTINGS.HBE.Enabled = Value
        -- Force Reset ngay lập tức khi tắt
        if not Value then
            for _, pl in pairs(Players:GetPlayers()) do
                if pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                    pl.Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1)
                    pl.Character.HumanoidRootPart.Transparency = 1
                end
            end
        end
    end,
})

CombatTab:CreateSlider({
    Name = "HBE Size",
    Range = {2, 25},
    Increment = 1,
    Suffix = "Studs",
    CurrentValue = 15,
    Flag = "HBESize",
    Callback = function(Value)
        _G.OXEN_SETTINGS.HBE.Size = Value
    end,
})

CombatTab:CreateSlider({
    Name = "HBE Transparency",
    Range = {0, 1},
    Increment = 0.1,
    Suffix = "Alpha",
    CurrentValue = 0.6,
    Flag = "HBETrans",
    Callback = function(Value)
        _G.OXEN_SETTINGS.HBE.Transparency = Value
    end,
})

-- ==================== TAB 2: VISUALS ====================
local VisualTab = Window:CreateTab("Visuals", 4483362458)
local VisSection = VisualTab:CreateSection("Overlay Settings")

VisualTab:CreateColorPicker({
    Name = "FOV Color",
    Color = Color3.fromRGB(0, 170, 255),
    Flag = "FOVColor",
    Callback = function(Value)
        _G.OXEN_SETTINGS.VISUALS.FOV_Color = Value
        if FOVCircle then FOVCircle.Color = Value end
    end,
})

VisualTab:CreateColorPicker({
    Name = "Deadzone Color (Locked)",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "DZColor",
    Callback = function(Value)
        _G.OXEN_SETTINGS.VISUALS.Deadzone_Color_Locked = Value
        if DeadzoneCircle then DeadzoneCircle.Color = Value end
    end,
})

-- ==================== TAB 3: MOVEMENT ====================
local MoveTab = Window:CreateTab("Movement", 4483362458)
local FlySection = MoveTab:CreateSection("Flight & Stability")

MoveTab:CreateToggle({
    Name = "Mobile Fly (Camera Dir)",
    CurrentValue = false,
    Flag = "MobileFly",
    Callback = function(Value)
        _G.OXEN_SETTINGS.MOVEMENT.Fly.Enabled = Value
        ToggleFly(Value)
    end,
})

MoveTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 300},
    Increment = 10,
    Suffix = "Vel",
    CurrentValue = 60,
    Flag = "FlySpeed",
    Callback = function(Value)
        _G.OXEN_SETTINGS.MOVEMENT.Fly.Speed = Value
    end,
})

MoveTab:CreateToggle({
    Name = "No Recoil (Shake Fix)",
    CurrentValue = false,
    Flag = "NoRecoil",
    Callback = function(Value)
        _G.OXEN_SETTINGS.MOVEMENT.NoRecoil.Enabled = Value
        ToggleNoRecoil(Value)
    end,
})

local SpeedSection = MoveTab:CreateSection("Speed & Jump")

MoveTab:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = false,
    Flag = "SpeedHack",
    Callback = function(Value)
        _G.OXEN_SETTINGS.MOVEMENT.SpeedEnabled = Value
        if not Value and LocalPlayer.Character then
             LocalPlayer.Character.Humanoid.WalkSpeed = 16
        end
    end,
})

MoveTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 250},
    Increment = 1,
    Suffix = "Ws",
    CurrentValue = 16,
    Flag = "WalkSpeed",
    Callback = function(Value)
        _G.OXEN_SETTINGS.MOVEMENT.WalkSpeed = Value
    end,
})

MoveTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "InfJump",
    Callback = function(Value)
        _G.OXEN_SETTINGS.MOVEMENT.JumpEnabled = Value
    end,
})

local BackstabSection = MoveTab:CreateSection("Backstab Engine")

MoveTab:CreateToggle({
    Name = "Auto Backstab (Sticky)",
    CurrentValue = false,
    Flag = "BackstabOn",
    Callback = function(Value)
        _G.OXEN_SETTINGS.BACKSTAB.Enabled = Value
    end,
})

--------------------------------------------------------------------------------------------------------
-- // FINALIZATION (KẾT THÚC)
--------------------------------------------------------------------------------------------------------

Rayfield:LoadConfiguration()

-- Thông báo System Ready
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "OXEN HUB V50";
    Text = "Hybrid God Mode Activated!";
    Duration = 5;
})

warn("[OXEN HUB] Script Loaded Successfully.")
warn("[OXEN HUB] HBE Integrated. Security Active.")
