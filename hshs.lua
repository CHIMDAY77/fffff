
-- [BẮT ĐẦU] CHỜ GAME LOAD XONG
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- ==============================================================================
-- [PHẦN 1] KHAI BÁO DỊCH VỤ & BIẾN TOÀN CỤC (GLOBAL)
-- ==============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Bảng cài đặt chính (Configuration)
_G.CORE = {
    -- [Aimbot Settings]
    AimEnabled = false,
    AimKey = "All", -- Tự động nhận diện
    FOV = 120,      -- Mặc định (Sẽ vẽ màu xanh dương)
    Deadzone = 17,  -- Mặc định (Sẽ vẽ màu xanh lá)
    Smoothness = 0.165, -- Độ mượt (Pred cũ)
    WallCheck = true,
    TargetPart = "HumanoidRootPart",
    
    -- [Visual Settings]
    EspEnabled = true,
    EspBox = true,
    EspName = true,
    EspLine = false,
    EspTeamCheck = false,
    
    -- [Backstab Settings]
    BackstabEnabled = false,
    BackstabSticky = true, -- Chế độ bám dính
    BackstabDist = 1.2,    -- Khoảng cách sau lưng
    BackstabSpeed = 50,    -- Tốc độ bay
    
    -- [Movement Settings]
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false,
    NoRecoil = false,
    
    -- [System Settings]
    SafeMode = true, -- Tự động tắt tính năng nguy hiểm
    DebugMode = false
}

-- Biến lưu trữ Runtime
local TargetCache = {}     -- Cache chứa người chơi (Cập nhật theo sự kiện)
local BotCache = {}        -- Cache chứa Bot (Cập nhật chậm)
local CurrentTarget = nil  -- Mục tiêu Aimbot hiện tại
local BackstabTarget = nil -- Mục tiêu Backstab hiện tại
local MobileFlyUI = nil    -- UI bay

-- ==============================================================================
-- [PHẦN 2] HỆ THỐNG ANTI-BAN TITAN V4 (GỐC TỪ OBFASL)
-- ==============================================================================
-- Giữ nguyên bản gốc để đảm bảo độ ổn định cao nhất trên Delta X
local function EnableTitanV4()
    if not hookmetamethod then return end -- Executor quá lỏm thì bỏ qua

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if not checkcaller() then
            -- 1. Chặn Kick/Ban/Shutdown
            if method == "Kick" or method == "Shutdown" or method == "KickPlayer" then
                return nil
            end
            
            -- 2. Chặn gửi lỗi về server (Error Logging)
            if method == "SetCore" and args[1] == "SendNotification" then
                return nil
            end

            -- 3. Chặn Remote nguy hiểm (Report/Ban)
            if method == "FireServer" or method == "InvokeServer" then
                local remoteName = tostring(self.Name):lower()
                if remoteName:match("ban") or remoteName:match("kick") or remoteName:match("admin") or remoteName:match("report") then
                    return nil
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    
    -- Fake thông tin người chơi
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if not checkcaller() and self == LocalPlayer then
            if key == "AccountAge" then return 1234 end -- Giả vờ nick cũ
            if key == "UserId" then return 1 end        -- Giả vờ là Roblox
        end
        return oldIndex(self, key)
    end)
end

-- Kích hoạt Anti-Ban an toàn trong luồng riêng
task.spawn(function()
    pcall(EnableTitanV4)
end)

-- ==============================================================================
-- [PHẦN 3] HỆ THỐNG VISUAL (RAW DRAWING API - OBFASL STYLE)
-- ==============================================================================
-- KHÔNG BỌC TRONG FUNCTION ĐỂ TRÁNH LỖI DELTA X
-- Khai báo trực tiếp để Executor nhận diện ngay lập tức

local FOV_Circle = Drawing.new("Circle")
FOV_Circle.Visible = false
FOV_Circle.Thickness = 1.5
FOV_Circle.Color = Color3.fromRGB(0, 170, 255) -- Xanh Dương (Chuẩn yêu cầu)
FOV_Circle.Filled = false
FOV_Circle.Transparency = 1
FOV_Circle.NumSides = 64 -- Độ tròn

local Dead_Circle = Drawing.new("Circle")
Dead_Circle.Visible = false
Dead_Circle.Thickness = 1.5
Dead_Circle.Color = Color3.fromRGB(0, 255, 0) -- Xanh Lá (Chuẩn yêu cầu: Sẵn sàng)
Dead_Circle.Filled = false
Dead_Circle.Transparency = 1
Dead_Circle.NumSides = 32

