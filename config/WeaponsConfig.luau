--!strict
--[[
    WeaponsConfig.luau
    Authoritative weapon specifications for ALIEN: NIGHTFALL.
    Includes fire rates, magazine capacities, recoil, noise radii (for AI hearing),
    and damage dropoffs strictly verified by CombatService and WeaponService.
]]

export type WeaponId = "PISTOL_STANDARD" | "SMG_RAPID" | "RIFLE_ASSAULT" | "SHOTGUN_BREACH" | "SNIPER_RAIL" | "WEAPON_EXPERIMENTAL"

export type WeaponType = "Pistol" | "SMG" | "AssaultRifle" | "Shotgun" | "Sniper" | "Experimental"

export type WeaponFireMode = "Semi" | "Auto" | "Burst" | "Charge"

export type WeaponConfigDef = {
    Id: WeaponId,
    Name: string,
    Category: WeaponType,
    FireMode: WeaponFireMode,
    BaseDamage: number,
    HeadshotMultiplier: number,
    Pellets: number,               -- >1 for shotguns
    FireRate: number,              -- Shots per second (Hz)
    MagazineCapacity: number,
    MaxReserveAmmo: number,
    ReloadDuration: number,        -- Seconds
    EffectiveRange: number,        -- Studs before damage falloff begins
    MaxRange: number,              -- Studs limit for raycast verification
    FalloffMinPercent: number,     -- Damage multiplier at MaxRange (e.g. 0.35)
    NoiseRadius: number,           -- Sound broadcast radius in studs for Alien AI hearing
    RecoilPattern: {
        VerticalKick: number,
        HorizontalSway: number,
        RecoverySpeed: number,
    },
    BasePriceCredits: number,
    RequiredLevel: number,
}

local WeaponsConfig: { [WeaponId]: WeaponConfigDef } = {
    PISTOL_STANDARD = {
        Id = "PISTOL_STANDARD",
        Name = "Vanguard P9 Service Pistol",
        Category = "Pistol",
        FireMode = "Semi",
        BaseDamage = 26,
        HeadshotMultiplier = 1.75,
        Pellets = 1,
        FireRate = 4.5,
        MagazineCapacity = 15,
        MaxReserveAmmo = 90,
        ReloadDuration = 1.4,
        EffectiveRange = 60,
        MaxRange = 250,
        FalloffMinPercent = 0.4,
        NoiseRadius = 75,
        RecoilPattern = {
            VerticalKick = 1.2,
            HorizontalSway = 0.4,
            RecoverySpeed = 8.0,
        },
        BasePriceCredits = 0,
        RequiredLevel = 1,
    },

    SMG_RAPID = {
        Id = "SMG_RAPID",
        Name = "Spectre-9 Tactical SMG",
        Category = "SMG",
        FireMode = "Auto",
        BaseDamage = 18,
        HeadshotMultiplier = 1.5,
        Pellets = 1,
        FireRate = 12.0,
        MagazineCapacity = 32,
        MaxReserveAmmo = 192,
        ReloadDuration = 1.8,
        EffectiveRange = 50,
        MaxRange = 200,
        FalloffMinPercent = 0.3,
        NoiseRadius = 90,
        RecoilPattern = {
            VerticalKick = 0.9,
            HorizontalSway = 0.8,
            RecoverySpeed = 6.5,
        },
        BasePriceCredits = 450,
        RequiredLevel = 2,
    },

    RIFLE_ASSAULT = {
        Id = "RIFLE_ASSAULT",
        Name = "Aegis AR-24 Defense Rifle",
        Category = "AssaultRifle",
        FireMode = "Auto",
        BaseDamage = 28,
        HeadshotMultiplier = 1.85,
        Pellets = 1,
        FireRate = 8.5,
        MagazineCapacity = 30,
        MaxReserveAmmo = 180,
        ReloadDuration = 2.2,
        EffectiveRange = 100,
        MaxRange = 400,
        FalloffMinPercent = 0.5,
        NoiseRadius = 140,
        RecoilPattern = {
            VerticalKick = 1.6,
            HorizontalSway = 0.6,
            RecoverySpeed = 5.0,
        },
        BasePriceCredits = 850,
        RequiredLevel = 4,
    },

    SHOTGUN_BREACH = {
        Id = "SHOTGUN_BREACH",
        Name = "Cerberus-12 Breaching Scattergun",
        Category = "Shotgun",
        FireMode = "Semi",
        BaseDamage = 14,             -- Per pellet
        HeadshotMultiplier = 1.4,
        Pellets = 8,                 -- 8 * 14 = 112 point-blank max
        FireRate = 1.6,
        MagazineCapacity = 6,
        MaxReserveAmmo = 36,
        ReloadDuration = 2.8,
        EffectiveRange = 25,
        MaxRange = 90,
        FalloffMinPercent = 0.15,
        NoiseRadius = 160,
        RecoilPattern = {
            VerticalKick = 4.2,
            HorizontalSway = 1.1,
            RecoverySpeed = 3.5,
        },
        BasePriceCredits = 700,
        RequiredLevel = 3,
    },

    SNIPER_RAIL = {
        Id = "SNIPER_RAIL",
        Name = "Hyperion Longshot Marksman",
        Category = "Sniper",
        FireMode = "Semi",
        BaseDamage = 135,
        HeadshotMultiplier = 2.5,
        Pellets = 1,
        FireRate = 0.9,
        MagazineCapacity = 5,
        MaxReserveAmmo = 25,
        ReloadDuration = 3.2,
        EffectiveRange = 250,
        MaxRange = 800,
        FalloffMinPercent = 0.8,
        NoiseRadius = 220,
        RecoilPattern = {
            VerticalKick = 6.0,
            HorizontalSway = 0.2,
            RecoverySpeed = 2.5,
        },
        BasePriceCredits = 1250,
        RequiredLevel = 6,
    },

    WEAPON_EXPERIMENTAL = {
        Id = "WEAPON_EXPERIMENTAL",
        Name = "Tesla-Arc Prototype Core",
        Category = "Experimental",
        FireMode = "Charge",
        BaseDamage = 85,
        HeadshotMultiplier = 1.2,
        Pellets = 1,
        FireRate = 2.0,
        MagazineCapacity = 20,       -- Energy charge cells
        MaxReserveAmmo = 60,
        ReloadDuration = 2.5,
        EffectiveRange = 70,
        MaxRange = 180,
        FalloffMinPercent = 0.6,
        NoiseRadius = 110,
        RecoilPattern = {
            VerticalKick = 1.0,
            HorizontalSway = 1.0,
            RecoverySpeed = 4.0,
        },
        BasePriceCredits = 2500,
        RequiredLevel = 10,
    },
}

return table.freeze(WeaponsConfig)
