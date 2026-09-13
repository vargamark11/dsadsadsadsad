--!strict
--[[
    ProgressionService.luau
    Authoritative career progression, XP formulas, level unlocks, and statistical tracking.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProgressionConfig = require(ReplicatedStorage.AlienNightfall.Config.ProgressionConfig)
local ServiceManager = require(script.Parent.Parent.ServiceManager)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

local ProgressionService = {
    Name = "ProgressionService",
    LevelUp = Signal.new(),
}

function ProgressionService:OnInit()
    print("[ProgressionService] Initialized.")
end

function ProgressionService:OnStart()
    print("[ProgressionService] Started.")
end

function ProgressionService:AddXP(player: Player, xpAmount: number, source: string): boolean
    if xpAmount <= 0 then return false end
    local DataService = ServiceManager.GetService("DataService") :: any
    local profile = DataService and DataService:GetProfile(player)
    if not profile then return false end

    profile.XP += xpAmount

    -- Check level milestones
    local currentLevel = profile.Level
    local newLevel = currentLevel

    while newLevel < ProgressionConfig.MaxLevel do
        local requiredForNext = ProgressionConfig.GetXPRequired(newLevel + 1)
        if profile.XP >= requiredForNext then
            newLevel += 1
            self:AwardLevelMilestone(player, newLevel)
        else
            break
        end
    end

    if newLevel > currentLevel then
        profile.Level = newLevel
        self.LevelUp:Fire(player, newLevel)
        print(string.format("[ProgressionService] Player %s leveled up to %d!", player.Name, newLevel))
    end

    return true
end

function ProgressionService:AwardLevelMilestone(player: Player, level: number)
    local milestone = ProgressionConfig.Milestones[level]
    if not milestone then return end

    local EconomyService = ServiceManager.GetService("EconomyService") :: any
    local DataService = ServiceManager.GetService("DataService") :: any
    local profile = DataService and DataService:GetProfile(player)

    if milestone.RewardCredits and milestone.RewardCredits > 0 and EconomyService then
        EconomyService:AddCredits(player, milestone.RewardCredits, "LEVEL_REWARD_" .. tostring(level))
    end

    if milestone.RewardNanites and milestone.RewardNanites > 0 and EconomyService then
        EconomyService:AddNanites(player, milestone.RewardNanites, "LEVEL_REWARD_" .. tostring(level))
    end

    if milestone.UnlockedWeaponId and profile then
        profile.UnlockedWeapons[milestone.UnlockedWeaponId] = true
    end

    if milestone.TitleAwarded and profile then
        profile.UnlockedCosmetics[milestone.TitleAwarded] = true
    end
end

function ProgressionService:IncrementStat(player: Player, statName: string, amount: number?)
    local DataService = ServiceManager.GetService("DataService") :: any
    local profile = DataService and DataService:GetProfile(player)
    if not profile or not profile.Stats then return end

    local delta = amount or 1
    if (profile.Stats :: any)[statName] ~= nil then
        (profile.Stats :: any)[statName] += delta
    end
end

return ProgressionService
