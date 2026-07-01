--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║     WARCORE v2.1 - UI COMPACTA + NOVAS FUNÇÕES                    ║
    ║     Design Responsivo • Mobile-Friendly • Mais Recursos            ║
    ╚══════════════════════════════════════════════════════════════════════╝
]]

-- ============================================================
-- 1. CONFIGURAÇÃO GLOBAL
-- ============================================================
getgenv().Warcore = getgenv().Warcore or {}
local Config = getgenv().Warcore

Config.Settings = {
    -- Combate
    AimAssist = false,
    SilentAim = false,
    FovRadius = 500,
    Smoothness = 0.35,
    TeamCheck = true,
    TriggerBot = false,
    TriggerDelay = 0.1,
    FovCircle = false,
    AutoClick = false,
    AutoClickDelay = 0.1,

    -- Visual (ESP)
    HighlightEnabled = false,
    HlDepthMode = "AlwaysOnTop",
    HlFillTransparency = 0.5,
    HlEnemyColor = Color3.fromRGB(255, 0, 0),
    DotEnabled = false,
    DotShape = "●",
    LineEnabled = false,
    LineColor = Color3.fromRGB(0, 255, 255),
    LineThickness = 1.5,
    MicroHpEnabled = false,
    MicroDistEnabled = false,
    MicroTextSize = 8,
    MicroWidth = 35,
    DistColor = Color3.fromRGB(255, 255, 255),
    NoFog = false,
    FovChanger = false,
    FovValue = 70,

    -- Iluminação
    FullBright = false,
    NoShadows = false,
    ClarezaMod = false,

    -- Monitor
    ShowFPS = false,
    ShowPlayers = false,

    -- Movimento
    FlyEnabled = false,
    FlySpeed = 50,
    FlyInfinite = false,
    SpeedEnabled = false,
    SpeedValue = 50,
    JumpEnabled = false,
    JumpPower = 100,
    InfiniteJump = false,
    NoClip = false,
    AntiAFK = false,

    -- Teleporte
    TeleportEnabled = false,

    -- Outros
    NoFallDamage = false,
}

-- ============================================================
-- 2. UTILITÁRIOS E CACHE
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Player = Players.LocalPlayer
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Cache de objetos por jogador
local Cache = {
    Highlights = {},
    Dots = {},
    MicroHUDs = {},
    Lines = {},
}

-- Valores originais para reset
local Original = {
    WalkSpeed = 16,
    JumpPower = 50,
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    GlobalShadows = Lighting.GlobalShadows,
    Exposure = Lighting.ExposureCompensation,
    CameraFov = Camera.FieldOfView,
}

-- Funções auxiliares
local function GetCharacter()
    return Player.Character
end

local function GetHumanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function IsTeamMate(player)
    return player.Team == Player.Team and Player.Team ~= nil
end

local function GetDepthMode()
    local mode = Config.Settings.HlDepthMode
    if mode == "AlwaysOnTop" then
        return Enum.HighlightDepthMode.AlwaysOnTop
    elseif mode == "Occluded" then
        return Enum.HighlightDepthMode.Occluded
    else
        return Enum.HighlightDepthMode.AlwaysOnTop
    end
end

-- ============================================================
-- 3. MÓDULO DE COMBATE (Aim Assist, Silent Aim, Trigger, AutoClick)
-- ============================================================
local Combat = {}
local fovCircle = nil
local aimTarget = nil
local triggerCooldown = 0
local autoClickCooldown = 0

function Combat.GetTarget()
    local closest, shortest = nil, Config.Settings.FovRadius
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                if not (IsTeamMate(p) and Config.Settings.TeamCheck) then
                    local pos, vis = Camera:WorldToViewportPoint(head.Position)
                    if vis and pos.Z > 0 then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist < shortest then
                            shortest = dist
                            closest = head
                        end
                    end
                end
            end
        end
    end
    return closest
end

function Combat.UpdateFovCircle()
    if Config.Settings.FovCircle then
        if not fovCircle then
            fovCircle = Drawing.new("Circle")
            fovCircle.Visible = true
            fovCircle.Radius = Config.Settings.FovRadius
            fovCircle.Color = Color3.fromRGB(0, 255, 255)
            fovCircle.Thickness = 1.5
            fovCircle.Filled = false
            fovCircle.Transparency = 0.5
        end
        fovCircle.Radius = Config.Settings.FovRadius
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Visible = true
    else
        if fovCircle then
            fovCircle.Visible = false
        end
    end
end

function Combat.TriggerBot()
    if not Config.Settings.TriggerBot then return end
    if tick() - triggerCooldown < Config.Settings.TriggerDelay then return end

    local target = Combat.GetTarget()
    if target then
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        triggerCooldown = tick()
    end
end

function Combat.AutoClick()
    if not Config.Settings.AutoClick then return end
    if tick() - autoClickCooldown < Config.Settings.AutoClickDelay then return end

    local target = Combat.GetTarget()
    if target then
        -- Verifica se o alvo está no centro da tela (dentro de um raio pequeno)
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local pos, vis = Camera:WorldToViewportPoint(target.Position)
        if vis and pos.Z > 0 then
            local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
            if dist < 100 then -- raio de 100 pixels
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                autoClickCooldown = tick()
            end
        end
    end
end

