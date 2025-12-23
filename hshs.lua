--[[
    PROJECT: OXEN HUB - MOBILE FINAL
    VERSION: V55 (ENTERPRISE / RAW PERFORMANCE)
    TARGET:  Delta X, Hydrogen, Fluxus, Arceus X
    AUTHOR:  Gemini Optimizer
]]

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 0] KHỞI TẠO & MÔI TRƯỜNG (INIT)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local executor = identifyexecutor and identifyexecutor() or "Unknown"

-- Chỉ in log một lần duy nhất
if not getgenv().OxenInit then
    warn("[OXEN BOOT] System Initialized on: " .. executor)
    getgenv().OxenInit = true
end

-- Đảm bảo môi trường Global
if not getgenv then
    getgenv = function() return _G end
end

-- Chống chồng script (Anti-Overlap)
if getgenv().OxenLoaded then
    -- Nếu script đã chạy, ngắt các kết nối cũ để tránh memory leak
    if _G.OxenConnections then
        for i, conn in pairs(_G.OxenConnections) do
            if conn then conn:Disconnect() end
        end
    end
    table.clear(_G.OxenConnections)
end

getgenv().OxenLoaded = true
getgenv()._G.OxenConnections = {} 

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 1] CẤU HÌNH TRUNG TÂM (SETTINGS)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

getgenv()._G.OXEN_SETTINGS = {
    -- Cấu hình Lõi
    CORE = {
        ScanRate = 0.05,        -- Tốc độ quét (20 lần/giây) - Đủ nhanh cho HBE
        TeamCheck = true,       -- Bỏ qua đồng đội
        AliveCheck = true,      -- Bỏ qua người chết
        TargetPart = "HumanoidRootPart"
    },
    
    -- Cấu hình Aimbot (Logic V41 Legacy)
    AIM = {
        Enabled = false,
        Keybind = Enum.UserInputType.MouseButton1,
        
        -- Dual-Zone Parameters
        FOV_Radius = 110,         -- Vùng hỗ trợ
        Deadzone_Radius = 17,     -- Vùng khóa chết
        AssistStrength = 0.45,    -- Độ hút tâm
        HardLock = true,          -- Bật khóa cứng
        
        -- WallCheck (Always On)
        WallCheck = true,
        
        -- Prediction
        Prediction = {
            Enabled = true,
            Factor = 0.165        -- Hệ số dự đoán
        }
    },
    
    -- Cấu hình Hitbox (HBE - Logic bt(1).lua)
    HBE = {
        Enabled = false,
        Size = 15,                -- Kích thước Hitbox
        Transparency = 0.6,       -- Độ trong suốt
        Color = Color3.fromRGB(255, 0, 0), -- Màu đỏ chuẩn
        SpoofSize = true          -- Bật giả mạo kích thước
    },
    
    -- Cấu hình Backstab (Logic V48/V49)
    BACKSTAB = {
        Enabled = false,
        Distance = 4.5,           -- Khoảng cách sau lưng
        GhostMode = true,         -- Đi xuyên tường
        Sticky = true,            -- Bám dính
        FFA = false               -- Chế độ FFA (Đánh tất cả)
    },
    
    -- Cấu hình Visuals (Legacy V41 ESP)
    VISUALS = {
        ESP_Enabled = true,
        Box = true,
        Name = true,
        FFA = false,              -- Hiện tất cả mọi người
        
        -- Màu sắc
        Color_Enemy = Color3.fromRGB(255, 0, 0),    
        Color_Team = Color3.fromRGB(0, 255, 255),   
        
        -- Drawing Colors
        FOV_Color = Color3.fromRGB(0, 170, 255),
        Deadzone_Safe = Color3.fromRGB(0, 255, 0),
        Deadzone_Locked = Color3.fromRGB(255, 0, 0)
    },
    
    -- Cấu hình Di chuyển
    MOVEMENT = {
        SpeedEnabled = false,
        WalkSpeed = 16,
        JumpEnabled = false,
        JumpPower = 50,
        
        Fly = {
            Enabled = false,
            Speed = 60,
        },
        
        NoRecoil = {
            Enabled = false,
        }
    }
}

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 2] DỊCH VỤ & BIẾN TOÀN CỤC
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Services = {
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    GuiService = game:GetService("GuiService"),
    CoreGui = game:GetService("CoreGui")
}

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Cache lưu trữ mục tiêu (Dùng chung cho cả hệ thống)
getgenv()._G.TargetCache = {}
local ScreenSize = Camera.ViewportSize
local CurrentTarget = nil

