--!strict
--[[
    InteractionPromptController.luau
    Modern multi-platform prompt UI controller for ALIEN: NIGHTFALL.
    Renders context-sensitive key bindings, hold progress meters, requirement alerts,
    and feedback notifications adapting seamlessly to Desktop, Mobile, and Gamepad.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ControllerManager = require(script.Parent.Parent.ControllerManager)
local InteractionTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.InteractionTypes)

export type InteractionDefinition = InteractionTypes.InteractionDefinition
export type InteractResponse = InteractionTypes.InteractResponse

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local InteractionPromptController = {
    Name = "InteractionPromptController",

    _screenGui = nil :: ScreenGui?,
    _promptContainer = nil :: Frame?,
    _keyBadge = nil :: TextLabel?,
    _actionLabel = nil :: TextLabel?,
    _requirementLabel = nil :: TextLabel?,
    _progressBarFrame = nil :: Frame?,
    _progressBarFill = nil :: Frame?,
    _feedbackBanner = nil :: Frame?,
    _feedbackLabel = nil :: TextLabel?,
}

function InteractionPromptController:OnInit()
    self:_BuildPromptUI()
    print("[InteractionPromptController] Initialized.")
end

function InteractionPromptController:OnStart()
    local InteractionController = ControllerManager.GetController("InteractionController") :: any
    local InputController = ControllerManager.GetController("InputController") :: any

    if InteractionController then
        -- 1. Proximity target changes
        InteractionController.TargetChanged:Connect(function(target: InteractionDefinition?, distance: number?)
            local platform = (InputController and InputController:GetPlatform()) or "Desktop"
            self:UpdatePrompt(target, platform)
        end)

        -- 2. Hold progress updates
        InteractionController.HoldProgressChanged:Connect(function(progress: number, target: InteractionDefinition?)
            self:UpdateHoldProgress(progress)
        end)

        -- 3. Feedback notifications
        InteractionController.InteractionFeedback:Connect(function(response: InteractResponse)
            self:ShowFeedback(response)
        end)
    end

    print("[InteractionPromptController] Started.")
end

function InteractionPromptController:_BuildPromptUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AlienNightfall_InteractionPrompt"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    self._screenGui = screenGui

    -- 1. Master Prompt Frame (Bottom Center)
    local container = Instance.new("Frame")
    container.Name = "PromptContainer"
    container.Size = UDim2.new(0, 360, 0, 72)
    container.Position = UDim2.new(0.5, -180, 0.72, 0)
    container.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
    container.BackgroundTransparency = 0.25
    container.BorderSizePixel = 0
    container.Visible = false
    container.Parent = screenGui
    self._promptContainer = container

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(45, 60, 85)
    stroke.Thickness = 1.2
    stroke.Parent = container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = container

    -- 2. Key Indicator Badge (Left)
    local keyBadge = Instance.new("TextLabel")
    keyBadge.Name = "KeyBadge"
    keyBadge.Size = UDim2.new(0, 56, 0, 40)
    keyBadge.Position = UDim2.new(0, 12, 0.5, -20)
    keyBadge.BackgroundColor3 = Color3.fromRGB(24, 32, 48)
    keyBadge.BorderSizePixel = 0
    keyBadge.Font = Enum.Font.GothamBold
    keyBadge.Text = "[ E ]"
    keyBadge.TextColor3 = Color3.fromRGB(100, 220, 255)
    keyBadge.TextSize = 14
    keyBadge.Parent = container
    self._keyBadge = keyBadge

    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 6)
    keyCorner.Parent = keyBadge

    local keyStroke = Instance.new("UIStroke")
    keyStroke.Color = Color3.fromRGB(70, 95, 135)
    keyStroke.Thickness = 1
    keyStroke.Parent = keyBadge

    -- 3. Action Title
    local actionLabel = Instance.new("TextLabel")
    actionLabel.Name = "ActionLabel"
    actionLabel.Size = UDim2.new(1, -80, 0, 24)
    actionLabel.Position = UDim2.new(0, 76, 0, 12)
    actionLabel.BackgroundTransparency = 1
    actionLabel.Font = Enum.Font.GothamBold
    actionLabel.Text = "Interact with Object"
    actionLabel.TextColor3 = Color3.fromRGB(245, 250, 255)
    actionLabel.TextSize = 15
    actionLabel.TextXAlignment = Enum.TextXAlignment.Left
    actionLabel.Parent = container
    self._actionLabel = actionLabel

    -- 4. Requirement Subtitle
    local reqLabel = Instance.new("TextLabel")
    reqLabel.Name = "RequirementLabel"
    reqLabel.Size = UDim2.new(1, -80, 0, 18)
    reqLabel.Position = UDim2.new(0, 76, 0, 36)
    reqLabel.BackgroundTransparency = 1
    reqLabel.Font = Enum.Font.GothamMedium
    reqLabel.Text = "Standard Access"
    reqLabel.TextColor3 = Color3.fromRGB(150, 175, 205)
    reqLabel.TextSize = 12
    reqLabel.TextXAlignment = Enum.TextXAlignment.Left
    reqLabel.Parent = container
    self._requirementLabel = reqLabel

    -- 5. Hold Progress Meter (Bottom Edge)
    local progressFrame = Instance.new("Frame")
    progressFrame.Name = "ProgressFrame"
    progressFrame.Size = UDim2.new(1, 0, 0, 4)
    progressFrame.Position = UDim2.new(0, 0, 1, -4)
    progressFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    progressFrame.BorderSizePixel = 0
    progressFrame.Visible = false
    progressFrame.Parent = container
    self._progressBarFrame = progressFrame

    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(50, 205, 150)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressFrame
    self._progressBarFill = progressFill

    -- 6. Floating Feedback Banner
    local feedbackBanner = Instance.new("Frame")
    feedbackBanner.Name = "FeedbackBanner"
    feedbackBanner.Size = UDim2.new(0, 300, 0, 36)
    feedbackBanner.Position = UDim2.new(0.5, -150, 0.65, 0)
    feedbackBanner.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    feedbackBanner.BackgroundTransparency = 0.2
    feedbackBanner.BorderSizePixel = 0
    feedbackBanner.Visible = false
    feedbackBanner.Parent = screenGui
    self._feedbackBanner = feedbackBanner

    local fbCorner = Instance.new("UICorner")
    fbCorner.CornerRadius = UDim.new(0, 6)
    fbCorner.Parent = feedbackBanner

    local fbStroke = Instance.new("UIStroke")
    fbStroke.Color = Color3.fromRGB(60, 80, 110)
    fbStroke.Thickness = 1
    fbStroke.Parent = feedbackBanner

    local fbLabel = Instance.new("TextLabel")
    fbLabel.Name = "FeedbackLabel"
    fbLabel.Size = UDim2.new(1, -20, 1, 0)
    fbLabel.Position = UDim2.new(0, 10, 0, 0)
    fbLabel.BackgroundTransparency = 1
    fbLabel.Font = Enum.Font.GothamBold
    fbLabel.Text = "ACCESS GRANTED"
    fbLabel.TextColor3 = Color3.fromRGB(100, 255, 180)
    fbLabel.TextSize = 13
    fbLabel.Parent = feedbackBanner
    self._feedbackLabel = fbLabel
