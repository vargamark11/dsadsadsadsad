--!strict
--[[
    InputController.luau
    Multi-platform input abstraction supporting PC (Mouse/Keyboard),
    Mobile (Scalable touch controls), and Console (Gamepad) for ALIEN: NIGHTFALL.
    Decouples gameplay logic from physical keycodes via query abstractions.
]]

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

export type PlatformType = "Desktop" | "Mobile" | "Console"

local InputController = {
    Name = "InputController",
    SprintToggled = Signal.new(),      -- (isSprinting: boolean)
    FireTriggered = Signal.new(),      -- (isFiring: boolean)
    ReloadTriggered = Signal.new(),    -- ()
    InteractTriggered = Signal.new(),  -- ()
    FlashlightToggled = Signal.new(),  -- ()
    InventoryToggled = Signal.new(),   -- ()
    Platform = "Desktop" :: PlatformType,
    _isSprintPressed = false,
    _isInteractPressed = false,
    _isReloadPressed = false,
    _isFiringPressed = false,
}

function InputController:OnInit()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        self.Platform = "Mobile"
    elseif (UserInputService.GamepadEnabled or GuiService:IsTenFootInterface()) and not UserInputService.KeyboardEnabled then
        self.Platform = "Console"
    else
        self.Platform = "Desktop"
    end
    print(string.format("[InputController] Initialized on platform: %s", self.Platform))
end

function InputController:OnStart()
    -- 1. Sprint Binding (Desktop: LeftShift, Console: ButtonL3, Mobile: Scalable Touch Button)
    ContextActionService:BindAction("SprintAction", function(actionName, inputState, inputObject)
        local isPressed = (inputState == Enum.UserInputState.Begin)
        self._isSprintPressed = isPressed
        self.SprintToggled:Fire(isPressed)
        return Enum.ContextActionResult.Pass
    end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

    -- Configure Mobile button styling and position dynamically
    if self.Platform == "Mobile" or UserInputService.TouchEnabled then
        ContextActionService:SetTitle("SprintAction", "SPRINT")
        local sprintButton = ContextActionService:GetButton("SprintAction")
        if sprintButton then
            sprintButton.Size = UDim2.new(0, 68, 0, 68)
            sprintButton.Position = UDim2.new(1, -160, 1, -110)
        end
    end

    -- 2. Interact Binding (Desktop: E, Console: ButtonX, Mobile: Touch Button)
    ContextActionService:BindAction("InteractAction", function(actionName, inputState, inputObject)
        local isPressed = (inputState == Enum.UserInputState.Begin)
        self._isInteractPressed = isPressed
        if isPressed then
            self.InteractTriggered:Fire()
        end
        return Enum.ContextActionResult.Pass
    end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

    if self.Platform == "Mobile" or UserInputService.TouchEnabled then
        ContextActionService:SetTitle("InteractAction", "INTERACT")
        local interactButton = ContextActionService:GetButton("InteractAction")
        if interactButton then
            interactButton.Size = UDim2.new(0, 68, 0, 68)
            interactButton.Position = UDim2.new(1, -85, 1, -185)
        end
    end

    -- 3. Reload Binding (Desktop: R, Console: ButtonY)
    ContextActionService:BindAction("ReloadAction", function(actionName, inputState, inputObject)
        local isPressed = (inputState == Enum.UserInputState.Begin)
        self._isReloadPressed = isPressed
        if isPressed then
            self.ReloadTriggered:Fire()
        end
        return Enum.ContextActionResult.Pass
    end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

    -- 4. Flashlight Binding (Desktop: F, Console: DPadUp)
    ContextActionService:BindAction("FlashlightAction", function(actionName, inputState, inputObject)
        if inputState == Enum.UserInputState.Begin then
            self.FlashlightToggled:Fire()
        end
        return Enum.ContextActionResult.Pass
    end, true, Enum.KeyCode.F, Enum.KeyCode.DPadUp)

    -- 5. Inventory Binding (Desktop: Tab, Console: ButtonSelect)
    ContextActionService:BindAction("InventoryAction", function(actionName, inputState, inputObject)
        if inputState == Enum.UserInputState.Begin then
            self.InventoryToggled:Fire()
        end
        return Enum.ContextActionResult.Pass
    end, true, Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect)

    -- 6. Primary Fire (Mouse Button 1 / Gamepad R2)
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
            self._isFiringPressed = true
            self.FireTriggered:Fire(true)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
            self._isFiringPressed = false
            self.FireTriggered:Fire(false)
        end
    end)

    print("[InputController] Input bindings configured successfully.")
end

-- Abstraction Query API (Decouples gameplay code from raw keyboard inputs)
function InputController:IsSprintPressed(): boolean
    return self._isSprintPressed
end

function InputController:IsInteractPressed(): boolean
    return self._isInteractPressed
end

function InputController:IsReloadPressed(): boolean
    return self._isReloadPressed
end

function InputController:IsFiringPressed(): boolean
    return self._isFiringPressed
end

function InputController:GetPlatform(): PlatformType
    return self.Platform
end

function InputController:RemapAction(actionName: string, ...: Enum.KeyCode)
    ContextActionService:UnbindAction(actionName)
    local keys = { ... }
    ContextActionService:BindAction(actionName, function(name, state)
        if actionName == "SprintAction" then
            local isPressed = (state == Enum.UserInputState.Begin)
            self._isSprintPressed = isPressed
            self.SprintToggled:Fire(isPressed)
        elseif actionName == "InteractAction" and state == Enum.UserInputState.Begin then
            self.InteractTriggered:Fire()
        elseif actionName == "ReloadAction" and state == Enum.UserInputState.Begin then
            self.ReloadTriggered:Fire()
        end
        return Enum.ContextActionResult.Pass
    end, true, table.unpack(keys))
end

return InputController
