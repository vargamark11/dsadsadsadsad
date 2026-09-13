--!strict
--[[
    init.server.luau
    Master server script entry point for ALIEN: NIGHTFALL.
    Synchronized into ServerScriptService via Rojo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.ServiceManager)

-- Initialize Network Protocol Remotes
NetworkProtocol.Init()

-- Register All Server Services
local ServicesFolder = script.Parent.Services

local serviceModules = {
    -- Infrastructure & Security
    require(ServicesFolder.LoggingService),
    require(ServicesFolder.PermissionService),
    require(ServicesFolder.AntiCheatService),
    require(ServicesFolder.DataService),

    -- Economy & Progression
    require(ServicesFolder.EconomyService),
    require(ServicesFolder.ProgressionService),
    require(ServicesFolder.InventoryService),
    require(ServicesFolder.ShopService),
    require(ServicesFolder.SeasonService),

    -- Player & Core Lifecycle
    require(ServicesFolder.CharacterService),
    require(ServicesFolder.PlayerStateManager),
    require(ServicesFolder.HealthService),
    require(ServicesFolder.StaminaService),
    require(ServicesFolder.ZoneService),
    require(ServicesFolder.PlayerService),
    require(ServicesFolder.InteractionService),
    require(ServicesFolder.TeamService),

    -- World, Weather & Events
    require(ServicesFolder.WeatherService),
    require(ServicesFolder.EventService),

    -- Missions & Extraction
    require(ServicesFolder.MissionGenerator),
    require(ServicesFolder.MissionService),
    require(ServicesFolder.ExtractionService),

    -- Combat & AI
    require(ServicesFolder.WeaponService),
    require(ServicesFolder.CombatService),
    require(ServicesFolder.AIService),
    require(ServicesFolder.AlienService),

    -- Administration & Moderation
    require(ServicesFolder.ModerationService),
    require(ServicesFolder.AdminService),
}

for _, service in ipairs(serviceModules) do
    ServiceManager.RegisterService(service)
end

-- Boot Services
ServiceManager.Start()
