--!strict
--[[
    NetworkRemotes.luau
    Centralized remote instance provider and initializer.
    Synchronized to ReplicatedStorage.Shared.NetworkRemotes via Rojo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NetworkRemotes = {}

local REMOTE_DEFINITIONS = {
    Player = {
        Events = { "SprintRequest", "PlayerStateSync", "DownedNotice" },
        Functions = { "ReviveInteraction" },
    },
    Interaction = {
        Events = { "CancelInteraction", "InteractionStateSync", "FeedbackNotice" },
        Functions = { "InteractRequest" },
    },
    Mission = {
        Events = { "ObjectiveUpdate", "MissionStateSync" },
        Functions = {},
    },
    Combat = {
        Events = { "FireWeapon", "ReloadRequest", "HitConfirmed" },
        Functions = {},
    },
    Inventory = {
        Events = { "ContainerSync" },
        Functions = { "PerformAction" },
    },
    Admin = {
        Events = {},
        Functions = { "ExecuteAdminCommand" },
    },
    Shop = {
        Events = {},
        Functions = { "PurchaseItem", "EquipCosmetic" },
    },
    Events = {
        Events = { "ColonyAlert", "WeatherUpdate" },
        Functions = {},
    },
}

local remotesFolder: Folder? = nil

-- Server-only initialization: instantiates category folders and remotes
function NetworkRemotes.InitServer(): Folder
    assert(RunService:IsServer(), "NetworkRemotes.InitServer can only be called from the server")

    local existing = ReplicatedStorage:FindFirstChild("Remotes")
    if existing and existing:IsA("Folder") then
        remotesFolder = existing
    else
        local folder = Instance.new("Folder")
        folder.Name = "Remotes"
        folder.Parent = ReplicatedStorage
        remotesFolder = folder
    end

    for category, defs in pairs(REMOTE_DEFINITIONS) do
        local catFolder = remotesFolder:FindFirstChild(category)
        if not catFolder then
            catFolder = Instance.new("Folder")
            catFolder.Name = category
            catFolder.Parent = remotesFolder
        end

        for _, eventName in ipairs(defs.Events) do
            if not catFolder:FindFirstChild(eventName) then
                local remote = Instance.new("RemoteEvent")
                remote.Name = eventName
                remote.Parent = catFolder
            end
        end

        for _, funcName in ipairs(defs.Functions) do
            if not catFolder:FindFirstChild(funcName) then
                local remote = Instance.new("RemoteFunction")
                remote.Name = funcName
                remote.Parent = catFolder
            end
        end
    end

    return remotesFolder :: Folder
end

-- Client and Server accessor: gets or waits for RemoteEvent
function NetworkRemotes.GetEvent(category: string, name: string): RemoteEvent
    local root = remotesFolder or ReplicatedStorage:WaitForChild("Remotes", 10)
    assert(root, "ReplicatedStorage.Remotes folder not found")
    local cat = root:WaitForChild(category, 10)
    assert(cat, string.format("Remote category %s not found", category))
    local remote = cat:WaitForChild(name, 10)
    assert(remote and remote:IsA("RemoteEvent"), string.format("RemoteEvent %s/%s not found", category, name))
    return remote :: RemoteEvent
end

-- Client and Server accessor: gets or waits for RemoteFunction
function NetworkRemotes.GetFunction(category: string, name: string): RemoteFunction
    local root = remotesFolder or ReplicatedStorage:WaitForChild("Remotes", 10)
    assert(root, "ReplicatedStorage.Remotes folder not found")
    local cat = root:WaitForChild(category, 10)
    assert(cat, string.format("Remote category %s not found", category))
    local remote = cat:WaitForChild(name, 10)
    assert(remote and remote:IsA("RemoteFunction"), string.format("RemoteFunction %s/%s not found", category, name))
    return remote :: RemoteFunction
end

return table.freeze(NetworkRemotes)
