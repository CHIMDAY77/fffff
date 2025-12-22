--[[
    ░█████╗░██╗░░██╗███████╗███╗░░██╗  ██╗░░██╗██╗░░░██╗██████╗░
    ██╔══██╗╚██╗██╔╝██╔════╝████╗░██║  ██║░░██║██║░░░██║██╔══██╗
    ██║░░██║░╚███╔╝░█████╗░░██╔██╗██║  ███████║██║░░░██║██████╔╝
    ██║░░██║░██╔██╗░██╔══╝░░██║╚████║  ██╔══██║██║░░░██║██╔══██╗
    ╚█████╔╝██╔╝╚██╗███████╗██║░╚███║  ██║░░██║╚██████╔╝██████╔╝
    ░╚════╝░╚═╝░░╚═╝╚══════╝╚═╝░░╚══╝  ╚═╝░░╚═╝░╚═════╝░╚═════╝░

    [+] SCRIPT INFO:
        - Name: Oxen Hub - Mobile Final
        - Version: V46 (Combat Ready)
        - Logic: Trigger Lock (Chỉ khóa khi bắn) + Team Check Backstab.
        - Scanner: Legacy V41 (Loop Mode).
        - Executor: Delta X / Hydrogen / Fluxus.
    
    [+] CHANGE LOG V46:
        1. Aimbot: Chỉ khóa chặt (Hard Lock) khi giữ nút bắn/chạm màn hình.
        2. Backstab: Thêm Team Check (Không bay vào đồng đội).
        3. Visual: Giữ nguyên Global Drawing.
]]

-- [INIT] Wait for Game Load
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer
task.wait(2) -- Chờ tải tài nguyên mạng

-- ==============================================================================
-- [SECTION 1] SERVICES & VARIABLES
-- ==============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Cache Functions (Tăng tốc truy xuất)
local FindFirstChild = game.FindFirstChild
local FindFirstChildOfClass = game.FindFirstChildOfClass
local WaitForChild = game.WaitForChild
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPlayers = Players.GetPlayers
local V2 = Vector2.new
local V3 = Vector3.new
local CF = CFrame.new

-- ==============================================================================
-- [SECTION 2] CORE CONFIGURATION
-- ==============================================================================
_G.CORE = {
    -- Aimbot Config
    AimEnabled = false,
    AimReady = false,      -- Warm-up check
    FOV = 110,             -- Cố định 110 (Xanh Dương)
    Deadzone = 17,         -- Cố định 17 (Xanh Lá)
    WallCheck = true,
    Pred = 0.165,
    AssistStrength = 1,    -- 1 = Khóa cứng (Ghim chặt)
    
    -- Visuals Config
    EspEnabled = true,
    EspBox = true,
    EspName = true,
    EspFFA = false,
    
    -- Backstab Config
    BackstabEnabled = false,
    BackstabSpeed = 50,    -- Tốc độ Tween
    BackstabDist = 1.2,    -- Khoảng cách (1.2m sau lưng)
    BackstabTeamCheck = true, -- Mặc định bật check team
    
    -- Movement Config
    WalkSpeedValue = 25,
    InfiniteJump = false,
    
    -- System Config
    ScanRate = 0.05        -- Tốc độ quét tối ưu cho Loop Scanner
}

-- ==============================================================================
-- [SECTION 3] ANTI-BAN SYSTEM V5 (TITAN LEGACY)
-- ==============================================================================
local function EnableAntiBanV5()
    -- Kiểm tra hỗ trợ hook
    if not (hookmetamethod and getnamecallmethod) then return end
    
    local bannedMethods = {
        ["Kick"] = true,
        ["Shutdown"] = true,
        ["BreakJoints"] = true,
        ["Destroy"] = true
    }
    
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        
        -- Chỉ chặn khi game gọi (Executor gọi thì cho qua)
        if not checkcaller() then
            -- 1. Chặn Kick/Ban/Destroy
            if bannedMethods[method] then return nil end
            
            -- 2. Chặn Error Logs (SetCore)
            if method == "SetCore" and tostring(self) == "StarterGui" then
                local args = {...}
                if args[1] == "SendNotification" then return nil end
            end
            
            -- 3. Chặn Remote Flag (FireServer)
            if method == "FireServer" or method == "InvokeServer" then
                local rName = tostring(self.Name):lower()
                if rName:match("ban") or rName:match("kick") or rName:match("flag") or rName:match("detect") then
                    return nil
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    
    -- Hook Index (Fake Info)
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if not checkcaller() and self == LocalPlayer then
            if key == "AccountAge" then return 365 end -- Fake 1 năm
            if key == "UserId" then return math.random(1000000, 9999999) end
            if key == "OsPlatform" then return "Android" end
        end
        return oldIndex(self, key)
    end)
