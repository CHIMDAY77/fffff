--[[
    GOD MODE V8 - DELTA X MOBILE FIX
    Fix: "Frozen Character" issue on Mobile
    Method: Physics State Override + Camera-based Movement
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
local Camera = Workspace.CurrentCamera

-- --- CẤU HÌNH ---
local Config = {
    Speed = 1, -- Tốc độ di chuyển (1 = Bình thường, 2 = Nhanh)
    FlyHeight = 0 -- Độ cao so với mặt đất (0 = đi bộ, >0 = bay)
}

-- Biến hệ thống
local DesyncEnabled = false
local SafeSpotCFrame = nil
local VisualCFrame = nil 

-- --- UI SETUP (GỌN NHẸ) ---
if LocalPlayer.PlayerGui:FindFirstChild("GodV8UI") then
    LocalPlayer.PlayerGui.GodV8UI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GodV8UI"
ScreenGui.ResetOnSpawn = false
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Nút Bấm
local MainBtn = Instance.new("TextButton")
MainBtn.Name = "MainBtn"
MainBtn.Size = UDim2.new(0, 60, 0, 60)
MainBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
MainBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainBtn.Text = "🏃" -- Icon Chạy
MainBtn.TextSize = 25
MainBtn.AutoButtonColor = true
MainBtn.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(1, 0)
Corner.Parent = MainBtn

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(255, 255, 255)
Stroke.Thickness = 2
Stroke.Parent = MainBtn

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(2, 0, 0.3, 0)
StatusLabel.Position = UDim2.new(-0.5, 0, 1.1, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "OFF"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 14
StatusLabel.Parent = MainBtn

-- --- LOGIC KÉO THẢ ---
local dragging, dragInput, dragStart, startPos
MainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = MainBtn.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
MainBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- --- LOGIC XỬ LÝ DI CHUYỂN (MOVEMENT FIX) ---

local function EnableGod()
    DesyncEnabled = true
    StatusLabel.Text = "GOD ON"
    StatusLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
    MainBtn.BackgroundColor3 = Color3.fromRGB(0, 50, 0)
    
    -- 1. Lưu vị trí núp (Safe Spot)
    SafeSpotCFrame = HRP.CFrame
    VisualCFrame = HRP.CFrame
    
    -- Marker
    local m = Instance.new("Part")
    m.Name = "HitboxMarker"
    m.Size = Vector3.new(2,5,2)
    m.CFrame = SafeSpotCFrame
    m.Anchored = true
    m.CanCollide = false
    m.Transparency = 0.5
    m.Color = Color3.fromRGB(255,0,0)
    m.Parent = Workspace
    
    -- 2. Thay đổi trạng thái vật lý (Thay vì PlatformStand)
    -- Giúp Joystick vẫn hoạt động
    Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    
    -- Tắt va chạm
    for _, v in pairs(Character:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = false end
    end
end

local function DisableGod()
    DesyncEnabled = false
    StatusLabel.Text = "OFF"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    MainBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    
    if Workspace:FindFirstChild("HitboxMarker") then Workspace.HitboxMarker:Destroy() end
    
    -- Reset trạng thái
    Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    
    -- Dịch chuyển về vị trí Client
    HRP.CFrame = VisualCFrame
    HRP.AssemblyLinearVelocity = Vector3.zero
    
    for _, v in pairs(Character:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = true end
    end
end

-- --- CORE LOOP (KHẮC PHỤC LỖI ĐỨNG IM) ---

RunService.RenderStepped:Connect(function(dt)
    if DesyncEnabled and Character and HRP and Humanoid then
        -- 1. LIÊN TỤC FORCE TRẠNG THÁI PHYSICS (Để không bị server đè)
        Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        Humanoid.WalkSpeed = 0 -- Tắt tốc độ mặc định để tự code di chuyển
        
        -- 2. TÍNH TOÁN DI CHUYỂN THỦ CÔNG (JOYSTICK FIX)
        local moveDir = Humanoid.MoveDirection -- Lấy hướng Joystick
        local camCFrame = Camera.CFrame
        
        -- Nếu MoveDirection bị kẹt (bằng 0), thử dùng Camera LookVector nếu đang chạm màn hình (Optional)
        
        if moveDir.Magnitude > 0 then
            -- Tính hướng đi dựa trên Camera
            -- Vì Humanoid.MoveDirection đã tự tính theo Camera rồi, ta chỉ cần nhân tốc độ
            local nextPos = VisualCFrame.Position + (moveDir * (16 * Config.Speed * dt))
            
            -- Giữ độ cao Y ổn định (Đi trên mặt đất) hoặc bay tùy chỉnh
            -- Để đi bộ mượt, ta lấy Y của địa hình hoặc giữ nguyên Y cũ
            nextPos = Vector3.new(nextPos.X, VisualCFrame.Y + Config.FlyHeight, nextPos.Z)
            
            -- Cập nhật VisualCFrame (Vị trí ảo)
            VisualCFrame = CFrame.new(nextPos, nextPos + moveDir)
        end
        
        -- 3. ÉP HIỂN THỊ CLIENT
        HRP.CFrame = VisualCFrame
        HRP.AssemblyLinearVelocity = Vector3.zero
    end
end)

RunService.Heartbeat:Connect(function()
    if DesyncEnabled and HRP then
        -- 4. ÉP SERVER THẤY HITBOX Ở CHỖ NÚP
        local saveVel = HRP.AssemblyLinearVelocity
        HRP.CFrame = SafeSpotCFrame
        HRP.AssemblyLinearVelocity = Vector3.zero 
    end
end)

-- --- INPUT ---
MainBtn.Activated:Connect(function() if not dragging then if DesyncEnabled then DisableGod() else EnableGod() end end end)

LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    HRP = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
    if DesyncEnabled then DisableGod() end
end)
