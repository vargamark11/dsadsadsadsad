--!strict
--[[
    StaminaService.luau
    Authoritative stamina simulation and sprint verification engine.
    Uses a single centralized server update loop to prevent per-player heartbeat overhead.
    Enforces recovery delay, drain thresholds, and anti-exhaustion cutoffs.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerConfig = require(ReplicatedStorage.AlienNightfall.Config.PlayerConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)
local ServiceManager = require(script.Parent.Parent.ServiceManager)

local StaminaService = {
    Name = "StaminaService",
    StaminaChanged = Signal.new(),    -- (player: Player, current: number, max: number)
    SprintStarted = Signal.new(),     -- (player: Player)
    SprintStopped = Signal.new(),     -- (player: Player, reason: string?)
    _heartbeatConnection = nil :: RBXScriptConnection?,
    _syncAccumulator = 0,
}

function StaminaService:OnInit()
    print("[StaminaService] Initialized.")
end

function StaminaService:OnStart()
    -- Centralized single heartbeat connection for all players
    self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
        self:_Update(dt)
    end)
    print("[StaminaService] Centralized update loop started.")
end

function StaminaService:GetStamina(player: Player): (number, number)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then
        return 0, PlayerConfig.Stamina.MaxStamina
    end
    return data.Stamina, data.MaxStamina
end

function StaminaService:SetStamina(player: Player, newStamina: number)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then return end

    local clamped = math.clamp(newStamina, 0, data.MaxStamina)
    if data.Stamina ~= clamped then
        data.Stamina = clamped
        self.StaminaChanged:Fire(player, clamped, data.MaxStamina)
    end
end

function StaminaService:RequestSprint(player: Player, wantsToSprint: boolean): boolean
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then return false end

    if wantsToSprint then
        return self:StartSprint(player)
    else
        self:StopSprint(player, "USER_RELEASE")
        return true
    end
end

function StaminaService:StartSprint(player: Player): boolean
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local CharacterService = ServiceManager.GetService("CharacterService") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then return false end

    -- Authoritative validation checks
    if not data.IsAlive or data.IsDowned or data.State == "DEAD" then
        return false
    end

    if data.InteractionLock then
        return false
    end

    if data.Stamina < PlayerConfig.Stamina.MinimumSprintStamina then
        return false
    end

    if data.IsSprinting then
        return true
    end

    data.IsSprinting = true
    data.LastStaminaDrainTimestamp = os.clock()
    PlayerStateManager:SetState(player, "SPRINTING")
    PlayerStateManager:SetMovementState(player, "SPRINTING")

    if CharacterService then
        CharacterService:SetWalkSpeed(player, PlayerConfig.Movement.SprintSpeed)
    end

    self.SprintStarted:Fire(player)
    self:_SyncStamina(player, data)
    return true
end

function StaminaService:StopSprint(player: Player, reason: string?)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local CharacterService = ServiceManager.GetService("CharacterService") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data or not data.IsSprinting then return end

    data.IsSprinting = false
    data.LastStaminaDrainTimestamp = os.clock()

    if data.State == "SPRINTING" then
        PlayerStateManager:SetState(player, "ALIVE")
    end

    if data.MovementState == "SPRINTING" then
        PlayerStateManager:SetMovementState(player, "WALKING")
    end

    if CharacterService and data.IsAlive and not data.IsDowned then
        CharacterService:SetWalkSpeed(player, PlayerConfig.Movement.WalkSpeed)
    end

    self.SprintStopped:Fire(player, reason)
    self:_SyncStamina(player, data)
end

function StaminaService:ResetForSpawn(player: Player)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then return end

    data.Stamina = PlayerConfig.Stamina.DefaultStamina
    data.MaxStamina = PlayerConfig.Stamina.MaxStamina
    data.IsSprinting = false
    data.LastStaminaDrainTimestamp = 0
    self:_SyncStamina(player, data)
end

function StaminaService:_Update(dt: number)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    if not PlayerStateManager then return end

    local now = os.clock()
    self._syncAccumulator += dt
    local shouldSyncNetwork = self._syncAccumulator >= 0.1 -- 10Hz network sync

    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        local data = PlayerStateManager:GetRuntimeData(player)
        if data and data.IsAlive and not data.IsDowned then
            if data.IsSprinting then
                -- Drain stamina
                local drainAmount = PlayerConfig.Stamina.SprintDrainRate * dt
                local newStamina = math.max(0, data.Stamina - drainAmount)
                data.Stamina = newStamina
                data.LastStaminaDrainTimestamp = now

                if newStamina <= 0 then
                    self:StopSprint(player, "EXHAUSTED")
                end

                if shouldSyncNetwork then
                    self:_SyncStamina(player, data)
                end
            else
                -- Recover stamina if past delay
                local elapsedSinceDrain = now - data.LastStaminaDrainTimestamp
                if elapsedSinceDrain >= PlayerConfig.Stamina.RecoveryDelay and data.Stamina < data.MaxStamina then
                    local recoveryAmount = PlayerConfig.Stamina.StaminaRecoveryRate * dt
                    data.Stamina = math.min(data.MaxStamina, data.Stamina + recoveryAmount)

                    if shouldSyncNetwork then
                        self:_SyncStamina(player, data)
                    end
                end
            end
        end
    end

    if shouldSyncNetwork then
        self._syncAccumulator = 0
    end
end

function StaminaService:_SyncStamina(player: Player, data: any)
    NetworkProtocol.ServerFireClient(player, "PlayerRemotes", "PlayerStateSync", {
        Health = data.Health,
        MaxHealth = data.MaxHealth,
        Stamina = math.floor(data.Stamina),
        MaxStamina = data.MaxStamina,
        IsSprinting = data.IsSprinting,
        IsDowned = data.IsDowned,
        DownedTimerRemaining = data.DownedTimerRemaining,
    })
end

return StaminaService
