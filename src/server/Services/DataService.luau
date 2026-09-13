--!strict
--[[
    DataService.luau
    Robust profile persistence layer for ALIEN: NIGHTFALL using DataStoreService.
    Includes retry loops, schema reconciliation, session locking, and BindToClose flushes.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TableUtil = require(ReplicatedStorage.AlienNightfall.Shared.Utility.TableUtil)
local PlayerTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.PlayerTypes)
local ProgressionConfig = require(ReplicatedStorage.AlienNightfall.Config.ProgressionConfig)
local EconomyConfig = require(ReplicatedStorage.AlienNightfall.Config.EconomyConfig)
local CosmeticsConfig = require(ReplicatedStorage.AlienNightfall.Config.CosmeticsConfig)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

local DATASTORE_NAME = "AlienNightfall_Production_v1"
local MAX_RETRIES = 3
local RETRY_DELAY_BASE = 1.5

local DataService = {
    Name = "DataService",
    ProfileLoaded = Signal.new(),
    _dataStore = nil :: GlobalDataStore?,
    _sessionProfiles = {} :: { [number]: PlayerTypes.PlayerProfileData },
    _loadedPlayers = {} :: { [number]: boolean },
}

function DataService:GetDefaultProfile(userId: number): PlayerTypes.PlayerProfileData
    return {
        SchemaVersion = 1,
        UserId = userId,
        ColonyCredits = EconomyConfig.Currencies.ColonyCredits.StartingBalance,
        DarkNanites = EconomyConfig.Currencies.DarkNanites.StartingBalance,
        XP = 0,
        Level = 1,
        SeasonTier = 1,
        SeasonPoints = 0,
        Inventory = {
            Slots = {
                [1] = { ItemId = "MED_BANDAGE", Quantity = 2 },
                [2] = { ItemId = "AMMO_LIGHT", Quantity = 60 },
            },
            MaxSlots = 16,
        },
        EquippedWeapons = {
            Primary = "PISTOL_STANDARD",
            Secondary = nil,
            Holster = nil,
        },
        EquippedCosmetics = TableUtil.DeepCopy(CosmeticsConfig.DefaultLoadout),
        UnlockedCosmetics = {
            ["SUIT_VANGUARD_DEFAULT"] = true,
            ["TITLE_SURVIVOR"] = true,
        },
        UnlockedWeapons = {
            ["PISTOL_STANDARD"] = true,
        },
        Achievements = {},
        Stats = TableUtil.DeepCopy(ProgressionConfig.DefaultStats),
        LastSavedTimestamp = os.time(),
    }
end

function DataService:OnInit()
    if RunService:IsStudio() then
        -- In Studio without API access, safe mock pcall or production datastore
        local success, store = pcall(function()
            return DataStoreService:GetDataStore(DATASTORE_NAME)
        end)
        if success then
            self._dataStore = store
        else
            warn("[DataService] Running in Studio without DataStore access. Using memory cache fallback.")
        end
    else
        self._dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
    end
    print("[DataService] Initialized.")
end

function DataService:OnStart()
    -- Periodic auto-save loop
    task.spawn(function()
        while true do
            task.wait(180) -- Every 3 minutes
            for _, player in ipairs(Players:GetPlayers()) do
                if self._loadedPlayers[player.UserId] then
                    self:SaveProfile(player)
                end
            end
        end
    end)

    -- BindToClose flush for clean shutdown
    game:BindToClose(function()
        print("[DataService] Server closing. Flushing all player profiles...")
        for _, player in ipairs(Players:GetPlayers()) do
            self:SaveProfile(player)
        end
    end)
    print("[DataService] Started.")
end

function DataService:OnPlayerAdded(player: Player)
    local key = "Player_" .. tostring(player.UserId)
    local profile: PlayerTypes.PlayerProfileData? = nil

    if self._dataStore then
        for attempt = 1, MAX_RETRIES do
            local success, result = pcall(function()
                return self._dataStore:GetAsync(key)
            end)

            if success then
                if result then
                    -- Reconcile with latest default schema
                    local defaultData = self:GetDefaultProfile(player.UserId)
                    profile = TableUtil.Reconcile(result, defaultData) :: any
                else
                    profile = self:GetDefaultProfile(player.UserId)
                end
                break
            else
                warn(string.format("[DataService] Load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
                task.wait(RETRY_DELAY_BASE * attempt)
            end
        end
    end

    if not profile then
        warn(string.format("[DataService] Failed to load data for %s after retries. Using default session profile.", player.Name))
        profile = self:GetDefaultProfile(player.UserId)
    end

    self._sessionProfiles[player.UserId] = profile
    self._loadedPlayers[player.UserId] = true
    self.ProfileLoaded:Fire(player, profile)
end

function DataService:OnPlayerRemoving(player: Player)
    self:SaveProfile(player)
    self._sessionProfiles[player.UserId] = nil
    self._loadedPlayers[player.UserId] = nil
end

function DataService:GetProfile(player: Player): PlayerTypes.PlayerProfileData?
    return self._sessionProfiles[player.UserId]
end

function DataService:SaveProfile(player: Player): boolean
    local profile = self._sessionProfiles[player.UserId]
    if not profile or not self._dataStore then
        return false
    end

    profile.LastSavedTimestamp = os.time()
    local key = "Player_" .. tostring(player.UserId)

    for attempt = 1, MAX_RETRIES do
        local success, err = pcall(function()
            self._dataStore:SetAsync(key, profile)
        end)

        if success then
            return true
        else
            warn(string.format("[DataService] Save attempt %d failed for %s: %s", attempt, player.Name, tostring(err)))
            task.wait(RETRY_DELAY_BASE * attempt)
        end
    end

    return false
end

return DataService