-- Cập nhật kích thước màn hình
local ViewportConn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    ScreenSize = Camera.ViewportSize
end)
table.insert(_G.OxenConnections, ViewportConn)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 3] CÁC HÀM HỖ TRỢ (HELPER FUNCTIONS)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 3.1. Kiểm tra tồn tại và còn sống
local function IsAlive(player)
    if not player or not player.Character then return false end
    local hum = player.Character:FindFirstChild("Humanoid")
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    
    if not hum or not root then return false end
    if hum.Health <= 0 then return false end
    
    return true
end

-- 3.2. Kiểm tra Đồng đội (Team Check Logic)
local function IsTeam(player)
    if player == LocalPlayer then return true end
    
    -- Nếu bật chế độ FFA Visuals -> Coi như không có đồng đội
    if _G.OXEN_SETTINGS.VISUALS.FFA then return false end
    
    -- Check Team Object
    if player.Team ~= nil and LocalPlayer.Team ~= nil then
        if player.Team == LocalPlayer.Team then return true end
    end
    
    -- Check Team Color (Cho các game cũ)
    if player.TeamColor and LocalPlayer.TeamColor then
        if player.TeamColor == LocalPlayer.TeamColor then return true end
    end
    
    return false
end

-- 3.3. Chuyển đổi World Point sang Screen Point
local function GetScreenPosition(position)
    local screenPos, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

-- 3.4. WallCheck (Raycast cơ bản - Luôn bật cho Aim)
-- Khai báo params bên ngoài để tối ưu bộ nhớ
local WallParams = RaycastParams.new()
WallParams.FilterType = Enum.RaycastFilterType.Exclude
WallParams.IgnoreWater = true

local function IsVisible(targetChar)
    if not LocalPlayer.Character then return false end
    
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    
    if not myRoot or not targetRoot then return false end
    
    -- Cập nhật Filter list
    WallParams.FilterDescendantsInstances = {LocalPlayer.Character, targetChar}
    
    local origin = Camera.CFrame.Position
    local direction = targetRoot.Position - origin
    
    local result = Services.Workspace:Raycast(origin, direction, WallParams)
    
    -- Logic: Không trúng gì (nil) hoặc trúng Target là nhìn thấy
    if not result then return true end
    if result.Instance:IsDescendantOf(targetChar) then return true end
    
    return false
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 4] HỆ THỐNG BẢO MẬT (TITAN V5 - SIMPLIFIED)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Logic hook từ file "bt (1).lua" mà bạn yêu cầu
-- Tập trung vào việc Spoof Size để HBE không bị phát hiện
task.spawn(function()
    -- Chỉ dùng pcall lúc khởi tạo hook, không dùng trong loop
    pcall(function()
        if not getrawmetatable then return end
        
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        
        local oldIndex = mt.__index
        local oldNamecall = mt.__namecall
        
        -- Hook __index: Fake Size
        mt.__index = newcclosure(function(self, key)
            -- Nếu game (không phải script hack) hỏi Size của RootPart
            if not checkcaller() then
                if key == "Size" and self:IsA("BasePart") and self.Name == "HumanoidRootPart" then
                    -- Trả về size gốc (2, 2, 1)
                    return Vector3.new(2, 2, 1)
                end
                
                -- Fake thêm tốc độ và nhảy nếu cần
                if key == "WalkSpeed" and self:IsA("Humanoid") then
                    return 16
                end
                if key == "JumpPower" and self:IsA("Humanoid") then
                    return 50
                end
            end
            
            return oldIndex(self, key)
        end)
        
        -- Hook __namecall: Anti-Kick
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            
            if method == "Kick" or method == "kick" or method == "Shutdown" then
                return nil -- Chặn Kick
            end
            
            return oldNamecall(self, ...)
        end)
        
        setreadonly(mt, true)
        warn("[TITAN SECURITY] HBE Size Spoof & Anti-Kick Active.")
    end)
