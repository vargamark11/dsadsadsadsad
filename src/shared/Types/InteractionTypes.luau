--!strict
--[[
    InteractionTypes.luau
    Type definitions, state representations, feedback codes, and data schemas
    for the ALIEN: NIGHTFALL generic interaction framework.
]]

export type InteractionType =
    | "SIMPLE"
    | "HOLD"
    | "TOGGLE"
    | "PROGRESS"
    | "REQUIRES_ITEM"
    | "REQUIRES_KEYCARD"
    | "MULTI_STEP"
    | "MULTI_PLAYER"
    | "SEQUENCE"
    | "TIMED"
    | "CONSUMABLE"
    | "ONE_TIME"
    | "REUSABLE"

export type InteractionFeedbackCode =
    | "SUCCESS"
    | "DENIED"
    | "TOO_FAR"
    | "LOCKED"
    | "MISSING_ITEM"
    | "WRONG_STATE"
    | "COOLDOWN"
    | "CANCELLED"
    | "FAILED"
    | "ACCESS_GRANTED"
    | "ACCESS_DENIED"
    | "ALREADY_ACTIVE"
    | "TIMED_OUT"
    | "NO_LINE_OF_SIGHT"
    | "REQUIRES_MORE_PLAYERS"
    | "SEQUENCE_ERROR"
    | "SEQUENCE_STEP"

export type ObjectCategory =
    | "DOOR"
    | "KEYPAD"
    | "COMPUTER"
    | "GENERATOR"
    | "SWITCH"
    | "BUTTON"
    | "CONTAINER"
    | "MEDICAL_STATION"
    | "TERMINAL"
    | "ELEVATOR"
    | "VEHICLE"
    | "MISSION_OBJECT"
    | "KEYCARD_READER"
    | "EMERGENCY_SYSTEM"
    | "EXTRACTION_CONSOLE"
    | "GENERIC"

export type KeycardLevel = 1 | 2 | 3 | 4 | 5

export type DoorState = "CLOSED" | "OPEN" | "LOCKED" | "UNLOCKED" | "LOCKDOWN" | "JAMMED"
export type TerminalState = "OFFLINE" | "ONLINE" | "LOCKED" | "HACKING" | "ACTIVE" | "DISABLED"
export type GeneratorState = "OFF" | "DAMAGED" | "REPAIRING" | "ACTIVE" | "OVERLOADED"
export type ContainerState = "CLOSED" | "OPENING" | "OPEN" | "EMPTY"
export type ElevatorState = "IDLE" | "MOVING" | "LOCKED" | "DISABLED" | "DOORS_OPEN" | "DOORS_CLOSING"
export type SwitchState = "ON" | "OFF" | "ACTIVE" | "INACTIVE"

export type LootEntry = {
    ItemId: string,
    Chance: number,          -- 0.0 to 1.0 (weight / probability)
    MinQuantity: number,
    MaxQuantity: number,
}

export type LootTable = {
    Id: string,
    MinRolls: number,
    MaxRolls: number,
    Items: { LootEntry },
}

export type MultiPlayerRequirement = {
    RequiredPlayers: number,
    ActivePlayerIds: { [number]: boolean }, -- UserId -> true
    HoldDuration: number,
}

export type SequenceRequirement = {
    ExpectedSequence: { number },
    CurrentIndex: number,                   -- Current step 1..#ExpectedSequence
    ResetOnError: boolean,
    Completed: boolean,
}

export type TimedRequirement = {
    TimeLimit: number,                      -- Seconds before expiration
    StartedAt: number,
    ExpiresAt: number,
    IsActive: boolean,
}

export type InteractionDefinition = {
    Id: string,
    Category: ObjectCategory,
    Name: string,
    ActionText: string,                     -- e.g. "Open Door", "Repair Generator", "Search Locker"
    Type: InteractionType,
    Distance: number,                       -- Max interaction range in studs (default: 10)
    HoldDuration: number,                   -- Seconds for HOLD / PROGRESS (0 for SIMPLE)
    Cooldown: number,                       -- Cooldown after completion in seconds
    RequiresLineOfSight: boolean,
    RequiredItem: string?,                  -- ItemId required in inventory (e.g. "ITEM_HV_FUSE")
    ConsumeItem: boolean?,                  -- Whether required item is removed on completion
    RequiredKeycardLevel: KeycardLevel?,    -- Minimum clearance level (1..5)
    RequiredPlayerStates: { [string]: boolean }?, -- e.g. { ALIVE = true }
    MultiPlayer: MultiPlayerRequirement?,
    Sequence: SequenceRequirement?,
    Timed: TimedRequirement?,
    CancelDistance: number?,                -- Maximum distance before active hold is cancelled
    CancelOnDamage: boolean?,
    CancelOnDeath: boolean?,
    SoundHooks: {
        Success: string?,
        Denied: string?,
        Start: string?,
        Loop: string?,
        Cancel: string?,
    }?,
    AnimationId: string?,
    LootTableId: string?,
    Attributes: { [string]: any }?,
}

export type ActiveHoldSession = {
    Player: Player,
    UserId: number,
    ObjectId: string,
    StartTime: number,
    Duration: number,
    TargetWorldPosition: Vector3,
    MaxDistance: number,
}

export type InteractRequestAction = "START" | "COMPLETE" | "CANCEL" | "INSTANT" | "SEQUENCE_STEP"

export type InteractRequest = {
    ObjectId: string,
    Action: InteractRequestAction,
    ClientTimestamp: number?,
    StepValue: number?,                     -- For SEQUENCE inputs
    Payload: any?,
}

export type InteractResponse = {
    Success: boolean,
    Feedback: InteractionFeedbackCode,
    ObjectId: string,
    NewState: string?,
    Message: string?,
    Data: any?,
}

return {}
