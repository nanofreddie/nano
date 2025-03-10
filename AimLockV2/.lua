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

local AimDetectionThreshold = 3 -- Порог точности прицеливания (в градусах)
local AimHoldDuration = 0.3 -- Минимальная продолжительность удержания прицела для фиксации Aim Lock (в секундах)
local StabilityFrameCount = 20 -- Количество кадров для проверки стабильности
local suddenTurnThreshold = 80 -- Порог резкого поворота в градусах
local aimLockHoldThreshold = 2 -- Порог времени удержания прицела на цели (в секундах)

local aimLockEnabled = false
local isInContinuousMode = false
local selectedPlayers = {}
local targetPlayer = nil
local detectedAimLockUsers = {} -- Список игроков, уличенных в Aim Lock (не убираются)
local aimTrackingData = {} -- Данные по игрокам
local aimHoldTime = {} -- Время начала прицеливания
local aimStability = {} -- Стабильность прицеливания
local lastCameraDirection = {} -- Последнее направление взгляда

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
frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Основной цвет черный
frame.BackgroundTransparency = 0.5 -- Делаем таблицу прозрачной
frame.BorderSizePixel = 0 -- Отключаем стандартную обводку
frame.Parent = screenGui

-- Добавляем белую обводку с округленными краями
local frameOutline = Instance.new("Frame")
frameOutline.Size = UDim2.new(1, 4, 1, 4)
frameOutline.Position = UDim2.new(0, -2, 0, -2)
frameOutline.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
frameOutline.BorderSizePixel = 0
frameOutline.ZIndex = -1

local frameOutlineCorner = Instance.new("UICorner")
frameOutlineCorner.CornerRadius = UDim.new(0, 10)
frameOutlineCorner.Parent = frameOutline

frameOutline.Parent = frame

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = frame

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
    button.Font = Enum.Font.GothamBold
    button.TextSize = 16
    button.Parent = scrollingFrame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 10)
    buttonCorner.Parent = button

    local lockLabel = Instance.new("TextLabel")
    lockLabel.Size = UDim2.new(0, 50, 1, 0)
    lockLabel.Position = UDim2.new(1, -50, 0, 0)
    lockLabel.BackgroundTransparency = 1
    lockLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    lockLabel.TextSize = 12 -- Уменьшили шрифт до 12
    lockLabel.Text = "LOCK"
    lockLabel.Visible = detectedAimLockUsers[player] or false
    lockLabel.Parent = button

    aimTrackingData[player] = { button = button, lockLabel = lockLabel }

    button.MouseButton1Click:Connect(function()
        if selectedPlayers[player] then
            selectedPlayers[player] = nil
            button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        else
            selectedPlayers[player] = true
            button.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            button.BackgroundTransparency = 0.5
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
instructionFrame.Size = UDim2.new(0, 250, 0, 150)
instructionFrame.Position = UDim2.new(0, 320, 0, 10)
instructionFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Основной цвет черный
instructionFrame.BackgroundTransparency = 0.5 -- Делаем таблицу прозрачной
instructionFrame.BorderSizePixel = 0 -- Отключаем стандартную обводку
instructionFrame.Parent = screenGui

-- Добавляем белую обводку с округленными краями
local instructionFrameOutline = Instance.new("Frame")
instructionFrameOutline.Size = UDim2.new(1, 4, 1, 4)
instructionFrameOutline.Position = UDim2.new(0, -2, 0, -2)
instructionFrameOutline.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
instructionFrameOutline.BorderSizePixel = 0
instructionFrameOutline.ZIndex = -1

local instructionFrameOutlineCorner = Instance.new("UICorner")
instructionFrameOutlineCorner.CornerRadius = UDim.new(0, 10)
instructionFrameOutlineCorner.Parent = instructionFrameOutline

instructionFrameOutline.Parent = instructionFrame

local uiCornerInstruction = Instance.new("UICorner")
uiCornerInstruction.CornerRadius = UDim.new(0, 10)
uiCornerInstruction.Parent = instructionFrame

makeDraggable(instructionFrame)

local instructionLabel = Instance.new("TextLabel")
instructionLabel.Size = UDim2.new(1, 0, 0, 120)
instructionLabel.BackgroundTransparency = 1
instructionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
instructionLabel.TextSize = 14
instructionLabel.Font = Enum.Font.GothamBold
instructionLabel.Text = "Инструкция:\n" ..
                        "F - Вкл/выкл аим лока\n" ..
                        "K - Переключить режим аим лока\n" ..
                        "M - Скрыть/показать таблицы\n" ..
                        "N - Сбросить цели"
instructionLabel.TextWrapped = true
instructionLabel.Parent = instructionFrame

local authorLabel = Instance.new("TextLabel")
authorLabel.Size = UDim2.new(1, 0, 0, 30)
authorLabel.Position = UDim2.new(0, 0, 0.8, 0)
authorLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
authorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
authorLabel.TextSize = 12
authorLabel.Font = Enum.Font.GothamBold
authorLabel.Text = "Создано игроком Nano"
authorLabel.TextWrapped = true
authorLabel.Parent = instructionFrame

local authorCorner = Instance.new("UICorner")
authorCorner.CornerRadius = UDim.new(0, 10)
authorCorner.Parent = authorLabel

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

-- Сброс aimLockEnabled при смерти игрока
LocalPlayer.CharacterAdded:Connect(function(character)
    aimLockEnabled = false
    targetPlayer = nil
end)

local function trackAimingBehavior()
    RunService.RenderStepped:Connect(function()
        if not aimLockEnabled or not targetPlayer or not targetPlayer.Character then
            return
        end

        local cameraDirection = Camera.CFrame.LookVector
        local rootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        -- Проверяем резкие повороты камеры
        if lastCameraDirection[targetPlayer] then
            local angleDiff = math.deg(math.acos(lastCameraDirection[targetPlayer]:Dot(cameraDirection)))
            if angleDiff > 80 then -- Увеличили порог резкого поворота
                detectedAimLockUsers[targetPlayer] = true
            end
        end
        lastCameraDirection[targetPlayer] = cameraDirection

        -- Проверяем, насколько долго прицел зафиксирован на цели
        local targetPos = rootPart.Position
        local directionToTarget = (targetPos - Camera.CFrame.Position).Unit
        local angleToTarget = math.deg(math.acos(cameraDirection:Dot(directionToTarget)))

        if angleToTarget <= 3 then -- Разрешаем небольшие отклонения
            if not aimHoldTime[targetPlayer] then
                aimHoldTime[targetPlayer] = tick()
                aimStability[targetPlayer] = 0
            else
                aimStability[targetPlayer] = aimStability[targetPlayer] + 1
                if tick() - aimHoldTime[targetPlayer] >= AimHoldDuration and aimStability[targetPlayer] >= StabilityFrameCount then
                    if tick() - aimHoldTime[targetPlayer] >= aimLockHoldThreshold and (tick() - aimHoldTime[targetPlayer]) > 0.6 then
                        detectedAimLockUsers[targetPlayer] = true
                    end
                end
            end
        else
            aimHoldTime[targetPlayer] = nil
            aimStability[targetPlayer] = 0
        end

        -- Обновляем отображение "LOCK"
        if detectedAimLockUsers[targetPlayer] and aimTrackingData[targetPlayer] then
            aimTrackingData[targetPlayer].lockLabel.Visible = true
        end
    end)
end

trackAimingBehavior()