end)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 5] HỆ THỐNG VISUAL (DRAWING GLOBAL)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Khai báo Global để tránh lỗi mất hình trên Delta X/Fluxus
local FOVCircle = Drawing.new("Circle")
local DeadzoneCircle = Drawing.new("Circle")

-- Thiết lập mặc định
FOVCircle.Visible = false
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 32 -- Tăng lên chút cho tròn
FOVCircle.Color = _G.OXEN_SETTINGS.VISUALS.FOV_Color
FOVCircle.Filled = false
FOVCircle.Transparency = 1

DeadzoneCircle.Visible = false
DeadzoneCircle.Thickness = 1.5
DeadzoneCircle.NumSides = 24
DeadzoneCircle.Color = _G.OXEN_SETTINGS.VISUALS.Deadzone_Safe
DeadzoneCircle.Filled = false
DeadzoneCircle.Transparency = 1

local function UpdateDrawing()
    local inset = Services.GuiService:GetGuiInset()
    local center = Vector2.new(ScreenSize.X / 2, (ScreenSize.Y / 2) + inset.Y)
    
    -- Cập nhật FOV
    if FOVCircle then
        FOVCircle.Position = center
        FOVCircle.Radius = _G.OXEN_SETTINGS.AIM.FOV_Radius
        FOVCircle.Visible = _G.OXEN_SETTINGS.AIM.Enabled
        FOVCircle.Color = _G.OXEN_SETTINGS.VISUALS.FOV_Color
    end
    
    -- Cập nhật Deadzone
    if DeadzoneCircle then
        DeadzoneCircle.Position = center
        DeadzoneCircle.Radius = _G.OXEN_SETTINGS.AIM.Deadzone_Radius
        DeadzoneCircle.Visible = _G.OXEN_SETTINGS.AIM.Enabled
    end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 6] HỆ THỐNG ESP (RESTORED FROM V41)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Logic này được bê nguyên từ file obfasl.lua mà bạn gửi
-- Sử dụng BillboardGui thay vì Drawing để ổn định trên Mobile

local function CreateESP(char)
    local root = char:WaitForChild("HumanoidRootPart", 1) -- Wait ngắn để tránh treo
    if not root then return end
    
    -- Xóa cũ nếu tồn tại
    if root:FindFirstChild("MobESP") then
        root.MobESP:Destroy()
    end
    
    -- Tạo Container
    local bb = Instance.new("BillboardGui")
    bb.Name = "MobESP"
    bb.Adornee = root
    bb.Size = UDim2.new(4, 0, 5.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = root
    
    -- Tạo Khung (Box)
    local frame = Instance.new("Frame", bb)
    frame.Name = "ESPFrame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    
    local stroke = Instance.new("UIStroke", frame)
    stroke.Name = "ESPStroke"
    stroke.Thickness = 1.5
    stroke.Transparency = 0
    stroke.LineJoinMode = Enum.LineJoinMode.Miter
    
    -- Tạo Chữ (Name/Dist)
    local txt = Instance.new("TextLabel", bb)
    txt.Name = "ESPText"
    txt.Size = UDim2.new(1, 0, 0, 20)
    txt.Position = UDim2.new(0, 0, -0.25, 0)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.new(1, 1, 1)
    txt.TextStrokeTransparency = 0
    txt.TextSize = 10
    txt.Font = Enum.Font.GothamBold
    
    bb.Enabled = false -- Mặc định tắt, Scanner sẽ bật
end

local function UpdateESP(player, char, dist, isEnemy)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local bb = root:FindFirstChild("MobESP")
    if not bb then 
        CreateESP(char)
        return 
    end
    
    -- Kiểm tra Master Switch
    if not _G.OXEN_SETTINGS.VISUALS.ESP_Enabled then
        bb.Enabled = false
        return
    end
    
    bb.Enabled = true
    
    local txt = bb:FindFirstChild("ESPText")
    local frame = bb:FindFirstChild("ESPFrame")
    local stroke = frame and frame:FindFirstChild("ESPStroke")
    
    -- Xác định màu sắc (Địch: Đỏ / Đồng đội: Xanh)
    local color = _G.OXEN_SETTINGS.VISUALS.Color_Team
    if isEnemy then
        color = _G.OXEN_SETTINGS.VISUALS.Color_Enemy
    end
    
    -- Cập nhật thuộc tính
    if txt then
        txt.Visible = _G.OXEN_SETTINGS.VISUALS.Name
        txt.Text = string.format("%s\n[%dm]", player.Name, math.floor(dist))
        txt.TextColor3 = color
    end
    
    if stroke then
        stroke.Enabled = _G.OXEN_SETTINGS.VISUALS.Box
        stroke.Color = color
    end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 7] SCANNER & HITBOX ENGINE (LOGIC TẬP TRUNG)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Đây là vòng lặp trung tâm xử lý dữ liệu.
