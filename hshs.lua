--[[
    ADVANCED COMBAT DESYNC: VELOCITY SPLIT & VISUAL CHAOS
    Target: Delta X Mobile
    Technique: 
      1. Velocity Spoofing (Confuse Server Prediction)
      2. CFrame Desynchronization (Split Render vs Physics)
      3. Visual Ghosting (Distraction)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
local Camera = Workspace.CurrentCamera

-- --- CẤU HÌNH (CONFIG) ---
local Config = {
    DesyncSpeed = 1.0,        -- Tốc độ di chuyển khi Desync (16 * n)
    GhostInterval = 0.1,      -- Tốc độ tạo bóng
    GhostColor = Color3.fromRGB(0, 255, 255), -- Màu Cyan
    VelocityVector = Vector3.new(0, 10000, 0) -- Vector gây nhiễu Server
}

-- Biến trạng thái
local State = {
    Enabled = false,
    ClientCFrame = nil,
    LastGhost = 0
}

-- --- PHẦN 1: UI LIBRARY TỐI ƯU CHO DELTA (TOUCH) ---

-- Dọn dẹp UI cũ
if LocalPlayer.PlayerGui:FindFirstChild("DesyncInterface") then
    LocalPlayer.PlayerGui.DesyncInterface:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DesyncInterface"
ScreenGui.ResetOnSpawn = false
-- Ưu tiên gethui cho Executor đời mới
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Container chính (Nút tròn)
local MainBtn = Instance.new("TextButton")
MainBtn.Name = "ToggleBtn"
MainBtn.Size = UDim2.new(0, 55, 0, 55)
MainBtn.Position = UDim2.new(0.05, 0, 0.45, 0) -- Vị trí ngón cái trái
MainBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainBtn.Text = "⚡"
MainBtn.TextSize = 24
MainBtn.AutoButtonColor = true
MainBtn.Parent = ScreenGui

-- Bo tròn & Viền
local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(1, 0)
Corner.Parent = MainBtn

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(255, 255, 255)
Stroke.Thickness = 2.5
Stroke.Parent = MainBtn

-- Label trạng thái
local StatusTxt = Instance.new("TextLabel")
StatusTxt.Size = UDim2.new(2, 0, 0.3, 0)
StatusTxt.Position = UDim2.new(-0.5, 0, 1.15, 0)
StatusTxt.BackgroundTransparency = 1
StatusTxt.Text = "SYNCED"
StatusTxt.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusTxt.Font = Enum.Font.GothamBold
StatusTxt.TextSize = 12
StatusTxt.TextStrokeTransparency = 0.5
StatusTxt.Parent = MainBtn

-- --- LOGIC KÉO THẢ (DRAG) ---
local dragging, dragInput, dragStart, startPos
MainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainBtn.Position
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

-- --- PHẦN 2: VISUAL FX (BÓNG MỜ/AFTERIMAGE) ---

local function SpawnGhost(cf)
    if not Character then return end
    Character.Archivable = true -- Bắt buộc cho Clone
    
    local GhostModel = Instance.new("Model")
    GhostModel.Name = "DesyncGhost"
    
    -- Clone Visuals
    for _, v in pairs(Character:GetChildren()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" and v.Transparency < 1 then
            local p = v:Clone()
            p.Parent = GhostModel
            p.CFrame = v.CFrame -- Clone tại vị trí hiển thị hiện tại
            p.Anchored = true
            p.CanCollide = false
            p.Material = Enum.Material.ForceField -- Hiệu ứng điện tử
            p.Color = Config.GhostColor
            p.Transparency = 0.6
            
            -- Xóa tạp chất
            for _, c in pairs(p:GetChildren()) do 
                if not c:IsA("SpecialMesh") then c:Destroy() end 
            end
            
            -- Hiệu ứng biến mất
            TweenService:Create(p, TweenInfo.new(0.5), {Transparency = 1, Color = Color3.new(1,1,1)}):Play()
        end
    end
    
    GhostModel.Parent = Workspace
    task.delay(0.5, function() GhostModel:Destroy() end)
end

-- --- PHẦN 3: CORE DESYNC LOGIC (VELOCITY MANIPULATION) ---

local function ToggleDesync()
    State.Enabled = not State.Enabled
    
    if State.Enabled then
        -- KÍCH HOẠT DESYNC
        Stroke.Color = Color3.fromRGB(0, 255, 255) -- Cyan
        MainBtn.BackgroundColor3 = Color3.fromRGB(0, 50, 50)
        StatusTxt.Text = "DESYNC ACTIVE"
        StatusTxt.TextColor3 = Color3.fromRGB(0, 255, 255)
        
        -- Snapshot vị trí bắt đầu
        State.ClientCFrame = HRP.CFrame
        
        -- Ngắt vật lý (Physics Edge Case: PlatformStand ngăn server can thiệp chuyển động)
        Humanoid.PlatformStand = true
        
        -- Tắt va chạm để tránh bị kẹt khi desync
        for _, v in pairs(Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
        
    else
        -- TẮT DESYNC
        Stroke.Color = Color3.fromRGB(255, 255, 255)
        MainBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        StatusTxt.Text = "SYNCED"
        StatusTxt.TextColor3 = Color3.fromRGB(200, 200, 200)
        
        Humanoid.PlatformStand = false
        HRP.AssemblyLinearVelocity = Vector3.zero -- Reset vận tốc
        
        -- Đồng bộ lại vị trí
        HRP.CFrame = State.ClientCFrame
        
        -- Bật lại va chạm
        for _, v in pairs(Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = true end
        end
    end
end

-- --- LOOPS (TRÁI TIM CỦA DESYNC) ---

-- 1. Heartbeat (Physics Loop): Thao tác Server
RunService.Heartbeat:Connect(function(dt)
    if State.Enabled and HRP and Character then
        -- KỸ THUẬT: VELOCITY SPOOFING
        -- Thay vì để Velocity = 0, ta set nó thành một giá trị cực lớn hướng lên trên
        -- Server sẽ bối rối trong việc nội suy (interpolate) vị trí thực tế -> Hitbox bị lag lại
        HRP.AssemblyLinearVelocity = Config.VelocityVector 
        HRP.AssemblyAngularVelocity = Vector3.zero
        
        -- Có thể thêm logic giữ Hitbox Server tại một chỗ cũ (Lag switch simulation)
        -- Nhưng Velocity Spoofing thường hiệu quả hơn để né đạn (Bullet miss)
    end
end)

-- 2. RenderStepped (Visual Loop): Thao tác Client
RunService.RenderStepped:Connect(function(dt)
    if State.Enabled and HRP and Character then
        -- TÍNH TOÁN DI CHUYỂN CLIENT (Tự code lại movement)
        local moveDir = Humanoid.MoveDirection
        
        if moveDir.Magnitude > 0 then
            -- Di chuyển CFrame độc lập với Server
            local newPos = State.ClientCFrame.Position + (moveDir * (16 * Config.DesyncSpeed * dt))
            
            -- Xoay mặt theo hướng đi
            local lookAt = State.ClientCFrame.Position + moveDir
            State.ClientCFrame = CFrame.new(newPos, lookAt)
            
            -- TẠO GHOST TRAIL (Gây nhiễu thị giác)
            if tick() - State.LastGhost > Config.GhostInterval then
                SpawnGhost(State.ClientCFrame)
                State.LastGhost = tick()
            end
        end
        
        -- ÉP HIỂN THỊ
        -- Client nhìn thấy mình đang lướt mượt mà, nhưng Server thì thấy Velocity đang loạn xạ
        HRP.CFrame = State.ClientCFrame
    end
end)

-- --- INPUT HANDLER ---

-- Sử dụng Activated (Tối ưu cho Mobile Touch)
MainBtn.Activated:Connect(function()
    if not dragging then ToggleDesync() end
end)

-- Phím tắt cho PC (nếu cần test)
UserInputService.InputBegan:Connect(function(inp, gp)
    if not gp and inp.KeyCode == Enum.KeyCode.B then ToggleDesync() end
end)

-- Reset khi chết
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    HRP = Character:WaitForChild("HumanoidRootPart")
    Humanoid = Character:WaitForChild("Humanoid")
    if State.Enabled then ToggleDesync() end -- Tắt để tránh lỗi spawn
end)
