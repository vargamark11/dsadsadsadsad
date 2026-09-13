--!strict
--[[
    CosmeticsConfig.luau
    Authoritative catalog for cosmetics in ALIEN: NIGHTFALL.
    Cosmetics provide zero statistical advantages (fair-play strictly enforced).
]]

export type CosmeticCategory =
    | "WEAPON_SKIN"
    | "CHARACTER_SUIT"
    | "EMOTE"
    | "TRAIL_EFFECT"
    | "PLAYER_TITLE"
    | "AVATAR_BADGE"

export type CosmeticRarity = "STANDARD" | "SUPERIOR" | "EXOTIC" | "MYTHIC"

export type CosmeticItem = {
    Id: string,
    Name: string,
    Category: CosmeticCategory,
    Rarity: CosmeticRarity,
    Description: string,
    PriceCredits: number?,
    PriceNanites: number?,
    AssetId: string,              -- Roblox MeshId / TextureId / AnimationId
    EquipSlot: string,
    SeasonExclusive: number?,
}

local CosmeticsConfig: {
    Items: { [string]: CosmeticItem },
    DefaultLoadout: { [string]: string },
} = {
    Items = {
        -- Character Suits
        SUIT_VANGUARD_DEFAULT = {
            Id = "SUIT_VANGUARD_DEFAULT",
            Name = "Standard Haz-Spec Suit",
            Category = "CHARACTER_SUIT",
            Rarity = "STANDARD",
            Description = "Standard issue vacuum-sealed survival suit for colony contractors.",
            PriceCredits = 0,
            AssetId = "rbxassetid://101001",
            EquipSlot = "CharacterSuit",
        },
        SUIT_BIO_OPERATOR = {
            Id = "SUIT_BIO_OPERATOR",
            Name = "Bio-Containment Enforcer",
            Category = "CHARACTER_SUIT",
            Rarity = "SUPERIOR",
            Description = "Reinforced hazard plating with neon-amber filter vents.",
            PriceCredits = 1200,
            PriceNanites = 150,
            AssetId = "rbxassetid://101002",
            EquipSlot = "CharacterSuit",
        },
        SUIT_NIGHTFALL_SPEC_OPS = {
            Id = "SUIT_NIGHTFALL_SPEC_OPS",
            Name = "Eclipse Black-Ops Exoskeleton",
            Category = "CHARACTER_SUIT",
            Rarity = "EXOTIC",
            Description = "Matte obsidian tactical weave with luminescent sensor visor.",
            PriceNanites = 400,
            AssetId = "rbxassetid://101003",
            EquipSlot = "CharacterSuit",
            SeasonExclusive = 1,
        },

        -- Weapon Skins
        SKIN_PISTOL_CARBON = {
            Id = "SKIN_PISTOL_CARBON",
            Name = "Carbon-Fiber P9",
            Category = "WEAPON_SKIN",
            Rarity = "STANDARD",
            Description = "Textured carbon fiber upper slide.",
            PriceCredits = 400,
            AssetId = "rbxassetid://102001",
            EquipSlot = "PISTOL_STANDARD",
        },
        SKIN_AR_XENO_CHITIN = {
            Id = "SKIN_AR_XENO_CHITIN",
            Name = "Carapace Infiltration AR-24",
            Category = "WEAPON_SKIN",
            Rarity = "EXOTIC",
            Description = "Bio-luminescent organic veins pulsing along the gun barrel.",
            PriceNanites = 350,
            AssetId = "rbxassetid://102002",
            EquipSlot = "RIFLE_ASSAULT",
            SeasonExclusive = 1,
        },

        -- Emotes
        EMOTE_TACTICAL_SCAN = {
            Id = "EMOTE_TACTICAL_SCAN",
            Name = "Scan Surrounding Area",
            Category = "EMOTE",
            Rarity = "STANDARD",
            Description = "Character raises wrist scanner to inspect perimeter.",
            PriceCredits = 300,
            AssetId = "rbxassetid://103001",
            EquipSlot = "EmoteWheel_1",
        },
        EMOTE_PANIC_LOOK = {
            Id = "EMOTE_PANIC_LOOK",
            Name = "Paranoid Check",
            Category = "EMOTE",
            Rarity = "SUPERIOR",
            Description = "Nervously points flashlight into the darkness behind.",
            PriceCredits = 650,
            AssetId = "rbxassetid://103002",
            EquipSlot = "EmoteWheel_2",
        },

        -- Player Titles
        TITLE_SURVIVOR = {
            Id = "TITLE_SURVIVOR",
            Name = "Colony Survivor",
            Category = "PLAYER_TITLE",
            Rarity = "STANDARD",
            Description = "Display title beneath username.",
            PriceCredits = 0,
            AssetId = "Survivor",
            EquipSlot = "PlayerTitle",
        },
        TITLE_APEX_SLAYER = {
            Id = "TITLE_APEX_SLAYER",
            Name = "Hive Matriarch Slayer",
            Category = "PLAYER_TITLE",
            Rarity = "MYTHIC",
            Description = "Awarded for defeating the Hive Empress on Nightmare difficulty.",
            PriceNanites = nil,
            AssetId = "Hive Matriarch Slayer",
            EquipSlot = "PlayerTitle",
        },
    },

    DefaultLoadout = {
        CharacterSuit = "SUIT_VANGUARD_DEFAULT",
        PISTOL_STANDARD = "NONE",
        RIFLE_ASSAULT = "NONE",
        PlayerTitle = "TITLE_SURVIVOR",
    },
}

return table.freeze(CosmeticsConfig)
