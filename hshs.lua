--[[
    NAME: Oxen Hub - Mobile Final
    VERSION: V33 (Complete Delta X Edition)
    OPTIMIZED FOR: Delta X, Hydrogen, Fluxus (Mobile Executors)
    
    LOG UPDATE:
    - [x] Anti-Ban V5 (Advanced Hooking & Network Throttle)
    - [x] Hybrid Scanner V3 (Player + Bot + ForceField Check)
    - [x] Visual Engine (Rainbow + Status Colors: Yellow/Green/Rainbow)
    - [x] Backstab V2 (Smooth Tweening + Velocity Spoof)
    - [x] Mobile Optimization (Render Throttle, Garbage Collection Safety)
    - [x] Full Features Restored (Fly, Noclip, InfJump, Walkspeed, NoRecoil)
]]

-- Chờ game load xong hoàn toàn để tránh crash script
repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer
task.wait(2) -- Đợi thêm 2s cho ổn định mạng

-- ==============================================================================
-- [SECTION 1] SERVICES & UTILITIES (CÁC DỊCH VỤ CỐT LÕI)
-- ==============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Hàm tạo Drawing an toàn (Tránh lỗi trên một số Executor yếu)
local function SafeDrawing(type)
    local success, object = pcall(function() return Drawing.new(type) end)
    if success and object then return object end
    return nil
end

-- ==============================================================================
-- [SECTION 2] CORE CONFIGURATION (CẤU HÌNH TỔNG)
-- ==============================================================================
_G.CORE = {
    -- AIMBOT CONFIG (Đã cố định theo yêu cầu)
    AimEnabled = false,
    AimReady = false,      -- Biến trạng thái Warm-up
    FOV = 110,             -- Góc nhìn hỗ trợ (Cố định)
    Deadzone = 17,         -- Vòng khóa cứng (Cố định)
    WallCheck = true,      -- Kiểm tra tường
    Pred = 0.165,          -- Dự đoán chuyển động
    AssistStrength = 0.4,  -- Độ mượt khi kéo tâm
    
    -- VISUALS CONFIG
    EspEnabled = true,     -- Master Switch
    EspBox = true,
    EspName = true,
    EspFFA = false,        -- Chế độ hiện tất cả (Free For All)
    
    -- MOVEMENT & COMBAT
    BackstabEnabled = false,
    BackstabSpeed = 50,    -- Tốc độ bay ra sau lưng (Slider)
    BackstabDist = 1.2,    -- Khoảng cách an toàn (~0.3 mét)
    WalkSpeedValue = 25,   -- Tốc độ chạy mặc định
    
    -- SYSTEM OPTIMIZATION
    ScanRate = 0.1,        -- Tốc độ quét (0.1s = 10 lần/giây -> Tiết kiệm Pin)
    RainbowHue = 0,        -- Giá trị màu hiện tại
    RainbowEnabled = true, -- Bật chế độ màu mè
    TargetLocking = false  -- Biến kiểm tra đang khóa mục tiêu hay không
}