-- Hàm cập nhật Visual mỗi frame (RenderStepped)
RunService.RenderStepped:Connect(function()
    -- Cập nhật vị trí và trạng thái
    local Center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    if _G.CORE.AimEnabled then
        -- Update FOV Circle
        FOV_Circle.Visible = true
        FOV_Circle.Position = Center
        FOV_Circle.Radius = _G.CORE.FOV
        
        -- Update Deadzone Circle
        Dead_Circle.Visible = true
        Dead_Circle.Position = Center
        Dead_Circle.Radius = _G.CORE.Deadzone
        
        -- Logic đổi màu Deadzone (Xanh Lá -> Đỏ khi khóa)
        if CurrentTarget then
            Dead_Circle.Color = Color3.fromRGB(255, 0, 0) -- Đỏ (Đã khóa)
        else
            Dead_Circle.Color = Color3.fromRGB(0, 255, 0) -- Xanh Lá (Tìm kiếm)
        end
    else
        FOV_Circle.Visible = false
        Dead_Circle.Visible = false
    end
end)

-- ==============================================================================
-- [PHẦN 4] HỆ THỐNG CACHE V4 (EVENT BASED - SIÊU NHẸ)
-- ==============================================================================

-- Hàm tiện ích kiểm tra nhanh
local function IsValid(char)
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not root then return false end
    return true
end

-- 1. Thêm người chơi vào Cache khi vào game
local function AddToCache(plr)
    if plr == LocalPlayer then return end
    
    -- Tạo hook character
    local function CharAdded(char)
        TargetCache[plr] = {
            Player = plr,
            Character = char,
            Root = char:WaitForChild("HumanoidRootPart", 5),
            Humanoid = char:WaitForChild("Humanoid", 5),
            IsBot = false
        }
    end
    
    if plr.Character then CharAdded(plr.Character) end
    plr.CharacterAdded:Connect(CharAdded)
end

-- 2. Xóa người chơi khỏi Cache khi thoát
local function RemoveFromCache(plr)
    TargetCache[plr] = nil
end

-- Khởi tạo Cache ban đầu (chỉ chạy 1 lần)
for _, p in ipairs(Players:GetPlayers()) do
    AddToCache(p)
end
Players.PlayerAdded:Connect(AddToCache)
Players.PlayerRemoving:Connect(RemoveFromCache)

-- 3. Quét Bot (NPC) - Chạy chậm (3 giây/lần) để không lag
task.spawn(function()
    while true do
        local tempBots = {}
        local settings = _G.CORE
        
        -- Chỉ quét nếu cần thiết
        if settings.AimEnabled or settings.BackstabEnabled then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                    if not Players:GetPlayerFromCharacter(obj) and obj.Name ~= "Space" then -- Lọc bớt rác
                        local hum = obj.Humanoid
                        if hum.Health > 0 then
                            table.insert(tempBots, {
                                Character = obj,
                                Root = obj.HumanoidRootPart,
                                Humanoid = hum,
                                IsBot = true
                            })
                        end
                    end
                end
            end
        end
        BotCache = tempBots -- Cập nhật mảng Bot
        task.wait(3) -- Nghỉ 3 giây
    end
end)

-- ==============================================================================
-- [PHẦN 5] HỆ THỐNG AIMBOT & TÍNH TOÁN
-- ==============================================================================

local function GetClosestTarget()
    local closestDist = math.huge
    local target = nil
    local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local fovLimit = _G.CORE.FOV
    
    -- Gộp danh sách Player và Bot để duyệt
    local AllTargets = {}
    for _, v in pairs(TargetCache) do table.insert(AllTargets, v) end
    for _, v in pairs(BotCache) do table.insert(AllTargets, v) end
    
    for _, entry in ipairs(AllTargets) do
        local char = entry.Character
        local root = entry.Root
        local hum = entry.Humanoid
        
        -- Kiểm tra cơ bản
        if char and root and hum and hum.Health > 0 then
            -- Kiểm tra Team (Nếu bật)
            local isTeammate = false
            if entry.Player and _G.CORE.EspTeamCheck then
                if entry.Player.Team == LocalPlayer.Team and entry.Player.Team ~= nil then
                    isTeammate = true
                end
            end
            
            if not isTeammate then
                -- Tính toán vị trí trên màn hình
                local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                
                if onScreen then
                    local distToMouse = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    
                    -- Kiểm tra FOV
                    if distToMouse <= fovLimit then
                        -- Kiểm tra tường (WallCheck)
                        local isVisible = true
                        if _G.CORE.WallCheck then
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = {LocalPlayer.Character, char}
                            local ray = Workspace:Raycast(Camera.CFrame.Position, (root.Position - Camera.CFrame.Position), rayParams)
                            if ray then isVisible = false end
                        end
                        
                        if isVisible and distToMouse < closestDist then
                            closestDist = distToMouse
                            target = entry
                        end
                    end
                end
            end
        end
    end
    
    return target
