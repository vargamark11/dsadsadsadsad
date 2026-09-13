--!strict
--[[
    TeamService.luau
    Cooperative team coordination service supporting 1 to 8 players in ALIEN: NIGHTFALL.
    Aggregates team health states, downed indicators, shared objective progress,
    and monitors team wipe conditions.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

export type TeamMemberSummary = {
    UserId: number,
    Name: string,
    Health: number,
    MaxHealth: number,
    IsDowned: boolean,
    Position: Vector3,
}

local TeamService = {
    Name = "TeamService",
    TeamWiped = Signal.new(),
}

function TeamService:OnInit()
    print("[TeamService] Initialized.")
end

function TeamService:OnStart()
    -- Periodic team status broadcast (every 0.5s)
    task.spawn(function()
        while true do
            task.wait(0.5)
            self:_BroadcastTeamStatus()
        end
    end)
    print("[TeamService] Started.")
end

function TeamService:_BroadcastTeamStatus()
    local PlayerService = ServiceManager.GetService("PlayerService") :: any
    if not PlayerService then return end

    local activePlayers = Players:GetPlayers()
    if #activePlayers == 0 then return end

    local roster: { TeamMemberSummary } = {}
    local anyAlive = false

    for _, player in ipairs(activePlayers) do
        local liveState = PlayerService:GetLiveState(player)
        local char = player.Character
        local rootPart = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?

        if liveState then
            if not liveState.IsDowned and not liveState.IsDead then
                anyAlive = true
            end

            table.insert(roster, {
                UserId = player.UserId,
                Name = player.Name,
                Health = liveState.Health,
                MaxHealth = liveState.MaxHealth,
                IsDowned = liveState.IsDowned,
                Position = rootPart and rootPart.Position or Vector3.zero,
            })
        end
    end

    -- If all players in the session are downed -> Team wipe!
    if #activePlayers > 0 and not anyAlive then
        self.TeamWiped:Fire()
    end

    -- Broadcast roster update to all clients
    NetworkProtocol.ServerFireAllClients("PlayerRemotes", "PlayerStateSync", {
        TeamRoster = roster,
    })
end

return TeamService
