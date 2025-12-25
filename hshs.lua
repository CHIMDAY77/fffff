--[[
    ► MOBILE AIMBOT PRO (STANDALONE EDITION)
    ► Optimized for: Delta X, Hydrogen, Fluxus (Android/iOS)
    ► Build: V2.0 (Silent + Assist)
    ► Logic: Raw Performance (No UI, Just Power)
]]

-- // 1. CẤU HÌNH (SETTINGS)
-- Bạn có thể chỉnh sửa trực tiếp tại đây
getgenv().MobileConfig = {
    Keybind = Enum.UserInputType.MouseButton1, -- Chạm màn hình để bắn/aim
    ShowFOV = true,             -- Hiện vòng tròn FOV
    FOV_Radius = 150,           -- Bán kính vòng tròn (To hơn để dễ aim trên mobile)
    FOV_Color = Color3.fromRGB(255, 0, 0), -- Màu đỏ chiến
    
    SilentAim = {
        Enabled = true,
        HitChance = 100,        -- Tỉ lệ trúng (100 = Luôn trúng)
        Part = "HumanoidRootPart", -- Bộ phận nhắm (Head, Torso, HumanoidRootPart)
        Prediction = 0.145,     -- Dự đoán di chuyển (Ping 60-100ms)
        AutoPred = true         -- Tự động chỉnh Pred theo Ping
    },
    
    Checks = {
        WallCheck = true,       -- Không bắn xuyên tường (Tắt để giảm lag nếu máy yếu)
        TeamCheck = true,       -- Không bắn đồng đội
        KnockedCheck = true,    -- Không bắn người bị knock (Da Hood)
        ForceFieldCheck = true  -- Không bắn người có khiên bất tử
    }
}

-- // 2. DỊCH VỤ & KHỞI TẠO
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Quản lý Drawing (Vẽ vòng tròn) - Tối ưu cho Mobile Executor
-- Khai báo Global để tránh lỗi mất hình trên Delta
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = MobileConfig.ShowFOV
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 24 -- Giảm số cạnh để đỡ lag trên điện thoại yếu
FOVCircle.Radius = MobileConfig.FOV_Radius
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Color = MobileConfig.FOV_Color

-- Biến lưu mục tiêu toàn cục (để Hook sử dụng)
getgenv()._G.MobileAimTarget = nil

-- // 3. HÀM HỖ TRỢ (OPTIMIZED FUNCTIONS)

-- Kiểm tra mục tiêu hợp lệ (Gộp chung để gọi 1 lần)
local function IsValidTarget(plr)
    if not plr or not plr.Character or plr == LocalPlayer then return false end
    
    local hum = plr.Character:FindFirstChild("Humanoid")
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    
    if not hum or not root or hum.Health <= 0 then return false end
    
    -- Check ForceField
    if MobileConfig.Checks.ForceFieldCheck and plr.Character:FindFirstChildOfClass("ForceField") then return false end
    
    -- Check Team
    if MobileConfig.Checks.TeamCheck and LocalPlayer.Team ~= nil and plr.Team ~= nil and plr.Team == LocalPlayer.Team then return false end
    
    -- Check Knocked (Da Hood specific)
    if MobileConfig.Checks.KnockedCheck then
        local be = plr.Character:FindFirstChild("BodyEffects")
        if be then
            local ko = be:FindFirstChild("K.O") or be:FindFirstChild("KO")
            if ko and ko.Value then return false end
        end
        if plr.Character:FindFirstChild("GRABBING_CONSTRAINT") then return false end
    end
    
    return true
end

-- Raycast WallCheck (Tái sử dụng Params để tiết kiệm RAM)
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

local function IsVisible(target)
    if not MobileConfig.Checks.WallCheck then return true end
    if not LocalPlayer.Character then return false end
    
    -- Cập nhật danh sách bỏ qua
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character, target.Character, Camera}
    
    local origin = Camera.CFrame.Position
    local dest = target.Character[MobileConfig.SilentAim.Part].Position
    local dir = dest - origin
    
    local ray = Workspace:Raycast(origin, dir, RayParams)
    
    -- Nếu không trúng gì hoặc trúng nhân vật địch -> Nhìn thấy
    return ray == nil or ray.Instance:IsDescendantOf(target.Character)
end

-- Chuyển tọa độ thế giới sang màn hình
local function GetScreenPos(pos)
    local screen, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screen.X, screen.Y), onScreen
end

-- Tính toán Prediction tự động theo Ping
local function GetAutoPred()
    if not MobileConfig.SilentAim.AutoPred then return MobileConfig.SilentAim.Prediction end
    
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    -- Công thức ước lượng đơn giản nhưng hiệu quả
    if ping < 30 then return 0.11
    elseif ping < 60 then return 0.125
    elseif ping < 90 then return 0.138
    elseif ping < 130 then return 0.152
    else return 0.165 end
end

