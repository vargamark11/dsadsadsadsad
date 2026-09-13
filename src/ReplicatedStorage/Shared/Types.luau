--!strict
--[[
    Types.luau
    Centralized type definitions for ALIEN: NIGHTFALL.
    Synchronized to ReplicatedStorage.Shared.Types via Rojo.
]]

export type PlayerState =
    | "LOBBY"
    | "SPAWNING"
    | "ALIVE"
    | "SPRINTING"
    | "INTERACTING"
    | "DOWNED"
    | "DEAD"
    | "EXTRACTING"
    | "SPECTATING"

export type MovementState =
    | "WALKING"
    | "SPRINTING"
    | "DOWNED"
    | "DEAD"
    | "SPECTATING"

export type ZoneId =
    | "LandingBase"
    | "ResearchComplex"
    | "Hospital"
    | "Forest"
    | "Underground"
    | "AbandonedCity"
    | "AlienNest"

export type ZoneDefinition = {
    Id: ZoneId,
    DisplayName: string,
    Description: string,
    IsSafeZone: boolean,
    ThreatLevel: number,
    AmbientLighting: Color3,
    FogDensity: number,
    AllowedSpawnTypes: { string },
}

export type PlayerStats = {
    Health: number,
    MaxHealth: number,
    Stamina: number,
    MaxStamina: number,
    IsSprinting: boolean,
    State: PlayerState,
    CurrentZone: ZoneId,
    ReviveProgress: number,
}

export type PlayerData = {
    UserId: number,
    CareerLevel: number,
    CareerXP: number,
    Credits: number,
    DarkNanites: number,
    Inventory: { [string]: any },
    Stats: {
        MatchesPlayed: number,
        Extractions: number,
        AlienKills: number,
        RevivesPerformed: number,
        TimesDowned: number,
    },
    EquippedCosmetics: {
        Suit: string?,
        WeaponSkin: string?,
        Title: string?,
    },
}

export type InteractionType =
    | "SIMPLE"
    | "HOLD"
    | "PROGRESS"
    | "TOGGLE"
    | "REQUIRES_KEYCARD"
    | "REQUIRES_ITEM"
    | "MULTI_PLAYER"
    | "SEQUENCE"
    | "TIMED"

export type InteractionState =
    | "AVAILABLE"
    | "LOCKED"
    | "BUSY"
    | "DISABLED"
    | "COMPLETED"
    | "OPEN"
    | "CLOSED"
    | "ACTIVE"
    | "LOCKDOWN"

export type InteractionFeedback =
    | "SUCCESS"
    | "DENIED"
    | "TOO_FAR"
    | "LOCKED"
    | "ACCESS_GRANTED"
    | "ACCESS_DENIED"
    | "MISSING_ITEM"
    | "WRONG_STATE"
    | "COOLDOWN"
    | "FAILED"
    | "TIMED_OUT"
    | "NO_LINE_OF_SIGHT"

export type ClearanceLevel =
    | "NONE"
    | "KEYCARD_LEVEL_1"
    | "KEYCARD_LEVEL_2"
    | "KEYCARD_LEVEL_3"
    | "KEYCARD_MASTER"
    | "KEYCARD_LEVEL_5"

export type InteractionDefinition = {
    Id: string,
    Name: string,
    Type: InteractionType,
    Distance: number,
    HoldDuration: number?,
    RequiredClearance: ClearanceLevel?,
    RequiredItem: string?,
    ConsumeItemOnUse: boolean?,
    RequiredPlayers: number?,
    Sequence: { number }?,
    TimeLimit: number?,
    State: InteractionState,
    RequiresLineOfSight: boolean?,
    LootTableId: string?,
    OnInteractServer: ((player: Player, action: string, payload: any?) -> (boolean, InteractionFeedback, any?))?,
}

export type InteractionResult = {
    Success: boolean,
    Feedback: InteractionFeedback,
    ObjectId: string,
    NewState: InteractionState?,
    Message: string?,
    Data: any?,
}

export type Service = {
    Name: string,
    OnInit: ((self: any) -> ())?,
    OnStart: ((self: any) -> ())?,
    [string]: any,
}

export type Controller = {
    Name: string,
    OnInit: ((self: any) -> ())?,
    OnStart: ((self: any) -> ())?,
    [string]: any,
}

local Types = {}
return Types
