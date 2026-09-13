--!strict
--[[
    PlayerController.luau
    Client-side character state predictor and synchronization listener in ALIEN: NIGHTFALL.
    Binds sprint inputs, monitors health/stamina, tracks world zone, and handles revive prompts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ControllerManager = require(script.Parent.Parent.ControllerManager)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

local localPlayer = Players.LocalPlayer

local PlayerController = {
    Name = "PlayerController",
    StateUpdated = Signal.new(),       -- (snapshot: any)
    ZoneUpdated = Signal.new(),        -- (zoneData: any)
    HealthUpdated = Signal.new(),      -- (health: number, maxHealth: number)
    StaminaUpdated = Signal.new(),     -- (stamina: number, maxStamina: number)
    _health = 100,
    _maxHealth = 100,
    _stamina = 100,
    _maxStamina = 100,
    _isSprinting = false,
    _isDowned = false,
    _state = "LOBBY",
    _currentZone = "LandingBase",
    _downedTimerRemaining = nil :: number?,
}

function PlayerController:OnInit()
    print("[PlayerController] Initialized.")
end

function PlayerController:OnStart()
    local InputController = ControllerManager.GetController("InputController") :: any
    local CameraController = ControllerManager.GetController("CameraController") :: any
    local AudioController = ControllerManager.GetController("AudioController") :: any

    -- Listen for sprint input via multi-platform abstraction
    if InputController then
        InputController.SprintToggled:Connect(function(isSprinting: boolean)
            if self._isDowned or self._state == "DEAD" then return end
            self._isSprinting = isSprinting

            -- Inform server
            NetworkProtocol.ClientFireServer("PlayerRemotes", "SprintRequest", isSprinting)

            if CameraController then
                CameraController:SetSprinting(isSprinting)
            end
        end)
    end

    -- Listen for server state replication
    NetworkProtocol.ClientConnectEvent("PlayerRemotes", "PlayerStateSync", function(payload: any)
        if not payload then return end

        if payload.Health ~= nil then
            local prevHealth = self._health
            self._health = payload.Health
            self._maxHealth = payload.MaxHealth or self._maxHealth

            if self._health < prevHealth and CameraController then
                CameraController:AddTrauma(0.4)
            end

            local isCritical = (self._health / self._maxHealth) < 0.25
            if AudioController then
                AudioController:SetLowHealthState(isCritical or self._isDowned)
            end

            self.HealthUpdated:Fire(self._health, self._maxHealth)
        end

        if payload.Stamina ~= nil then
            self._stamina = payload.Stamina
            self._maxStamina = payload.MaxStamina or self._maxStamina
            self.StaminaUpdated:Fire(self._stamina, self._maxStamina)
        end

        if payload.IsDowned ~= nil then
            self._isDowned = payload.IsDowned
            self._downedTimerRemaining = payload.DownedTimerRemaining
        end

        if payload.IsSprinting ~= nil then
            self._isSprinting = payload.IsSprinting
            if CameraController then
                CameraController:SetSprinting(self._isSprinting)
            end
        end

        self.StateUpdated:Fire({
            Health = self._health,
            MaxHealth = self._maxHealth,
            Stamina = self._stamina,
            MaxStamina = self._maxStamina,
            IsSprinting = self._isSprinting,
            IsDowned = self._isDowned,
            State = self._state,
            CurrentZone = self._currentZone,
            DownedTimerRemaining = self._downedTimerRemaining,
        })
    end)

    -- Listen for authoritative state machine transitions
    NetworkProtocol.ClientConnectEvent("PlayerRemotes", "StateChanged", function(payload: any)
        if not payload then return end
        self._state = payload.NewState or self._state

        if self._state == "DEAD" then
            self._isSprinting = false
            if CameraController then
                CameraController:SetSprinting(false)
            end
        end

        self.StateUpdated:Fire({
            Health = self._health,
            MaxHealth = self._maxHealth,
            Stamina = self._stamina,
            MaxStamina = self._maxStamina,
            IsSprinting = self._isSprinting,
            IsDowned = self._isDowned,
            State = self._state,
            CurrentZone = self._currentZone,
            DownedTimerRemaining = self._downedTimerRemaining,
        })
    end)

    -- Listen for player update attributes
    NetworkProtocol.ClientConnectEvent("PlayerRemotes", "PlayerUpdate", function(payload: any)
        if not payload then return end
        if payload.State then self._state = payload.State end
        if payload.CurrentZone then self._currentZone = payload.CurrentZone end
    end)

    -- Listen for world zone transitions
    NetworkProtocol.ClientConnectEvent("PlayerRemotes", "ZoneChanged", function(payload: any)
        if not payload then return end
        self._currentZone = payload.NewZone or self._currentZone
        self.ZoneUpdated:Fire(payload)
    end)

    print("[PlayerController] Started.")
end

function PlayerController:GetHealth(): (number, number)
    return self._health, self._maxHealth
end

function PlayerController:GetStamina(): (number, number)
    return self._stamina, self._maxStamina
end

function PlayerController:GetState(): string
    return self._state
end

function PlayerController:GetZone(): string
    return self._currentZone
end

function PlayerController:IsDowned(): boolean
    return self._isDowned
end

function PlayerController:IsAlive(): boolean
    return not self._isDowned and self._state ~= "DEAD"
end

function PlayerController:RequestRespawn()
    NetworkProtocol.ClientFireServer("PlayerRemotes", "RespawnRequest", {})
end

return PlayerController
