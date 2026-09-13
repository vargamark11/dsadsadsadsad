--!strict
--[[
    InteractionValidator.luau
    Authoritative server-side validation module for ALIEN: NIGHTFALL.
    Strictly verifies distances, line-of-sight raycasts, player states, inventory items,
    keycard clearance levels, hold duration integrity, cooldowns, and sequences.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InteractionTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.InteractionTypes)
local InteractionConfig = require(ReplicatedStorage.AlienNightfall.Config.InteractionConfig)
local InteractionRegistry = require(ReplicatedStorage.AlienNightfall.Shared.Interaction.InteractionRegistry)

export type InteractionDefinition = InteractionTypes.InteractionDefinition
export type InteractionFeedbackCode = InteractionTypes.InteractionFeedbackCode
export type ActiveHoldSession = InteractionTypes.ActiveHoldSession

local InteractionValidator = {
    _playerCooldowns = {} :: { [number]: number },      -- UserId -> last interact timestamp
    _objectCooldowns = {} :: { [string]: number },      -- ObjectId -> last interact timestamp
    _activeHolds = {} :: { [number]: ActiveHoldSession }, -- UserId -> ActiveHoldSession
}

-- Computes distance between player character and target instance / world point
function InteractionValidator.GetPlayerDistance(player: Player, targetPos: Vector3): number?
    local char = player.Character
    if not char then return nil end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp and char:IsA("Model") and char.PrimaryPart then
        hrp = char.PrimaryPart
    end

    if not hrp then return nil end
    return (hrp.Position - targetPos).Magnitude
end

-- Validates that player is within interaction distance (including tolerance)
function InteractionValidator.ValidateDistance(player: Player, def: InteractionDefinition, targetPos: Vector3): (boolean, InteractionFeedbackCode)
    local distance = InteractionValidator.GetPlayerDistance(player, targetPos)
    if not distance then
        return false, "DENIED"
    end

    local allowedMax = def.Distance + 2.5 -- 2.5 studs latency buffer
    if distance > allowedMax then
        return false, "TOO_FAR"
    end

    return true, "SUCCESS"
end

-- Validates line-of-sight via Raycast
function InteractionValidator.ValidateLineOfSight(player: Player, targetPos: Vector3, targetInstance: Instance?): (boolean, InteractionFeedbackCode)
    local char = player.Character
    if not char then return false, "DENIED" end

    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp and char.PrimaryPart then
        hrp = char.PrimaryPart
    end
    if not hrp then return false, "DENIED" end

    local origin = hrp.Position + InteractionConfig.Defaults.RaycastOffset
    local targetWithOffset = targetPos + Vector3.new(0, 0.5, 0)
    local direction = targetWithOffset - origin

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude

    local ignoreList = { char }
    if targetInstance then
        table.insert(ignoreList, targetInstance)
    end
    raycastParams.FilterDescendantsInstances = ignoreList
    raycastParams.IgnoreWater = true

    local result = Workspace:Raycast(origin, direction, raycastParams)
    if result and result.Instance then
        -- An obstructing part is between the player and target
        if result.Instance.CanCollide and result.Instance.Transparency < 0.95 then
            return false, "NO_LINE_OF_SIGHT"
        end
    end

    return true, "SUCCESS"
end

-- Validates player state (e.g. not DOWNED or DEAD)
function InteractionValidator.ValidatePlayerState(player: Player, def: InteractionDefinition, playerStateManager: any?): (boolean, InteractionFeedbackCode)
    if not playerStateManager then
        return true, "SUCCESS"
    end

    local state = playerStateManager:GetState(player)

    -- Downed, dead, or spectating players cannot normally interact
    if state == "DOWNED" or state == "DEAD" or state == "SPECTATING" then
        return false, "WRONG_STATE"
    end

    if def.RequiredPlayerStates then
        if not def.RequiredPlayerStates[state] then
            return false, "WRONG_STATE"
        end
    end

    return true, "SUCCESS"
end

-- Validates keycard clearance level against player's inventory
function InteractionValidator.ValidateKeycard(player: Player, requiredLevel: number, inventoryService: any?): (boolean, InteractionFeedbackCode)
    if not inventoryService then
        -- In isolated unit tests or missing inventory, check player attributes
        local attrLevel = player:GetAttribute("KeycardLevel")
        if typeof(attrLevel) == "number" and attrLevel >= requiredLevel then
            return true, "ACCESS_GRANTED"
        end
        return false, "ACCESS_DENIED"
    end

    local inv = inventoryService:GetInventory(player)
    if not inv or not inv.Slots then
        return false, "ACCESS_DENIED"
    end

    local highestClearance = 0
    local attrLevel = player:GetAttribute("KeycardLevel")
    if typeof(attrLevel) == "number" then
        highestClearance = math.max(highestClearance, attrLevel)
    end

    for _, slot in pairs(inv.Slots) do
        if slot and slot.ItemId then
            local level = InteractionConfig.KeycardItemMap[slot.ItemId]
            if level and level > highestClearance then
                highestClearance = level
            end
        end
    end

    if highestClearance >= requiredLevel then
        return true, "ACCESS_GRANTED"
    end

    return false, "ACCESS_DENIED"
end

-- Validates item presence in player's inventory
function InteractionValidator.ValidateRequiredItem(player: Player, itemId: string, inventoryService: any?): (boolean, InteractionFeedbackCode, number?)
    if not inventoryService then
        -- In mock or attribute test mode
        if player:GetAttribute("HasItem_" .. itemId) == true then
            return true, "SUCCESS", 1
        end
        return false, "MISSING_ITEM", nil
    end

    local inv = inventoryService:GetInventory(player)
    if not inv or not inv.Slots then
        return false, "MISSING_ITEM", nil
    end

    for slotIdx, slot in pairs(inv.Slots) do
        if slot and slot.ItemId == itemId and slot.Quantity >= 1 then
            return true, "SUCCESS", slotIdx
        end
    end

    return false, "MISSING_ITEM", nil
end

-- Validates cooldowns
function InteractionValidator.ValidateCooldowns(player: Player, def: InteractionDefinition): (boolean, InteractionFeedbackCode)
    local now = os.clock()

    -- Per-player cooldown
    local lastPlayerTime = InteractionValidator._playerCooldowns[player.UserId]
    if lastPlayerTime and (now - lastPlayerTime) < InteractionConfig.Defaults.PlayerCooldown then
        return false, "COOLDOWN"
    end

    -- Per-object cooldown
    local lastObjTime = InteractionValidator._objectCooldowns[def.Id]
    if lastObjTime and (now - lastObjTime) < def.Cooldown then
        return false, "COOLDOWN"
    end

    return true, "SUCCESS"
end

function InteractionValidator.RecordCooldown(player: Player, def: InteractionDefinition)
    local now = os.clock()
    InteractionValidator._playerCooldowns[player.UserId] = now
    InteractionValidator._objectCooldowns[def.Id] = now
end

-- ============================================================================
-- Hold / Progress Anti-Exploit Timing Engine
-- ============================================================================

function InteractionValidator.StartHoldSession(player: Player, def: InteractionDefinition, targetPos: Vector3): ActiveHoldSession
    local session: ActiveHoldSession = {
        Player = player,
        UserId = player.UserId,
        ObjectId = def.Id,
        StartTime = os.clock(),
        Duration = def.HoldDuration,
        TargetWorldPosition = targetPos,
        MaxDistance = def.CancelDistance or (def.Distance + 4),
    }

    InteractionValidator._activeHolds[player.UserId] = session
    return session
end

function InteractionValidator.GetHoldSession(player: Player): ActiveHoldSession?
    return InteractionValidator._activeHolds[player.UserId]
end

function InteractionValidator.CancelHoldSession(player: Player)
    InteractionValidator._activeHolds[player.UserId] = nil
end

function InteractionValidator.ValidateHoldCompletion(player: Player, def: InteractionDefinition): (boolean, InteractionFeedbackCode)
    local session = InteractionValidator._activeHolds[player.UserId]
    if not session then
        return false, "DENIED"
    end

    if session.ObjectId ~= def.Id then
        InteractionValidator.CancelHoldSession(player)
        return false, "DENIED"
    end

    -- 1. Anti-Exploit Duration Check (Prevents instant hold exploit)
    local now = os.clock()
    local elapsed = now - session.StartTime
    local minRequired = session.Duration - InteractionConfig.Defaults.ToleranceGracePeriod

    if elapsed < minRequired then
        -- Client claimed completion before required time elapsed
        InteractionValidator.CancelHoldSession(player)
        return false, "FAILED"
    end

    -- 2. Drift Distance Check
    local currentDist = InteractionValidator.GetPlayerDistance(player, session.TargetWorldPosition)
    if currentDist and currentDist > session.MaxDistance then
        InteractionValidator.CancelHoldSession(player)
        return false, "TOO_FAR"
    end

    -- Cleanup session on valid completion
    InteractionValidator.CancelHoldSession(player)
    return true, "SUCCESS"
end

-- ============================================================================
-- Master Full Request Validation
-- ============================================================================

function InteractionValidator.ValidateRequest(
    player: Player,
    def: InteractionDefinition,
    action: string,
    services: {
        PlayerStateManager: any?,
        InventoryService: any?,
    }
): (boolean, InteractionFeedbackCode, any?)
    -- 1. Player & Object Existence
    if not player or not def then
        return false, "DENIED", nil
    end

    -- 2. Target Position Resolution
    local instance = InteractionRegistry.GetInstance(def.Id)
    local targetPos = if instance then InteractionRegistry.GetWorldPosition(instance) else Vector3.zero
    if instance == nil and def.Attributes and def.Attributes.WorldPosition then
        targetPos = def.Attributes.WorldPosition
    end

    -- 3. Distance Validation
    if targetPos ~= Vector3.zero or instance ~= nil then
        local distOk, distCode = InteractionValidator.ValidateDistance(player, def, targetPos)
        if not distOk then
            return false, distCode, nil
        end
    end

    -- 4. Line of Sight (if required)
    if def.RequiresLineOfSight and targetPos ~= Vector3.zero then
        local losOk, losCode = InteractionValidator.ValidateLineOfSight(player, targetPos, instance)
        if not losOk then
            return false, losCode, nil
        end
    end

    -- 5. Player State Validation
    local stateOk, stateCode = InteractionValidator.ValidatePlayerState(player, def, services.PlayerStateManager)
    if not stateOk then
        return false, stateCode, nil
    end

    -- 6. Cooldown Validation
    local cdOk, cdCode = InteractionValidator.ValidateCooldowns(player, def)
    if not cdOk then
        return false, cdCode, nil
    end

    -- 7. Keycard Clearance Validation
    if def.RequiredKeycardLevel then
        local keyOk, keyCode = InteractionValidator.ValidateKeycard(player, def.RequiredKeycardLevel, services.InventoryService)
        if not keyOk then
            return false, keyCode, nil
        end
    end

    -- 8. Required Item Validation
    local slotIdx: number? = nil
    if def.RequiredItem then
        local itemOk, itemCode, foundSlot = InteractionValidator.ValidateRequiredItem(player, def.RequiredItem, services.InventoryService)
        if not itemOk then
            return false, itemCode, nil
        end
        slotIdx = foundSlot
    end

    return true, "SUCCESS", { SlotIndex = slotIdx, TargetPosition = targetPos, Instance = instance }
end

return InteractionValidator
