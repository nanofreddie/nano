local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

-- Настройки
local AimLockKey = Enum.KeyCode.F -- Клавиша для включения aim lock
local AimSensitivity = 1 -- Скорость наведения на цель
local AimLockDuration = 0.01 -- Продолжительность действия aim lock (в секундах)
local ToggleTableKey = Enum.KeyCode.M -- Клавиша для переключения видимости обеих таблиц
local ResetTargetsKey = Enum.KeyCode.N -- Клавиша для сброса всех выбранных целей

local aimLockEnabled = false
local selectedPlayers = {} -- Список выбранных игроков
local targetPlayer = nil

-- Создаем GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
screenGui.Name = "AimLockGUI"

-- Основная таблица игроков
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 300)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Parent = screenGui

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, 5)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = frame

local playerButtons = {} -- Храним кнопки для игроков

-- Функция для создания кнопки для игрока
local function createPlayerButton(player)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Text = player.Name
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    button.Parent = frame

    -- Обработка выбора игрока
    button.MouseButton1Click:Connect(function()
        if selectedPlayers[player] then
            selectedPlayers[player] = nil
            button.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Обычный цвет
        else
            selectedPlayers[player] = true
            button.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Зеленый цвет для выбранных
        end
    end)

    return button
end

-- Функция для отображения всех игроков на сервере в GUI
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
end

-- Функция для получения ближайшей цели
local function getClosestTarget()
    local closestDistance = math.huge
    local closestPlayer = nil

    for player, _ in pairs(selectedPlayers) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local middlePart = player.Character.HumanoidRootPart
            local targetPosition = middlePart.Position
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - targetPosition).Magnitude

            if distance < closestDistance then
                closestDistance = distance
                closestPlayer = player
            end
        end
    end

    return closestPlayer
end

-- Функция для наведения на цель
local function aimAtTarget(target)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        return
    end

    local middlePart = target.Character.HumanoidRootPart
    local targetPosition = middlePart.Position
    -- Интерполяция для плавного наведения
    local currentCameraCFrame = Camera.CFrame
    local direction = (targetPosition - currentCameraCFrame.Position).Unit
    local newCFrame = CFrame.new(currentCameraCFrame.Position, currentCameraCFrame.Position + direction)

    Camera.CFrame = currentCameraCFrame:Lerp(newCFrame, AimSensitivity)
end

-- Создаем маленькую таблицу с инструкцией справа от списка игроков
local instructionFrame = Instance.new("Frame")
instructionFrame.Size = UDim2.new(0, 250, 0, 230) -- Увеличиваем размер таблицы, чтобы поместилась вся инструкция
instructionFrame.Position = UDim2.new(0, 220, 0, 10)
instructionFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
instructionFrame.Visible = true -- Сделаем видимой с самого начала
instructionFrame.Parent = screenGui

local instructionLabel = Instance.new("TextLabel")
instructionLabel.Size = UDim2.new(1, 0, 0, 150)
instructionLabel.Position = UDim2.new(0, 0, 0, 0)
instructionLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
instructionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
instructionLabel.TextSize = 14
instructionLabel.Text = "Инструкция:\n" ..
                        "F - Наведение на 0.01 сек\n" ..
                        "M - Скрыть/Показать обе таблицы\n" ..
                        "N - Сбросить все цели"
instructionLabel.TextWrapped = true
instructionLabel.TextYAlignment = Enum.TextYAlignment.Top
instructionLabel.Parent = instructionFrame

-- Подпись "Создано игроком Nano - AimLock Script"
local authorLabel = Instance.new("TextLabel")
authorLabel.Size = UDim2.new(1, 0, 0, 30)
authorLabel.Position = UDim2.new(0, 0, 0.8, 0)
authorLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
authorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
authorLabel.TextSize = 12
authorLabel.Text = "Создано игроком Nano - AimLock Script"
authorLabel.TextWrapped = true
authorLabel.TextYAlignment = Enum.TextYAlignment.Top
authorLabel.Parent = instructionFrame

-- Обработка ввода пользователя
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- Переключение видимости обеих таблиц
    if input.KeyCode == ToggleTableKey then
        frame.Visible = not frame.Visible
        instructionFrame.Visible = not instructionFrame.Visible
    end

    -- Включение aim lock при нажатии на F
    if input.KeyCode == AimLockKey then
        aimLockEnabled = true

        -- Получаем ближайшую цель из выбранных
        targetPlayer = getClosestTarget()

        -- Если цель найдена, наводим на неё
        if targetPlayer then
            aimAtTarget(targetPlayer)

            -- Останавливаем aim lock через 0.01 секунды
            wait(AimLockDuration)

            -- Отключаем aim lock после задержки
            aimLockEnabled = false
            targetPlayer = nil
        end
    end

    -- Сброс всех выбранных игроков при нажатии на N
    if input.KeyCode == ResetTargetsKey then
        selectedPlayers = {} -- Очищаем список выбранных игроков
        -- Обновляем GUI, сбрасывая подсветку кнопок
        updatePlayerList()
    end
end)

-- Цикл для обновления aim lock
game:GetService("RunService").RenderStepped:Connect(function()
    if aimLockEnabled then
        if not targetPlayer then
            -- Если нет выбранной цели, ищем ближайшую
            targetPlayer = getClosestTarget()
        end

        if targetPlayer then
            aimAtTarget(targetPlayer)
        end
    end
end)

-- Инициализация списка игроков
Players.PlayerAdded:Connect(function(player)
    updatePlayerList()
end)

Players.PlayerRemoving:Connect(function(player)
    updatePlayerList()
end)

-- Изначально отображаем список игроков
updatePlayerList()
