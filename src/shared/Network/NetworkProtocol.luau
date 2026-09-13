--!strict
--[[
    NetworkProtocol.luau
    Authoritative networking broker.
    Provides typed event dispatching, remote creation on server initialization,
    and automatic token-bucket rate limiting to eliminate remote spam exploits.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NetworkTypes = require(script.Parent.Parent.Types.NetworkTypes)
local RateLimiter = require(script.Parent.Parent.Utility.RateLimiter)
local Signal = require(script.Parent.Parent.Utility.Signal)

local IS_SERVER = RunService:IsServer()

local NetworkProtocol = {
    _remotesRoot = nil :: Folder?,
    _rateLimiter = RateLimiter.new(),
    _localSignals = {} :: { [string]: any },
}

local function getOrCreateRemotesFolder(): Folder
    local sharedRoot = ReplicatedStorage:FindFirstChild("AlienNightfall")
    if not sharedRoot then
        sharedRoot = Instance.new("Folder")
        sharedRoot.Name = "AlienNightfall"
        sharedRoot.Parent = ReplicatedStorage
    end

    local remotesFolder = sharedRoot:FindFirstChild("Remotes") :: Folder?
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = sharedRoot
    end

    return remotesFolder
end

function NetworkProtocol.Init()
    if IS_SERVER then
        local root = getOrCreateRemotesFolder()
        NetworkProtocol._remotesRoot = root

        -- Bootstrap subfolders and remotes based on NetworkTypes
        for categoryKey, folderName in pairs(NetworkTypes.Folders) do
            local subFolder = root:FindFirstChild(folderName) :: Folder?
            if not subFolder then
                subFolder = Instance.new("Folder")
                subFolder.Name = folderName
                subFolder.Parent = root
            end

            local contract = (NetworkTypes :: any)[categoryKey]
            if contract and type(contract) == "table" then
                local explicitFunctions = {
                    ReviveInteraction = true,
                    PerformAction = true,
                    PurchaseItem = true,
                    EquipCosmetic = true,
                    ClaimSeasonTier = true,
                    RequestStartMission = true,
                    ExecuteCommand = true,
                    FetchLogs = true,
                    InteractRequest = true,
                }

                for remoteKey, remoteName in pairs(contract) do
                    local isFunction = explicitFunctions[remoteName] == true

                    if isFunction then
                        if not subFolder:FindFirstChild(remoteName) then
                            local rf = Instance.new("RemoteFunction")
                            rf.Name = remoteName
                            rf.Parent = subFolder
                        end
                    else
                        if not subFolder:FindFirstChild(remoteName) then
                            local re = Instance.new("RemoteEvent")
                            re.Name = remoteName
                            re.Parent = subFolder
                        end
                    end
                end
            end
        end
    else
        -- Client: wait for remotes folder
        local sharedRoot = ReplicatedStorage:WaitForChild("AlienNightfall", 10)
        if sharedRoot then
            NetworkProtocol._remotesRoot = sharedRoot:WaitForChild("Remotes", 10) :: Folder?
        end
    end
end

-- ============================================================================
-- Server-Side API
-- ============================================================================

function NetworkProtocol.ServerFireClient(player: Player, folderName: string, remoteName: string, ...: any)
    assert(IS_SERVER, "ServerFireClient can only be called from Server")
    local folder = NetworkProtocol._remotesRoot and NetworkProtocol._remotesRoot:FindFirstChild(folderName)
    local remote = folder and folder:FindFirstChild(remoteName) :: RemoteEvent?
    if remote and remote:IsA("RemoteEvent") then
        remote:FireClient(player, ...)
    end
end

function NetworkProtocol.ServerFireAllClients(folderName: string, remoteName: string, ...: any)
    assert(IS_SERVER, "ServerFireAllClients can only be called from Server")
    local folder = NetworkProtocol._remotesRoot and NetworkProtocol._remotesRoot:FindFirstChild(folderName)
    local remote = folder and folder:FindFirstChild(remoteName) :: RemoteEvent?
    if remote and remote:IsA("RemoteEvent") then
        remote:FireAllClients(...)
    end
end

function NetworkProtocol.ServerConnectEvent(
    folderName: string,
    remoteName: string,
    callback: (player: Player, ...any) -> (),
    maxRatePerSec: number?
)
    assert(IS_SERVER, "ServerConnectEvent can only be called from Server")
    local rateLimit = maxRatePerSec or 20
    local folder = NetworkProtocol._remotesRoot and NetworkProtocol._remotesRoot:FindFirstChild(folderName)
    local remote = folder and folder:FindFirstChild(remoteName) :: RemoteEvent?
    if remote and remote:IsA("RemoteEvent") then
        return remote.OnServerEvent:Connect(function(player: Player, ...: any)
            local key = tostring(player.UserId) .. ":" .. remoteName
            if not NetworkProtocol._rateLimiter:Check(key, rateLimit, rateLimit) then
                warn(string.format("[AntiCheat/Network] Rate limit exceeded for Player %s on %s", player.Name, remoteName))
                return
            end
            callback(player, ...)
        end)
    end
    return nil
end

function NetworkProtocol.ServerBindFunction(
    folderName: string,
    remoteName: string,
    callback: (player: Player, ...any) -> any,
    maxRatePerSec: number?
)
    assert(IS_SERVER, "ServerBindFunction can only be called from Server")
    local rateLimit = maxRatePerSec or 10
    local folder = NetworkProtocol._remotesRoot and NetworkProtocol._remotesRoot:FindFirstChild(folderName)
    local rf = folder and folder:FindFirstChild(remoteName) :: RemoteFunction?
    if rf and rf:IsA("RemoteFunction") then
        rf.OnServerInvoke = function(player: Player, ...: any)
            local key = tostring(player.UserId) .. ":" .. remoteName
            if not NetworkProtocol._rateLimiter:Check(key, rateLimit, rateLimit) then
                warn(string.format("[AntiCheat/Network] Invocation rate limit exceeded for Player %s on %s", player.Name, remoteName))
                return { Success = false, Error = "Rate limit exceeded. Please wait." }
            end
            return callback(player, ...)
        end
    end
end

-- ============================================================================
-- Client-Side API
-- ============================================================================

function NetworkProtocol.ClientFireServer(folderName: string, remoteName: string, ...: any)
    assert(not IS_SERVER, "ClientFireServer can only be called from Client")
    if not NetworkProtocol._remotesRoot then return end
    local folder = NetworkProtocol._remotesRoot:FindFirstChild(folderName)
    local remote = folder and folder:FindFirstChild(remoteName) :: RemoteEvent?
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer(...)
    end
end

function NetworkProtocol.ClientInvokeServer(folderName: string, remoteName: string, ...: any): any
    assert(not IS_SERVER, "ClientInvokeServer can only be called from Client")
    if not NetworkProtocol._remotesRoot then return nil end
    local folder = NetworkProtocol._remotesRoot:FindFirstChild(folderName)
    local rf = folder and folder:FindFirstChild(remoteName) :: RemoteFunction?
    if rf and rf:IsA("RemoteFunction") then
        return rf:InvokeServer(...)
    end
    return nil
end

function NetworkProtocol.ClientConnectEvent(folderName: string, remoteName: string, callback: (...any) -> ())
    assert(not IS_SERVER, "ClientConnectEvent can only be called from Client")
    if not NetworkProtocol._remotesRoot then return nil end
    local folder = NetworkProtocol._remotesRoot:FindFirstChild(folderName)
    local remote = folder and folder:FindFirstChild(remoteName) :: RemoteEvent?
    if remote and remote:IsA("RemoteEvent") then
        return remote.OnClientEvent:Connect(callback)
    end
    return nil
end

return NetworkProtocol