function Combat.UpdateAim()
    if Config.Settings.AimAssist then
        local target = Combat.GetTarget()
        if target then
            local goal = CFrame.new(Camera.CFrame.Position, target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(goal, Config.Settings.Smoothness * math.clamp(60 * RunService.RenderStepped:Wait(), 0, 1))
            aimTarget = target
        else
            aimTarget = nil
        end
    end

    -- Silent Aim: ajusta a mira sem mover a câmera (apenas para armas)
    if Config.Settings.SilentAim then
        local target = Combat.GetTarget()
        if target then
            -- Aqui seria necessário modificar a direção do tiro, mas isso é específico de cada jogo.
            -- Uma abordagem comum é usar um remoto ou modificar o ângulo da arma.
            -- Como não temos acesso ao jogo específico, apenas simulamos o efeito.
            -- Vamos apenas armazenar o alvo para uso futuro.
            aimTarget = target
        end
    end
end

-- ============================================================
-- 4. MÓDULO VISUAL (ESP, Dot, Line, Micro-HUD, NoFog, FovChanger)
-- ============================================================
local Visual = {}

function Visual.UpdateHighlight(player)
    local char = player.Character
    if not char then return end
    local hl = Cache.Highlights[player]
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "Warcore_HL"
        hl.Parent = char
        Cache.Highlights[player] = hl
    end
    local isTeam = IsTeamMate(player)
    local color = isTeam and Color3.fromRGB(0, 255, 0) or Config.Settings.HlEnemyColor
    hl.Enabled = Config.Settings.HighlightEnabled
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = Config.Settings.HlFillTransparency
    hl.OutlineTransparency = 0
    hl.Adornee = char
    pcall(function() hl.DepthMode = GetDepthMode() end)
end

function Visual.UpdateDot(player)
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local dot = Cache.Dots[player]
    if not dot then
        dot = Instance.new("BillboardGui")
        dot.Name = "Warcore_Dot"
        dot.Size = UDim2.new(0, 20, 0, 20) -- menor
        dot.AlwaysOnTop = true
        dot.ExtentsOffset = Vector3.new(0, 1.5, 0)
        dot.Parent = head

        local label = Instance.new("TextLabel", dot)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextStrokeTransparency = 0.3
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        Cache.Dots[player] = dot
    end

    local label = dot:FindFirstChildOfClass("TextLabel")
    if not label then return end

    local isTeam = IsTeamMate(player)
    local behind = false
    local headPos = head.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {GetCharacter(), char}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(Camera.CFrame.Position, (headPos - Camera.CFrame.Position).Unit * 1000, rayParams)
    behind = result ~= nil

    local dotColor = isTeam and Color3.fromRGB(0, 255, 0) or (behind and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(255, 0, 0))
    label.TextColor3 = dotColor
    label.Text = Config.Settings.DotShape

    local shape = Config.Settings.DotShape
    if shape == "●" then label.TextSize = 14
    elseif shape == "▲" then label.TextSize = 16
    elseif shape == "■" then label.TextSize = 14
    elseif shape == "◆" then label.TextSize = 16
    elseif shape == "★" then label.TextSize = 16
    end

    dot.Enabled = Config.Settings.DotEnabled
end

function Visual.UpdateMicroHUD(player)
    local char = player.Character
    if not char then return end
    local root = GetRootPart(char)
    local hum = GetHumanoid(char)
    if not root or not hum or hum.Health <= 0 then
        if Cache.MicroHUDs[player] then
            Cache.MicroHUDs[player].Enabled = false
        end
        return
    end

    local hud = Cache.MicroHUDs[player]
    if not hud then
        hud = Instance.new("BillboardGui", root)
        hud.Name = "Warcore_MicroHUD"
        hud.AlwaysOnTop = true
        hud.ExtentsOffset = Vector3.new(0, -3.2, 0) -- ajuste

        local bgBar = Instance.new("Frame", hud)
        bgBar.Name = "BackgroundBar"
        bgBar.Size = UDim2.new(1, 0, 0, 2)
        bgBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        bgBar.BorderSizePixel = 0

        local mainBar = Instance.new("Frame", bgBar)
        mainBar.Name = "MainBar"
        mainBar.Size = UDim2.new(1, 0, 1, 0)
        mainBar.BorderSizePixel = 0

        local label = Instance.new("TextLabel", hud)
        label.Name = "DistLabel"
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.4
        label.TextXAlignment = Enum.TextXAlignment.Center

        Cache.MicroHUDs[player] = hud
    end

    local textWidth = math.max(Config.Settings.MicroWidth, 50) -- menor
    hud.Size = UDim2.new(0, textWidth, 0, Config.Settings.MicroTextSize + 6)
    hud.DistLabel.Size = UDim2.new(1, 0, 0, Config.Settings.MicroTextSize + 2)
    hud.DistLabel.TextSize = Config.Settings.MicroTextSize
    hud.DistLabel.Position = UDim2.new(0, 0, 0, 2)

    local isTeam = IsTeamMate(player)
    local teamColor = isTeam and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 50, 50)

    if Config.Settings.MicroHpEnabled then
        local healthRatio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        hud.BackgroundBar.MainBar.Size = UDim2.new(healthRatio, 0, 1, 0)
        hud.BackgroundBar.MainBar.BackgroundColor3 = teamColor
        hud.BackgroundBar.Visible = true
    else
        hud.BackgroundBar.Visible = false
    end

    if Config.Settings.MicroDistEnabled then
        local distance = math.floor(Player:DistanceFromCharacter(root.Position))
        hud.DistLabel.Text = string.format("%s %dm", player.Name, distance)
        hud.DistLabel.TextColor3 = Config.Settings.DistColor
        hud.DistLabel.Visible = true
    else
        hud.DistLabel.Visible = false
    end

    hud.Enabled = true
end

function Visual.UpdateLines()
    local lineEnabled = Config.Settings.LineEnabled
    local lineColor = Config.Settings.LineColor
    local lineThickness = Config.Settings.LineThickness

    local myRoot = GetRootPart(GetCharacter())
    if not myRoot then
        for _, line in pairs(Cache.Lines) do
            line.Visible = false
        end
        return
    end

    local myPos = Camera:WorldToViewportPoint(myRoot.Position)
    local myScreenPos = Vector2.new(myPos.X, myPos.Y)

    for player, line in pairs(Cache.Lines) do
        local char = player.Character
        if lineEnabled and char and GetRootPart(char) then
            local rootPart = GetRootPart(char)
            local enemyPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

            if onScreen and enemyPos.Z > 0 then
                line.Color = lineColor
                line.Thickness = lineThickness
                line.From = myScreenPos
                line.To = Vector2.new(enemyPos.X, enemyPos.Y)
                line.Visible = true
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

function Visual.InitLines()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            local line = Drawing.new("Line")
            line.Visible = false
            line.Color = Config.Settings.LineColor
            line.Thickness = Config.Settings.LineThickness
            line.Transparency = 1
            Cache.Lines[p] = line
        end
    end

    Players.PlayerAdded:Connect(function(p)
        if p ~= Player then
            local line = Drawing.new("Line")
            line.Visible = false
            line.Color = Config.Settings.LineColor
            line.Thickness = Config.Settings.LineThickness
            line.Transparency = 1
            Cache.Lines[p] = line
        end
    end)

    Players.PlayerRemoving:Connect(function(p)
        if Cache.Lines[p] then
            Cache.Lines[p]:Remove()
            Cache.Lines[p] = nil
        end
    end)
end

function Visual.UpdateNoFog()
    if Config.Settings.NoFog then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    else
        Lighting.FogEnd = Original.FogEnd
        -- FogStart não é armazenado, mas podemos deixar como 0
    end
end

function Visual.UpdateFov()
    if Config.Settings.FovChanger then
        Camera.FieldOfView = Config.Settings.FovValue
    else
        Camera.FieldOfView = Original.CameraFov
    end
end