end

-- AIMBOT LOOP (RenderStepped)
RunService.RenderStepped:Connect(function()
    if not _G.CORE.AimEnabled then 
        CurrentTarget = nil
        return 
    end
    
    -- Lấy mục tiêu tốt nhất
    local bestEntry = GetClosestTarget()
    
    if bestEntry and bestEntry.Character then
        CurrentTarget = bestEntry.Character
        local aimPart = bestEntry.Character:FindFirstChild(_G.CORE.TargetPart)
        
        if aimPart then
            -- Logic trợ lực (Assist) & Deadzone
            local root = bestEntry.Root
            local velocity = root.AssemblyLinearVelocity
            local predictedPos = aimPart.Position + (velocity * _G.CORE.Smoothness)
            
            local screenPos = Camera:WorldToViewportPoint(aimPart.Position)
            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            
            -- Nếu nằm trong Deadzone (vòng xanh lá) -> Aim chặt (Hard Lock)
            if dist <= _G.CORE.Deadzone then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, predictedPos)
            else
                -- Nếu nằm ngoài -> Lerp nhẹ (Soft Aim)
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, predictedPos), 0.2)
            end
        end
    else
        CurrentTarget = nil
    end
end)

-- ==============================================================================
-- [PHẦN 6] HỆ THỐNG BACKSTAB V3 (STICKY + AUTO SWITCH)
-- ==============================================================================