end
task.spawn(function() pcall(EnableAntiBanV5) end)

-- ==============================================================================
-- [SECTION 4] DRAWING LOGIC (GLOBAL FIX FOR DELTA X)
-- ==============================================================================
-- Code này được đặt ở Global Scope (Ngoài cùng) để Delta X nhận diện
-- KHÔNG ĐƯỢC BỌC TRONG FUNCTION HAY PCALL

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.NumSides = 40
fovCircle.Filled = false
fovCircle.Color = Color3.fromRGB(0, 170, 255) -- Xanh Dương (Blue)
fovCircle.Transparency = 1
fovCircle.Visible = false

local deadCircle = Drawing.new("Circle")
deadCircle.Thickness = 1.5
deadCircle.NumSides = 24
deadCircle.Filled = false
deadCircle.Color = Color3.fromRGB(0, 255, 0) -- Xanh Lá (Green)
deadCircle.Transparency = 1
deadCircle.Visible = false

-- ==============================================================================
-- [SECTION 5] SCANNER SYSTEM (V41 LEGACY LOOP - RESTORED)
-- ==============================================================================
local TargetCache = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- Helper: Check Enemy (Team Check Logic)
local function IsEnemy(p)
    if not p or p == LocalPlayer then return false end
    if LocalPlayer.Neutral or p.Neutral then return true end
    if not p.Team or not LocalPlayer.Team then return true end
    return p.Team ~= LocalPlayer.Team
end

-- Helper: Check Bot
local function IsGameBot(model)
    if not model or not model:IsA("Model") or model == LocalPlayer.Character then return false end
    local hum = FindFirstChild(model, "Humanoid")
    local root = FindFirstChild(model, "HumanoidRootPart")
    
    -- Check cơ bản
    if not hum or hum.Health <= 0 or not root then return false end
    -- Check xem có phải người chơi thật không
    if Players:GetPlayerFromCharacter(model) then return false end
    -- Check bất tử (ForceField) -> Bỏ qua
    if FindFirstChildOfClass(model, "ForceField") then return false end
    
    return true
end

-- Helper: Get Aim Part
local function GetAimPart(char)
    if not char then return nil end
    return FindFirstChild(char, "Head") or 
           FindFirstChild(char, "UpperTorso") or 
           FindFirstChild(char, "HumanoidRootPart") or 
           FindFirstChild(char, "Torso")
end

