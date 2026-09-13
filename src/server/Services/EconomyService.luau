--!strict
--[[
    EconomyService.luau
    Authoritative transaction, balance management, and currency validation service.
    Direct client mutation of currency is strictly blocked.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage.AlienNightfall.Config.EconomyConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)

local EconomyService = {
    Name = "EconomyService",
}

function EconomyService:OnInit()
    print("[EconomyService] Initialized.")
end

function EconomyService:OnStart()
    print("[EconomyService] Started.")
end

function EconomyService:GetBalance(player: Player): (number, number)
    local DataService = ServiceManager.GetService("DataService") :: any
    local profile = DataService and DataService:GetProfile(player)
    if not profile then
        return 0, 0
    end
    return profile.ColonyCredits, profile.DarkNanites
end

function EconomyService:AddCredits(player: Player, amount: number, sourceReason: string): boolean
    if amount <= 0 then return false end
    local DataService = ServiceManager.GetService("DataService") :: any
    local LoggingService = ServiceManager.GetService("LoggingService") :: any
    local profile = DataService and DataService:GetProfile(player)
    if not profile then return false end

    local maxLimit = EconomyConfig.Currencies.ColonyCredits.MaxBalance
    profile.ColonyCredits = math.clamp(profile.ColonyCredits + amount, 0, maxLimit)
    profile.Stats.TotalCreditsEarned += amount

    if LoggingService then
        LoggingService:Log("ECONOMY", "CREDITS_ADDED", { Amount = amount, Reason = sourceReason, NewBalance = profile.ColonyCredits }, player, nil)
    end

    self:SyncToClient(player)
    return true
end

function EconomyService:RemoveCredits(player: Player, amount: number, spendReason: string): boolean
    if amount <= 0 then return false end
    local DataService = ServiceManager.GetService("DataService") :: any
    local LoggingService = ServiceManager.GetService("LoggingService") :: any
    local profile = DataService and DataService:GetProfile(player)
    if not profile or profile.ColonyCredits < amount then
        return false
    end

    profile.ColonyCredits -= amount

    if LoggingService then
        LoggingService:Log("ECONOMY", "CREDITS_SPENT", { Amount = amount, Reason = spendReason, NewBalance = profile.ColonyCredits }, player, nil)
    end

    self:SyncToClient(player)
    return true
end

function EconomyService:AddNanites(player: Player, amount: number, sourceReason: string): boolean
    if amount <= 0 then return false end
    local DataService = ServiceManager.GetService("DataService") :: any
    local LoggingService = ServiceManager.GetService("LoggingService") :: any
    local profile = DataService and DataService:GetProfile(player)
    if not profile then return false end

    local maxLimit = EconomyConfig.Currencies.DarkNanites.MaxBalance
    profile.DarkNanites = math.clamp(profile.DarkNanites + amount, 0, maxLimit)

    if LoggingService then
        LoggingService:Log("ECONOMY", "NANITES_ADDED", { Amount = amount, Reason = sourceReason, NewBalance = profile.DarkNanites }, player, nil)
    end

    self:SyncToClient(player)
    return true
end

function EconomyService:RemoveNanites(player: Player, amount: number, spendReason: string): boolean
    if amount <= 0 then return false end
    local DataService = ServiceManager.GetService("DataService") :: any
    local LoggingService = ServiceManager.GetService("LoggingService") :: any
    local profile = DataService and DataService:GetProfile(player)
    if not profile or profile.DarkNanites < amount then
        return false
    end

    profile.DarkNanites -= amount

    if LoggingService then
        LoggingService:Log("ECONOMY", "NANITES_SPENT", { Amount = amount, Reason = spendReason, NewBalance = profile.DarkNanites }, player, nil)
    end

    self:SyncToClient(player)
    return true
end

function EconomyService:SyncToClient(player: Player)
    local credits, nanites = self:GetBalance(player)
    NetworkProtocol.ServerFireClient(player, "ShopRemotes", "EconomySync", {
        ColonyCredits = credits,
        DarkNanites = nanites,
    })
end

return EconomyService
