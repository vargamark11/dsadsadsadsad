--!strict
--[[
    ServerMain.server.luau
    Master server application entry point for ALIEN: NIGHTFALL.
    Synchronized into ServerScriptService via Rojo.
    
    Responsibilities:
    - Safe one-time server boot sequence.
    - Provision server remotes in ReplicatedStorage.Remotes.
    - Initialize and start server services in deterministic order.
    - Robust error trapping per service (pcall).
    - Clear development logging.
    - Strictly delegates all gameplay logic to individual Services.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Prevent duplicate server initialization
if _G.__ALIEN_NIGHTFALL_SERVER_STARTED then
    warn("[ServerMain] Server application already running! Aborting duplicate bootstrap.")
    return
end
_G.__ALIEN_NIGHTFALL_SERVER_STARTED = true

print("==================================================")
print("  ALIEN: NIGHTFALL — SERVER BOOTSTRAP INITIATED   ")
print("==================================================")

-- 1. Initialize Replicated Remotes Hierarchy
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkRemotes = require(Shared:WaitForChild("NetworkRemotes"))
local remotesFolder = NetworkRemotes.InitServer()
print(string.format("[ServerMain] Network remotes initialized in %s.", remotesFolder:GetFullName()))

-- 2. Service Registry & Ordered Boot Pipeline
local ServicesFolder = script.Parent:WaitForChild("Services")

export type ServiceModule = {
    Name: string,
    OnInit: ((self: any) -> ())?,
    OnStart: ((self: any) -> ())?,
    [string]: any,
}

local serviceRegistry: { [string]: ServiceModule } = {}
local serviceExecutionOrder: { ServiceModule } = {}

-- Deterministic Ordered Service List
local SERVICE_BOOT_SEQUENCE = {
    -- Core Infrastructure & World
    "ZoneService",
    "CharacterService",
    
    -- Player & State Systems
    "PlayerService",
    
    -- Interaction & Environment Systems
    "InteractionService",
}

-- Load and register services
local function LoadService(serviceName: string): ServiceModule?
    local moduleScript = ServicesFolder:FindFirstChild(serviceName)
    if not moduleScript or not moduleScript:IsA("ModuleScript") then
        warn(string.format("[ServerMain] Service module '%s' not found in Services folder.", serviceName))
        return nil
    end

    local success, result = pcall(function()
        return require(moduleScript) :: ServiceModule
    end)

    if not success or typeof(result) ~= "table" then
        warn(string.format("[ServerMain] Failed to require service '%s': %s", serviceName, tostring(result)))
        return nil
    end

    local service = result :: ServiceModule
    local name = service.Name or serviceName
    serviceRegistry[name] = service
    table.insert(serviceExecutionOrder, service)
    print(string.format("[ServerMain] Registered service: %s", name))
    return service
end

-- Load designated boot sequence
for _, serviceName in ipairs(SERVICE_BOOT_SEQUENCE) do
    LoadService(serviceName)
end

-- Discover and load any remaining service modules in the folder
for _, child in ipairs(ServicesFolder:GetChildren()) do
    if child:IsA("ModuleScript") and not serviceRegistry[child.Name] then
        LoadService(child.Name)
    end
end

-- Phase 1: OnInit (Synchronous setup, state initialization, dependency wire-up)
print("[ServerMain] Executing OnInit phase for registered services...")
for _, service in ipairs(serviceExecutionOrder) do
    if typeof(service.OnInit) == "function" then
        local success, err = pcall(function()
            service:OnInit()
        end)
        if success then
            print(string.format("  ✓ [%s:OnInit] Completed successfully.", service.Name))
        else
            warn(string.format("  ✕ [%s:OnInit] Error during initialization: %s", service.Name, tostring(err)))
        end
    end
end

-- Phase 2: OnStart (Asynchronous tasks, event connections, loop starts)
print("[ServerMain] Executing OnStart phase for registered services...")
for _, service in ipairs(serviceExecutionOrder) do
    if typeof(service.OnStart) == "function" then
        task.spawn(function()
            local success, err = pcall(function()
                service:OnStart()
            end)
            if success then
                print(string.format("  ✓ [%s:OnStart] Service started successfully.", service.Name))
            else
                warn(string.format("  ✕ [%s:OnStart] Error starting service: %s", service.Name, tostring(err)))
            end
        end)
    end
end

print("==================================================")
print("  ALIEN: NIGHTFALL — SERVER RUNNING SUCCESSFULLY  ")
print("==================================================")
