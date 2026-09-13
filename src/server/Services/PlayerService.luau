--!strict
--[[
    PlayerService.luau
    Master coordinator for the Player System in ALIEN: NIGHTFALL.
    Orchestrates CharacterService, PlayerStateManager, HealthService,
    StaminaService, and ZoneService to maintain complete server authority.
    Handles player join/leave lifecycle, respawns, revives, and network endpoints.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.PlayerTypes)
local PlayerConfig = require(ReplicatedStorage.AlienNightfall.Config.PlayerConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

local PlayerService = {
    Name = "PlayerService",
    PlayerAdded = Signal.new(),        -- (player: Player)
    PlayerRemoving = Signal.new(),     -- (player: Player)
    PlayerSpawned = Signal.new(),      -- (player: Player, character: Model)
    PlayerDowned = Signal.new(),       -- (player: Player)
    PlayerRevived = Signal.new(),      -- (player: Player)
    PlayerDied = Signal.new(),         -- (player: Player)
    _bleedoutThread = nil :: thread?,
}

function PlayerService:OnInit()
    print("[PlayerService] Initialized coordinator.")
end

function PlayerService:OnStart()
    local CharacterService = ServiceManager.GetService("CharacterService") :: any
    local HealthService = ServiceManager.GetService("HealthService") :: any
    local StaminaService = ServiceManager.GetService("StaminaService") :: any
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any

    -- Forward signals from sub-services for external listeners
    if HealthService then
        HealthService.PlayerDowned:Connect(function(player: Player)
            self.PlayerDowned:Fire(player)
        end)
        HealthService.PlayerRevived:Connect(function(player: Player)
            self.PlayerRevived:Fire(player)
        end)
        HealthService.PlayerDied:Connect(function(player: Player)
            self.PlayerDied:Fire(player)
            self:_OnPlayerDied(player)
        end)
    end

    if CharacterService then
        CharacterService.CharacterSpawned:Connect(function(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
            self:_OnCharacterSpawned(player, character, humanoid, rootPart)
        end)
        CharacterService.CharacterDied:Connect(function(player: Player, character: Model)
            if HealthService then
                HealthService:KillPlayer(player)
            end
        end)
    end

    -- Connect Authoritative Network Endpoints
    NetworkProtocol.ServerConnectEvent("PlayerRemotes", "SprintRequest", function(player: Player, wantsSprint: any)
        if StaminaService then
            StaminaService:RequestSprint(player, wantsSprint == true)
        end
    end)

    NetworkProtocol.ServerConnectEvent("PlayerRemotes", "RespawnRequest", function(player: Player)
        self:RespawnPlayer(player)
    end)

    NetworkProtocol.ServerBindFunction("PlayerRemotes", "ReviveInteraction", function(player: Player, payload: any)
        return self:HandleReviveRequest(player, payload)
    end)

    -- Centralized Downed Bleedout Loop (no per-player loops)
    self._bleedoutThread = task.spawn(function()
        while true do
            local dt = task.wait(0.25)
            self:_UpdateDownedTimers(dt)
        end
    end)

    -- Bind existing players in case server was started late
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:OnPlayerAdded(player)
        end)
    end

    print("[PlayerService] Started coordinator and network bindings.")
end

function PlayerService:OnPlayerAdded(player: Player)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local CharacterService = ServiceManager.GetService("CharacterService") :: any
    local ZoneService = ServiceManager.GetService("ZoneService") :: any

    -- Initialize authoritative runtime data
    if PlayerStateManager then
        PlayerStateManager:InitRuntimeData(player)
    end

    if ZoneService then
        ZoneService:OnPlayerAdded(player)
    end

    if CharacterService then
        CharacterService:OnPlayerAdded(player)
    end

    self.PlayerAdded:Fire(player)

    -- Send initial state snapshot to client
    self:SyncLiveState(player)
end

function PlayerService:OnPlayerRemoving(player: Player)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local CharacterService = ServiceManager.GetService("CharacterService") :: any
    local ZoneService = ServiceManager.GetService("ZoneService") :: any

    self.PlayerRemoving:Fire(player)

    if CharacterService then
        CharacterService:OnPlayerRemoving(player)
    end

    if ZoneService then
        ZoneService:OnPlayerRemoving(player)
    end

    if PlayerStateManager then
        PlayerStateManager:CleanupRuntimeData(player)
    end
end

function PlayerService:_OnCharacterSpawned(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
    local HealthService = ServiceManager.GetService("HealthService") :: any
    local StaminaService = ServiceManager.GetService("StaminaService") :: any
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any

    if PlayerStateManager then
        PlayerStateManager:SetState(player, "SPAWNING")
    end

    -- Position character safely
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if data and data.LastSafePosition ~= Vector3.zero then
        rootPart.CFrame = CFrame.new(data.LastSafePosition + PlayerConfig.Respawn.SafeSpawnOffset)
    end

    -- Reset health, stamina, and movement systems
    if HealthService then
        HealthService:ResetForSpawn(player)
    end

    if StaminaService then
        StaminaService:ResetForSpawn(player)
    end

    self.PlayerSpawned:Fire(player, character)
    self:SyncLiveState(player)
end

function PlayerService:_OnPlayerDied(player: Player)
    -- Handle controlled respawn flow
    if PlayerConfig.Respawn.AutoRespawn then
        task.delay(PlayerConfig.Respawn.RespawnDelay, function()
            if player and player.Parent then
                self:RespawnPlayer(player)
            end
        end)
    end
end

function PlayerService:RespawnPlayer(player: Player): boolean
    local CharacterService = ServiceManager.GetService("CharacterService") :: any
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any

    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then return false end

    -- Reset downed flags
    data.IsDowned = false
    data.DownedTimestamp = nil
    data.DownedTimerRemaining = nil
    data.RevivingPlayer = nil
    data.ReviveProgressSeconds = 0

    if CharacterService then
        return CharacterService:Respawn(player)
    else
        player:LoadCharacter()
        return true
    end
end

function PlayerService:HandleReviveRequest(reviverPlayer: Player, payload: any): any
    if not payload or not payload.TargetUserId then
        return { Success = false, Error = "Missing TargetUserId in request" }
    end

    local targetPlayer = Players:GetPlayerByUserId(payload.TargetUserId)
    if not targetPlayer then
        return { Success = false, Error = "Target player not found in server" }
    end

    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local HealthService = ServiceManager.GetService("HealthService") :: any
    local CharacterService = ServiceManager.GetService("CharacterService") :: any

    local targetData = PlayerStateManager and PlayerStateManager:GetRuntimeData(targetPlayer)
    local reviverData = PlayerStateManager and PlayerStateManager:GetRuntimeData(reviverPlayer)

    if not targetData or not targetData.IsDowned then
        return { Success = false, Error = "Target is not in a downed state" }
    end

    if not reviverData or not reviverData.IsAlive or reviverData.IsDowned then
        return { Success = false, Error = "Reviver is unable to interact" }
    end

    -- Distance verification
    local reviverPos = CharacterService and CharacterService:GetPosition(reviverPlayer)
    local targetPos = CharacterService and CharacterService:GetPosition(targetPlayer)

    if not reviverPos or not targetPos then
        return { Success = false, Error = "Physical character positions unavailable" }
    end

    local distance = (reviverPos - targetPos).Magnitude
    if distance > PlayerConfig.Downed.MaxReviveDistance then
        return { Success = false, Error = "Target is beyond maximum revive distance" }
    end

    -- Increment revive progress
    targetData.RevivingPlayer = reviverPlayer
    targetData.ReviveProgressSeconds += PlayerConfig.Downed.ReviveProgressStep

    if targetData.ReviveProgressSeconds >= PlayerConfig.Downed.ReviveDuration then
        targetData.ReviveProgressSeconds = 0
        targetData.RevivingPlayer = nil

        if HealthService then
            HealthService:SetDowned(targetPlayer, false)
        end

        local ProgressionService = ServiceManager.GetService("ProgressionService") :: any
        if ProgressionService then
            ProgressionService:IncrementStat(reviverPlayer, "TeammatesRevived", 1)
            ProgressionService:AddXP(reviverPlayer, 150, "TEAM_REVIVE")
        end

        return { Success = true, Completed = true }
    end

    return {
        Success = true,
        Progress = targetData.ReviveProgressSeconds / PlayerConfig.Downed.ReviveDuration,
        Remaining = PlayerConfig.Downed.ReviveDuration - targetData.ReviveProgressSeconds,
    }
end

function PlayerService:_UpdateDownedTimers(dt: number)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local HealthService = ServiceManager.GetService("HealthService") :: any
    if not PlayerStateManager or not HealthService then return end

    for _, player in ipairs(Players:GetPlayers()) do
        local data = PlayerStateManager:GetRuntimeData(player)
        if data and data.IsDowned and data.DownedTimerRemaining then
            data.DownedTimerRemaining -= dt
            if data.DownedTimerRemaining <= 0 then
                -- Player bled out
                HealthService:KillPlayer(player)
            end
        end
    end
end

-- Compatibility API Wrappers (Ensures Phase 1 services run without modification)
function PlayerService:GetLiveState(player: Player): PlayerTypes.PlayerRuntimeData?
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    return PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
end

function PlayerService:GetRuntimeData(player: Player): PlayerTypes.PlayerRuntimeData?
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    return PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
end

function PlayerService:GetState(player: Player): PlayerTypes.PlayerState
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    return PlayerStateManager and PlayerStateManager:GetState(player) or "LOBBY"
end

function PlayerService:SetState(player: Player, newState: PlayerTypes.PlayerState): boolean
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    return PlayerStateManager and PlayerStateManager:SetState(player, newState) or false
end

function PlayerService:TakeDamage(player: Player, amount: number, damageSource: string?): boolean
    local HealthService = ServiceManager.GetService("HealthService") :: any
    return HealthService and HealthService:DamagePlayer(player, amount, damageSource) or false
end

function PlayerService:DamagePlayer(player: Player, amount: number, damageSource: string?): boolean
    local HealthService = ServiceManager.GetService("HealthService") :: any
    return HealthService and HealthService:DamagePlayer(player, amount, damageSource) or false
end

function PlayerService:Heal(player: Player, amount: number)
    local HealthService = ServiceManager.GetService("HealthService") :: any
    if HealthService then
        HealthService:HealPlayer(player, amount, "HEAL_SERVICE")
    end
end

function PlayerService:HealPlayer(player: Player, amount: number, source: string?): boolean
    local HealthService = ServiceManager.GetService("HealthService") :: any
    return HealthService and HealthService:HealPlayer(player, amount, source) or false
end

function PlayerService:SetHealth(player: Player, health: number): boolean
    local HealthService = ServiceManager.GetService("HealthService") :: any
    return HealthService and HealthService:SetHealth(player, health) or false
end

function PlayerService:GetHealth(player: Player): (number, number)
    local HealthService = ServiceManager.GetService("HealthService") :: any
    return HealthService and HealthService:GetHealth(player) or (0, PlayerConfig.Health.MaxHealth)
end

function PlayerService:IsAlive(player: Player): boolean
    local HealthService = ServiceManager.GetService("HealthService") :: any
    return HealthService and HealthService:IsAlive(player) or false
end

function PlayerService:SetSprinting(player: Player, isSprinting: boolean)
    local StaminaService = ServiceManager.GetService("StaminaService") :: any
    if StaminaService then
        StaminaService:RequestSprint(player, isSprinting)
    end
end

function PlayerService:SetDowned(player: Player, isDowned: boolean)
    local HealthService = ServiceManager.GetService("HealthService") :: any
    if HealthService then
        HealthService:SetDowned(player, isDowned)
    end
end

function PlayerService:SyncLiveState(player: Player)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then return end

    NetworkProtocol.ServerFireClient(player, "PlayerRemotes", "PlayerStateSync", {
        Health = data.Health,
        MaxHealth = data.MaxHealth,
        Stamina = math.floor(data.Stamina),
        MaxStamina = data.MaxStamina,
        IsSprinting = data.IsSprinting,
        IsDowned = data.IsDowned,
        DownedTimerRemaining = data.DownedTimerRemaining,
    })

    NetworkProtocol.ServerFireClient(player, "PlayerRemotes", "PlayerUpdate", {
        State = data.State,
        MovementState = data.MovementState,
        CurrentZone = data.CurrentZone,
    })
end

return PlayerService
