--!strict
--[[
    EventsConfig.luau
    Dynamic event parameters for world, horror, and extraction threats in ALIEN: NIGHTFALL.
    Usable by both runtime EventService and AdminService.
]]

export type WorldEventType =
    | "BLACKOUT"
    | "STORM"
    | "FOG"
    | "ALIEN_HUNT"
    | "POWER_FAILURE"
    | "LOCKDOWN"
    | "EMERGENCY"
    | "BOSS_EVENT"
    | "EXTRACTION_ATTACK"
    | "RADIO_EVENT"

export type EventConfigDef = {
    Type: WorldEventType,
    Title: string,
    Description: string,
    DurationSeconds: number,
    LightingPreset: {
        Brightness: number,
        FogEnd: number,
        AmbientColor: { R: number, G: number, B: number },
        EmergencyLightsRed: boolean,
    },
    AudioTrack: string,
    AlienSpawnRateMultiplier: number,
    AlienSpeedMultiplier: number,
    SafeZoneDisabled: boolean,
    MinTimeBetweenOccurrences: number,
}

local EventsConfig: { [WorldEventType]: EventConfigDef } = {
    BLACKOUT = {
        Type = "BLACKOUT",
        Title = "Catastrophic Power Failure",
        Description = "Colony generators tripped. Visibility reduced to zero without flashlight.",
        DurationSeconds = 90,
        LightingPreset = {
            Brightness = 0.05,
            FogEnd = 40,
            AmbientColor = { R = 8, G = 8, B = 14 },
            EmergencyLightsRed = true,
        },
        AudioTrack = "rbxassetid://audio_blackout_drone",
        AlienSpawnRateMultiplier = 1.8,
        AlienSpeedMultiplier = 1.15,
        SafeZoneDisabled = false,
        MinTimeBetweenOccurrences = 360,
    },

    ALIEN_HUNT = {
        Type = "ALIEN_HUNT",
        Title = "Hive Blood-Scent Frenzy",
        Description = "Aliens have caught player pheromones and are aggressively swarming outward.",
        DurationSeconds = 120,
        LightingPreset = {
            Brightness = 0.4,
            FogEnd = 90,
            AmbientColor = { R = 45, G = 15, B = 15 },
            EmergencyLightsRed = true,
        },
        AudioTrack = "rbxassetid://audio_alien_hunt_alarm",
        AlienSpawnRateMultiplier = 2.5,
        AlienSpeedMultiplier = 1.25,
        SafeZoneDisabled = false,
        MinTimeBetweenOccurrences = 480,
    },

    LOCKDOWN = {
        Type = "LOCKDOWN",
        Title = "Sector Security Containment",
        Description = "Automated blast doors seal connecting sectors. Secondary vents open.",
        DurationSeconds = 80,
        LightingPreset = {
            Brightness = 0.3,
            FogEnd = 100,
            AmbientColor = { R = 60, G = 40, B = 10 },
            EmergencyLightsRed = false,
        },
        AudioTrack = "rbxassetid://audio_lockdown_klaxon",
        AlienSpawnRateMultiplier = 1.4,
        AlienSpeedMultiplier = 1.0,
        SafeZoneDisabled = false,
        MinTimeBetweenOccurrences = 300,
    },

    BOSS_EVENT = {
        Type = "BOSS_EVENT",
        Title = "Hive Matriarch Emergence",
        Description = "The colossal Empress has burst into the mining complex atrium.",
        DurationSeconds = 300,
        LightingPreset = {
            Brightness = 0.25,
            FogEnd = 70,
            AmbientColor = { R = 25, G = 10, B = 35 },
            EmergencyLightsRed = true,
        },
        AudioTrack = "rbxassetid://audio_boss_matriarch_theme",
        AlienSpawnRateMultiplier = 2.0,
        AlienSpeedMultiplier = 1.2,
        SafeZoneDisabled = false,
        MinTimeBetweenOccurrences = 900,
    },

    EXTRACTION_ATTACK = {
        Type = "EXTRACTION_ATTACK",
        Title = "Evac Beacon Distress Signal",
        Description = "Extraction transport engines attracted apex predators to the landing pad.",
        DurationSeconds = 100,
        LightingPreset = {
            Brightness = 0.5,
            FogEnd = 120,
            AmbientColor = { R = 30, G = 50, B = 70 },
            EmergencyLightsRed = true,
        },
        AudioTrack = "rbxassetid://audio_extraction_countdown",
        AlienSpawnRateMultiplier = 3.0,
        AlienSpeedMultiplier = 1.3,
        SafeZoneDisabled = true,     -- Extraction pad safe zone becomes disabled during attack!
        MinTimeBetweenOccurrences = 600,
    },

    STORM = {
        Type = "STORM",
        Title = "Exo-Atmospheric Ion Tempest",
        Description = "Violent gale winds and lightning disrupt audio sensors and radar.",
        DurationSeconds = 140,
        LightingPreset = {
            Brightness = 0.3,
            FogEnd = 50,
            AmbientColor = { R = 20, G = 25, B = 40 },
            EmergencyLightsRed = false,
        },
        AudioTrack = "rbxassetid://audio_heavy_storm",
        AlienSpawnRateMultiplier = 1.3,
        AlienSpeedMultiplier = 1.0,
        SafeZoneDisabled = false,
        MinTimeBetweenOccurrences = 420,
    },

    FOG = {
        Type = "FOG",
        Title = "Spore Mists Infiltration",
        Description = "Thick fungal spores blanket corridors, muting sound and obscuring silhouettes.",
        DurationSeconds = 110,
        LightingPreset = {
            Brightness = 0.4,
            FogEnd = 30,
            AmbientColor = { R = 35, G = 45, B = 30 },
            EmergencyLightsRed = false,
        },
        AudioTrack = "rbxassetid://audio_creepy_drone",
        AlienSpawnRateMultiplier = 1.5,
        AlienSpeedMultiplier = 1.05,
        SafeZoneDisabled = false,
        MinTimeBetweenOccurrences = 360,
    },

    POWER_FAILURE = {
        Type = "POWER_FAILURE",
        Title = "Substation Breaker Cascade",
        Description = "Local sector lights cut off sequentially with loud capacitor explosions.",
        DurationSeconds = 75,
        LightingPreset = {
            Brightness = 0.1,
            FogEnd = 60,
            AmbientColor = { R = 15, G = 15, B = 20 },
            EmergencyLightsRed = false,
        },
        AudioTrack = "rbxassetid://audio_power_fail",
        AlienSpawnRateMultiplier = 1.4,
        AlienSpeedMultiplier = 1.1,
        SafeZoneDisabled = false,
        MinTimeBetweenOccurrences = 300,
    },

    EMERGENCY = {
        Type = "EMERGENCY",
        Title = "Colony Red Alert",
        Description = "General evacuation protocols activated across all public address systems.",
        DurationSeconds = 90,
        LightingPreset = {
            Brightness = 0.4,
            FogEnd = 80,
            AmbientColor = { R = 70, G = 20, B = 20 },
            EmergencyLightsRed = true,
        },
        AudioTrack = "rbxassetid://audio_siren_alarm",
        AlienSpawnRateMultiplier = 1.7,
        AlienSpeedMultiplier = 1.15,
        SafeZoneDisabled = false,
        MinTimeBetweenOccurrences = 500,
    },

    RADIO_EVENT = {
        Type = "RADIO_EVENT",
        Title = "Interference & Ghost Broadcasts",
        Description = "Distorted distress calls and cryptic static leak through team transceivers.",
        DurationSeconds = 60,
        LightingPreset = {
            Brightness = 0.6,
            FogEnd = 150,
            AmbientColor = { R = 30, G = 30, B = 35 },
            EmergencyLightsRed = false,
        },
        AudioTrack = "rbxassetid://audio_ghost_radio",
        AlienSpawnRateMultiplier = 1.1,
        AlienSpeedMultiplier = 1.0,
        SafeZoneDisabled = false,
        MinTimeBetweenOccurrences = 240,
    },
}

return table.freeze(EventsConfig)
