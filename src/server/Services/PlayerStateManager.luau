--!strict
--[[
    PlayerStateManager.luau
    Authoritative state machine and runtime memory manager for players in ALIEN: NIGHTFALL.
    Strictly enforces valid state transitions and synchronizes state to clients
    via typed remote events and lightweight Roblox Attributes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.PlayerTypes)
local PlayerConfig = require(ReplicatedStorage.AlienNightfall.Config.PlayerConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

export type PlayerState = PlayerTypes.PlayerState
export type MovementState = PlayerTypes.MovementState
export type PlayerRuntimeData = PlayerTypes.PlayerRuntimeData

local PlayerStateManager = {
    Name = "PlayerStateManager",
    StateChanged = Signal.new(),        -- (player: Player, oldState: PlayerState, newState: PlayerState)
    MovementChanged = Signal.new(),     -- (player: Player, oldMovement: MovementState, newMovement: MovementState)
    _runtimeData = {} :: { [number]: PlayerRuntimeData },
}

function PlayerStateManager:OnInit()
    print("[PlayerStateManager] Initialized.")
end

function PlayerStateManager:OnStart()
    print("[PlayerStateManager] Started.")
end

function PlayerStateManager:InitRuntimeData(player: Player): PlayerRuntimeData
    local existing = self._runtimeData[player.UserId]
    if existing then
        return existing
    end

    local runtimeData: PlayerRuntimeData = {
        Player = player,
        UserId = player.UserId,
        State = "LOBBY",
        MovementState = "WALKING",
        Health = PlayerConfig.Health.DefaultHealth,
        MaxHealth = PlayerConfig.Health.MaxHealth,
        Stamina = PlayerConfig.Stamina.DefaultStamina,
        MaxStamina = PlayerConfig.Stamina.MaxStamina,
        IsSprinting = false,
        IsDowned = false,
        IsAlive = false,
        CurrentZone = PlayerConfig.Zones.DefaultZone,
        CurrentMission = nil,
        TeamId = nil,
        LastSafePosition = Vector3.zero,
        LastDamageTimestamp = 0,
        LastStaminaDrainTimestamp = 0,
        DownedTimestamp = nil,
        DownedTimerRemaining = nil,
        RevivingPlayer = nil,
        ReviveProgressSeconds = 0,
        InteractionLock = false,
        SpawnTimestamp = 0,
        EquippedSlot = 1,
    }

    self._runtimeData[player.UserId] = runtimeData
    self:_SyncAttributes(player, runtimeData)

    return runtimeData
end

function PlayerStateManager:CleanupRuntimeData(player: Player)
    self._runtimeData[player.UserId] = nil
end

function PlayerStateManager:GetRuntimeData(player: Player): PlayerRuntimeData?
    return self._runtimeData[player.UserId]
end

function PlayerStateManager:GetState(player: Player): PlayerState
    local data = self._runtimeData[player.UserId]
    return data and data.State or "LOBBY"
end

function PlayerStateManager:GetMovementState(player: Player): MovementState
    local data = self._runtimeData[player.UserId]
    return data and data.MovementState or "WALKING"
end

function PlayerStateManager:CanTransition(player: Player, newState: PlayerState): (boolean, string?)
    local data = self._runtimeData[player.UserId]
    if not data then
        return false, "Player runtime data does not exist"
    end

    local currentState = data.State
    if currentState == newState then
        return true, nil
    end

    local validNextStates = PlayerConfig.StateTransitions[currentState]
    if not validNextStates or not validNextStates[newState] then
        return false, string.format("Invalid transition from %s to %s", currentState, newState)
    end

    -- Additional domain logic validations
    if newState == "SPRINTING" then
        if data.IsDowned or not data.IsAlive or data.InteractionLock then
            return false, "Cannot sprint while downed, dead, or interacting"
        end
        if data.Stamina < PlayerConfig.Stamina.MinimumSprintStamina then
            return false, "Insufficient stamina to sprint"
        end
    end

    if newState == "INTERACTING" then
        if data.IsDowned or not data.IsAlive then
            return false, "Cannot interact while downed or dead"
        end
    end

    return true, nil
end

function PlayerStateManager:SetState(player: Player, newState: PlayerState): boolean
    local data = self._runtimeData[player.UserId]
    if not data then return false end

    local allowed, reason = self:CanTransition(player, newState)
    if not allowed then
        warn(string.format("[PlayerStateManager] Transition rejected for %s: %s", player.Name, reason or "Unknown"))
        return false
    end

    local oldState = data.State
    if oldState == newState then
        return true
    end

    data.State = newState

    -- Update derived booleans
    if newState == "ALIVE" then
        data.IsAlive = true
        data.IsDowned = false
        data.IsSprinting = false
        data.MovementState = "WALKING"
    elseif newState == "SPRINTING" then
        data.IsSprinting = true
        data.MovementState = "SPRINTING"
    elseif newState == "DOWNED" then
        data.IsDowned = true
        data.IsSprinting = false
        data.MovementState = "DOWNED"
    elseif newState == "DEAD" then
        data.IsAlive = false
        data.IsDowned = false
        data.IsSprinting = false
        data.MovementState = "DEAD"
    elseif newState == "SPECTATING" then
        data.IsAlive = false
        data.IsDowned = false
        data.IsSprinting = false
        data.MovementState = "SPECTATING"
    elseif newState == "LOBBY" or newState == "SPAWNING" then
        data.IsSprinting = false
        data.MovementState = "WALKING"
    end

    self:_SyncAttributes(player, data)
    self.StateChanged:Fire(player, oldState, newState)

    -- Replicate to client
    NetworkProtocol.ServerFireClient(player, "PlayerRemotes", "StateChanged", {
        OldState = oldState,
        NewState = newState,
        MovementState = data.MovementState,
    })

    return true
end

function PlayerStateManager:SetMovementState(player: Player, newMovement: MovementState): boolean
    local data = self._runtimeData[player.UserId]
    if not data then return false end

    local oldMovement = data.MovementState
    if oldMovement == newMovement then return true end

    data.MovementState = newMovement
    self:_SyncAttributes(player, data)
    self.MovementChanged:Fire(player, oldMovement, newMovement)

    return true
end

function PlayerStateManager:SetInteractionLock(player: Player, locked: boolean)
    local data = self._runtimeData[player.UserId]
    if data then
        data.InteractionLock = locked
    end
end

function PlayerStateManager:_SyncAttributes(player: Player, data: PlayerRuntimeData)
    -- Lightweight Roblox Attributes for simple read access
    player:SetAttribute("PlayerState", data.State)
    player:SetAttribute("MovementState", data.MovementState)
    player:SetAttribute("IsDowned", data.IsDowned)
    player:SetAttribute("IsSprinting", data.IsSprinting)
    player:SetAttribute("CurrentZone", data.CurrentZone)

    local char = player.Character
    if char then
        char:SetAttribute("PlayerState", data.State)
        char:SetAttribute("MovementState", data.MovementState)
        char:SetAttribute("IsDowned", data.IsDowned)
        char:SetAttribute("IsSprinting", data.IsSprinting)
    end
end

return PlayerStateManager
