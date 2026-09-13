--!strict
--[[
    EventService.luau
    Dynamic horror and colony catastrophe orchestrator in ALIEN: NIGHTFALL.
    Drives Blackouts, Alien Hunts, Lockdowns, and Boss events.
    Supports both procedural round triggers and admin panel overrides.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local EventsConfig = require(ReplicatedStorage.AlienNightfall.Config.EventsConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)
local ServiceManager = require(script.Parent.Parent.ServiceManager)

export type WorldEventType = EventsConfig.WorldEventType

local EventService = {
    Name = "EventService",
    EventStarted = Signal.new(),
    EventEnded = Signal.new(),
    _activeEvent = nil :: EventsConfig.EventConfigDef?,
    _eventEndTimestamp = 0,
    _lastEventTimes = {} :: { [WorldEventType]: number },
}

function EventService:OnInit()
    print("[EventService] Initialized.")
end

function EventService:OnStart()
    -- Event expiration check loop
    task.spawn(function()
        while true do
            task.wait(1.0)
            if self._activeEvent and os.clock() >= self._eventEndTimestamp then
                self:EndCurrentEvent()
            end
        end
    end)
    print("[EventService] Started.")
end

function EventService:TriggerEvent(eventType: WorldEventType): boolean
    local config = EventsConfig[eventType]
    if not config then return false end

    -- End any existing active event
    if self._activeEvent then
        self:EndCurrentEvent()
    end

    self._activeEvent = config
    self._eventEndTimestamp = os.clock() + config.DurationSeconds
    self._lastEventTimes[eventType] = os.clock()

    print(string.format("[EventService] EVENT ACTIVATED: %s (%s) for %ds", eventType, config.Title, config.DurationSeconds))

    -- Apply Lighting overrides
    Lighting.Brightness = config.LightingPreset.Brightness
    Lighting.FogEnd = config.LightingPreset.FogEnd
    local amb = config.LightingPreset.AmbientColor
    Lighting.Ambient = Color3.fromRGB(amb.R, amb.G, amb.B)

    -- Notify all clients for audio and HUD alarms
    NetworkProtocol.ServerFireAllClients("AdminRemotes", "AdminNotice", {
        Title = "COLONY ALERT: " .. config.Title,
        Message = config.Description,
        Duration = 6.0,
    })

    local LoggingService = ServiceManager.GetService("LoggingService") :: any
    if LoggingService then
        LoggingService:Log("SYSTEM", "WORLD_EVENT_TRIGGERED", { EventType = eventType, Duration = config.DurationSeconds })
    end

    self.EventStarted:Fire(config)
    return true
end

function EventService:EndCurrentEvent()
    if not self._activeEvent then return end
    local prev = self._activeEvent
    self._activeEvent = nil
    self._eventEndTimestamp = 0

    print(string.format("[EventService] Event concluded: %s", prev.Title))

    -- Reset to ambient weather defaults
    local WeatherService = ServiceManager.GetService("WeatherService") :: any
    if WeatherService then
        WeatherService:SetWeather(WeatherService._currentState)
    end

    self.EventEnded:Fire(prev)
end

function EventService:GetActiveEvent(): EventsConfig.EventConfigDef?
    return self._activeEvent
end

return EventService
