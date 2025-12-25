--[[ 
    Mobile Ghost Trail Visual FX Script (Delta X Fixed)
    Fixes: Archivable property, UI Parenting, Mobile Touch Input
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Camera = workspace.CurrentCamera

-- --- CẤU HÌNH (SETTINGS) ---
local Settings = {
    Enabled = false,
    Interval = 0.1, 
    FadeTime = 0.5, 
    Color = Color3.fromRGB(100, 255, 255), 
    TransparencyStart = 0.6, 
    Material = Enum.Material.ForceField 
}

-- --- UI SETUP (DELTA X OPTIMIZED) ---
-- Xóa UI cũ nếu có để tránh trùng lặp khi chạy lại script
if Player.PlayerGui:FindFirstChild("GhostFX_GUI") then
    Player.PlayerGui.GhostFX_GUI:Destroy()
end
if CoreGui:FindFirstChild("GhostFX_GUI") then
    CoreGui.GhostFX_GUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GhostFX_GUI"
ScreenGui.ResetOnSpawn = false -- Giữ UI khi chết

-- Delta X hỗ trợ gethui tốt nhất, nếu không thì dùng PlayerGui cho an toàn
if gethui then
    ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then 
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = CoreGui
else
    ScreenGui.Parent = Player:WaitForChild("PlayerGui")
end

-- 1. Nút Bật/Tắt Menu
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Parent = ScreenGui
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Text = "FX"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 20
ToggleBtn.BorderSizePixel = 0
ToggleBtn.AutoButtonColor = true

local UICornerBtn = Instance.new("UICorner")
UICornerBtn.CornerRadius = UDim.new(1, 0)
UICornerBtn.Parent = ToggleBtn

local UIStrokeBtn = Instance.new("UIStroke")
UIStrokeBtn.Parent = ToggleBtn
UIStrokeBtn.Color = Color3.fromRGB(100, 255, 255)
UIStrokeBtn.Thickness = 2
UIStrokeBtn.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- 2. Bảng Menu Chính
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
MainFrame.Size = UDim2.new(0, 220, 0, 180)
MainFrame.Visible = false
MainFrame.BorderSizePixel = 0

local UICornerFrame = Instance.new("UICorner")
UICornerFrame.CornerRadius = UDim.new(0, 10)
UICornerFrame.Parent = MainFrame

-- Tiêu đề
local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 0, 0, 10)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.GothamBold
Title.Text = "VISUAL FX SETTINGS"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16

-- Nút kích hoạt
local SwitchBtn = Instance.new("TextButton")
SwitchBtn.Parent = MainFrame
SwitchBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Đỏ
SwitchBtn.Position = UDim2.new(0.1, 0, 0.4, 0)
SwitchBtn.Size = UDim2.new(0.8, 0, 0, 40)
SwitchBtn.Font = Enum.Font.Gotham
SwitchBtn.Text = "Ghost Mode: OFF"
SwitchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SwitchBtn.TextSize = 14
SwitchBtn.AutoButtonColor = false

local UICornerSwitch = Instance.new("UICorner")
UICornerSwitch.CornerRadius = UDim.new(0, 8)
UICornerSwitch.Parent = SwitchBtn

-- Note
local Note = Instance.new("TextLabel")
Note.Parent = MainFrame
Note.BackgroundTransparency = 1
Note.Position = UDim2.new(0.05, 0, 0.7, 0)
Note.Size = UDim2.new(0.9, 0, 0, 40)
Note.Font = Enum.Font.Gotham
Note.Text = "Fix for Delta X Mobile\nBật để tạo hiệu ứng bóng mờ."
Note.TextColor3 = Color3.fromRGB(150, 150, 150)
Note.TextSize = 12
Note.TextWrapped = true

-- --- CHỨC NĂNG KÉO THẢ (Fixed Logic) ---
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- --- LOGIC HIỆU ỨNG (DELTA FIXED) ---

local function CreateGhost()
    -- Kiểm tra kỹ Character và RootPart để tránh crash
    if not Character or not Character.Parent then return end
    local HRP = Character:FindFirstChild("HumanoidRootPart")
    if not HRP then return end
    
    -- Chỉ tạo bóng nếu đang di chuyển (Tối ưu hiệu năng mobile)
    if HRP.Velocity.Magnitude < 0.5 then return end

    -- [FIX QUAN TRỌNG] Bật Archivable để cho phép Clone
    Character.Archivable = true 

    local GhostModel = Instance.new("Model")
    GhostModel.Name = "GhostFX"
    
    for _, part in pairs(Character:GetChildren()) do
        -- Lọc bỏ HumanoidRootPart và các phần không nhìn thấy
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
            
            -- Sử dụng pcall để tránh lỗi khi clone MeshPart phức tạp trên mobile
            local success, GhostPart = pcall(function()
                return part:Clone()
            end)

            if success and GhostPart then
                GhostPart.Parent = GhostModel
                GhostPart.Anchored = true
                GhostPart.CanCollide = false
                GhostPart.CFrame = part.CFrame
                GhostPart.Material = Settings.Material
                GhostPart.Color = Settings.Color
                GhostPart.Transparency = Settings.TransparencyStart
                
                -- Xóa script, âm thanh, hiệu ứng hạt bên trong part
                for _, child in pairs(GhostPart:GetChildren()) do
                    if not child:IsA("SpecialMesh") then
                        child:Destroy()
                    end
                end
                
                -- Tween mờ dần
                local tweenInfo = TweenInfo.new(Settings.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local tween = TweenService:Create(GhostPart, tweenInfo, {Transparency = 1})
                tween:Play()
            end
        end
    end
    
    GhostModel.Parent = workspace
    
    -- Dọn dẹp
    task.delay(Settings.FadeTime, function()
        if GhostModel then GhostModel:Destroy() end
    end)
end

-- Vòng lặp
local LastTime = 0
RunService.Heartbeat:Connect(function(dt)
    if Settings.Enabled then
        local Now = tick()
        if Now - LastTime >= Settings.Interval then
            CreateGhost()
            LastTime = Now
        end
    end
end)

-- --- XỬ LÝ SỰ KIỆN UI ---

-- Sử dụng Activated thay vì MouseButton1Click để nhạy hơn trên màn hình cảm ứng
ToggleBtn.Activated:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

SwitchBtn.Activated:Connect(function()
    Settings.Enabled = not Settings.Enabled
    
    if Settings.Enabled then
        SwitchBtn.Text = "Ghost Mode: ON"
        SwitchBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    else
        SwitchBtn.Text = "Ghost Mode: OFF"
        SwitchBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
end)

-- Cập nhật Character khi respawn
Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
end)