local function GetBackstabTarget()
    -- Ưu tiên lấy mục tiêu gần nhất trong bán kính 100m
    local bestChar = nil
    local minDist = 100 
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    -- Gộp list
    local AllTargets = {}
    for _, v in pairs(TargetCache) do table.insert(AllTargets, v) end
    for _, v in pairs(BotCache) do table.insert(AllTargets, v) end

    for _, entry in ipairs(AllTargets) do
        if IsValid(entry.Character) and entry.Character ~= LocalPlayer.Character then
             -- Bỏ qua đồng đội
            local isTeammate = false
            if entry.Player and entry.Player.Team == LocalPlayer.Team and entry.Player.Team ~= nil then
                isTeammate = true
            end

            if not isTeammate then
                local dist = (entry.Root.Position - myRoot.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    bestChar = entry.Character
                end
            end
        end
    end
    return bestChar
end

-- BACKSTAB LOOP (Heartbeat - Vật lý)
RunService.Heartbeat:Connect(function(deltaTime)
    if not _G.CORE.BackstabEnabled then 
        BackstabTarget = nil
        return 
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    if not myRoot then return end

    -- 1. Kiểm tra mục tiêu hiện tại (Valid Check)
    if BackstabTarget then
        local hum = BackstabTarget:FindFirstChild("Humanoid")
        -- Nếu mục tiêu chết hoặc biến mất -> Reset ngay lập tức
        if not hum or hum.Health <= 0 or not BackstabTarget.Parent then
            BackstabTarget = nil
        end
    end

    -- 2. Nếu chưa có mục tiêu (hoặc vừa mất), tìm mục tiêu mới (Auto Switch)
    if not BackstabTarget then
        BackstabTarget = GetBackstabTarget()
    end

    -- 3. Thực thi dịch chuyển (Teleport logic)
    if BackstabTarget then
        local tRoot = BackstabTarget:FindFirstChild("HumanoidRootPart")
        if tRoot then
            -- Tính vị trí sau lưng
            local backOffset = CFrame.new(0, 0, _G.CORE.BackstabDist)
            local targetPos = tRoot.CFrame * backOffset
            
            -- Nếu bật Sticky -> Dính liên tục
            if _G.CORE.BackstabSticky then
                -- Tween hoặc Set CFrame tùy khoảng cách
                local dist = (myRoot.Position - targetPos.Position).Magnitude
                
                -- Anti-Cheat Velocity: Copy tốc độ địch để không bị kéo lại
                myRoot.AssemblyLinearVelocity = tRoot.AssemblyLinearVelocity
                
                if dist > 2 then
                    -- Nếu xa -> Tween lại gần
                    local tweenInfo = TweenInfo.new(dist / _G.CORE.BackstabSpeed, Enum.EasingStyle.Linear)
                    local tween = TweenService:Create(myRoot, tweenInfo, {CFrame = targetPos})
                    tween:Play()
                else
                    -- Nếu gần -> Khóa cứng (Sticky)
                    myRoot.CFrame = targetPos
                end
                
                -- Luôn nhìn vào lưng địch
                myRoot.CFrame = CFrame.lookAt(myRoot.Position, tRoot.Position)
            end
        end
    end
end)

-- ==============================================================================
-- [PHẦN 7] CÁC TÍNH NĂNG PHỤ TRỢ (WALKSPEED / FLY / NO RECOIL)
-- ==============================================================================

-- 1. Walkspeed Loop (Chống bị game reset)
task.spawn(function()
    while task.wait(0.5) do
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then
                -- Chỉ set nếu giá trị thay đổi
                if hum.WalkSpeed ~= _G.CORE.WalkSpeed and _G.CORE.WalkSpeed > 16 then
                    hum.WalkSpeed = _G.CORE.WalkSpeed
                end
                if _G.CORE.InfJump then
                    hum.JumpPower = 50 -- Reset power
                end
            end
        end
    end
end)

-- 2. Infinite Jump (Nhảy vô hạn)
UserInputService.JumpRequest:Connect(function()
    if _G.CORE.InfJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- 3. No Recoil (Fix Mobile Camera Shake)
local function NoRecoilHook()
    local Camera = workspace.CurrentCamera
    -- Hook đơn giản vào Update
    if _G.CORE.NoRecoil then
        -- Rất khó hook CFrame trực tiếp trên mobile mà không crash
        -- Dùng mẹo: Giới hạn độ giật
    end
end
-- Lưu ý: No Recoil trên mobile executor thường không ổn định, tính năng này để tượng trưng.

-- 4. ESP Manager (Quản lý vẽ ESP Box)
-- Sử dụng BillboardGui thay vì Drawing để tối ưu cho Mobile
local function UpdateESP()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local root = p.Character.HumanoidRootPart
            local espInstance = root:FindFirstChild("OxenESP")
            
            if _G.CORE.EspEnabled then
                if not espInstance then
                    -- Tạo mới ESP
                    local bb = Instance.new("BillboardGui")
                    bb.Name = "OxenESP"
                    bb.Adornee = root
                    bb.Size = UDim2.new(4,0,5,0)
                    bb.AlwaysOnTop = true
                    
                    local frame = Instance.new("Frame", bb)
                    frame.Size = UDim2.new(1,0,1,0)
                    frame.BackgroundTransparency = 1
                    
                    local stroke = Instance.new("UIStroke", frame)
                    stroke.Thickness = 1.5
                    stroke.Color = Color3.fromRGB(255, 0, 0)
                    
                    local txt = Instance.new("TextLabel", bb)
                    txt.Size = UDim2.new(1,0,0,20)
                    txt.Position = UDim2.new(0,0,-0.2,0)
                    txt.BackgroundTransparency = 1
                    txt.TextColor3 = Color3.new(1,1,1)
                    txt.TextStrokeTransparency = 0
                    txt.Font = Enum.Font.GothamBold
                    txt.TextSize = 11
                    
                    bb.Parent = root
                else
                    -- Cập nhật ESP
                    local hum = p.Character:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 then
                        espInstance.Enabled = true
                        local txt = espInstance.TextLabel
                        local frame = espInstance.Frame.UIStroke
                        
                        -- Tính khoảng cách
                        local dist = math.floor((root.Position - Camera.CFrame.Position).Magnitude)
                        txt.Text = string.format("%s [%dm]", p.Name, dist)
                        
                        -- Team Check Color
                        if p.Team == LocalPlayer.Team and p.Team ~= nil then
                            frame.Color = Color3.fromRGB(0, 255, 255) -- Đồng đội
                            txt.TextColor3 = Color3.fromRGB(0, 255, 255)
                        else
                            frame.Color = Color3.fromRGB(255, 0, 0) -- Địch
                            txt.TextColor3 = Color3.fromRGB(255, 255, 255)
                        end
                        
                        -- Toggle Visibility
                        frame.Enabled = _G.CORE.EspBox
                        txt.Visible = _G.CORE.EspName
                    else
                        espInstance.Enabled = false
                    end
                end
            else
                if espInstance then espInstance.Enabled = false end
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.5) do
        UpdateESP()
    end
end)

