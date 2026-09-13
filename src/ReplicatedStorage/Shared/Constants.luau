--!strict
--[[
    Constants.luau
    Universal gameplay, networking, and system constants for ALIEN: NIGHTFALL.
    Synchronized to ReplicatedStorage.Shared.Constants via Rojo.
]]

local Constants = {
    GameTitle = "ALIEN: NIGHTFALL",
    Version = "0.2.0-rojo.release",

    -- Multiplayer Settings
    MinPlayers = 1,
    MaxPlayers = 8,
    DefaultPartySize = 4,

    -- Player Core Mechanics
    DefaultHealth = 100,
    MaxHealth = 100,
    DefaultStamina = 100,
    MaxStamina = 100,
    
    WalkSpeed = 16,
    SprintSpeed = 25,
    DownedSpeed = 4,

    SprintDrainRate = 18,        -- Stamina consumed per second
    StaminaRecoveryRate = 22,    -- Stamina recovered per second
    StaminaRecoveryDelay = 1.25, -- Seconds before stamina starts regenerating
    MinimumSprintStamina = 10,   -- Minimum stamina threshold to sprint

    -- Downed & Revive Constants
    DownedBleedoutDuration = 45, -- Seconds until death if not revived
    ReviveDuration = 5.0,        -- Seconds of hold interaction to revive
    RevivedHealthPercent = 0.40, -- 40% health granted on teammate revive
    MaxReviveDistance = 10,      -- Studs

    -- Interaction System Defaults
    DefaultInteractionDistance = 10,  -- Studs
    InteractionToleranceBuffer = 2.5, -- Studs buffer for latency
    MaxHoldDuration = 30.0,           -- Maximum single hold interaction in seconds
    AntiSpamCooldown = 0.25,          -- Minimum seconds between interactions

    -- Sound & Sensory Radii (Studs for Alien AI detection)
    SoundRadii = {
        CrouchWalk = 0,
        Walk = 25,
        Sprint = 75,
        DoorOpen = 35,
        Gunshot = 160,
        Explosion = 300,
    },

    -- Network Rate Limits (Tokens / second)
    RateLimits = {
        InteractRequest = 10,
        SprintRequest = 10,
        ReviveInteraction = 5,
        FireWeapon = 25,
        ReloadRequest = 5,
        PerformAction = 10,
    },

    -- Safe Zone Radius
    LandingBaseSafeRadius = 140,
}

return table.freeze(Constants)
