--]

--// 1. SERVICES //--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

--// 2. CẤU HÌNH (SETTINGS) //--
local Config = {
    -- Tên của bi cái trong game (Cần chỉnh sửa nếu game đặt tên khác)
    -- Các tên phổ biến: "CueBall", "WhiteBall", "MainBall"
    BallName = "CueBall", 
    
    -- Màu sắc
    LineColor = Color3.fromRGB(255, 255, 255),      -- Màu đường chính
    BounceColor = Color3.fromRGB(0, 255, 0),        -- Màu đường sau khi nảy
    DotColor = Color3.new(0, 0, 0),                 -- Màu chấm đen lỗ
    
    -- Thông số kỹ thuật
    LineWidth = 3,           -- Độ dày đường vẽ
    MaxDistance = 50,        -- Độ dài tối đa của tia dự đoán
    MaxBounces = 3,          -- Số lần nảy băng tối đa
    DotSize = 30             -- Kích thước chấm định vị lỗ (pixel)
}

--// 3. THƯ VIỆN VẼ GUI (VIRTUAL DRAWING LIB) //--
-- Thay thế Drawing.new để tránh lỗi trên Delta Mobile
local DrawLib = {}
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BidaPredictionOverlay"
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 10000
ScreenGui.ResetOnSpawn = false

-- Bảo vệ GUI (nếu Executor hỗ trợ)
if syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = CoreGui
elseif gethui then
    ScreenGui.Parent = gethui()
else
    ScreenGui.Parent = CoreGui
end

local LinePool = {}
local ActiveLines = {}

-- Hàm lấy Frame từ "bể chứa" (Object Pooling) để tiết kiệm RAM
local function GetLineFrame()
    local line = table.remove(LinePool)
    if not line then
        line = Instance.new("Frame")
        line.Name = "Line"
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BorderSizePixel = 0
        line.ZIndex = 5
        line.Parent = ScreenGui
    end
    line.Visible = true
    return line
end

function DrawLib:Clear()
    for _, line in ipairs(ActiveLines) do
        line.Visible = false
        table.insert(LinePool, line)
    end
    table.clear(ActiveLines)
end

function DrawLib:DrawLine(from, to, color, thickness)
    local center = (from + to) / 2
    local vector = to - from
    local length = vector.Magnitude
    if length < 1 then return end -- Không vẽ nếu quá ngắn

    local angle = math.atan2(vector.Y, vector.X)
    local line = GetLineFrame()

    line.Position = UDim2.fromOffset(center.X, center.Y)
    line.Size = UDim2.fromOffset(length, thickness or Config.LineWidth)
    line.Rotation = math.deg(angle)
    line.BackgroundColor3 = color or Config.LineColor
    
    table.insert(ActiveLines, line)
end

--// 4. HỆ THỐNG 6 CHẤM ĐỊNH VỊ (CALIBRATION DOTS) //--
local Calibration = {}
local Dots = {}

