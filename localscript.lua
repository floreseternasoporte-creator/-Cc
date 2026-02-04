--[[
═══════════════════════════════════════════════════════════════════════════
🧟 ZOMBIE APOCALYPSE - CLIENT SCRIPT 🧟
═══════════════════════════════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local RemoteFolder = ReplicatedStorage:WaitForChild("LobbyEvents")

local UpdateUIRemote = RemoteFolder:WaitForChild("UpdateUI")
local TeleportRemote = RemoteFolder:WaitForChild("TeleportEffect")
local ToggleExitBtn = RemoteFolder:WaitForChild("ToggleExitBtn")
local LeaveLobbyRemote = RemoteFolder:WaitForChild("LeaveLobby")
local HidePlayersRemote = RemoteFolder:WaitForChild("HidePlayers")
local CountdownSoundRemote = RemoteFolder:WaitForChild("CountdownSound")
local UpdatesRemote = RemoteFolder:WaitForChild("UpdatesRemote")

-- ═══════════════════════════════════════════════════════════════════════════
-- SONIDO DEL COUNTDOWN
-- ═══════════════════════════════════════════════════════════════════════════

local countdownSound = Instance.new("Sound")
countdownSound.SoundId = "rbxassetid://104748925849270"
countdownSound.Volume = 0.5
countdownSound.Parent = game:GetService("SoundService")

CountdownSoundRemote.OnClientEvent:Connect(function()
    countdownSound:Play()
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- PANTALLA NEGRA CON EFECTO SANGRE
-- ═══════════════════════════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui", PlayerGui)
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999

local BlackFrame = Instance.new("Frame", ScreenGui)
BlackFrame.Name = "BlackScreen"
BlackFrame.Size = UDim2.new(1, 0, 1, 0)
BlackFrame.BackgroundColor3 = Color3.fromRGB(10, 0, 0)
BlackFrame.BackgroundTransparency = 1
BlackFrame.BorderSizePixel = 0
BlackFrame.ZIndex = 999

-- ═══════════════════════════════════════════════════════════════════════════
-- BOTÓN DE SALIR (ESTILO APOCALÍPTICO)
-- ═══════════════════════════════════════════════════════════════════════════

local ExitGui = Instance.new("ScreenGui", PlayerGui)
ExitGui.Name = "ExitLobbyGui"
ExitGui.Enabled = false
ExitGui.ResetOnSpawn = false

local ExitBtn = Instance.new("TextButton", ExitGui)
ExitBtn.Name = "ExitButton"
ExitBtn.Size = UDim2.new(0, 120, 0, 45)
ExitBtn.Position = UDim2.new(0.5, -60, 0.88, 0)
ExitBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
ExitBtn.BorderSizePixel = 0
ExitBtn.Text = "🚪 SALIR"
ExitBtn.TextColor3 = Color3.new(1, 1, 1)
ExitBtn.Font = Enum.Font.GothamBlack
ExitBtn.TextSize = 20

local exitCorner = Instance.new("UICorner", ExitBtn)
exitCorner.CornerRadius = UDim.new(0, 8)

local exitStroke = Instance.new("UIStroke", ExitBtn)
exitStroke.Color = Color3.fromRGB(255, 50, 50)
exitStroke.Thickness = 3
exitStroke.Transparency = 0.3

ExitBtn.MouseButton1Click:Connect(function()
    LeaveLobbyRemote:FireServer()
end)

-- Efecto de pulso en el botón
task.spawn(function()
    while true do
        if ExitGui.Enabled then
            TweenService:Create(
                exitStroke,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {Transparency = 0}
            ):Play()
            task.wait(0.8)
            TweenService:Create(
                exitStroke,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {Transparency = 0.7}
            ):Play()
            task.wait(0.8)
        else
            task.wait(0.1)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- MENÚ DE SELECCIÓN DE JUGADORES (ESTILO APOCALÍPTICO)
-- ═══════════════════════════════════════════════════════════════════════════

local MenuGui = Instance.new("ScreenGui", PlayerGui)
MenuGui.Name = "PlayerSelectorMenu"
MenuGui.Enabled = false
MenuGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", MenuGui)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 420, 0, 240)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 15)
MainFrame.BorderSizePixel = 5
MainFrame.BorderColor3 = Color3.fromRGB(200, 0, 0)

local mainCorner = Instance.new("UICorner", MainFrame)
mainCorner.CornerRadius = UDim.new(0, 15)

local Title = Instance.new("TextLabel", MainFrame)
Title.Name = "Title"
Title.Text = "🧟 SELECCIONA SOBREVIVIENTES 🧟"
Title.Size = UDim2.new(1, 0, 0.25, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 50, 50)
Title.Font = Enum.Font.Creepster
Title.TextSize = 34
Title.TextStrokeTransparency = 0.4

local BtnContainer = Instance.new("Frame", MainFrame)
BtnContainer.Name = "ButtonContainer"
BtnContainer.Size = UDim2.new(1, -40, 0.35, 0)
BtnContainer.Position = UDim2.new(0, 20, 0.35, 0)
BtnContainer.BackgroundTransparency = 1

local btnLayout = Instance.new("UIListLayout", BtnContainer)
btnLayout.FillDirection = Enum.FillDirection.Horizontal
btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
btnLayout.Padding = UDim.new(0, 14)

local currentSelection = 5
local currentLobbyIndex = 0
local buttons = {}

local function UpdateSelection(newSelection)
    currentSelection = newSelection
    
    for j = 1, 5 do
        buttons[j].Button.BackgroundColor3 = Color3.fromRGB(50, 45, 45)
        buttons[j].Button.TextColor3 = Color3.fromRGB(200, 200, 200)
        buttons[j].Stroke.Thickness = 0
    end
    
    buttons[newSelection].Button.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    buttons[newSelection].Button.TextColor3 = Color3.new(1, 1, 1)
    buttons[newSelection].Stroke.Thickness = 4
end

for i = 1, 5 do
    local btn = Instance.new("TextButton", BtnContainer)
    btn.Name = "Btn" .. i
    btn.Size = UDim2.new(0, 52, 0, 52)
    btn.Text = tostring(i)
    btn.BackgroundColor3 = Color3.fromRGB(50, 45, 45)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamBlack
    btn.TextSize = 26
    
    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 8)
    
    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = Color3.fromRGB(255, 50, 50)
    btnStroke.Thickness = 0
    
    buttons[i] = {Button = btn, Stroke = btnStroke}
    
    btn.MouseButton1Click:Connect(function()
        UpdateSelection(i)
    end)
end

UpdateSelection(5)

local ConfirmBtn = Instance.new("TextButton", MainFrame)
ConfirmBtn.Name = "ConfirmButton"
ConfirmBtn.Text = "✅ CONFIRMAR EQUIPO"
ConfirmBtn.Size = UDim2.new(0.7, 0, 0.22, 0)
ConfirmBtn.Position = UDim2.new(0.15, 0, 0.73, 0)
ConfirmBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
ConfirmBtn.BorderSizePixel = 0
ConfirmBtn.TextColor3 = Color3.new(1, 1, 1)
ConfirmBtn.Font = Enum.Font.GothamBlack
ConfirmBtn.TextSize = 22

local confirmCorner = Instance.new("UICorner", ConfirmBtn)
confirmCorner.CornerRadius = UDim.new(0, 10)

local confirmStroke = Instance.new("UIStroke", ConfirmBtn)
confirmStroke.Color = Color3.fromRGB(0, 255, 0)
confirmStroke.Thickness = 2

ConfirmBtn.MouseButton1Click:Connect(function()
    MenuGui.Enabled = false
    UpdateUIRemote:FireServer("SetSize", currentLobbyIndex, currentSelection)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- 📝 EDITOR DE ACTUALIZACIONES/MISIONES (SOLO ADMIN)
-- ═══════════════════════════════════════════════════════════════════════════

local EditorGui = Instance.new("ScreenGui", PlayerGui)
EditorGui.Name = "UpdatesEditorGui"
EditorGui.Enabled = false
EditorGui.ResetOnSpawn = false
EditorGui.DisplayOrder = 100

local EditorFrame = Instance.new("Frame", EditorGui)
EditorFrame.Name = "EditorFrame"
EditorFrame.Size = UDim2.new(0, 750, 0, 550)
EditorFrame.Position = UDim2.new(0.5, -375, 0.5, -275)
EditorFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 15)
EditorFrame.BorderSizePixel = 6
EditorFrame.BorderColor3 = Color3.fromRGB(200, 0, 0)

local editorCorner = Instance.new("UICorner", EditorFrame)
editorCorner.CornerRadius = UDim.new(0, 18)

local EditorTitle = Instance.new("TextLabel", EditorFrame)
EditorTitle.Name = "EditorTitle"
EditorTitle.Text = "📝 EDITOR DE MISIONES DEL APOCALIPSIS"
EditorTitle.Size = UDim2.new(1, 0, 0, 55)
EditorTitle.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
EditorTitle.BorderSizePixel = 0
EditorTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
EditorTitle.Font = Enum.Font.GothamBlack
EditorTitle.TextSize = 26
EditorTitle.TextStrokeTransparency = 0.4

local titleCorner = Instance.new("UICorner", EditorTitle)
titleCorner.CornerRadius = UDim.new(0, 18)

local EditorScrollFrame = Instance.new("ScrollingFrame", EditorFrame)
EditorScrollFrame.Name = "EditorScrollFrame"
EditorScrollFrame.Size = UDim2.new(0.95, 0, 0, 370)
EditorScrollFrame.Position = UDim2.new(0.025, 0, 0, 70)
EditorScrollFrame.BackgroundColor3 = Color3.fromRGB(35, 30, 30)
EditorScrollFrame.BorderSizePixel = 3
EditorScrollFrame.BorderColor3 = Color3.fromRGB(100, 90, 90)
EditorScrollFrame.ScrollBarThickness = 12
EditorScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

local scrollCorner = Instance.new("UICorner", EditorScrollFrame)
scrollCorner.CornerRadius = UDim.new(0, 10)

local EditorTextBox = Instance.new("TextBox", EditorScrollFrame)
EditorTextBox.Name = "EditorTextBox"
EditorTextBox.Size = UDim2.new(1, -20, 1, 0)
EditorTextBox.Position = UDim2.new(0, 10, 0, 10)
EditorTextBox.BackgroundTransparency = 1
EditorTextBox.Text = ""
EditorTextBox.PlaceholderText = "Escribe las misiones del apocalipsis aquí...\n\nEjemplo:\n🧟 MISIONES ACTIVAS\n\n• Sobrevive 10 minutos\n• Elimina 50 zombies\n• Encuentra el refugio\n• Rescata a los sobrevivientes"
EditorTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
EditorTextBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
EditorTextBox.Font = Enum.Font.SourceSans
EditorTextBox.TextSize = 24
EditorTextBox.TextXAlignment = Enum.TextXAlignment.Left
EditorTextBox.TextYAlignment = Enum.TextYAlignment.Top
EditorTextBox.TextWrapped = true
EditorTextBox.ClearTextOnFocus = false
EditorTextBox.MultiLine = true

EditorTextBox:GetPropertyChangedSignal("TextBounds"):Connect(function()
    EditorScrollFrame.CanvasSize = UDim2.new(0, 0, 0, EditorTextBox.TextBounds.Y + 20)
end)

local ButtonContainer = Instance.new("Frame", EditorFrame)
ButtonContainer.Size = UDim2.new(1, 0, 0, 70)
ButtonContainer.Position = UDim2.new(0, 0, 1, -80)
ButtonContainer.BackgroundTransparency = 1

local SaveButton = Instance.new("TextButton", ButtonContainer)
SaveButton.Name = "SaveButton"
SaveButton.Size = UDim2.new(0.45, 0, 0, 50)
SaveButton.Position = UDim2.new(0.05, 0, 0.5, -25)
SaveButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
SaveButton.BorderSizePixel = 0
SaveButton.Text = "💾 GUARDAR MISIONES"
SaveButton.TextColor3 = Color3.new(1, 1, 1)
SaveButton.Font = Enum.Font.GothamBlack
SaveButton.TextSize = 22

local saveCorner = Instance.new("UICorner", SaveButton)
saveCorner.CornerRadius = UDim.new(0, 12)

local saveStroke = Instance.new("UIStroke", SaveButton)
saveStroke.Color = Color3.fromRGB(0, 255, 0)
saveStroke.Thickness = 2

local CancelButton = Instance.new("TextButton", ButtonContainer)
CancelButton.Name = "CancelButton"
CancelButton.Size = UDim2.new(0.45, 0, 0, 50)
CancelButton.Position = UDim2.new(0.5, 0, 0.5, -25)
CancelButton.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
CancelButton.BorderSizePixel = 0
CancelButton.Text = "❌ CANCELAR"
CancelButton.TextColor3 = Color3.new(1, 1, 1)
CancelButton.Font = Enum.Font.GothamBlack
CancelButton.TextSize = 22

local cancelCorner = Instance.new("UICorner", CancelButton)
cancelCorner.CornerRadius = UDim.new(0, 12)

local cancelStroke = Instance.new("UIStroke", CancelButton)
cancelStroke.Color = Color3.fromRGB(255, 50, 50)
cancelStroke.Thickness = 2

SaveButton.MouseButton1Click:Connect(function()
    local newText = EditorTextBox.Text
    if newText and newText ~= "" then
        UpdatesRemote:FireServer("SaveUpdates", newText)
        EditorGui.Enabled = false
        
        -- Confirmación visual apocalíptica
        local confirmGui = Instance.new("ScreenGui")
        confirmGui.Name = "SaveConfirmation"
        confirmGui.ResetOnSpawn = false
        confirmGui.Parent = PlayerGui
        
        local confirmFrame = Instance.new("Frame", confirmGui)
        confirmFrame.Size = UDim2.new(0, 450, 0, 120)
        confirmFrame.Position = UDim2.new(0.5, -225, 0.15, 0)
        confirmFrame.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
        confirmFrame.BorderSizePixel = 4
        confirmFrame.BorderColor3 = Color3.fromRGB(0, 255, 0)
        
        local confirmCorner = Instance.new("UICorner", confirmFrame)
        confirmCorner.CornerRadius = UDim.new(0, 15)
        
        local confirmLabel = Instance.new("TextLabel", confirmFrame)
        confirmLabel.Text = "✅ MISIONES ACTUALIZADAS\nTodos los sobrevivientes verán los cambios"
        confirmLabel.Size = UDim2.new(1, -20, 1, -20)
        confirmLabel.Position = UDim2.new(0, 10, 0, 10)
        confirmLabel.BackgroundTransparency = 1
        confirmLabel.TextColor3 = Color3.new(1, 1, 1)
        confirmLabel.Font = Enum.Font.GothamBold
        confirmLabel.TextSize = 22
        confirmLabel.TextStrokeTransparency = 0.4
        confirmLabel.TextWrapped = true
        
        task.delay(3, function()
            confirmGui:Destroy()
        end)
    end
end)

CancelButton.MouseButton1Click:Connect(function()
    EditorGui.Enabled = false
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ACTUALIZAR CARTEL DE ACTUALIZACIONES EN TIEMPO REAL
-- ═══════════════════════════════════════════════════════════════════════════

UpdatesRemote.OnClientEvent:Connect(function(action, data)
    if action == "OpenEditor" then
        EditorTextBox.Text = data or ""
        EditorGui.Enabled = true
    elseif action == "UpdateText" then
        task.wait(1)
        
        local updatesBoard = workspace:FindFirstChild("ZombieApocalypseLobby")
        if updatesBoard then
            local updatesPart = updatesBoard:FindFirstChild("UpdatesBoardPart")
            if updatesPart then
                local surfaceGui = updatesPart:FindFirstChild("UpdatesSurfaceGui")
                if surfaceGui then
                    local scrollFrame = surfaceGui:FindFirstChild("UpdatesScrollFrame", true)
                    if scrollFrame then
                        local textLabel = scrollFrame:FindFirstChild("UpdatesTextLabel")
                        if textLabel then
                            textLabel.Text = data
                        end
                    end
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- SISTEMA DE OCULTACIÓN DE JUGADORES
-- ═══════════════════════════════════════════════════════════════════════════

local hiddenPlayers = {}

local function HidePlayer(targetPlayer)
    if targetPlayer == player then return end
    if hiddenPlayers[targetPlayer] then return end
    
    hiddenPlayers[targetPlayer] = true
    
    local function hideCharacter(char)
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.LocalTransparencyModifier = 1
            end
        end
    end
    
    if targetPlayer.Character then
        hideCharacter(targetPlayer.Character)
    end
    
    targetPlayer.CharacterAdded:Connect(function(char)
        if hiddenPlayers[targetPlayer] then
            task.wait(0.1)
            hideCharacter(char)
        end
    end)
end

local function ShowPlayer(targetPlayer)
    if not hiddenPlayers[targetPlayer] then return end
    
    hiddenPlayers[targetPlayer] = nil
    
    if targetPlayer.Character then
        for _, part in pairs(targetPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.LocalTransparencyModifier = 0
            end
        end
    end
end

local function ShowAllPlayers()
    for targetPlayer, _ in pairs(hiddenPlayers) do
        ShowPlayer(targetPlayer)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTOS DEL SERVIDOR
-- ═══════════════════════════════════════════════════════════════════════════

UpdateUIRemote.OnClientEvent:Connect(function(action, lobbyIndex)
    if action == "ShowCreateMenu" then
        currentLobbyIndex = lobbyIndex
        UpdateSelection(5)
        MenuGui.Enabled = true
    end
end)

ToggleExitBtn.OnClientEvent:Connect(function(visible)
    ExitGui.Enabled = visible
end)

TeleportRemote.OnClientEvent:Connect(function(action)
    if action == "FadeBlack" then
        TweenService:Create(
            BlackFrame,
            TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {BackgroundTransparency = 0}
        ):Play()
        
        task.wait(4)
        
        TweenService:Create(
            BlackFrame,
            TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {BackgroundTransparency = 1}
        ):Play()
    end
end)

HidePlayersRemote.OnClientEvent:Connect(function(action, groupID, groupPlayers)
    if action == "HideOthers" then
        local myGroup = {}
        for _, p in pairs(groupPlayers) do
            myGroup[p] = true
        end
        
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if not myGroup[otherPlayer] then
                HidePlayer(otherPlayer)
            end
        end
        
        Players.PlayerAdded:Connect(function(newPlayer)
            if not myGroup[newPlayer] then
                HidePlayer(newPlayer)
            end
        end)
        
    elseif action == "ShowAll" then
        ShowAllPlayers()
    end
end)

print("✅ Zombie Apocalypse Client - Sistema completamente funcional con diseño apocalíptico")
