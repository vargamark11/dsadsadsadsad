--!strict
--[[
    MissionController.luau
    Client-side mission tracker and objective display coordinator in ALIEN: NIGHTFALL.
    Receives mission updates from MissionService and provides active objective state to the HUD.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

local MissionController = {
    Name = "MissionController",
    MissionUpdated = Signal.new(),
    ObjectiveUpdated = Signal.new(),
    MissionCompleted = Signal.new(),
    _activeChainTitle = "Awaiting Orders...",
    _currentMission = nil :: any?,
}

function MissionController:OnInit()
    print("[MissionController] Initialized.")
end

function MissionController:OnStart()
    NetworkProtocol.ClientConnectEvent("MissionRemotes", "ActiveMissionSync", function(payload: any)
        if not payload then return end
        self._activeChainTitle = payload.ChainTitle or self._activeChainTitle
        self._currentMission = payload.Mission
        self.MissionUpdated:Fire(self._activeChainTitle, self._currentMission)
    end)

    NetworkProtocol.ClientConnectEvent("MissionRemotes", "ObjectiveProgress", function(objData: any)
        self.ObjectiveUpdated:Fire(objData)
    end)

    NetworkProtocol.ClientConnectEvent("MissionRemotes", "MissionCompleted", function(data: any)
        self.MissionCompleted:Fire(data)
    end)

    print("[MissionController] Started.")
end

function MissionController:GetActiveMission(): (string, any?)
    return self._activeChainTitle, self._currentMission
end

return MissionController