-- ============================================================
-- 5. MÓDULO DE MOVIMENTO
-- ============================================================
local Movement = {}

local flyVelocity = nil
local flyConnection = nil
local noClipConnection = nil
local antiAFKConnection = nil

function Movement.StartFly()
    local char = GetCharacter()
    if not char then return end
    local hrp = GetRootPart(char)
    local hum = GetHumanoid(char)
    if not hrp or not hum then return end

    hum.PlatformStand = false
    hum.AutoRotate = true

    if flyVelocity then flyVelocity:Destroy() end
    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.Name = "FlyVelocity"
    flyVelocity.MaxForce = Vector3.new(400000, 400000, 400000)
    flyVelocity.Parent = hrp

    if flyConnection then flyConnection:Disconnect() end
    flyConnection = RunService.RenderStepped:Connect(function()
        if not Config.Settings.FlyEnabled then
            Movement.StopFly()
            return
        end
        local char = GetCharacter()
        if not char then return end
        local hrp = GetRootPart(char)
        local hum = GetHumanoid(char)
        if not hrp or not hum then return end
        if not flyVelocity then return end

        local speed = Config.Settings.FlySpeed
        local targetVel = Vector3.zero

        if Config.Settings.FlyInfinite then
            targetVel = Camera.CFrame.LookVector * speed
        else
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                local flatLook = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
                if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
                local flatCamCFrame = CFrame.lookAt(Vector3.zero, flatLook)
                local rawInput = flatCamCFrame:VectorToObjectSpace(moveDir)
                targetVel = Camera.CFrame:VectorToWorldSpace(rawInput) * speed
            else
                targetVel = Vector3.zero
            end
        end
        flyVelocity.Velocity = targetVel
    end)
end

function Movement.StopFly()
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    Config.Settings.FlyEnabled = false
end

function Movement.ToggleNoClip(enable)
    Config.Settings.NoClip = enable
    if enable then
        if noClipConnection then noClipConnection:Disconnect() end
        noClipConnection = RunService.Stepped:Connect(function()
            local char = GetCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    else
        if noClipConnection then
            noClipConnection:Disconnect()
            noClipConnection = nil
        end
        local char = GetCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end

function Movement.ToggleAntiAFK(enable)
    Config.Settings.AntiAFK = enable
    if enable then
        if antiAFKConnection then antiAFKConnection:Disconnect() end
        antiAFKConnection = RunService.Heartbeat:Connect(function()
            if not Config.Settings.AntiAFK then
                if antiAFKConnection then antiAFKConnection:Disconnect(); antiAFKConnection = nil end
                return
            end
            if tick() % 30 < 0.1 then
                local keys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D}
                local key = keys[math.random(1, #keys)]
                VirtualInputManager:SendKeyEvent(true, key, false, game)
                wait(0.1)
                VirtualInputManager:SendKeyEvent(false, key, false, game)
            end
        end)
    else
        if antiAFKConnection then
            antiAFKConnection:Disconnect()
            antiAFKConnection = nil
        end
    end
end

-- ============================================================
-- 6. MÓDULO DE TELEPORTE (com lista de jogadores)
-- ============================================================
local Teleport = {}
Teleport.Locations = {}
Teleport.FixedLocations = {
    {name = "👑 Bandeira", x = -463.30, y = 261.15, z = -1013.22},
    {name = "👑 Barril", x = 1706.69, y = 120.95, z = 3773.69}
}

function Teleport.TeleportToPlayer(player)
    local char = player.Character
    if char and GetRootPart(char) then
        local root = GetRootPart(GetCharacter())
        if root then
            root.CFrame = GetRootPart(char).CFrame + Vector3.new(0, 2, 0)
        end
    end
end

-- ============================================================
-- 7. MÓDULO DE MONITOR
-- ============================================================
local Monitor = {}
local TagContainer = Instance.new("Frame", CoreGui)
TagContainer.Size = UDim2.new(0, 60, 0, 50)
TagContainer.Position = UDim2.new(0, 5, 0, 45)
TagContainer.BackgroundTransparency = 1
local UIList = Instance.new("UIListLayout", TagContainer)
UIList.Padding = UDim.new(0, 3)

local function CreateTag(color)
    local f = Instance.new("Frame", TagContainer)
    f.Size = UDim2.new(0, 70, 0, 16)
    f.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
    f.BackgroundTransparency = 0.2
    f.Visible = false
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    local stroke = Instance.new("UIStroke", f)
    stroke.Thickness = 1
    stroke.Color = color
    stroke.Transparency = 0.4
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.TextSize = 10
    l.Font = Enum.Font.GothamBold
    return f, l
end

local fpsF, fpsL = CreateTag(Color3.fromRGB(0, 240, 255))
local countF, countL = CreateTag(Color3.fromRGB(255, 0, 120))

function Monitor.Update(dt)
    if Config.Settings.ShowFPS then
        fpsL.Text = "⚡ " .. math.floor(1 / dt)
        fpsF.Visible = true
    else
        fpsF.Visible = false
    end

    if Config.Settings.ShowPlayers then
        countL.Text = "👥 " .. #Players:GetPlayers()
        countF.Visible = true
    else
        countF.Visible = false
    end
end

-- ============================================================
-- 8. CRIAÇÃO DA UI PERSONALIZADA (TAMANHO REDUZIDO)
-- ============================================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "WarcoreUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- Tema
local Theme = {
    Background = Color3.fromRGB(11, 13, 23),
    Surface = Color3.fromRGB(25, 28, 40),
    SurfaceLight = Color3.fromRGB(40, 44, 60),
    Primary = Color3.fromRGB(0, 240, 255),
    Secondary = Color3.fromRGB(120, 80, 255),
    Text = Color3.fromRGB(240, 245, 255),
    TextMuted = Color3.fromRGB(160, 170, 190),
    Success = Color3.fromRGB(0, 255, 120),
    Danger = Color3.fromRGB(255, 60, 60),
    Warning = Color3.fromRGB(255, 200, 0),
}

-- Função para criar um botão estilizado (tamanhos reduzidos)
local function createStyledButton(parent, text, size, backgroundColor, textColor, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = size or UDim2.new(0, 160, 0, 32)
    btn.BackgroundColor3 = backgroundColor or Theme.SurfaceLight
    btn.TextColor3 = textColor or Theme.Text
    btn.Text = text or ""
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness = 1
    stroke.Color = Theme.Primary
    stroke.Transparency = 0.5

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Primary, TextColor3 = Color3.fromRGB(0,0,0)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = backgroundColor or Theme.SurfaceLight, TextColor3 = textColor or Theme.Text}):Play()
    end)
    btn.MouseButton1Click:Connect(callback or function() end)

    return btn
