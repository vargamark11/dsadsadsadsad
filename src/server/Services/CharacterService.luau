--!strict
--[[
    CharacterService.luau
    Authoritative character lifecycle, reference caching, and physical state coordinator.
    Eliminates repetitive Workspace searches by safely caching Humanoid and HumanoidRootPart
    references. Handles rapid respawning, missing parts, and clean disconnection.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)
local PlayerConfig = require(ReplicatedStorage.AlienNightfall.Config.PlayerConfig)

export type CachedCharacter = {
    Player: Player,
    Model: Model,
    Humanoid: Humanoid,
    RootPart: BasePart,
    SpawnTimestamp: number,
    Connections: { RBXScriptConnection },
}

local CharacterService = {
    Name = "CharacterService",
    CharacterSpawned = Signal.new(),    -- (player: Player, model: Model, humanoid: Humanoid, rootPart: BasePart)
    CharacterRemoving = Signal.new(),   -- (player: Player, model: Model)
    CharacterDied = Signal.new(),       -- (player: Player, character: Model)
    _cache = {} :: { [number]: CachedCharacter },
    _respawnCooldowns = {} :: { [number]: number },
}

function CharacterService:OnInit()
    print("[CharacterService] Initialized.")
end

function CharacterService:OnStart()
    print("[CharacterService] Started.")
end

function CharacterService:OnPlayerAdded(player: Player)
    player.CharacterAdded:Connect(function(character: Model)
        self:_OnCharacterAdded(player, character)
    end)

    player.CharacterRemoving:Connect(function(character: Model)
        self:_OnCharacterRemoving(player, character)
    end)

    if player.Character then
        self:_OnCharacterAdded(player, player.Character)
    end
end

function CharacterService:OnPlayerRemoving(player: Player)
    self:_Cleanup(player.UserId)
    self._respawnCooldowns[player.UserId] = nil
end

function CharacterService:_OnCharacterAdded(player: Player, character: Model)
    -- Clean any previous character references for this user
    self:_Cleanup(player.UserId)

    -- Guard against player disconnecting while character was spawning
    if not player.Parent then
        return
    end

    -- Wait safely for critical components with timeout
    local humanoid = character:WaitForChild("Humanoid", 8) :: Humanoid?
    local rootPart = character:WaitForChild("HumanoidRootPart", 8) :: BasePart?

    if not humanoid or not rootPart or not character.Parent then
        warn(string.format("[CharacterService] Character spawned without valid Humanoid/RootPart for %s", player.Name))
        return
    end

    -- Configure humanoid base physics
    humanoid.BreakJointsOnDeath = false
    humanoid.MaxHealth = PlayerConfig.Health.MaxHealth
    humanoid.Health = PlayerConfig.Health.DefaultHealth
    humanoid.WalkSpeed = PlayerConfig.Movement.WalkSpeed
    humanoid.JumpPower = PlayerConfig.Movement.JumpPower

    local connections: { RBXScriptConnection } = {}

    -- Track death
    table.insert(connections, humanoid.Died:Connect(function()
        self.CharacterDied:Fire(player, character)
    end))

    local cached: CachedCharacter = {
        Player = player,
        Model = character,
        Humanoid = humanoid,
        RootPart = rootPart,
        SpawnTimestamp = os.clock(),
        Connections = connections,
    }

    self._cache[player.UserId] = cached
    self.CharacterSpawned:Fire(player, character, humanoid, rootPart)
end

function CharacterService:_OnCharacterRemoving(player: Player, character: Model)
    local cached = self._cache[player.UserId]
    if cached and cached.Model == character then
        self.CharacterRemoving:Fire(player, character)
        self:_Cleanup(player.UserId)
    end
end

function CharacterService:_Cleanup(userId: number)
    local cached = self._cache[userId]
    if cached then
        for _, conn in ipairs(cached.Connections) do
            conn:Disconnect()
        end
        table.clear(cached.Connections)
        self._cache[userId] = nil
    end
end

function CharacterService:GetCharacter(player: Player): Model?
    local cached = self._cache[player.UserId]
    return cached and cached.Model or nil
end

function CharacterService:GetHumanoid(player: Player): Humanoid?
    local cached = self._cache[player.UserId]
    return cached and cached.Humanoid or nil
end

function CharacterService:GetRootPart(player: Player): BasePart?
    local cached = self._cache[player.UserId]
    return cached and cached.RootPart or nil
end

function CharacterService:GetPosition(player: Player): Vector3?
    local root = self:GetRootPart(player)
    return root and root.Position or nil
end

function CharacterService:SetWalkSpeed(player: Player, speed: number)
    local humanoid = self:GetHumanoid(player)
    if humanoid then
        humanoid.WalkSpeed = speed
    end
end

function CharacterService:Teleport(player: Player, cframe: CFrame)
    local root = self:GetRootPart(player)
    if root then
        root.CFrame = cframe
    end
end

function CharacterService:Respawn(player: Player): boolean
    local now = os.clock()
    local lastRespawn = self._respawnCooldowns[player.UserId] or 0
    if (now - lastRespawn) < 1.0 then
        -- Prevent rapid respawn flooding
        return false
    end

    self._respawnCooldowns[player.UserId] = now
    self:_Cleanup(player.UserId)
    player:LoadCharacter()
    return true
end

return CharacterService