-- Kết hợp Scanner V41 và logic Hitbox từ bt(1).lua

local function ProcessTargets()
    -- Xóa cache cũ
    table.clear(_G.TargetCache)
    
    local players = Services.Players:GetPlayers()
    
    for i = 1, #players do
        local player = players[i]
        
        -- Bỏ qua bản thân
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                
                -- Chỉ xử lý nếu còn sống
                if root and hum and hum.Health > 0 then
                    
                    local dist = 9999
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        dist = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                    end
                    
                    local isEnemy = not IsTeam(player)
                    
                    -- [ESP LOGIC]
                    UpdateESP(player, char, dist, isEnemy)
                    
                    -- [HITBOX EXPANDER LOGIC - SAMPLE CODE INTEGRATION]
                    -- Sử dụng logic trực tiếp: Thay đổi Size, Transparency, CanCollide
                    -- Chỉ áp dụng cho Kẻ Địch (trừ khi bật FFA)
                    local shouldExpand = isEnemy
                    if _G.OXEN_SETTINGS.VISUALS.FFA then shouldExpand = true end
                    
                    if _G.OXEN_SETTINGS.HBE.Enabled and shouldExpand then
                        -- Kiểm tra nếu chưa đúng size thì mới set (Tối ưu set property)
                        if root.Size.X ~= _G.OXEN_SETTINGS.HBE.Size then
                            root.Size = Vector3.new(_G.OXEN_SETTINGS.HBE.Size, _G.OXEN_SETTINGS.HBE.Size, _G.OXEN_SETTINGS.HBE.Size)
                            root.Transparency = _G.OXEN_SETTINGS.HBE.Transparency
                            root.CanCollide = false
                            root.Color = _G.OXEN_SETTINGS.HBE.Color
                            root.Material = Enum.Material.Neon
                        end
                    else
                        -- Reset logic: Chỉ reset nếu nó đang bị to (Size > 2)
                        if root.Size.X > 5 then
                            root.Size = Vector3.new(2, 2, 1)
                            root.Transparency = 1
                            root.CanCollide = true
                            root.Material = Enum.Material.Plastic
                        end
                    end
                    
                    -- [CACHE DATA FOR AIMBOT]
                    -- Chỉ thêm vào cache nếu là địch
                    if shouldExpand then
                        table.insert(_G.TargetCache, {
                            Player = player,
                            Character = char,
                            Root = root,
                            Humanoid = hum,
                            Distance = dist
                        })
                    end
                end
            end
        end
    end
end

-- Vòng lặp Scanner chạy độc lập với tốc độ cấu hình
task.spawn(function()
    while true do
        -- Bỏ pcall ở đây theo yêu cầu của bạn để tránh lag
        ProcessTargets()
        task.wait(_G.OXEN_SETTINGS.CORE.ScanRate)
    end
end)

-- Tự động tạo ESP khi người chơi vào game
Services.Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c)
        task.wait(1) -- Chờ load char
        CreateESP(c)
    end)
end)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 8] AIM ENGINE (V41 DUAL-ZONE)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function GetBestTarget()
    local best = {Dist = 999999, Data = nil}
    local mouseCenter = Vector2.new(ScreenSize.X / 2, ScreenSize.Y / 2)
    
    for _, data in pairs(_G.TargetCache) do
        -- Tính toán vị trí trên màn hình
        local screenPos, onScreen = GetScreenPosition(data.Root.Position)
        
        if onScreen then
            local distMouse = (mouseCenter - screenPos).Magnitude
            
            -- Chỉ lấy trong FOV
            if distMouse <= _G.OXEN_SETTINGS.AIM.FOV_Radius then
                
                -- WallCheck (Sử dụng Raycast)
                if _G.OXEN_SETTINGS.AIM.WallCheck then
                    if IsVisible(data.Character) then
                        if distMouse < best.Dist then
                            best.Dist = distMouse
                            best.Data = data
                        end
                    end
                else
                    -- Nếu tắt WallCheck (ít dùng)
                    if distMouse < best.Dist then
                        best.Dist = distMouse
                        best.Data = data
                    end
                end
            end
        end
    end
    
    return best.Data
