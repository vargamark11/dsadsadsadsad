--!strict
--[[
    WorldConfig.luau
    Central configuration for world zones, safe areas, difficulty tiers, and environment hazards.
    Synchronized to ReplicatedStorage.Config.WorldConfig via Rojo.
]]

export type ZoneId =
    | "LandingBase"
    | "ResearchComplex"
    | "Hospital"
    | "Forest"
    | "Underground"
    | "AbandonedCity"
    | "AlienNest"

export type ZoneDefinition = {
    Id: ZoneId,
    DisplayName: string,
    Description: string,
    IsSafeZone: boolean,
    ThreatLevel: number,          -- 1 (Minimal) to 5 (Extremely Dangerous)
    DifficultyMultiplier: number, -- Multiplier for alien spawn counts and perception
    AmbientLighting: Color3,
    FogDensity: number,
    OutdoorFogDistance: number,
    AllowedSpawnTypes: { string },
    KeycardRequired: string?,
}

local WorldConfig = {
    DefaultZone = "LandingBase" :: ZoneId,

    -- All Registered Zone IDs
    ZoneIds = {
        LandingBase = "LandingBase",
        ResearchComplex = "ResearchComplex",
        Hospital = "Hospital",
        Forest = "Forest",
        Underground = "Underground",
        AbandonedCity = "AbandonedCity",
        AlienNest = "AlienNest",
    } :: { [string]: ZoneId },

    -- Safe Zones (Hostile AI Spawning & Damage strictly disabled)
    SafeZones = {
        LandingBase = true,
    } :: { [ZoneId]: boolean },

    -- Complete Zone Definitions
    Zones = {
        LandingBase = {
            Id = "LandingBase",
            DisplayName = "Landing Base (Aegis Hub)",
            Description = "Fortified perimeter outpost with automated point-defense and landing pads.",
            IsSafeZone = true,
            ThreatLevel = 1,
            DifficultyMultiplier = 0.5,
            AmbientLighting = Color3.fromRGB(80, 85, 95),
            FogDensity = 0.05,
            OutdoorFogDistance = 250,
            AllowedSpawnTypes = {},
            KeycardRequired = nil,
        } :: ZoneDefinition,

        ResearchComplex = {
            Id = "ResearchComplex",
            DisplayName = "Research Complex Sector Alpha",
            Description = "Sub-level xenobiology labs and containment corridors with biometric locks.",
            IsSafeZone = false,
            ThreatLevel = 3,
            DifficultyMultiplier = 1.2,
            AmbientLighting = Color3.fromRGB(35, 45, 55),
            FogDensity = 0.12,
            OutdoorFogDistance = 140,
            AllowedSpawnTypes = { "Crawler", "Stalker", "Spitter" },
            KeycardRequired = "KEYCARD_LEVEL_2",
        } :: ZoneDefinition,

        Hospital = {
            Id = "Hospital",
            DisplayName = "Medical Center & Quarantine",
            Description = "Quarantined surgical suites and intensive care wards overrun by xenomorph scouts.",
            IsSafeZone = false,
            ThreatLevel = 3,
            DifficultyMultiplier = 1.3,
            AmbientLighting = Color3.fromRGB(30, 40, 45),
            FogDensity = 0.14,
            OutdoorFogDistance = 120,
            AllowedSpawnTypes = { "Drone", "Crawler", "Facehugger" },
            KeycardRequired = "KEYCARD_LEVEL_1",
        } :: ZoneDefinition,

        Forest = {
            Id = "Forest",
            DisplayName = "Blackwood Perimeter Forest",
            Description = "Dense extraterrestrial pine woodlands shrouded in heavy fog and hunting prowlers.",
            IsSafeZone = false,
            ThreatLevel = 2,
            DifficultyMultiplier = 1.0,
            AmbientLighting = Color3.fromRGB(25, 30, 35),
            FogDensity = 0.22,
            OutdoorFogDistance = 80,
            AllowedSpawnTypes = { "Drone", "Stalker" },
            KeycardRequired = nil,
        } :: ZoneDefinition,

        Underground = {
            Id = "Underground",
            DisplayName = "Subterranean Geothermal Tunnels",
            Description = "Dark utility shafts and pipes beneath the colony with zero natural light.",
            IsSafeZone = false,
            ThreatLevel = 4,
            DifficultyMultiplier = 1.6,
            AmbientLighting = Color3.fromRGB(15, 15, 20),
            FogDensity = 0.18,
            OutdoorFogDistance = 60,
            AllowedSpawnTypes = { "Drone", "Warrior", "Burrower" },
            KeycardRequired = "KEYCARD_LEVEL_3",
        } :: ZoneDefinition,

        AbandonedCity = {
            Id = "AbandonedCity",
            DisplayName = "New Eden Colony Ruins",
            Description = "Crumbling urban high-rises and transit corridors littered with wreckage.",
            IsSafeZone = false,
            ThreatLevel = 4,
            DifficultyMultiplier = 1.5,
            AmbientLighting = Color3.fromRGB(20, 25, 35),
            FogDensity = 0.16,
            OutdoorFogDistance = 90,
            AllowedSpawnTypes = { "Drone", "Warrior", "Spitter", "Stalker" },
            KeycardRequired = nil,
        } :: ZoneDefinition,

        AlienNest = {
            Id = "AlienNest",
            DisplayName = "Sub-Surface Hive Infestation",
            Description = "Bioresin hive chambers housing egg clusters and the Praetorian guard.",
            IsSafeZone = false,
            ThreatLevel = 5,
            DifficultyMultiplier = 2.0,
            AmbientLighting = Color3.fromRGB(25, 10, 15),
            FogDensity = 0.25,
            OutdoorFogDistance = 45,
            AllowedSpawnTypes = { "Facehugger", "Warrior", "Praetorian" },
            KeycardRequired = "KEYCARD_MASTER",
        } :: ZoneDefinition,
    },
}

return table.freeze(WorldConfig)