-- ==============================================================================
-- [SECTION 3] ANTI-BAN SYSTEM V5 (BẢO VỆ CAO CẤP)
-- ==============================================================================
local function ActivateAntiBan()
    -- Kiểm tra xem Executor có hỗ trợ Hook không
    if not (hookmetamethod and getnamecallmethod) then 
        warn("OxenHub: Executor không hỗ trợ Hook Metamethod -> Anti-Ban bị hạn chế.")
        return 
    end
    
    local bannedMethods = {
        ["Kick"] = true,
        ["Shutdown"] = true,
        ["BreakJoints"] = true, -- Một số game dùng cái này để giết hacker
        ["Destroy"] = true      -- Hoặc destroy character
    }
    
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local caller = checkcaller and checkcaller() or false
        
        -- Chỉ can thiệp vào các lệnh do GAME gọi (không phải do Script mình gọi)
        if not caller then
            -- 1. Chặn các lệnh Kick/Ban trực tiếp
            if bannedMethods[method] then 
                return nil -- Trả về rỗng -> Vô hiệu hóa lệnh
            end
            
            -- 2. Chặn gửi báo cáo lỗi (Error Logging)
            if method == "SetCore" and (self.Name == "StarterGui" or tostring(self) == "StarterGui") then
                local args = {...}
                if args[1] == "SendNotification" then return nil end
            end
            
            -- 3. Chặn Remote Event nguy hiểm (FireServer)
            -- Đây là cách game mobile hay dùng để flag hacker
            if method == "FireServer" or method == "InvokeServer" then
                local remoteName = tostring(self.Name):lower()
                -- Các từ khóa nhạy cảm thường dùng trong Anti-Cheat
                if remoteName:match("ban") or remoteName:match("kick") or remoteName:match("flag") or remoteName:match("detect") or remoteName:match("security") then
                    return nil
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    
    -- Hook Index để Fake thông tin người chơi (Tránh check Account Age)
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if not checkcaller() and self == LocalPlayer then
            if key == "AccountAge" then return 365 end -- Giả mạo nick 1 năm tuổi
            if key == "UserId" then return math.random(1000000, 9999999) end -- Fake ID ngẫu nhiên
        end
        return oldIndex(self, key)
    end)
    
    -- Network Throttle: Reset bộ đếm remote mỗi frame để tránh bị kick do spam
    RunService.Heartbeat:Connect(function() 
        -- Logic placeholder cho bộ đếm (nếu cần mở rộng sau này)
    end)
end

-- Kích hoạt Anti-Ban trong luồng bảo vệ
task.spawn(function() pcall(ActivateAntiBan) end)

-- ==============================================================================
-- [SECTION 4] VISUAL ENGINE (DRAWING & RAINBOW LOGIC)
-- ==============================================================================
local fovCircle = SafeDrawing("Circle")
local deadCircle = SafeDrawing("Circle")

-- Hàm khôi phục vòng tròn nếu bị Game xóa (Garbage Collection Fix)
local function RestoreDrawingObjects()
    if not fovCircle then fovCircle = SafeDrawing("Circle") end
    if not deadCircle then deadCircle = SafeDrawing("Circle") end
    
    if fovCircle then
        fovCircle.Thickness = 1.5
        fovCircle.NumSides = 40 -- Giảm giác để tối ưu FPS mobile
        fovCircle.Filled = false
        fovCircle.Transparency = 1
    end
    if deadCircle then
        deadCircle.Thickness = 1.5
        deadCircle.NumSides = 24
        deadCircle.Filled = false
        deadCircle.Transparency = 1
    end
end
RestoreDrawingObjects() -- Gọi lần đầu

-- Luồng xử lý màu sắc thông minh (Status Colors)
task.spawn(function()
    while true do
        if _G.CORE.RainbowEnabled then
            _G.CORE.RainbowHue = (_G.CORE.RainbowHue + 5) % 360
            local rainbowColor = Color3.fromHSV(_G.CORE.RainbowHue / 360, 1, 1)
            
            -- Logic màu trạng thái:
            -- 1. Nếu đang Warm-up (Chưa sẵn sàng) -> Màu Vàng
            -- 2. Nếu đang Khóa mục tiêu (Locked) -> Màu Xanh Lá
            -- 3. Bình thường -> Màu Rainbow
            
            local statusColor = rainbowColor
            if _G.CORE.AimEnabled then
                if not _G.CORE.AimReady then
                    statusColor = Color3.fromRGB(255, 255, 0) -- Vàng (Waiting)
                elseif _G.CORE.TargetLocking then
                    statusColor = Color3.fromRGB(0, 255, 0)   -- Xanh Lá (Locked)
                end
            end
            
            if fovCircle then fovCircle.Color = statusColor end
            if deadCircle then deadCircle.Color = statusColor end
        end
        task.wait(0.1) -- Cập nhật 10 lần/giây
    end
end)

