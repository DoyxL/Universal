local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Workspace = workspace
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ESP_UPDATE_INTERVAL = 0.08
local AIMBOT_UPDATE_INTERVAL = 0.03
local RAY_INTERVAL = 0.12
local espTick, aimTick, rayTick = 0, 0, 0
local cachedTargets = {}

local State = {
    AimbotEnabled = false,
    LockTeammates = true,
    DisableWallLock = true,
    AimbotFOV = 50,
    AimbotTargetPart = "Head",
    ShowFOV = true,
    ESP = {
        BoxESP = false,
        OutlineESP = false,
        NameESP = false,
        DistanceESP = false,
        ESPTeammates = false,
    },
}

local C = {
    accent = Color3.fromRGB(90, 200, 255),
    accentB = Color3.fromRGB(40, 140, 210),
    red = Color3.fromRGB(230, 70, 70),
    green = Color3.fromRGB(80, 210, 130),
    gold = Color3.fromRGB(255, 200, 80),
    white = Color3.fromRGB(255, 255, 255),
}

local OWNER_TAG = "kunani"
local BUILD_TAG = "v2.0.0"

local Window = WindUI:CreateWindow({
    Title = "Kunani Hub V2",
    Icon = "kanban",
    Author = "by " .. OWNER_TAG .. " Â· " .. BUILD_TAG,
    Folder = "KunaniHub",
    Size = UDim2.fromOffset(560, 420),
    Transparent = true,
    Theme = "Dark",
    User = {
        Enabled = true,
        Anonymous = true,
    },
})

local FOVCircle
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Color = C.accent
    FOVCircle.Thickness = 1.5
    FOVCircle.NumSides = 64
    FOVCircle.Filled = false
    FOVCircle.Visible = false
end)

local function isTeammate(p)
    return LocalPlayer.Team and p.Team == LocalPlayer.Team
end

local function isVisible(part)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = { LocalPlayer.Character }
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local r = Workspace:Raycast(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position), rp)
    return r and r.Instance:IsDescendantOf(part.Parent)
end

local function getESPColor(p)
    if #Teams:GetChildren() > 0 and p.TeamColor then
        return p.TeamColor.Color
    end
    return C.accent
end

local ESPCache = {}

local function createESP(player)
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Transparency = 1
    box.Visible = false
    box.Color = getESPColor(player)

    local outline = Drawing.new("Square")
    outline.Thickness = 3
    outline.Filled = false
    outline.Transparency = 1
    outline.Visible = false
    outline.Color = Color3.new(0, 0, 0)

    local name = Drawing.new("Text")
    name.Size = 14
    name.Center = true
    name.Outline = true
    name.OutlineColor = Color3.new(0, 0, 0)
    name.Visible = false
    name.Color = C.white

    local dist = Drawing.new("Text")
    dist.Size = 13
    dist.Center = true
    dist.Outline = true
    dist.OutlineColor = Color3.new(0, 0, 0)
    dist.Visible = false
    dist.Color = C.dim or C.white

    ESPCache[player] = { box = box, outline = outline, name = name, dist = dist }
end

local function removeESP(player)
    local c = ESPCache[player]
    if c then
        for _, d in pairs(c) do
            pcall(function() d:Remove() end)
        end
        ESPCache[player] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createESP(p) end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then createESP(p) end
end)

Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
end)

local function updateESP()
    local camPos = Camera.CFrame.Position
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local c = ESPCache[p]
        if not c then createESP(p) c = ESPCache[p] end

        local char = p.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        local show = char and hrp and hum and hum.Health > 0
        local skip = (not State.ESP.ESPTeammates and isTeammate(p))

        if not show or skip then
            c.box.Visible = false
            c.outline.Visible = false
            c.name.Visible = false
            c.dist.Visible = false
        else
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local scale = 1 / (pos.Z * math.tan(math.rad(Camera.FieldOfView * 0.5)) * 2) * 100
                local w, h = 3.2 * scale, 4.5 * scale
                local x, y = pos.X - w / 2, pos.Y - h / 2
                local col = getESPColor(p)

                c.box.Size = Vector2.new(w, h)
                c.box.Position = Vector2.new(x, y)
                c.box.Color = col
                c.box.Visible = State.ESP.BoxESP

                c.outline.Size = Vector2.new(w, h)
                c.outline.Position = Vector2.new(x, y)
                c.outline.Color = col
                c.outline.Visible = State.ESP.OutlineESP

                c.name.Text = p.Name
                c.name.Position = Vector2.new(pos.X, y - 16)
                c.name.Visible = State.ESP.NameESP

                c.dist.Text = string.format("[%d studs]", (camPos - hrp.Position).Magnitude)
                c.dist.Position = Vector2.new(pos.X, y + h + 2)
                c.dist.Visible = State.ESP.DistanceESP
            else
                c.box.Visible = false
                c.outline.Visible = false
                c.name.Visible = false
                c.dist.Visible = false
            end
        end
    end
