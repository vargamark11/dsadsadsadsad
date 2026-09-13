--!strict
--[[
    MissionGenerator.luau
    Dynamic procedural mission chain generator in ALIEN: NIGHTFALL.
    Synthesizes multi-stage exploration, repair, recovery, and extraction objectives
    without hardcoded single-script structures.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local MissionsConfig = require(ReplicatedStorage.AlienNightfall.Config.MissionsConfig)
local MissionTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.MissionTypes)

local MissionGenerator = {
    Name = "MissionGenerator",
}

function MissionGenerator:OnInit()
    print("[MissionGenerator] Initialized.")
end

function MissionGenerator:OnStart()
    print("[MissionGenerator] Started.")
end

function MissionGenerator:GenerateChain(difficulty: number?, seed: number?): MissionTypes.MissionChain
    local diff = difficulty or 2
    local missionSeed = seed or os.time()
    local rng = Random.new(missionSeed)

    -- Collect templates matching target difficulty range
    local pool: { MissionsConfig.MissionTemplate } = {}
    for _, template in pairs(MissionsConfig.Templates) do
        if math.abs(template.Difficulty - diff) <= 1 then
            table.insert(pool, template)
        end
    end

    if #pool == 0 then
        -- Fallback to all templates
        for _, template in pairs(MissionsConfig.Templates) do
            table.insert(pool, template)
        end
    end

    -- Select 1 or 2 linked missions
    local selectedCount = rng:NextInteger(1, math.min(2, #pool))
    local steps: { MissionTypes.ActiveMissionInstance } = {}
    local totalXP = 0
    local totalCredits = 0

    for i = 1, selectedCount do
        local chosen = pool[rng:NextInteger(1, #pool)]
        local activeObjectives: { MissionTypes.ActiveObjectiveState } = {}

        for _, objDef in ipairs(chosen.Objectives) do
            table.insert(activeObjectives, {
                Id = objDef.Id,
                Title = objDef.Title,
                Description = objDef.Description,
                Type = objDef.Type,
                CurrentCount = 0,
                RequiredCount = objDef.TargetQuantity,
                IsCompleted = false,
                TimeRemainingSeconds = objDef.TimeLimitSeconds,
                TargetZone = objDef.TargetZone,
            })
        end

        local instance: MissionTypes.ActiveMissionInstance = {
            MissionInstanceId = HttpService:GenerateGUID(false),
            TemplateId = chosen.TemplateId,
            Title = chosen.Title,
            Category = chosen.Category,
            PrimaryZone = chosen.PrimaryZone,
            Difficulty = chosen.Difficulty,
            Status = "PENDING",
            CurrentObjectiveIndex = 1,
            Objectives = activeObjectives,
            StartTime = 0,
            EndTime = nil,
            RewardXP = chosen.BaseXPReward,
            RewardCredits = chosen.BaseCreditsReward,
            Participants = {},
        }

        totalXP += chosen.BaseXPReward
        totalCredits += chosen.BaseCreditsReward
        table.insert(steps, instance)
    end

    local chain: MissionTypes.MissionChain = {
        ChainId = "CHAIN_" .. HttpService:GenerateGUID(false):sub(1, 8),
        Title = string.format("Operation %s", steps[1].Title),
        Seed = missionSeed,
        CurrentStepIndex = 1,
        Steps = steps,
        IsCompleted = false,
        TotalRewardXP = totalXP,
        TotalRewardCredits = totalCredits,
    }

    return chain
end

return MissionGenerator
