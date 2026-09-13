--!strict
--[[
    ServiceManager.luau
    Deterministic lifecycle coordinator for all server-side services in ALIEN: NIGHTFALL.
    Enforces two-phase boot: OnInit -> OnStart, preventing circular dependency races.
]]

local Players = game:GetService("Players")

export type Service = {
    Name: string,
    OnInit: ((self: any) -> ())?,
    OnStart: ((self: any) -> ())?,
    OnPlayerAdded: ((self: any, player: Player) -> ())?,
    OnPlayerRemoving: ((self: any, player: Player) -> ())?,
    [string]: any,
}

local ServiceManager = {
    _services = {} :: { [string]: Service },
    _orderedList = {} :: { Service },
    _isStarted = false,
}

function ServiceManager.RegisterService(service: Service)
    assert(not ServiceManager._isStarted, "Cannot register services after ServiceManager has started.")
    assert(service.Name, "Service must have a unique Name field.")
    assert(ServiceManager._services[service.Name] == nil, "Service already registered: " .. service.Name)

    ServiceManager._services[service.Name] = service
    table.insert(ServiceManager._orderedList, service)
end

function ServiceManager.GetService<T>(serviceName: string): T
    local service = ServiceManager._services[serviceName]
    assert(service ~= nil, string.format("Service '%s' requested but not registered.", serviceName))
    return (service :: any) :: T
end

function ServiceManager.Start()
    if ServiceManager._isStarted then return end
    ServiceManager._isStarted = true

    print("==================================================")
    print("ALIEN: NIGHTFALL — BOOTING SERVER SERVICE MANAGER")
    print("==================================================")

    -- Phase 1: OnInit (Module initialization, data schemas, remote bindings)
    for _, service in ipairs(ServiceManager._orderedList) do
        if service.OnInit then
            local success, err = pcall(function()
                service:OnInit()
            end)
            if not success then
                error(string.format("[ServiceManager] Fatal error in %s:OnInit() -> %s", service.Name, tostring(err)))
            else
                print(string.format("  [INIT] %s ready", service.Name))
            end
        end
    end

    -- Phase 2: OnStart (Inter-service links, runtime loops, external listeners)
    for _, service in ipairs(ServiceManager._orderedList) do
        if service.OnStart then
            task.spawn(function()
                local success, err = pcall(function()
                    service:OnStart()
                end)
                if not success then
                    warn(string.format("[ServiceManager] Error in %s:OnStart() -> %s", service.Name, tostring(err)))
                else
                    print(string.format("  [START] %s operational", service.Name))
                end
            end)
        end
    end

    -- Player lifecycle routing
    Players.PlayerAdded:Connect(function(player: Player)
        for _, service in ipairs(ServiceManager._orderedList) do
            if service.OnPlayerAdded then
                task.spawn(function()
                    local success, err = pcall(function()
                        service:OnPlayerAdded(player)
                    end)
                    if not success then
                        warn(string.format("[ServiceManager] Error in %s:OnPlayerAdded(%s) -> %s", service.Name, player.Name, tostring(err)))
                    end
                end)
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        for _, service in ipairs(ServiceManager._orderedList) do
            if service.OnPlayerRemoving then
                task.spawn(function()
                    local success, err = pcall(function()
                        service:OnPlayerRemoving(player)
                    end)
                    if not success then
                        warn(string.format("[ServiceManager] Error in %s:OnPlayerRemoving(%s) -> %s", service.Name, player.Name, tostring(err)))
                    end
                end)
            end
        end
    end)

    print("[ServiceManager] All services initialized and operational.")
end

return ServiceManager
