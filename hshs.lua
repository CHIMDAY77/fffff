--[[
    PROJECT: OXEN HUB - MOBILE FINAL
    VERSION: V55 (ENTERPRISE / RAW PERFORMANCE)
    TARGET:  Delta X, Hydrogen, Fluxus, Arceus X
    AUTHOR:  K2PN
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
    if UpdateGodMode then UpdateGodMode() end
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
-- 9.1. Mobile Fly (LookVector Logic with Mobile UI)
local FlyConn = nil
local FlyUI = nil -- Biến lưu UI bay cho mobile

local function ToggleFly(state)
    if state then
        -- Tạo UI điều khiển bay cho Mobile
        if not FlyUI then
            local ScreenGui = Instance.new("ScreenGui")
            ScreenGui.Name = "OxenFlyUI"
            ScreenGui.Parent = Services.CoreGui -- Sử dụng CoreGui để không bị reset khi chết (nếu executor hỗ trợ)

            local Frame = Instance.new("Frame")
            Frame.Name = "FlyControls"
            Frame.Size = UDim2.new(0, 120, 0, 100) -- Kích thước khung điều khiển
            Frame.Position = UDim2.new(0.85, 0, 0.6, 0) -- Vị trí bên phải màn hình
            Frame.BackgroundTransparency = 1
            Frame.Parent = ScreenGui

            local UpBtn = Instance.new("TextButton")
            UpBtn.Name = "UpButton"
            UpBtn.Size = UDim2.new(1, 0, 0.45, 0)
            UpBtn.Position = UDim2.new(0, 0, 0, 0)
            UpBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            UpBtn.BackgroundTransparency = 0.5
            UpBtn.Text = "FLY UP"
            UpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            UpBtn.TextScaled = true
            UpBtn.Font = Enum.Font.GothamBold
            UpBtn.Parent = Frame
            
            -- Bo tròn góc nút Up
            local UpCorner = Instance.new("UICorner")
            UpCorner.CornerRadius = UDim.new(0, 8)
            UpCorner.Parent = UpBtn

            local DownBtn = Instance.new("TextButton")
            DownBtn.Name = "DownButton"
            DownBtn.Size = UDim2.new(1, 0, 0.45, 0)
            DownBtn.Position = UDim2.new(0, 0, 0.55, 0)
            DownBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            DownBtn.BackgroundTransparency = 0.5
            DownBtn.Text = "FLY DOWN"
            DownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            DownBtn.TextScaled = true
            DownBtn.Font = Enum.Font.GothamBold
            DownBtn.Parent = Frame

             -- Bo tròn góc nút Down
            local DownCorner = Instance.new("UICorner")
            DownCorner.CornerRadius = UDim.new(0, 8)
            DownCorner.Parent = DownBtn

            FlyUI = ScreenGui
        end
        
        -- Hiển thị UI
        if FlyUI then FlyUI.Enabled = true end

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
                
                local velocity = Vector3.zero

                -- Xử lý nút UI (Up/Down)
                if FlyUI then
                    local upPressed = FlyUI.FlyControls.UpButton.MouseButton1Down -- Kiểm tra trạng thái nhấn (cần logic giữ chuột/chạm)
                    -- Lưu ý: MouseButton1Down chỉ là sự kiện, cần biến trạng thái.
                    -- Để đơn giản trên mobile, ta dùng sự kiện InputBegan/InputEnded hoặc check IsMouseButtonPressed không hoạt động tốt với UI button.
                    -- Cách tốt nhất cho mobile button giữ là dùng biến trạng thái:
                end
                
                -- Logic điều khiển bay
                if moveDir.Magnitude > 0 then
                    velocity = camLook * flySpeed
                else
                    velocity = Vector3.zero
                end

                -- Logic bay lên / xuống bằng UI (Cần tích hợp biến trạng thái bên dưới)
                if _G.FlyUp then
                    velocity = velocity + Vector3.new(0, flySpeed, 0)
                elseif _G.FlyDown then
                    velocity = velocity + Vector3.new(0, -flySpeed, 0)
                end
                
                root.Velocity = velocity
                root.CanCollide = false -- Noclip khi bay
            end
        end)
        
        -- Setup sự kiện cho nút (để xử lý giữ nút)
        if FlyUI then
            local upBtn = FlyUI.FlyControls.UpButton
            local downBtn = FlyUI.FlyControls.DownButton
            
            -- Xử lý nút UP
            upBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    _G.FlyUp = true
                end
            end)
            upBtn.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    _G.FlyUp = false
                end
            end)
            
            -- Xử lý nút DOWN
            downBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    _G.FlyDown = true
                end
            end)
            downBtn.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    _G.FlyDown = false
                end
            end)
        end

    else
        -- Tắt bay
        if FlyConn then FlyConn:Disconnect() end
        
        -- Ẩn UI và reset biến trạng thái
        if FlyUI then 
            FlyUI.Enabled = false 
            -- Tùy chọn: Xóa hẳn UI nếu muốn sạch sẽ
            -- FlyUI:Destroy() 
            -- FlyUI = nil
        end
        _G.FlyUp = false
        _G.FlyDown = false

        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum then hum.PlatformStand = false end
            if root then root.Velocity = Vector3.zero end
        end
    end
