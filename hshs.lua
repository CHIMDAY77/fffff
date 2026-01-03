local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Cấu hình
local Settings = {
    ESP_Players = false,
    ESP_Monster = false,
    ESP_Coins = false,
    CoinFolder = "Coins",
    -- Màu sắc
    Color_Team = Color3.fromRGB(0, 255, 100),
    Color_Enemy = Color3.fromRGB(255, 0, 0), -- Màu đỏ cho địch/quái
    Color_Coin = Color3.fromRGB(255, 255, 0)
}

-- Tạo Window UI
local Window = Rayfield:CreateWindow({
    Name = "Fragid Dusk | ESP Fix",
    LoadingTitle = "Loading...",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false,
})

-------------------------------------------------------------------
-- [CORE] HÀM VẼ BOX (DÙNG CHUNG CHO CẢ NGƯỜI VÀ QUÁI)
-------------------------------------------------------------------
-- Hàm này tạo box 2D nét đứt (Style Oxen Hub)
local function DrawESP(targetPart, nameText, color)
    if not targetPart then return end
    
    -- Kiểm tra xem đã có ESP chưa
    local bb = targetPart:FindFirstChild("OxenESP_Box")
    if not bb then
        -- 1. Tạo BillboardGui (Container)
        bb = Instance.new("BillboardGui")
        bb.Name = "OxenESP_Box"
        bb.Adornee = targetPart
        bb.Size = UDim2.new(4.5, 0, 6, 0) -- Kích thước Box (Rộng x Cao)
        bb.AlwaysOnTop = true
        bb.Parent = targetPart
        
        -- 2. Tạo Khung (Frame)
        local frame = Instance.new("Frame", bb)
        frame.Name = "ESPFrame"
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        
        -- 3. Tạo Viền (Stroke)
        local stroke = Instance.new("UIStroke", frame)
        stroke.Name = "ESPStroke"
        stroke.Thickness = 2 -- Độ dày viền
        stroke.Transparency = 0
        stroke.LineJoinMode = Enum.LineJoinMode.Miter
        
        -- 4. Tạo Chữ (Text)
        local txt = Instance.new("TextLabel", bb)
        txt.Name = "ESPText"
        txt.Size = UDim2.new(1, 0, 0, 20)
        txt.Position = UDim2.new(0, 0, -0.3, 0) -- Đẩy chữ lên trên đầu
        txt.BackgroundTransparency = 1
        txt.TextStrokeTransparency = 0
        txt.Font = Enum.Font.GothamBold
        txt.TextSize = 12
    end
    
    -- Cập nhật thông tin (Real-time)
    bb.Enabled = true
    
    local txt = bb:FindFirstChild("ESPText")
    local frame = bb:FindFirstChild("ESPFrame")
    local stroke = frame and frame:FindFirstChild("ESPStroke")
    
    -- Tính khoảng cách
    local dist = "N/A"
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        dist = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - targetPart.Position).Magnitude)
    end
    
    if txt then
        txt.Text = string.format("%s\n[%dm]", nameText, dist)
        txt.TextColor3 = color
    end
    
    if stroke then
        stroke.Color = color
    end
end

-- Hàm xóa ESP khi tắt
local function ClearESP(attributeType)
    -- Quét tất cả ESP trong game để xóa loại tương ứng
    for _, v in pairs(Workspace:GetDescendants()) do
        if v.Name == "OxenESP_Box" and v:GetAttribute("ESPType") == attributeType then
            v:Destroy()
        end
    end
end

-------------------------------------------------------------------
-- [UI] CÁC TAB CHỨC NĂNG
-------------------------------------------------------------------
local VisualTab = Window:CreateTab("Visuals", 4483362458)

VisualTab:CreateToggle({
    Name = "ESP Players (Box 2D)",
    CurrentValue = false,
    Flag = "ESP_Players",
    Callback = function(Value)
        Settings.ESP_Players = Value
        if not Value then
            -- Tắt ESP Player
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character then
                    local esp = p.Character:FindFirstChild("OxenESP_Box", true)
                    if esp then esp:Destroy() end
                end
            end
        end
    end,
})

VisualTab:CreateToggle({
    Name = "ESP Monster (Box 2D)",
    CurrentValue = false,
    Flag = "ESP_Monster",
    Callback = function(Value)
        Settings.ESP_Monster = Value
        if not Value then
            -- Tìm và xóa ESP Monster cũ
            if Workspace.Map.Lab.Interaction.MonsterB:FindFirstChild("Hitbox") then
                local esp = Workspace.Map.Lab.Interaction.MonsterB.Hitbox:FindFirstChild("OxenESP_Box")
                if esp then esp:Destroy() end
            end
        end
    end,
})

VisualTab:CreateToggle({
    Name = "ESP Coins",
    CurrentValue = false,
    Flag = "ESP_Coins",
    Callback = function(Value)
        Settings.ESP_Coins = Value
        if not Value then
             local coinFolder = Workspace:FindFirstChild(Settings.CoinFolder)
             if coinFolder then
                for _, c in pairs(coinFolder:GetChildren()) do
                    if c:FindFirstChild("Base") then
                        local esp = c.Base:FindFirstChild("OxenESP_Box")
                        if esp then esp:Destroy() end
                    end
                end
             end
        end
    end,
})

-------------------------------------------------------------------
-- [LOOP] VÒNG LẶP CẬP NHẬT
-------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    -- 1. XỬ LÝ ESP NGƯỜI CHƠI
    if Settings.ESP_Players then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local color = (player.Team == LocalPlayer.Team) and Settings.Color_Team or Settings.Color_Enemy
                    DrawESP(root, player.Name, color)
                end
            end
        end
    end

    -- 2. XỬ LÝ ESP QUÁI VẬT (MONSTER)
    if Settings.ESP_Monster then
        -- Sử dụng pcall để tránh lỗi nếu đường dẫn sai hoặc quái chưa spawn
        local success, _ = pcall(function()
            local monsterHitbox = Workspace.Map.Lab.Interaction.MonsterB.Hitbox
            if monsterHitbox then
                -- Gọi hàm DrawESP giống hệt Player
                DrawESP(monsterHitbox, "MONSTER", Settings.Color_Enemy)
                
                -- Đánh dấu ESP này là Monster để dễ quản lý (Optional)
                local currentESP = monsterHitbox:FindFirstChild("OxenESP_Box")
                if currentESP then currentESP:SetAttribute("ESPType", "Monster") end
            end
        end)
    end

    -- 3. XỬ LÝ ESP COINS
    if Settings.ESP_Coins then
        local coinFolder = Workspace:FindFirstChild(Settings.CoinFolder)
        if coinFolder then
            for _, coin in pairs(coinFolder:GetChildren()) do
                if coin.Name == "Money" and coin:FindFirstChild("Base") then
                    DrawESP(coin.Base, "Coin", Settings.Color_Coin)
                end
            end
        end
    end
end)
