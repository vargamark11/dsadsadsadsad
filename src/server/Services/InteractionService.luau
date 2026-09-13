--!strict
--[[
    InteractionService.luau
    Master server-authoritative service for the generic interaction framework in ALIEN: NIGHTFALL.
    Coordinates validation, state execution, item consumption, loot distribution,
    door mechanics, generators, terminals, sequence puzzles, and mission events.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InteractionTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.InteractionTypes)
local InteractionConfig = require(ReplicatedStorage.AlienNightfall.Config.InteractionConfig)
local InteractionRegistry = require(ReplicatedStorage.AlienNightfall.Shared.Interaction.InteractionRegistry)
local InteractionValidator = require(script.Parent.InteractionValidator)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

export type InteractionDefinition = InteractionTypes.InteractionDefinition
export type InteractRequest = InteractionTypes.InteractRequest
export type InteractResponse = InteractionTypes.InteractResponse
export type InteractionFeedbackCode = InteractionTypes.InteractionFeedbackCode

local InteractionService = {
    Name = "InteractionService",

    -- Generic Core Events (for future subsystems to subscribe to)
    InteractionStarted = Signal.new(),       -- (player: Player, objectId: string, def: InteractionDefinition)
    InteractionCancelled = Signal.new(),     -- (player: Player, objectId: string, reason: string)
    InteractionCompleted = Signal.new(),     -- (player: Player, objectId: string, def: InteractionDefinition, resultData: any?)
    InteractionFailed = Signal.new(),        -- (player: Player, objectId: string, feedback: InteractionFeedbackCode)
    ObjectActivated = Signal.new(),          -- (objectId: string, category: string, def: InteractionDefinition)
    ObjectDeactivated = Signal.new(),        -- (objectId: string, category: string, def: InteractionDefinition)

    -- Specific Mission & Subsystem Hooks
    DoorOpened = Signal.new(),               -- (objectId: string, player: Player)
    DoorClosed = Signal.new(),               -- (objectId: string, player: Player)
    GeneratorRepaired = Signal.new(),        -- (objectId: string, player: Player)
    TerminalActivated = Signal.new(),        -- (objectId: string, player: Player)
    ItemCollected = Signal.new(),            -- (objectId: string, player: Player, itemId: string, quantity: number)
    SwitchActivated = Signal.new(),          -- (objectId: string, player: Player, newState: string)
    ElevatorCalled = Signal.new(),           -- (objectId: string, player: Player, targetFloor: number)
    SequenceCompleted = Signal.new(),        -- (objectId: string, player: Player)
    TimedCompleted = Signal.new(),           -- (objectId: string, player: Player)

    _objectStates = {} :: { [string]: string }, -- ObjectId -> current state string
}

function InteractionService:OnInit()
    print("[InteractionService] Initializing generic interaction engine...")
end

function InteractionService:OnStart()
    -- 1. Bind network request function (Authoritative single-entry point)
    NetworkProtocol.ServerBindFunction("InteractionRemotes", "InteractRequest", function(player: Player, payload: any)
        return self:HandleInteractRequest(player, payload)
    end)

    -- 2. Bind cancel event
    NetworkProtocol.ServerConnectEvent("InteractionRemotes", "CancelInteraction", function(player: Player, payload: any)
        if typeof(payload) == "table" and payload.ObjectId then
            self:CancelPlayerInteraction(player, payload.ObjectId, "ClientRequested")
        end
    end)

    -- 3. Watch player state changes (Cancel holds on damage/downed/dead)
    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    if PlayerStateManager and PlayerStateManager.StateChanged then
        PlayerStateManager.StateChanged:Connect(function(player: Player, oldState: string, newState: string)
            if newState == "DOWNED" or newState == "DEAD" or newState == "SPECTATING" then
                self:CancelAllHoldsForPlayer(player, "StateInvalidated: " .. newState)
            end
        end)
    end

    -- 4. Watch player departure
    Players.PlayerRemoving:Connect(function(player: Player)
        self:CancelAllHoldsForPlayer(player, "PlayerLeaving")
    end)

    print("[InteractionService] Started successfully.")
end

-- ============================================================================
-- Core Server-Authoritative Request Handler
-- ============================================================================

function InteractionService:HandleInteractRequest(player: Player, req: any): InteractResponse
    if typeof(req) ~= "table" or not req.ObjectId then
        return {
            Success = false,
            Feedback = "DENIED",
            ObjectId = "",
            Message = "Invalid interaction request payload",
        }
    end

    local objectId: string = req.ObjectId
    local def = InteractionRegistry.Get(objectId)
    if not def then
        return {
            Success = false,
            Feedback = "DENIED",
            ObjectId = objectId,
            Message = "Interactable object is not registered",
        }
    end

    local action = req.Action or "INSTANT"
    local services = {
        PlayerStateManager = ServiceManager.GetService("PlayerStateManager"),
        InventoryService = ServiceManager.GetService("InventoryService"),
    }

    -- 1. Master Request Validation
    local valid, feedback, meta = InteractionValidator.ValidateRequest(player, def, action, services)
    if not valid then
        self.InteractionFailed:Fire(player, objectId, feedback)
        return {
            Success = false,
            Feedback = feedback,
            ObjectId = objectId,
            Message = "Interaction validation rejected: " .. feedback,
        }
    end

    -- 2. Dispatch Based on Interaction Type
    if def.Type == "HOLD" or def.Type == "PROGRESS" then
        return self:_HandleHoldInteraction(player, def, action, meta, services)
    elseif def.Type == "MULTI_PLAYER" then
        return self:_HandleMultiPlayerInteraction(player, def, action, services)
    elseif def.Type == "SEQUENCE" then
        return self:_HandleSequenceInteraction(player, def, req.StepValue or 0)
    elseif def.Type == "TIMED" then
        return self:_HandleTimedInteraction(player, def)
    elseif def.Type == "TOGGLE" or def.Category == "DOOR" or def.Category == "SWITCH" then
        return self:_HandleToggleInteraction(player, def, meta, services)
    elseif def.Type == "REQUIRES_KEYCARD" then
        return self:_HandleKeycardInteraction(player, def, meta, services)
    elseif def.Type == "REQUIRES_ITEM" then
        return self:_HandleItemRequiredInteraction(player, def, meta, services)
    else
        -- SIMPLE / REUSABLE / ONE_TIME
        return self:_HandleSimpleInteraction(player, def, meta, services)
    end
end

-- ============================================================================
-- Interaction Type Handlers
-- ============================================================================

function InteractionService:_HandleHoldInteraction(
    player: Player,
    def: InteractionDefinition,
    action: string,
    meta: any,
    services: any
): InteractResponse
    local PlayerStateManager = services.PlayerStateManager

    if action == "START" then
        -- Transition player into INTERACTING state
        if PlayerStateManager then
            PlayerStateManager:SetState(player, "INTERACTING")
        end

        local targetPos = meta and meta.TargetPosition or Vector3.zero
        InteractionValidator.StartHoldSession(player, def, targetPos)
        self.InteractionStarted:Fire(player, def.Id, def)

        return {
            Success = true,
            Feedback = "SUCCESS",
            ObjectId = def.Id,
            NewState = "HOLD_STARTED",
            Message = "Hold interaction initialized",
        }

    elseif action == "CANCEL" then
        self:CancelPlayerInteraction(player, def.Id, "ClientCancelled")
        return {
            Success = false,
            Feedback = "CANCELLED",
            ObjectId = def.Id,
            Message = "Interaction cancelled by player",
        }

    elseif action == "COMPLETE" then
        -- Server validates true elapsed hold duration
        local timingOk, timingFeedback = InteractionValidator.ValidateHoldCompletion(player, def)
        if not timingOk then
            if PlayerStateManager then
                PlayerStateManager:SetState(player, "ALIVE")
            end
            self.InteractionFailed:Fire(player, def.Id, timingFeedback)
            return {
                Success = false,
                Feedback = timingFeedback,
                ObjectId = def.Id,
                Message = "Hold duration verification failed: " .. timingFeedback,
            }
        end

        -- Release player state back to ALIVE
        if PlayerStateManager then
            PlayerStateManager:SetState(player, "ALIVE")
        end

        -- Handle item consumption if applicable
        if def.RequiredItem and def.ConsumeItem and meta and meta.SlotIndex then
            local InventoryService = services.InventoryService
            if InventoryService then
                InventoryService:RemoveItem(player, meta.SlotIndex, 1)
            end
        end

        -- Handle Loot Container distribution
        local rolledLoot = nil
        if def.Category == "CONTAINER" or def.LootTableId then
            rolledLoot = self:_DistributeLoot(player, def, services.InventoryService)
        end

        -- Update object state
        local newState = "COMPLETED"
        if def.Category == "GENERATOR" then
            newState = "ACTIVE"
            self:_UpdateObjectState(def.Id, "ACTIVE")
            self.GeneratorRepaired:Fire(def.Id, player)
            self.ObjectActivated:Fire(def.Id, "GENERATOR", def)
        elseif def.Category == "CONTAINER" then
            newState = "OPEN"
            self:_UpdateObjectState(def.Id, "OPEN")
        elseif def.Category == "TERMINAL" then
            newState = "ACTIVE"
            self:_UpdateObjectState(def.Id, "ACTIVE")
            self.TerminalActivated:Fire(def.Id, player)
            self.ObjectActivated:Fire(def.Id, "TERMINAL", def)
        end

        InteractionValidator.RecordCooldown(player, def)
        self.InteractionCompleted:Fire(player, def.Id, def, { Loot = rolledLoot })

        return {
            Success = true,
            Feedback = "SUCCESS",
            ObjectId = def.Id,
            NewState = newState,
            Data = rolledLoot,
        }
    end

    return {
        Success = false,
        Feedback = "DENIED",
        ObjectId = def.Id,
        Message = "Unrecognized hold action: " .. tostring(action),
    }
end

function InteractionService:_HandleToggleInteraction(
    player: Player,
    def: InteractionDefinition,
    meta: any,
    services: any
): InteractResponse
    local currentState = self:GetObjectState(def.Id, def.Attributes and def.Attributes.DoorState or "CLOSED")

    if def.Category == "DOOR" then
        if currentState == "LOCKDOWN" then
            return { Success = false, Feedback = "LOCKED", ObjectId = def.Id, Message = "Security Lockdown Active" }
        end
        if currentState == "LOCKED" and not def.RequiredKeycardLevel then
            return { Success = false, Feedback = "LOCKED", ObjectId = def.Id, Message = "Door is securely locked" }
        end

        local nextState = (currentState == "OPEN") and "CLOSED" or "OPEN"
        self:_UpdateObjectState(def.Id, nextState)

        if nextState == "OPEN" then
            self.DoorOpened:Fire(def.Id, player)
            self.ObjectActivated:Fire(def.Id, "DOOR", def)
        else
            self.DoorClosed:Fire(def.Id, player)
            self.ObjectDeactivated:Fire(def.Id, "DOOR", def)
        end

        InteractionValidator.RecordCooldown(player, def)
        self.InteractionCompleted:Fire(player, def.Id, def, { State = nextState })

        return {
            Success = true,
            Feedback = "SUCCESS",
            ObjectId = def.Id,
            NewState = nextState,
        }

    elseif def.Category == "SWITCH" then
        local nextState = (currentState == "ON") and "OFF" or "ON"
        self:_UpdateObjectState(def.Id, nextState)

        self.SwitchActivated:Fire(def.Id, player, nextState)
        if nextState == "ON" then
            self.ObjectActivated:Fire(def.Id, "SWITCH", def)
        else
            self.ObjectDeactivated:Fire(def.Id, "SWITCH", def)
        end

        InteractionValidator.RecordCooldown(player, def)
        self.InteractionCompleted:Fire(player, def.Id, def, { State = nextState })

        return {
            Success = true,
            Feedback = "SUCCESS",
            ObjectId = def.Id,
            NewState = nextState,
        }
    end

    -- Default toggle
    local nextState = (currentState == "ACTIVE") and "INACTIVE" or "ACTIVE"
    self:_UpdateObjectState(def.Id, nextState)
    InteractionValidator.RecordCooldown(player, def)
    self.InteractionCompleted:Fire(player, def.Id, def, { State = nextState })

    return {
        Success = true,
        Feedback = "SUCCESS",
        ObjectId = def.Id,
        NewState = nextState,
    }
end

function InteractionService:_HandleKeycardInteraction(
    player: Player,
    def: InteractionDefinition,
    meta: any,
    services: any
): InteractResponse
    -- Keycard clearance was already strictly checked in InteractionValidator.ValidateRequest
    local nextState = "OPEN"
    if def.Category == "DOOR" then
        self:_UpdateObjectState(def.Id, "OPEN")
        self.DoorOpened:Fire(def.Id, player)
        self.ObjectActivated:Fire(def.Id, "DOOR", def)
    elseif def.Category == "TERMINAL" then
        nextState = "ONLINE"
        self:_UpdateObjectState(def.Id, "ONLINE")
        self.TerminalActivated:Fire(def.Id, player)
        self.ObjectActivated:Fire(def.Id, "TERMINAL", def)
    end

    InteractionValidator.RecordCooldown(player, def)
    self.InteractionCompleted:Fire(player, def.Id, def, { State = nextState })

    return {
        Success = true,
        Feedback = "ACCESS_GRANTED",
        ObjectId = def.Id,
        NewState = nextState,
        Message = "Keycard clearance accepted",
    }
end

function InteractionService:_HandleItemRequiredInteraction(
    player: Player,
    def: InteractionDefinition,
    meta: any,
    services: any
): InteractResponse
    if def.ConsumeItem and meta and meta.SlotIndex then
        local InventoryService = services.InventoryService
        if InventoryService then
            InventoryService:RemoveItem(player, meta.SlotIndex, 1)
        end
    end

    local nextState = "ACTIVE"
    self:_UpdateObjectState(def.Id, nextState)
    self.ObjectActivated:Fire(def.Id, def.Category, def)

    InteractionValidator.RecordCooldown(player, def)
    self.InteractionCompleted:Fire(player, def.Id, def, { State = nextState })

    return {
        Success = true,
        Feedback = "SUCCESS",
        ObjectId = def.Id,
        NewState = nextState,
        Message = "Required item accepted",
    }
end

function InteractionService:_HandleSimpleInteraction(
    player: Player,
    def: InteractionDefinition,
    meta: any,
    services: any
): InteractResponse
    if def.Category == "ELEVATOR" then
        local currentFloor = (def.Attributes and def.Attributes.CurrentFloor) or 1
        local targetFloor = (currentFloor == 1) and 2 or 1
        if def.Attributes then
            def.Attributes.CurrentFloor = targetFloor
        end
        self.ElevatorCalled:Fire(def.Id, player, targetFloor)
        InteractionValidator.RecordCooldown(player, def)
        self.InteractionCompleted:Fire(player, def.Id, def, { Floor = targetFloor })

        return {
            Success = true,
            Feedback = "SUCCESS",
            ObjectId = def.Id,
            NewState = "MOVING",
            Data = { TargetFloor = targetFloor },
        }
    end

    InteractionValidator.RecordCooldown(player, def)
    self.InteractionCompleted:Fire(player, def.Id, def, nil)
    self.ObjectActivated:Fire(def.Id, def.Category, def)

    return {
        Success = true,
        Feedback = "SUCCESS",
        ObjectId = def.Id,
        NewState = "ACTIVATED",
    }
end

function InteractionService:_HandleMultiPlayerInteraction(
    player: Player,
    def: InteractionDefinition,
    action: string,
    services: any
): InteractResponse
    local mp = def.MultiPlayer
    if not mp then
        return { Success = false, Feedback = "DENIED", ObjectId = def.Id }
    end

    if action == "START" then
        mp.ActivePlayerIds[player.UserId] = true

        local activeCount = 0
        for _ in pairs(mp.ActivePlayerIds) do
            activeCount += 1
        end

        if activeCount >= mp.RequiredPlayers then
            -- All players simultaneously holding! Complete override
            mp.ActivePlayerIds = {}
            self:_UpdateObjectState(def.Id, "OVERRIDE_COMPLETE")
            self.ObjectActivated:Fire(def.Id, def.Category, def)
            self.InteractionCompleted:Fire(player, def.Id, def, { Players = activeCount })

            return {
                Success = true,
                Feedback = "SUCCESS",
                ObjectId = def.Id,
                NewState = "OVERRIDE_COMPLETE",
                Message = "Simultaneous multi-player override completed!",
            }
        else
            return {
                Success = true,
                Feedback = "REQUIRES_MORE_PLAYERS",
                ObjectId = def.Id,
                Message = string.format("Holding (%d/%d Players)", activeCount, mp.RequiredPlayers),
                Data = { Active = activeCount, Required = mp.RequiredPlayers },
            }
        end

    elseif action == "CANCEL" then
        mp.ActivePlayerIds[player.UserId] = nil
        return {
            Success = false,
            Feedback = "CANCELLED",
            ObjectId = def.Id,
        }
    end

    return { Success = false, Feedback = "DENIED", ObjectId = def.Id }
end

function InteractionService:_HandleSequenceInteraction(
    player: Player,
    def: InteractionDefinition,
    inputStep: number
): InteractResponse
    local seq = def.Sequence
    if not seq or seq.Completed then
        return { Success = false, Feedback = "DENIED", ObjectId = def.Id }
    end

    local expected = seq.ExpectedSequence[seq.CurrentIndex]
    if inputStep == expected then
        seq.CurrentIndex += 1
        if seq.CurrentIndex > #seq.ExpectedSequence then
            -- Sequence fully solved!
            seq.Completed = true
            self:_UpdateObjectState(def.Id, "UNLOCKED")
            self.SequenceCompleted:Fire(def.Id, player)
            self.InteractionCompleted:Fire(player, def.Id, def, { SequenceSolved = true })

            return {
                Success = true,
                Feedback = "SUCCESS",
                ObjectId = def.Id,
                NewState = "UNLOCKED",
                Message = "Sequence puzzle solved successfully!",
            }
        else
            return {
                Success = true,
                Feedback = "SEQUENCE_STEP",
                ObjectId = def.Id,
                Message = string.format("Step %d accepted", seq.CurrentIndex - 1),
                Data = { NextStep = seq.CurrentIndex },
            }
        end
    else
        -- Wrong sequence input! Reset
        if seq.ResetOnError then
            seq.CurrentIndex = 1
        end
        return {
            Success = false,
            Feedback = "SEQUENCE_ERROR",
            ObjectId = def.Id,
            Message = "Incorrect sequence input. Puzzle reset.",
        }
    end
end

function InteractionService:_HandleTimedInteraction(
    player: Player,
    def: InteractionDefinition
): InteractResponse
    local timed = def.Timed
    if not timed then
        return { Success = false, Feedback = "DENIED", ObjectId = def.Id }
    end

    local now = os.clock()

    if not timed.IsActive then
        -- First interaction starts the countdown timer
        timed.IsActive = true
        timed.StartedAt = now
        timed.ExpiresAt = now + timed.TimeLimit

        return {
            Success = true,
            Feedback = "SUCCESS",
            ObjectId = def.Id,
            NewState = "TIMER_ACTIVE",
            Message = string.format("Timed sequence initiated! Complete within %d seconds", timed.TimeLimit),
            Data = { TimeRemaining = timed.TimeLimit },
        }
    else
        -- Second interaction resolves the timer before expiration
        if now <= timed.ExpiresAt then
            timed.IsActive = false
            self:_UpdateObjectState(def.Id, "TIMED_SUCCESS")
            self.TimedCompleted:Fire(def.Id, player)
            self.InteractionCompleted:Fire(player, def.Id, def, { TimedResolved = true })

            return {
                Success = true,
                Feedback = "SUCCESS",
                ObjectId = def.Id,
                NewState = "TIMED_SUCCESS",
                Message = "Timed interaction completed in time!",
            }
        else
            -- Timer expired!
            timed.IsActive = false
            return {
                Success = false,
                Feedback = "TIMED_OUT",
                ObjectId = def.Id,
                Message = "Timed interaction expired.",
            }
        end
    end
end

-- ============================================================================
-- Loot Engine
-- ============================================================================

function InteractionService:_DistributeLoot(player: Player, def: InteractionDefinition, inventoryService: any?): { any }
    local lootTableId = def.LootTableId or "MedicalCrate"
    local tableDef = InteractionConfig.LootTables[lootTableId]
    if not tableDef then return {} end

    local awardedItems = {}
    local numRolls = math.random(tableDef.MinRolls, tableDef.MaxRolls)

    for _ = 1, numRolls do
        for _, entry in ipairs(tableDef.Items) do
            local roll = math.random()
            if roll <= entry.Chance then
                local qty = math.random(entry.MinQuantity, entry.MaxQuantity)
                if inventoryService then
                    inventoryService:AddItem(player, entry.ItemId, qty)
                end
                table.insert(awardedItems, { ItemId = entry.ItemId, Quantity = qty })
                self.ItemCollected:Fire(def.Id, player, entry.ItemId, qty)
                break -- One item per roll
            end
        end
    end

    return awardedItems
end

-- ============================================================================
-- State Updates & Replication
-- ============================================================================

function InteractionService:_UpdateObjectState(objectId: string, newState: string)
    self._objectStates[objectId] = newState

    -- Set attribute on bound instance if present
    local instance = InteractionRegistry.GetInstance(objectId)
    if instance then
        instance:SetAttribute("InteractionState", newState)
    end

    -- Broadcast state update to all connected clients
    NetworkProtocol.ServerFireAll("InteractionRemotes", "InteractionStateSync", {
        ObjectId = objectId,
        State = newState,
    })
end

function InteractionService:GetObjectState(objectId: string, fallback: string?): string
    return self._objectStates[objectId] or fallback or "READY"
end

function InteractionService:CancelPlayerInteraction(player: Player, objectId: string, reason: string)
    InteractionValidator.CancelHoldSession(player)

    local PlayerStateManager = ServiceManager.GetService("PlayerStateManager") :: any
    if PlayerStateManager and PlayerStateManager:GetState(player) == "INTERACTING" then
        PlayerStateManager:SetState(player, "ALIVE")
    end

    self.InteractionCancelled:Fire(player, objectId, reason)
end

function InteractionService:CancelAllHoldsForPlayer(player: Player, reason: string)
    local session = InteractionValidator.GetHoldSession(player)
    if session then
        self:CancelPlayerInteraction(player, session.ObjectId, reason)
    end

    -- Also remove from any multiplayer hold lists
    for _, def in pairs(InteractionRegistry.GetAll()) do
        if def.MultiPlayer and def.MultiPlayer.ActivePlayerIds[player.UserId] then
            def.MultiPlayer.ActivePlayerIds[player.UserId] = nil
        end
    end
end

return InteractionService
