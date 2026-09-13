--!strict
--[[
    UIController.luau
    Client HUD coordinator: manages health/stamina displays, interaction prompts, and bleedout alerts.
    Synchronized to StarterPlayer.StarterPlayerScripts.Controllers.UIController via Rojo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Utilities = require(Shared:WaitForChild("Utilities"))

local localPlayer = Players.LocalPlayer

local UIController = {
    Name = "UIController",
    _screenGui = nil :: ScreenGui?,
    _promptFrame = nil :: Frame?,
    _promptText = nil :: TextLabel?,
    _progressBar = nil :: Frame?,
    _healthBar = nil :: Frame?,
    _staminaBar = nil :: Frame?,
}

function UIController:OnInit()
    print("[UIController] Initialized client UI coordinator.")
end

function UIController:OnStart()
    local PlayerController = require(script.Parent:WaitForChild("PlayerController")) :: any
    local InteractionController = require(script.Parent:WaitForChild("InteractionController")) :: any

    self:_BuildHUD()

    PlayerController.StateUpdated:Connect(function(stats: any)
        self:_UpdateHUDStats(stats)
    end)

    InteractionController.FocusedTargetChanged:Connect(function(target: any)
        self:_UpdatePromptVisibility(target)
    end)

    InteractionController.HoldProgressChanged:Connect(function(progress: number, target: any)
        self:_UpdateHoldProgress(progress)
    end)
end

function UIController:_BuildHUD()
    local playerGui = localPlayer:WaitForChild("PlayerGui", 10) :: PlayerGui?
    if not playerGui then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AlienNightfallHUD"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui
    self._screenGui = gui

    -- Interaction Prompt Frame
    local prompt = Instance.new("Frame")
    prompt.Name = "PromptFrame"
    prompt.Size = UDim2.new(0, 260, 0, 60)
    prompt.Position = UDim2.new(0.5, -130, 0.65, 0)
    prompt.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    prompt.BackgroundTransparency = 0.25
    prompt.Visible = false
    prompt.Parent = gui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 110, 160)
    stroke.Thickness = 1.5
    stroke.Parent = prompt

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = prompt

    local label = Instance.new("TextLabel")
    label.Name = "ActionLabel"
    label.Size = UDim2.new(1, -20, 0, 30)
    label.Position = UDim2.new(0, 10, 0, 6)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(240, 240, 245)
    label.Text = "[E] INTERACT"
    label.Parent = prompt
    self._promptText = label

    local barBg = Instance.new("Frame")
    barBg.Name = "ProgressBarBg"
    barBg.Size = UDim2.new(1, -20, 0, 6)
    barBg.Position = UDim2.new(0, 10, 1, -14)
    barBg.BackgroundColor3 = Color3.fromRGB(35, 40, 50)
    barBg.BorderSizePixel = 0
    barBg.Parent = prompt

    local barFill = Instance.new("Frame")
    barFill.Name = "ProgressBarFill"
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    self._progressBar = barFill

    self._promptFrame = prompt
end

function UIController:_UpdateHUDStats(stats: any)
    -- Update HUD bars
end

function UIController:_UpdatePromptVisibility(target: any)
    if not self._promptFrame or not self._promptText then return end

    if target then
        self._promptFrame.Visible = true
        local key = if target.HoldDuration and target.HoldDuration > 0 then "[HOLD E]" else "[E]"
        self._promptText.Text = string.format("%s %s", key, string.upper(target.Name))
        if self._progressBar then
            self._progressBar.Size = UDim2.new(0, 0, 1, 0)
        end
    else
        self._promptFrame.Visible = false
    end
end

function UIController:_UpdateHoldProgress(progress: number)
    if self._progressBar then
        self._progressBar.Size = UDim2.new(progress, 0, 1, 0)
    end
end

return UIController