-- // 4. LOGIC TÌM MỤC TIÊU (TARGET SELECTOR)
local function GetClosestPlayer()
    local bestTarget = nil
    local shortestDist = math.huge
    local mousePos = Vector2.new(Camera.ViewportSize.X / 2, (Camera.ViewportSize.Y / 2) + GuiService:GetGuiInset().Y) -- Tâm màn hình chuẩn
    
    for _, plr in pairs(Players:GetPlayers()) do
        if IsValidTarget(plr) then
            local part = plr.Character[MobileConfig.SilentAim.Part]
            local screenPos, onScreen = GetScreenPos(part.Position)
            
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                
                -- Chỉ xét trong vòng FOV
                if dist <= MobileConfig.FOV_Radius then
                    -- WallCheck chỉ chạy khi đã thỏa mãn các điều kiện trên (Tiết kiệm CPU)
                    if IsVisible(plr) then
                        if dist < shortestDist then
                            shortestDist = dist
                            bestTarget = plr
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- // 5. CORE LOOP (VÒNG LẶP CHÍNH)
-- Sử dụng RenderStepped để cập nhật FOV và Aim mượt mà nhất
RunService.RenderStepped:Connect(function()
    -- Cập nhật Prediction
    if MobileConfig.SilentAim.AutoPred then
        MobileConfig.SilentAim.Prediction = GetAutoPred()
    end

    -- Cập nhật vị trí vòng tròn theo tâm màn hình
    local center = Vector2.new(Camera.ViewportSize.X / 2, (Camera.ViewportSize.Y / 2) + GuiService:GetGuiInset().Y)
    FOVCircle.Position = center
    FOVCircle.Radius = MobileConfig.FOV_Radius
    FOVCircle.Color = MobileConfig.FOV_Color
    FOVCircle.Visible = MobileConfig.ShowFOV
    
    -- Quét mục tiêu liên tục
    local target = GetClosestPlayer()
    
    if target then
        -- Visual Feedback: Đổi màu khi bắt được địch
        FOVCircle.Color = Color3.fromRGB(0, 255, 0) -- Xanh lá (Locked)
        _G.MobileAimTarget = target -- Lưu vào biến toàn cục để Hook sử dụng
    else
        FOVCircle.Color = MobileConfig.FOV_Color -- Đỏ (Idle)
        _G.MobileAimTarget = nil
    end
end)

-- // 6. SILENT AIM HOOK (MAGIC BULLET)
-- Phần này can thiệp vào game để bẻ cong đạn
-- Sử dụng kỹ thuật Hook an toàn cho Mobile (Delta/Fluxus support)

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    -- Chỉ hook khi có mục tiêu và chức năng bật
    if MobileConfig.SilentAim.Enabled and _G.MobileAimTarget and _G.MobileAimTarget.Character then
        if method == "FireServer" or method == "InvokeServer" then
            -- Kiểm tra các RemoteEvent phổ biến (Da Hood, Arsenal, Phantom Forces, v.v.)
            -- Logic chung: Tìm tham số Vector3 (vị trí bắn) và thay thế nó bằng đầu địch
            
            -- Tính toán vị trí dự đoán
            local root = _G.MobileAimTarget.Character[MobileConfig.SilentAim.Part]
            local vel = root.Velocity
            local predPos = root.Position + (vel * MobileConfig.SilentAim.Prediction)
            
            -- Thay thế tham số
            for i, v in pairs(args) do
                if typeof(v) == "Vector3" then
                    -- Thay thế vị trí chuột bằng vị trí đầu địch
                    args[i] = predPos
                elseif typeof(v) == "CFrame" then
                     -- Một số game dùng CFrame
                    args[i] = CFrame.new(Camera.CFrame.Position, predPos)
                end
            end
            
            return oldNamecall(self, unpack(args))
        end
    end
    
    return oldNamecall(self, ...)
end)

-- Hook Index (Dành cho game cũ dùng Mouse.Hit)
mt.__index = newcclosure(function(self, k)
    if k == "Hit" and MobileConfig.SilentAim.Enabled and _G.MobileAimTarget and _G.MobileAimTarget.Character then
        local root = _G.MobileAimTarget.Character[MobileConfig.SilentAim.Part]
        local vel = root.Velocity
        local predPos = root.Position + (vel * MobileConfig.SilentAim.Prediction)
        
        -- Trả về CFrame giả nhắm vào địch
        return CFrame.new(predPos)
    end
    
    -- Hook Target (Dành cho game check Mouse.Target)
    if k == "Target" and MobileConfig.SilentAim.Enabled and _G.MobileAimTarget and _G.MobileAimTarget.Character then
        return _G.MobileAimTarget.Character[MobileConfig.SilentAim.Part]
    end
    
    return oldIndex(self, k)
end)

setreadonly(mt, true)

-- // 7. THÔNG BÁO KHỞI ĐỘNG
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Mobile Aim V2";
    Text = "Active! FOV: " .. MobileConfig.FOV_Radius;
    Duration = 3;
})
