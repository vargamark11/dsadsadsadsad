--!strict
--[[
    WeatherService.luau
    Authoritative atmospheric weather manager in ALIEN: NIGHTFALL.
    Drives Lighting, Atmosphere, environmental audio, and alien detection modifiers.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local WeatherConfig = require(ReplicatedStorage.AlienNightfall.Config.WeatherConfig)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

export type WeatherState = WeatherConfig.WeatherState

local WeatherService = {
    Name = "WeatherService",
    WeatherChanged = Signal.new(),
    _currentState = "CLEAR" :: WeatherState,
}

function WeatherService:OnInit()
    print("[WeatherService] Initialized.")
end

function WeatherService:OnStart()
    self:SetWeather("CLEAR")
    print("[WeatherService] Started.")
end

function WeatherService:GetCurrentWeather(): WeatherConfig.WeatherProfile
    return WeatherConfig[self._currentState]
end

function WeatherService:GetSensoryMultipliers(): (number, number)
    local profile = WeatherConfig[self._currentState]
    if profile then
        return profile.AlienDetectionMultiplier, profile.AlienHearingMultiplier
    end
    return 1.0, 1.0
end

function WeatherService:SetWeather(state: WeatherState)
    local profile = WeatherConfig[state]
    if not profile then return end

    self._currentState = state
    print(string.format("[WeatherService] Transitioning to weather: %s (%s)", state, profile.DisplayName))

    -- Apply Lighting properties smoothly
    Lighting.Brightness = profile.Lighting.Brightness
    Lighting.ClockTime = profile.Lighting.ClockTime
    Lighting.FogStart = profile.Lighting.FogStart
    Lighting.FogEnd = profile.Lighting.FogEnd

    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphere then
        atmosphere.Density = profile.Atmosphere.Density
        atmosphere.Offset = profile.Atmosphere.Offset
        atmosphere.Haze = profile.Atmosphere.Haze
        atmosphere.Glare = profile.Atmosphere.Glare
    end

    self.WeatherChanged:Fire(state, profile)
end

return WeatherService