end

function InteractionPromptController:UpdatePrompt(target: InteractionDefinition?, platform: string)
    if not self._promptContainer or not self._keyBadge or not self._actionLabel or not self._requirementLabel then
        return
    end

    if not target then
        self._promptContainer.Visible = false
        if self._progressBarFrame then
            self._progressBarFrame.Visible = false
        end
        return
    end

    self._promptContainer.Visible = true

    -- 1. Format Key Badge based on Platform and Interaction Type
    local isHold = (target.Type == "HOLD" or target.Type == "PROGRESS" or target.Type == "MULTI_PLAYER")
    local keyText = "[ E ]"
    if platform == "Console" then
        keyText = isHold and "[ HOLD X ]" or "[ X ]"
    elseif platform == "Mobile" then
        keyText = isHold and "[ HOLD ]" or "[ TAP ]"
    else
        keyText = isHold and "[ HOLD E ]" or "[ E ]"
    end
    self._keyBadge.Text = keyText

    -- 2. Format Action Text
    self._actionLabel.Text = target.ActionText or target.Name

    -- 3. Format Requirement Subtitle
    if target.RequiredKeycardLevel then
        self._requirementLabel.Text = string.format("Clearance Required: Level %d", target.RequiredKeycardLevel)
        self._requirementLabel.TextColor3 = Color3.fromRGB(255, 190, 80)
    elseif target.RequiredItem then
        self._requirementLabel.Text = string.format("Item Required: %s", target.RequiredItem)
        self._requirementLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
    elseif target.Type == "MULTI_PLAYER" and target.MultiPlayer then
        self._requirementLabel.Text = string.format("Multi-Crew: %d Players Required", target.MultiPlayer.RequiredPlayers)
        self._requirementLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    elseif target.Attributes and target.Attributes.DoorState == "LOCKDOWN" then
        self._requirementLabel.Text = "EMERGENCY LOCKDOWN IN EFFECT"
        self._requirementLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
    else
        self._requirementLabel.Text = target.Name
        self._requirementLabel.TextColor3 = Color3.fromRGB(150, 175, 205)
    end
end

function InteractionPromptController:UpdateHoldProgress(progress: number)
    if not self._progressBarFrame or not self._progressBarFill then return end

    if progress > 0 and progress < 1 then
        self._progressBarFrame.Visible = true
        self._progressBarFill.Size = UDim2.new(progress, 0, 1, 0)
    else
        self._progressBarFrame.Visible = false
        self._progressBarFill.Size = UDim2.new(0, 0, 1, 0)
    end
end

function InteractionPromptController:ShowFeedback(response: InteractResponse)
    if not self._feedbackBanner or not self._feedbackLabel then return end

    local feedbackText = response.Message or response.Feedback
    local color = Color3.fromRGB(240, 240, 240)

    if response.Feedback == "ACCESS_GRANTED" or response.Feedback == "SUCCESS" then
        color = Color3.fromRGB(80, 240, 160)
    elseif response.Feedback == "ACCESS_DENIED" or response.Feedback == "LOCKED" then
        color = Color3.fromRGB(255, 80, 80)
    elseif response.Feedback == "TOO_FAR" or response.Feedback == "NO_LINE_OF_SIGHT" then
        color = Color3.fromRGB(255, 180, 70)
    elseif response.Feedback == "MISSING_ITEM" then
        color = Color3.fromRGB(255, 140, 70)
    elseif response.Feedback == "REQUIRES_MORE_PLAYERS" then
        color = Color3.fromRGB(100, 200, 255)
    end

    self._feedbackLabel.Text = feedbackText
    self._feedbackLabel.TextColor3 = color
    self._feedbackBanner.Visible = true

    task.delay(2.5, function()
        if self._feedbackBanner then
            self._feedbackBanner.Visible = false
        end
    end)
end

return InteractionPromptController
