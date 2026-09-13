--!strict
--[[
    NetworkTypes.luau
    Centralized contract defining all RemoteEvent and RemoteFunction identifiers,
    communication channels, and network payloads in ALIEN: NIGHTFALL.
]]

export type RemoteClassification = "EVENT" | "FUNCTION"

export type RemoteEndpointDef = {
    Name: string,
    Kind: RemoteClassification,
    RateLimitHz: number,             -- Enforced by AntiCheat / NetworkManager
    RequiresAuth: boolean,
    Description: string,
}

local NetworkTypes = {
    -- Remote Folders in ReplicatedStorage.AlienNightfall.Remotes
    Folders = {
        Player = "PlayerRemotes",
        Mission = "MissionRemotes",
        Combat = "CombatRemotes",
        Inventory = "InventoryRemotes",
        Admin = "AdminRemotes",
        Shop = "ShopRemotes",
        Interaction = "InteractionRemotes",
    },

    -- Player Network Contract
    Player = {
        SprintRequest = "SprintRequest",               -- Client -> Server (Event)
        StateSync = "PlayerStateSync",                 -- Server -> Client (Event)
        StateChanged = "StateChanged",                 -- Server -> Client (Event)
        PlayerUpdate = "PlayerUpdate",                 -- Server -> Client (Event)
        ZoneChanged = "ZoneChanged",                   -- Server -> Client (Event)
        DownedNotice = "DownedNotice",                 -- Server -> Client (Event)
        ReviveInteraction = "ReviveInteraction",       -- Client -> Server (Function: Returns Success, Message)
        RespawnRequest = "RespawnRequest",             -- Client -> Server (Event)
    },

    -- Mission Network Contract
    Mission = {
        ActiveMissionSync = "ActiveMissionSync",       -- Server -> Client (Event)
        ObjectiveProgress = "ObjectiveProgress",       -- Server -> Client (Event)
        MissionCompleted = "MissionCompleted",         -- Server -> Client (Event)
        RequestStartMission = "RequestStartMission",   -- Client -> Server (Function: Returns Success, ChainId)
    },

    -- Combat Network Contract
    Combat = {
        FireWeapon = "FireWeapon",                     -- Client -> Server (Event)
        ReloadRequest = "ReloadRequest",               -- Client -> Server (Event)
        HitConfirmed = "HitConfirmed",                 -- Server -> Client (Event)
        DamageIndicator = "DamageIndicator",           -- Server -> Client (Event)
    },

    -- Inventory Network Contract
    Inventory = {
        ContainerSync = "ContainerSync",               -- Server -> Client (Event)
        PerformAction = "PerformAction",               -- Client -> Server (Function: Returns Result)
        EquipSlot = "EquipSlot",                       -- Client -> Server (Event)
    },

    -- Admin Network Contract
    Admin = {
        ExecuteCommand = "ExecuteCommand",             -- Client -> Server (Function: Returns Success, Message)
        FetchLogs = "FetchLogs",                       -- Client -> Server (Function: Returns LogEntries)
        AdminNotice = "AdminNotice",                   -- Server -> Client (Event)
    },

    -- Shop & Economy Network Contract
    Shop = {
        PurchaseItem = "PurchaseItem",                 -- Client -> Server (Function: Returns Success, Msg)
        EquipCosmetic = "EquipCosmetic",               -- Client -> Server (Function: Returns Success, Msg)
        ClaimSeasonTier = "ClaimSeasonTier",           -- Client -> Server (Function: Returns Success, Msg)
        EconomySync = "EconomySync",                   -- Server -> Client (Event)
    },

    -- Interaction Network Contract
    Interaction = {
        InteractRequest = "InteractRequest",           -- Client -> Server (Function: Returns InteractResponse)
        CancelInteraction = "CancelInteraction",       -- Client -> Server (Event)
        StateSync = "InteractionStateSync",            -- Server -> Client (Event)
        FeedbackNotice = "FeedbackNotice",             -- Server -> Client (Event)
    },
}

return table.freeze(NetworkTypes)
