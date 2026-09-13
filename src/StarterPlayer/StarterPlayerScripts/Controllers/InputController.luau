--!strict
--[[
    InputController.luau
    Centralized cross-platform input management (Desktop, Console, Mobile).
    Synchronized to StarterPlayer.StarterPlayerScripts.Controllers.InputController via Rojo.
]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Utilities = require(Shared:WaitForChild("Utilities"))

local ACTION_INTERACT = "AN_InteractAction"
local ACTION_CANCEL = "AN_CancelAction"
local ACTION_SPRINT = "AN_SprintAction"

local InputController = {
    Name = "InputController",
    InteractPressed = Utilities.CreateSignal(),  -- ()
    InteractReleased = Utilities.CreateSignal(), -- ()
    CancelPressed = Utilities.CreateSignal(),    -- ()
    SprintToggled = Utilities.CreateSignal(),    -- (isSprinting: boolean)

    _isSprinting = false,
    _isInteracting = false,
}

function InputController:OnInit()
    print("[InputController] Initializing cross-platform input bindings.")
end

function InputController:OnStart()
    self:_BindActions()
end

function InputController:_BindActions()
    -- Interact: E (Keyboard), ButtonX (Gamepad)
    ContextActionService:BindAction(
        ACTION_INTERACT,
        function(actionName, inputState, inputObject)
            if inputState == Enum.UserInputState.Begin then
                self._isInteracting = true
                self.InteractPressed:Fire()
            elseif inputState == Enum.UserInputState.End then
                self._isInteracting = false
                self.InteractReleased:Fire()
            end
            return Enum.ContextActionResult.Sink
        end,
        false,
        Enum.KeyCode.E,
        Enum.KeyCode.ButtonX
    )

    -- Cancel / Abort: Q (Keyboard), ButtonB (Gamepad)
    ContextActionService:BindAction(
        ACTION_CANCEL,
        function(actionName, inputState, inputObject)
            if inputState == Enum.UserInputState.Begin then
                self.CancelPressed:Fire()
            end
            return Enum.ContextActionResult.Pass
        end,
        false,
        Enum.KeyCode.Q,
        Enum.KeyCode.ButtonB
    )

    -- Sprint: LeftShift (Keyboard), ButtonL3 (Gamepad)
    ContextActionService:BindAction(
        ACTION_SPRINT,
        function(actionName, inputState, inputObject)
            if inputState == Enum.UserInputState.Begin then
                self._isSprinting = true
                self.SprintToggled:Fire(true)
            elseif inputState == Enum.UserInputState.End then
                self._isSprinting = false
                self.SprintToggled:Fire(false)
            end
            return Enum.ContextActionResult.Pass
        end,
        false,
        Enum.KeyCode.LeftShift,
        Enum.KeyCode.ButtonL3
    )
end

function InputController:IsSprinting(): boolean
    return self._isSprinting
end

function InputController:IsInteracting(): boolean
    return self._isInteracting
end

return InputController
