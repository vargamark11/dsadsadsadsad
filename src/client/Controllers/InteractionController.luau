--!strict
--[[
    InteractionController.luau
    Client interaction manager for ALIEN: NIGHTFALL.
    Performs proximity detection, manages candidate interactables, handles hold input loops,
    and communicates with server InteractionService via NetworkProtocol.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ControllerManager = require(script.Parent.Parent.ControllerManager)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local InteractionTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.InteractionTypes)
local InteractionRegistry = require(ReplicatedStorage.AlienNightfall.Shared.Interaction.InteractionRegistry)
local InteractionConfig = require(ReplicatedStorage.AlienNightfall.Config.InteractionConfig)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

export type InteractionDefinition = InteractionTypes.InteractionDefinition
export type InteractResponse = InteractionTypes.InteractResponse

local localPlayer = Players.LocalPlayer

local InteractionController = {
    Name = "InteractionController",

    TargetChanged = Signal.new(),            -- (newTarget: InteractionDefinition?, distance: number?)
    HoldProgressChanged = Signal.new(),      -- (progressPercent: number, target: InteractionDefinition?)
    InteractionFeedback = Signal.new(),      -- (response: InteractResponse)

    _currentTarget = nil :: InteractionDefinition?,
    _currentDistance = 0,
    _isHolding = false,
    _holdStartTime = 0,
    _activeHoldDuration = 0,
    _lastScanTime = 0,
    _scanInterval = 0.1,                     -- 10 Hz throttled scan rate
}

function InteractionController:OnInit()
    print("[InteractionController] Initialized.")
end

function InteractionController:OnStart()
    local InputController = ControllerManager.GetController("InputController") :: any

    -- 1. Listen for network state syncs from server
    NetworkProtocol.ClientConnectEvent("InteractionRemotes", "InteractionStateSync", function(payload: any)
        if typeof(payload) == "table" and payload.ObjectId then
            local def = InteractionRegistry.Get(payload.ObjectId)
            if def and def.Attributes then
                def.Attributes.CurrentState = payload.State
            end
        end
    end)

    -- 2. Bind interaction input triggers
    if InputController then
        InputController.InteractTriggered:Connect(function()
            self:OnInteractInputBegan()
        end)
    end

    -- 3. Throttled proximity scanning and hold progress loop
    RunService.Heartbeat:Connect(function(dt: number)
        local now = os.clock()

        -- Scan proximity at 10 Hz
        if now - self._lastScanTime >= self._scanInterval then
            self._lastScanTime = now
            self:_UpdateProximityScan()
        end

        -- Update active hold progress
        if self._isHolding and self._currentTarget then
            local elapsed = now - self._holdStartTime
            local progress = math.clamp(elapsed / self._activeHoldDuration, 0, 1)
            self.HoldProgressChanged:Fire(progress, self._currentTarget)

            -- Check if hold completed
            if progress >= 1.0 then
                self:CompleteHold()
            end

            -- Cancel if player walked too far during hold
            if self._currentDistance > (self._currentTarget.CancelDistance or (self._currentTarget.Distance + 4)) then
                self:CancelHold("WalkedTooFar")
            end
        end
    end)

    print("[InteractionController] Started successfully.")
end

-- Scans registered interactables for the closest valid target
function InteractionController:_UpdateProximityScan()
    local char = localPlayer.Character
    if not char then
        self:_SetCurrentTarget(nil, 0)
        return
    end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then
        self:_SetCurrentTarget(nil, 0)
        return
    end

    local playerPos = hrp.Position
    local closestDef: InteractionDefinition? = nil
    local closestDist = math.huge

    for _, def in pairs(InteractionRegistry.GetAll()) do
        local instance = InteractionRegistry.GetInstance(def.Id)
        local targetPos = if instance then InteractionRegistry.GetWorldPosition(instance) else Vector3.zero
        if instance == nil and def.Attributes and def.Attributes.WorldPosition then
            targetPos = def.Attributes.WorldPosition
        end

        if targetPos ~= Vector3.zero or instance ~= nil then
            local dist = (playerPos - targetPos).Magnitude
            if dist <= def.Distance and dist < closestDist then
                closestDef = def
                closestDist = dist
            end
        end
    end

    self:_SetCurrentTarget(closestDef, closestDist)
end

function InteractionController:_SetCurrentTarget(newTarget: InteractionDefinition?, distance: number)
    if self._currentTarget ~= newTarget then
        -- Cancel hold if switching targets
        if self._isHolding then
            self:CancelHold("TargetLost")
        end

        self._currentTarget = newTarget
        self._currentDistance = distance
        self.TargetChanged:Fire(newTarget, distance)
    else
        self._currentDistance = distance
    end
end

-- ============================================================================
-- Input Execution
-- ============================================================================

function InteractionController:OnInteractInputBegan()
    local target = self._currentTarget
    if not target then return end

    if target.Type == "HOLD" or target.Type == "PROGRESS" or target.Type == "MULTI_PLAYER" then
        self:StartHold(target)
    else
        self:ExecuteInstantInteraction(target)
    end
end

function InteractionController:ExecuteInstantInteraction(def: InteractionDefinition)
    task.spawn(function()
        local response: InteractResponse = NetworkProtocol.ServerInvoke("InteractionRemotes", "InteractRequest", {
            ObjectId = def.Id,
            Action = "INSTANT",
            ClientTimestamp = os.clock(),
        })

        if response then
            self.InteractionFeedback:Fire(response)
            self:_PlayFeedbackAudio(response.Feedback, def)
        end
    end)
end

function InteractionController:StartHold(def: InteractionDefinition)
    if self._isHolding then return end

    self._isHolding = true
    self._holdStartTime = os.clock()
    self._activeHoldDuration = math.max(def.HoldDuration, 0.25)
    self.HoldProgressChanged:Fire(0, def)

    task.spawn(function()
        local response: InteractResponse = NetworkProtocol.ServerInvoke("InteractionRemotes", "InteractRequest", {
            ObjectId = def.Id,
            Action = "START",
            ClientTimestamp = os.clock(),
        })

        if response and not response.Success then
            self:CancelHold(response.Feedback)
            self.InteractionFeedback:Fire(response)
        end
    end)
end

function InteractionController:CompleteHold()
    local def = self._currentTarget
    if not self._isHolding or not def then return end

    self._isHolding = false
    self.HoldProgressChanged:Fire(1.0, def)

    task.spawn(function()
        local response: InteractResponse = NetworkProtocol.ServerInvoke("InteractionRemotes", "InteractRequest", {
            ObjectId = def.Id,
            Action = "COMPLETE",
            ClientTimestamp = os.clock(),
        })

        self.HoldProgressChanged:Fire(0, nil)

        if response then
            self.InteractionFeedback:Fire(response)
            self:_PlayFeedbackAudio(response.Feedback, def)
        end
    end)
end

function InteractionController:CancelHold(reason: string)
    if not self._isHolding then return end

    local def = self._currentTarget
    self._isHolding = false
    self.HoldProgressChanged:Fire(0, nil)

    if def then
        NetworkProtocol.ClientFireServer("InteractionRemotes", "CancelInteraction", {
            ObjectId = def.Id,
            Reason = reason,
        })
    end
end

function InteractionController:_PlayFeedbackAudio(code: string, def: InteractionDefinition)
    local AudioController = ControllerManager.GetController("AudioController") :: any
    if not AudioController then return end

    if code == "ACCESS_GRANTED" or code == "SUCCESS" then
        AudioController:PlaySFX(InteractionConfig.AudioHooks.KeycardAccepted or "KeycardAccepted")
    elseif code == "ACCESS_DENIED" or code == "LOCKED" then
        AudioController:PlaySFX(InteractionConfig.AudioHooks.KeycardRejected or "KeycardRejected")
    end
end

function InteractionController:GetCurrentTarget(): InteractionDefinition?
    return self._currentTarget
end

function InteractionController:IsHolding(): boolean
    return self._isHolding
end

return InteractionController
