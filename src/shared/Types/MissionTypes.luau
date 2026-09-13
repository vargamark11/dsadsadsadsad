--!strict
--[[
    MissionTypes.luau
    State representations for active missions, chains, objectives, and generator manifests.
]]

export type MissionStatus = "PENDING" | "ACTIVE" | "COMPLETED" | "FAILED" | "EXPIRED"

export type ActiveObjectiveState = {
    Id: string,
    Title: string,
    Description: string,
    Type: string,
    CurrentCount: number,
    RequiredCount: number,
    IsCompleted: boolean,
    TimeRemainingSeconds: number?,
    TargetZone: string,
}

export type ActiveMissionInstance = {
    MissionInstanceId: string,
    TemplateId: string,
    Title: string,
    Category: string,
    PrimaryZone: string,
    Difficulty: number,
    Status: MissionStatus,
    CurrentObjectiveIndex: number,
    Objectives: { ActiveObjectiveState },
    StartTime: number,
    EndTime: number?,
    RewardXP: number,
    RewardCredits: number,
    Participants: { [number]: boolean }, -- UserIds of contributing players
}

export type MissionChain = {
    ChainId: string,
    Title: string,
    Seed: number,
    CurrentStepIndex: number,
    Steps: { ActiveMissionInstance },
    IsCompleted: boolean,
    TotalRewardXP: number,
    TotalRewardCredits: number,
}

local MissionTypes = {}
return MissionTypes
