--!strict
--[[
    ClientMain.client.luau
    Master client application entry point for ALIEN: NIGHTFALL.
    Synchronized into StarterPlayer.StarterPlayerScripts via Rojo.

    Responsibilities:
    - Safe one-time client boot sequence.
    - Wait for network remotes readiness.
    - Deterministic initialization of client controllers.
    - Safe error-trapping per controller (pcall).
    - Clear development logging.
    - Not contain gameplay logic itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Prevent duplicate client initialization
if _G.__ALIEN_NIGHTFALL_CLIENT_STARTED then
    warn("[ClientMain] Client application already running! Aborting duplicate bootstrap.")
    return
end
_G.__ALIEN_NIGHTFALL_CLIENT_STARTED = true

print("==================================================")
print("  ALIEN: NIGHTFALL — CLIENT BOOTSTRAP INITIATED   ")
print("==================================================")

local localPlayer = Players.LocalPlayer
assert(localPlayer, "[ClientMain] LocalPlayer must be defined in ClientMain.")

-- Ensure Remotes folder is ready
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 15)
if not remotesFolder then
    warn("[ClientMain] Timed out waiting for ReplicatedStorage.Remotes. Continuing with fallback...")
end

-- Controller Registry & Ordered Boot Pipeline
local ControllersFolder = script.Parent:WaitForChild("Controllers")

export type ControllerModule = {
    Name: string,
    OnInit: ((self: any) -> ())?,
    OnStart: ((self: any) -> ())?,
    [string]: any,
}

local controllerRegistry: { [string]: ControllerModule } = {}
local controllerExecutionOrder: { ControllerModule } = {}

-- Deterministic Ordered Controller List
local CONTROLLER_BOOT_SEQUENCE = {
    "InputController",
    "PlayerController",
    "InteractionController",
    "UIController",
}

local function LoadController(controllerName: string): ControllerModule?
    local moduleScript = ControllersFolder:FindFirstChild(controllerName)
    if not moduleScript or not moduleScript:IsA("ModuleScript") then
        warn(string.format("[ClientMain] Controller module '%s' not found.", controllerName))
        return nil
    end

    local success, result = pcall(function()
        return require(moduleScript) :: ControllerModule
    end)

    if not success or typeof(result) ~= "table" then
        warn(string.format("[ClientMain] Failed to require controller '%s': %s", controllerName, tostring(result)))
        return nil
    end

    local controller = result :: ControllerModule
    local name = controller.Name or controllerName
    controllerRegistry[name] = controller
    table.insert(controllerExecutionOrder, controller)
    print(string.format("[ClientMain] Registered controller: %s", name))
    return controller
end

-- Load designated boot sequence
for _, controllerName in ipairs(CONTROLLER_BOOT_SEQUENCE) do
    LoadController(controllerName)
end

-- Discover and load any remaining controllers
for _, child in ipairs(ControllersFolder:GetChildren()) do
    if child:IsA("ModuleScript") and not controllerRegistry[child.Name] then
        LoadController(child.Name)
    end
end

-- Phase 1: OnInit (Synchronous setup, input binds, signals)
print("[ClientMain] Executing OnInit phase for controllers...")
for _, controller in ipairs(controllerExecutionOrder) do
    if typeof(controller.OnInit) == "function" then
        local success, err = pcall(function()
            controller:OnInit()
        end)
        if success then
            print(string.format("  ✓ [%s:OnInit] Completed successfully.", controller.Name))
        else
            warn(string.format("  ✕ [%s:OnInit] Error during initialization: %s", controller.Name, tostring(err)))
        end
    end
end

-- Phase 2: OnStart (Event listeners, render step loops)
print("[ClientMain] Executing OnStart phase for controllers...")
for _, controller in ipairs(controllerExecutionOrder) do
    if typeof(controller.OnStart) == "function" then
        task.spawn(function()
            local success, err = pcall(function()
                controller:OnStart()
            end)
            if success then
                print(string.format("  ✓ [%s:OnStart] Controller started successfully.", controller.Name))
            else
                warn(string.format("  ✕ [%s:OnStart] Error starting controller: %s", controller.Name, tostring(err)))
            end
        end)
    end
end

print("==================================================")
print("  ALIEN: NIGHTFALL — CLIENT RUNNING SUCCESSFULLY  ")
print("==================================================")
