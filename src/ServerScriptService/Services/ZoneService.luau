--!strict
--[[
    ZoneService.luau
    Authoritative world sector partitioning, safe zone enforcement, and zone tracking.
    Synchronized to ServerScriptService.Services.ZoneService via Rojo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")

local WorldConfig = require(Config:WaitForChild("WorldConfig"))
local Types = require(Shared:WaitForChild("Types"))
local Utilities = require(Shared:WaitForChild("Utilities"))

type ZoneId = WorldConfig.ZoneId
type ZoneDefinition = WorldConfig.ZoneDefinition

local ZoneService = {
    Name = "ZoneService",
    ZoneChanged = Utilities.CreateSignal(), -- (player: Player, newZone: ZoneId, oldZone: ZoneId)
    
    _playerZones = {} :: { [Player]: ZoneId },
    _zoneDefinitions = WorldConfig.Zones,
    _safeZones = WorldConfig.SafeZones,
    _lastSweep = 0,
}

function ZoneService:OnInit()
    print("[ZoneService] Initialized World Zone manager.")
end

function ZoneService:OnStart()
    Players.PlayerAdded:Connect(function(player: Player)
        self._playerZones[player] = WorldConfig.DefaultZone
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self._playerZones[player] = nil
    end)

    -- Sweep player positions at 2 Hz (every 0.5s) to determine active zones
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - self._lastSweep >= 0.5 then
            self._lastSweep = now
            self:_UpdatePlayerZones()
        end
    end)
end

function ZoneService:_UpdatePlayerZones()
    local worldFolder = workspace:FindFirstChild("World")
    local zonesFolder = if worldFolder then worldFolder:FindFirstChild("Zones") else nil

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local rootPart = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
        if not rootPart then
            continue
        end

        local pos = rootPart.Position
        local detectedZone = self:_ResolveZoneAtPosition(pos, zonesFolder)
        local currentZone = self._playerZones[player] or WorldConfig.DefaultZone

        if detectedZone ~= currentZone then
            self._playerZones[player] = detectedZone
            self.ZoneChanged:Fire(player, detectedZone, currentZone)
        end
    end
end

function ZoneService:_ResolveZoneAtPosition(position: Vector3, zonesFolder: Instance?): ZoneId
    if zonesFolder then
        for zoneName, _ in pairs(self._zoneDefinitions) do
            local zonePart = zonesFolder:FindFirstChild(zoneName) :: BasePart?
            if zonePart and zonePart:IsA("BasePart") then
                local halfSize = zonePart.Size * 0.5
                local localPos = zonePart.CFrame:PointToObjectSpace(position)
                if math.abs(localPos.X) <= halfSize.X and
                   math.abs(localPos.Y) <= halfSize.Y and
                   math.abs(localPos.Z) <= halfSize.Z then
                    return zoneName :: ZoneId
                end
            end
        end
    end

    -- Landing base default radius if no explicit zone part bounds were intersected
    local distFromCenter = position.Magnitude
    if distFromCenter <= 140 then
        return "LandingBase" :: ZoneId
    end

    return WorldConfig.DefaultZone
end

function ZoneService:GetPlayerZone(player: Player): ZoneId
    return self._playerZones[player] or WorldConfig.DefaultZone
end

function ZoneService:IsPlayerInSafeZone(player: Player): boolean
    local zoneId = self:GetPlayerZone(player)
    return self._safeZones[zoneId] == true
end

function ZoneService:GetZoneDefinition(zoneId: ZoneId): ZoneDefinition?
    return self._zoneDefinitions[zoneId]
end

return ZoneService
