--[[
═══════════════════════════════════════════════════════════════════════════
🧟 ZOMBIE APOCALYPSE - SERVER SCRIPT 🧟
═══════════════════════════════════════════════════════════════════════════
 
✅ LOBBY APOCALÍPTICO
✅ SISTEMA DE MISIONES
✅ CARTEL DE ACTUALIZACIONES EDITABLE (solo admin: vegetl_)
✅ GUARDADO EN DATASTORE EN TIEMPO REAL
✅ TODOS LOS USUARIOS VEN LAS ACTUALIZACIONES

]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURACIÓN
-- ═══════════════════════════════════════════════════════════════════════════

local LOBBY_POS = Vector3.new(10000, 3000, 10000)
local GAME_SPAWN_POS = Vector3.new(0, 10, 0)
local MAX_LIVES = 3
local ROOM_SIZE = 160
local ROOM_HEIGHT = 40
local PAD_SIZE = 14

-- ADMINISTRADOR
local ADMIN_USERNAME = "vegetl_"

-- DataStores
local TimePlayedStore = DataStoreService:GetOrderedDataStore("ZombieTimePlayed_V1")
local PlayerDataStore = DataStoreService:GetDataStore("PlayerTimeData_V1")
local UpdatesDataStore = DataStoreService:GetDataStore("ZombieUpdates_V1")

-- Variables Globales
local PlayerStats = {}
local ActiveGames = {}
local CurrentUpdatesText = ""

-- ═══════════════════════════════════════════════════════════════════════════
-- COMUNICACIÓN CLIENTE-SERVIDOR
-- ═══════════════════════════════════════════════════════════════════════════

if ReplicatedStorage:FindFirstChild("LobbyEvents") then 
    ReplicatedStorage.LobbyEvents:Destroy() 
end

local RemoteFolder = Instance.new("Folder")
RemoteFolder.Name = "LobbyEvents"
RemoteFolder.Parent = ReplicatedStorage

local UpdateUIRemote = Instance.new("RemoteEvent", RemoteFolder)
UpdateUIRemote.Name = "UpdateUI"

local TeleportRemote = Instance.new("RemoteEvent", RemoteFolder)
TeleportRemote.Name = "TeleportEffect"

local ToggleExitBtn = Instance.new("RemoteEvent", RemoteFolder)
ToggleExitBtn.Name = "ToggleExitBtn"

local LeaveLobbyRemote = Instance.new("RemoteEvent", RemoteFolder)
LeaveLobbyRemote.Name = "LeaveLobby"

local HidePlayersRemote = Instance.new("RemoteEvent", RemoteFolder)
HidePlayersRemote.Name = "HidePlayers"

local CountdownSoundRemote = Instance.new("RemoteEvent", RemoteFolder)
CountdownSoundRemote.Name = "CountdownSound"

local UpdatesRemote = Instance.new("RemoteEvent", RemoteFolder)
UpdatesRemote.Name = "UpdatesRemote"

local Lobbies = {}
local MAX_PADS = 3
local NextGameGroupID = 1

-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCIONES DE ACTUALIZACIONES
-- ═══════════════════════════════════════════════════════════════════════════

local function LoadUpdates()
    local success, data = pcall(function()
        return UpdatesDataStore:GetAsync("CurrentUpdates")
    end)
    
    if success and data then
        CurrentUpdatesText = data
    else
        CurrentUpdatesText = "🧟 ACTUALIZACIONES DEL APOCALIPSIS\n\n• Sistema de supervivencia activado\n• Zonas de cuarentena disponibles\n• Nuevas armas desbloqueadas\n• Hordas de zombies mejoradas\n\n¡Sobrevive al apocalipsis!"
    end
end

local function SaveUpdates(text)
    pcall(function()
        UpdatesDataStore:SetAsync("CurrentUpdates", text)
        CurrentUpdatesText = text
    end)
end

local function UpdateAllPlayersUpdatesBoard()
    for _, player in pairs(Players:GetPlayers()) do
        UpdatesRemote:FireClient(player, "UpdateText", CurrentUpdatesText)
    end
end

LoadUpdates()

-- ═══════════════════════════════════════════════════════════════════════════
-- SISTEMA DE JUGADORES Y DATASTORES
-- ═══════════════════════════════════════════════════════════════════════════

local function LoadPlayerData(player)
    local success, data = pcall(function()
        return PlayerDataStore:GetAsync(player.UserId)
    end)
    
    if success and data then
        return data.TimePlayed or 0
    end
    return 0
end

local function SavePlayerData(player, timePlayed)
    pcall(function()
        PlayerDataStore:SetAsync(player.UserId, {TimePlayed = timePlayed})
        TimePlayedStore:SetAsync(player.UserId, timePlayed)
    end)
end

Players.PlayerAdded:Connect(function(player)
    local timePlayed = LoadPlayerData(player)
    
    local ls = Instance.new("Folder", player)
    ls.Name = "leaderstats"
    local timeValue = Instance.new("IntValue", ls)
    timeValue.Name = "Tiempo (min)"
    timeValue.Value = timePlayed
    
    PlayerStats[player.UserId] = {
        Lives = MAX_LIVES,
        InGame = false,
        GameGroup = nil,
        SessionStart = 0
    }
    
    task.wait(1)
    UpdatesRemote:FireClient(player, "UpdateText", CurrentUpdatesText)
    
    player.CharacterAdded:Connect(function(char)
        local stats = PlayerStats[player.UserId]
        task.wait(0.2)
        
        local root = char:WaitForChild("HumanoidRootPart")
        local hum = char:WaitForChild("Humanoid")
        
        if stats.InGame then
            local spawnLoc = workspace:FindFirstChild("SpawnLocation")
            local spawnPos = spawnLoc and spawnLoc.Position or GAME_SPAWN_POS
            root.CFrame = CFrame.new(spawnPos + Vector3.new(0, 5, 0) + Vector3.new(
                math.random(-10, 10), 
                0, 
                math.random(-10, 10)
            ))
        else
            root.CFrame = CFrame.new(LOBBY_POS + Vector3.new(0, 5, 40))
            ToggleExitBtn:FireClient(player, false)
        end
        
        hum.Died:Connect(function()
            if stats.InGame then
                stats.Lives = stats.Lives - 1
                
                if stats.Lives <= 0 then
                    if stats.SessionStart > 0 then
                        local timePlayedMinutes = math.floor((os.time() - stats.SessionStart) / 60)
                        local currentTime = player.leaderstats["Tiempo (min)"].Value
                        player.leaderstats["Tiempo (min)"].Value = currentTime + timePlayedMinutes
                        SavePlayerData(player, player.leaderstats["Tiempo (min)"].Value)
                    end
                    
                    stats.InGame = false
                    stats.Lives = MAX_LIVES
                    stats.GameGroup = nil
                    stats.SessionStart = 0
                    
                    HidePlayersRemote:FireClient(player, "ShowAll")
                end
            end
        end)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if PlayerStats[player.UserId] and PlayerStats[player.UserId].InGame and PlayerStats[player.UserId].SessionStart > 0 then
        local timePlayedMinutes = math.floor((os.time() - PlayerStats[player.UserId].SessionStart) / 60)
        local currentTime = player:FindFirstChild("leaderstats") and 
            player.leaderstats:FindFirstChild("Tiempo (min)") and 
            player.leaderstats["Tiempo (min)"].Value or 0
        SavePlayerData(player, currentTime + timePlayedMinutes)
    else
        local timePlayed = player:FindFirstChild("leaderstats") and 
            player.leaderstats:FindFirstChild("Tiempo (min)") and 
            player.leaderstats["Tiempo (min)"].Value or 0
        SavePlayerData(player, timePlayed)
    end
    
    PlayerStats[player.UserId] = nil
end)

task.spawn(function()
    while true do
        task.wait(60)
        for userId, stats in pairs(PlayerStats) do
            if stats.InGame and stats.SessionStart > 0 then
                local player = Players:GetPlayerByUserId(userId)
                if player and player:FindFirstChild("leaderstats") then
                    local timePlayedMinutes = math.floor((os.time() - stats.SessionStart) / 60)
                    if timePlayedMinutes > 0 then
                        player.leaderstats["Tiempo (min)"].Value = player.leaderstats["Tiempo (min)"].Value + timePlayedMinutes
                        stats.SessionStart = os.time()
                        SavePlayerData(player, player.leaderstats["Tiempo (min)"].Value)
                    end
                end
            end
        end
    end
end)

UpdatesRemote.OnServerEvent:Connect(function(player, action, newText)
    if player.Name ~= ADMIN_USERNAME then
        return
    end
    
    if action == "SaveUpdates" and newText then
        SaveUpdates(newText)
        UpdateAllPlayersUpdatesBoard()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- 🧟 CONSTRUCCIÓN DEL LABORATORIO ZOMBIE 🧟
-- ═══════════════════════════════════════════════════════════════════════════

local function BuildLab()
    if workspace:FindFirstChild("ZombieApocalypseLab") then 
        workspace.ZombieApocalypseLab:Destroy() 
    end
    
    local folder = Instance.new("Folder")
    folder.Name = "ZombieApocalypseLab"
    folder.Parent = workspace
    
    local function makePart(size, pos, color, name, material)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.Position = pos
        p.Anchored = true
        p.Color = color
        p.Material = material or Enum.Material.SmoothPlastic
        p.Parent = folder
        return p
    end
    
    -- ══════════════════════════════════════════════════════════════
    -- 🏢 SALA PRINCIPAL - ESTILO ZOMBIE CON MUCHOS EFECTOS
    -- ══════════════════════════════════════════════════════════════
    
    -- Suelo destruido
    local floor = makePart(
        Vector3.new(ROOM_SIZE, 1, ROOM_SIZE),
        LOBBY_POS,
        Color3.fromRGB(50, 45, 40),
        "Floor",
        Enum.Material.Asphalt
    )
    
    -- GRIETAS MASIVAS en el suelo (más realistas)
    for i = 1, 25 do
        local crack = Instance.new("Part", folder)
        crack.Size = Vector3.new(math.random(2, 8), 0.3, math.random(10, 40))
        crack.Position = LOBBY_POS + Vector3.new(
            math.random(-70, 70),
            0.65,
            math.random(-70, 70)
        )
        crack.CFrame = CFrame.new(crack.Position) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
        crack.Anchored = true
        crack.Material = Enum.Material.Cobblestone
        crack.Color = Color3.fromRGB(25, 20, 18)
        crack.CastShadow = true
    end
    
    -- MANCHAS DE SANGRE (muchas más y más realistas)
    for i = 1, 40 do
        local blood = Instance.new("Part", folder)
        blood.Size = Vector3.new(math.random(2, 8), 0.05, math.random(2, 8))
        blood.Position = LOBBY_POS + Vector3.new(
            math.random(-75, 75),
            0.55,
            math.random(-75, 75)
        )
        blood.Anchored = true
        blood.Material = Enum.Material.SmoothPlastic
        blood.Color = Color3.fromRGB(90, 10, 10)
        blood.Transparency = 0.2
        
        -- Textura de sangre
        local decal = Instance.new("Decal", blood)
        decal.Face = Enum.NormalId.Top
        decal.Texture = "rbxasset://textures/particles/smoke_main.dds"
        decal.Color3 = Color3.fromRGB(100, 0, 0)
    end
    
    -- ══════════════════════════════════════════════════════════════
    -- 🛢️ BARRILES Y CAJAS POR TODAS PARTES
    -- ══════════════════════════════════════════════════════════════
    
    local function createBarrel(position, color, hasSymbol)
        local barrel = Instance.new("Part", folder)
        barrel.Name = "Barrel"
        barrel.Size = Vector3.new(3, 4, 3)
        barrel.Position = position
        barrel.Anchored = true
        barrel.Material = Enum.Material.Metal
        barrel.Color = color
        barrel.Shape = Enum.PartType.Cylinder
        barrel.Orientation = Vector3.new(0, 0, 90)
        
        if hasSymbol then
            local billboard = Instance.new("BillboardGui", barrel)
            billboard.Size = UDim2.new(0, 100, 0, 100)
            billboard.StudsOffset = Vector3.new(0, 0, 1.5)
            
            local label = Instance.new("TextLabel", billboard)
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = "☣️"
            label.TextSize = 60
            label.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
        
        return barrel
    end
    
    -- Barriles amarillos de biohazard
    for i = 1, 12 do
        createBarrel(
            LOBBY_POS + Vector3.new(math.random(-70, 70), 2, math.random(-70, 70)),
            Color3.fromRGB(200, 180, 0),
            true
        )
    end
    
    -- Barriles verdes
    for i = 1, 8 do
        createBarrel(
            LOBBY_POS + Vector3.new(math.random(-70, 70), 2, math.random(-70, 70)),
            Color3.fromRGB(60, 90, 50),
            false
        )
    end
    
    -- CAJAS DE SUMINISTROS
    local function createCrate(position)
        local crate = Instance.new("Part", folder)
        crate.Name = "Crate"
        crate.Size = Vector3.new(5, 5, 5)
        crate.Position = position
        crate.Anchored = true
        crate.Material = Enum.Material.Wood
        crate.Color = Color3.fromRGB(80, 60, 40)
        
        -- Marcas en las cajas
        for face = 1, 6 do
            local decal = Instance.new("Decal", crate)
            decal.Face = Enum.NormalId[{"Front","Back","Left","Right","Top","Bottom"}[face]]
            decal.Texture = "rbxasset://textures/face.png"
            decal.Color3 = Color3.fromRGB(40, 30, 20)
        end
        
        return crate
    end
    
    -- Apilar cajas por el lobby
    for i = 1, 15 do
        createCrate(LOBBY_POS + Vector3.new(math.random(-75, 75), 2.5, math.random(-75, 75)))
    end
    
    -- ══════════════════════════════════════════════════════════════
    -- 🚧 VALLAS CON ALAMBRE DE PÚAS (como en la imagen)
    -- ══════════════════════════════════════════════════════════════
    
    local function createBarricade(startPos, endPos)
        local distance = (endPos - startPos).Magnitude
        local direction = (endPos - startPos).Unit
        local midpoint = (startPos + endPos) / 2
        
        -- Poste inicial
        local post1 = Instance.new("Part", folder)
        post1.Size = Vector3.new(0.5, 6, 0.5)
        post1.Position = startPos + Vector3.new(0, 3, 0)
        post1.Anchored = true
        post1.Material = Enum.Material.Metal
        post1.Color = Color3.fromRGB(60, 60, 60)
        
        -- Poste final
        local post2 = Instance.new("Part", folder)
        post2.Size = Vector3.new(0.5, 6, 0.5)
        post2.Position = endPos + Vector3.new(0, 3, 0)
        post2.Anchored = true
        post2.Material = Enum.Material.Metal
        post2.Color = Color3.fromRGB(60, 60, 60)
        
        -- Vallas horizontales (5 niveles)
        for level = 1, 5 do
            local fence = Instance.new("Part", folder)
            fence.Size = Vector3.new(distance, 0.3, 0.3)
            fence.Position = midpoint + Vector3.new(0, level * 1.2 - 0.5, 0)
            fence.CFrame = CFrame.new(fence.Position, fence.Position + direction)
            fence.Anchored = true
            fence.Material = Enum.Material.DiamondPlate
            fence.Color = Color3.fromRGB(80, 80, 80)
        end
        
        -- Alambre de púas en la parte superior
        for i = 0, 4 do
            local wire = Instance.new("Part", folder)
            wire.Size = Vector3.new(distance, 0.15, 0.15)
            wire.Position = midpoint + Vector3.new(0, 6.5 + (i * 0.25), 0)
            wire.CFrame = CFrame.new(wire.Position, wire.Position + direction) * CFrame.Angles(0, 0, math.rad(i * 15))
            wire.Anchored = true
            wire.Material = Enum.Material.Metal
            wire.Color = Color3.fromRGB(100, 100, 100)
        end
        
        -- Cartel "QUARANTINE ZONE"
        if math.random(1, 3) == 1 then
            local sign = Instance.new("Part", folder)
            sign.Size = Vector3.new(0.2, 3, 4)
            sign.Position = midpoint + Vector3.new(0, 3, 0)
            sign.CFrame = CFrame.new(sign.Position, sign.Position + direction) * CFrame.Angles(0, math.rad(90), 0)
            sign.Anchored = true
            sign.Material = Enum.Material.Metal
            sign.Color = Color3.fromRGB(200, 180, 0)
            
            local signGui = Instance.new("SurfaceGui", sign)
            signGui.Face = Enum.NormalId.Front
            
            local bg = Instance.new("Frame", signGui)
            bg.Size = UDim2.new(1, 0, 1, 0)
            bg.BackgroundColor3 = Color3.fromRGB(200, 180, 0)
            bg.BorderSizePixel = 3
            bg.BorderColor3 = Color3.fromRGB(0, 0, 0)
            
            -- Franjas negras
            for j = 1, 2 do
                local stripe = Instance.new("Frame", bg)
                stripe.Size = UDim2.new(1.2, 0, 0.15, 0)
                stripe.Position = UDim2.new(-0.1, 0, j * 0.35 - 0.15, 0)
                stripe.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                stripe.BorderSizePixel = 0
                stripe.Rotation = -10
            end
            
            local text = Instance.new("TextLabel", bg)
            text.Size = UDim2.new(0.9, 0, 0.5, 0)
            text.Position = UDim2.new(0.05, 0, 0.25, 0)
            text.BackgroundTransparency = 1
            text.Text = "⚠️\nQUARANTINE\nZONE"
            text.TextColor3 = Color3.fromRGB(0, 0, 0)
            text.Font = Enum.Font.GothamBlack
            text.TextSize = 24
            text.TextWrapped = true
        end
    end
    
    -- Crear vallas alrededor del perímetro
    local corners = {
        Vector3.new(-ROOM_SIZE/2 + 5, 0, -ROOM_SIZE/2 + 5),
        Vector3.new(ROOM_SIZE/2 - 5, 0, -ROOM_SIZE/2 + 5),
        Vector3.new(ROOM_SIZE/2 - 5, 0, ROOM_SIZE/2 - 5),
        Vector3.new(-ROOM_SIZE/2 + 5, 0, ROOM_SIZE/2 - 5)
    }
    
    for i = 1, 4 do
        local start = LOBBY_POS + corners[i]
        local endPos = LOBBY_POS + corners[(i % 4) + 1]
        
        -- Dividir cada lado en segmentos
        local segments = 3
        for j = 0, segments - 1 do
            local t1 = j / segments
            local t2 = (j + 1) / segments
            local segStart = start:Lerp(endPos, t1)
            local segEnd = start:Lerp(endPos, t2)
            createBarricade(segStart, segEnd)
        end
    end
    
    -- ══════════════════════════════════════════════════════════════
    -- ☣️ SÍMBOLO BIOHAZARD GIGANTE EN EL SUELO
    -- ══════════════════════════════════════════════════════════════
    
    local biohazardBase = Instance.new("Part", folder)
    biohazardBase.Name = "BiohazardSymbol"
    biohazardBase.Size = Vector3.new(30, 0.1, 30)
    biohazardBase.Position = LOBBY_POS + Vector3.new(0, 0.6, 0)
    biohazardBase.Anchored = true
    biohazardBase.Material = Enum.Material.SmoothPlastic
    biohazardBase.Color = Color3.fromRGB(200, 180, 0)
    biohazardBase.Transparency = 0.2
    
    local biohazardGui = Instance.new("SurfaceGui", biohazardBase)
    biohazardGui.Face = Enum.NormalId.Top
    biohazardGui.CanvasSize = Vector2.new(500, 500)
    
    local biohazardLabel = Instance.new("TextLabel", biohazardGui)
    biohazardLabel.Size = UDim2.new(1, 0, 1, 0)
    biohazardLabel.BackgroundTransparency = 1
    biohazardLabel.Text = "☣️"
    biohazardLabel.TextSize = 400
    biohazardLabel.TextColor3 = Color3.fromRGB(200, 180, 0)
    biohazardLabel.TextStrokeTransparency = 0.5
    biohazardLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    
    -- ══════════════════════════════════════════════════════════════
    -- 💨 EFECTOS DE HUMO Y PARTÍCULAS
    -- ══════════════════════════════════════════════════════════════
    
    for i = 1, 8 do
        local smokeEmitter = Instance.new("Part", folder)
        smokeEmitter.Size = Vector3.new(1, 1, 1)
        smokeEmitter.Position = LOBBY_POS + Vector3.new(
            math.random(-70, 70),
            0.5,
            math.random(-70, 70)
        )
        smokeEmitter.Anchored = true
        smokeEmitter.Transparency = 1
        smokeEmitter.CanCollide = false
        
        local smoke = Instance.new("ParticleEmitter", smokeEmitter)
        smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
        smoke.Rate = 20
        smoke.Lifetime = NumberRange.new(5, 8)
        smoke.Speed = NumberRange.new(2, 5)
        smoke.SpreadAngle = Vector2.new(20, 20)
        smoke.Color = ColorSequence.new(Color3.fromRGB(80, 80, 80))
        smoke.Size = NumberSequence.new(4, 8)
        smoke.Transparency = NumberSequence.new(0.3, 1)
        smoke.LightEmission = 0.1
        smoke.VelocityInheritance = 0.5
    end
    
    -- Techo
    local ceiling = makePart(
        Vector3.new(ROOM_SIZE, 1, ROOM_SIZE),
        LOBBY_POS + Vector3.new(0, ROOM_HEIGHT, 0),
        Color3.fromRGB(40, 40, 45),
        "Ceiling",
        Enum.Material.Metal
    )
    
    -- ══════════════════════════════════════════════════════════════
    -- 🚨 SISTEMA DE LUCES DE EMERGENCIA INTENSO
    -- ══════════════════════════════════════════════════════════════
    
    local lightBars = {}
    
    -- Luces rojas del techo (más cantidad)
    for i = -3, 3 do
        for j = -2, 2 do
            local lightBar = Instance.new("Part")
            lightBar.Name = "EmergencyLight_" .. i .. "_" .. j
            lightBar.Size = Vector3.new(6, 0.8, 6)
            lightBar.Position = LOBBY_POS + Vector3.new(i * 20, ROOM_HEIGHT - 1, j * 20)
            lightBar.Anchored = true
            lightBar.Material = Enum.Material.Neon
            lightBar.Color = Color3.fromRGB(255, 0, 0)
            lightBar.Parent = folder
            
            local light = Instance.new("SpotLight", lightBar)
            light.Face = Enum.NormalId.Bottom
            light.Range = 60
            light.Brightness = 5
            light.Angle = 90
            light.Color = Color3.fromRGB(255, 50, 50)
            
            -- PointLight adicional para más brillo
            local pointLight = Instance.new("PointLight", lightBar)
            pointLight.Range = 50
            pointLight.Brightness = 3
            pointLight.Color = Color3.fromRGB(255, 50, 50)
            
            table.insert(lightBars, {Part = lightBar, Spot = light, Point = pointLight})
        end
    end
    
    -- Luces de pared adicionales
    local wallPositions = {
        {pos = Vector3.new(-ROOM_SIZE/2 + 2, ROOM_HEIGHT/2, 0), dir = Vector3.new(1, 0, 0)},
        {pos = Vector3.new(ROOM_SIZE/2 - 2, ROOM_HEIGHT/2, 0), dir = Vector3.new(-1, 0, 0)},
        {pos = Vector3.new(0, ROOM_HEIGHT/2, -ROOM_SIZE/2 + 2), dir = Vector3.new(0, 0, 1)},
        {pos = Vector3.new(0, ROOM_HEIGHT/2, ROOM_SIZE/2 - 2), dir = Vector3.new(0, 0, -1)}
    }
    
    for _, wallData in pairs(wallPositions) do
        for i = -2, 2 do
            local offset = i * 25
            local lightPos = LOBBY_POS + wallData.pos + Vector3.new(offset, 0, offset):Cross(wallData.dir)
            
            local wallLight = Instance.new("Part", folder)
            wallLight.Size = Vector3.new(3, 3, 0.5)
            wallLight.Position = lightPos
            wallLight.Anchored = true
            wallLight.Material = Enum.Material.Neon
            wallLight.Color = Color3.fromRGB(255, 0, 0)
            
            local spotlight = Instance.new("SpotLight", wallLight)
            spotlight.Face = Enum.NormalId.Front
            spotlight.Range = 40
            spotlight.Brightness = 4
            spotlight.Angle = 60
            spotlight.Color = Color3.fromRGB(255, 50, 50)
            
            table.insert(lightBars, {Part = wallLight, Spot = spotlight})
        end
    end
    
    -- Animación de parpadeo de emergencia (más dramática)
    task.spawn(function()
        while true do
            -- Encender todas
            for _, lightData in pairs(lightBars) do
                lightData.Part.Transparency = 0
                if lightData.Spot then lightData.Spot.Enabled = true end
                if lightData.Point then lightData.Point.Enabled = true end
            end
            task.wait(0.4)
            
            -- Apagar todas
            for _, lightData in pairs(lightBars) do
                lightData.Part.Transparency = 0.8
                if lightData.Spot then lightData.Spot.Enabled = false end
                if lightData.Point then lightData.Point.Enabled = false end
            end
            task.wait(0.1)
            
            -- Parpadeo rápido
            for _, lightData in pairs(lightBars) do
                lightData.Part.Transparency = 0
                if lightData.Spot then lightData.Spot.Enabled = true end
                if lightData.Point then lightData.Point.Enabled = true end
            end
            task.wait(0.15)
            
            for _, lightData in pairs(lightBars) do
                lightData.Part.Transparency = 0.8
                if lightData.Spot then lightData.Spot.Enabled = false end
                if lightData.Point then lightData.Point.Enabled = false end
            end
            task.wait(0.1)
            
            -- Encender de nuevo
            for _, lightData in pairs(lightBars) do
                lightData.Part.Transparency = 0
                if lightData.Spot then lightData.Spot.Enabled = true end
                if lightData.Point then lightData.Point.Enabled = true end
            end
            task.wait(1)
        end
    end)
    
    -- ══════════════════════════════════════════════════════════════
    -- 💥 EFECTOS DE CHISPAS Y ELECTRICIDAD
    -- ══════════════════════════════════════════════════════════════
    
    for i = 1, 6 do
        local sparkEmitter = Instance.new("Part", folder)
        sparkEmitter.Size = Vector3.new(0.5, 0.5, 0.5)
        sparkEmitter.Position = LOBBY_POS + Vector3.new(
            math.random(-75, 75),
            math.random(5, ROOM_HEIGHT - 2),
            math.random(-75, 75)
        )
        sparkEmitter.Anchored = true
        sparkEmitter.Transparency = 1
        sparkEmitter.CanCollide = false
        
        local sparks = Instance.new("ParticleEmitter", sparkEmitter)
        sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        sparks.Rate = 5
        sparks.Lifetime = NumberRange.new(0.5, 1)
        sparks.Speed = NumberRange.new(5, 10)
        sparks.SpreadAngle = Vector2.new(30, 30)
        sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 0))
        sparks.Size = NumberSequence.new(0.3, 0)
        sparks.Transparency = NumberSequence.new(0, 1)
        sparks.LightEmission = 1
        sparks.EmissionDirection = Enum.NormalId.Bottom
    end
    
    -- Función para crear paredes con azulejos y daño
    local function createTiledWall(size, position, name, color)
        local wall = makePart(size, position, color or Color3.fromRGB(80, 75, 70), name, Enum.Material.Concrete)
        
        local tileSize = 4
        local tilesX = math.floor(size.X / tileSize)
        local tilesY = math.floor(size.Y / tileSize)
        
        -- Líneas verticales
        for i = 0, tilesX do
            local line = Instance.new("Part", folder)
            line.Size = Vector3.new(0.1, size.Y, size.Z + 0.2)
            line.Position = position + Vector3.new((i * tileSize) - size.X/2, 0, 0)
            line.Anchored = true
            line.Color = Color3.fromRGB(50, 45, 40)
            line.Material = Enum.Material.SmoothPlastic
        end
        
        -- Líneas horizontales
        for j = 0, tilesY do
            local line = Instance.new("Part", folder)
            line.Size = Vector3.new(size.X + 0.2, 0.1, size.Z + 0.2)
            line.Position = position + Vector3.new(0, (j * tileSize) - size.Y/2, 0)
            line.Anchored = true
            line.Color = Color3.fromRGB(50, 45, 40)
            line.Material = Enum.Material.SmoothPlastic
        end
        
        -- Marcas de sangre en las paredes
        for k = 1, math.random(3, 6) do
            local bloodMark = Instance.new("Part", folder)
            bloodMark.Size = Vector3.new(math.random(2, 4), math.random(3, 6), 0.05)
            bloodMark.Position = position + Vector3.new(
                math.random(-size.X/2 + 5, size.X/2 - 5),
                math.random(-size.Y/2 + 5, size.Y/2 - 5),
                size.Z/2 + 0.1
            )
            bloodMark.Anchored = true
            bloodMark.Material = Enum.Material.SmoothPlastic
            bloodMark.Color = Color3.fromRGB(70, 10, 10)
            bloodMark.Transparency = 0.3
        end
        
        -- Agujeros de bala en las paredes
        for k = 1, math.random(8, 15) do
            local bulletHole = Instance.new("Part", folder)
            bulletHole.Size = Vector3.new(0.3, 0.3, 0.05)
            bulletHole.Position = position + Vector3.new(
                math.random(-size.X/2 + 2, size.X/2 - 2),
                math.random(-size.Y/2 + 2, size.Y/2 - 2),
                size.Z/2 + 0.05
            )
            bulletHole.Anchored = true
            bulletHole.Material = Enum.Material.Concrete
            bulletHole.Color = Color3.fromRGB(20, 20, 20)
            bulletHole.Shape = Enum.PartType.Ball
        end
        
        return wall
    end
    
    -- PARED TRASERA con carteles
    local wallBack = createTiledWall(
        Vector3.new(ROOM_SIZE, ROOM_HEIGHT, 2),
        LOBBY_POS + Vector3.new(0, ROOM_HEIGHT/2, ROOM_SIZE/2 - 1),
        "WallBack"
    )
    
    -- Carteles en pared trasera
    for i = -2, 2 do
        local signPart = Instance.new("Part", folder)
        signPart.Size = Vector3.new(10, 8, 0.2)
        signPart.Position = LOBBY_POS + Vector3.new(i * 25, 15, ROOM_SIZE/2 - 2)
        signPart.Anchored = true
        signPart.Material = Enum.Material.Metal
        signPart.Color = Color3.fromRGB(200, 180, 0)
        
        local signGui = Instance.new("SurfaceGui", signPart)
        signGui.Face = Enum.NormalId.Front
        
        local signBg = Instance.new("Frame", signGui)
        signBg.Size = UDim2.new(1, 0, 1, 0)
        signBg.BackgroundColor3 = Color3.fromRGB(200, 180, 0)
        signBg.BorderSizePixel = 4
        signBg.BorderColor3 = Color3.fromRGB(0, 0, 0)
        
        local signText = Instance.new("TextLabel", signBg)
        signText.Size = UDim2.new(1, 0, 1, 0)
        signText.BackgroundTransparency = 1
        signText.TextColor3 = Color3.fromRGB(0, 0, 0)
        signText.Font = Enum.Font.GothamBlack
        signText.TextSize = 40
        signText.TextWrapped = true
        
        local warnings = {
            "⚠️\nZOMBIES\nAHEAD",
            "☣️\nBIOHAZARD\nZONE",
            "⚠️\nDANGER\nRUN!",
            "☠️\nQUARANTINE\nZONE",
            "⚠️\nNO ENTRY\nDEAD END"
        }
        signText.Text = warnings[math.random(1, #warnings)]
    end
    
    -- PARED FRONTAL
    createTiledWall(
        Vector3.new(ROOM_SIZE, ROOM_HEIGHT, 2),
        LOBBY_POS + Vector3.new(0, ROOM_HEIGHT/2, -ROOM_SIZE/2 + 1),
        "WallFront"
    )
    
    -- PARED IZQUIERDA
    createTiledWall(
        Vector3.new(2, ROOM_HEIGHT, ROOM_SIZE),
        LOBBY_POS + Vector3.new(-ROOM_SIZE/2 + 1, ROOM_HEIGHT/2, 0),
        "WallLeft"
    )
    
    -- PARED DERECHA
    createTiledWall(
        Vector3.new(2, ROOM_HEIGHT, ROOM_SIZE),
        LOBBY_POS + Vector3.new(ROOM_SIZE/2 - 1, ROOM_HEIGHT/2, 0),
        "WallRight"
    )
    
    -- ══════════════════════════════════════════════════════════════
    -- 🧟 TEXTO "ZOMBIE APOCALYPSE"
    -- ══════════════════════════════════════════════════════════════
    
    local textWallPart = Instance.new("Part")
    textWallPart.Name = "ZombieApocalypseText"
    textWallPart.Size = Vector3.new(0.5, 20, 80)
    textWallPart.Position = LOBBY_POS + Vector3.new(-ROOM_SIZE/2 + 1.5, 20, 0)
    textWallPart.CFrame = CFrame.new(textWallPart.Position) * CFrame.Angles(0, math.rad(90), 0)
    textWallPart.Anchored = true
    textWallPart.Material = Enum.Material.SmoothPlastic
    textWallPart.Transparency = 1
    textWallPart.Parent = folder
    
    local textGui = Instance.new("SurfaceGui", textWallPart)
    textGui.Face = Enum.NormalId.Front
    textGui.CanvasSize = Vector2.new(800, 200)
    
    local textLabel = Instance.new("TextLabel", textGui)
    textLabel.Text = "ZOMBIE\nAPOCALYPSE"
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(200, 0, 0)
    textLabel.Font = Enum.Font.Creepster
    textLabel.TextSize = 100
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    
    local glow = Instance.new("UIStroke", textLabel)
    glow.Color = Color3.fromRGB(255, 50, 50)
    glow.Thickness = 6
    glow.Transparency = 0.3
    
    task.spawn(function()
        while true do
            for i = 1, 3 do
                textLabel.TextTransparency = 0
                task.wait(0.5)
                textLabel.TextTransparency = 0.3
                task.wait(0.1)
            end
            task.wait(2)
        end
    end)
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- 📊 LEADERBOARD (SOBREVIVIENTES)
    -- ═══════════════════════════════════════════════════════════════════════
    
    local leaderboardPart = Instance.new("Part")
    leaderboardPart.Name = "LeaderboardPart"
    leaderboardPart.Size = Vector3.new(35, 25, 1)
    leaderboardPart.Position = LOBBY_POS + Vector3.new(ROOM_SIZE/2 - 3, 16, 0)
    leaderboardPart.CFrame = CFrame.new(leaderboardPart.Position) * CFrame.Angles(0, math.rad(90), 0)
    leaderboardPart.Anchored = true
    leaderboardPart.Material = Enum.Material.Metal
    leaderboardPart.Color = Color3.fromRGB(30, 30, 35)
    leaderboardPart.Parent = folder
    
    local surfaceGui = Instance.new("SurfaceGui", leaderboardPart)
    surfaceGui.Face = Enum.NormalId.Front
    surfaceGui.CanvasSize = Vector2.new(800, 600)
    
    local background = Instance.new("Frame", surfaceGui)
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = Color3.fromRGB(15, 10, 10)
    background.BorderSizePixel = 6
    background.BorderColor3 = Color3.fromRGB(200, 0, 0)
    
    local title = Instance.new("TextLabel", background)
    title.Text = "🏆 TOP SOBREVIVIENTES 🏆"
    title.Size = UDim2.new(1, 0, 0.15, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 50, 50)
    title.Font = Enum.Font.Creepster
    title.TextSize = 52
    title.TextStrokeTransparency = 0.5
    
    local listFrame = Instance.new("Frame", background)
    listFrame.Name = "ListFrame"
    listFrame.Size = UDim2.new(0.95, 0, 0.8, 0)
    listFrame.Position = UDim2.new(0.025, 0, 0.18, 0)
    listFrame.BackgroundTransparency = 1
    
    local listLayout = Instance.new("UIListLayout", listFrame)
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    task.spawn(function()
        while true do
            for _, child in pairs(listFrame:GetChildren()) do
                if child:IsA("Frame") then
                    child:Destroy()
                end
            end
            
            local success, pages = pcall(function()
                return TimePlayedStore:GetSortedAsync(false, 10)
            end)
            
            if success and pages then
                local data = pages:GetCurrentPage()
                
                for rank, entry in ipairs(data) do
                    local row = Instance.new("Frame", listFrame)
                    row.Size = UDim2.new(1, 0, 0, 55)
                    row.BackgroundTransparency = 1
                    row.LayoutOrder = rank
                    
                    local username = "Sobreviviente"
                    pcall(function()
                        username = Players:GetNameFromUserIdAsync(entry.key)
                    end)
                    
                    local medal = ""
                    if rank == 1 then medal = "🥇"
                    elseif rank == 2 then medal = "🥈"
                    elseif rank == 3 then medal = "🥉"
                    else medal = "#" .. rank
                    end
                    
                    local totalMinutes = entry.value
                    local hours = math.floor(totalMinutes / 60)
                    local minutes = totalMinutes % 60
                    local timeText = string.format("%dh %dm", hours, minutes)
                    
                    local label = Instance.new("TextLabel", row)
                    label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 1
                    label.Text = string.format("%s  %s  -  %s", medal, username, timeText)
                    label.TextColor3 = Color3.fromRGB(255, 255, 255)
                    label.Font = Enum.Font.Code
                    label.TextSize = 32
                    label.TextXAlignment = Enum.TextXAlignment.Left
                    label.TextStrokeTransparency = 0.7
                end
            end
            
            task.wait(20)
        end
    end)
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- 📋 CARTEL DE MISIONES ZOMBIE
    -- ═══════════════════════════════════════════════════════════════════════
    
    local updatesBoardPart = Instance.new("Part")
    updatesBoardPart.Name = "UpdatesBoardPart"
    updatesBoardPart.Size = Vector3.new(35, 25, 1)
    updatesBoardPart.Position = LOBBY_POS + Vector3.new(ROOM_SIZE/2 - 3, 16, -35)
    updatesBoardPart.CFrame = CFrame.new(updatesBoardPart.Position) * CFrame.Angles(0, math.rad(90), 0)
    updatesBoardPart.Anchored = true
    updatesBoardPart.Material = Enum.Material.Metal
    updatesBoardPart.Color = Color3.fromRGB(30, 30, 35)
    updatesBoardPart.Parent = folder
    
    local updatesSurfaceGui = Instance.new("SurfaceGui", updatesBoardPart)
    updatesSurfaceGui.Name = "UpdatesSurfaceGui"
    updatesSurfaceGui.Face = Enum.NormalId.Front
    updatesSurfaceGui.CanvasSize = Vector2.new(800, 600)
    
    local updatesBackground = Instance.new("Frame", updatesSurfaceGui)
    updatesBackground.Size = UDim2.new(1, 0, 1, 0)
    updatesBackground.BackgroundColor3 = Color3.fromRGB(15, 10, 10)
    updatesBackground.BorderSizePixel = 6
    updatesBackground.BorderColor3 = Color3.fromRGB(200, 150, 0)
    
    local updatesTitle = Instance.new("TextLabel", updatesBackground)
    updatesTitle.Text = "📋 MISIONES DEL APOCALIPSIS 📋"
    updatesTitle.Size = UDim2.new(1, 0, 0.15, 0)
    updatesTitle.BackgroundTransparency = 1
    updatesTitle.TextColor3 = Color3.fromRGB(255, 200, 0)
    updatesTitle.Font = Enum.Font.Creepster
    updatesTitle.TextSize = 48
    updatesTitle.TextStrokeTransparency = 0.5
    
    local updatesScrollFrame = Instance.new("ScrollingFrame", updatesBackground)
    updatesScrollFrame.Name = "UpdatesScrollFrame"
    updatesScrollFrame.Size = UDim2.new(0.95, 0, 0.8, 0)
    updatesScrollFrame.Position = UDim2.new(0.025, 0, 0.18, 0)
    updatesScrollFrame.BackgroundTransparency = 1
    updatesScrollFrame.ScrollBarThickness = 8
    updatesScrollFrame.BorderSizePixel = 0
    updatesScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    local updatesTextLabel = Instance.new("TextLabel", updatesScrollFrame)
    updatesTextLabel.Name = "UpdatesTextLabel"
    updatesTextLabel.Size = UDim2.new(1, -10, 1, 0)
    updatesTextLabel.Position = UDim2.new(0, 5, 0, 0)
    updatesTextLabel.BackgroundTransparency = 1
    updatesTextLabel.Text = CurrentUpdatesText
    updatesTextLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    updatesTextLabel.Font = Enum.Font.SourceSans
    updatesTextLabel.TextSize = 28
    updatesTextLabel.TextXAlignment = Enum.TextXAlignment.Left
    updatesTextLabel.TextYAlignment = Enum.TextYAlignment.Top
    updatesTextLabel.TextWrapped = true
    updatesTextLabel.TextStrokeTransparency = 0.8
    updatesTextLabel.RichText = true
    
    local function updateCanvasSize()
        updatesTextLabel.Size = UDim2.new(1, -10, 0, updatesTextLabel.TextBounds.Y + 20)
        updatesScrollFrame.CanvasSize = UDim2.new(0, 0, 0, updatesTextLabel.TextBounds.Y + 20)
    end
    
    updatesTextLabel:GetPropertyChangedSignal("TextBounds"):Connect(updateCanvasSize)
    updateCanvasSize()
    
    local updatesPrompt = Instance.new("ProximityPrompt", updatesBoardPart)
    updatesPrompt.Name = "UpdatesPrompt"
    updatesPrompt.ActionText = "Editar Misiones"
    updatesPrompt.ObjectText = "📝 TABLERO DE MISIONES"
    updatesPrompt.MaxActivationDistance = 10
    updatesPrompt.HoldDuration = 0
    updatesPrompt.RequiresLineOfSight = false
    
    updatesPrompt.Triggered:Connect(function(player)
        if player.Name == ADMIN_USERNAME then
            UpdatesRemote:FireClient(player, "OpenEditor", CurrentUpdatesText)
        else
            local notif = Instance.new("ScreenGui")
            notif.Name = "UpdatesNotification"
            notif.ResetOnSpawn = false
            notif.Parent = player.PlayerGui
            
            local frame = Instance.new("Frame", notif)
            frame.Size = UDim2.new(0, 400, 0, 100)
            frame.Position = UDim2.new(0.5, -200, 0.15, 0)
            frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
            frame.BorderSizePixel = 3
            frame.BorderColor3 = Color3.fromRGB(255, 80, 80)
            
            local corner = Instance.new("UICorner", frame)
            corner.CornerRadius = UDim.new(0, 12)
            
            local label = Instance.new("TextLabel", frame)
            label.Text = "⚠️ SOLO EL ADMINISTRADOR\nPUEDE EDITAR LAS MISIONES"
            label.Size = UDim2.new(1, -20, 1, -20)
            label.Position = UDim2.new(0, 10, 0, 10)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(255, 100, 100)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 20
            label.TextStrokeTransparency = 0.5
            label.TextWrapped = true
            
            task.delay(3, function()
                notif:Destroy()
            end)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 🟥 ZONAS DE CUARENTENA (PADS)
-- ═══════════════════════════════════════════════════════════════════════════

local function UpdatePadVisuals(index, padPart)
    if not Lobbies[index] or not padPart then return end
    
    local lobby = Lobbies[index]
    local billboard = padPart:FindFirstChild("BillboardGui")
    local statusLabel = billboard and billboard:FindFirstChild("StatusLabel")
    if not statusLabel then return end
    
    local borderFront = padPart:FindFirstChild("BorderFront")
    local borderBack = padPart:FindFirstChild("BorderBack")
    local borderLeft = padPart:FindFirstChild("BorderLeft")
    local borderRight = padPart:FindFirstChild("BorderRight")
    local pointLight = padPart:FindFirstChild("NeonGlow") and padPart.NeonGlow:FindFirstChild("PointLight")
    
    if #lobby.Occupants == 0 then
        statusLabel.Text = "ZONA SEGURA\n0/" .. lobby.MaxPlayers
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        
        local greenColor = Color3.fromRGB(0, 255, 0)
        
        if borderFront then borderFront.Color = greenColor end
        if borderBack then borderBack.Color = greenColor end
        if borderLeft then borderLeft.Color = greenColor end
        if borderRight then borderRight.Color = greenColor end
        if pointLight then pointLight.Color = greenColor end
    else
        if lobby.Status == "Countdown" then
            statusLabel.Text = "⚠️ INICIANDO\n" .. math.ceil(lobby.Timer)
            statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            
            local redColor = Color3.fromRGB(255, 0, 0)
            
            if borderFront then borderFront.Color = redColor end
            if borderBack then borderBack.Color = redColor end
            if borderLeft then borderLeft.Color = redColor end
            if borderRight then borderRight.Color = redColor end
            if pointLight then pointLight.Color = redColor end
        else
            statusLabel.Text = "ESPERANDO\n" .. #lobby.Occupants .. "/" .. lobby.MaxPlayers
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
            
            local yellowColor = Color3.fromRGB(255, 200, 0)
            
            if borderFront then borderFront.Color = yellowColor end
            if borderBack then borderBack.Color = yellowColor end
            if borderLeft then borderLeft.Color = yellowColor end
            if borderRight then borderRight.Color = yellowColor end
            if pointLight then pointLight.Color = yellowColor end
        end
    end
end

local function CreatePads()
    if workspace:FindFirstChild("QuarantinePads") then
        workspace.QuarantinePads:Destroy()
    end
    
    local folder = Instance.new("Folder")
    folder.Name = "QuarantinePads"
    folder.Parent = workspace
    
    local padZ = LOBBY_POS.Z + (ROOM_SIZE/2) - 20
    local gap = 35
    local positions = {
        Vector3.new(LOBBY_POS.X - gap, LOBBY_POS.Y + 0.5, padZ),
        Vector3.new(LOBBY_POS.X, LOBBY_POS.Y + 0.5, padZ),
        Vector3.new(LOBBY_POS.X + gap, LOBBY_POS.Y + 0.5, padZ)
    }
    
    for i = 1, MAX_PADS do
        Lobbies[i] = {
            Occupants = {},
            MaxPlayers = 5,
            Status = "Waiting",
            Timer = 20,
            Owner = nil
        }
        
        -- BASE DEL PAD con efecto metálico
        local pad = Instance.new("Part")
        pad.Name = "Pad_" .. i
        pad.Size = Vector3.new(PAD_SIZE, 0.8, PAD_SIZE)
        pad.Position = positions[i]
        pad.Anchored = true
        pad.CanCollide = false
        pad.Material = Enum.Material.Metal
        pad.Color = Color3.fromRGB(40, 40, 45)
        pad.Parent = folder
        
        -- PLATAFORMA ELEVADA
        local platform = Instance.new("Part", folder)
        platform.Size = Vector3.new(PAD_SIZE - 1, 0.3, PAD_SIZE - 1)
        platform.Position = positions[i] + Vector3.new(0, 0.55, 0)
        platform.Anchored = true
        platform.Material = Enum.Material.DiamondPlate
        platform.Color = Color3.fromRGB(60, 60, 65)
        
        -- MARCAS DE PELIGRO (amarillo y negro)
        for j = 1, 4 do
            local stripe = Instance.new("Part", pad)
            stripe.Name = "DangerStripe"
            stripe.Size = Vector3.new(PAD_SIZE + 0.3, 0.81, 1.2)
            stripe.Position = pad.Position + Vector3.new(0, 0, (j - 2.5) * 3.2)
            stripe.Anchored = true
            stripe.CanCollide = false
            stripe.Material = Enum.Material.SmoothPlastic
            stripe.Color = Color3.fromRGB(200, 180, 0)
        end
        
        -- Franjas negras intercaladas
        for j = 1, 3 do
            local blackStripe = Instance.new("Part", pad)
            blackStripe.Size = Vector3.new(PAD_SIZE + 0.3, 0.82, 0.8)
            blackStripe.Position = pad.Position + Vector3.new(0, 0, (j - 2) * 4)
            blackStripe.Anchored = true
            blackStripe.CanCollide = false
            blackStripe.Material = Enum.Material.SmoothPlastic
            blackStripe.Color = Color3.fromRGB(0, 0, 0)
        end
        
        -- BORDES NEÓN (más gruesos y brillantes)
        local borderThickness = 0.8
        local borderHeight = 2
        
        local borderFront = Instance.new("Part", pad)
        borderFront.Name = "BorderFront"
        borderFront.Size = Vector3.new(PAD_SIZE, borderHeight, borderThickness)
        borderFront.Position = pad.Position + Vector3.new(0, borderHeight/2 + 0.4, PAD_SIZE/2)
        borderFront.Anchored = true
        borderFront.CanCollide = false
        borderFront.Material = Enum.Material.Neon
        borderFront.Color = Color3.fromRGB(0, 255, 0)
        
        local borderBack = Instance.new("Part", pad)
        borderBack.Name = "BorderBack"
        borderBack.Size = Vector3.new(PAD_SIZE, borderHeight, borderThickness)
        borderBack.Position = pad.Position + Vector3.new(0, borderHeight/2 + 0.4, -PAD_SIZE/2)
        borderBack.Anchored = true
        borderBack.CanCollide = false
        borderBack.Material = Enum.Material.Neon
        borderBack.Color = Color3.fromRGB(0, 255, 0)
        
        local borderLeft = Instance.new("Part", pad)
        borderLeft.Name = "BorderLeft"
        borderLeft.Size = Vector3.new(borderThickness, borderHeight, PAD_SIZE)
        borderLeft.Position = pad.Position + Vector3.new(-PAD_SIZE/2, borderHeight/2 + 0.4, 0)
        borderLeft.Anchored = true
        borderLeft.CanCollide = false
        borderLeft.Material = Enum.Material.Neon
        borderLeft.Color = Color3.fromRGB(0, 255, 0)
        
        local borderRight = Instance.new("Part", pad)
        borderRight.Name = "BorderRight"
        borderRight.Size = Vector3.new(borderThickness, borderHeight, PAD_SIZE)
        borderRight.Position = pad.Position + Vector3.new(PAD_SIZE/2, borderHeight/2 + 0.4, 0)
        borderRight.Anchored = true
        borderRight.CanCollide = false
        borderRight.Material = Enum.Material.Neon
        borderRight.Color = Color3.fromRGB(0, 255, 0)
        
        -- LUZ CENTRAL (más grande y brillante)
        local neonGlow = Instance.new("Part", pad)
        neonGlow.Name = "NeonGlow"
        neonGlow.Size = Vector3.new(2, 2, 2)
        neonGlow.Position = pad.Position + Vector3.new(0, 3, 0)
        neonGlow.Anchored = true
        neonGlow.CanCollide = false
        neonGlow.Material = Enum.Material.Neon
        neonGlow.Color = Color3.fromRGB(0, 255, 0)
        neonGlow.Shape = Enum.PartType.Ball
        neonGlow.Transparency = 0.3
        
        local pointLight = Instance.new("PointLight", neonGlow)
        pointLight.Color = Color3.fromRGB(0, 255, 0)
        pointLight.Brightness = 5
        pointLight.Range = 25
        
        -- Efecto de partículas en el pad
        local particleEmitter = Instance.new("ParticleEmitter", neonGlow)
        particleEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        particleEmitter.Rate = 10
        particleEmitter.Lifetime = NumberRange.new(1, 2)
        particleEmitter.Speed = NumberRange.new(1, 3)
        particleEmitter.SpreadAngle = Vector2.new(360, 360)
        particleEmitter.Color = ColorSequence.new(Color3.fromRGB(0, 255, 0))
        particleEmitter.Size = NumberSequence.new(0.5, 0)
        particleEmitter.Transparency = NumberSequence.new(0, 1)
        particleEmitter.LightEmission = 1
        
        -- CARTEL DE ZONA SEGURA
        local signBoard = Instance.new("Part", folder)
        signBoard.Size = Vector3.new(6, 4, 0.3)
        signBoard.Position = pad.Position + Vector3.new(0, 6, -PAD_SIZE/2 - 2)
        signBoard.Anchored = true
        signBoard.Material = Enum.Material.Metal
        signBoard.Color = Color3.fromRGB(200, 180, 0)
        
        local signGui = Instance.new("SurfaceGui", signBoard)
        signGui.Face = Enum.NormalId.Front
        
        local signBg = Instance.new("Frame", signGui)
        signBg.Size = UDim2.new(1, 0, 1, 0)
        signBg.BackgroundColor3 = Color3.fromRGB(200, 180, 0)
        signBg.BorderSizePixel = 3
        signBg.BorderColor3 = Color3.fromRGB(0, 0, 0)
        
        local signLabel = Instance.new("TextLabel", signBg)
        signLabel.Size = UDim2.new(1, 0, 1, 0)
        signLabel.BackgroundTransparency = 1
        signLabel.Text = "⚠️\nSAFE ZONE\n" .. i
        signLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
        signLabel.Font = Enum.Font.GothamBlack
        signLabel.TextSize = 35
        
        -- BILLBOARD FLOTANTE
        local billboard = Instance.new("BillboardGui", pad)
        billboard.Size = UDim2.new(0, 280, 0, 150)
        billboard.StudsOffset = Vector3.new(0, 12, 0)
        billboard.AlwaysOnTop = false
        billboard.MaxDistance = 100
        
        local statusBg = Instance.new("Frame", billboard)
        statusBg.Size = UDim2.new(1, 0, 1, 0)
        statusBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        statusBg.BackgroundTransparency = 0.3
        statusBg.BorderSizePixel = 0
        
        local statusCorner = Instance.new("UICorner", statusBg)
        statusCorner.CornerRadius = UDim.new(0, 10)
        
        local statusLabel = Instance.new("TextLabel", statusBg)
        statusLabel.Name = "StatusLabel"
        statusLabel.Size = UDim2.new(1, 0, 1, 0)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "ZONA SEGURA\n0/5"
        statusLabel.Font = Enum.Font.Creepster
        statusLabel.TextSize = 48
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        statusLabel.TextStrokeTransparency = 0
        statusLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        
        pad.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if not player then return end
            
            local humanoid = hit.Parent:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then return end
            
            for _, lobby in pairs(Lobbies) do
                for _, occupant in pairs(lobby.Occupants) do
                    if occupant == player then
                        return
                    end
                end
            end
            
            if #Lobbies[i].Occupants < Lobbies[i].MaxPlayers then
                table.insert(Lobbies[i].Occupants, player)
                
                if #Lobbies[i].Occupants == 1 then
                    Lobbies[i].Owner = player
                    UpdateUIRemote:FireClient(player, "ShowCreateMenu", i)
                end
                
                ToggleExitBtn:FireClient(player, true)
                UpdatePadVisuals(i, pad)
            else
                local root = hit.Parent:FindFirstChild("HumanoidRootPart")
                if root then
                    local pushDirection = (root.Position - pad.Position).Unit
                    root.Velocity = pushDirection * 60
                end
            end
        end)
    end
end

local function RemovePlayerFromLobby(player, lobbyIndex)
    local lobby = Lobbies[lobbyIndex]
    if not lobby then return end
    
    for idx, occupant in pairs(lobby.Occupants) do
        if occupant == player then
            table.remove(lobby.Occupants, idx)
            ToggleExitBtn:FireClient(player, false)
            
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local root = player.Character.HumanoidRootPart
                root.CFrame = root.CFrame + Vector3.new(0, 0, -18)
            end
            
            if player == lobby.Owner then
                lobby.MaxPlayers = 5
                lobby.Owner = lobby.Occupants[1] or nil
            end
            
            local pad = workspace.QuarantinePads:FindFirstChild("Pad_" .. lobbyIndex)
            if pad then
                UpdatePadVisuals(lobbyIndex, pad)
            end
            
            break
        end
    end
end

LeaveLobbyRemote.OnServerEvent:Connect(function(player)
    for i = 1, MAX_PADS do
        RemovePlayerFromLobby(player, i)
    end
end)

RunService.Heartbeat:Connect(function(dt)
    for i, lobby in pairs(Lobbies) do
        local pad = workspace.QuarantinePads and workspace.QuarantinePads:FindFirstChild("Pad_" .. i)
        if pad then
        
            for idx = #lobby.Occupants, 1, -1 do
                local player = lobby.Occupants[idx]
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                
                if root then
                    local diff = root.Position - pad.Position
                    local flatDistance = Vector2.new(diff.X, diff.Z).Magnitude
                    local maxRadius = (PAD_SIZE / 2) - 0.8
                    
                    if flatDistance > maxRadius then
                        local direction = Vector3.new(diff.X, 0, diff.Z).Unit
                        local correctedPos = pad.Position + (direction * maxRadius)
                        root.CFrame = CFrame.new(
                            Vector3.new(correctedPos.X, root.Position.Y, correctedPos.Z),
                            root.Position + root.CFrame.LookVector
                        )
                        root.AssemblyLinearVelocity = Vector3.zero
                    end
                else
                    table.remove(lobby.Occupants, idx)
                end
            end
            
            if #lobby.Occupants > 0 then
                if lobby.MaxPlayers == 1 and #lobby.Occupants > 1 then
                    for idx = #lobby.Occupants, 1, -1 do
                        local player = lobby.Occupants[idx]
                        if player ~= lobby.Owner then
                            RemovePlayerFromLobby(player, i)
                        end
                    end
                end
                
                lobby.Status = "Countdown"
                local previousSecond = math.ceil(lobby.Timer)
                lobby.Timer = lobby.Timer - dt
                local currentSecond = math.ceil(lobby.Timer)
                
                if currentSecond ~= previousSecond and currentSecond > 0 and currentSecond <= 20 then
                    for _, player in pairs(lobby.Occupants) do
                        CountdownSoundRemote:FireClient(player)
                    end
                end
                
                if lobby.Timer <= 0 then
                    lobby.Status = "Teleporting"
                    lobby.Timer = 20
                    
                    local travelers = {unpack(lobby.Occupants)}
                    local groupID = NextGameGroupID
                    NextGameGroupID = NextGameGroupID + 1
                    
                    ActiveGames[groupID] = {
                        Players = travelers,
                        MaxPlayers = lobby.MaxPlayers
                    }
                    
                    lobby.Occupants = {}
                    lobby.Owner = nil
                    lobby.Status = "Waiting"
                    UpdatePadVisuals(i, pad)
                    
                    for _, player in pairs(travelers) do
                        TeleportRemote:FireClient(player, "FadeBlack")
                    end
                    
                    task.delay(2.5, function()
                        local spawnLoc = workspace:FindFirstChild("SpawnLocation")
                        local spawnPos = spawnLoc and spawnLoc.Position or GAME_SPAWN_POS
                        local targetPos = spawnPos + Vector3.new(0, 5, 0)
                        
                        for _, player in pairs(travelers) do
                            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                                PlayerStats[player.UserId].InGame = true
                                PlayerStats[player.UserId].Lives = MAX_LIVES
                                PlayerStats[player.UserId].GameGroup = groupID
                                PlayerStats[player.UserId].SessionStart = os.time()
                                
                                ToggleExitBtn:FireClient(player, false)
                                
                                player.Character.HumanoidRootPart.CFrame = CFrame.new(
                                    targetPos + Vector3.new(
                                        math.random(-12, 12),
                                        0,
                                        math.random(-12, 12)
                                    )
                                )
                                
                                HidePlayersRemote:FireClient(player, "HideOthers", groupID, travelers)
                            end
                        end
                    end)
                end
            else
                lobby.Status = "Waiting"
                lobby.Timer = 20
            end
            
            if math.floor(lobby.Timer * 10) % 5 == 0 then
                UpdatePadVisuals(i, pad)
            end
        end
    end
end)

UpdateUIRemote.OnServerEvent:Connect(function(player, action, lobbyIndex, size)
    if action == "SetSize" and Lobbies[lobbyIndex] and Lobbies[lobbyIndex].Owner == player then
        Lobbies[lobbyIndex].MaxPlayers = size
        
        local pad = workspace.QuarantinePads:FindFirstChild("Pad_" .. lobbyIndex)
        if pad then
            UpdatePadVisuals(lobbyIndex, pad)
        end
    end
end)

BuildLab()
CreatePads()

print("✅ ZOMBIE APOCALYPSE LOBBY - Completamente funcional con diseño apocalíptico")
