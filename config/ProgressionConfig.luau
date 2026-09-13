--!strict
--[[
    ProgressionConfig.luau
    Authoritative level formula, stat tracking requirements, and career milestone unlocks.
]]

export type LevelMilestone = {
    Level: number,
    RewardCredits: number,
    RewardNanites: number?,
    UnlockedWeaponId: string?,
    UnlockedCosmeticId: string?,
    TitleAwarded: string?,
}

local function calculateXPForLevel(level: number): number
    -- Smooth exponential curve: Base 1000 with 1.15 compounding factor
    if level <= 1 then
        return 0
    end
    return math.floor(1000 * ((level - 1) ^ 1.45))
end

local PrecomputedLevelThresholds: { [number]: number } = {}
for lvl = 1, 100 do
    PrecomputedLevelThresholds[lvl] = calculateXPForLevel(lvl)
end

local Milestones: { [number]: LevelMilestone } = {
    [2] = { Level = 2, RewardCredits = 250, UnlockedWeaponId = "SMG_RAPID" },
    [3] = { Level = 3, RewardCredits = 350, UnlockedWeaponId = "SHOTGUN_BREACH" },
    [4] = { Level = 4, RewardCredits = 500, UnlockedWeaponId = "RIFLE_ASSAULT" },
    [5] = { Level = 5, RewardCredits = 750, TitleAwarded = "Field Recon" },
    [6] = { Level = 6, RewardCredits = 1000, UnlockedWeaponId = "SNIPER_RAIL" },
    [10] = { Level = 10, RewardCredits = 2500, RewardNanites = 100, UnlockedWeaponId = "WEAPON_EXPERIMENTAL", TitleAwarded = "Veteran Operator" },
    [25] = { Level = 25, RewardCredits = 5000, RewardNanites = 250, TitleAwarded = "Colony Legend" },
    [50] = { Level = 50, RewardCredits = 15000, RewardNanites = 500, TitleAwarded = "Nightfall Apex" },
}

local ProgressionConfig = {
    MaxLevel = 100,
    GetXPRequired = calculateXPForLevel,
    LevelThresholds = PrecomputedLevelThresholds,
    Milestones = Milestones,
    DefaultStats = {
        TotalKills = 0,
        ScoutKills = 0,
        HunterKills = 0,
        StalkerKills = 0,
        BruteKills = 0,
        BossKills = 0,
        TotalDeaths = 0,
        TimesDowned = 0,
        TeammatesRevived = 0,
        MissionsCompleted = 0,
        MissionsFailed = 0,
        ExtractionsSuccessful = 0,
        TotalDamageDealt = 0,
        TotalCreditsEarned = 0,
        TotalSecondsSurvived = 0,
    },
}

return table.freeze(ProgressionConfig)
