--!strict
--[[
    InteractionService.luau
    Master server-authoritative interaction engine for ALIEN: NIGHTFALL.
    Synchronized to ServerScriptService.Services.InteractionService via Rojo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")

local Types = require(Shared:WaitForChild("Types"))
local InteractionConfig = require(Config:WaitForChild("InteractionConfig"))
local Constants = require(Shared:WaitForChild("Constants"))
local Utilities = require(Shared:WaitForChild("Utilities"))
local NetworkRemotes = require(Shared:WaitForChild("NetworkRemotes"))

type InteractionType = Types.InteractionType
type InteractionState = Types.InteractionState
type InteractionFeedback = Types.InteractionFeedback
type InteractionDefinition = Types.InteractionDefinition
type InteractionResult = Types.InteractionResult

type ActiveHold = {
    Player: Player,
    ObjectId: string,
    StartTime: number,
    TargetDuration: number,
    InitialPosition: Vector3,
}

local InteractionService = {
    Name = "InteractionService",
    ObjectInteracted = Utilities.CreateSignal(), -- (player: Player, objectId: string, action: string, result: InteractionResult)
    StateChanged = Utilities.CreateSignal(),     -- (objectId: string, newState: InteractionState)

    _registry = {} :: { [string]: InteractionDefinition },
    _activeHolds = {} :: { [Player]: ActiveHold },
    _playerCooldowns = {} :: { [Player]: number },
    _objectCooldowns = {} :: { [string]: number },
    _rateLimiter = Utilities.CreateRateLimiter(10, 15),
}

function InteractionService:OnInit()
    print("[InteractionService] Initializing authoritative Interaction Engine.")
    self:_RegisterDefaultInteractions()
end

function InteractionService:OnStart()
    local interactFunc = NetworkRemotes.GetFunction("Interaction", "InteractRequest")
    local cancelEvent = NetworkRemotes.GetEvent("Interaction", "CancelInteraction")

    interactFunc.OnServerInvoke = function(player: Player, objectId: any, action: any, payload: any)
        return self:_HandleInteractRequest(player, tostring(objectId), tostring(action), payload)
    end

    cancelEvent.OnServerEvent:Connect(function(player: Player, objectId: any)
        self:CancelHold(player, "CLIENT_CANCEL")
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self._activeHolds[player] = nil
        self._playerCooldowns[player] = nil
        self._rateLimiter:Reset(tostring(player.UserId))
    end)
end

function InteractionService:_RegisterDefaultInteractions()
    -- Sample base interactions for airlock, medical cabinet, security terminal, generator
    self:RegisterInteraction({
        Id = "Aegis_MainAirlock",
        Name = "Main Perimeter Airlock",
        Type = "TOGGLE",
        Distance = 12.0,
        HoldDuration = nil,
        State = "CLOSED",
        RequiresLineOfSight = true,
    })

    self:RegisterInteraction({
        Id = "Lab_Alpha_Terminal",
        Name = "Containment Terminal Alpha",
        Type = "REQUIRES_KEYCARD",
        Distance = 8.0,
        HoldDuration = 3.0,
        RequiredClearance = "KEYCARD_LEVEL_2",
        State = "LOCKED",
        RequiresLineOfSight = true,
    })

    self:RegisterInteraction({
        Id = "Med_Supply_Cabinet_01",
        Name = "Medical Supply Locker",
        Type = "HOLD",
        Distance = 8.0,
        HoldDuration = 2.5,
        State = "AVAILABLE",
        LootTableId = "MedicalCabinet",
        RequiresLineOfSight = true,
    })

    self:RegisterInteraction({
        Id = "Backup_Power_Generator",
        Name = "Geothermal Backup Generator",
        Type = "PROGRESS",
        Distance = 10.0,
        HoldDuration = 5.0,
        State = "AVAILABLE",
        RequiresLineOfSight = true,
    })
end

function InteractionService:RegisterInteraction(def: InteractionDefinition)
    self._registry[def.Id] = def
    print(string.format("[InteractionService] Registered interaction object '%s' (%s).", def.Id, def.Type))
end

function InteractionService:GetInteraction(objectId: string): InteractionDefinition?
    return self._registry[objectId]
end

function InteractionService:_HandleInteractRequest(player: Player, objectId: string, action: string, payload: any?): InteractionResult
    if not self._rateLimiter:Check(tostring(player.UserId)) then
        return self:_CreateResult(false, "COOLDOWN", objectId, nil, "Rate limit exceeded.")
    end

    local now = os.clock()
    local playerCooldown = self._playerCooldowns[player] or 0
    if now < playerCooldown then
        return self:_CreateResult(false, "COOLDOWN", objectId, nil, "Please wait before interacting again.")
    end

    local def = self._registry[objectId]
    if not def then
        return self:_CreateResult(false, "FAILED", objectId, nil, "Interactive object does not exist.")
    end

    -- Spatial Distance & LOS validation
    local isValidDistance, feedback = self:_ValidateSpatial(player, def)
    if not isValidDistance then
        return self:_CreateResult(false, feedback, objectId, def.State, "Too far or obstructed.")
    end

    -- State & Clearance Validation
    if def.State == "LOCKED" or def.State == "DISABLED" or def.State == "LOCKDOWN" then
        if def.Type == "REQUIRES_KEYCARD" then
            local hasKeycard = self:_ValidateKeycard(player, def.RequiredClearance or "NONE")
            if not hasKeycard then
                return self:_CreateResult(false, "ACCESS_DENIED", objectId, def.State, "Security Clearance Insufficient.")
            end
        else
            return self:_CreateResult(false, "LOCKED", objectId, def.State, "Object is currently locked.")
        end
    end

    -- Process based on interaction action (BEGIN, COMPLETE, TRIGGER)
    if action == "START_HOLD" and (def.Type == "HOLD" or def.Type == "PROGRESS" or def.Type == "REQUIRES_KEYCARD") then
        return self:_StartHold(player, def)
    elseif action == "COMPLETE_HOLD" then
        return self:_CompleteHold(player, def)
    else
        -- Instant or Toggle
        return self:_ExecuteInstant(player, def)
    end
end

function InteractionService:_ValidateSpatial(player: Player, def: InteractionDefinition): (boolean, InteractionFeedback)
    local char = player.Character
    local rootPart = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    if not rootPart then
        return false, "FAILED"
    end

    -- Locate interactive part in workspace or world
    local targetPart: BasePart? = nil
    local worldFolder = workspace:FindFirstChild("World")
    if worldFolder then
        targetPart = worldFolder:FindFirstChild(def.Id, true) :: BasePart?
    end
    if not targetPart then
        targetPart = workspace:FindFirstChild(def.Id, true) :: BasePart?
    end

    -- If target part physically exists, enforce distance
    if targetPart then
        local dist = Utilities.Distance(rootPart, targetPart)
        local allowedMax = def.Distance + InteractionConfig.Validation.LatencyToleranceBuffer
        if dist > allowedMax then
            return false, "TOO_FAR"
        end

        if def.RequiresLineOfSight then
            local origin = rootPart.Position + InteractionConfig.Validation.RaycastHeadOffset
            local target = targetPart.Position
            local hasLoS = Utilities.HasLineOfSight(origin, target, { char, targetPart })
            if not hasLoS then
                return false, "NO_LINE_OF_SIGHT"
            end
        end
    end

    return true, "SUCCESS"
end

function InteractionService:_ValidateKeycard(player: Player, requiredClearance: string): boolean
    -- Check player inventory / attributes for clearance
    local clearanceValue = InteractionConfig.ClearanceHierarchy[requiredClearance :: any] or 0
    local playerClearance = player:GetAttribute("KeycardClearance")
    local playerVal = if typeof(playerClearance) == "string"
        then (InteractionConfig.ClearanceHierarchy[playerClearance :: any] or 0)
        else 0
    return playerVal >= clearanceValue
end

function InteractionService:_StartHold(player: Player, def: InteractionDefinition): InteractionResult
    local char = player.Character
    local rootPart = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    local pos = if rootPart then rootPart.Position else Vector3.zero

    self._activeHolds[player] = {
        Player = player,
        ObjectId = def.Id,
        StartTime = os.clock(),
        TargetDuration = def.HoldDuration or 2.0,
        InitialPosition = pos,
    }

    return self:_CreateResult(true, "SUCCESS", def.Id, def.State, "Hold initiated.")
end

function InteractionService:_CompleteHold(player: Player, def: InteractionDefinition): InteractionResult
    local hold = self._activeHolds[player]
    if not hold or hold.ObjectId ~= def.Id then
        return self:_CreateResult(false, "FAILED", def.Id, def.State, "No active hold recorded.")
    end

    local elapsed = os.clock() - hold.StartTime
    local minDuration = hold.TargetDuration * 0.90 -- 10% latency leeway
    if elapsed < minDuration then
        self._activeHolds[player] = nil
        return self:_CreateResult(false, "FAILED", def.Id, def.State, "Hold completed too quickly.")
    end

    self._activeHolds[player] = nil
    return self:_ApplyInteractionOutcome(player, def)
end

function InteractionService:_ExecuteInstant(player: Player, def: InteractionDefinition): InteractionResult
    return self:_ApplyInteractionOutcome(player, def)
end

function InteractionService:_ApplyInteractionOutcome(player: Player, def: InteractionDefinition): InteractionResult
    local newState: InteractionState = def.State
    if def.Type == "TOGGLE" then
        newState = if def.State == "OPEN" then "CLOSED" else "OPEN"
    elseif def.Type == "REQUIRES_KEYCARD" then
        newState = "OPEN"
    else
        newState = "COMPLETED"
    end

    def.State = newState
    self._playerCooldowns[player] = os.clock() + InteractionConfig.Cooldowns.PlayerInteraction

    -- Replicate state sync to all clients
    local stateSyncEvent = NetworkRemotes.GetEvent("Interaction", "InteractionStateSync")
    stateSyncEvent:FireAllClients(def.Id, newState)

    local result = self:_CreateResult(true, "SUCCESS", def.Id, newState, "Interaction successful.")
    self.ObjectInteracted:Fire(player, def.Id, "INTERACT", result)
    self.StateChanged:Fire(def.Id, newState)

    return result
end

function InteractionService:CancelHold(player: Player, reason: string)
    local hold = self._activeHolds[player]
    if hold then
        self._activeHolds[player] = nil
        local feedbackNotice = NetworkRemotes.GetEvent("Interaction", "FeedbackNotice")
        feedbackNotice:FireClient(player, "FAILED", hold.ObjectId, reason)
    end
end

function InteractionService:_CreateResult(
    success: boolean,
    feedback: InteractionFeedback,
    objectId: string,
    newState: InteractionState?,
    message: string?
): InteractionResult
    return {
        Success = success,
        Feedback = feedback,
        ObjectId = objectId,
        NewState = newState,
        Message = message,
        Data = nil,
    }
end

return InteractionService