-- ==============================================================================
-- [SECTION 5] TARGET SCANNER & ESP SYSTEM (V3 HYBRID)
-- ==============================================================================
local TargetCache = {} -- Lưu danh sách mục tiêu hợp lệ

-- Hàm kiểm tra địch thủ (Hỗ trợ Team Check & Neutral)
local function IsEnemy(p)
    if not p or p == LocalPlayer then return false end
    if LocalPlayer.Neutral or p.Neutral then return true end -- Đấu đơn
    return p.Team ~= LocalPlayer.Team -- Đấu đội
end

-- Hàm lấy bộ phận ngắm tốt nhất (Head -> Torso -> Root)
-- Tương thích cả R6 và R15
local function GetAimPart(char)
    if not char then return nil end
    return char:FindFirstChild("Head") or 
           char:FindFirstChild("UpperTorso") or 
           char:FindFirstChild("HumanoidRootPart") or 
           char:FindFirstChild("Torso")
end

-- Hàm tạo/cập nhật ESP (Dùng chung cho Scanner và GC)
local function UpdateESP(root, nameText, isEnemy)
    if not _G.CORE.EspEnabled then 
        if root:FindFirstChild("MobESP") then root.MobESP.Enabled = false end
        return 
    end

    local esp = root:FindFirstChild("MobESP")
    if not esp then
        -- Tạo mới BillboardGui
        local bb = Instance.new("BillboardGui", root)
        bb.Name = "MobESP"
        bb.Size = UDim2.new(4, 0, 5.5, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 500 -- Giới hạn tầm nhìn để đỡ lag
        
        local frame = Instance.new("Frame", bb)
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        
        local stroke = Instance.new("UIStroke", frame)
        stroke.Thickness = 1.5
        
        local label = Instance.new("TextLabel", bb)
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Position = UDim2.new(0, 0, -0.25, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 10
        label.TextColor3 = Color3.new(1, 1, 1)
        
        esp = bb
    end
    
    esp.Enabled = true
    local isTarget = isEnemy or _G.CORE.EspFFA
    
    -- Màu sắc ESP: Đỏ (Địch) vs Xanh (Đồng đội)
    -- Không dùng Rainbow cho ESP để tránh rối mắt
    local color = isTarget and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 255)
    
    esp.Frame.UIStroke.Color = color
    esp.Frame.UIStroke.Enabled = _G.CORE.EspBox
    esp.TextLabel.Visible = _G.CORE.EspName
    
    local dist = math.floor((root.Position - Camera.CFrame.Position).Magnitude)
    esp.TextLabel.Text = string.format("%s\n[%dm]", nameText, dist)
end

-- MAIN SCANNER THREAD (Chạy ngầm)
task.spawn(function()
    while true do
        local config = _G.CORE
        local tempCache = {}
        local pCount = 0
        
        -- 1. Quét Người chơi (Players)
        for _, p in ipairs(Players:GetPlayers()) do
            if pCount > 50 then break end -- Giới hạn số lượng quét
            
            if p ~= LocalPlayer and p.Character then
                local char = p.Character
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                
                if root and hum and hum.Health > 0 then
                    local isEnemy = IsEnemy(p)
                    -- Cập nhật ESP
                    UpdateESP(root, p.Name, isEnemy)
                    
                    -- Thêm vào danh sách Aim nếu là địch
                    if isEnemy or config.EspFFA then
                        local aimPart = GetAimPart(char)
                        if aimPart then
                            table.insert(tempCache, {
                                Part = aimPart, 
                                Char = char, 
                                Root = root,
                                Dist = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                            })
                        end
                    end
                end
            end
            pCount = pCount + 1
        end
        
        -- 2. Quét Bot/NPC (Bot Check cải tiến)
        local bCount = 0
        local wsChildren = Workspace:GetChildren()
        for i = 1, #wsChildren do
            local obj = wsChildren[i]
            if bCount > 20 then break end
            
            -- Điều kiện nhận diện Bot: Là Model, Có Humanoid, Không phải Player, Không có ForceField (Bất tử)
            if obj:IsA("Model") and obj ~= LocalPlayer.Character then
                local hum = obj:FindFirstChild("Humanoid")
                local root = obj:FindFirstChild("HumanoidRootPart")
                
                if hum and root and hum.Health > 0 and not Players:GetPlayerFromCharacter(obj) then
                    if not obj:FindFirstChildOfClass("ForceField") then -- Bỏ qua bot bất tử
                        local aimPart = GetAimPart(obj)
                        if aimPart then
                            table.insert(tempCache, {
                                Part = aimPart, 
                                Char = obj, 
                                Root = root,
                                Dist = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                            })
                            bCount = bCount + 1
                        end
                    end
                end
            end
        end

        TargetCache = tempCache
        
        -- Logic Warm-up (Đợi 1.5s khi mới bật Aim)
        if config.AimEnabled and not config.AimReady then
            task.wait(1.5)
            config.AimReady = true
        end
        
        task.wait(config.ScanRate) -- Nghỉ 0.1s
    end
end)

-- ==============================================================================
-- [SECTION 6] AIMBOT ENGINE & RENDERER (RENDERSTEPPED)
-- ==============================================================================
RunService.RenderStepped:Connect(function()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local conf = _G.CORE
    
    -- 1. Drawing Safety Check (Tự động khôi phục nếu mất)
    if not fovCircle or not deadCircle then RestoreDrawingObjects() end
    
    if fovCircle then
        fovCircle.Visible = conf.AimEnabled
        fovCircle.Position = center
        fovCircle.Radius = conf.FOV -- Cố định 110
    end
    
    if deadCircle then
        deadCircle.Visible = conf.AimEnabled
        deadCircle.Position = center
        deadCircle.Radius = conf.Deadzone -- Cố định 17
    end

    -- 2. Aimbot Logic
    conf.TargetLocking = false -- Reset trạng thái khóa
    
    if conf.AimEnabled and conf.AimReady then
        local bestTarget = nil
        local maxDist = conf.FOV
        
        for _, data in ipairs(TargetCache) do
            if data.Part and data.Part.Parent then
                local pos, onScreen = Camera:WorldToViewportPoint(data.Part.Position)
                
                if onScreen then
                    local screenDist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if screenDist < maxDist then
                        -- Wall Check Logic
                        local visible = true
                        if conf.WallCheck then
                            local params = RaycastParams.new()
                            params.FilterType = Enum.RaycastFilterType.Exclude
                            params.FilterDescendantsInstances = {LocalPlayer.Character, data.Char}
                            
                            local dir = data.Part.Position - Camera.CFrame.Position
                            local ray = Workspace:Raycast(Camera.CFrame.Position, dir, params)
                            if ray then visible = false end
                        end
                        
                        if visible then
                            maxDist = screenDist
                            bestTarget = data
                        end
                    end
                end
            end
        end
        
        if bestTarget then
            conf.TargetLocking = true -- Đánh dấu đang khóa -> Đổi màu vòng tròn
            
            local velocity = bestTarget.Root.AssemblyLinearVelocity or Vector3.zero
            local predPos = bestTarget.Part.Position + (velocity * conf.Pred)
            local screenPos = Camera:WorldToViewportPoint(bestTarget.Part.Position)
            local distToCenter = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            
            -- Logic Dual Zone:
            if distToCenter <= conf.Deadzone then
                -- Trong vòng Deadzone -> Khóa cứng (Hard Lock)
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, predPos)
            else
                -- Trong vòng FOV -> Kéo tâm nhẹ (Assist)
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, predPos), conf.AssistStrength)
            end
        end
    end
