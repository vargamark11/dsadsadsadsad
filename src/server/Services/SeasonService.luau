--!strict
--[[
    SeasonService.luau
    Authoritative season progress, tier tracking, and battle pass reward dispatching.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SeasonsConfig = require(ReplicatedStorage.AlienNightfall.Config.SeasonsConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)

local SeasonService = {
    Name = "SeasonService",
}

function SeasonService:OnInit()
    print("[SeasonService] Initialized.")
end

function SeasonService:OnStart()
    NetworkProtocol.ServerBindFunction("ShopRemotes", "ClaimSeasonTier", function(player: Player, tierNumber: number)
        return self:ClaimTier(player, tierNumber)
    end)
    print("[SeasonService] Started.")
end

function SeasonService:AddSeasonPoints(player: Player, points: number)
    local DataService = ServiceManager.GetService("DataService") :: any
    local profile = DataService and DataService:GetProfile(player)
    if not profile or points <= 0 then return end

    profile.SeasonPoints += points
    local activeSeason = SeasonsConfig.Seasons[SeasonsConfig.ActiveSeasonNumber]
    if not activeSeason then return end

    local newTier = math.clamp(math.floor(profile.SeasonPoints / activeSeason.TierStepPoints) + 1, 1, activeSeason.MaxTier)
    if newTier > profile.SeasonTier then
        profile.SeasonTier = newTier
        print(string.format("[SeasonService] Player %s advanced to Season Tier %d!", player.Name, newTier))
    end
end

function SeasonService:ClaimTier(player: Player, tierNumber: number): any
    local DataService = ServiceManager.GetService("DataService") :: any
    local EconomyService = ServiceManager.GetService("EconomyService") :: any
    local profile = DataService and DataService:GetProfile(player)

    if not profile or not EconomyService then
        return { Success = false, Error = "Profile not available" }
    end

    if tierNumber > profile.SeasonTier then
        return { Success = false, Error = "Tier not yet unlocked" }
    end

    local claimKey = "SEASON_CLAIMED_T" .. tostring(tierNumber)
    if profile.Achievements[claimKey] then
        return { Success = false, Error = "Tier reward already claimed" }
    end

    local activeSeason = SeasonsConfig.Seasons[SeasonsConfig.ActiveSeasonNumber]
    local tierDef = activeSeason and activeSeason.Tiers[tierNumber]
    if not tierDef then
        return { Success = false, Error = "Invalid tier definition" }
    end

    -- Deliver free reward
    local free = tierDef.FreeReward
    if free.Type == "CREDITS" then
        EconomyService:AddCredits(player, free.Amount, "SEASON_TIER_FREE_" .. tostring(tierNumber))
    elseif free.Type == "TITLE" then
        profile.UnlockedCosmetics[free.Id] = true
    end

    profile.Achievements[claimKey] = os.time()
    return { Success = true, Tier = tierNumber, ClaimedReward = free }
end

return SeasonService
