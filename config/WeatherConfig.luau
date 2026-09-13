--!strict
--[[
    WeatherConfig.luau
    Weather definitions affecting visibility, ambient acoustics, and Alien sensory multipliers.
]]

export type WeatherState = "CLEAR" | "RAIN" | "HEAVY_RAIN" | "FOG" | "STORM"

export type WeatherProfile = {
    State: WeatherState,
    DisplayName: string,
    Atmosphere: {
        Density: number,
        Offset: number,
        Haze: number,
        Glare: number,
    },
    Lighting: {
        Brightness: number,
        ClockTime: number,
        FogStart: number,
        FogEnd: number,
    },
    AudioAmbience: string,
    RainParticleRate: number,
    AlienDetectionMultiplier: number,    -- Visibility factor (0.7 = aliens detect 30% slower/closer)
    AlienHearingMultiplier: number,      -- Audio masking factor (rain masks footsteps)
    PlayerStaminaDrainRate: number,      -- Multiplier for sprinting in heavy mud/rain
}

local WeatherConfig: { [WeatherState]: WeatherProfile } = {
    CLEAR = {
        State = "CLEAR",
        DisplayName = "Starlit Nightfall",
        Atmosphere = { Density = 0.25, Offset = 0, Haze = 0.5, Glare = 0 },
        Lighting = { Brightness = 0.8, ClockTime = 0.0, FogStart = 50, FogEnd = 500 },
        AudioAmbience = "rbxassetid://audio_ambience_wind",
        RainParticleRate = 0,
        AlienDetectionMultiplier = 1.0,
        AlienHearingMultiplier = 1.0,
        PlayerStaminaDrainRate = 1.0,
    },

    RAIN = {
        State = "RAIN",
        DisplayName = "Acid Drizzle",
        Atmosphere = { Density = 0.45, Offset = 0.1, Haze = 1.5, Glare = 0 },
        Lighting = { Brightness = 0.5, ClockTime = 0.0, FogStart = 30, FogEnd = 300 },
        AudioAmbience = "rbxassetid://audio_rain_light",
        RainParticleRate = 150,
        AlienDetectionMultiplier = 0.85,
        AlienHearingMultiplier = 0.75,     -- Rain sound dampens player footstep noise
        PlayerStaminaDrainRate = 1.1,
    },

    HEAVY_RAIN = {
        State = "HEAVY_RAIN",
        DisplayName = "Colony Deluge",
        Atmosphere = { Density = 0.65, Offset = 0.2, Haze = 3.0, Glare = 0 },
        Lighting = { Brightness = 0.3, ClockTime = 0.0, FogStart = 20, FogEnd = 160 },
        AudioAmbience = "rbxassetid://audio_rain_heavy",
        RainParticleRate = 400,
        AlienDetectionMultiplier = 0.7,
        AlienHearingMultiplier = 0.5,      -- Significant noise masking
        PlayerStaminaDrainRate = 1.25,
    },

    FOG = {
        State = "FOG",
        DisplayName = "Thick Spore Mist",
        Atmosphere = { Density = 0.85, Offset = 0.4, Haze = 5.0, Glare = 0 },
        Lighting = { Brightness = 0.25, ClockTime = 0.0, FogStart = 5, FogEnd = 70 },
        AudioAmbience = "rbxassetid://audio_fog_drone",
        RainParticleRate = 0,
        AlienDetectionMultiplier = 0.5,     -- Line of sight severely degraded
        AlienHearingMultiplier = 1.1,      -- Sound travels well through still fog
        PlayerStaminaDrainRate = 1.0,
    },

    STORM = {
        State = "STORM",
        DisplayName = "Electromagnetic Tempest",
        Atmosphere = { Density = 0.75, Offset = 0.3, Haze = 4.0, Glare = 0.5 },
        Lighting = { Brightness = 0.2, ClockTime = 0.0, FogStart = 15, FogEnd = 120 },
        AudioAmbience = "rbxassetid://audio_storm_thunder",
        RainParticleRate = 500,
        AlienDetectionMultiplier = 0.65,
        AlienHearingMultiplier = 0.4,
        PlayerStaminaDrainRate = 1.35,
    },
}

return table.freeze(WeatherConfig)
