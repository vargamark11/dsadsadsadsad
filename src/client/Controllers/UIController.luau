--!strict
--[[
    UIController.luau
    Master client user interface coordinator for ALIEN: NIGHTFALL.
    Constructs and manages the survival HUD, health/stamina gauges, ammunition display,
    objective trackers, hit markers, and downed status overlays.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ControllerManager = require(script.Parent.Parent.ControllerManager)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local UIController = {
    Name = "UIController",
    _screenGui = nil :: ScreenGui?,
    _healthBarFill = nil :: Frame?,
    _healthLabel = nil :: TextLabel?,
    _staminaBarFill = nil :: Frame?,
    _ammoLabel = nil :: TextLabel?,
    _weaponLabel = nil :: TextLabel?,
    _objectiveTitleLabel = nil :: TextLabel?,
    _objectiveDescLabel = nil :: TextLabel?,
    _downedFrame = nil :: Frame?,
    _downedTimerLabel = nil :: TextLabel?,
    _stateLabel = nil :: TextLabel?,
    _zoneLabel = nil :: TextLabel?,
    _alertBanner = nil :: Frame?,
    _alertText = nil :: TextLabel?,
    _hitMarker = nil :: Frame?,
}

function UIController:OnInit()
    self:_BuildHUD()
    print("[UIController] Initialized.")
end

function UIController:OnStart()
    local PlayerController = ControllerManager.GetController("PlayerController") :: any
    local WeaponController = ControllerManager.GetController("WeaponController") :: any
    local MissionController = ControllerManager.GetController("MissionController") :: any

    -- Connect health & stamina updates
    if PlayerController then
        PlayerController.StateUpdated:Connect(function(state: any)
            self:UpdateHealthAndStamina(state.Health, state.MaxHealth, state.Stamina, state.MaxStamina)
            self:UpdateDownedState(state.IsDowned, state.DownedTimerRemaining)
            self:UpdatePlayerState(state.State, state.MovementState)
            self:UpdateZone(state.CurrentZone)
        end)

        PlayerController.ZoneUpdated:Connect(function(zoneData: any)
            self:UpdateZone(zoneData.NewZone or zoneData.DisplayName or "LandingBase")
        end)
    end

    -- Connect ammo updates
    if WeaponController then
        WeaponController.AmmoUpdated:Connect(function(current: number, reserve: number)
            self:UpdateAmmo(current, reserve)
        end)

        WeaponController.HitConfirmed:Connect(function(hitData: any)
            self:ShowHitMarker(hitData.IsHeadshot == true)
        end)
    end

    -- Connect mission updates
    if MissionController then
        MissionController.MissionUpdated:Connect(function(chainTitle: string, mission: any)
            self:UpdateMissionHUD(chainTitle, mission)
        end)
    end

    -- Connect admin/event notice
    NetworkProtocol.ClientConnectEvent("AdminRemotes", "AdminNotice", function(notice: any)
        self:ShowColonyAlert(notice.Title or "ALERT", notice.Message or "")
    end)

    print("[UIController] Started.")
end

function UIController:_BuildHUD()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AlienNightfall_HUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    self._screenGui = screenGui

    -- 1. Status Gauges (Bottom Left)
    local statusFrame = Instance.new("Frame")
    statusFrame.Name = "StatusFrame"
    statusFrame.Size = UDim2.new(0, 280, 0, 96)
    statusFrame.Position = UDim2.new(0, 24, 1, -120)
    statusFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
    statusFrame.BackgroundTransparency = 0.35
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = screenGui

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = statusFrame

    -- Health Bar Background
    local healthBg = Instance.new("Frame")
    healthBg.Name = "HealthBg"
    healthBg.Size = UDim2.new(1, -24, 0, 16)
    healthBg.Position = UDim2.new(0, 12, 0, 14)
    healthBg.BackgroundColor3 = Color3.fromRGB(30, 35, 42)
    healthBg.BorderSizePixel = 0
    healthBg.Parent = statusFrame

    local healthCorner = Instance.new("UICorner")
    healthCorner.CornerRadius = UDim.new(0, 4)
    healthCorner.Parent = healthBg

    local healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBg
    self._healthBarFill = healthFill

    local healthFillCorner = Instance.new("UICorner")
    healthFillCorner.CornerRadius = UDim.new(0, 4)
    healthFillCorner.Parent = healthFill

    local healthLbl = Instance.new("TextLabel")
    healthLbl.Name = "HealthLabel"
    healthLbl.Size = UDim2.new(1, 0, 1, 0)
    healthLbl.BackgroundTransparency = 1
    healthLbl.Font = Enum.Font.GothamBold
    healthLbl.TextSize = 11
    healthLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthLbl.Text = "HP 100 / 100"
    healthLbl.Parent = healthBg
    self._healthLabel = healthLbl

    -- Stamina Bar Background
    local staminaBg = Instance.new("Frame")
    staminaBg.Name = "StaminaBg"
    staminaBg.Size = UDim2.new(1, -24, 0, 10)
    staminaBg.Position = UDim2.new(0, 12, 0, 38)
    staminaBg.BackgroundColor3 = Color3.fromRGB(30, 35, 42)
    staminaBg.BorderSizePixel = 0
    staminaBg.Parent = statusFrame

    local staminaCorner = Instance.new("UICorner")
    staminaCorner.CornerRadius = UDim.new(0, 4)
    staminaCorner.Parent = staminaBg

    local staminaFill = Instance.new("Frame")
    staminaFill.Name = "StaminaFill"
    staminaFill.Size = UDim2.new(1, 0, 1, 0)
    staminaFill.BackgroundColor3 = Color3.fromRGB(32, 201, 151)
    staminaFill.BorderSizePixel = 0
    staminaFill.Parent = staminaBg
    self._staminaBarFill = staminaFill

    local staminaFillCorner = Instance.new("UICorner")
    staminaFillCorner.CornerRadius = UDim.new(0, 4)
    staminaFillCorner.Parent = staminaFill

    -- Status State & Zone Badges
    local stateLbl = Instance.new("TextLabel")
    stateLbl.Name = "StateLabel"
    stateLbl.Size = UDim2.new(0.48, 0, 0, 20)
    stateLbl.Position = UDim2.new(0, 12, 0, 58)
    stateLbl.BackgroundTransparency = 1
    stateLbl.Font = Enum.Font.GothamBold
    stateLbl.TextSize = 10
    stateLbl.TextColor3 = Color3.fromRGB(120, 220, 180)
    stateLbl.TextXAlignment = Enum.TextXAlignment.Left
    stateLbl.Text = "STATE: ALIVE"
    stateLbl.Parent = statusFrame
    self._stateLabel = stateLbl

    local zoneLbl = Instance.new("TextLabel")
    zoneLbl.Name = "ZoneLabel"
    zoneLbl.Size = UDim2.new(0.48, 0, 0, 20)
    zoneLbl.Position = UDim2.new(0.5, 0, 0, 58)
    zoneLbl.BackgroundTransparency = 1
    zoneLbl.Font = Enum.Font.GothamBold
    zoneLbl.TextSize = 10
    zoneLbl.TextColor3 = Color3.fromRGB(150, 190, 255)
    zoneLbl.TextXAlignment = Enum.TextXAlignment.Right
    zoneLbl.Text = "ZONE: LandingBase"
    zoneLbl.Parent = statusFrame
    self._zoneLabel = zoneLbl

    -- 2. Ammunition & Weapon Indicator (Bottom Right)
    local ammoFrame = Instance.new("Frame")
    ammoFrame.Name = "AmmoFrame"
    ammoFrame.Size = UDim2.new(0, 200, 0, 80)
    ammoFrame.Position = UDim2.new(1, -224, 1, -104)
    ammoFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
    ammoFrame.BackgroundTransparency = 0.35
    ammoFrame.BorderSizePixel = 0
    ammoFrame.Parent = screenGui

    local ammoCorner = Instance.new("UICorner")
    ammoCorner.CornerRadius = UDim.new(0, 8)
    ammoCorner.Parent = ammoFrame

    local weaponLbl = Instance.new("TextLabel")
    weaponLbl.Name = "WeaponLabel"
    weaponLbl.Size = UDim2.new(1, -16, 0, 24)
    weaponLbl.Position = UDim2.new(0, 8, 0, 8)
    weaponLbl.BackgroundTransparency = 1
    weaponLbl.Font = Enum.Font.GothamBold
    weaponLbl.TextSize = 13
    weaponLbl.TextColor3 = Color3.fromRGB(180, 190, 205)
    weaponLbl.TextXAlignment = Enum.TextXAlignment.Right
    weaponLbl.Text = "P-12 SURVIVAL PISTOL"
    weaponLbl.Parent = ammoFrame
    self._weaponLabel = weaponLbl

    local ammoCountLbl = Instance.new("TextLabel")
    ammoCountLbl.Name = "AmmoCountLabel"
    ammoCountLbl.Size = UDim2.new(1, -16, 0, 36)
    ammoCountLbl.Position = UDim2.new(0, 8, 0, 32)
    ammoCountLbl.BackgroundTransparency = 1
    ammoCountLbl.Font = Enum.Font.GothamBlack
    ammoCountLbl.TextSize = 28
    ammoCountLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    ammoCountLbl.TextXAlignment = Enum.TextXAlignment.Right
    ammoCountLbl.Text = "12 / 60"
    ammoCountLbl.Parent = ammoFrame
    self._ammoLabel = ammoCountLbl

    -- 3. Mission Objectives HUD (Top Left)
    local missionFrame = Instance.new("Frame")
    missionFrame.Name = "MissionFrame"
    missionFrame.Size = UDim2.new(0, 320, 0, 90)
    missionFrame.Position = UDim2.new(0, 24, 0, 24)
    missionFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
    missionFrame.BackgroundTransparency = 0.35
    missionFrame.BorderSizePixel = 0
    missionFrame.Parent = screenGui

    local missionCorner = Instance.new("UICorner")
    missionCorner.CornerRadius = UDim.new(0, 8)
    missionCorner.Parent = missionFrame

    local missionHeader = Instance.new("TextLabel")
    missionHeader.Name = "MissionHeader"
    missionHeader.Size = UDim2.new(1, -20, 0, 22)
    missionHeader.Position = UDim2.new(0, 10, 0, 8)
    missionHeader.BackgroundTransparency = 1
    missionHeader.Font = Enum.Font.GothamBold
    missionHeader.TextSize = 13
    missionHeader.TextColor3 = Color3.fromRGB(255, 193, 7)
    missionHeader.TextXAlignment = Enum.TextXAlignment.Left
    missionHeader.Text = "ACTIVE MISSION: ESTABLISH COMMS"
    missionHeader.Parent = missionFrame
    self._objectiveTitleLabel = missionHeader

    local missionDesc = Instance.new("TextLabel")
    missionDesc.Name = "MissionDesc"
    missionDesc.Size = UDim2.new(1, -20, 0, 48)
    missionDesc.Position = UDim2.new(0, 10, 0, 32)
    missionDesc.BackgroundTransparency = 1
    missionDesc.Font = Enum.Font.Gotham
    missionDesc.TextSize = 12
    missionDesc.TextColor3 = Color3.fromRGB(220, 225, 235)
    missionDesc.TextXAlignment = Enum.TextXAlignment.Left
    missionDesc.TextYAlignment = Enum.TextYAlignment.Top
    missionDesc.TextWrapped = true
    missionDesc.Text = "• Restore power cells to the relay array (0/2)\n• Defend relay from alien swarm"
    missionDesc.Parent = missionFrame
    self._objectiveDescLabel = missionDesc

    -- 4. Hit Marker (Center)
    local hitMarker = Instance.new("Frame")
    hitMarker.Name = "HitMarker"
    hitMarker.Size = UDim2.new(0, 20, 0, 20)
    hitMarker.Position = UDim2.new(0.5, -10, 0.5, -10)
    hitMarker.BackgroundTransparency = 1
    hitMarker.Visible = false
    hitMarker.Parent = screenGui
    self._hitMarker = hitMarker

    -- 5. Downed Critical Bleedout Overlay
    local downedFrame = Instance.new("Frame")
    downedFrame.Name = "DownedFrame"
    downedFrame.Size = UDim2.new(1, 0, 1, 0)
    downedFrame.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    downedFrame.BackgroundTransparency = 0.85
    downedFrame.Visible = false
    downedFrame.Parent = screenGui
    self._downedFrame = downedFrame

    local downedLbl = Instance.new("TextLabel")
    downedLbl.Name = "DownedLabel"
    downedLbl.Size = UDim2.new(1, 0, 0, 40)
    downedLbl.Position = UDim2.new(0, 0, 0.5, -40)
    downedLbl.BackgroundTransparency = 1
    downedLbl.Font = Enum.Font.GothamBlack
    downedLbl.TextSize = 32
    downedLbl.TextColor3 = Color3.fromRGB(255, 50, 50)
    downedLbl.Text = "CRITICAL: DOWNED"
    downedLbl.Parent = downedFrame

    local downedSubLbl = Instance.new("TextLabel")
    downedSubLbl.Name = "DownedSubLabel"
    downedSubLbl.Size = UDim2.new(1, 0, 0, 24)
    downedSubLbl.Position = UDim2.new(0, 0, 0.5, 5)
    downedSubLbl.BackgroundTransparency = 1
    downedSubLbl.Font = Enum.Font.GothamBold
    downedSubLbl.TextSize = 16
    downedSubLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    downedSubLbl.Text = "Bleeding out... Awaiting teammate revive (45s)"
    downedSubLbl.Parent = downedFrame
    self._downedTimerLabel = downedSubLbl

    -- 6. Colony Alert Banner (Top Center)
    local alertFrame = Instance.new("Frame")
    alertFrame.Name = "AlertFrame"
    alertFrame.Size = UDim2.new(0, 500, 0, 50)
    alertFrame.Position = UDim2.new(0.5, -250, 0, -60) -- Off-screen by default
    alertFrame.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
    alertFrame.BorderSizePixel = 0
    alertFrame.Parent = screenGui
    self._alertBanner = alertFrame

    local alertCorner = Instance.new("UICorner")
    alertCorner.CornerRadius = UDim.new(0, 6)
    alertCorner.Parent = alertFrame

    local alertText = Instance.new("TextLabel")
    alertText.Name = "AlertText"
    alertText.Size = UDim2.new(1, -20, 1, 0)
    alertText.Position = UDim2.new(0, 10, 0, 0)
    alertText.BackgroundTransparency = 1
    alertText.Font = Enum.Font.GothamBlack
    alertText.TextSize = 15
    alertText.TextColor3 = Color3.fromRGB(255, 255, 255)
    alertText.Text = "COLONY ALERT"
    alertText.Parent = alertFrame
    self._alertText = alertText
end

function UIController:UpdateHealthAndStamina(health: number, maxHealth: number, stamina: number, maxStamina: number)
    if self._healthBarFill and self._healthLabel then
        local hpPercent = math.clamp(health / maxHealth, 0, 1)
        TweenService:Create(self._healthBarFill, TweenInfo.new(0.2), {
            Size = UDim2.new(hpPercent, 0, 1, 0),
        }):Play()
        self._healthLabel.Text = string.format("HP %d / %d", math.ceil(health), math.ceil(maxHealth))
    end

    if self._staminaBarFill then
        local stamPercent = math.clamp(stamina / maxStamina, 0, 1)
        TweenService:Create(self._staminaBarFill, TweenInfo.new(0.15), {
            Size = UDim2.new(stamPercent, 0, 1, 0),
        }):Play()
    end
end

function UIController:UpdateAmmo(current: number, reserve: number)
    if self._ammoLabel then
        self._ammoLabel.Text = string.format("%d / %d", current, reserve)
    end
end

function UIController:UpdateDownedState(isDowned: boolean, remainingSeconds: number?)
    if self._downedFrame then
        self._downedFrame.Visible = isDowned
        if isDowned and self._downedTimerLabel and remainingSeconds then
            self._downedTimerLabel.Text = string.format("Bleeding out... Awaiting teammate revive (%ds)", math.ceil(remainingSeconds))
        end
    end
end

function UIController:UpdateMissionHUD(chainTitle: string, mission: any)
    if self._objectiveTitleLabel then
        self._objectiveTitleLabel.Text = "MISSION: " .. chainTitle:upper()
    end
    if self._objectiveDescLabel and mission then
        local text = ""
        for i, obj in ipairs(mission.Objectives) do
            local status = obj.IsCompleted and "[DONE]" or string.format("[%d/%d]", obj.CurrentCount, obj.RequiredCount)
            text = text .. string.format("• %s %s\n", obj.Title, status)
        end
        self._objectiveDescLabel.Text = text
    end
end

function UIController:UpdatePlayerState(state: string, movementState: string?)
    if self._stateLabel then
        self._stateLabel.Text = string.format("STATE: %s", state or "ALIVE")
        if state == "DOWNED" then
            self._stateLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
        elseif state == "SPRINTING" then
            self._stateLabel.TextColor3 = Color3.fromRGB(255, 190, 60)
        elseif state == "DEAD" then
            self._stateLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        else
            self._stateLabel.TextColor3 = Color3.fromRGB(120, 220, 180)
        end
    end
end

function UIController:UpdateZone(zoneName: string)
    if self._zoneLabel then
        self._zoneLabel.Text = string.format("ZONE: %s", zoneName or "LandingBase")
        if zoneName == "LandingBase" then
            self._zoneLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
        else
            self._zoneLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        end
    end
end

function UIController:ShowHitMarker(isHeadshot: boolean)
    if not self._hitMarker then return end
    self._hitMarker.Visible = true
    task.delay(0.12, function()
        if self._hitMarker then
            self._hitMarker.Visible = false
        end
    end)
end

function UIController:ShowColonyAlert(title: string, message: string)
    if not self._alertBanner or not self._alertText then return end
    self._alertText.Text = string.format("%s: %s", title:upper(), message)

    local tweenIn = TweenService:Create(self._alertBanner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -250, 0, 30),
    })
    tweenIn:Play()

    task.delay(5.0, function()
        local tweenOut = TweenService:Create(self._alertBanner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -250, 0, -60),
        })
        tweenOut:Play()
    end)
end

return UIController