-- Helper: Create/Update ESP
local function CreateESP(char)
    local root = WaitForChild(char, "HumanoidRootPart", 5)
    if not root then return end
    
    -- Xóa cũ nếu có để tránh trùng
    if root:FindFirstChild("MobESP") then root.MobESP:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = "MobESP"
    bb.Adornee = root
    bb.Size = UDim2.new(4, 0, 5.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = root
    bb.MaxDistance = 500 -- Tối ưu FPS

    local frame = Instance.new("Frame", bb)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    
    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = 1.5

    local txt = Instance.new("TextLabel", bb)
    txt.Size = UDim2.new(1, 0, 0, 20)
    txt.Position = UDim2.new(0, 0, -0.25, 0)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.new(1, 1, 1)
    txt.TextStrokeTransparency = 0
    txt.TextSize = 10
    txt.Font = Enum.Font.GothamBold
    
    bb.Enabled = false 
end

-- Main Scanner Loop (V41 Logic - KEEPING AS REQUESTED)
task.spawn(function()
    while true do
        local tempCache = {}
        local config = _G.CORE
        local lpPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.zero
        
        -- 1. SCAN PLAYERS
        local plrs = GetPlayers(Players)
        for i = 1, #plrs do
            local p = plrs[i]
            if p ~= LocalPlayer and p.Character then
                local char = p.Character
                local root = FindFirstChild(char, "HumanoidRootPart")
                local hum = FindFirstChild(char, "Humanoid")
                
                if root and hum and hum.Health > 0 then
                    -- ESP Logic
                    local espBox = FindFirstChild(root, "MobESP")
                    if not espBox then
                        CreateESP(char)
                    else
                        if config.EspEnabled then
                            espBox.Enabled = true
                            local txt = FindFirstChild(espBox, "TextLabel")
                            local frame = FindFirstChild(espBox, "Frame")
                            local stroke = frame and FindFirstChild(frame, "UIStroke")
                            
                            if txt and stroke then
                                local dist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)
                                txt.Visible = config.EspName
                                txt.Text = string.format("%s\n[%dm]", p.Name, dist)
                                stroke.Enabled = config.EspBox
                                
                                local isE = IsEnemy(p)
                                local col = Color3.fromRGB(0, 255, 255) -- Cyan (Đồng đội)
                                if config.EspFFA or isE then
                                    col = Color3.fromRGB(255, 0, 0) -- Đỏ (Địch)
                                end
                                stroke.Color = col
                                txt.TextColor3 = (config.EspFFA or isE) and Color3.new(1,1,1) or col
                            end
                        else
                            espBox.Enabled = false
                        end
                    end
                    
                    -- Aim Cache Logic
                    -- Logic: Nếu là kẻ địch hoặc đang bật FFA thì mới đưa vào danh sách ngắm
                    if IsEnemy(p) or config.EspFFA then
                        local part = GetAimPart(char)
                        if part then
                            table.insert(tempCache, {
                                Part = part, 
                                Char = char, 
                                Root = root,
                                Humanoid = hum,
                                Player = p, -- Lưu player để check team sau này
                                Dist = (root.Position - lpPos).Magnitude
                            })
                        end
                    end
                end
            end
        end
        
        -- 2. SCAN BOTS
        local wsChildren = Workspace:GetChildren()
        for i = 1, #wsChildren do
            local obj = wsChildren[i]
            if IsGameBot(obj) then
                local root = FindFirstChild(obj, "HumanoidRootPart")
                local hum = FindFirstChild(obj, "Humanoid")
                
                if root and hum then
                    local part = GetAimPart(obj)
                    if part then
                        table.insert(tempCache, {
                            Part = part, 
                            Char = obj, 
                            Root = root, 
                            Humanoid = hum,
                            Player = nil, -- Bot không phải player
                            Dist = (root.Position - lpPos).Magnitude
                        })
                    end
                end
            end
        end

        TargetCache = tempCache
        
        -- Warmup Check (Logic cũ)
        if config.AimEnabled then
            if not config.AimReady then
                task.wait(1.5)
                config.AimReady = true
            end
        else
            config.AimReady = false
        end
        
        task.wait(config.ScanRate)
    end
end)

-- Auto Create ESP
Players.PlayerAdded:Connect(function(p) 
    p.CharacterAdded:Connect(function(c) 
        task.wait(1)
        CreateESP(c) 
    end) 
end)

-- ==============================================================================
-- [SECTION 6] AIM ENGINE (TRIGGER LOCK LOGIC)
-- ==============================================================================
-- Tính năng mới: Chỉ khóa khi bắn

local function GetBestTarget()
    local bestPart = nil
    local shortestDist = math.huge
    local center = V2(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for i = 1, #TargetCache do
        local entry = TargetCache[i]
        local part = entry.Part
        
        if part and part.Parent then 
            local pos, onScreen = WorldToViewportPoint(Camera, part.Position)
            if onScreen then
                local dist = (V2(pos.X, pos.Y) - center).Magnitude
                
                -- Check trong vòng FOV (110)
                if dist <= _G.CORE.FOV then
                    local visible = true
                    if _G.CORE.WallCheck then
                        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, entry.Char}
                        local dir = part.Position - Camera.CFrame.Position
                        local hit = Workspace:Raycast(Camera.CFrame.Position, dir, rayParams)
                        if hit then visible = false end
                    end
                    
                    if visible and dist < shortestDist then
                        shortestDist = dist
                        bestPart = entry
                    end
                end
            end
        end
    end
    return bestPart
end