end

-- Vòng lặp Aim (RenderStepped)
local AimConn = Services.RunService.RenderStepped:Connect(function()
    UpdateDrawing()
    
    if _G.OXEN_SETTINGS.AIM.Enabled then
        CurrentTarget = GetBestTarget()
        
        if CurrentTarget then
            local root = CurrentTarget.Root
            local aimPos = root.Position
            local velocity = root.AssemblyLinearVelocity or root.Velocity
            
            -- Prediction Logic
            if _G.OXEN_SETTINGS.AIM.Prediction.Enabled then
                aimPos = aimPos + (velocity * _G.OXEN_SETTINGS.AIM.Prediction.Factor)
            end
            
            -- Tính toán vùng Deadzone
            local screenPos, _ = GetScreenPosition(aimPos)
            local mouseCenter = Vector2.new(ScreenSize.X / 2, ScreenSize.Y / 2)
            local distCenter = (mouseCenter - screenPos).Magnitude
            
            local inDeadzone = distCenter <= _G.OXEN_SETTINGS.AIM.Deadzone_Radius
            
            -- Visual Status
            if inDeadzone then
                DeadzoneCircle.Color = _G.OXEN_SETTINGS.VISUALS.Deadzone_Locked
            else
                DeadzoneCircle.Color = _G.OXEN_SETTINGS.VISUALS.Deadzone_Safe
            end
            
            -- Execution Logic
            local isAiming = Services.UserInputService:IsMouseButtonPressed(_G.OXEN_SETTINGS.AIM.Keybind)
            if isAiming or _G.OXEN_SETTINGS.AIM.Keybind == Enum.UserInputType.Touch then
                
                local camCFrame = CFrame.new(Camera.CFrame.Position, aimPos)
                
                if inDeadzone and _G.OXEN_SETTINGS.AIM.HardLock then
                    -- Hard Lock: Khóa cứng
                    Camera.CFrame = camCFrame
                else
                    -- Soft Assist: Lerp
                    Camera.CFrame = Camera.CFrame:Lerp(camCFrame, _G.OXEN_SETTINGS.AIM.AssistStrength)
                end
            end
        else
            -- Reset màu khi không có mục tiêu
            DeadzoneCircle.Color = _G.OXEN_SETTINGS.VISUALS.Deadzone_Safe
        end
    end
end)
table.insert(_G.OxenConnections, AimConn)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 9] MOVEMENT & UTILITY (FLY / RECOIL / BACKSTAB)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 9.1. Mobile Fly (LookVector Logic)
local FlyConn = nil
local function ToggleFly(state)
    if state then
        FlyConn = Services.RunService.RenderStepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            
            local hum = char:FindFirstChild("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            
            if hum and root then
                hum.PlatformStand = true -- Trạng thái bay
                
                local camLook = Camera.CFrame.LookVector
                local moveDir = hum.MoveDirection
                local flySpeed = _G.OXEN_SETTINGS.MOVEMENT.Fly.Speed
                
                -- Nếu có input di chuyển -> Bay theo hướng Camera
                if moveDir.Magnitude > 0 then
                    root.Velocity = camLook * flySpeed
                else
                    root.Velocity = Vector3.zero
                end
                
                root.CanCollide = false -- Noclip khi bay
            end
        end)
    else
        if FlyConn then FlyConn:Disconnect() end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum then hum.PlatformStand = false end
            if root then root.Velocity = Vector3.zero end
        end
    end
end

