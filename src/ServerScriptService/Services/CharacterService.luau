--!strict
--[[
    CharacterService.luau
    Authoritative character tracking, humanoid root part caching, and lifecycle management.
    Synchronized to ServerScriptService.Services.CharacterService via Rojo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Utilities = require(Shared:WaitForChild("Utilities"))

type CharacterData = {
    Character: Model,
    Humanoid: Humanoid,
    RootPart: BasePart,
    SpawnTime: number,
}

local CharacterService = {
    Name = "CharacterService",
    CharacterSpawned = Utilities.CreateSignal(), -- (player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
    CharacterRemoving = Utilities.CreateSignal(), -- (player: Player, character: Model)
    CharacterDied = Utilities.CreateSignal(),     -- (player: Player, character: Model)
    
    _characters = {} :: { [Player]: CharacterData },
}

function CharacterService:OnInit()
    print("[CharacterService] Initialized character lifecycle tracker.")
end

function CharacterService:OnStart()
    Players.PlayerAdded:Connect(function(player: Player)
        self:_OnPlayerAdded(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self._characters[player] = nil
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:_OnPlayerAdded(player)
    end
end

function CharacterService:_OnPlayerAdded(player: Player)
    player.CharacterAdded:Connect(function(character: Model)
        self:_OnCharacterAdded(player, character)
    end)

    player.CharacterRemoving:Connect(function(character: Model)
        self.CharacterRemoving:Fire(player, character)
        self._characters[player] = nil
    end)

    if player.Character then
        self:_OnCharacterAdded(player, player.Character)
    end
end

function CharacterService:_OnCharacterAdded(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
    local rootPart = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?

    if not humanoid or not rootPart then
        warn(string.format("[CharacterService] Character for %s missing Humanoid or HumanoidRootPart", player.Name))
        return
    end

    local charData: CharacterData = {
        Character = character,
        Humanoid = humanoid,
        RootPart = rootPart,
        SpawnTime = os.clock(),
    }
    self._characters[player] = charData

    humanoid.Died:Connect(function()
        self.CharacterDied:Fire(player, character)
    end)

    self.CharacterSpawned:Fire(player, character, humanoid, rootPart)
end

function CharacterService:GetCharacterData(player: Player): CharacterData?
    return self._characters[player]
end

function CharacterService:GetRootPart(player: Player): BasePart?
    local data = self._characters[player]
    return if data then data.RootPart else nil
end

function CharacterService:GetPosition(player: Player): Vector3?
    local rootPart = self:GetRootPart(player)
    return if rootPart then rootPart.Position else nil
end

function CharacterService:IsAlive(player: Player): boolean
    local data = self._characters[player]
    if not data or not data.Humanoid then
        return false
    end
    return data.Humanoid.Health > 0 and data.Humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

return CharacterService
