--!strict
--[[
    InteractionRegistry.luau
    Central registry for all interactive objects, physical instances, attribute bindings,
    and interaction definitions across server and client in ALIEN: NIGHTFALL.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local InteractionTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.InteractionTypes)
local InteractionConfig = require(ReplicatedStorage.AlienNightfall.Config.InteractionConfig)
local TableUtil = require(ReplicatedStorage.AlienNightfall.Shared.Utility.TableUtil)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

export type InteractionDefinition = InteractionTypes.InteractionDefinition
export type ObjectCategory = InteractionTypes.ObjectCategory
export type InteractionType = InteractionTypes.InteractionType

local TAG_INTERACTABLE = "AlienNightfall_Interactable"

local InteractionRegistry = {
    DefinitionRegistered = Signal.new(),    -- (def: InteractionDefinition)
    DefinitionUnregistered = Signal.new(),  -- (id: string)
    _definitions = {} :: { [string]: InteractionDefinition },
    _instances = {} :: { [string]: Instance },
    _instanceToId = {} :: { [Instance]: string },
}

-- Computes the true world pivot or CFrame position of any physical Instance
function InteractionRegistry.GetWorldPosition(instance: Instance): Vector3
    if instance:IsA("BasePart") then
        return instance.Position
    elseif instance:IsA("Model") then
        local primary = instance.PrimaryPart
        if primary then
            return primary.Position
        end
        local pivot = instance:GetPivot()
        return pivot.Position
    elseif instance:IsA("Attachment") then
        return instance.WorldPosition
    end
    return Vector3.zero
end

-- Registers a typed interaction definition
function InteractionRegistry.Register(def: InteractionDefinition)
    assert(def.Id and def.Id ~= "", "InteractionDefinition must have a valid non-empty Id")
    
    -- Normalize defaults from InteractionConfig
    local fullDef: InteractionDefinition = TableUtil.DeepCopy(def)
    if not fullDef.Distance or fullDef.Distance <= 0 then
        fullDef.Distance = InteractionConfig.Defaults.InteractionDistance
    end
    if not fullDef.Cooldown or fullDef.Cooldown < 0 then
        fullDef.Cooldown = InteractionConfig.Defaults.DefaultCooldown
    end
    if fullDef.RequiresLineOfSight == nil then
        fullDef.RequiresLineOfSight = false
    end
    if not fullDef.RequiredPlayerStates then
        fullDef.RequiredPlayerStates = { ALIVE = true, SPRINTING = true }
    end

    InteractionRegistry._definitions[fullDef.Id] = fullDef
    InteractionRegistry.DefinitionRegistered:Fire(fullDef)
    return fullDef
end

-- Unregisters a definition and removes instance bindings
function InteractionRegistry.Unregister(id: string)
    local def = InteractionRegistry._definitions[id]
    if def then
        local inst = InteractionRegistry._instances[id]
        if inst then
            InteractionRegistry._instanceToId[inst] = nil
            InteractionRegistry._instances[id] = nil
        end
        InteractionRegistry._definitions[id] = nil
        InteractionRegistry.DefinitionUnregistered:Fire(id)
    end
end

-- Retrieves a definition by its unique ID
function InteractionRegistry.Get(id: string): InteractionDefinition?
    return InteractionRegistry._definitions[id]
end

-- Returns all currently registered definitions
function InteractionRegistry.GetAll(): { [string]: InteractionDefinition }
    return InteractionRegistry._definitions
end

-- Binds a physical Roblox Instance to a definition ID
function InteractionRegistry.BindInstance(id: string, instance: Instance)
    InteractionRegistry._instances[id] = instance
    InteractionRegistry._instanceToId[instance] = id
    CollectionService:AddTag(instance, TAG_INTERACTABLE)
end

-- Unbinds an instance
function InteractionRegistry.UnbindInstance(instance: Instance)
    local id = InteractionRegistry._instanceToId[instance]
    if id then
        InteractionRegistry._instances[id] = nil
        InteractionRegistry._instanceToId[instance] = nil
        CollectionService:RemoveTag(instance, TAG_INTERACTABLE)
    end
end

-- Gets the bound Instance for a definition ID
function InteractionRegistry.GetInstance(id: string): Instance?
    return InteractionRegistry._instances[id]
end

-- Gets the definition associated with a given Instance
function InteractionRegistry.GetByInstance(instance: Instance): InteractionDefinition?
    local id = InteractionRegistry._instanceToId[instance]
    if id then
        return InteractionRegistry._definitions[id]
    end

    -- Fallback: check attribute on the instance itself
    local attrId = instance:GetAttribute("InteractionId")
    if typeof(attrId) == "string" and attrId ~= "" then
        return InteractionRegistry._definitions[attrId]
    end

    return nil
end

-- Automatically inspects a Roblox Instance's attributes to build and register a definition
function InteractionRegistry.RegisterInstance(instance: Instance, overrides: { [string]: any }?): InteractionDefinition
    local id = (overrides and overrides.Id) 
        or instance:GetAttribute("InteractionId") 
        or instance.Name

    local category: ObjectCategory = (overrides and overrides.Category) 
        or (instance:GetAttribute("Category") :: any) 
        or "GENERIC"

    local actionText = (overrides and overrides.ActionText) 
        or instance:GetAttribute("ActionText") 
        or "Interact"

    local interactionType: InteractionType = (overrides and overrides.Type) 
        or (instance:GetAttribute("InteractionType") :: any) 
        or "SIMPLE"

    local distance = (overrides and overrides.Distance) 
        or instance:GetAttribute("InteractionDistance") 
        or InteractionConfig.Defaults.InteractionDistance

    local holdDuration = (overrides and overrides.HoldDuration) 
        or instance:GetAttribute("HoldDuration") 
        or 0

    local cooldown = (overrides and overrides.Cooldown) 
        or instance:GetAttribute("Cooldown") 
        or InteractionConfig.Defaults.DefaultCooldown

    local reqKeycard = (overrides and overrides.RequiredKeycardLevel) 
        or instance:GetAttribute("RequiredKeycardLevel")

    local reqItem = (overrides and overrides.RequiredItem) 
        or instance:GetAttribute("RequiredItem")

    local consumeItem = (overrides and overrides.ConsumeItem)
        or instance:GetAttribute("ConsumeItem")

    local reqLos = (overrides and overrides.RequiresLineOfSight)
        or instance:GetAttribute("RequiresLineOfSight")
        or false

    local def: InteractionDefinition = {
        Id = id,
        Category = category,
        Name = instance.Name,
        ActionText = actionText,
        Type = interactionType,
        Distance = distance,
        HoldDuration = holdDuration,
        Cooldown = cooldown,
        RequiresLineOfSight = reqLos,
        RequiredItem = reqItem,
        ConsumeItem = consumeItem,
        RequiredKeycardLevel = reqKeycard,
        SoundHooks = InteractionConfig.AudioHooks,
        AnimationId = nil,
    }

    if overrides then
        for k, v in pairs(overrides) do
            (def :: any)[k] = v
        end
    end

    local registered = InteractionRegistry.Register(def)
    InteractionRegistry.BindInstance(id, instance)
    return registered
end

-- ============================================================================
-- Domain Object Factory Templates (Data-Driven Archetypes)
-- ============================================================================

function InteractionRegistry.CreateDoor(id: string, name: string, options: {
    Distance: number?,
    KeycardLevel: number?,
    RequiredItem: string?,
    IsLocked: boolean?,
    IsLockdown: boolean?,
    RequiresLineOfSight: boolean?,
}?): InteractionDefinition
    local opts = options or {}
    local def: InteractionDefinition = {
        Id = id,
        Category = "DOOR",
        Name = name,
        ActionText = (opts.KeycardLevel and string.format("Scan Keycard (Level %d)", opts.KeycardLevel))
            or (opts.IsLocked and "Door (Locked)")
            or "Open / Close Door",
        Type = (opts.KeycardLevel or opts.RequiredItem) and "REQUIRES_KEYCARD" or "TOGGLE",
        Distance = opts.Distance or InteractionConfig.Doors.DefaultDistance,
        HoldDuration = 0,
        Cooldown = 0.5,
        RequiresLineOfSight = if opts.RequiresLineOfSight ~= nil then opts.RequiresLineOfSight else true,
        RequiredKeycardLevel = opts.KeycardLevel :: any,
        RequiredItem = opts.RequiredItem,
        ConsumeItem = false,
        Attributes = {
            DoorState = if opts.IsLockdown then "LOCKDOWN" elseif opts.IsLocked then "LOCKED" else "CLOSED",
            AutoClose = true,
        },
    }
    return InteractionRegistry.Register(def)
end

function InteractionRegistry.CreateGenerator(id: string, name: string, options: {
    RepairDuration: number?,
    RequiredFuse: string?,
    RequiresLineOfSight: boolean?,
}?): InteractionDefinition
    local opts = options or {}
    local def: InteractionDefinition = {
        Id = id,
        Category = "GENERATOR",
        Name = name,
        ActionText = "Repair Power Grid",
        Type = "PROGRESS",
        Distance = InteractionConfig.Generators.DefaultDistance,
        HoldDuration = opts.RepairDuration or InteractionConfig.Generators.RepairDuration,
        Cooldown = 1.0,
        RequiresLineOfSight = if opts.RequiresLineOfSight ~= nil then opts.RequiresLineOfSight else true,
        RequiredItem = opts.RequiredFuse or InteractionConfig.Generators.RequiredFuseItem,
        ConsumeItem = true,
        CancelDistance = 14,
        CancelOnDamage = true,
        CancelOnDeath = true,
        Attributes = {
            GeneratorState = "DAMAGED",
            PowerOutput = 0,
        },
    }
    return InteractionRegistry.Register(def)
end

function InteractionRegistry.CreateTerminal(id: string, name: string, options: {
    HackDuration: number?,
    RequiredKeycardLevel: number?,
    RequiresLineOfSight: boolean?,
}?): InteractionDefinition
    local opts = options or {}
    local def: InteractionDefinition = {
        Id = id,
        Category = "TERMINAL",
        Name = name,
        ActionText = "Access Terminal System",
        Type = "HOLD",
        Distance = InteractionConfig.Terminals.DefaultDistance,
        HoldDuration = opts.HackDuration or InteractionConfig.Terminals.DefaultHackDuration,
        Cooldown = 0.5,
        RequiresLineOfSight = if opts.RequiresLineOfSight ~= nil then opts.RequiresLineOfSight else true,
        RequiredKeycardLevel = opts.RequiredKeycardLevel :: any,
        Attributes = {
            TerminalState = if opts.RequiredKeycardLevel then "LOCKED" else "ONLINE",
            LogsAccessed = false,
        },
    }
    return InteractionRegistry.Register(def)
end

function InteractionRegistry.CreateContainer(id: string, name: string, options: {
    LootTableId: string?,
    SearchDuration: number?,
    RequiresLineOfSight: boolean?,
}?): InteractionDefinition
    local opts = options or {}
    local def: InteractionDefinition = {
        Id = id,
        Category = "CONTAINER",
        Name = name,
        ActionText = "Search Container",
        Type = "HOLD",
        Distance = InteractionConfig.Containers.DefaultDistance,
        HoldDuration = opts.SearchDuration or InteractionConfig.Containers.DefaultSearchDuration,
        Cooldown = 0.5,
        RequiresLineOfSight = if opts.RequiresLineOfSight ~= nil then opts.RequiresLineOfSight else true,
        LootTableId = opts.LootTableId or "MedicalCrate",
        Attributes = {
            ContainerState = "CLOSED",
            HasBeenLooted = false,
        },
    }
    return InteractionRegistry.Register(def)
end

function InteractionRegistry.CreateSwitch(id: string, name: string, options: {
    ActionText: string?,
    Distance: number?,
    CallbackEvent: string?,
}?): InteractionDefinition
    local opts = options or {}
    local def: InteractionDefinition = {
        Id = id,
        Category = "SWITCH",
        Name = name,
        ActionText = opts.ActionText or "Toggle Switch",
        Type = "TOGGLE",
        Distance = opts.Distance or 8,
        HoldDuration = 0,
        Cooldown = 0.5,
        RequiresLineOfSight = true,
        Attributes = {
            SwitchState = "OFF",
            CallbackEvent = opts.CallbackEvent or "DefaultSwitchToggle",
        },
    }
    return InteractionRegistry.Register(def)
end

function InteractionRegistry.CreateElevator(id: string, name: string, options: {
    Distance: number?,
    KeycardLevel: number?,
}?): InteractionDefinition
    local opts = options or {}
    local def: InteractionDefinition = {
        Id = id,
        Category = "ELEVATOR",
        Name = name,
        ActionText = "Call Elevator",
        Type = "SIMPLE",
        Distance = opts.Distance or InteractionConfig.Elevators.DefaultDistance,
        HoldDuration = 0,
        Cooldown = 2.0,
        RequiresLineOfSight = true,
        RequiredKeycardLevel = opts.KeycardLevel :: any,
        Attributes = {
            ElevatorState = "IDLE",
            CurrentFloor = 1,
            TargetFloor = 1,
        },
    }
    return InteractionRegistry.Register(def)
end

function InteractionRegistry.CreateMultiPlayerConsole(id: string, name: string, options: {
    RequiredPlayers: number,
    HoldDuration: number?,
    ActionText: string?,
}?): InteractionDefinition
    local opts = options or {}
    local def: InteractionDefinition = {
        Id = id,
        Category = "EMERGENCY_SYSTEM",
        Name = name,
        ActionText = opts.ActionText or string.format("Synchronized Override (%d Players)", opts.RequiredPlayers),
        Type = "MULTI_PLAYER",
        Distance = 10,
        HoldDuration = opts.HoldDuration or 3.0,
        Cooldown = 1.0,
        RequiresLineOfSight = true,
        MultiPlayer = {
            RequiredPlayers = opts.RequiredPlayers,
            ActivePlayerIds = {},
            HoldDuration = opts.HoldDuration or 3.0,
        },
        Attributes = {
            OverrideTriggered = false,
        },
    }
    return InteractionRegistry.Register(def)
end

function InteractionRegistry.CreateSequencePuzzle(id: string, name: string, expectedSequence: { number }): InteractionDefinition
    local def: InteractionDefinition = {
        Id = id,
        Category = "SWITCH",
        Name = name,
        ActionText = "Input Sequence Step",
        Type = "SEQUENCE",
        Distance = 8,
        HoldDuration = 0,
        Cooldown = 0.2,
        RequiresLineOfSight = true,
        Sequence = {
            ExpectedSequence = expectedSequence,
            CurrentIndex = 1,
            ResetOnError = true,
            Completed = false,
        },
        Attributes = {
            SequenceUnlocked = false,
        },
    }
    return InteractionRegistry.Register(def)
end

function InteractionRegistry.CreateTimedConsole(id: string, name: string, timeLimit: number): InteractionDefinition
    local def: InteractionDefinition = {
        Id = id,
        Category = "EXTRACTION_CONSOLE",
        Name = name,
        ActionText = "Activate Timed Override",
        Type = "TIMED",
        Distance = 8,
        HoldDuration = 0,
        Cooldown = 0.5,
        RequiresLineOfSight = true,
        Timed = {
            TimeLimit = timeLimit,
            StartedAt = 0,
            ExpiresAt = 0,
            IsActive = false,
        },
        Attributes = {
            TimedSuccess = false,
        },
    }
    return InteractionRegistry.Register(def)
end

return InteractionRegistry
