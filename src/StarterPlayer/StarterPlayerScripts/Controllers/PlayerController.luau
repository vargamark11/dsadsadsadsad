--!strict
--[[
    PlayerController.luau
    Client-side player state tracking, sprint network communication, and downed alerts.
    Synchronized to StarterPlayer.StarterPlayerScripts.Controllers.PlayerController via Rojo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")

local Types = require(Shared:WaitForChild("Types"))
local PlayerConfig = require(Config:WaitForChild("PlayerConfig"))
local Utilities = require(Shared:WaitForChild("Utilities"))
local NetworkRemotes = require(Shared:WaitForChild("NetworkRemotes"))

local localPlayer = Players.LocalPlayer

local PlayerController = {
    Name = "PlayerController",
    StateUpdated = Utilities.CreateSignal(), -- (stats: any)
    DownedNoticeReceived = Utilities.CreateSignal(), -- (playerName: string, position: Vector3)

    _stats = {
        Health = 100,
        MaxHealth = 100,
        Stamina = 100,
        MaxStamina = 100,
        State = "ALIVE",
        IsSprinting = false,
        BleedoutTimeRemaining = 45,
    },
    _isSprinting = false,
}

function PlayerController:OnInit()
    print("[PlayerController] Initialized client player state coordinator.")
end

function PlayerController:OnStart()
    local InputController = require(script.Parent:WaitForChild("InputController")) :: any

    -- Listen to input toggle for sprint
    InputController.SprintToggled:Connect(function(wantsSprint: boolean)
        self:SetSprintIntent(wantsSprint)
    end)

    -- Listen to server state sync
    local stateSyncEvent = NetworkRemotes.GetEvent("Player", "PlayerStateSync")
    stateSyncEvent.OnClientEvent:Connect(function(syncedStats: any)
        if typeof(syncedStats) == "table" then
            for k, v in pairs(syncedStats) do
                (self._stats :: any)[k] = v
            end
            self.StateUpdated:Fire(self._stats)
        end
    end)

    -- Listen to downed alert
    local downedNoticeEvent = NetworkRemotes.GetEvent("Player", "DownedNotice")
    downedNoticeEvent.OnClientEvent:Connect(function(playerName: any, position: any)
        self.DownedNoticeReceived:Fire(tostring(playerName), position :: Vector3)
    end)
end

function PlayerController:SetSprintIntent(wantsSprint: boolean)
    if self._stats.State ~= "ALIVE" then
        return
    end

    if wantsSprint and self._stats.Stamina < PlayerConfig.MinimumSprintStamina then
        return
    end

    self._isSprinting = wantsSprint
    local sprintEvent = NetworkRemotes.GetEvent("Player", "SprintRequest")
    sprintEvent:FireServer(wantsSprint)
end

function PlayerController:GetStats(): any
    return self._stats
end

function PlayerController:IsAlive(): boolean
    return self._stats.State == "ALIVE"
end

function PlayerController:IsDowned(): boolean
    return self._stats.State == "DOWNED"
end

return PlayerController