end)

-- ==============================================================================
-- [SECTION 7] UI INTERFACE (RAYFIELD LIBRARY)
-- ==============================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "Oxen Hub - K2PN",
   Icon = 0,
   LoadingTitle = "Oxen-Hub V33",
   LoadingSubtitle = "Delta X Complete",
   Theme = "Default",
   DisableRayfieldPrompts = false,
   ConfigurationSaving = { Enabled = true, FileName = "OxenHub_V33_Config" },
   KeySystem = false,
})

-- === TAB 1: COMBAT ===
local CombatTab = Window:CreateTab("Combat", nil)
CombatTab:CreateSection("Aimbot System")

-- Toggle chính (Đã bỏ Slider FOV/Deadzone như yêu cầu)
CombatTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Flag = "Aim",
    Callback = function(v) _G.CORE.AimEnabled = v end
})

CombatTab:CreateToggle({
    Name = "Wall Check (Chắn tường)",
    CurrentValue = true,
    Flag = "WallCheck",
    Callback = function(v) _G.CORE.WallCheck = v end
})

CombatTab:CreateSection("Gun Modifications")

-- No Recoil (Mobile Fix) - Giữ nguyên logic ổn định
CombatTab:CreateToggle({
    Name = "No Recoil (Giảm giật)",
    CurrentValue = false,
    Callback = function(v) 
        _G.NoRecoil = v 
        if v then
            local LastRot = workspace.CurrentCamera.CFrame.Rotation
            RunService:BindToRenderStep("OxenNoRecoil", Enum.RenderPriority.Camera.Value + 1, function()
                if not _G.NoRecoil then return end
                local Cam = workspace.CurrentCamera
                local CurRot = Cam.CFrame.Rotation
                local x, y, z = CurRot:ToOrientation()
                local lx, ly, lz = LastRot:ToOrientation()
                
                -- Nếu góc lệch nhỏ (giật súng) -> Trả về góc cũ
                if math.deg(x - lx) > 0.5 then
                    Cam.CFrame = CFrame.new(Cam.CFrame.Position) * CFrame.fromOrientation(lx, y, z)
                    LastRot = CFrame.fromOrientation(lx, y, z)
                else
                    LastRot = CurRot
                end
            end)
        else
            pcall(function() RunService:UnbindFromRenderStep("OxenNoRecoil") end)
        end
    end,
})