-- RENDERSTEPPED LOOP (CẬP NHẬT MỖI KHUNG HÌNH)
RunService.RenderStepped:Connect(function()
    local center = V2(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local conf = _G.CORE
    
    -- [VISUALS] Luôn luôn vẽ vòng tròn khi bật Aim
    if conf.AimEnabled then
        fovCircle.Visible = true
        fovCircle.Position = center
        fovCircle.Radius = conf.FOV
        
        deadCircle.Visible = true
        deadCircle.Position = center
        deadCircle.Radius = conf.Deadzone
        
        -- Hiệu ứng màu trạng thái
        if not conf.AimReady then
            deadCircle.Color = Color3.fromRGB(255, 255, 0) -- Vàng (Chờ)
        else
            deadCircle.Color = Color3.fromRGB(0, 255, 0)   -- Xanh Lá (Ready)
        end
    else
        fovCircle.Visible = false
        deadCircle.Visible = false
        return
    end

    -- [TRIGGER AIM LOGIC]
    -- Kiểm tra xem người chơi có đang nhấn nút bắn không (Chuột trái hoặc Chạm màn hình)
    local isShooting = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch)

    if conf.AimReady and isShooting then
        local targetData = GetBestTarget()
        
        if targetData then
            -- Khi khóa trúng -> Deadzone chuyển màu Đỏ (Locked)
            deadCircle.Color = Color3.fromRGB(255, 0, 0) 
            
            local aimPart = targetData.Part
            local root = targetData.Root
            
            local velocity = root.AssemblyLinearVelocity or V3(0,0,0)
            local predPos = aimPart.Position + (velocity * conf.Pred)
            
            local screenPos = WorldToViewportPoint(Camera, aimPart.Position)
            local distToCenter = (V2(screenPos.X, screenPos.Y) - center).Magnitude
            
            -- ƯU TIÊN DEADZONE: Nếu mục tiêu nằm trong Deadzone, KHÓA CỨNG (Hard Lock)
            if distToCenter <= conf.Deadzone then
                Camera.CFrame = CF(Camera.CFrame.Position, predPos) -- Ghim chết, không trượt phát nào
            else
                -- Nếu nằm ngoài Deadzone nhưng trong FOV, vẫn hỗ trợ kéo tâm vào
                Camera.CFrame = Camera.CFrame:Lerp(CF(Camera.CFrame.Position, predPos), 0.5) 
            end
        end
    else
        -- Khi không bắn: KHÔNG LÀM GÌ CẢ (Để người chơi tự do lia tâm)
        -- Vòng tròn vẫn hiện màu xanh lá để báo hiệu sẵn sàng
    end
end)

-- ==============================================================================
-- [SECTION 7] BACKSTAB ENGINE (STICKY V3 + TEAM CHECK)
-- ==============================================================================
local CurrentBS_Target = nil

local function GetNearestBackstab()
    local bestChar, minDist = nil, math.huge
    for i = 1, #TargetCache do
        local d = TargetCache[i]
        
        -- TEAM CHECK LOGIC: Nếu là đồng đội thì bỏ qua
        local isTeammate = false
        if _G.CORE.BackstabTeamCheck and d.Player then
             if d.Player.Team == LocalPlayer.Team and d.Player.Team ~= nil then
                 isTeammate = true
             end
        end
        
        if not isTeammate then
            if d.Dist < minDist then
                minDist = d.Dist
                bestChar = d.Char
            end
        end
    end
    return bestChar
end

