--!strict
--[[
    PlayerConfig.luau
    Central configuration for player health, stamina, movement, and life cycles.
    Synchronized to ReplicatedStorage.Config.PlayerConfig via Rojo.
]]

local PlayerConfig = {
    -- Health Attributes
    DefaultHealth = 100,
    MaxHealth = 100,
    MinHealth = 0,
    RespawnHealth = 100,
    RevivedHealthPercent = 0.40, -- 40% health restored upon revive
    NaturalRegenEnabled = false, -- Survival requirement: medical items needed to restore HP

    -- Stamina Attributes
    DefaultStamina = 100,
    MaxStamina = 100,
    SprintDrainRate = 18,        -- Units drained per second while sprinting
    StaminaRecoveryRate = 22,    -- Units recovered per second while resting
    MinimumSprintStamina = 10,   -- Minimum stamina threshold to initiate sprint
    StaminaRecoveryDelay = 1.25, -- Seconds delay before recovery begins

    -- Movement Speeds (Studs per second)
    Movement = {
        WalkSpeed = 16,
        SprintSpeed = 25,
        DownedSpeed = 4,
        JumpPower = 50,
        JumpHeight = 7.2,
    },

    -- Downed & Revive Timing
    Downed = {
        BleedoutDuration = 45,    -- Seconds before death if not revived
        ReviveDuration = 5.0,     -- Seconds of continuous hold interaction to revive
        MaxReviveDistance = 10,   -- Studs
        ReviveProgressStep = 1.0, -- Progress increment per second
    },

    -- Respawn System
    Respawn = {
        RespawnDelay = 5.0,
        AutoRespawn = true,
        SafeSpawnOffset = Vector3.new(0, 5, 0),
    },

    -- Valid State Transitions (Authoritative FSM)
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
