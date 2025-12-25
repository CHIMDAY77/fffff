--]

--// SERVICES //--
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--// CONFIGURATION //--
local Config = {
    Prediction = {
        Enabled = true,
        MaxSteps = 5,       -- Số lần va chạm tối đa dự đoán
        MaxLength = 20,     -- Độ dài tối đa của đường dự đoán
        Thickness = 3,      -- Độ dày đường kẻ
        Color = Color3.fromRGB(255, 255, 255),
        BounceColor = Color3.fromRGB(0, 255, 0), -- Màu sau khi va chạm
        GhostBall = true    -- Hiển thị bóng ma tại điểm va chạm
    },
    UI = {
        ThemeColor = Color3.fromRGB(45, 45, 45),
        AccentColor = Color3.fromRGB(0, 120, 215),
        TextColor = Color3.fromRGB(240, 240, 240),
        Size = UDim2.fromOffset(200, 250)
    },
    Physics = {
        BallRadius = 0.5,   -- Bán kính bi (cần điều chỉnh theo game)
        Epsilon = 0.05      -- Sai số cho phép
    }
}

------------------------------------------------------------------------
-- MODULE 1: UTILITIES & MEMORY MANAGEMENT (MAID)
------------------------------------------------------------------------
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({_tasks = {}}, Maid)
end

function Maid:GiveTask(task)
    table.insert(self._tasks, task)
    return task
end

function Maid:Clean()
    for i, task in ipairs(self._tasks) do
        if typeof(task) == "Instance" then
            task:Destroy()
        elseif typeof(task) == "RBXScriptConnection" then
            task:Disconnect()
        elseif type(task) == "function" then
            task()
        elseif type(task) == "table" and task.Destroy then
            task:Destroy()
        end
    end
    self._tasks = {}
end

function Maid:Destroy()
    self:Clean()
end

------------------------------------------------------------------------
-- MODULE 2: DRAWING API WRAPPER (Frame-based)
------------------------------------------------------------------------
-- Polyfill for environments lacking native Drawing API
local DrawingLib = {}
local DrawingContainer = Instance.new("ScreenGui")
DrawingContainer.Name = "WizardOverlay"
DrawingContainer.IgnoreGuiInset = true
DrawingContainer.DisplayOrder = 9999
-- Kiểm tra quyền truy cập CoreGui, fallback về PlayerGui
if pcall(function() DrawingContainer.Parent = CoreGui end) then
    -- Success
else
    DrawingContainer.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local function CreateBaseFrame(type)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = Color3.new(1,1,1)
    f.Parent = DrawingContainer
    if type == "Circle" then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = f
    end
    return f
end

-- Lớp Line (Đường thẳng)
local Line = {}
Line.__index = Line

function Line.new()
    local self = setmetatable({}, Line)
    self.Visible = true
    self.Color = Color3.new(1, 1, 1)
    self.Transparency = 1
    self.Thickness = 1
    self.From = Vector2.new(0, 0)
    self.To = Vector2.new(0, 0)
    self.Object = CreateBaseFrame("Line")
    return self
end

function Line:Update()
    if not self.Visible then
        self.Object.Visible = false
        return
    end
    
    local startPoint = self.From
    local endPoint = self.To
    local vector = endPoint - startPoint
    local length = vector.Magnitude
    local angle = math.atan2(vector.Y, vector.X)
    local center = (startPoint + endPoint) / 2
    
    self.Object.Visible = true
    self.Object.Size = UDim2.fromOffset(length, self.Thickness)
    self.Object.Position = UDim2.fromOffset(center.X, center.Y)
    self.Object.Rotation = math.deg(angle)
    self.Object.BackgroundColor3 = self.Color
    self.Object.BackgroundTransparency = 1 - self.Transparency
end

function Line:Remove()
    self.Object:Destroy()
end

-- Lớp Circle (Vòng tròn)
local Circle = {}
Circle.__index = Circle