RunService.Heartbeat:Connect(function()
    -- Nếu tắt chức năng thì reset và thoát
    if not _G.CORE.BackstabEnabled then 
        CurrentBS_Target = nil
        return 
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and FindFirstChild(myChar, "HumanoidRootPart")
    
    if not myRoot then return end

    -- 1. VALIDATION (Kiểm tra mục tiêu hiện tại)
    if CurrentBS_Target then
        local hum = FindFirstChild(CurrentBS_Target, "Humanoid")
        local root = FindFirstChild(CurrentBS_Target, "HumanoidRootPart")
        
        -- Nếu mục tiêu chết (Máu <= 0), mất root, hoặc biến mất khỏi game -> Hủy ngay
        if not hum or hum.Health <= 0 or not root or not CurrentBS_Target.Parent then
            CurrentBS_Target = nil 
        end
    end
    
    -- 2. ACQUISITION (Nếu chưa có mục tiêu, lấy từ Cache)
    if not CurrentBS_Target then
        CurrentBS_Target = GetNearestBackstab()
    end
    
    -- 3. EXECUTION (Thực thi Backstab)
    if CurrentBS_Target then
        local tRoot = FindFirstChild(CurrentBS_Target, "HumanoidRootPart")
        if tRoot then
            -- Tính toán vị trí: Sau lưng 1.2 studs
            local backOffset = CF(0, 0, _G.CORE.BackstabDist)
            local targetCFrame = tRoot.CFrame * backOffset
            
            -- Tính khoảng cách thực tế
            local dist = (myRoot.Position - targetCFrame.Position).Magnitude
            
            -- Tốc độ Tween
            local speed = math.max(_G.CORE.BackstabSpeed, 20)
            local duration = dist / speed
            
            -- Giới hạn frame time (tránh lỗi chia cho 0)
            if duration < 0.03 then duration = 0.03 end 
            
            -- Chỉ Tween nếu khoảng cách đáng kể (> 0.5 studs) để tránh spam lệnh
            if dist > 0.5 then
                local tInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
                local tween = TweenService:Create(myRoot, tInfo, {CFrame = targetCFrame})
                tween:Play()
            else
                -- Nếu đã rất gần, dùng CFrame Lerp nhẹ để "dính" vào (Sticky Effect)
                myRoot.CFrame = myRoot.CFrame:Lerp(targetCFrame, 0.5)
            end
            
            -- Anti-Cheat: Fake Velocity (Giả lập vật lý)
            if tRoot.AssemblyLinearVelocity then
                myRoot.AssemblyLinearVelocity = tRoot.AssemblyLinearVelocity
            end
            
            -- Anti-Cheat: Luôn nhìn vào lưng mục tiêu
            local lookPos = V3(tRoot.Position.X, myRoot.Position.Y, tRoot.Position.Z)
            myRoot.CFrame = CFrame.lookAt(myRoot.Position, lookPos)
        end
    end
end)

-- ==============================================================================
-- [SECTION 8] UI INTERFACE (RAYFIELD)
-- ==============================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "Oxen Hub - Mobile Final",
   Icon = 0,
   LoadingTitle = "Oxen-Hub V46",
   LoadingSubtitle = "Combat Ready",
   Theme = "Default",
   DisableRayfieldPrompts = false,
   ConfigurationSaving = { Enabled = true, FileName = "OxenHub_V46_Final" },
   KeySystem = false,
})

-- === TAB 1: COMBAT ===
local CombatTab = Window:CreateTab("Combat", nil)
CombatTab:CreateSection("Aimbot Logic (Trigger Mode)")

CombatTab:CreateToggle({
    Name = "Enable Aimbot (Hold Shoot to Lock)",
    CurrentValue = false,
    Flag = "Aim",
    Callback = function(v) _G.CORE.AimEnabled = v end,
})

CombatTab:CreateToggle({
    Name = "Wall Check (Chắn tường)",
    CurrentValue = true,
    Flag = "WallCheck",
    Callback = function(v) _G.CORE.WallCheck = v end,
})

local RecoilSection = CombatTab:CreateSection("Gun Mods")

CombatTab:CreateToggle({
    Name = "No Recoil (Mobile Fix)",
    CurrentValue = false,
    Flag = "Recoil",
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
                    Cam.CFrame = CF(Cam.CFrame.Position) * CFrame.fromOrientation(lx, y, z)
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
    Name = "Bật ESP (Master)",
    CurrentValue = true,
    Flag = "ESP",
    Callback = function(v) 
        _G.CORE.EspEnabled = v
        _G.CORE.EspBox = v
        _G.CORE.EspName = v
    end,
})

VisualsTab:CreateToggle({
    Name = "Show Boxes",
    CurrentValue = true,
    Callback = function(v) _G.CORE.EspBox = v end,
})

VisualsTab:CreateToggle({
    Name = "Show Names",
    CurrentValue = true,
    Callback = function(v) _G.CORE.EspName = v end,
})

VisualsTab:CreateToggle({
    Name = "FFA Mode (Hiện tất cả)",
    CurrentValue = false,
    Flag = "FFAMode",
    Callback = function(v) _G.CORE.EspFFA = v end,
})

-- === TAB 3: MOVEMENT ===
local MoveTab = Window:CreateTab("Movement", nil)