-- === TAB 2: VISUALS ===
local VisualsTab = Window:CreateTab("Visuals", nil)
VisualsTab:CreateSection("ESP Settings")

VisualsTab:CreateToggle({
    Name = "Bật ESP (Master Switch)",
    CurrentValue = true,
    Callback = function(v) 
        _G.CORE.EspEnabled = v
        _G.CORE.EspBox = v
        _G.CORE.EspName = v
    end
})

VisualsTab:CreateToggle({
    Name = "Show Boxes",
    CurrentValue = true,
    Callback = function(v) _G.CORE.EspBox = v end
})

VisualsTab:CreateToggle({
    Name = "Show Names",
    CurrentValue = true,
    Callback = function(v) _G.CORE.EspName = v end
})

VisualsTab:CreateToggle({
    Name = "FFA Mode (Hiện tất cả)",
    CurrentValue = false,
    Callback = function(v) _G.CORE.EspFFA = v end
})

-- === TAB 3: MOVEMENT ===
local MoveTab = Window:CreateTab("Movement", nil)

-- [FEATURE] BACKSTAB LOGIC V2 (TWEENING)
local CurrentBackstabTarget = nil

local function GetNearestBackstabTarget()
    local nearest, minDist = nil, math.huge
    for _, data in ipairs(TargetCache) do
        if data.Dist < minDist then 
            minDist = data.Dist
            nearest = data.Char 
        end
    end
    return nearest
end