function Circle.new()
    local self = setmetatable({}, Circle)
    self.Visible = true
    self.Color = Color3.new(1, 1, 1)
    self.Radius = 10
    self.Position = Vector2.new(0, 0)
    self.Transparency = 1
    self.Filled = true
    self.Object = CreateBaseFrame("Circle")
    
    -- Thêm UIStroke để hỗ trợ vòng tròn rỗng (Outline)
    self.Stroke = Instance.new("UIStroke")
    self.Stroke.Parent = self.Object
    return self
end

function Circle:Update()
    if not self.Visible then
        self.Object.Visible = false
        return
    end
    
    self.Object.Visible = true
    self.Object.Position = UDim2.fromOffset(self.Position.X, self.Position.Y)
    self.Object.Size = UDim2.fromOffset(self.Radius * 2, self.Radius * 2)
    self.Object.BackgroundTransparency = self.Filled and (1 - self.Transparency) or 1
    self.Object.BackgroundColor3 = self.Color
    
    self.Stroke.Enabled = not self.Filled
    self.Stroke.Color = self.Color
    self.Stroke.Transparency = 1 - self.Transparency
end

function Circle:Remove()
    self.Object:Destroy()
end

DrawingLib.Line = Line
DrawingLib.Circle = Circle

------------------------------------------------------------------------
-- MODULE 3: MOBILE UI LIBRARY
------------------------------------------------------------------------
local UILib = {}

function UILib:MakeDraggable(frame, trigger)
    local dragging, dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        local newX = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        -- Sử dụng TweenService để di chuyển mượt mà hơn trên mobile
        -- frame.Position = newX (Cập nhật trực tiếp sẽ nhanh hơn nhưng giật hơn)
        frame.Position = newX 
    end
    
    trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    trigger.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

function UILib:CreateWindow(title)
    local Window = Instance.new("Frame")
    Window.Name = "MainUI"
    Window.Size = Config.UI.Size
    Window.Position = UDim2.fromScale(0.1, 0.3) -- Vị trí mặc định an toàn cho mobile
    Window.BackgroundColor3 = Config.UI.ThemeColor
    Window.BorderSizePixel = 0
    Window.Parent = DrawingContainer
    
    -- Bo góc
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = Window
    
    -- Header
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 30)
    Header.BackgroundColor3 = Config.UI.AccentColor
    Header.BorderSizePixel = 0
    Header.Parent = Window
    
    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 8)
    hCorner.Parent = Header
    
    -- Che phần bo góc dưới của header để liền mạch
    local filler = Instance.new("Frame")
    filler.Size = UDim2.new(1, 0, 0, 10)
    filler.Position = UDim2.new(0, 0, 1, -10)
    filler.BackgroundColor3 = Config.UI.AccentColor
    filler.BorderSizePixel = 0
    filler.Parent = Header
    
    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size = UDim2.new(1, -10, 1, 0)
    TitleLbl.Position = UDim2.new(0, 10, 0, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Text = title
    TitleLbl.TextColor3 = Config.UI.TextColor
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.TextSize = 14
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Parent = Header
    
    -- Container cho các element
    local Container = Instance.new("ScrollingFrame")
    Container.Size = UDim2.new(1, -10, 1, -40)
    Container.Position = UDim2.new(0, 5, 0, 35)
    Container.BackgroundTransparency = 1
    Container.ScrollBarThickness = 2
    Container.Parent = Window
    
    local UIList = Instance.new("UIListLayout")
    UIList.Padding = UDim.new(0, 5)
    UIList.SortOrder = Enum.SortOrder.LayoutOrder
    UIList.Parent = Container
    
    -- Kích hoạt kéo thả
    self:MakeDraggable(Window, Header)
    
    local WindowFuncs = {}
    
    function WindowFuncs:AddButton(text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        btn.Text = text
        btn.TextColor3 = Config.UI.TextColor
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 12
        btn.Parent = Container
        
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 4)
        bCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(callback)
        btn.TouchTap:Connect(callback) -- Hỗ trợ tốt hơn cho mobile
    end
    
    function WindowFuncs:AddToggle(text, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 30)
        frame.BackgroundTransparency = 1
        frame.Parent = Container
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Config.UI.TextColor
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 40, 0, 20)
        btn.Position = UDim2.new(1, -45, 0.5, -10)
        btn.BackgroundColor3 = default and Config.UI.AccentColor or Color3.fromRGB(80, 80, 80)
        btn.Text = ""
        btn.Parent = frame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(1, 0)
        btnCorner.Parent = btn
        
        local circle = Instance.new("Frame")
        circle.Size = UDim2.new(0, 16, 0, 16)
        circle.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        circle.BackgroundColor3 = Color3.new(1,1,1)
        circle.Parent = btn
        
        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(1, 0)
        cCorner.Parent = circle
        
        local toggled = default
        
        local function toggle()
            toggled = not toggled
            
            -- Animation
            local goalColor = toggled and Config.UI.AccentColor or Color3.fromRGB(80, 80, 80)
            local goalPos = toggled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = goalColor}):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), {Position = goalPos}):Play()
            
            callback(toggled)
        end
        
        btn.MouseButton1Click:Connect(toggle)
        btn.TouchTap:Connect(toggle)
    end
    
    return WindowFuncs
