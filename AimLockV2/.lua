local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

-- Настройки
local AimLockKey = Enum.KeyCode.F
local AimSensitivity = 1
local AimLockDuration = 0.01
local ToggleTableKey = Enum.KeyCode.M
local ResetTargetsKey = Enum.KeyCode.N
local ToggleAimModeKey = Enum.KeyCode.K

local aimLockEnabled = false
local isContinuousAimEnabled = false
local selectedPlayers = {}
local targetPlayer = nil
local isInContinuousMode = false

-- Создаем GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
screenGui.Name = "AimLockGUI"
screenGui.ResetOnSpawn = false -- Чтобы GUI не исчезал после смерти

-- Основная таблица игроков
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 250)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BackgroundTransparency = 0.5
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
frame.Parent = screenGui

-- ScrollingFrame для прокрутки
local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, 0, 1, 0)
scrollingFrame.BackgroundTransparency = 1
scrollingFrame.BorderSizePixel = 0
scrollingFrame.ScrollBarThickness = 10
scrollingFrame.Parent = frame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, 5)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = scrollingFrame

local playerButtons = {}

-- Функция для создания кнопки для игрока
local function createPlayerButton(player)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 40) -- Увеличен размер текста
    button.Text = player.Name .. "\n(" .. player.DisplayName .. ")"
    button.TextSize = 18 -- Увеличен размер шрифта
    button.TextWrapped = true
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 1
    button.BorderColor3 = Color3.fromRGB(255, 255, 255)
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

    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, #playerButtons * 45)
end

-- Инструкция
local instructionFrame = Instance.new("Frame")
instructionFrame.Size = UDim2.new(0, 250, 0, 300)
instructionFrame.Position = UDim2.new(0, 320, 0, 10)
instructionFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
instructionFrame.BackgroundTransparency = 0.5
instructionFrame.BorderSizePixel = 2
instructionFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
instructionFrame.Visible = true
instructionFrame.Parent = screenGui

local instructionLabel = Instance.new("TextLabel")
instructionLabel.Size = UDim2.new(1, 0, 0, 250)
instructionLabel.Position = UDim2.new(0, 0, 0, 0)
instructionLabel.BackgroundTransparency = 1
instructionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
instructionLabel.TextSize = 14
instructionLabel.Text = "Инструкция:\nF - Вкл/выкл аим лока (на 0.01 сек)\nK - Переключить режим аим лока\nM - Скрыть/показать таблицы\nN - Сбросить цели"
instructionLabel.TextWrapped = true
instructionLabel.TextYAlignment = Enum.TextYAlignment.Top
instructionLabel.Parent = instructionFrame

local authorLabel = Instance.new("TextLabel")
authorLabel.Size = UDim2.new(1, 0, 0, 30)
authorLabel.Position = UDim2.new(0, 0, 0.85, 0)
authorLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
authorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
authorLabel.TextSize = 12
authorLabel.Text = "Создано игроком Nano"
authorLabel.TextWrapped = true
authorLabel.TextYAlignment = Enum.TextYAlignment.Top
authorLabel.Parent = instructionFrame

-- Обработка ввода пользователя
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == ToggleTableKey then
        frame.Visible = not frame.Visible
        instructionFrame.Visible = not instructionFrame.Visible
    end
end)

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)

updatePlayerList()
