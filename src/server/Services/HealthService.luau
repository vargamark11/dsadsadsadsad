--!strict
--[[
    HealthService.luau
    Authoritative player health, damage processing, healing, and mortality evaluator.
    Coordinates directly with PlayerStateManager and CharacterService.
    Blocks client attempts to modify health values directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerConfig = require(ReplicatedStorage.AlienNightfall.Config.PlayerConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)
local ServiceManager = require(script.Parent.Parent.ServiceManager)

local HealthService = {
    Name = "HealthService",
    HealthChanged = Signal.new(),    -- (player: Player, oldHealth: number, newHealth: number, maxHealth: number)
    PlayerDamaged = Signal.new(),    -- (player: Player, amount: number, damageSource: string?)
    PlayerHealed = Signal.new(),     -- (player: Player, amount: number, healSource: string?)
    PlayerDowned = Signal.new(),     -- (player: Player)
    PlayerRevived = Signal.new(),    -- (player: Player)
    PlayerDied = Signal.new(),       -- (player: Player)
}

function HealthService:OnInit()
    print("[HealthService] Initialized.")
end

function HealthService:OnStart()
    print("[HealthService] Started.")
end

function HealthService:GetHealth(player: Player): (number, number)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then
        return 0, PlayerConfig.Health.MaxHealth
    end
    return data.Health, data.MaxHealth
end

function HealthService:IsAlive(player: Player): boolean
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    return data ~= nil and data.IsAlive and not data.IsDowned
end

function HealthService:SetHealth(player: Player, newHealth: number): boolean
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local CharacterService = ServiceManager.GetService("CharacterService") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then return false end

    local oldHealth = data.Health
    local clampedHealth = math.clamp(newHealth, PlayerConfig.Health.MinHealth, data.MaxHealth)
    if oldHealth == clampedHealth then return true end

    data.Health = clampedHealth

    -- Synchronize physical Roblox Humanoid
    local humanoid = CharacterService and CharacterService:GetHumanoid(player)
    if humanoid then
        humanoid.Health = math.max(1, clampedHealth) -- Maintain humanoid alive if in downed state
    end

    self.HealthChanged:Fire(player, oldHealth, clampedHealth, data.MaxHealth)

    -- Handle lethal damage
    if clampedHealth <= PlayerConfig.Health.MinHealth then
        if not data.IsDowned and data.State ~= "DEAD" then
            self:SetDowned(player, true)
        elseif data.IsDowned then
            self:KillPlayer(player)
        end
    end

    self:_SyncHealthToClient(player, data)
    return true
end

function HealthService:DamagePlayer(player: Player, amount: number, damageSource: string?): boolean
    if amount <= 0 then return false end
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data or not data.IsAlive or data.State == "DEAD" then
        return false
    end

    data.LastDamageTimestamp = os.clock()
    local targetHealth = data.Health - amount

    self.PlayerDamaged:Fire(player, amount, damageSource)
    self:SetHealth(player, targetHealth)
    return true
end

function HealthService:HealPlayer(player: Player, amount: number, healSource: string?): boolean
    if amount <= 0 then return false end
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data or data.IsDowned or not data.IsAlive or data.State == "DEAD" then
        return false
    end

    if data.Health >= data.MaxHealth then
        return false
    end

    local targetHealth = data.Health + amount
    self.PlayerHealed:Fire(player, amount, healSource)
    self:SetHealth(player, targetHealth)
    return true
end

function HealthService:SetDowned(player: Player, isDowned: boolean)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local CharacterService = ServiceManager.GetService("CharacterService") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then return end

    if isDowned then
        data.IsDowned = true
        data.DownedTimestamp = os.clock()
        data.DownedTimerRemaining = PlayerConfig.Downed.BleedoutDuration
        data.Health = 0
        PlayerStateManager:SetState(player, "DOWNED")

        if CharacterService then
            CharacterService:SetWalkSpeed(player, PlayerConfig.Movement.DownedSpeed)
        end

        self.PlayerDowned:Fire(player)

        NetworkProtocol.ServerFireAllClients("PlayerRemotes", "DownedNotice", {
            UserId = player.UserId,
            PlayerName = player.Name,
            IsDowned = true,
            Position = CharacterService and CharacterService:GetPosition(player) or Vector3.zero,
        })
    else
        data.IsDowned = false
        data.DownedTimestamp = nil
        data.DownedTimerRemaining = nil
        data.Health = math.floor(data.MaxHealth * PlayerConfig.Health.RevivedHealthPercent)
        PlayerStateManager:SetState(player, "ALIVE")

        if CharacterService then
            CharacterService:SetWalkSpeed(player, PlayerConfig.Movement.WalkSpeed)
        end

        self.PlayerRevived:Fire(player)

        NetworkProtocol.ServerFireAllClients("PlayerRemotes", "DownedNotice", {
            UserId = player.UserId,
            PlayerName = player.Name,
            IsDowned = false,
        })
    end

    self:_SyncHealthToClient(player, data)
end

function HealthService:KillPlayer(player: Player)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local CharacterService = ServiceManager.GetService("CharacterService") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then return end

    data.Health = 0
    data.IsAlive = false
    data.IsDowned = false
    data.DownedTimestamp = nil
    data.DownedTimerRemaining = nil

    PlayerStateManager:SetState(player, "DEAD")

    local humanoid = CharacterService and CharacterService:GetHumanoid(player)
    if humanoid then
        humanoid.Health = 0
    end

    self.PlayerDied:Fire(player)
    self:_SyncHealthToClient(player, data)
end

function HealthService:ResetForSpawn(player: Player)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local CharacterService = ServiceManager.GetService("CharacterService") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if not data then return end

    data.Health = PlayerConfig.Health.RespawnHealth
    data.MaxHealth = PlayerConfig.Health.MaxHealth
    data.IsAlive = true
    data.IsDowned = false
    data.DownedTimestamp = nil
    data.DownedTimerRemaining = nil
    data.ReviveProgressSeconds = 0
    data.RevivingPlayer = nil

    PlayerStateManager:SetState(player, "ALIVE")

    if CharacterService then
        CharacterService:SetWalkSpeed(player, PlayerConfig.Movement.WalkSpeed)
    end

    self:_SyncHealthToClient(player, data)
end

function HealthService:_SyncHealthToClient(player: Player, data: any)
    NetworkProtocol.ServerFireClient(player, "PlayerRemotes", "PlayerStateSync", {
        Health = data.Health,
        MaxHealth = data.MaxHealth,
        Stamina = data.Stamina,
        MaxStamina = data.MaxStamina,
        IsSprinting = data.IsSprinting,
        IsDowned = data.IsDowned,
        DownedTimerRemaining = data.DownedTimerRemaining,
    })
end

return HealthService
