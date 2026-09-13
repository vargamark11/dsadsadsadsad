--!strict
--[[
    init.client.luau
    Master client script entry point for ALIEN: NIGHTFALL.
    Synchronized into StarterPlayerScripts via Rojo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ControllerManager = require(script.Parent.ControllerManager)

-- Initialize client-side network binding
NetworkProtocol.Init()

-- Register All Client Controllers
local ControllersFolder = script.Parent.Controllers

local controllers = {
    require(ControllersFolder.InputController),
    require(ControllersFolder.CameraController),
    require(ControllersFolder.AudioController),
    require(ControllersFolder.PlayerController),
    require(ControllersFolder.InventoryController),
    require(ControllersFolder.InteractionController),
    require(ControllersFolder.InteractionPromptController),
    require(ControllersFolder.WeaponController),
    require(ControllersFolder.MissionController),
    require(ControllersFolder.UIController),
}

for _, controller in ipairs(controllers) do
    ControllerManager.RegisterController(controller)
end

-- Boot Client Controllers
ControllerManager.Start()