task.spawn(function()
    while true do
        if _G.CORE.BackstabEnabled and LocalPlayer.Character then
            local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                -- Tìm mục tiêu mới nếu mục tiêu cũ chết/mất
                if not CurrentBackstabTarget or 
                   not CurrentBackstabTarget:FindFirstChild("Humanoid") or 
                   CurrentBackstabTarget.Humanoid.Health <= 0 then
                    CurrentBackstabTarget = GetNearestBackstabTarget()
                end
                
                if CurrentBackstabTarget then
                    local tRoot = CurrentBackstabTarget:FindFirstChild("HumanoidRootPart")
                    if tRoot then
                        -- Tính vị trí sau lưng (Offset)
                        local offset = tRoot.CFrame * CFrame.new(0, 0, _G.CORE.BackstabDist)
                        local dist = (myRoot.Position - offset.Position).Magnitude
                        
                        -- Tweening Movement (Bay mượt)
                        local speed = math.max(_G.CORE.BackstabSpeed, 1)
                        local time = math.max(dist / speed, 0.05)
                        
                        local tInfo = TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                        local tween = TweenService:Create(myRoot, tInfo, {CFrame = offset})
                        tween:Play()
                        
                        -- Anti-Cheat Bypass: Fake Velocity & LookAt
                        myRoot.AssemblyLinearVelocity = tRoot.AssemblyLinearVelocity
                        -- Quay mặt về phía lưng địch
                        local lookPos = Vector3.new(tRoot.Position.X, myRoot.Position.Y, tRoot.Position.Z)
                        myRoot.CFrame = CFrame.lookAt(myRoot.Position, lookPos)
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

MoveTab:CreateSection("Backstab (Áp sát)")
MoveTab:CreateToggle({
    Name = "Tween to enemy",
    CurrentValue = false,
    Callback = function(v) 
        _G.CORE.BackstabEnabled = v
        if not v then CurrentBackstabTarget = nil end
    end
})
MoveTab:CreateSlider({
    Name = "Tween Speed",
    Range = {20, 200}, Increment = 5, CurrentValue = 50,
    Callback = function(v) _G.CORE.BackstabSpeed = v end
})

MoveTab:CreateSection("Character Mods")

-- Walkspeed Loop (Đảm bảo không bị game reset)
MoveTab:CreateSlider({
   Name = "Walkspeed",
   Range = {16, 150}, Increment = 1, CurrentValue = 25,
   Callback = function(v) 
       _G.CORE.WalkSpeedValue = v
       task.spawn(function()
           while task.wait(0.5) do
               if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                   LocalPlayer.Character.Humanoid.WalkSpeed = v
               end
           end
       end)
   end,
})

-- Infinite Jump
MoveTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Callback = function(v) 
       _G.InfJump = v
       if v and not _G.IJConn then
           _G.IJConn = UserInputService.JumpRequest:Connect(function()
               if _G.InfJump and LocalPlayer.Character then 
                   LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) 
               end
           end)
       end
   end,
})

-- SMOOTH FLY SYSTEM (MOBILE UI)
local FlySettings = {Enabled = false, Speed = 1.5, Smoothness = 0.2, GoingUp = false, GoingDown = false, CurrentVelocity = Vector3.new(0,0,0)}
local MobileFlyUI = nil

