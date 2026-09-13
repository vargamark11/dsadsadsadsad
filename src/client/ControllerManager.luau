--!strict
--[[
    ControllerManager.luau
    Deterministic client-side lifecycle coordinator for ALIEN: NIGHTFALL.
    Executes OnInit -> OnStart on all client controllers.
]]

export type Controller = {
    Name: string,
    OnInit: ((self: any) -> ())?,
    OnStart: ((self: any) -> ())?,
    [string]: any,
}

local ControllerManager = {
    _controllers = {} :: { [string]: Controller },
    _orderedList = {} :: { Controller },
    _isStarted = false,
}

function ControllerManager.RegisterController(controller: Controller)
    assert(not ControllerManager._isStarted, "Cannot register controllers after ControllerManager has started.")
    assert(controller.Name, "Controller must have a unique Name.")
    assert(ControllerManager._controllers[controller.Name] == nil, "Controller already registered: " .. controller.Name)

    ControllerManager._controllers[controller.Name] = controller
    table.insert(ControllerManager._orderedList, controller)
end

function ControllerManager.GetController<T>(controllerName: string): T
    local controller = ControllerManager._controllers[controllerName]
    assert(controller ~= nil, string.format("Controller '%s' requested but not registered.", controllerName))
    return (controller :: any) :: T
end

function ControllerManager.Start()
    if ControllerManager._isStarted then return end
    ControllerManager._isStarted = true

    print("[ControllerManager] Initializing client systems...")

    -- Phase 1: OnInit
    for _, controller in ipairs(ControllerManager._orderedList) do
        if controller.OnInit then
            local success, err = pcall(function()
                controller:OnInit()
            end)
            if not success then
                error(string.format("[ControllerManager] Fatal error in %s:OnInit() -> %s", controller.Name, tostring(err)))
            end
        end
    end

    -- Phase 2: OnStart
    for _, controller in ipairs(ControllerManager._orderedList) do
        if controller.OnStart then
            task.spawn(function()
                local success, err = pcall(function()
                    controller:OnStart()
                end)
                if not success then
                    warn(string.format("[ControllerManager] Error in %s:OnStart() -> %s", controller.Name, tostring(err)))
                end
            end)
        end
    end

    print("[ControllerManager] All client controllers operational.")
end

return ControllerManager
