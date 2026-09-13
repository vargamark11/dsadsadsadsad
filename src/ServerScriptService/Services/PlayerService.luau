--!strict
--[[
    PlayerService.luau
    Master coordinator for Player System in ALIEN: NIGHTFALL.
    Maintains authoritative player health, stamina, movement, and life cycles.
    Synchronized to ServerScriptService.Services.PlayerService via Rojo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")

local Types = require(Shared:WaitForChild("Types"))
local PlayerConfig = require(Config:WaitForChild("PlayerConfig"))
local Constants = require(Shared:WaitForChild("Constants"))
local Utilities = require(Shared:WaitForChild("Utilities"))
local NetworkRemotes = require(Shared:WaitForChild("NetworkRemotes"))

type PlayerState = Types.PlayerState
type PlayerStats = Types.PlayerStats

type PlayerRecord = {
    Player: Player,
    Health: number,
    MaxHealth: number,
    Stamina: number,
    MaxStamina: number,
    IsSprinting: boolean,
    State: PlayerState,
    LastSprintTime: number,
    BleedoutTimeRemaining: number,
    ReviveProgress: number,
}

local PlayerService = {
    Name = "PlayerService",
    PlayerAdded = Utilities.CreateSignal(),
    PlayerRemoving = Utilities.CreateSignal(),
    PlayerDowned = Utilities.CreateSignal(),
    PlayerRevived = Utilities.CreateSignal(),
    PlayerDied = Utilities.CreateSignal(),

    _players = {} :: { [Player]: PlayerRecord },
    _rateLimiter = Utilities.CreateRateLimiter(10, 15),
}

function PlayerService:OnInit()
    print("[PlayerService] Initializing PlayerService authority.")
end

function PlayerService:OnStart()
    -- Connect Network Remotes
    local sprintEvent = NetworkRemotes.GetEvent("Player", "SprintRequest")
    local stateSyncEvent = NetworkRemotes.GetEvent("Player", "PlayerStateSync")
    local downedNoticeEvent = NetworkRemotes.GetEvent("Player", "DownedNotice")
    local reviveFunc = NetworkRemotes.GetFunction("Player", "ReviveInteraction")

    sprintEvent.OnServerEvent:Connect(function(player: Player, wantsSprint: any)
        self:_OnSprintRequest(player, wantsSprint == true)
    end)

    reviveFunc.OnServerInvoke = function(reviver: Player, targetPlayerName: any)
        return self:_OnReviveRequest(reviver, tostring(targetPlayerName))
    end

    Players.PlayerAdded:Connect(function(player: Player)
        self:_OnPlayerAdded(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self:_OnPlayerRemoving(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:_OnPlayerAdded(player)
    end

    -- Heartbeat loop for authoritative stamina drain/recovery and bleedout
    RunService.Heartbeat:Connect(function(dt: number)
        self:_UpdatePlayerStats(dt)
    end)
end

function PlayerService:_OnPlayerAdded(player: Player)
    local record: PlayerRecord = {
        Player = player,
        Health = PlayerConfig.DefaultHealth,
        MaxHealth = PlayerConfig.MaxHealth,
        Stamina = PlayerConfig.DefaultStamina,
        MaxStamina = PlayerConfig.MaxStamina,
        IsSprinting = false,
        State = "ALIVE",
        LastSprintTime = 0,
        BleedoutTimeRemaining = PlayerConfig.Downed.BleedoutDuration,
        ReviveProgress = 0,
    }
    self._players[player] = record
    self.PlayerAdded:Fire(player)

    player.CharacterAdded:Connect(function(character: Model)
        self:_OnCharacterSpawned(player, character)
    end)
end

function PlayerService:_OnCharacterSpawned(player: Player, character: Model)
    local record = self._players[player]
    if record then
        record.Health = PlayerConfig.RespawnHealth
        record.Stamina = PlayerConfig.MaxStamina
        record.IsSprinting = false
        record.State = "ALIVE"
        record.BleedoutTimeRemaining = PlayerConfig.Downed.BleedoutDuration
        record.ReviveProgress = 0
    end

    local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
    if humanoid then
        humanoid.WalkSpeed = PlayerConfig.Movement.WalkSpeed
        humanoid.Died:Connect(function()
            self:_OnPlayerDeath(player)
        end)
    end
end

function PlayerService:_OnPlayerRemoving(player: Player)
    self._players[player] = nil
    self._rateLimiter:Reset(tostring(player.UserId))
    self.PlayerRemoving:Fire(player)
end

function PlayerService:_OnSprintRequest(player: Player, wantsSprint: boolean)
    if not self._rateLimiter:Check(tostring(player.UserId)) then
        return
    end

    local record = self._players[player]
    if not record or record.State ~= "ALIVE" then
        return
    end

    if wantsSprint then
        if record.Stamina >= PlayerConfig.MinimumSprintStamina then
            record.IsSprinting = true
            record.LastSprintTime = os.clock()
            self:_ApplyWalkSpeed(player, PlayerConfig.Movement.SprintSpeed)
        end
    else
        record.IsSprinting = false
        self:_ApplyWalkSpeed(player, PlayerConfig.Movement.WalkSpeed)
    end
end

function PlayerService:_ApplyWalkSpeed(player: Player, speed: number)
    local character = player.Character
    local humanoid = if character then character:FindFirstChild("Humanoid") :: Humanoid? else nil
    if humanoid and humanoid.Health > 0 then
        humanoid.WalkSpeed = speed
    end
end

function PlayerService:_UpdatePlayerStats(dt: number)
    local now = os.clock()
    local stateSyncEvent = NetworkRemotes.GetEvent("Player", "PlayerStateSync")

    for player, record in pairs(self._players) do
        if record.State == "ALIVE" then
            if record.IsSprinting then
                -- Drain stamina
                record.Stamina = math.max(0, record.Stamina - (PlayerConfig.SprintDrainRate * dt))
                record.LastSprintTime = now
                if record.Stamina <= 0 then
                    record.IsSprinting = false
                    self:_ApplyWalkSpeed(player, PlayerConfig.Movement.WalkSpeed)
                end
            else
                -- Recover stamina after delay
                if now - record.LastSprintTime >= PlayerConfig.StaminaRecoveryDelay then
                    record.Stamina = math.min(record.MaxStamina, record.Stamina + (PlayerConfig.StaminaRecoveryRate * dt))
                end
            end
        elseif record.State == "DOWNED" then
            -- Bleedout timer
            record.BleedoutTimeRemaining -= dt
            if record.BleedoutTimeRemaining <= 0 then
                self:_OnPlayerDeath(player)
            end
        end

        -- Replicate state to client
        stateSyncEvent:FireClient(player, {
            Health = record.Health,
            MaxHealth = record.MaxHealth,
            Stamina = record.Stamina,
            MaxStamina = record.MaxStamina,
            State = record.State,
            IsSprinting = record.IsSprinting,
            BleedoutTimeRemaining = record.BleedoutTimeRemaining,
        })
    end
end

function PlayerService:ApplyDamage(player: Player, amount: number)
    local record = self._players[player]
    if not record or record.State == "DEAD" then
        return
    end

    record.Health = math.max(0, record.Health - amount)
    if record.Health <= 0 and record.State == "ALIVE" then
        self:_DownPlayer(player)
    end
end

function PlayerService:_DownPlayer(player: Player)
    local record = self._players[player]
    if not record then return end

    record.State = "DOWNED"
    record.IsSprinting = false
    record.BleedoutTimeRemaining = PlayerConfig.Downed.BleedoutDuration
    self:_ApplyWalkSpeed(player, PlayerConfig.Movement.DownedSpeed)

    local downedNoticeEvent = NetworkRemotes.GetEvent("Player", "DownedNotice")
    downedNoticeEvent:FireAllClients(player.Name, if player.Character and player.Character.PrimaryPart then player.Character.PrimaryPart.Position else Vector3.zero)
    self.PlayerDowned:Fire(player)
end

function PlayerService:_OnReviveRequest(reviver: Player, targetName: string): boolean
    local target = Players:FindFirstChild(targetName)
    if not target or target == reviver then
        return false
    end

    local reviverRecord = self._players[reviver]
    local targetRecord = self._players[target]
    if not reviverRecord or not targetRecord then
        return false
    end

    if reviverRecord.State ~= "ALIVE" or targetRecord.State ~= "DOWNED" then
        return false
    end

    -- Proximity check
    local reviverPos = if reviver.Character and reviver.Character.PrimaryPart then reviver.Character.PrimaryPart.Position else nil
    local targetPos = if target.Character and target.Character.PrimaryPart then target.Character.PrimaryPart.Position else nil
    if not reviverPos or not targetPos or (reviverPos - targetPos).Magnitude > PlayerConfig.Downed.MaxReviveDistance then
        return false
    end

    -- Successful revive
    targetRecord.State = "ALIVE"
    targetRecord.Health = targetRecord.MaxHealth * PlayerConfig.RevivedHealthPercent
    targetRecord.BleedoutTimeRemaining = PlayerConfig.Downed.BleedoutDuration
    self:_ApplyWalkSpeed(target, PlayerConfig.Movement.WalkSpeed)

    self.PlayerRevived:Fire(target)
    return true
end

function PlayerService:_OnPlayerDeath(player: Player)
    local record = self._players[player]
    if not record then return end

    record.State = "DEAD"
    record.Health = 0
    record.IsSprinting = false
    self.PlayerDied:Fire(player)

    -- Auto-respawn after delay
    task.delay(PlayerConfig.Respawn.RespawnDelay, function()
        if player.Parent and self._players[player] then
            player:LoadCharacter()
        end
    end)
end

function PlayerService:GetPlayerState(player: Player): PlayerState?
    local record = self._players[player]
    return if record then record.State else nil
end

function PlayerService:GetStats(player: Player): PlayerRecord?
    return self._players[player]
end

return PlayerService
