--!strict
--[[
    MissionService.luau
    Authoritative mission runner and objective evaluator in ALIEN: NIGHTFALL.
    Dispatches mission states to clients, tracks progress, and grants rewards.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.MissionTypes)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

local MissionService = {
    Name = "MissionService",
    MissionStarted = Signal.new(),
    ObjectiveUpdated = Signal.new(),
    MissionCompleted = Signal.new(),
    _activeChain = nil :: MissionTypes.MissionChain?,
}

function MissionService:OnInit()
    print("[MissionService] Initialized.")
end

function MissionService:OnStart()
    NetworkProtocol.ServerBindFunction("MissionRemotes", "RequestStartMission", function(player: Player, difficulty: any)
        return self:StartNewMissionChain(tonumber(difficulty) or 2)
    end)

    -- Auto-start an introductory mission chain on boot
    task.delay(3, function()
        if not self._activeChain then
            self:StartNewMissionChain(2)
        end
    end)
    print("[MissionService] Started.")
end

function MissionService:StartNewMissionChain(difficulty: number): any
    local MissionGenerator = ServiceManager.GetService("MissionGenerator") :: any
    if not MissionGenerator then return { Success = false, Error = "Generator unavailable" } end

    local chain = MissionGenerator:GenerateChain(difficulty)
    self._activeChain = chain

    local currentMission = chain.Steps[chain.CurrentStepIndex]
    if currentMission then
        currentMission.Status = "ACTIVE"
        currentMission.StartTime = os.clock()
        for _, p in ipairs(Players:GetPlayers()) do
            currentMission.Participants[p.UserId] = true
        end
    end

    print(string.format("[MissionService] Active Mission Chain Started: %s (Steps: %d)", chain.Title, #chain.Steps))
    self:SyncActiveMissionToAll()
    self.MissionStarted:Fire(chain)

    return { Success = true, ChainId = chain.ChainId, Title = chain.Title }
end

function MissionService:RecordObjectiveProgress(objectiveId: string, deltaAmount: number, contributingPlayer: Player?): boolean
    if not self._activeChain then return false end

    local currentMission = self._activeChain.Steps[self._activeChain.CurrentStepIndex]
    if not currentMission or currentMission.Status ~= "ACTIVE" then return false end

    local currentObj = currentMission.Objectives[currentMission.CurrentObjectiveIndex]
    if not currentObj or currentObj.Id ~= objectiveId or currentObj.IsCompleted then
        return false
    end

    currentObj.CurrentCount = math.min(currentObj.RequiredCount, currentObj.CurrentCount + deltaAmount)
    if contributingPlayer then
        currentMission.Participants[contributingPlayer.UserId] = true
    end

    self.ObjectiveUpdated:Fire(currentObj)
    NetworkProtocol.ServerFireAllClients("MissionRemotes", "ObjectiveProgress", {
        ObjectiveId = currentObj.Id,
        Current = currentObj.CurrentCount,
        Required = currentObj.RequiredCount,
    })

    -- Check completion of objective
    if currentObj.CurrentCount >= currentObj.RequiredCount then
        currentObj.IsCompleted = true
        print(string.format("[MissionService] Objective Completed: %s", currentObj.Title))

        if currentMission.CurrentObjectiveIndex < #currentMission.Objectives then
            currentMission.CurrentObjectiveIndex += 1
            print(string.format("[MissionService] Advancing to next objective: %s",
                currentMission.Objectives[currentMission.CurrentObjectiveIndex].Title))
        else
            -- All objectives in this mission step completed!
            self:_CompleteCurrentMissionStep()
        end
    end

    self:SyncActiveMissionToAll()
    return true
end

function MissionService:_CompleteCurrentMissionStep()
    if not self._activeChain then return end
    local currentMission = self._activeChain.Steps[self._activeChain.CurrentStepIndex]
    if not currentMission then return end

    currentMission.Status = "COMPLETED"
    currentMission.EndTime = os.clock()

    -- Grant rewards to participating players
    local ProgressionService = ServiceManager.GetService("ProgressionService") :: any
    local EconomyService = ServiceManager.GetService("EconomyService") :: any

    for userId, _ in pairs(currentMission.Participants) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            if ProgressionService then
                ProgressionService:AddXP(player, currentMission.RewardXP, "MISSION_" .. currentMission.TemplateId)
                ProgressionService:IncrementStat(player, "MissionsCompleted", 1)
            end
            if EconomyService then
                EconomyService:AddCredits(player, currentMission.RewardCredits, "MISSION_" .. currentMission.TemplateId)
            end
        end
    end

    NetworkProtocol.ServerFireAllClients("MissionRemotes", "MissionCompleted", {
        Title = currentMission.Title,
        RewardXP = currentMission.RewardXP,
        RewardCredits = currentMission.RewardCredits,
    })

    if self._activeChain.CurrentStepIndex < #self._activeChain.Steps then
        self._activeChain.CurrentStepIndex += 1
        local nextStep = self._activeChain.Steps[self._activeChain.CurrentStepIndex]
        nextStep.Status = "ACTIVE"
        nextStep.StartTime = os.clock()
        self:SyncActiveMissionToAll()
    else
        self._activeChain.IsCompleted = true
        print(string.format("[MissionService] Full Chain '%s' Completed! Triggering Extraction Phase.", self._activeChain.Title))
        local ExtractionService = ServiceManager.GetService("ExtractionService") :: any
        if ExtractionService then
            ExtractionService:RequestExtraction("SHUTTLE_BAY_ALPHA")
        end
    end
end

function MissionService:SyncActiveMissionToAll()
    if not self._activeChain then return end
    local currentMission = self._activeChain.Steps[self._activeChain.CurrentStepIndex]
    if not currentMission then return end

    NetworkProtocol.ServerFireAllClients("MissionRemotes", "ActiveMissionSync", {
        ChainTitle = self._activeChain.Title,
        Mission = currentMission,
    })
end

return MissionService
