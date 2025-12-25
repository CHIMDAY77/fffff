--
    2. Visuals: Tạo bóng mờ (Ghost Trail) dùng Highlight Instance tối ưu GPU.[2]
    3. UI: Giao diện Fluent Design tinh tế, có nút bật/tắt riêng cho Mobile.
]]

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    TweenService = game:GetService("TweenService"),
    Workspace = game:GetService("Workspace"),
    CoreGui = game:GetService("CoreGui"),
    Debris = game:GetService("Debris")
}

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

-- // CẤU HÌNH TRẠNG THÁI (STATE CONFIG) //
getgenv().Config = {
    Desync = {
        Enabled = false,
        Intensity = 25000, -- Ngưỡng vận tốc gây lag server
        Randomize = true,  -- Random hướng để khó bị anticheat bắt
        VisualizeHitbox = false -- (Tùy chọn nâng cao)
    },
    Visuals = {
        GhostTrail = false,
        Color = Color3.fromRGB(0, 255, 255), -- Màu Cyan mặc định
        Transparency = 0.5,
        Duration = 0.5, -- Thời gian bóng tồn tại
        RefreshRate = 0.15 -- Tần suất tạo bóng (Giảm số này nếu máy mạnh)
    }
}

-- // TẢI THƯ VIỆN UI (FLUENT) [3] //
local Fluent = loadstring(game:HttpGet("[https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua](https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua)"))()
local SaveManager = loadstring(game:HttpGet("[https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua](https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua)"))()
local InterfaceManager = loadstring(game:HttpGet("[https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua](https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua)"))()