end

local function getAimbotTarget()
    local closest, closestDist = nil, State.AimbotFOV
    local center = Camera.ViewportSize / 2
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not State.LockTeammates and isTeammate(p) then continue end
        local char = p.Character
        local part = char and char:FindFirstChild(State.AimbotTargetPart)
        if not part then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if State.DisableWallLock and not isVisible(part) then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < closestDist then
            closestDist = d
            closest = part
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function(dt)
    espTick = espTick + dt
    aimTick = aimTick + dt

    if FOVCircle then
        FOVCircle.Visible = State.ShowFOV and State.AimbotEnabled
        FOVCircle.Position = Camera.ViewportSize / 2
        FOVCircle.Radius = State.AimbotFOV
    end

    if espTick >= ESP_UPDATE_INTERVAL then
        espTick = 0
        pcall(updateESP)
    end

    if State.AimbotEnabled and aimTick >= AIMBOT_UPDATE_INTERVAL then
        aimTick = 0
        local target = getAimbotTarget()
        if target then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        end
    end
end)

local Tabs = {
    Aimbot = Window:Tab({ Title = "Aimbot", Icon = "crosshair" }),
    Visuals = Window:Tab({ Title = "Visuals", Icon = "eye" }),
    Settings = Window:Tab({ Title = "Settings", Icon = "settings" }),
}

Tabs.Aimbot:Toggle({
    Title = "Enable Aimbot",
    Desc = "Lock camera to nearest target",
    Value = false,
    Callback = function(v) State.AimbotEnabled = v end,
})

Tabs.Aimbot:Toggle({
    Title = "Lock Teammates",
    Desc = "Include teammates in target list",
    Value = true,
    Callback = function(v) State.LockTeammates = v end,
})

Tabs.Aimbot:Toggle({
    Title = "Wall Check",
    Desc = "Only target visible players",
    Value = true,
    Callback = function(v) State.DisableWallLock = v end,
})

Tabs.Aimbot:Slider({
    Title = "FOV",
    Desc = "Aimbot field of view radius",
    Value = { Min = 10, Max = 400, Default = 50 },
    Callback = function(v) State.AimbotFOV = v end,
})

Tabs.Aimbot:Dropdown({
    Title = "Target Part",
    Values = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
    Value = "Head",
    Callback = function(v) State.AimbotTargetPart = v end,
})

Tabs.Visuals:Toggle({
    Title = "Box ESP",
    Value = false,
    Callback = function(v) State.ESP.BoxESP = v end,
})

Tabs.Visuals:Toggle({
    Title = "Outline ESP",
    Value = false,
    Callback = function(v) State.ESP.OutlineESP = v end,
})

Tabs.Visuals:Toggle({
    Title = "Name ESP",
    Value = false,
    Callback = function(v) State.ESP.NameESP = v end,
})

Tabs.Visuals:Toggle({
    Title = "Distance ESP",
    Value = false,
    Callback = function(v) State.ESP.DistanceESP = v end,
})

Tabs.Visuals:Toggle({
    Title = "ESP Teammates",
    Value = false,
    Callback = function(v) State.ESP.ESPTeammates = v end,
})

Tabs.Settings:Toggle({
    Title = "Show FOV Circle",
    Value = true,
    Callback = function(v) State.ShowFOV = v end,
})

Tabs.Settings:Button({
    Title = "Unload",
    Desc = "Remove all drawings",
    Callback = function()
        for p, _ in pairs(ESPCache) do removeESP(p) end
        if FOVCircle then FOVCircle:Remove() end
        Window:Destroy()
    end,
})

Window:SelectTab(1)