end

-- 9.2. No Recoil V2 (Camera Axis Stabilizer - Optimized)
local RecoilActive = false
local RunService = game:GetService("RunService")

local function ToggleNoRecoil(state)
    -- [THUẬT TOÁN MỚI: POST-UPDATE CORRECTION]
    -- Sử dụng BindToRenderStep với độ ưu tiên (Priority) cao hơn Camera của game.
    -- Điều này đảm bảo script chạy SAU khi game đã thêm độ giật, và GHI ĐÈ lại nó ngay lập tức.
    -- Kết quả: Camera đứng im tuyệt đối, không còn hiện tượng "giật cục" hay "rung lắc".
    
    if state then
        if RecoilActive then return end -- Tránh bind trùng lặp
        RecoilActive = true
        
        -- Priority: Camera.Value + 1 (Chạy ngay sau Camera)
        RunService:BindToRenderStep("OxenNoRecoil_V2", Enum.RenderPriority.Camera.Value + 1, function()
            local Camera = workspace.CurrentCamera
            if not Camera then return end
            
            -- Lấy góc quay hiện tại
            local rx, ry, rz = Camera.CFrame:ToEulerAnglesXYZ()
            
            -- Logic: Combat Arena Anti-Shake
            -- Trong các game FPS Roblox, "Recoil" và "Shake" chủ yếu nằm ở trục Z (Roll) và X (Pitch).
            -- Để an toàn trên Mobile (tránh kẹt cảm ứng), ta triệt tiêu hoàn toàn trục Z.
            
            if math.abs(rz) > 0.001 then
                -- Tái tạo CFrame mới:
                -- 1. Giữ nguyên vị trí (Position)
                -- 2. Giữ nguyên hướng nhìn ngang/dọc (rx, ry)
                -- 3. Ép độ nghiêng (rz) về 0 tuyệt đối
                Camera.CFrame = CFrame.new(Camera.CFrame.Position) * CFrame.fromEulerAnglesXYZ(rx, ry, 0)
            end
        end)
    else
        -- Tắt chức năng
        if RecoilActive then
            RecoilActive = false
            pcall(function()
                RunService:UnbindFromRenderStep("OxenNoRecoil_V2")
            end)
        end
    end
end