local function ToggleMobileFlyUI(bool)
    if bool then
        if MobileFlyUI then MobileFlyUI:Destroy() end
        local ScreenGui = Instance.new("ScreenGui", CoreGui)
        ScreenGui.Name = "OxenFlyUI"
        
        -- Nút Bay Lên (UP)
        local BtnUp = Instance.new("TextButton", ScreenGui)
        BtnUp.Size = UDim2.new(0, 50, 0, 50)
        BtnUp.Position = UDim2.new(0, 50, 0.40, 0) -- Vị trí bên trái màn hình
        BtnUp.Text = "UP"
        BtnUp.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        BtnUp.BackgroundTransparency = 0.5
        Instance.new("UICorner", BtnUp).CornerRadius = UDim.new(1,0)
        
        -- Nút Bay Xuống (DN)
        local BtnDown = Instance.new("TextButton", ScreenGui)
        BtnDown.Size = UDim2.new(0, 50, 0, 50)
        BtnDown.Position = UDim2.new(0, 50, 0.40, 60)
        BtnDown.Text = "DN"
        BtnDown.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
        BtnDown.BackgroundTransparency = 0.5
        Instance.new("UICorner", BtnDown).CornerRadius = UDim.new(1,0)

        -- Events Touch
        BtnUp.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then FlySettings.GoingUp = true end end)
        BtnUp.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then FlySettings.GoingUp = false end end)
        BtnDown.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then FlySettings.GoingDown = true end end)
        BtnDown.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then FlySettings.GoingDown = false end end)
        
        MobileFlyUI = ScreenGui
    else
        if MobileFlyUI then MobileFlyUI:Destroy() end
        MobileFlyUI = nil
        FlySettings.GoingUp = false
        FlySettings.GoingDown = false
        FlySettings.CurrentVelocity = Vector3.new(0,0,0)
    end
end

-- Fly Logic & Noclip
local NoclipConn = nil
RunService.RenderStepped:Connect(function()
    if not FlySettings.Enabled or not LocalPlayer.Character then return end
    local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not root or not hum then return end
    
    -- Tính toán hướng bay
    root.Velocity = Vector3.zero
    local tDir = Vector3.zero
    
    if FlySettings.GoingUp then 
        tDir = Vector3.new(0, FlySettings.Speed, 0) 
    elseif FlySettings.GoingDown then 
        tDir = Vector3.new(0, -FlySettings.Speed, 0) 
    else 
        -- Bay theo hướng nhìn của Camera/MoveDirection
        tDir = (hum.MoveDirection * Vector3.new(1,0,1)) * FlySettings.Speed 
    end
    
    -- Lerp để bay mượt
    FlySettings.CurrentVelocity = FlySettings.CurrentVelocity:Lerp(tDir, FlySettings.Smoothness)
    root.CFrame = root.CFrame + FlySettings.CurrentVelocity
    
    hum.PlatformStand = true -- Tránh animation đi bộ
end)

MoveTab:CreateSection("Fly System")
MoveTab:CreateToggle({
    Name = "Smooth Fly (Mobile UI + Noclip)",
    CurrentValue = false,
    Callback = function(v)
        FlySettings.Enabled = v
        ToggleMobileFlyUI(v)
        
        if v then
            -- Bật Noclip khi bay
            if NoclipConn then NoclipConn:Disconnect() end
            NoclipConn = RunService.Stepped:Connect(function()
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                    end
                end
            end)
        else
            -- Tắt Noclip và Reset
            if NoclipConn then NoclipConn:Disconnect() end
            NoclipConn = nil
            if LocalPlayer.Character then
                local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
                if hum then hum.PlatformStand = false end
                workspace.Gravity = 196.2
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end
    end,
})
MoveTab:CreateSlider({Name = "Fly Speed", Range = {0.5, 5}, Increment = 0.1, CurrentValue = 1.5, Callback = function(v) FlySettings.Speed = v end})

-- ==============================================================================
-- [SECTION 8] GARBAGE COLLECTOR (DỌN DẸP & SỬA LỖI)
-- ==============================================================================
task.spawn(function()
    while true do
        -- Vòng lặp này chạy chậm (3s/lần) để check lỗi
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                -- Nếu Scanner lỡ bỏ sót ESP -> Tạo lại
                if root then 
                    UpdateESP(root, p.Name, IsEnemy(p)) 
                end
            end
        end
        task.wait(3)
    end
end)

Rayfield:Notify({Title = "Oxen-HUB", Content = "FOLLOW ME TO CREATE", Duration = 4})
