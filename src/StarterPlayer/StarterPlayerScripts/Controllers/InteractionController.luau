--!strict
--[[
    InteractionController.luau
    Client-side spatial proximity detection, hold-to-interact loop, and server synchronization.
    Synchronized to StarterPlayer.StarterPlayerScripts.Controllers.InteractionController via Rojo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")

local Types = require(Shared:WaitForChild("Types"))
local InteractionConfig = require(Config:WaitForChild("InteractionConfig"))
local Utilities = require(Shared:WaitForChild("Utilities"))
local NetworkRemotes = require(Shared:WaitForChild("NetworkRemotes"))

local localPlayer = Players.LocalPlayer

type TargetCandidate = {
    ObjectId: string,
    Name: string,
    Part: BasePart,
    Distance: number,
    Type: string,
    HoldDuration: number?,
    Clearance: string?,
}

local InteractionController = {
    Name = "InteractionController",
    FocusedTargetChanged = Utilities.CreateSignal(), -- (target: TargetCandidate?)
    HoldProgressChanged = Utilities.CreateSignal(),   -- (progress: number, target: TargetCandidate)
    InteractionCompleted = Utilities.CreateSignal(), -- (result: any)

    _focusedTarget = nil :: TargetCandidate?,
    _isHolding = false,
    _holdStartTime = 0,
    _holdDuration = 0,
    _holdConnection = nil :: RBXScriptConnection?,
}

function InteractionController:OnInit()
    print("[InteractionController] Initialized client interaction coordinator.")
end

function InteractionController:OnStart()
    local InputController = require(script.Parent:WaitForChild("InputController")) :: any

    InputController.InteractPressed:Connect(function()
        self:_OnInteractPressed()
    end)

    InputController.InteractReleased:Connect(function()
        self:_OnInteractReleased()
    end)

    InputController.CancelPressed:Connect(function()
        self:CancelCurrentInteraction()
    end)

    -- Sweep for nearby interactive candidates every frame
    RunService.Heartbeat:Connect(function()
        self:_SweepNearbyTargets()
    end)

    -- Listen to server feedback events
    local feedbackNotice = NetworkRemotes.GetEvent("Interaction", "FeedbackNotice")
    feedbackNotice.OnClientEvent:Connect(function(feedback: any, objectId: any, message: any)
        print(string.format("[InteractionController] Server Feedback for %s: %s (%s)", tostring(objectId), tostring(feedback), tostring(message)))
    end)
end

function InteractionController:_SweepNearbyTargets()
    local char = localPlayer.Character
    local rootPart = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    if not rootPart then
        self:_SetFocusedTarget(nil)
        return
    end

    local bestCandidate: TargetCandidate? = nil
    local bestDistance = InteractionConfig.Validation.DefaultDistance

    -- Scan workspace and World folder for interactable parts with tags or attributes
    local worldFolder = workspace:FindFirstChild("World")
    local candidates = if worldFolder then worldFolder:GetDescendants() else workspace:GetDescendants()

    for _, inst in ipairs(candidates) do
        if inst:IsA("BasePart") and inst:GetAttribute("InteractableId") ~= nil then
            local objId = tostring(inst:GetAttribute("InteractableId"))
            local dist = (rootPart.Position - inst.Position).Magnitude
            local maxDist = (inst:GetAttribute("MaxDistance") :: number?) or InteractionConfig.Validation.DefaultDistance

            if dist <= maxDist and dist < bestDistance then
                -- Check line of sight
                local hasLoS = Utilities.HasLineOfSight(
                    rootPart.Position + InteractionConfig.Validation.RaycastHeadOffset,
                    inst.Position,
                    { char, inst }
                )

                if hasLoS then
                    bestDistance = dist
                    bestCandidate = {
                        ObjectId = objId,
                        Name = tostring(inst:GetAttribute("DisplayName") or inst.Name),
                        Part = inst,
                        Distance = dist,
                        Type = tostring(inst:GetAttribute("InteractType") or "SIMPLE"),
                        HoldDuration = inst:GetAttribute("HoldDuration") :: number?,
                        Clearance = inst:GetAttribute("RequiredClearance") :: string?,
                    }
                end
            end
        end
    end

    self:_SetFocusedTarget(bestCandidate)
end

function InteractionController:_SetFocusedTarget(target: TargetCandidate?)
    if self._focusedTarget ~= target then
        if self._isHolding and (target == nil or target.ObjectId ~= self._focusedTarget.ObjectId) then
            self:CancelCurrentInteraction()
        end
        self._focusedTarget = target
        self.FocusedTargetChanged:Fire(target)
    end
end

function InteractionController:_OnInteractPressed()
    local target = self._focusedTarget
    if not target then
        return
    end

    local holdDuration = target.HoldDuration or 0
    if holdDuration > 0 then
        -- Start Hold Interaction
        self._isHolding = true
        self._holdStartTime = os.clock()
        self._holdDuration = holdDuration

        -- Notify server hold has begun
        local interactFunc = NetworkRemotes.GetFunction("Interaction", "InteractRequest")
        task.spawn(function()
            pcall(function()
                interactFunc:InvokeServer(target.ObjectId, "START_HOLD")
            end)
        end)

        -- Progress tracking loop
        if self._holdConnection then
            self._holdConnection:Disconnect()
        end
        self._holdConnection = RunService.RenderStepped:Connect(function()
            if not self._isHolding then
                return
            end
            local elapsed = os.clock() - self._holdStartTime
            local progress = math.clamp(elapsed / self._holdDuration, 0, 1)
            self.HoldProgressChanged:Fire(progress, target)

            if progress >= 1.0 then
                self:_CompleteHold(target)
            end
        end)
    else
        -- Instant interaction
        self:_ExecuteInstant(target)
    end
end

function InteractionController:_OnInteractReleased()
    if self._isHolding then
        self:CancelCurrentInteraction()
    end
end

function InteractionController:_CompleteHold(target: TargetCandidate)
    self._isHolding = false
    if self._holdConnection then
        self._holdConnection:Disconnect()
        self._holdConnection = nil
    end

    local interactFunc = NetworkRemotes.GetFunction("Interaction", "InteractRequest")
    local success, result = pcall(function()
        return interactFunc:InvokeServer(target.ObjectId, "COMPLETE_HOLD")
    end)

    if success then
        self.InteractionCompleted:Fire(result)
    end
end

function InteractionController:_ExecuteInstant(target: TargetCandidate)
    local interactFunc = NetworkRemotes.GetFunction("Interaction", "InteractRequest")
    local success, result = pcall(function()
        return interactFunc:InvokeServer(target.ObjectId, "TRIGGER")
    end)

    if success then
        self.InteractionCompleted:Fire(result)
    end
end

function InteractionController:CancelCurrentInteraction()
    if not self._isHolding then
        return
    end

    self._isHolding = false
    if self._holdConnection then
        self._holdConnection:Disconnect()
        self._holdConnection = nil
    end

    local target = self._focusedTarget
    if target then
        local cancelEvent = NetworkRemotes.GetEvent("Interaction", "CancelInteraction")
        cancelEvent:FireServer(target.ObjectId)
    end

    self.HoldProgressChanged:Fire(0, target)
end

function InteractionController:GetFocusedTarget(): TargetCandidate?
    return self._focusedTarget
end

return InteractionController
