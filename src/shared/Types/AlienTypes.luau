--!strict
--[[
    AlienTypes.luau
    State machine states, sensory inputs, blackboard keys, and archetype definitions
    for Alien AI in ALIEN: NIGHTFALL.
]]

export type AIState =
    | "IDLE"
    | "PATROL"
    | "INVESTIGATE"
    | "ALERT"
    | "CHASE"
    | "ATTACK"
    | "SEARCH"
    | "RETREAT"
    | "RETURN_TO_PATROL"

export type SoundStimulus = {
    Position: Vector3,
    Amplitude: number,           -- Decibel/intensity rating (1-100)
    Radius: number,              -- In studs
    SourcePlayer: Player?,
    Timestamp: number,
    Category: "FOOTSTEP" | "SPRINT" | "GUNFIRE" | "INTERACT" | "EXPLOSION" | "DECOY",
}

export type VisualStimulus = {
    TargetPlayer: Player,
    TargetRootPart: BasePart,
    Distance: number,
    AngleDegrees: number,
    HasLineOfSight: boolean,
    LightingLevel: number,
    Timestamp: number,
}

export type AlienBlackboard = {
    CurrentState: AIState,
    TargetPlayer: Player?,
    TargetLastSeenPosition: Vector3?,
    TargetLastSeenTimestamp: number?,
    InvestigationPosition: Vector3?,
    InvestigationReason: string?,
    CurrentHealth: number,
    MaxHealth: number,
    IsAttacking: boolean,
    LastAttackTimestamp: number,
    StateEnteredTimestamp: number,
    SearchTimer: number,
    PatrolAnchor: Vector3,
    CurrentPatrolIndex: number,
    PatrolWaypoints: { Vector3 },
    MemoryTimer: number,
    IsStaggered: boolean,
    StaggerEndTimestamp: number,
}

export type AlienInstance = {
    EntityId: string,
    ClassType: "SCOUT" | "HUNTER" | "STALKER" | "BRUTE" | "SWARM" | "BOSS",
    Model: Model,
    Humanoid: Humanoid,
    RootPart: BasePart,
    Blackboard: AlienBlackboard,
    Config: any,
    SpawnTimestamp: number,
}

local AlienTypes = {}
return AlienTypes
