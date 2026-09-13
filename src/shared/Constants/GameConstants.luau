--!strict
--[[
    GameConstants.luau
    Universal gameplay constants for ALIEN: NIGHTFALL.
]]

local GameConstants = {
    GameTitle = "ALIEN: NIGHTFALL",
    Version = "0.1.0-alpha.architecture",

    -- Multiplayer Capacity
    MinPlayers = 1,
    MaxPlayers = 8,

    -- Player Mechanics
    DefaultHealth = 100,
    DefaultStamina = 100,
    WalkSpeed = 16,
    SprintSpeed = 25,
    DownedSpeed = 4,

    StaminaSprintDrainRate = 18,     -- Units per second
    StaminaRegenRate = 22,           -- Units per second
    StaminaRegenDelay = 1.25,        -- Delay before regen starts after sprinting

    -- Downed & Revive
    DownedBleedoutDuration = 45,     -- Seconds before death if not revived
    ReviveDuration = 5.0,            -- Seconds of continuous hold interaction to revive
    RevivedHealthPercent = 0.40,     -- Player returns with 40% HP upon revive

    -- Sensory & Sound Radii (Studs)
    SoundProfiles = {
        CrouchWalk = 0,              -- Silent
        Walk = 25,
        Sprint = 75,
        DoorOpen = 35,
        Gunshot = 160,
        Explosion = 300,
        Decoy = 200,
    },

    -- Performance & Update Intervals (Optimized for Roblox StreamingEnabled)
    AIUpdateInterval = 0.25,         -- 4Hz sensory sweep per active alien
    CombatMaxRayDistance = 800,
    MaxInteractDistance = 10,

    -- Safe Zones
    LandingBaseSafeZoneRadius = 140,
}

return table.freeze(GameConstants)