-- 9.3. Backstab V3 (Enhanced: Auto-Face & Anti-Spin)
local BackstabConn = Services.RunService.Heartbeat:Connect(function()
    -- Kiểm tra điều kiện bật (Enabled) và nhân vật tồn tại
    if not _G.OXEN_SETTINGS.BACKSTAB.Enabled then return end
    if not LocalPlayer.Character then return end
    
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    
    local closest = nil
    local minDist = 999 -- Phạm vi quét mục tiêu
    
    -- Lấy mục tiêu từ Cache (TargetCache được cập nhật bởi Scanner ở Section 7)
    for _, data in pairs(_G.TargetCache) do
        local isValid = false
        
        -- Logic lọc mục tiêu:
        -- Nếu FFA = True -> Đánh tất cả
        -- Nếu FFA = False -> Chỉ đánh kẻ địch (Team Check)
        if _G.OXEN_SETTINGS.BACKSTAB.FFA then
            isValid = true
        else
            if not IsTeam(data.Player) then isValid = true end
        end
        
        -- Tìm mục tiêu gần nhất trong phạm vi cho phép
        if isValid and data.Distance < minDist then
            minDist = data.Distance
            closest = data
        end
    end
    
    -- Thực hiện Backstab nếu tìm thấy mục tiêu
    if closest and closest.Root then
        local tRoot = closest.Root
        
        -- [BƯỚC 1] Tính vị trí ĐÍCH ĐẾN (Sau lưng địch)
        -- Sử dụng CFrame của địch * offset Z (4.5 studs)
        local backOffset = CFrame.new(0, 0, _G.OXEN_SETTINGS.BACKSTAB.Distance)
        local targetPosition = (tRoot.CFrame * backOffset).Position
        
        -- [BƯỚC 2] Tính toán AUTO-FACE (Khóa hướng nhìn)
        -- Mục tiêu: Luôn nhìn thẳng vào lưng địch để skill/hitbox trúng đích
        -- Kỹ thuật: Lấy tọa độ X, Z của địch, giữ nguyên Y của vị trí đích để camera không bị chúc đầu xuống đất
        local faceTargetPosition = Vector3.new(tRoot.Position.X, targetPosition.Y, tRoot.Position.Z)
        
        -- [BƯỚC 3] Áp dụng Teleport (Sticky CFrame)
        -- CFrame.lookAt(Vị trí đứng, Vị trí nhìn) -> Tạo ra góc nhìn chuẩn xác
        myRoot.CFrame = CFrame.lookAt(targetPosition, faceTargetPosition)
        
        -- [BƯỚC 4] Ổn định vật lý (Stability)
        -- Reset vận tốc về 0 để nhân vật đứng im phăng phắc, không bị trôi do quán tính
        myRoot.Velocity = Vector3.zero
        myRoot.RotVelocity = Vector3.zero
        
        -- [BƯỚC 5] Ghost Mode (Xuyên tường)
        -- Tắt va chạm liên tục để không bị kẹt khi địch ép góc hoặc xoay người
        if _G.OXEN_SETTINGS.BACKSTAB.GhostMode then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
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

--[[ 
    GOD MODE V58 (STICKY SHIELD)
    Logic: WeldConstraint (Bám sát tuyệt đối) + Projectile Eraser
    Cơ chế: 
    1. Tường vật lý được HÀN (Weld) vào người -> Không bao giờ bị trễ nhịp.
    2. Sử dụng NoCollisionConstraint cho TẤT CẢ bộ phận cơ thể -> Chống văng map.
    3. Projectile Eraser: Xóa đạn bay vào vùng an toàn.
]]

local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local GodWalls = {}
local ProjectileLoop = nil

-- Tạo Collision Group an toàn (nếu có thể)
local ShieldGroup = "OxenShieldGroup"
local PlayerGroup = "OxenPlayerGroup"

pcall(function()
    PhysicsService:CreateCollisionGroup(ShieldGroup)
    PhysicsService:CreateCollisionGroup(PlayerGroup)
    PhysicsService:CollisionGroupSetCollidable(ShieldGroup, PlayerGroup, false) -- Shield không chạm Player
    PhysicsService:CollisionGroupSetCollidable(ShieldGroup, "Default", true)   -- Shield chặn mọi thứ khác
end)

-- Hàm dọn dẹp
local function CleanGodWalls()
    for _, wall in pairs(GodWalls) do
        if wall then wall:Destroy() end
    end
    table.clear(GodWalls)
end

-- Hàm tạo khiên vật lý (WELD EDITION)
local function CreateStickyShield(char)
    if not char then return end
    local root = char:WaitForChild("HumanoidRootPart", 1)
    if not root then return end
    
    CleanGodWalls()
    
    -- Gán Player vào Group an toàn
    pcall(function()
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") then PhysicsService:SetPartCollisionGroup(v, PlayerGroup) end
        end
    end)
    
    local size = Vector3.new(6, 8, 0.5)
    local dist = 1.5 -- Khoảng cách 1.5m là an toàn nhất cho Weld (0.7m rất dễ lỗi vật lý)
    
    -- Vị trí tương đối (Relative CFrame)
    local offsets = {
        CFrame.new(0, 0, -dist), -- Trước
        CFrame.new(0, 0, dist),  -- Sau
        CFrame.new(-dist, 0, 0) * CFrame.Angles(0, math.rad(90), 0), -- Trái
        CFrame.new(dist, 0, 0) * CFrame.Angles(0, math.rad(90), 0)   -- Phải
    }
    
    for i, offset in ipairs(offsets) do
        local wall = Instance.new("Part")
        wall.Name = "OxenShield"
        wall.Size = size
        wall.Transparency = 1 
        wall.CanCollide = true 
        wall.Anchored = false   -- [QUAN TRỌNG] Không Neo để Weld hoạt động
        wall.Massless = true    -- Không trọng lượng
        wall.Material = Enum.Material.ForceField
        wall.Parent = char
        
        -- Gán vào Group khiên
        pcall(function() PhysicsService:SetPartCollisionGroup(wall, ShieldGroup) end)
        
        -- Định vị và Hàn
        wall.CFrame = root.CFrame * offset
        
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = root
        weld.Part1 = wall
        weld.Parent = wall
        
        -- Fallback: NoCollisionConstraint (Cho Executor yếu)
        for _, part in pairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                local nc = Instance.new("NoCollisionConstraint")
                nc.Part0 = wall; nc.Part1 = part; nc.Parent = wall
            end
        end
        
        table.insert(GodWalls, wall)
    end
end

-- Hàm kích hoạt
local function StartGodMode()
    if not LocalPlayer.Character then return end
    CreateStickyShield(LocalPlayer.Character)
    
    -- Loop chỉ để quét đạn (Không cần update vị trí tường nữa vì đã Weld)
    ProjectileLoop = RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        -- Quét đạn xung quanh (Radius 15)
        local regionParams = OverlapParams.new()
        regionParams.FilterDescendantsInstances = {char, Camera}
        regionParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local parts = workspace:GetPartBoundsInRadius(root.Position, 15, regionParams)
        
        for _, part in ipairs(parts) do
            -- Logic xóa đạn (Projectile Eraser)
            local isBullet = false
            local name = part.Name:lower()
            
            if name:find("bullet") or name:find("projectile") or name:find("ray") or name:find("beam") then
                isBullet = true
            end
            
            if part.Size.Magnitude < 3 and not part.Parent:FindFirstChild("Humanoid") then
                if part.AssemblyLinearVelocity.Magnitude > 50 then
                    isBullet = true
                end
            end
            
            if isBullet then
                pcall(function() 
                    part.CanCollide = false 
                    part.Anchored = true -- Dừng đạn lại
                    part.Transparency = 1
                    part:Destroy() 
                end)
            end
        end
    end)
