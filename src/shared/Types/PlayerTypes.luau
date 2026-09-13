--!strict
--[[
    PlayerTypes.luau
    Authoritative state structures for Player lifecycle, health, stamina,
    movement states, downed mechanics, runtime cache, and persisted profile schemas.
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

-- Authoritative in-memory runtime model (separated from persistent DataStore)
export type PlayerRuntimeData = {
    Player: Player,
    UserId: number,
    State: PlayerState,
    MovementState: MovementState,
    Health: number,
    MaxHealth: number,
    Stamina: number,
    MaxStamina: number,
    IsSprinting: boolean,
    IsDowned: boolean,
    IsAlive: boolean,
    CurrentZone: string,
    CurrentMission: string?,
    TeamId: string?,
    LastSafePosition: Vector3,
    LastDamageTimestamp: number,
    LastStaminaDrainTimestamp: number,
    DownedTimestamp: number?,
    DownedTimerRemaining: number?,
    RevivingPlayer: Player?,
    ReviveProgressSeconds: number,
    InteractionLock: boolean,
    SpawnTimestamp: number,
    EquippedSlot: number,
}

-- Backward compatible alias for live state consumers
export type PlayerLiveState = PlayerRuntimeData

-- Replicated client state snapshot
export type PlayerStateSnapshot = {
    UserId: number,
    State: PlayerState,
    MovementState: MovementState,
    Health: number,
    MaxHealth: number,
    Stamina: number,
    MaxStamina: number,
    IsSprinting: boolean,
    IsDowned: boolean,
    IsAlive: boolean,
    CurrentZone: string,
    DownedTimerRemaining: number?,
}

-- Persisted player profile schema (DataStore)
export type PlayerProfileData = {
    SchemaVersion: number,
    UserId: number,
    ColonyCredits: number,
    DarkNanites: number,
    XP: number,
    Level: number,
    SeasonTier: number,
    SeasonPoints: number,
    Inventory: {
        Slots: { [number]: { ItemId: string, Quantity: number, Metadata: { [string]: any }? } },
        MaxSlots: number,
    },
    EquippedWeapons: {
        Primary: string?,
        Secondary: string?,
        Holster: string?,
    },
    EquippedCosmetics: {
        Suit: string,
        WeaponSkins: { [string]: string },
        Title: string,
        Emotes: { [number]: string },
    },
    UnlockedCosmetics: { [string]: boolean },
    UnlockedWeapons: { [string]: boolean },
    Achievements: { [string]: number },
    Stats: {
        TotalKills: number,
        ScoutKills: number,
        HunterKills: number,
        StalkerKills: number,
        BruteKills: number,
        BossKills: number,
        TotalDeaths: number,
        TimesDowned: number,
        TeammatesRevived: number,
        MissionsCompleted: number,
        MissionsFailed: number,
        ExtractionsSuccessful: number,
        TotalDamageDealt: number,
        TotalCreditsEarned: number,
        TotalSecondsSurvived: number,
    },
    LastSavedTimestamp: number,
}

export type ReviveRequest = {
    TargetPlayerUserId: number,
    Action: "START" | "STEP" | "CANCEL" | "COMPLETE",
}

local PlayerTypes = {}
return PlayerTypes
