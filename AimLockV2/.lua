local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

-- Настройки
local AimLockKey = Enum.KeyCode.F -- Клавиша для включения aim lock
local AimSensitivity = 1 -- Скорость наведения на цель
local AimLockDuration = 0.01 -- Продолжительность мгновенной наводки
local ToggleTableKey = Enum.KeyCode.M -- Клавиша для переключения видимости таблиц
local ResetTargetsKey = Enum.KeyCode.N -- Клавиша для сброса всех целей
local ToggleAimModeKey = Enum.KeyCode.K -- Клавиша для переключения режима наводки

local aimLockEnabled = false
local isInContinuousMode = false
local selectedPlayers = {}
local targetPlayer = nil

-- Создаем GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimLockGUI"
screenGui.ResetOnSpawn = false -- Отключаем сброс при возрождении
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Функция для плавного перемещения окон
local function makeDraggable(frame)
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if dragging then
                    local delta = input.Position - dragStart
                    frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- Основная таблица игроков
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 250)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BackgroundTransparency = 0.5
frame.BorderSizePixel = 2
frame.Parent = screenGui

makeDraggable(frame)

local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.ScrollBarThickness = 10
scrollingFrame.Parent = frame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, 5)
uiListLayout.Parent = scrollingFrame

local playerButtons = {}

local function createPlayerButton(player)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Text = player.Name .. "\n(" .. player.DisplayName .. ")"
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Parent = scrollingFrame

    button.MouseButton1Click:Connect(function()
        if selectedPlayers[player] then
            selectedPlayers[player] = nil
            button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        else
            selectedPlayers[player] = true
            button.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        end
    end)

    return button
end

local function updatePlayerList()
    for _, button in pairs(playerButtons) do
        button:Destroy()
    end
    playerButtons = {}

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local button = createPlayerButton(player)
            table.insert(playerButtons, button)
        end
    end

    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, #playerButtons * 35)
end

local function getClosestTarget()
    local closestDistance = math.huge
    local closestPlayer = nil

    for player, _ in pairs(selectedPlayers) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestPlayer = player
            end
        end
    end

    return closestPlayer
end

local function aimAtTarget(target)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        return
    end

    local targetPosition = target.Character.HumanoidRootPart.Position
    local direction = (targetPosition - Camera.CFrame.Position).Unit
    local newCFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + direction)

    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, AimSensitivity)
end

-- Окно с инструкцией
local instructionFrame = Instance.new("Frame")
instructionFrame.Size = UDim2.new(0, 250, 0, 300)
instructionFrame.Position = UDim2.new(0, 320, 0, 10)
instructionFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
instructionFrame.BackgroundTransparency = 0.5
instructionFrame.BorderSizePixel = 2
instructionFrame.Parent = screenGui

makeDraggable(instructionFrame)

local instructionLabel = Instance.new("TextLabel")
instructionLabel.Size = UDim2.new(1, 0, 0, 250)
instructionLabel.BackgroundTransparency = 1
instructionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
instructionLabel.TextSize = 14
instructionLabel.Text = "Инструкция:\n" ..
                        "F - Вкл/выкл аим лока\n" ..
                        "K - Переключить режим аим лока\n" ..
                        "M - Скрыть/показать таблицы\n" ..
                        "N - Сбросить цели"
instructionLabel.TextWrapped = true
instructionLabel.Parent = instructionFrame

local authorLabel = Instance.new("TextLabel")
authorLabel.Size = UDim2.new(1, 0, 0, 30)
authorLabel.Position = UDim2.new(0, 0, 0.85, 0)
authorLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
authorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
authorLabel.TextSize = 12
authorLabel.Text = "Создано игроком Nano"
authorLabel.TextWrapped = true
authorLabel.Parent = instructionFrame

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == ToggleTableKey then
        frame.Visible = not frame.Visible
        instructionFrame.Visible = not instructionFrame.Visible
    end

    if input.KeyCode == AimLockKey then
        if isInContinuousMode then
            aimLockEnabled = not aimLockEnabled
        else
            aimLockEnabled = true
            targetPlayer = getClosestTarget()

            if targetPlayer then
                aimAtTarget(targetPlayer)
                wait(AimLockDuration)
                aimLockEnabled = false
                targetPlayer = nil
            end
        end
    end

    if input.KeyCode == ToggleAimModeKey then
        isInContinuousMode = not isInContinuousMode
        aimLockEnabled = false
        targetPlayer = nil
    end

    if input.KeyCode == ResetTargetsKey then
        selectedPlayers = {}
        aimLockEnabled = false
        targetPlayer = nil
        updatePlayerList()
    end
end)

RunService.RenderStepped:Connect(function()
    if aimLockEnabled then
        if not targetPlayer or not targetPlayer.Character then
            targetPlayer = getClosestTarget()
        end
        if targetPlayer then
            aimAtTarget(targetPlayer)
        end
    end
end)

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)
updatePlayerList()
