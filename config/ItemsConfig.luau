--!strict
--[[
    ItemsConfig.luau
    Master catalog of all scavengeable, mission, medical, and equipment items in ALIEN: NIGHTFALL.
]]

export type ItemCategory =
    | "WEAPON"
    | "AMMO"
    | "BATTERY"
    | "MEDICAL"
    | "KEYCARD"
    | "TOOL"
    | "MISSION"
    | "COLLECTIBLE"

export type ItemRarity = "COMMON" | "UNCOMMON" | "RARE" | "EPIC" | "CLASSIFIED"

export type ItemDef = {
    Id: string,
    Name: string,
    Category: ItemCategory,
    Rarity: ItemRarity,
    Description: string,
    MaxStack: number,
    Weight: number,                -- kg for stamina drain scaling
    UseTime: number,               -- Interaction/use time in seconds
    ConsumeOnUse: boolean,
    Attributes: { [string]: any },
}

local ItemsConfig: { [string]: ItemDef } = {
    -- Medical Items
    MED_BANDAGE = {
        Id = "MED_BANDAGE",
        Name = "Hemostatic Bandage",
        Category = "MEDICAL",
        Rarity = "COMMON",
        Description = "Stops bleeding and restores 25 health over 5 seconds.",
        MaxStack = 5,
        Weight = 0.2,
        UseTime = 2.0,
        ConsumeOnUse = true,
        Attributes = { HealAmount = 25, StopsBleeding = true, Duration = 5.0 },
    },
    MED_KIT = {
        Id = "MED_KIT",
        Name = "Emergency Trauma Kit",
        Category = "MEDICAL",
        Rarity = "UNCOMMON",
        Description = "Field medical pack. Restores 75 health and clears status ailments.",
        MaxStack = 2,
        Weight = 1.0,
        UseTime = 4.5,
        ConsumeOnUse = true,
        Attributes = { HealAmount = 75, FullHealBleed = true },
    },
    MED_ADRENALINE = {
        Id = "MED_ADRENALINE",
        Name = "Epi-Boost Injector",
        Category = "MEDICAL",
        Rarity = "RARE",
        Description = "Instantly restores full stamina and grants 25% sprint speed for 12 seconds.",
        MaxStack = 3,
        Weight = 0.3,
        UseTime = 1.2,
        ConsumeOnUse = true,
        Attributes = { StaminaRestore = 100, SpeedBuff = 1.25, BuffDuration = 12.0 },
    },

    -- Ammo Types
    AMMO_LIGHT = {
        Id = "AMMO_LIGHT",
        Name = "9x19mm Standard Mag",
        Category = "AMMO",
        Rarity = "COMMON",
        Description = "Standard pistol / SMG ammunition box (30 rounds).",
        MaxStack = 8,
        Weight = 0.4,
        UseTime = 0.0,
        ConsumeOnUse = true,
        Attributes = { BulletType = "Light", Rounds = 30 },
    },
    AMMO_MEDIUM = {
        Id = "AMMO_MEDIUM",
        Name = "5.56mm Armor-Piercing Clip",
        Category = "AMMO",
        Rarity = "COMMON",
        Description = "Rifle cartridge clip (30 rounds).",
        MaxStack = 6,
        Weight = 0.6,
        UseTime = 0.0,
        ConsumeOnUse = true,
        Attributes = { BulletType = "Medium", Rounds = 30 },
    },
    AMMO_SHELLS = {
        Id = "AMMO_SHELLS",
        Name = "12-Gauge Tungsten Buckshot",
        Category = "AMMO",
        Rarity = "UNCOMMON",
        Description = "Heavy duty shotgun shells (8 shells).",
        MaxStack = 6,
        Weight = 0.5,
        UseTime = 0.0,
        ConsumeOnUse = true,
        Attributes = { BulletType = "Shotgun", Rounds = 8 },
    },
    AMMO_ENERGY = {
        Id = "AMMO_ENERGY",
        Name = "Plasma Battery Cell",
        Category = "AMMO",
        Rarity = "RARE",
        Description = "High-output energy capacitor for experimental tech (20 charges).",
        MaxStack = 4,
        Weight = 0.8,
        UseTime = 0.0,
        ConsumeOnUse = true,
        Attributes = { BulletType = "Energy", Rounds = 20 },
    },

    -- Keycards
    KEYCARD_LEVEL_1 = {
        Id = "KEYCARD_LEVEL_1",
        Name = "Maintenance Keycard (Level 1)",
        Category = "KEYCARD",
        Rarity = "COMMON",
        Description = "Grants access to utility corridors, storerooms, and generator stations.",
        MaxStack = 1,
        Weight = 0.1,
        UseTime = 0.5,
        ConsumeOnUse = false,
        Attributes = { ClearanceLevel = 1, Color = "Cyan" },
    },
    KEYCARD_LEVEL_2 = {
        Id = "KEYCARD_LEVEL_2",
        Name = "Research Sector Keycard (Level 2)",
        Category = "KEYCARD",
        Rarity = "UNCOMMON",
        Description = "Unlocks laboratories, hospital isolation units, and observation decks.",
        MaxStack = 1,
        Weight = 0.1,
        UseTime = 0.5,
        ConsumeOnUse = false,
        Attributes = { ClearanceLevel = 2, Color = "Yellow" },
    },
    KEYCARD_LEVEL_3 = {
        Id = "KEYCARD_LEVEL_3",
        Name = "Security Director Keycard (Level 3)",
        Category = "KEYCARD",
        Rarity = "RARE",
        Description = "Grants access to armories, security control rooms, and subway gates.",
        MaxStack = 1,
        Weight = 0.1,
        UseTime = 0.5,
        ConsumeOnUse = false,
        Attributes = { ClearanceLevel = 3, Color = "Red" },
    },
    KEYCARD_MASTER = {
        Id = "KEYCARD_MASTER",
        Name = "Colony Executive Master Key",
        Category = "KEYCARD",
        Rarity = "CLASSIFIED",
        Description = "Overrides all electromagnetic airlocks, blast doors, and extraction pods.",
        MaxStack = 1,
        Weight = 0.1,
        UseTime = 0.5,
        ConsumeOnUse = false,
        Attributes = { ClearanceLevel = 4, Color = "Black" },
    },

    -- Tools & Gadgets
    TOOL_FLASHLIGHT_BATTERY = {
        Id = "TOOL_FLASHLIGHT_BATTERY",
        Name = "High-Density Lithium Cell",
        Category = "BATTERY",
        Rarity = "COMMON",
        Description = "Restores 100% battery power to flashlights and night-vision gear.",
        MaxStack = 4,
        Weight = 0.3,
        UseTime = 1.0,
        ConsumeOnUse = true,
        Attributes = { BatteryRecharge = 100 },
    },
    TOOL_SONIC_DECOY = {
        Id = "TOOL_SONIC_DECOY",
        Name = "Acoustic Audio Decoy",
        Category = "TOOL",
        Rarity = "RARE",
        Description = "Throwable device emits fake human footsteps and gunfire for 15s to lure aliens.",
        MaxStack = 2,
        Weight = 0.8,
        UseTime = 0.8,
        ConsumeOnUse = true,
        Attributes = { DecoyDuration = 15, NoiseRadius = 180, AlienPriority = 2 },
    },

    -- Mission Specific
    ITEM_HV_FUSE = {
        Id = "ITEM_HV_FUSE",
        Name = "High-Voltage Grid Fuse",
        Category = "MISSION",
        Rarity = "UNCOMMON",
        Description = "Industrial ceramic fuse required to jumpstart the colony electrical substation.",
        MaxStack = 3,
        Weight = 2.0,
        UseTime = 1.5,
        ConsumeOnUse = true,
        Attributes = { MissionTag = "POWER_REPAIR" },
    },
    ITEM_RESEARCH_DRIVE = {
        Id = "ITEM_RESEARCH_DRIVE",
        Name = "Encrypted Bio-Telemetric Datacore",
        Category = "MISSION",
        Rarity = "EPIC",
        Description = "Contains flight records and alien organism genetic sequencing data.",
        MaxStack = 1,
        Weight = 1.5,
        UseTime = 3.0,
        ConsumeOnUse = false,
        Attributes = { MissionTag = "SPECIMEN_EXTRACT" },
    },
}

return table.freeze(ItemsConfig)