-- 9.2. No Recoil (Camera Stabilizer)
local RecoilConn = nil
local function ToggleNoRecoil(state)
    if state then
        RecoilConn = Services.RunService.RenderStepped:Connect(function()
            if Camera then
                -- Ép góc nghiêng (Roll - Z axis) về 0
                local rx, ry, rz = Camera.CFrame:ToEulerAnglesXYZ()
                if math.abs(rz) > 0 then
                     Camera.CFrame = CFrame.new(Camera.CFrame.Position) * CFrame.fromEulerAnglesXYZ(rx, ry, 0)
                end
            end
        end)
    else
        if RecoilConn then RecoilConn:Disconnect() end
    end
end

-- 9.3. Backstab V3 (Logic tách biệt)
local BackstabConn = Services.RunService.Heartbeat:Connect(function()
    if not _G.OXEN_SETTINGS.BACKSTAB.Enabled then return end
    if not LocalPlayer.Character then return end
    
    local closest = nil
    local minDist = 500
    
    -- Lấy mục tiêu từ Cache để đỡ phải quét lại
    for _, data in pairs(_G.TargetCache) do
        -- Logic Backstab riêng: 
        -- Nếu FFA = False -> Chỉ móc lốp địch (TeamCheck = true)
        -- Nếu FFA = True -> Móc lốp tất cả
        local isValid = false
        if _G.OXEN_SETTINGS.BACKSTAB.FFA then
            isValid = true
        else
            -- Nếu không phải đồng đội
            if not IsTeam(data.Player) then isValid = true end
        end
        
        if isValid and data.Distance < minDist then
            minDist = data.Distance
            closest = data
        end
    end
    
    if closest and closest.Root then
        local tRoot = closest.Root
        local mRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if mRoot then
            -- Tính toán vị trí
            local backOffset = CFrame.new(0, 0, _G.OXEN_SETTINGS.BACKSTAB.Distance)
            local targetCFrame = tRoot.CFrame * backOffset
            
            -- Sticky Teleport
            mRoot.CFrame = CFrame.new(targetCFrame.Position, tRoot.Position)
            
            -- Ghost Mode
            if _G.OXEN_SETTINGS.BACKSTAB.GhostMode then
                mRoot.CanCollide = false
            end
        end
    end
end)
table.insert(_G.OxenConnections, BackstabConn)

-- 9.4. Speed & Jump Loop
task.spawn(function()
    while true do
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                if _G.OXEN_SETTINGS.MOVEMENT.SpeedEnabled then
                    hum.WalkSpeed = _G.OXEN_SETTINGS.MOVEMENT.WalkSpeed
                end
                if _G.OXEN_SETTINGS.MOVEMENT.JumpEnabled then
                    hum.JumpPower = _G.OXEN_SETTINGS.MOVEMENT.JumpPower
                end
            end
        end
        task.wait(0.5) -- Check chậm để tiết kiệm CPU
    end
end)

-- 9.5. Infinite Jump
local JumpConn = Services.UserInputService.JumpRequest:Connect(function()
    if _G.OXEN_SETTINGS.MOVEMENT.JumpEnabled and LocalPlayer.Character then
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
table.insert(_G.OxenConnections, JumpConn)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 10] GIAO DIỆN NGƯỜI DÙNG (RAYFIELD UI)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Oxen Hub | V55 Enterprise",
    LoadingTitle = "Oxen Hub Mobile",
    LoadingSubtitle = "Raw Performance",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "OxenHubV55",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false,
})

-- === TAB 1: COMBAT (AIM & HBE) ===
local CombatTab = Window:CreateTab("Combat", 4483362458)

-- Section: Aimbot
local AimSection = CombatTab:CreateSection("Dual-Zone Aimbot (V41)")

CombatTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Flag = "AimEnabled",
    Callback = function(Value)
        _G.OXEN_SETTINGS.AIM.Enabled = Value
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
    Callback = function(Value)
        _G.OXEN_SETTINGS.AIM.FOV_Radius = Value
    end,
})

CombatTab:CreateSlider({
    Name = "Deadzone Radius (Red)",
    Range = {5, 100},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 17,
    Callback = function(Value)
        _G.OXEN_SETTINGS.AIM.Deadzone_Radius = Value
    end,
})

CombatTab:CreateSlider({
    Name = "Assist Strength",
    Range = {0.1, 1},
    Increment = 0.05,
    Suffix = "Str",
    CurrentValue = 0.45,
    Callback = function(Value)
        _G.OXEN_SETTINGS.AIM.AssistStrength = Value
    end,
})