end

-- Função para criar um toggle (tamanho reduzido)
local function createToggle(parent, labelText, initialValue, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Theme.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left

    local toggleBtn = Instance.new("TextButton", frame)
    toggleBtn.Size = UDim2.new(0, 40, 0, 22)
    toggleBtn.Position = UDim2.new(1, -48, 0.5, -11)
    toggleBtn.BackgroundColor3 = initialValue and Theme.Primary or Theme.SurfaceLight
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.BorderSizePixel = 0
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

    local indicator = Instance.new("Frame", toggleBtn)
    indicator.Size = UDim2.new(0, 18, 0, 18)
    indicator.Position = initialValue and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9)
    indicator.BackgroundColor3 = Color3.fromRGB(255,255,255)
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

    local currentValue = initialValue

    local function updateToggle(value)
        currentValue = value
        TweenService:Create(toggleBtn, TweenInfo.new(0.12), {BackgroundColor3 = value and Theme.Primary or Theme.SurfaceLight}):Play()
        TweenService:Create(indicator, TweenInfo.new(0.12), {Position = value and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9)}):Play()
        if callback then callback(value) end
    end

    toggleBtn.MouseButton1Click:Connect(function()
        updateToggle(not currentValue)
    end)

    return {
        SetValue = updateToggle,
        GetValue = function() return currentValue end,
    }
end

-- Função para criar um slider (tamanho reduzido)
local function createSlider(parent, labelText, minValue, maxValue, step, initialValue, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 48)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.7, 0, 0, 18)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Theme.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left

    local valueLabel = Instance.new("TextLabel", frame)
    valueLabel.Size = UDim2.new(0.3, 0, 0, 18)
    valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(initialValue)
    valueLabel.TextColor3 = Theme.Primary
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local sliderBg = Instance.new("Frame", frame)
    sliderBg.Size = UDim2.new(1, 0, 0, 4)
    sliderBg.Position = UDim2.new(0, 0, 0, 22)
    sliderBg.BackgroundColor3 = Theme.SurfaceLight
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", sliderBg)
    fill.Size = UDim2.new((initialValue - minValue) / (maxValue - minValue), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Primary
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local currentValue = initialValue
    local dragging = false

    local function setValueFromPosition(x)
        local relativeX = math.clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        local val = minValue + (maxValue - minValue) * relativeX
        val = math.round(val / step) * step
        val = math.clamp(val, minValue, maxValue)
        currentValue = val
        fill.Size = UDim2.new((val - minValue) / (maxValue - minValue), 0, 1, 0)
        valueLabel.Text = tostring(val)
        if callback then callback(val) end
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setValueFromPosition(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setValueFromPosition(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        SetValue = function(val)
            val = math.clamp(val, minValue, maxValue)
            currentValue = val
            fill.Size = UDim2.new((val - minValue) / (maxValue - minValue), 0, 1, 0)
            valueLabel.Text = tostring(val)
            if callback then callback(val) end
        end,
        GetValue = function() return currentValue end,
    }
end

-- Função para criar um dropdown (tamanho reduzido)
local function createDropdown(parent, labelText, options, defaultOption, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Theme.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left

    local dropdownBtn = Instance.new("TextButton", frame)
    dropdownBtn.Size = UDim2.new(0.5, -10, 1, -6)
    dropdownBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
    dropdownBtn.BackgroundColor3 = Theme.SurfaceLight
    dropdownBtn.Text = defaultOption or options[1]
    dropdownBtn.TextColor3 = Theme.Text
    dropdownBtn.Font = Enum.Font.Gotham
    dropdownBtn.TextSize = 13
    dropdownBtn.AutoButtonColor = false
    dropdownBtn.BorderSizePixel = 0
    Instance.new("UICorner", dropdownBtn).CornerRadius = UDim.new(0, 4)

    local isOpen = false
    local listFrame = Instance.new("Frame", frame)
    listFrame.Size = UDim2.new(0.5, -10, 0, 0)
    listFrame.Position = UDim2.new(0.5, 0, 1, 0)
    listFrame.BackgroundColor3 = Theme.Surface
    listFrame.ClipsDescendants = true
    listFrame.Visible = false
    listFrame.ZIndex = 2
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 4)

    local listLayout = Instance.new("UIListLayout", listFrame)
    listLayout.Padding = UDim.new(0, 2)

    local selectedOption = defaultOption or options[1]

    local function updateList()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, opt in ipairs(options) do
            local btn = Instance.new("TextButton", listFrame)
            btn.Size = UDim2.new(1, 0, 0, 26)
            btn.BackgroundColor3 = Theme.SurfaceLight
            btn.Text = opt
            btn.TextColor3 = Theme.Text
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 12
            btn.AutoButtonColor = false
            btn.BorderSizePixel = 0
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
            btn.MouseButton1Click:Connect(function()
                selectedOption = opt
                dropdownBtn.Text = opt
                if callback then callback(opt) end
                isOpen = false
                listFrame.Visible = false
                listFrame.Size = UDim2.new(0.5, -10, 0, 0)
            end)
        end
        listFrame.Size = UDim2.new(0.5, -10, 0, #options * 28 + 4)
    end
    updateList()

    dropdownBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        listFrame.Visible = isOpen
        if isOpen then
            listFrame.Size = UDim2.new(0.5, -10, 0, #options * 28 + 4)
        else
            listFrame.Size = UDim2.new(0.5, -10, 0, 0)
        end
    end)

    return {
        SetOption = function(opt)
            if table.find(options, opt) then
                selectedOption = opt
                dropdownBtn.Text = opt
                if callback then callback(opt) end
            end
        end,
        GetOption = function() return selectedOption end,
    }
end

-- Função para criar um color picker simplificado (tamanho reduzido)
local function createColorPicker(parent, labelText, initialColor, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Theme.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left

    local colorBtn = Instance.new("TextButton", frame)
    colorBtn.Size = UDim2.new(0, 32, 0, 24)
    colorBtn.Position = UDim2.new(1, -40, 0.5, -12)
    colorBtn.BackgroundColor3 = initialColor
    colorBtn.AutoButtonColor = false
    colorBtn.BorderSizePixel = 0
    Instance.new("UICorner", colorBtn).CornerRadius = UDim.new(0, 4)

    local currentColor = initialColor
    colorBtn.MouseButton1Click:Connect(function()
        local colors = {
            Color3.fromRGB(255,0,0),
            Color3.fromRGB(0,255,0),
            Color3.fromRGB(0,0,255),
            Color3.fromRGB(255,255,0),
            Color3.fromRGB(255,0,255),
            Color3.fromRGB(0,255,255),
            Color3.fromRGB(255,255,255),
            Color3.fromRGB(0,0,0),
        }
        local palette = Instance.new("Frame", ScreenGui)
        palette.Size = UDim2.new(0, 160, 0, 40)
        palette.Position = UDim2.new(0.5, -80, 0.5, -20)
        palette.BackgroundColor3 = Theme.Surface
        palette.ZIndex = 20
        Instance.new("UICorner", palette).CornerRadius = UDim.new(0, 6)

        local layout = Instance.new("UIListLayout", palette)
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.Padding = UDim.new(0, 3)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.VerticalAlignment = Enum.VerticalAlignment.Center

        for _, col in ipairs(colors) do
            local btn = Instance.new("TextButton", palette)
            btn.Size = UDim2.new(0, 24, 0, 24)
            btn.BackgroundColor3 = col
            btn.AutoButtonColor = false
            btn.BorderSizePixel = 0
            Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
            btn.MouseButton1Click:Connect(function()
                currentColor = col
                colorBtn.BackgroundColor3 = col
                if callback then callback(col) end
                palette:Destroy()
            end)
        end

        local function closePalette(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                palette:Destroy()
            end
        end
        UserInputService.InputBegan:Connect(closePalette)
    end)

    return {
        SetColor = function(col)
            currentColor = col
            colorBtn.BackgroundColor3 = col
            if callback then callback(col) end
        end,
        GetColor = function() return currentColor end,
    }
end

-- ============================================================
-- 9. ESTRUTURA DO MENU PRINCIPAL (TAMANHO REDUZIDO)
-- ============================================================
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -290)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.ClipsDescendants = true
MainFrame.Visible = false
MainFrame.ZIndex = 5
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local shadow = Instance.new("UIStroke", MainFrame)
shadow.Thickness = 6
shadow.Color = Color3.fromRGB(0,0,0)
shadow.Transparency = 0.6

-- Top bar
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Theme.Surface
TopBar.BorderSizePixel = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)

-- Título
local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(0.8, 0, 1, 0)
Title.Position = UDim2.new(0, 8, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "👑 WARCORE v2.1"
Title.TextColor3 = Theme.Primary
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Botão fechar
local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -38, 0.5, -16)
CloseBtn.BackgroundColor3 = Theme.Danger
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.AutoButtonColor = false
CloseBtn.BorderSizePixel = 0
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)
CloseBtn.MouseButton1Click:Connect(function()
    ToggleMenu(false)
end)

-- Container para tabs e conteúdo
local TabContainer = Instance.new("Frame", MainFrame)
TabContainer.Size = UDim2.new(1, 0, 1, -40)
TabContainer.Position = UDim2.new(0, 0, 0, 40)
TabContainer.BackgroundTransparency = 1

-- Abas (buttons)
local TabButtons = Instance.new("Frame", TabContainer)
TabButtons.Size = UDim2.new(0, 100, 1, 0)
TabButtons.BackgroundTransparency = 1

local TabList = Instance.new("UIListLayout", TabButtons)
TabList.Padding = UDim.new(0, 4)
TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- Conteúdo
local ContentFrame = Instance.new("ScrollingFrame", TabContainer)
ContentFrame.Size = UDim2.new(1, -110, 1, 0)
ContentFrame.Position = UDim2.new(0, 105, 0, 0)
ContentFrame.BackgroundColor3 = Theme.Surface
ContentFrame.BorderSizePixel = 0
ContentFrame.ScrollBarThickness = 3
ContentFrame.ScrollBarImageColor3 = Theme.Primary
Instance.new("UICorner", ContentFrame).CornerRadius = UDim.new(0, 6)

local ContentList = Instance.new("UIListLayout", ContentFrame)
ContentList.Padding = UDim.new(0, 6)
ContentList.SortOrder = Enum.SortOrder.LayoutOrder

-- Estado do menu
local menuOpen = false
local currentTab = "Combate"
local tabObjects = {}

-- Função para alternar o menu
function ToggleMenu(open)
    menuOpen = open
    MainFrame.Visible = true
    if open then
        MainFrame.Size = UDim2.new(0, 500, 0, 580) -- menor
        MainFrame.BackgroundTransparency = 0
        TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 500, 0, 580)
        }):Play()
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()
        task.wait(0.2)
        MainFrame.Visible = false
    end