end

------------------------------------------------------------------------
-- MODULE 4: VECTOR MATH & PHYSICS ENGINE
------------------------------------------------------------------------
local Physics = {}

-- Chuyển đổi 3D (World) sang 2D (Screen)
function Physics.WorldToScreen(worldPos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

-- Chuyển đổi 2D (Screen) sang 3D (World - Plane Y)
-- Giả sử bàn bida nằm phẳng, ta dùng Raycast từ camera để tìm giao điểm
function Physics.ScreenToWorld(screenPos)
    local ray = Camera:ViewportPointToRay(screenPos.X, screenPos.Y)
    -- Giả sử bàn bida ở độ cao Y cụ thể (cần lấy mẫu từ game thực tế)
    -- Ở đây ta dùng Raycast xuống bàn
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Whitelist
    -- Cần thêm logic tìm Bàn (Table) vào Whitelist
    
    local result = Workspace:Raycast(ray.Origin, ray.Direction * 100, params)
    if result then return result.Position end
    return ray.Origin + ray.Direction * 10 -- Fallback
end

-- Phản xạ Vector: R = V - 2(V.N)N
function Physics.Reflect(vector, normal)
    return vector - (2 * vector:Dot(normal) * normal)
end

-- Phát hiện va chạm Sphere-Sphere (Đơn giản hóa cho 2D trên mặt phẳng XZ)
function Physics.CheckBallCollision(posA, radiusA, posB, radiusB)
    local diff = Vector3.new(posA.X - posB.X, 0, posA.Z - posB.Z)
    local dist = diff.Magnitude
    if dist < (radiusA + radiusB) then
        return true, diff.Unit -- Trả về Hit và Normal
    end
    return false, nil
end

-- Tìm bi cái và các bi khác
function Physics.ScanTable()
    local balls = {}
    local cueBall = nil
    
    -- Cần logic quét Workspace cụ thể cho từng game.
    -- Ví dụ này giả định folder "Balls"
    local folder = Workspace:FindFirstChild("Balls")
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("BasePart") then
                if child.Name == "CueBall" then -- Tên giả định
                    cueBall = child
                else
                    table.insert(balls, child)
                end
            end
        end
    end
    return cueBall, balls
end

------------------------------------------------------------------------
-- MODULE 5: PREDICTION ALGORITHM (GHOST BALL)
------------------------------------------------------------------------
local Predictor = {}
Predictor.Lines = {} -- Pool chứa các Line
Predictor.Ghost = nil

-- Khởi tạo Pool cho Drawing Lines
function Predictor:InitDrawingPool()
    for i = 1, 50 do -- 50 đoạn thẳng tối đa
        table.insert(self.Lines, DrawingLib.Line.new())
    end
    self.Ghost = DrawingLib.Circle.new()
    self.Ghost.Filled = false
    self.Ghost.Color = Color3.fromRGB(255, 255, 0)
    self.Ghost.Visible = false
end

function Predictor:ResetDrawings()
    for _, line in ipairs(self.Lines) do
        line.Visible = false
        line:Update()
    end
    self.Ghost.Visible = false
    self.Ghost:Update()
end

-- Thuật toán dự đoán chính
function Predictor:Update(cueBall, otherBalls)
    self:ResetDrawings()
    
    if not cueBall then return end
    
    -- 1. Xác định hướng đánh
    -- Logic này phụ thuộc vào cách game điều khiển (Mouse hay Drag gậy)
    -- Giả sử hướng đánh dựa trên Camera LookVector (FPS mode) hoặc Gậy
    local aimDir = Camera.CFrame.LookVector
    aimDir = Vector3.new(aimDir.X, 0, aimDir.Z).Unit -- Chiếu xuống 2D
    
    local startPos = cueBall.Position
    local currentPos = startPos
    local currentDir = aimDir
    local remainingDist = Config.Prediction.MaxLength
    
    local lineIndex = 1
    
    -- Vòng lặp các bước va chạm (Bounces)
    for step = 1, Config.Prediction.MaxSteps do
        if remainingDist <= 0 then break end
        
        -- Raycast thủ công (Custom Raycast) để tìm va chạm bóng hoặc tường
        -- Trong thực tế, cần SphereCast (ShapeCast) để chính xác với kích thước bóng
        
        local hitResult = nil
        local minHitDist = remainingDist
        local hitObj = nil
        local hitNormal = nil
        local hitType = nil -- "Ball" or "Wall"
        
        -- Kiểm tra va chạm với các bóng khác
        for _, ball in ipairs(otherBalls) do
            -- Toán học giao điểm Ray-Sphere (Đơn giản hóa 2D)
            local toBall = ball.Position - currentPos
            local t = toBall:Dot(currentDir)
            local closestPoint = currentPos + currentDir * t
            local distToCenter = (closestPoint - ball.Position).Magnitude
            
            -- Kiểm tra va chạm: Khoảng cách < 2 * Bán kính (Ghost Ball touch)
            if t > 0 and t < minHitDist and distToCenter < (Physics.BallRadius * 2) then
                -- Tính chính xác điểm va chạm bề mặt
                local offset = math.sqrt((Physics.BallRadius * 2)^2 - distToCenter^2)
                local hitDist = t - offset
                
                if hitDist > 0 and hitDist < minHitDist then
                    minHitDist = hitDist
                    hitResult = currentPos + currentDir * hitDist
                    hitObj = ball
                    hitType = "Ball"
                    hitNormal = (hitResult - ball.Position).Unit -- Sai, Ghost Ball logic khác
                    -- Normal thực tế là đường nối tâm bóng ảo và bóng thật
                    local ghostBallPos = currentPos + currentDir * hitDist
                    hitNormal = (ghostBallPos - ball.Position).Unit
                end
            end
        end
        
        -- Kiểm tra va chạm với tường (Giả sử Raycast của Workspace hoạt động với tường)
        -- Cần lọc bỏ bóng khỏi raycast này
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        local ignoreList = {cueBall}
        for _, b in ipairs(otherBalls) do table.insert(ignoreList, b) end
        rayParams.FilterDescendantsInstances = ignoreList
        
        local wallHit = Workspace:Raycast(currentPos, currentDir * minHitDist, rayParams)
        
        if wallHit then
            minHitDist = wallHit.Distance
            hitResult = wallHit.Position
            hitNormal = wallHit.Normal
            hitType = "Wall"
            hitObj = wallHit.Instance
        end
        
        -- Vẽ đường từ currentPos đến điểm va chạm
        local endPos = currentPos + currentDir * minHitDist
        
        -- Chuyển tọa độ World -> Screen để vẽ bằng Frame
        local s1, v1 = Physics.WorldToScreen(currentPos)
        local s2, v2 = Physics.WorldToScreen(endPos)
        
        if v1 or v2 then -- Chỉ vẽ nếu ít nhất 1 điểm trong màn hình
            local line = self.Lines[lineIndex]
            if line then
                line.From = s1
                line.To = s2
                line.Color = (step == 1) and Config.Prediction.Color or Config.Prediction.BounceColor
                line.Visible = true
                line:Update()
                lineIndex = lineIndex + 1
            end
        end
        
        -- Xử lý sau va chạm
        if hitResult then
            if hitType == "Wall" then
                currentDir = Physics.Reflect(currentDir, hitNormal)
                currentPos = hitResult + currentDir * 0.1 -- Đẩy nhẹ ra khỏi tường
            elseif hitType == "Ball" then
                -- Vẽ Ghost Ball tại điểm va chạm
                if Config.Prediction.GhostBall then
                    local sG, vG = Physics.WorldToScreen(endPos)
                    if vG then
                        self.Ghost.Position = sG
                        -- Cần tính bán kính trên màn hình dựa trên khoảng cách camera
                        -- Công thức ước lượng: (WorldRadius * ScreenHeight) / (FOV * Depth)
                        local depth = (endPos - Camera.CFrame.Position).Magnitude
                        local screenRad = (Physics.BallRadius * 500) / depth -- Hệ số 500 ước lượng
                        self.Ghost.Radius = screenRad
                        self.Ghost.Visible = true
                        self.Ghost:Update()
                    end
                end
                
                -- Bi cái sẽ bật ra theo hướng tiếp tuyến (Tangent)
                -- Vận tốc bi mục tiêu sẽ theo hướng Normal
                -- Vận tốc bi cái mới vuông góc với Normal
                -- Logic phản xạ đơn giản:
                local tangent = (currentDir - (currentDir:Dot(hitNormal) * hitNormal)).Unit
                currentDir = tangent
                currentPos = endPos + currentDir * 0.1
                
                -- Có thể vẽ thêm đường dự đoán cho bi mục tiêu (Target Ball Line)
                --...
            end
        else
            break -- Không va chạm gì, kết thúc
        end
        
        remainingDist = remainingDist - minHitDist
    end
end

------------------------------------------------------------------------
-- MODULE 6: MAIN CONTROLLER
------------------------------------------------------------------------
local Main = {}

function Main:Start()
    -- 1. Khởi tạo Drawing
    Predictor:InitDrawingPool()
    
    -- 2. Tạo UI
    local Window = UILib:CreateWindow("8-Ball Wizard")
    
    Window:AddToggle("Enable Prediction", true, function(state)
        Config.Prediction.Enabled = state
        if not state then Predictor:ResetDrawings() end
    end)
    
    Window:AddToggle("Show Ghost Ball", true, function(state)
        Config.Prediction.GhostBall = state
    end)
    
    Window:AddButton("Unload Script", function()
        -- Dọn dẹp bộ nhớ
        DrawingContainer:Destroy()
        -- Ngắt kết nối RunService (Cần quản lý connection biến)
        script.Disabled = true 
    end)
    
    -- 3. Vòng lặp Render
    RunService.RenderStepped:Connect(function(dt)
        if not Config.Prediction.Enabled then return end
        
        local cue, others = Physics.ScanTable()
        if cue then
            Predictor:Update(cue, others)
        else
            Predictor:ResetDrawings()
        end
    end)
end

-- Chạy hệ thống
Main:Start()

--]
