--!strict
--[[
    SeasonsConfig.luau
    Extensible multi-season battle pass and seasonal event configuration for ALIEN: NIGHTFALL.
]]

export type SeasonReward = {
    Tier: number,
    RequiredPoints: number,
    FreeReward: {
        Type: "CREDITS" | "NANITES" | "COSMETIC" | "TITLE",
        Id: string,
        Amount: number,
    },
    PremiumReward: {
        Type: "CREDITS" | "NANITES" | "COSMETIC" | "TITLE",
        Id: string,
        Amount: number,
    },
}

export type SeasonDefinition = {
    SeasonNumber: number,
    SeasonCode: string,
    Title: string,
    Theme: string,
    StartTime: number,
    EndTime: number,
    MaxTier: number,
    TierStepPoints: number,
    Tiers: { SeasonReward },
}

local function generateSeason1Tiers(): { SeasonReward }
    local tiers: { SeasonReward } = {}
    for tier = 1, 30 do
        local points = tier * 1000
        local freeType: "CREDITS" | "NANITES" | "COSMETIC" | "TITLE" = "CREDITS"
        local freeId = "ColonyCredits"
        local freeAmt = 150

        local premType: "CREDITS" | "NANITES" | "COSMETIC" | "TITLE" = "NANITES"
        local premId = "DarkNanites"
        local premAmt = 30

        if tier == 5 then
            freeType = "TITLE"
            freeId = "TITLE_SURVIVOR"
            freeAmt = 1
            premType = "COSMETIC"
            premId = "SKIN_PISTOL_CARBON"
            premAmt = 1
        elseif tier == 15 then
            premType = "COSMETIC"
            premId = "SKIN_AR_XENO_CHITIN"
            premAmt = 1
        elseif tier == 30 then
            premType = "COSMETIC"
            premId = "SUIT_NIGHTFALL_SPEC_OPS"
            premAmt = 1
        end

        table.insert(tiers, {
            Tier = tier,
            RequiredPoints = points,
            FreeReward = { Type = freeType, Id = freeId, Amount = freeAmt },
            PremiumReward = { Type = premType, Id = premId, Amount = premAmt },
        })
    end
    return tiers
end

local SeasonsConfig: {
    ActiveSeasonNumber: number,
    Seasons: { [number]: SeasonDefinition },
} = {
    ActiveSeasonNumber = 1,
    Seasons = {
        [1] = {
            SeasonNumber = 1,
            SeasonCode = "SEASON_01_OUTBREAK",
            Title = "Season 1: Colony Zero",
            Theme = "The initial containment breach and collapse of Sector 3.",
            StartTime = 1700000000,
            EndTime = 1800000000,
            MaxTier = 30,
            TierStepPoints = 1000,
            Tiers = generateSeason1Tiers(),
        },
    },
}

return table.freeze(SeasonsConfig)