MoveTab:CreateSection("Backstab V3 (Sticky + TeamCheck)")
MoveTab:CreateToggle({
    Name = "Auto Backstab (Continuous)",
    CurrentValue = false,
    Callback = function(v) 
        _G.CORE.BackstabEnabled = v 
        if not v then CurrentBS_Target = nil end
    end
})
MoveTab:CreateToggle({
    Name = "Team Check (Bỏ qua đồng đội)",
    CurrentValue = true,
    Callback = function(v) _G.CORE.BackstabTeamCheck = v end
})
MoveTab:CreateSlider({
    Name = "Tween Speed",
    Range = {20, 200}, Increment = 5, CurrentValue = 50,
    Callback = function(v) _G.CORE.BackstabSpeed = v end
})

MoveTab:CreateSection("Character Mods")
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

-- SMOOTH FLY (MOBILE UI)
local FlySettings = {Enabled = false, Speed = 1.5, Smoothness = 0.2, GoingUp = false, GoingDown = false, CurrentVelocity = V3(0,0,0)}
local MobileFlyUI = nil

local function ToggleMobileFlyUI(bool)
    if bool then
        if MobileFlyUI then MobileFlyUI:Destroy() end
        local ScreenGui = Instance.new("ScreenGui", CoreGui)
        ScreenGui.Name = "OxenFlyUI"

        local BtnUp = Instance.new("TextButton", ScreenGui)
        BtnUp.Size = UDim2.new(0, 50, 0, 50); BtnUp.Position = UDim2.new(0, 10, 0.40, 0) 
        BtnUp.BackgroundColor3 = Color3.fromRGB(0, 200, 0); BtnUp.BackgroundTransparency = 0.4
        BtnUp.Text = "UP"; Instance.new("UICorner", BtnUp).CornerRadius = UDim.new(1, 0)

        local BtnDown = Instance.new("TextButton", ScreenGui)
        BtnDown.Size = UDim2.new(0, 50, 0, 50); BtnDown.Position = UDim2.new(0, 10, 0.40, 60) 
        BtnDown.BackgroundColor3 = Color3.fromRGB(200, 0, 0); BtnDown.BackgroundTransparency = 0.4
        BtnDown.Text = "DN"; Instance.new("UICorner", BtnDown).CornerRadius = UDim.new(1, 0)

        BtnUp.InputBegan:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingUp = true end end)
        BtnUp.InputEnded:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingUp = false end end)
        BtnDown.InputBegan:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingDown = true end end)
        BtnDown.InputEnded:Connect(function(i) if i.UserInputType.Name:match("Touch") then FlySettings.GoingDown = false end end)
        MobileFlyUI = ScreenGui
    else
        if MobileFlyUI then MobileFlyUI:Destroy() end
        MobileFlyUI = nil; FlySettings.GoingUp = false; FlySettings.GoingDown = false
        FlySettings.CurrentVelocity = V3(0,0,0)
    end
end
local NoclipConn = nil
RunService.RenderStepped:Connect(function()
    if not FlySettings.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return end
    
    root.Velocity = Vector3.zero
    local moveDir = hum.MoveDirection
    local targetDir = V3(moveDir.X, 0, moveDir.Z) * FlySettings.Speed
    if FlySettings.GoingUp then targetDir = targetDir + V3(0, FlySettings.Speed, 0)
    elseif FlySettings.GoingDown then targetDir = targetDir + V3(0, -FlySettings.Speed, 0) end
    
    FlySettings.CurrentVelocity = FlySettings.CurrentVelocity:Lerp(targetDir, FlySettings.Smoothness)
    if FlySettings.CurrentVelocity.Magnitude > 0.01 then root.CFrame = root.CFrame + FlySettings.CurrentVelocity
    else FlySettings.CurrentVelocity = Vector3.zero end
    hum.PlatformStand = true 
end)

MoveTab:CreateSection("Fly System")
MoveTab:CreateToggle({
    Name = "Smooth Fly (Mobile UI + Noclip)",
    CurrentValue = false,
    Callback = function(v)
        FlySettings.Enabled = v
        ToggleMobileFlyUI(v) 
        if v then
            if NoclipConn then NoclipConn:Disconnect() end
            NoclipConn = RunService.Stepped:Connect(function()
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                    end
                end
            end)
        else
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
-- [SECTION 9] GARBAGE COLLECTOR
-- ==============================================================================
task.spawn(function()
    while true do
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if root and not root:FindFirstChild("MobESP") then CreateESP(p.Character) end
            end
        end
        task.wait(3) 
    end
end)

Rayfield:Notify({Title = "Oxen Hub Final", Content = "V46: Combat Ready Loaded", Duration = 5})