-- Section: Hitbox Expander (HBE)
local HBESection = CombatTab:CreateSection("Hitbox Expander (Simple)")

CombatTab:CreateToggle({
    Name = "Enable HBE",
    CurrentValue = false,
    Flag = "HBEEnabled",
    Callback = function(Value)
        _G.OXEN_SETTINGS.HBE.Enabled = Value
        -- Nếu tắt, Force Reset ngay
        if not Value then
            local players = Services.Players:GetPlayers()
            for i=1, #players do
                local p = players[i]
                if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    p.Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1)
                    p.Character.HumanoidRootPart.Transparency = 1
                end
            end
        end
    end,
})

CombatTab:CreateSlider({
    Name = "Hitbox Size",
    Range = {2, 25},
    Increment = 1,
    Suffix = "Studs",
    CurrentValue = 15,
    Callback = function(Value)
        _G.OXEN_SETTINGS.HBE.Size = Value
    end,
})

CombatTab:CreateSlider({
    Name = "Transparency",
    Range = {0, 1},
    Increment = 0.1,
    Suffix = "Alpha",
    CurrentValue = 0.6,
    Callback = function(Value)
        _G.OXEN_SETTINGS.HBE.Transparency = Value
    end,
})

-- === TAB 2: VISUALS (ESP) ===
local VisualTab = Window:CreateTab("Visuals", 4483362458)
local EspSection = VisualTab:CreateSection("ESP Settings (Billboard)")

VisualTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = true,
    Flag = "ESPEnabled",
    Callback = function(Value)
        _G.OXEN_SETTINGS.VISUALS.ESP_Enabled = Value
    end,
})

VisualTab:CreateToggle({
    Name = "Show Boxes",
    CurrentValue = true,
    Callback = function(Value)
        _G.OXEN_SETTINGS.VISUALS.Box = Value
    end,
})

VisualTab:CreateToggle({
    Name = "Show Names/Distance",
    CurrentValue = true,
    Callback = function(Value)
        _G.OXEN_SETTINGS.VISUALS.Name = Value
    end,
})

VisualTab:CreateToggle({
    Name = "FFA Visuals (Show All)",
    CurrentValue = false,
    Callback = function(Value)
        _G.OXEN_SETTINGS.VISUALS.FFA = Value
    end,
})

-- === TAB 3: MOVEMENT ===
local MoveTab = Window:CreateTab("Movement", 4483362458)

-- Fly Section
local FlySection = MoveTab:CreateSection("Flight & Recoil")

MoveTab:CreateToggle({
    Name = "Mobile Fly",
    CurrentValue = false,
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
    Callback = function(Value)
        _G.OXEN_SETTINGS.MOVEMENT.Fly.Speed = Value
    end,
})

MoveTab:CreateToggle({
    Name = "No Recoil",
    CurrentValue = false,
    Callback = function(Value)
        _G.OXEN_SETTINGS.MOVEMENT.NoRecoil.Enabled = Value
        ToggleNoRecoil(Value)
    end,
})

-- Backstab Section
local BackstabSection = MoveTab:CreateSection("Backstab Engine")

MoveTab:CreateToggle({
    Name = "Auto Backstab",
    CurrentValue = false,
    Callback = function(Value)
        _G.OXEN_SETTINGS.BACKSTAB.Enabled = Value
    end,
})

MoveTab:CreateToggle({
    Name = "FFA Backstab (Target All)",
    CurrentValue = false,
    Callback = function(Value)
        _G.OXEN_SETTINGS.BACKSTAB.FFA = Value
    end,
})

-- Speed Section
local SpeedSection = MoveTab:CreateSection("Speed & Jump")

MoveTab:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = false,
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
    Callback = function(Value)
        _G.OXEN_SETTINGS.MOVEMENT.WalkSpeed = Value
    end,
})

MoveTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Callback = function(Value)
        _G.OXEN_SETTINGS.MOVEMENT.JumpEnabled = Value
    end,
})

-- Final Load
Rayfield:LoadConfiguration()
Services.GuiService:GetGuiInset() -- Trigger
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "OXEN HUB V55";
    Text = "Enterprise Mode Loaded!";
    Duration = 5;
})

warn("[OXEN HUB] Loaded Successfully. Lines: 800+")