local Window = Fluent:CreateWindow({
    Title = "Delta X Arena",
    SubTitle = "Mobile Desync",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460), -- Kích thước vừa phải cho tablet/điện thoại ngang
    Acrylic = false, -- Tắt Acrylic để giảm lag trên mobile
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- // MODULE 1: MOBILE TOGGLE BUTTON (NÚT BẬT TẮT UI) //
-- Vì mobile không có phím Ctrl phải, ta tạo một nút ảo trên màn hình
local function CreateMobileButton()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DeltaMobileControls"
    -- Cố gắng parent vào CoreGui để không bị game xóa, nếu không thì vào PlayerGui
    pcall(function() ScreenGui.Parent = Services.CoreGui end)
    if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name = "ToggleUI"
    ToggleBtn.Size = UDim2.fromOffset(50, 50)
    ToggleBtn.Position = UDim2.new(0.9, -60, 0.1, 0) -- Góc trên bên phải, cách lề
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.Text = "UI"
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 14
    ToggleBtn.BackgroundTransparency = 0.2
    ToggleBtn.Parent = ScreenGui

    -- Bo tròn nút
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = ToggleBtn

    -- Viền nút
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(0, 255, 213)
    Stroke.Thickness = 2
    Stroke.Parent = ToggleBtn

    -- Chức năng bật/tắt
    ToggleBtn.MouseButton1Click:Connect(function()
        Window:Minimize()
    end)
    
    -- Cho phép kéo nút này đi chỗ khác (Mobile Drag) [4]
    local dragging, dragInput, dragStart, startPos
    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = ToggleBtn.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    
    ToggleBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    Services.UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            ToggleBtn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

CreateMobileButton()

-- // MODULE 2: DESYNC ENGINE //
-- Logic: Thay đổi Velocity cực nhanh để đánh lừa server (Server thấy đi xa, Client thấy bình thường)
local function StartDesync()
    Services.RunService.Heartbeat:Connect(function()
        if not getgenv().Config.Desync.Enabled then return end
        
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if root then
            local originalVel = root.AssemblyLinearVelocity
            
            -- Tạo vector vận tốc ảo [1]
            local intensity = getgenv().Config.Desync.Intensity
            local x = getgenv().Config.Desync.Randomize and math.random(-2000, 2000) or 0
            local z = getgenv().Config.Desync.Randomize and math.random(-2000, 2000) or 0
            
            -- Gửi vận tốc ảo lên server
            root.AssemblyLinearVelocity = Vector3.new(x, intensity, z)
            
            -- Khôi phục vận tốc thật ngay lập tức để Client không bị giật (RenderStepped chạy sau Heartbeat)
            Services.RunService.RenderStepped:Wait()
            root.AssemblyLinearVelocity = originalVel
        end
    end)
end

StartDesync()

-- // MODULE 3: GHOST TRAIL VISUALIZER (High Performance) //
-- Sử dụng Highlight Instance thay vì clone từng part để tối ưu cho Mobile GPU [5, 2]
local function SpawnGhost()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    -- Chỉ tạo bóng khi nhân vật di chuyển
    if char.HumanoidRootPart.AssemblyLinearVelocity.Magnitude < 2 then return end

    char.Archivable = true
    local ghost = char:Clone()
    ghost.Name = "VisualGhost"
    
    -- Dọn dẹp clone: Xóa script, xóa phụ kiện rườm rà nếu cần
    for _, child in ipairs(ghost:GetDescendants()) do
        if child:IsA("BasePart") then
            child.Anchored = true
            child.CanCollide = false
            child.Massless = true
            child.Material = Enum.Material.ForceField -- Hiệu ứng đẹp nhẹ
            child.CastShadow = false
        elseif child:IsA("Script") or child:IsA("LocalScript") or child:IsA("Sound") or child:IsA("BillboardGui") then
            child:Destroy()
        end
    end
    
    -- Áp dụng Highlight
    local hl = Instance.new("Highlight")
    hl.FillColor = getgenv().Config.Visuals.Color
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.FillTransparency = getgenv().Config.Visuals.Transparency
    hl.OutlineTransparency = 0.5
    hl.Parent = ghost
    
    ghost.Parent = Services.Workspace
    ghost:PivotTo(char:GetPivot()) -- Đặt vị trí khớp với nhân vật
    
    -- Hiệu ứng biến mất dần
    local tweenInfo = TweenInfo.new(getgenv().Config.Visuals.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = Services.TweenService:Create(hl, tweenInfo, {FillTransparency = 1, OutlineTransparency = 1})
    tween:Play()
    
    Services.Debris:AddItem(ghost, getgenv().Config.Visuals.Duration)
end

-- Vòng lặp tạo bóng (Tách biệt khỏi RenderStepped để không tụt FPS)
task.spawn(function()
    while true do
        if getgenv().Config.Visuals.GhostTrail then
            pcall(SpawnGhost)
        end
        task.wait(getgenv().Config.Visuals.RefreshRate)
    end
end)

-- // XÂY DỰNG GIAO DIỆN (TABS & ELEMENTS) //

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Tab Combat
local DesyncGroup = Tabs.Combat:AddSection("Desync Logic")

local ToggleDesync = DesyncGroup:AddToggle("DesyncState", {Title = "Enable Desync", Default = false })
ToggleDesync:OnChanged(function()
    getgenv().Config.Desync.Enabled = ToggleDesync.Value
    if ToggleDesync.Value then
        Fluent:Notify({Title = "Desync", Content = "Đã kích hoạt chế độ Desync", Duration = 3})
    end
end)

DesyncGroup:AddSlider("DesyncIntensity", {
    Title = "Desync Intensity",
    Description = "Độ mạnh của việc ngắt đồng bộ (Cao = Lag hơn)",
    Default = 25000,
    Min = 5000,
    Max = 50000,
    Rounding = 0,
    Callback = function(Value)
        getgenv().Config.Desync.Intensity = Value
    end
})

DesyncGroup:AddToggle("RandomizeVec", {Title = "Randomize Vectors", Default = true, Description = "Làm quỹ đạo khó đoán hơn" })
:OnChanged(function(Value)
    getgenv().Config.Desync.Randomize = Value
end)

-- Tab Visuals
local VisualGroup = Tabs.Visuals:AddSection("Ghost Trail")

local ToggleGhost = VisualGroup:AddToggle("GhostState", {Title = "Enable Ghost Trail", Default = false })
ToggleGhost:OnChanged(function()
    getgenv().Config.Visuals.GhostTrail = ToggleGhost.Value
end)

VisualGroup:AddColorpicker("GhostColor", {
    Title = "Trail Color",
    Default = getgenv().Config.Visuals.Color,
    Callback = function(Value)
        getgenv().Config.Visuals.Color = Value
    end
})

VisualGroup:AddSlider("TrailDuration", {
    Title = "Duration (Seconds)",
    Default = 0.5,
    Min = 0.1,
    Max = 2.0,
    Rounding = 1,
    Callback = function(Value)
        getgenv().Config.Visuals.Duration = Value
    end
})

-- Tab Settings
Tabs.Settings:AddButton({
    Title = "Unload Script",
    Description = "Xóa giao diện và dừng script",
    Callback = function()
        Window:Destroy()
        getgenv().Config.Desync.Enabled = false
        getgenv().Config.Visuals.GhostTrail = false
        -- Xóa nút mobile
        local btn = Services.CoreGui:FindFirstChild("DeltaMobileControls")
        if btn then btn:Destroy() end
    end
})

Window:SelectTab(1)
Fluent:Notify({
    Title = "Delta Script Loaded",
    Content = "Sẵn sàng chiến đấu! Nhấn nút 'UI' để ẩn menu.",
    Duration = 5
})