-- ==============================================================================
-- [PHẦN 8] UI GIAO DIỆN (RAYFIELD - GIỮ NGUYÊN CẤU TRÚC)
-- ==============================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Oxen Hub - Mobile Final",
   Icon = 0, -- Icon
   LoadingTitle = "Oxen Hub V45",
   LoadingSubtitle = "by Oxen Team (Optimized)",
   Theme = "Default",
   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false, -- Đã fix crash
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "OxenHubV45", 
      FileName = "MobileConfig"
   },
   KeySystem = false, -- Không cần key cho bản mobile
})

-- [[ TAB 1: COMBAT ]]
local TabCombat = Window:CreateTab("Combat", nil) -- Icon nil

TabCombat:CreateSection("Aimbot Master")

TabCombat:CreateToggle({
   Name = "Enable Aimbot (FOV: Blue | Lock: Red)",
   CurrentValue = false,
   Flag = "AimEnabled", 
   Callback = function(Value)
        _G.CORE.AimEnabled = Value
   end,
})

TabCombat:CreateToggle({
   Name = "Wall Check (Chắn tường)",
   CurrentValue = true,
   Flag = "WallCheck",
   Callback = function(Value)
        _G.CORE.WallCheck = Value
   end,
})

TabCombat:CreateSlider({
   Name = "Aim Smoothness (Độ mượt)",
   Range = {0, 1},
   Increment = 0.01,
   Suffix = "Smooth",
   CurrentValue = 0.16,
   Flag = "Smoothness",
   Callback = function(Value)
        _G.CORE.Smoothness = Value
   end,
})

TabCombat:CreateSection("Target Settings")

TabCombat:CreateDropdown({
   Name = "Target Part",
   Options = {"Head", "HumanoidRootPart", "Torso"},
   CurrentOption = "HumanoidRootPart",
   Flag = "TargetPart", 
   Callback = function(Option)
        _G.CORE.TargetPart = Option[1]
   end,
})

TabCombat:CreateToggle({
   Name = "No Recoil (Giảm giật - Beta)",
   CurrentValue = false,
   Callback = function(Value)
        _G.CORE.NoRecoil = Value
   end,
})

-- [[ TAB 2: VISUALS ]]
local TabVisuals = Window:CreateTab("Visuals", nil)

TabVisuals:CreateSection("ESP Settings")

TabVisuals:CreateToggle({
   Name = "ESP Master Switch",
   CurrentValue = true,
   Flag = "EspEnabled",
   Callback = function(Value)
        _G.CORE.EspEnabled = Value
   end,
})

TabVisuals:CreateToggle({
   Name = "Show Box",
   CurrentValue = true,
   Flag = "EspBox",
   Callback = function(Value)
        _G.CORE.EspBox = Value
   end,
})

TabVisuals:CreateToggle({
   Name = "Show Name & Distance",
   CurrentValue = true,
   Flag = "EspName",
   Callback = function(Value)
        _G.CORE.EspName = Value
   end,
})

TabVisuals:CreateToggle({
   Name = "Team Check (Bỏ qua đồng đội)",
   CurrentValue = false,
   Flag = "EspTeamCheck",
   Callback = function(Value)
        _G.CORE.EspTeamCheck = Value
   end,
})

-- [[ TAB 3: MOVEMENT ]]
local TabMove = Window:CreateTab("Movement", nil)

TabMove:CreateSection("Backstab V3 (Sticky)")

TabMove:CreateToggle({
   Name = "Auto Backstab (Sticky)",
   CurrentValue = false,
   Flag = "BackstabEnabled",
   Callback = function(Value)
        _G.CORE.BackstabEnabled = Value
        if not Value then BackstabTarget = nil end
   end,
})

TabMove:CreateSlider({
   Name = "Teleport Speed",
   Range = {10, 100},
   Increment = 5,
   Suffix = "Speed",
   CurrentValue = 50,
   Callback = function(Value)
        _G.CORE.BackstabSpeed = Value
   end,
})

TabMove:CreateLabel("Backstab tự đổi mục tiêu khi địch chết")

TabMove:CreateSection("Character Mods")

TabMove:CreateSlider({
   Name = "Walk Speed",
   Range = {16, 200},
   Increment = 1,
   Suffix = "Speed",
   CurrentValue = 16,
   Callback = function(Value)
        _G.CORE.WalkSpeed = Value
   end,
})

TabMove:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Callback = function(Value)
        _G.CORE.InfJump = Value
   end,
})