function Calibration:Init()
    local CalibGui = Instance.new("ScreenGui")
    CalibGui.Name = "CalibrationUI"
    CalibGui.DisplayOrder = 10001
    if gethui then CalibGui.Parent = gethui() else CalibGui.Parent = CoreGui end

    -- Hàm làm cho GUI kéo thả được trên Mobile
    local function MakeDraggable(guiObject)
        local dragging = false
        local dragInput, dragStart, startPos

        guiObject.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = guiObject.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        guiObject.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                guiObject.Position = UDim2.new(
                    startPos.X.Scale, 
                    startPos.X.Offset + delta.X, 
                    startPos.Y.Scale, 
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- Tạo 6 chấm đen
    -- Vị trí mặc định (tương đối)
    local defaultPositions = {
        UDim2.new(0.1, 0, 0.2, 0), UDim2.new(0.5, 0, 0.15, 0), UDim2.new(0.9, 0, 0.2, 0), -- 3 lỗ trên
        UDim2.new(0.1, 0, 0.8, 0), UDim2.new(0.5, 0, 0.85, 0), UDim2.new(0.9, 0, 0.8, 0)  -- 3 lỗ dưới
    }

    for i = 1, 6 do
        local dot = Instance.new("Frame")
        dot.Name = "HoleDot_".. i
        dot.Size = UDim2.fromOffset(Config.DotSize, Config.DotSize)
        dot.BackgroundColor3 = Config.DotColor
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = defaultPositions[i]
        
        -- Làm tròn thành hình tròn
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = dot
        
        -- Viền trắng để dễ nhìn
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.new(1, 1, 1)
        stroke.Thickness = 2
        stroke.Parent = dot
        
        dot.Parent = CalibGui
        MakeDraggable(dot)
        table.insert(Dots, dot)
    end

    -- Nút Ẩn/Hiện Chấm (Toggle UI)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleDots"
    toggleBtn.Size = UDim2.fromOffset(100, 40)
    toggleBtn.Position = UDim2.new(0.5, -50, 0.05, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.Text = "Ẩn Lỗ (Hide)"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    
    local cornerBtn = Instance.new("UICorner")
    cornerBtn.CornerRadius = UDim.new(0, 8)
    cornerBtn.Parent = toggleBtn
    
    toggleBtn.Parent = CalibGui

    local isVisible = true
    toggleBtn.MouseButton1Click:Connect(function()
        isVisible = not isVisible
        for _, dot in ipairs(Dots) do
            dot.Visible = isVisible
        end
        toggleBtn.Text = isVisible and "Ẩn Lỗ (Hide)" or "Hiện Lỗ (Show)"
    end)
end

--// 5. PHYSICS ENGINE (XỬ LÝ VẬT LÝ) //--

local function GetCueBall()
    -- Tìm bi cái trong Workspace. Bạn có thể cần sửa tên "CueBall" tùy vào game
    -- Game bida thường để bi trong folder "Balls" hoặc ngay trong Workspace
    local target = Workspace:FindFirstChild(Config.BallName, true)
    
    -- Nếu không tìm thấy theo tên, thử tìm part màu trắng hình cầu (Advanced logic)
    if not target then
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") and v.Name == "White" or (v:IsA("BasePart") and v.Color == Color3.new(1,1,1) and v.Shape == Enum.PartType.Ball) then
                return v
            end
        end
    end
    return target
end

local function CalculateTrajectory(startPos, direction)
    local points = {startPos}
    local currentPos = startPos
    local currentDir = direction
    
    -- Raycast Params: Bỏ qua nhân vật và chính bi cái
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = {LocalPlayer.Character, GetCueBall()}
    params.FilterDescendantsInstances = ignoreList

    for i = 1, Config.MaxBounces + 1 do
        -- Bắn tia Raycast
        local result = Workspace:Raycast(currentPos, currentDir * Config.MaxDistance, params)
        
        if result then
            -- Nếu va chạm
            table.insert(points, result.Position)
            
            -- Tính toán phản xạ: R = D - 2(D.N)N
            local n = result.Normal
            local d = currentDir
            local reflect = d - (2 * d:Dot(n) * n)
            
            -- Cập nhật vị trí và hướng mới cho lần lặp sau
            currentDir = reflect
            -- Dịch chuyển điểm bắt đầu ra xa bề mặt một chút để tránh kẹt tia
            currentPos = result.Position + (reflect * 0.1)
        else
            -- Nếu không va chạm gì, vẽ tia dài ra vô tận (trong tầm MaxDistance)
            table.insert(points, currentPos + (currentDir * Config.MaxDistance))
            break
        end
    end
    
    return points
end

--// 6. MAIN LOOP (VÒNG LẶP CHÍNH) //--

Calibration:Init() -- Khởi tạo UI lỗ

RunService.RenderStepped:Connect(function()
    DrawLib:Clear() -- Xóa đường cũ mỗi khung hình
    
    local cueBall = GetCueBall()
    if not cueBall then return end
    
    -- Lấy hướng Camera để làm hướng đánh
    -- Game bida trên mobile thường đánh theo hướng nhìn Camera
    local camDir = Camera.CFrame.LookVector
    -- Ép vector xuống mặt phẳng ngang (bỏ qua trục Y cao thấp)
    local aimDir = Vector3.new(camDir.X, 0, camDir.Z).Unit
    
    -- Tính toán đường đi
    local pathPoints = CalculateTrajectory(cueBall.Position, aimDir)
    
    -- Vẽ đường đi
    for i = 1, #pathPoints - 1 do
        local p1 = pathPoints[i]
        local p2 = pathPoints[i+1]
        
        -- Chuyển tọa độ 3D thế giới -> 2D màn hình
        local pos1, vis1 = Camera:WorldToViewportPoint(p1)
        local pos2, vis2 = Camera:WorldToViewportPoint(p2)
        
        if vis1 or vis2 then -- Chỉ vẽ nếu ít nhất 1 điểm nằm trong màn hình
            local vec1 = Vector2.new(pos1.X, pos1.Y)
            local vec2 = Vector2.new(pos2.X, pos2.Y)
            
            -- Đoạn đầu tiên màu Trắng, các đoạn nảy sau màu Xanh
            local color = (i == 1) and Config.LineColor or Config.BounceColor
            
            DrawLib:DrawLine(vec1, vec2, color)
        end
    end
end)

print("✅ Delta Billiard Script Loaded!")
