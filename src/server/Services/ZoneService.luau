--!strict
--[[
    ZoneService.luau
    Authoritative world zone tracking and spatial environmental boundary interface.
    Maintains the player's active zone (LandingBase, ResearchComplex, Hospital, etc.)
    and provides extensible trigger volume registration for future map expansions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerConfig = require(ReplicatedStorage.AlienNightfall.Config.PlayerConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)
local ServiceManager = require(script.Parent.Parent.ServiceManager)

export type ZoneId = PlayerConfig.ZoneId

local ZoneService = {
    Name = "ZoneService",
    ZoneChanged = Signal.new(),    -- (player: Player, oldZone: string, newZone: string)
    _registeredZones = {} :: { [string]: { Safe: boolean, DisplayName: string } },
    _playerZones = {} :: { [number]: string },
}

function ZoneService:OnInit()
    -- Initialize known zones from configuration
    for _, zone in ipairs(PlayerConfig.Zones.AllZones) do
        self._registeredZones[zone] = {
            Safe = PlayerConfig.Zones.SafeZones[zone] == true,
            DisplayName = PlayerConfig.Zones.ZoneDisplayNames[zone] or zone,
        }
    end
    print("[ZoneService] Initialized with", #PlayerConfig.Zones.AllZones, "zones.")
end

function ZoneService:OnStart()
    print("[ZoneService] Started.")
end

function ZoneService:OnPlayerAdded(player: Player)
    self._playerZones[player.UserId] = PlayerConfig.Zones.DefaultZone
    player:SetAttribute("CurrentZone", PlayerConfig.Zones.DefaultZone)
end

function ZoneService:OnPlayerRemoving(player: Player)
    self._playerZones[player.UserId] = nil
end

function ZoneService:GetPlayerZone(player: Player): string
    return self._playerZones[player.UserId] or PlayerConfig.Zones.DefaultZone
end

function ZoneService:IsSafeZone(zoneName: string): boolean
    local info = self._registeredZones[zoneName]
    return info and info.Safe or false
end

function ZoneService:SetPlayerZone(player: Player, newZone: string): boolean
    local oldZone = self:GetPlayerZone(player)
    if oldZone == newZone then
        return true
    end

    if not self._registeredZones[newZone] then
        warn(string.format("[ZoneService] Attempted to set unregistered zone %s for %s", newZone, player.Name))
        return false
    end

    self._playerZones[player.UserId] = newZone

    -- Update runtime data
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    local data = PlayerStateManager and PlayerStateManager:GetRuntimeData(player)
    if data then
        data.CurrentZone = newZone
    end

    -- Update replicated attribute
    player:SetAttribute("CurrentZone", newZone)
    if player.Character then
        player.Character:SetAttribute("CurrentZone", newZone)
    end

    self.ZoneChanged:Fire(player, oldZone, newZone)

    -- Replicate to client
    NetworkProtocol.ServerFireClient(player, "PlayerRemotes", "ZoneChanged", {
        OldZone = oldZone,
        NewZone = newZone,
        DisplayName = self._registeredZones[newZone].DisplayName,
        IsSafe = self._registeredZones[newZone].Safe,
    })

    return true
end

function ZoneService:RegisterZone(zoneName: string, isSafe: boolean, displayName: string)
    self._registeredZones[zoneName] = {
        Safe = isSafe,
        DisplayName = displayName,
    }
end

return ZoneService