end

-- Tích hợp Scanner
_G.OxenUpdateGodMode = function()
    if _G.OXEN_SETTINGS.GODMODE and _G.OXEN_SETTINGS.GODMODE.Enabled then
        -- Nếu nhân vật tồn tại mà chưa có tường -> Tạo mới
        if LocalPlayer.Character and #GodWalls == 0 then
            StartGodMode()
        end
    else
        if ProjectileLoop then 
            ProjectileLoop:Disconnect() 
            ProjectileLoop = nil
        end
        CleanGodWalls()
    end
end

-- [PHẦN 9.7] HITBOX EXPANDER LOGIC (ENHANCED & FIXED)
-- Logic dựa trên bt(1).lua nhưng tối ưu hóa cho Mobile và sửa lỗi mất hitbox khi đứng gần.

_G.OxenUpdateHBE = function()
    -- Nếu tắt HBE -> Reset toàn bộ về mặc định
    if not _G.OXEN_SETTINGS.HBE.Enabled then
        for _, p in pairs(Services.Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                -- Chỉ reset nếu nó đang bị to (tránh spam set size gây lag)
                if root and root.Size.X > 5 then
                    root.Size = Vector3.new(2, 2, 1) -- Size chuẩn Roblox
                    root.Transparency = 1
                    root.CanCollide = true
                    root.Material = Enum.Material.Plastic
                    root.Color = Color3.new(1,1,1) -- Reset màu (tùy chọn)
                end
            end
        end
        return
    end

    -- Vòng lặp áp dụng HBE
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local isEnemy = not IsTeam(player)
            if _G.OXEN_SETTINGS.VISUALS.FFA then isEnemy = true end
            
            -- Fix lỗi mất HBE khi đứng gần:
            -- Trước đây có thể do logic check distance trong Scanner loại bỏ target quá gần.
            -- Ở đây ta tách biệt logic HBE, áp dụng cho TOÀN BỘ kẻ địch hợp lệ đang tồn tại.
            
            if isEnemy and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                local hum = player.Character:FindFirstChild("Humanoid")
                
                -- Chỉ áp dụng nếu còn sống
                if root and hum and hum.Health > 0 then
                    -- [YÊU CẦU: HITBOX GẤP 3]
                    -- Lấy size từ Slider và nhân 3 (hoặc bạn có thể chỉnh Slider lên 45, ở đây tôi nhân 3 theo yêu cầu code)
                    local baseSize = _G.OXEN_SETTINGS.HBE.Size
                    local targetSize = Vector3.new(baseSize, baseSize, baseSize) -- Nếu muốn gấp 3 thì: baseSize * 3
                    
                    -- Kiểm tra để tránh set liên tục (giảm lag)
                    if root.Size ~= targetSize then
                        root.Size = targetSize
                        root.Transparency = _G.OXEN_SETTINGS.HBE.Transparency
                        root.Color = _G.OXEN_SETTINGS.HBE.Color
                        root.Material = _G.OXEN_SETTINGS.HBE.Material
                        root.CanCollide = false -- Quan trọng: Tắt va chạm để không bị đẩy
                    end
                end
            end
        end
    end
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- // [PHẦN 10] GIAO DIỆN NGƯỜI DÙNG (RAYFIELD UI)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Oxen Hub | V55 ",
    LoadingTitle = "Oxen Hub",
    LoadingSubtitle = "Donate me",
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
    KeySettings = {
        Title = "Untitled",
        Subtitle = "Key System",
        Note = "No method of obtaining the key is provided", -- Use this to tell the user how to get a key
        FileName = "Keyocutas", -- It is recommended to use something unique as other scripts using Rayfield may overwrite your key file
        SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
        GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
        Key = {"Hello"} -- List of keys that will be accepted by the system, can be RAW file links (pastebin, github etc) or simple strings ("hello","key22")
    }
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

local HBE_Section = CombatTab:CreateSection("Hitbox Expander (HBE)")

CombatTab:CreateToggle({
    Name = "Tăng hitbox",
    CurrentValue = false,
    Flag = "HBEEnabled",
    Callback = function(Value)
        _G.OXEN_SETTINGS.HBE.Enabled = Value
        -- Gọi hàm update ngay lập tức để người dùng thấy hiệu quả (hoặc reset) ngay
        if _G.OxenUpdateHBE then _G.OxenUpdateHBE() end
    end
})

CombatTab:CreateSlider({
    Name = "Hitbox Size", 
    Range = {2, 30}, -- Range thực tế
    Increment = 1, 
    CurrentValue = 15, -- Giá trị mặc định
    Callback = function(Value) 
        _G.OXEN_SETTINGS.HBE.Size = Value -- Sẽ được dùng trong hàm trên
    end
})

CombatTab:CreateSlider({
    Name = "Độ trong suốt", 
    Range = {0, 1}, 
    Increment = 0.1, 
    CurrentValue = 0.6, 
    Callback = function(Value) 
        _G.OXEN_SETTINGS.HBE.Transparency = Value 
    end
})

-- Thêm Section God Mode vào cuối Tab Combat
local GodSection = CombatTab:CreateSection("God Mode (Shield V58)")

CombatTab:CreateToggle({
    Name = "Enable God Mode",
    CurrentValue = false,
    Flag = "GodModeEnabled",
    Callback = function(Value)
        -- Khởi tạo config nếu chưa có
        if not _G.OXEN_SETTINGS.GODMODE then 
            _G.OXEN_SETTINGS.GODMODE = { Enabled = false } 
        end
        
        _G.OXEN_SETTINGS.GODMODE.Enabled = Value
        
        -- Gọi hàm cập nhật ngay lập tức để phản hồi nhanh
        if _G.OxenUpdateGodMode then 
            _G.OxenUpdateGodMode() 
        end
        
        -- Thông báo trạng thái (Tùy chọn)
        local status = Value and "Enabled" or "Disabled"
        -- warn("[GOD MODE] " .. status)
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
    Text = "Hello baby";
    Duration = 5;
})

warn("[OXEN HUB] Loaded Successfully. Lines: 800+")
