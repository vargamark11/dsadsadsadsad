--!strict
--[[
    InteractionConfig.luau
    Central configuration for Phase 3 Interaction System.
    Synchronized to ReplicatedStorage.Config.InteractionConfig via Rojo.
]]

export type ClearanceLevel =
    | "NONE"
    | "KEYCARD_LEVEL_1"
    | "KEYCARD_LEVEL_2"
    | "KEYCARD_LEVEL_3"
    | "KEYCARD_MASTER"
    | "KEYCARD_LEVEL_5"

local InteractionConfig = {
    -- Distance & Spatial Validation
    Validation = {
        DefaultDistance = 10.0,       -- Maximum studs from player to interactive object
        LatencyToleranceBuffer = 2.5, -- Extra studs buffer for network ping variance
        MaxAllowedDistance = 15.0,    -- Absolute server cutoff regardless of object
        RaycastHeadOffset = Vector3.new(0, 1.5, 0), -- Ray origin offset from HumanoidRootPart
        HoldCancellationDriftBuffer = 3.5, -- Studs player can drift during hold before cancel
    },

    -- Hold Duration Defaults (Seconds)
    HoldDurations = {
        QuickSearch = 1.5,
        ContainerSearch = 3.0,
        TerminalHack = 4.0,
        DoorManualOverride = 3.5,
        GeneratorRepair = 6.0,
        AirlockPurge = 5.0,
        SelfDestructHold = 8.0,
        ReviveTeammate = 5.0,
    },

    -- Cooldowns (Anti-Spam Throttling)
    Cooldowns = {
        PlayerInteraction = 0.25, -- Minimum seconds between requests per player
        ObjectInteraction = 0.50, -- Minimum seconds between triggers on same object
        RemoteTokenRate = 10,     -- Requests per second token bucket rate
    },

    -- Keycard Clearance Hierarchy Values (Higher value unlocks lower tiers)
    ClearanceHierarchy = {
        NONE = 0,
        KEYCARD_LEVEL_1 = 1,
        KEYCARD_LEVEL_2 = 2,
        KEYCARD_LEVEL_3 = 3,
        KEYCARD_MASTER = 4,
        KEYCARD_LEVEL_5 = 5,
    } :: { [ClearanceLevel]: number },

    -- Server-Side Loot Tables
    LootTables = {
        MedicalCabinet = {
            RollCount = { Min = 1, Max = 3 },
            Entries = {
                { ItemId = "ITEM_MEDKIT_SMALL", Weight = 50, MinCount = 1, MaxCount = 2 },
                { ItemId = "ITEM_BANDAGE", Weight = 35, MinCount = 2, MaxCount = 3 },
                { ItemId = "ITEM_STIM_INJECTOR", Weight = 15, MinCount = 1, MaxCount = 1 },
            },
        },
        AmmoCrate = {
            RollCount = { Min = 2, Max = 4 },
            Entries = {
                { ItemId = "AMMO_PULSE_RIFLE", Weight = 45, MinCount = 30, MaxCount = 60 },
                { ItemId = "AMMO_SHOTGUN", Weight = 30, MinCount = 8, MaxCount = 16 },
                { ItemId = "AMMO_MAGNUM", Weight = 15, MinCount = 6, MaxCount = 12 },
                { ItemId = "AMMO_FLAMETHROWER", Weight = 10, MinCount = 50, MaxCount = 100 },
            },
        },
        ToolLocker = {
            RollCount = { Min = 1, Max = 2 },
            Entries = {
                { ItemId = "ITEM_HV_FUSE", Weight = 40, MinCount = 1, MaxCount = 1 },
                { ItemId = "ITEM_BLOWTORCH", Weight = 25, MinCount = 1, MaxCount = 1 },
                { ItemId = "KEYCARD_LEVEL_1", Weight = 20, MinCount = 1, MaxCount = 1 },
                { ItemId = "KEYCARD_LEVEL_2", Weight = 15, MinCount = 1, MaxCount = 1 },
            },
        },
    },

    -- Prompt Badges Configuration (Cross-Platform Key Glyphs)
    PlatformKeyMap = {
        Desktop = {
            Interact = "E",
            Cancel = "Q",
        },
        Console = {
            Interact = "ButtonX",
            Cancel = "ButtonB",
        },
        Mobile = {
            Interact = "TAP",
            Hold = "HOLD",
        },
    },
}

return table.freeze(InteractionConfig)
