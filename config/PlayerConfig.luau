--!strict
--[[
    PlayerConfig.luau
    Centralized configuration for Player System mechanics, movement, stamina,
    health, respawn, downed states, and world zones in ALIEN: NIGHTFALL.
    Never hardcode balancing numbers in controllers or services.
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

local PlayerConfig = {
    -- Health System Balancing
    Health = {
        DefaultHealth = 100,
        MaxHealth = 100,
        MinHealth = 0,
        RespawnHealth = 100,
        RevivedHealthPercent = 0.40, -- 40% health restored upon teammate revive
        NaturalRegenEnabled = false, -- Survival game rule: requires medical items to heal
        NaturalRegenRate = 0,
    },

    -- Stamina System Balancing
    Stamina = {
        DefaultStamina = 100,
        MaxStamina = 100,
        SprintDrainRate = 18,        -- Stamina units consumed per second while sprinting
        StaminaRecoveryRate = 22,    -- Stamina units recovered per second when resting
        MinimumSprintStamina = 10,   -- Minimum stamina needed to initiate or sustain sprint
        RecoveryDelay = 1.25,        -- Delay in seconds before recovery starts after sprinting stops
    },

    -- Movement Speeds (Studs per second)
    Movement = {
        WalkSpeed = 16,
        SprintSpeed = 25,
        DownedSpeed = 4,
        JumpPower = 50,
        JumpHeight = 7.2,
    },

    -- Downed & Revive Mechanics
    Downed = {
        BleedoutDuration = 45,       -- Seconds before bleeding out into death
        ReviveDuration = 5.0,        -- Seconds of continuous hold interaction to revive
        MaxReviveDistance = 10,      -- Studs from downed player to allow revive
        ReviveProgressStep = 1.0,    -- Progress rate per tick
    },

    -- Respawn System
    Respawn = {
        RespawnDelay = 5.0,          -- Seconds after death before respawn is allowed
        AutoRespawn = true,
        SafeSpawnOffset = Vector3.new(0, 5, 0),
    },

    -- World Zones Foundation
    Zones = {
        DefaultZone = "LandingBase" :: ZoneId,
        AllZones = {
            "LandingBase",
            "ResearchComplex",
            "Hospital",
            "Forest",
            "Underground",
            "AbandonedCity",
            "AlienNest",
        } :: { ZoneId },
        ZoneDisplayNames = {
            LandingBase = "Landing Base (Safe Hub)",
            ResearchComplex = "Research Complex Sector Alpha",
            Hospital = "Medical Center & Quarantine",
            Forest = "Blackwood Perimeter Forest",
            Underground = "Subterranean Geothermal Tunnels",
            AbandonedCity = "New Eden Colony Ruins",
            AlienNest = "Sub-Surface Hive Infestation",
        } :: { [string]: string },
        SafeZones = {
            LandingBase = true,
        } :: { [string]: boolean },
    },

    -- Allowed State Transitions (Server State Machine Rules)
    StateTransitions = {
        LOBBY = { SPAWNING = true, SPECTATING = true },
        SPAWNING = { ALIVE = true, DEAD = true },
        ALIVE = { SPRINTING = true, INTERACTING = true, DOWNED = true, DEAD = true, EXTRACTING = true, SPECTATING = true },
        SPRINTING = { ALIVE = true, INTERACTING = true, DOWNED = true, DEAD = true },
        INTERACTING = { ALIVE = true, DOWNED = true, DEAD = true },
        DOWNED = { ALIVE = true, DEAD = true, SPECTATING = true },
        DEAD = { SPAWNING = true, SPECTATING = true, LOBBY = true },
        EXTRACTING = { LOBBY = true, DEAD = true, SPECTATING = true },
        SPECTATING = { SPAWNING = true, LOBBY = true },
    } :: { [string]: { [string]: boolean } },
}

return table.freeze(PlayerConfig)