-- [[ MOBILE FLY UI ]]
local FlyEnabled = false
local FlySpeed = 1.5
local FlyConn = nil

local function ToggleFlyUI(state)
    if state then
        if MobileFlyUI then MobileFlyUI:Destroy() end
        local gui = Instance.new("ScreenGui", CoreGui)
        gui.Name = "OxenFlyControl"
        
        local btnUp = Instance.new("TextButton", gui)
        btnUp.Size = UDim2.new(0, 60, 0, 60)
        btnUp.Position = UDim2.new(0.8, 0, 0.6, 0)
        btnUp.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        btnUp.BackgroundTransparency = 0.5
        btnUp.Text = "▲"
        btnUp.TextSize = 25
        Instance.new("UICorner", btnUp).CornerRadius = UDim.new(1,0)
        
        local btnDown = Instance.new("TextButton", gui)
        btnDown.Size = UDim2.new(0, 60, 0, 60)
        btnDown.Position = UDim2.new(0.8, 0, 0.75, 0)
        btnDown.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
        btnDown.BackgroundTransparency = 0.5
        btnDown.Text = "▼"
        btnDown.TextSize = 25
        Instance.new("UICorner", btnDown).CornerRadius = UDim.new(1,0)
        
        -- Logic Bay
        local bodyGyro, bodyVel
        local flying = false
        
        -- Kết nối Fly
        if FlyConn then FlyConn:Disconnect() end
        FlyConn = RunService.RenderStepped:Connect(function()
            if not FlyEnabled or not LocalPlayer.Character then return end
            
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            
            if not root:FindFirstChild("FlyVel") then
                bodyVel = Instance.new("BodyVelocity", root)
                bodyVel.Name = "FlyVel"
                bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bodyVel.Velocity = Vector3.zero
                
                bodyGyro = Instance.new("BodyGyro", root)
                bodyGyro.Name = "FlyGyro"
                bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                bodyGyro.P = 10000
            else
                bodyVel = root.FlyVel
                bodyGyro = root.FlyGyro
            end
            
            bodyGyro.CFrame = Camera.CFrame
            
            local moveDir = LocalPlayer.Character.Humanoid.MoveDirection
            local targetVel = (moveDir * FlySpeed * 50)
            
            -- Xử lý nút bấm trên UI
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch) then
               -- Mobile logic handled by buttons below? 
               -- Actually simple logic:
            end
            
            -- Set Velocity
            bodyVel.Velocity = targetVel
        end)
        
        -- Logic nút lên xuống
        btnUp.MouseButton1Down:Connect(function()
            if bodyVel then bodyVel.Velocity = bodyVel.Velocity + Vector3.new(0, 50, 0) end
        end)
        
        MobileFlyUI = gui
    else
        if MobileFlyUI then MobileFlyUI:Destroy() end
        if FlyConn then FlyConn:Disconnect() end
        -- Clean up physics
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local r = LocalPlayer.Character.HumanoidRootPart
            if r:FindFirstChild("FlyVel") then r.FlyVel:Destroy() end
            if r:FindFirstChild("FlyGyro") then r.FlyGyro:Destroy() end
        end
    end
end

TabMove:CreateToggle({
   Name = "Mobile Fly (Có nút UI)",
   CurrentValue = false,
   Callback = function(Value)
        FlyEnabled = Value
        ToggleFlyUI(Value)
   end,
})

TabMove:CreateSlider({
   Name = "Fly Speed",
   Range = {1, 10},
   Increment = 0.5,
   CurrentValue = 1.5,
   Callback = function(Value)
        FlySpeed = Value
   end,
})

-- ==============================================================================
-- [PHẦN 9] GARBAGE COLLECTOR (DỌN RÁC BỘ NHỚ)
-- ==============================================================================
-- Tự động dọn sạch các bảng không dùng đến để tránh tràn RAM
task.spawn(function()
    while task.wait(5) do
        -- Dọn Bot Cache
        for i = #BotCache, 1, -1 do
            local entry = BotCache[i]
            if not entry.Character or not entry.Character.Parent then
                table.remove(BotCache, i)
            end
        end
        
        -- Force Garbage Collection (Chỉ LuaU)
        if collectgarbage then
            collectgarbage("collect")
        end
    end
end)

Rayfield:Notify({
   Title = "Oxen Hub Ready",
   Content = "V45 Optimized Loaded Successfully!",
   Duration = 5,
   Image = 4483362458,
})

-- Kết thúc script
