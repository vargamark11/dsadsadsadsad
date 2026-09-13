--!strict
--[[
    InteractionConfig.luau
    Authoritative configuration, tuning parameters, loot tables, clearance levels,
    and defaults for the ALIEN: NIGHTFALL interaction framework.
]]

local InteractionTypes = require(script.Parent.Parent.src.shared.Types.InteractionTypes)

export type LootTable = InteractionTypes.LootTable
export type KeycardLevel = InteractionTypes.KeycardLevel

local InteractionConfig = {
    -- Global Defaults
    Defaults = {
        InteractionDistance = 10,       -- Studs
        MaxHoldDistance = 12,           -- Max drift before hold auto-cancels
        MinHoldDuration = 0.25,         -- Minimum duration to qualify as HOLD
        DefaultCooldown = 0.5,          -- Global anti-spam cooldown (seconds)
        PlayerCooldown = 0.3,           -- Per-player interaction cooldown
        RaycastOffset = Vector3.new(0, 1.5, 0), -- Humanoid chest/eye level
        ToleranceGracePeriod = 0.35,    -- Server timing latency leeway for hold completions
    },

    -- Keycard Clearance Level Hierarchy
    KeycardLevels = {
        LEVEL_1 = 1 :: KeycardLevel,
        LEVEL_2 = 2 :: KeycardLevel,
        LEVEL_3 = 3 :: KeycardLevel,
        LEVEL_4 = 4 :: KeycardLevel,
        LEVEL_5 = 5 :: KeycardLevel,
    },

    -- Item ID to Clearance Level Mapping
    KeycardItemMap = {
        KEYCARD_LEVEL_1 = 1,
        KEYCARD_LEVEL_2 = 2,
        KEYCARD_LEVEL_3 = 3,
        KEYCARD_MASTER = 4,
        KEYCARD_LEVEL_5 = 5,
    } :: { [string]: number },

    -- Door System Configuration
    Doors = {
        DefaultDistance = 9,
        AutoCloseDelay = 10.0,          -- Seconds before unlocked door auto-closes (0 = manual)
        DefaultOpenDuration = 1.2,      -- Motion / animation duration
        States = {
            CLOSED = "CLOSED",
            OPEN = "OPEN",
            LOCKED = "LOCKED",
            UNLOCKED = "UNLOCKED",
            LOCKDOWN = "LOCKDOWN",
            JAMMED = "JAMMED",
        },
    },

    -- Terminal / Computer Configuration
    Terminals = {
        DefaultDistance = 8,
        DefaultHackDuration = 4.5,
        States = {
            OFFLINE = "OFFLINE",
            ONLINE = "ONLINE",
            LOCKED = "LOCKED",
            HACKING = "HACKING",
            ACTIVE = "ACTIVE",
            DISABLED = "DISABLED",
        },
    },

    -- Generator Configuration
    Generators = {
        DefaultDistance = 10,
        RepairDuration = 6.0,
        RequiredFuseItem = "ITEM_HV_FUSE",
        OverloadTimer = 45.0,
        States = {
            OFF = "OFF",
            DAMAGED = "DAMAGED",
            REPAIRING = "REPAIRING",
            ACTIVE = "ACTIVE",
            OVERLOADED = "OVERLOADED",
        },
    },

    -- Container & Locker Configuration
    Containers = {
        DefaultDistance = 8,
        DefaultSearchDuration = 2.5,
        States = {
            CLOSED = "CLOSED",
            OPENING = "OPENING",
            OPEN = "OPEN",
            EMPTY = "EMPTY",
        },
    },

    -- Elevator Configuration
    Elevators = {
        DefaultDistance = 10,
        TravelDuration = 5.0,
        DoorTransitionDuration = 1.5,
        States = {
            IDLE = "IDLE",
            MOVING = "MOVING",
            LOCKED = "LOCKED",
            DISABLED = "DISABLED",
            DOORS_OPEN = "DOORS_OPEN",
            DOORS_CLOSING = "DOORS_CLOSING",
        },
    },

    -- Loot Tables for Scavenging & Containers
    LootTables = {
        MedicalCrate = {
            Id = "MedicalCrate",
            MinRolls = 1,
            MaxRolls = 3,
            Items = {
                { ItemId = "MED_BANDAGE", Chance = 0.75, MinQuantity = 1, MaxQuantity = 2 },
                { ItemId = "MED_KIT", Chance = 0.35, MinQuantity = 1, MaxQuantity = 1 },
                { ItemId = "MED_ADRENALINE", Chance = 0.15, MinQuantity = 1, MaxQuantity = 1 },
                { ItemId = "TOOL_FLASHLIGHT_BATTERY", Chance = 0.40, MinQuantity = 1, MaxQuantity = 1 },
            },
        },

        ResearchLocker = {
            Id = "ResearchLocker",
            MinRolls = 2,
            MaxRolls = 4,
            Items = {
                { ItemId = "KEYCARD_LEVEL_2", Chance = 0.25, MinQuantity = 1, MaxQuantity = 1 },
                { ItemId = "TOOL_FLASHLIGHT_BATTERY", Chance = 0.80, MinQuantity = 1, MaxQuantity = 2 },
                { ItemId = "TOOL_SONIC_DECOY", Chance = 0.20, MinQuantity = 1, MaxQuantity = 1 },
                { ItemId = "ITEM_HV_FUSE", Chance = 0.30, MinQuantity = 1, MaxQuantity = 1 },
            },
        },

        AmmoStash = {
            Id = "AmmoStash",
            MinRolls = 2,
            MaxRolls = 3,
            Items = {
                { ItemId = "AMMO_LIGHT", Chance = 0.85, MinQuantity = 1, MaxQuantity = 2 },
                { ItemId = "AMMO_MEDIUM", Chance = 0.60, MinQuantity = 1, MaxQuantity = 2 },
                { ItemId = "AMMO_SHELLS", Chance = 0.40, MinQuantity = 1, MaxQuantity = 1 },
                { ItemId = "AMMO_ENERGY", Chance = 0.15, MinQuantity = 1, MaxQuantity = 1 },
            },
        },

        SecurityArmory = {
            Id = "SecurityArmory",
            MinRolls = 3,
            MaxRolls = 5,
            Items = {
                { ItemId = "KEYCARD_LEVEL_3", Chance = 0.30, MinQuantity = 1, MaxQuantity = 1 },
                { ItemId = "KEYCARD_MASTER", Chance = 0.05, MinQuantity = 1, MaxQuantity = 1 },
                { ItemId = "AMMO_MEDIUM", Chance = 0.90, MinQuantity = 2, MaxQuantity = 3 },
                { ItemId = "AMMO_SHELLS", Chance = 0.70, MinQuantity = 1, MaxQuantity = 2 },
                { ItemId = "MED_KIT", Chance = 0.50, MinQuantity = 1, MaxQuantity = 1 },
            },
        },

        GeneratorScavenge = {
            Id = "GeneratorScavenge",
            MinRolls = 1,
            MaxRolls = 2,
            Items = {
                { ItemId = "ITEM_HV_FUSE", Chance = 0.50, MinQuantity = 1, MaxQuantity = 1 },
                { ItemId = "TOOL_FLASHLIGHT_BATTERY", Chance = 0.75, MinQuantity = 1, MaxQuantity = 2 },
            },
        },
    } :: { [string]: LootTable },

    -- Configurable Audio Asset Hooks (Roblox Sound IDs)
    AudioHooks = {
        DoorOpen = "rbxassetid://9114223175",
        DoorClose = "rbxassetid://9114223281",
        DoorLocked = "rbxassetid://9114223400",
        KeycardAccepted = "rbxassetid://9114223555",
        KeycardRejected = "rbxassetid://9114223680",
        TerminalBeep = "rbxassetid://9114223800",
        TerminalHack = "rbxassetid://9114223910",
        GeneratorHum = "rbxassetid://9114224050",
        GeneratorRepaired = "rbxassetid://9114224170",
        ButtonPressed = "rbxassetid://9114224300",
        ContainerOpened = "rbxassetid://9114224420",
        InteractionCancelled = "rbxassetid://9114224550",
    },

    -- Configurable Animation Asset Hooks
    AnimationHooks = {
        Repair = "rbxassetid://507770239",
        TerminalInteract = "rbxassetid://507770453",
        KeycardSwipe = "rbxassetid://507770677",
        ContainerSearch = "rbxassetid://507770891",
        ButtonPush = "rbxassetid://507771025",
    },
}

return table.freeze(InteractionConfig)