end

-- Botão flutuante para abrir/fechar
local FloatingBtn = Instance.new("TextButton", ScreenGui)
FloatingBtn.Size = UDim2.new(0, 52, 0, 52)
FloatingBtn.Position = UDim2.new(0.9, -60, 0.9, -60)
FloatingBtn.BackgroundColor3 = Theme.Background
FloatingBtn.Text = "⚡"
FloatingBtn.TextColor3 = Theme.Primary
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.TextSize = 24
FloatingBtn.AutoButtonColor = false
FloatingBtn.BorderSizePixel = 0
FloatingBtn.ZIndex = 10
Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(1, 0)
local floatStroke = Instance.new("UIStroke", FloatingBtn)
floatStroke.Thickness = 2
floatStroke.Color = Theme.Primary
floatStroke.Transparency = 0.5

FloatingBtn.MouseButton1Click:Connect(function()
    ToggleMenu(not menuOpen)
end)

-- Draggable na TopBar
local dragData = {dragging = false, startPos = nil, frameStart = nil}
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragData.dragging = true
        dragData.startPos = input.Position
        dragData.frameStart = MainFrame.Position
    end
end)
TopBar.InputChanged:Connect(function(input)
    if dragData.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragData.startPos
        MainFrame.Position = UDim2.new(dragData.frameStart.X.Scale, dragData.frameStart.X.Offset + delta.X, dragData.frameStart.Y.Scale, dragData.frameStart.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragData.dragging = false
    end
end)

-- Criar uma aba
function CreateTab(name, icon)
    local btn = Instance.new("TextButton", TabButtons)
    btn.Size = UDim2.new(0, 85, 0, 34)
    btn.BackgroundColor3 = Theme.SurfaceLight
    btn.Text = icon .. " " .. name
    btn.TextColor3 = Theme.TextMuted
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.ZIndex = 2
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local content = Instance.new("Frame", ContentFrame)
    content.Size = UDim2.new(1, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.LayoutOrder = #tabObjects + 1

    local contentLayout = Instance.new("UIListLayout", content)
    contentLayout.Padding = UDim.new(0, 6)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder

    tabObjects[name] = {
        Button = btn,
        Content = content,
        Layout = contentLayout,
    }

    btn.MouseButton1Click:Connect(function()
        SwitchTab(name)
    end)

    return content
end

function SwitchTab(name)
    currentTab = name
    for tabName, data in pairs(tabObjects) do
        local isActive = (tabName == name)
        data.Button.BackgroundColor3 = isActive and Theme.Primary or Theme.SurfaceLight
        data.Button.TextColor3 = isActive and Color3.fromRGB(0,0,0) or Theme.TextMuted
        data.Content.Visible = isActive
    end
    local activeContent = tabObjects[name].Content
    local layout = tabObjects[name].Layout
    local totalHeight = 0
    for _, child in ipairs(activeContent:GetChildren()) do
        if child:IsA("Frame") then
            totalHeight = totalHeight + child.Size.Y.Offset + layout.Padding.Offset
        end
    end
    activeContent.Size = UDim2.new(1, 0, 0, totalHeight)
    ContentFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
end

-- Inicializar abas
local CombatTab = CreateTab("Combate", "🔫")
local VisualTab = CreateTab("Visual", "👁️")
local RxTab = CreateTab("RX", "🛸")
local LightTab = CreateTab("Luz", "💡")
local MoveTab = CreateTab("Mov", "🧱")
local TeleportTab = CreateTab("TP", "📍")
local MonitorTab = CreateTab("Monitor", "📊")
local ExtraTab = CreateTab("Extras", "⚡")

SwitchTab("Combate")

-- ============================================================
-- 10. PREENCHIMENTO DAS ABAS (COM NOVAS FUNÇÕES)
-- ============================================================
local function AddSection(parent, title)
    local section = Instance.new("Frame", parent)
    section.Size = UDim2.new(1, 0, 0, 24)
    section.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", section)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Theme.Primary
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    return section
end

-- Combate
AddSection(CombatTab, "Aim Assist")
createToggle(CombatTab, "Mira Assistida", Config.Settings.AimAssist, function(v) Config.Settings.AimAssist = v end)
createToggle(CombatTab, "Silent Aim", Config.Settings.SilentAim, function(v) Config.Settings.SilentAim = v end)
createSlider(CombatTab, "Suavidade", 0.1, 1, 0.05, Config.Settings.Smoothness, function(v) Config.Settings.Smoothness = v end)
createSlider(CombatTab, "Raio FOV", 100, 1000, 10, Config.Settings.FovRadius, function(v) Config.Settings.FovRadius = v end)
createToggle(CombatTab, "Círculo FOV", Config.Settings.FovCircle, function(v) Config.Settings.FovCircle = v end)

AddSection(CombatTab, "Automáticos")
createToggle(CombatTab, "Trigger Bot", Config.Settings.TriggerBot, function(v) Config.Settings.TriggerBot = v end)
createSlider(CombatTab, "Delay Trigger", 0.05, 0.5, 0.05, Config.Settings.TriggerDelay, function(v) Config.Settings.TriggerDelay = v end)
createToggle(CombatTab, "Auto Click", Config.Settings.AutoClick, function(v) Config.Settings.AutoClick = v end)
createSlider(CombatTab, "Delay Click", 0.05, 0.5, 0.05, Config.Settings.AutoClickDelay, function(v) Config.Settings.AutoClickDelay = v end)

-- Visual
AddSection(VisualTab, "ESP")
createToggle(VisualTab, "Raio-X (Highlight)", Config.Settings.HighlightEnabled, function(v) Config.Settings.HighlightEnabled = v end)
createToggle(VisualTab, "Ponto na Cabeça", Config.Settings.DotEnabled, function(v) Config.Settings.DotEnabled = v end)
createToggle(VisualTab, "Linha de Mira", Config.Settings.LineEnabled, function(v) Config.Settings.LineEnabled = v end)
createToggle(VisualTab, "Micro-HUD Vida", Config.Settings.MicroHpEnabled, function(v) Config.Settings.MicroHpEnabled = v end)
createToggle(VisualTab, "Micro-HUD Dist", Config.Settings.MicroDistEnabled, function(v) Config.Settings.MicroDistEnabled = v end)

AddSection(VisualTab, "Ajustes")
createSlider(VisualTab, "Tamanho Texto", 6, 24, 1, Config.Settings.MicroTextSize, function(v) Config.Settings.MicroTextSize = v end)
createSlider(VisualTab, "Largura Barra", 20, 100, 5, Config.Settings.MicroWidth, function(v) Config.Settings.MicroWidth = v end)

-- Opções RX
AddSection(RxTab, "Configurações")
local depthDropdown = createDropdown(RxTab, "Modo Visibilidade", {"Ver através", "Ocultar atrás"}, "Ver através", function(opt)
    Config.Settings.HlDepthMode = (opt == "Ver através") and "AlwaysOnTop" or "Occluded"
end)
createSlider(RxTab, "Transparência Fill", 0, 1, 0.05, Config.Settings.HlFillTransparency, function(v) Config.Settings.HlFillTransparency = v end)
createColorPicker(RxTab, "Cor do Contorno", Config.Settings.HlEnemyColor, function(v) Config.Settings.HlEnemyColor = v end)

AddSection(RxTab, "Mira")
createColorPicker(RxTab, "Cor da Linha", Config.Settings.LineColor, function(v) Config.Settings.LineColor = v end)
createSlider(RxTab, "Espessura Linha", 0.5, 5, 0.5, Config.Settings.LineThickness, function(v) Config.Settings.LineThickness = v end)
createColorPicker(RxTab, "Cor Distância", Config.Settings.DistColor, function(v) Config.Settings.DistColor = v end)
local shapeDropdown = createDropdown(RxTab, "Forma do Ponto", {"Círculo ●", "Triângulo ▲", "Quadrado ■", "Losango ◆", "Estrela ★"}, "Círculo ●", function(opt)
    local shapes = {["Círculo ●"] = "●", ["Triângulo ▲"] = "▲", ["Quadrado ■"] = "■", ["Losango ◆"] = "◆", ["Estrela ★"] = "★"}
    Config.Settings.DotShape = shapes[opt] or "●"
end)

-- Iluminação
createToggle(LightTab, "FullBright", Config.Settings.FullBright, function(v)
    Config.Settings.FullBright = v
    UpdateLighting()
end)
createToggle(LightTab, "Clareza Técnica", Config.Settings.ClarezaMod, function(v)
    Config.Settings.ClarezaMod = v
    UpdateLighting()
end)
createToggle(LightTab, "Remover Sombras", Config.Settings.NoShadows, function(v)
    Config.Settings.NoShadows = v
    Lighting.GlobalShadows = not v
end)
createToggle(LightTab, "Remover Neblina", Config.Settings.NoFog, function(v)
    Config.Settings.NoFog = v
    Visual.UpdateNoFog()
end)
createToggle(LightTab, "FOV Changer", Config.Settings.FovChanger, function(v)
    Config.Settings.FovChanger = v
    Visual.UpdateFov()
end)
createSlider(LightTab, "Valor FOV", 1, 120, 1, Config.Settings.FovValue, function(v)
    Config.Settings.FovValue = v
    if Config.Settings.FovChanger then Visual.UpdateFov() end
end)

-- Movimento
AddSection(MoveTab, "Fly")
createToggle(MoveTab, "Ativar Fly", Config.Settings.FlyEnabled, function(v)
    Config.Settings.FlyEnabled = v
    if v then Movement.StartFly() else Movement.StopFly() end
end)
createToggle(MoveTab, "Modo Infinito", Config.Settings.FlyInfinite, function(v) Config.Settings.FlyInfinite = v end)
createSlider(MoveTab, "Velocidade Fly", 1, 500, 1, Config.Settings.FlySpeed, function(v) Config.Settings.FlySpeed = v end)

AddSection(MoveTab, "No-Clip")
createToggle(MoveTab, "Ativar No-Clip", Config.Settings.NoClip, function(v) Movement.ToggleNoClip(v) end)

AddSection(MoveTab, "Speed")
createToggle(MoveTab, "Speed Hack", Config.Settings.SpeedEnabled, function(v)
    Config.Settings.SpeedEnabled = v
    local hum = GetHumanoid(GetCharacter())
    if hum then hum.WalkSpeed = v and Config.Settings.SpeedValue or Original.WalkSpeed end
end)
createSlider(MoveTab, "Velocidade", 16, 200, 1, Config.Settings.SpeedValue, function(v)
    Config.Settings.SpeedValue = v
    if Config.Settings.SpeedEnabled then
        local hum = GetHumanoid(GetCharacter())
        if hum then hum.WalkSpeed = v end
    end
end)

AddSection(MoveTab, "Pulo")
createToggle(MoveTab, "Super Pulo", Config.Settings.JumpEnabled, function(v)
    Config.Settings.JumpEnabled = v
    local hum = GetHumanoid(GetCharacter())
    if hum then hum.JumpPower = v and Config.Settings.JumpPower or Original.JumpPower end
end)
createSlider(MoveTab, "Altura Pulo", 50, 300, 5, Config.Settings.JumpPower, function(v)
    Config.Settings.JumpPower = v
    if Config.Settings.JumpEnabled then
        local hum = GetHumanoid(GetCharacter())
        if hum then hum.JumpPower = v end
    end
end)
createToggle(MoveTab, "Pulo Infinito", Config.Settings.InfiniteJump, function(v) Config.Settings.InfiniteJump = v end)

AddSection(MoveTab, "Extras")
createToggle(MoveTab, "Anti-AFK", Config.Settings.AntiAFK, function(v) Movement.ToggleAntiAFK(v) end)
createToggle(MoveTab, "Sem Dano Queda", Config.Settings.NoFallDamage, function(v) Config.Settings.NoFallDamage = v end)

-- Teleporte
AddSection(TeleportTab, "Salvar Local")
local saveBtn = createStyledButton(TeleportTab, "💾 Salvar Atual", UDim2.new(1, 0, 0, 32), Theme.Success, Color3.fromRGB(0,0,0), function()
    local char = GetCharacter()
    if not char or not GetRootPart(char) then return end
    local pos = GetRootPart(char).Position
    local name = "Local " .. (#Teleport.Locations + 1)
    table.insert(Teleport.Locations, {name = name, x = pos.X, y = pos.Y, z = pos.Z})
    RefreshTeleportList()
end)

AddSection(TeleportTab, "Locais")
local teleportList = Instance.new("ScrollingFrame", TeleportTab)
teleportList.Size = UDim2.new(1, 0, 0, 160)
teleportList.BackgroundColor3 = Theme.SurfaceLight
teleportList.BorderSizePixel = 0
teleportList.ScrollBarThickness = 3
teleportList.ScrollBarImageColor3 = Theme.Primary
Instance.new("UICorner", teleportList).CornerRadius = UDim.new(0, 6)

local teleportLayout = Instance.new("UIListLayout", teleportList)
teleportLayout.Padding = UDim.new(0, 3)

function RefreshTeleportList()
    for _, child in ipairs(teleportList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for _, loc in ipairs(Teleport.FixedLocations) do
        local btn = createStyledButton(teleportList, loc.name .. " (fixo)", UDim2.new(1, 0, 0, 26), Theme.Warning, Color3.fromRGB(0,0,0), function()
            local root = GetRootPart(GetCharacter())
            if root then root.CFrame = CFrame.new(loc.x, loc.y, loc.z) end
        end)
    end

    for i, loc in ipairs(Teleport.Locations) do
        local frame = Instance.new("Frame", teleportList)
        frame.Size = UDim2.new(1, 0, 0, 26)
        frame.BackgroundTransparency = 1

        local btn = createStyledButton(frame, loc.name, UDim2.new(1, -40, 1, 0), Theme.SurfaceLight, Theme.Text, function()
            local root = GetRootPart(GetCharacter())
            if root then root.CFrame = CFrame.new(loc.x, loc.y, loc.z) end
        end)

        local delBtn = Instance.new("TextButton", frame)
        delBtn.Size = UDim2.new(0, 32, 0, 26)
        delBtn.Position = UDim2.new(1, -32, 0, 0)
        delBtn.BackgroundColor3 = Theme.Danger
        delBtn.Text = "✕"
        delBtn.TextColor3 = Color3.fromRGB(255,255,255)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 14
        delBtn.AutoButtonColor = false
        delBtn.BorderSizePixel = 0
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 4)
        delBtn.MouseButton1Click:Connect(function()
            table.remove(Teleport.Locations, i)
            RefreshTeleportList()
        end)
    end

    local total = #Teleport.FixedLocations + #Teleport.Locations
    teleportList.CanvasSize = UDim2.new(0, 0, 0, total * 30 + 10)
end
RefreshTeleportList()

AddSection(TeleportTab, "Teleportar para Jogador")
local playerListFrame = Instance.new("ScrollingFrame", TeleportTab)
playerListFrame.Size = UDim2.new(1, 0, 0, 100)
playerListFrame.BackgroundColor3 = Theme.SurfaceLight
playerListFrame.BorderSizePixel = 0
playerListFrame.ScrollBarThickness = 3
playerListFrame.ScrollBarImageColor3 = Theme.Primary
Instance.new("UICorner", playerListFrame).CornerRadius = UDim.new(0, 6)

local playerListLayout = Instance.new("UIListLayout", playerListFrame)
playerListLayout.Padding = UDim.new(0, 3)

function RefreshPlayerList()
    for _, child in ipairs(playerListFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            local btn = createStyledButton(playerListFrame, p.Name, UDim2.new(1, 0, 0, 26), Theme.SurfaceLight, Theme.Text, function()
                Teleport.TeleportToPlayer(p)
            end)
        end
    end
    local count = #Players:GetPlayers() - 1
    playerListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(count, 1) * 30 + 10)
end
RefreshPlayerList()
Players.PlayerAdded:Connect(RefreshPlayerList)
Players.PlayerRemoving:Connect(RefreshPlayerList)

-- Monitor
createToggle(MonitorTab, "Mostrar FPS", Config.Settings.ShowFPS, function(v)
    Config.Settings.ShowFPS = v
    fpsF.Visible = v
end)
createToggle(MonitorTab, "Contar Players", Config.Settings.ShowPlayers, function(v)
    Config.Settings.ShowPlayers = v
    countF.Visible = v
end)

-- Extras
AddSection(ExtraTab, "Utilitários")
createStyledButton(ExtraTab, "🔄 Rejoin", UDim2.new(1, 0, 0, 32), Theme.Primary, Color3.fromRGB(0,0,0), function()
    game:GetService("TeleportService"):Teleport(game.PlaceId)
end)
createStyledButton(ExtraTab, "💥 Explodir", UDim2.new(1, 0, 0, 32), Theme.Danger, Color3.fromRGB(255,255,255), function()
    local char = GetCharacter()
    if char and GetRootPart(char) then
        local exp = Instance.new("Explosion")
        exp.Position = GetRootPart(char).Position
        exp.Parent = workspace
        exp.ExplosionType = Enum.ExplosionType.NoCraters
        exp.BlastRadius = 10
        exp.BlastPressure = 50000
    end
end)
createStyledButton(ExtraTab, "🔫 Resetar Câmera", UDim2.new(1, 0, 0, 32), Theme.Warning, Color3.fromRGB(0,0,0), function()
    Camera.FieldOfView = Original.CameraFov
    Config.Settings.FovChanger = false
end)

-- ============================================================
-- 11. LOOP PRINCIPAL
-- ============================================================
local function OnRenderStep(dt)
    Combat.UpdateAim()
    Combat.TriggerBot()
    Combat.AutoClick()
    Combat.UpdateFovCircle()

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            Visual.UpdateHighlight(p)
            Visual.UpdateDot(p)
            Visual.UpdateMicroHUD(p)
        end
    end
    Visual.UpdateLines()

    if Config.Settings.NoFallDamage then
        local char = GetCharacter()
        if char then
            local root = GetRootPart(char)
            if root and root.Velocity.Y < -50 then
                root.Velocity = Vector3.new(root.Velocity.X, -10, root.Velocity.Z)
            end
        end
    end

    -- Atualiza NoFog e FOV continuamente (caso mudem)
    Visual.UpdateNoFog()
    Visual.UpdateFov()

    Monitor.Update(dt)
end

RunService.RenderStepped:Connect(OnRenderStep)

-- ============================================================
-- 12. EVENTOS DE JOGADOR
-- ============================================================
Player.CharacterAdded:Connect(function(char)
    task.wait(0.6)
    local hum = GetHumanoid(char)
    if hum then
        Original.WalkSpeed = hum.WalkSpeed
        Original.JumpPower = hum.JumpPower
    end

    if Config.Settings.NoClip then Movement.ToggleNoClip(true) end
    if Config.Settings.FlyEnabled then Movement.StartFly() end
    if Config.Settings.SpeedEnabled then hum.WalkSpeed = Config.Settings.SpeedValue end
    if Config.Settings.JumpEnabled then hum.JumpPower = Config.Settings.JumpPower end
end)

RunService.Heartbeat:Connect(function()
    local char = GetCharacter()
    if not char then return end
    local hum = GetHumanoid(char)
    if not hum then return end

    if Config.Settings.SpeedEnabled then
        if hum.WalkSpeed ~= Config.Settings.SpeedValue then hum.WalkSpeed = Config.Settings.SpeedValue end
    else
        if hum.WalkSpeed ~= Original.WalkSpeed then hum.WalkSpeed = Original.WalkSpeed end
    end

    if Config.Settings.JumpEnabled then
        if hum.JumpPower ~= Config.Settings.JumpPower then hum.JumpPower = Config.Settings.JumpPower end
    else
        if hum.JumpPower ~= Original.JumpPower then hum.JumpPower = Original.JumpPower end
    end

    if Config.Settings.InfiniteJump then
        if hum:GetState() == Enum.HumanoidStateType.Freefall and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ============================================================
-- 13. ILUMINAÇÃO
-- ============================================================
local function UpdateLighting()
    if Config.Settings.FullBright then
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.ClockTime = 14
    else
        Lighting.Ambient = Original.Ambient
        Lighting.OutdoorAmbient = Original.OutdoorAmbient
        Lighting.ClockTime = Original.ClockTime
    end

    if Config.Settings.ClarezaMod then
        Lighting.Brightness = 3
        Lighting.ExposureCompensation = 0.5
    else
        Lighting.Brightness = Original.Brightness
        Lighting.ExposureCompensation = Original.Exposure
    end

    Lighting.GlobalShadows = not Config.Settings.NoShadows
end

-- ============================================================
-- 14. INICIALIZAÇÃO
-- ============================================================
Visual.InitLines()
UpdateLighting()
Visual.UpdateNoFog()
Visual.UpdateFov()

-- Notificação inicial
local notify = Instance.new("TextLabel", ScreenGui)
notify.Size = UDim2.new(0, 260, 0, 40)
notify.Position = UDim2.new(0.5, -130, 0.1, 0)
notify.BackgroundColor3 = Theme.Surface
notify.Text = "👑 WARCORE v2.1 carregado!"
notify.TextColor3 = Theme.Primary
notify.Font = Enum.Font.GothamBold
notify.TextSize = 16
notify.ZIndex = 15
Instance.new("UICorner", notify).CornerRadius = UDim.new(0, 6)
TweenService:Create(notify, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -130, 0.15, 0)}):Play()
task.wait(2.5)
TweenService:Create(notify, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -130, -0.1, 0)}):Play()
task.wait(0.3)
notify:Destroy()

print("WARCORE v2.1 - UI Compacta + Novas Funções carregada!")