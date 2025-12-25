--[[
    ULTIMATE COMBAT DESYNC V7 - GOD MODE "TÁCH XÁC"
    Platform: Delta X Mobile Optimized
    Mechanism: Split-Frame CFrame Override + Custom Movement Handler
    Result: Visual Body moves freely, Actual Hitbox stays anchored.
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
    MoveSpeed = 20, -- Tốc độ di chuyển khi bật God Mode (Mặc định game là 16)
    JumpPower = 50  -- Lực nhảy (Nếu game cho phép nhảy)
}

-- Biến hệ thống
local DesyncEnabled = false
local HitboxAnchorCFrame = nil -- Vị trí xác thật (Hitbox)
local VisualCFrame = nil       -- Vị trí hình ảnh (Linh hồn)

-- --- UI SETUP (DELTA X) ---
if LocalPlayer.PlayerGui:FindFirstChild("GodModeUI") then
    LocalPlayer.PlayerGui.GodModeUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GodModeUI"
ScreenGui.ResetOnSpawn = false
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Nút Icon (Draggable)
local MainBtn = Instance.new("TextButton")
MainBtn.Name = "GodBtn"
MainBtn.Size = UDim2.new(0, 65, 0, 65)
MainBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
MainBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainBtn.Text = "🛡️"
MainBtn.TextSize = 30
MainBtn.AutoButtonColor = true
MainBtn.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(1, 0)
Corner.Parent = MainBtn

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(255, 255, 255)
Stroke.Thickness = 3
Stroke.Parent = MainBtn

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(2, 0, 0.3, 0)
Status.Position = UDim2.new(-0.5, 0, 1.15, 0)
Status.BackgroundTransparency = 1
Status.Text = "SAFE"
Status.TextColor3 = Color3.fromRGB(0, 255, 0)
Status.Font = Enum.Font.GothamBold
Status.TextSize = 14
Status.TextStrokeTransparency = 0.8
Status.Parent = MainBtn

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

-- --- LOGIC GOD MODE CHÍNH ---

local function CreateMarker(cf)
    if Workspace:FindFirstChild("HitboxMarker") then Workspace.HitboxMarker:Destroy() end
    local p = Instance.new("Part")
    p.Name = "HitboxMarker"
    p.Size = Vector3.new(2, 6, 2)
    p.CFrame = cf
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 0.4
    p.Color = Color3.fromRGB(255, 0, 0) -- Cột đỏ = Điểm yếu
    p.Material = Enum.Material.Neon
    p.Parent = Workspace
end

local function ToggleGod()
    DesyncEnabled = not DesyncEnabled
    
    if DesyncEnabled then
        -- BẬT GOD MODE
        Status.Text = "GOD ACTIVE"
        Status.TextColor3 = Color3.fromRGB(255, 50, 50)
        Stroke.Color = Color3.fromRGB(255, 50, 50)
        MainBtn.BackgroundColor3 = Color3.fromRGB(50, 10, 10)
        
        -- 1. Ghim vị trí Hitbox tại chỗ đứng hiện tại
        HitboxAnchorCFrame = HRP.CFrame
        VisualCFrame = HRP.CFrame
        
        -- Tạo cột đánh dấu điểm yếu
        CreateMarker(HitboxAnchorCFrame)
        
        -- 2. Ngắt hệ thống vật lý mặc định (Fix lỗi kẹt chân)
        Humanoid.PlatformStand = true
        
        -- Tắt va chạm để đi xuyên tường
        for _, v in pairs(Character:GetDescendants()) do
           if v:IsA("BasePart") then v.CanCollide = false end
        end
        
    else
        -- TẮT GOD MODE
        Status.Text = "SAFE"
        Status.TextColor3 = Color3.fromRGB(0, 255, 0)
        Stroke.Color = Color3.fromRGB(255, 255, 255)
        MainBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        
        if Workspace:FindFirstChild("HitboxMarker") then Workspace.HitboxMarker:Destroy() end
        
        -- Hồi phục vật lý
        Humanoid.PlatformStand = false
        HRP.AssemblyLinearVelocity = Vector3.zero
        
        -- Dịch chuyển về vị trí hình ảnh đang đứng
        HRP.CFrame = VisualCFrame
        
        -- Bật lại va chạm
        for _, v in pairs(Character:GetDescendants()) do
           if v:IsA("BasePart") then v.CanCollide = true end
        end
    end
end

-- --- VÒNG LẶP XỬ LÝ (BÍ MẬT CỦA DESYNC) ---

-- 1. HEARTBEAT (Gửi dữ liệu lên Server)
RunService.Heartbeat:Connect(function(dt)
    if DesyncEnabled and HRP and Character then
        -- ÉP SERVER NHÌN THẤY BẠN ĐỨNG IM TẠI CỘT ĐỎ
        HRP.AssemblyLinearVelocity = Vector3.zero -- Triệt tiêu vận tốc để không bị giật
        HRP.AssemblyAngularVelocity = Vector3.zero
        HRP.CFrame = HitboxAnchorCFrame -- Khóa vị trí Hitbox
    end
end)

-- 2. RENDERSTEPPED (Xử lý hình ảnh và di chuyển Client)
RunService.RenderStepped:Connect(function(dt)
    if DesyncEnabled and HRP and Character and Humanoid then
        -- HỆ THỐNG DI CHUYỂN THỦ CÔNG (Fix lỗi kẹt trên Mobile)
        -- Lấy hướng từ Joystick ảo
        local moveDir = Humanoid.MoveDirection
        
        -- Tính toán vị trí mới dựa trên tốc độ Config
        local newPos = VisualCFrame.Position
        if moveDir.Magnitude > 0 then
             newPos = newPos + (moveDir * Config.MoveSpeed * dt)
        end
        
        -- Xử lý nhảy thủ công (Nếu cần - thử nghiệm)
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or Humanoid.Jump then
             -- newPos = newPos + Vector3.new(0, Config.JumpPower * dt, 0) -- (Cần logic phức tạp hơn cho nhảy)
        end

        -- Cập nhật vị trí nhìn thấy, giữ độ cao Y ổn định hoặc theo địa hình nếu muốn
        -- Ở đây giữ nguyên Y để lướt đi cho mượt
        VisualCFrame = CFrame.new(Vector3.new(newPos.X, VisualCFrame.Y, newPos.Z), newPos + moveDir)
        
        -- ÉP MÀN HÌNH HIỂN THỊ VỊ TRÍ MỚI
        HRP.CFrame = VisualCFrame
    end
end)

-- INPUT
MainBtn.Activated:Connect(function() if not dragging then ToggleGod() end end)

-- Reset
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    HRP = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
    if DesyncEnabled then ToggleGod() end
end)
