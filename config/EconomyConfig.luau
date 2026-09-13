--!strict
--[[
    EconomyConfig.luau
    Authoritative currency and transaction configuration for ALIEN: NIGHTFALL.
    Strictly server-authoritative. Currencies:
      - ColonyCredits (Soft Currency): Earned through gameplay, survival, missions, and extractions.
      - DarkNanites (Premium Currency): Earned via Season pass, milestones, and developer products.
]]

export type CurrencyType = "ColonyCredits" | "DarkNanites"

export type TransactionCategory =
    | "MISSION_REWARD"
    | "SHOP_PURCHASE"
    | "EXTRACTION_PAYOUT"
    | "SEASON_TIER_CLAIM"
    | "ADMIN_ADJUST"
    | "REVIVE_BONUS"

export type EconomyConfigDef = {
    Currencies: {
        ColonyCredits: {
            DisplayName: string,
            Symbol: string,
            StartingBalance: number,
            MaxBalance: number,
        },
        DarkNanites: {
            DisplayName: string,
            Symbol: string,
            StartingBalance: number,
            MaxBalance: number,
        },
    },
    Rewards: {
        KillScoutXP: number,
        KillHunterXP: number,
        KillStalkerXP: number,
        KillBruteXP: number,
        KillBossXP: number,
        ExtractionCreditBonusPerTeammate: number,
        ReviveCreditBonus: number,
        FlawlessRunBonusPercent: number,
    },
    DevProductIds: { [string]: number },
}

local EconomyConfig: EconomyConfigDef = {
    Currencies = {
        ColonyCredits = {
            DisplayName = "Colony Credits",
            Symbol = "CC",
            StartingBalance = 250,
            MaxBalance = 1000000,
        },
        DarkNanites = {
            DisplayName = "Dark Nanites",
            Symbol = "DN",
            StartingBalance = 50,
            MaxBalance = 500000,
        },
    },
    Rewards = {
        KillScoutXP = 40,
        KillHunterXP = 90,
        KillStalkerXP = 150,
        KillBruteXP = 300,
        KillBossXP = 2500,
        ExtractionCreditBonusPerTeammate = 120,
        ReviveCreditBonus = 75,
        FlawlessRunBonusPercent = 0.35,
    },
    DevProductIds = {
        NANITE_POUCH_100 = 1894001,
        NANITE_CRATE_500 = 1894002,
        NANITE_VAULT_1200 = 1894003,
        BATTLE_PASS_SEASON_1 = 1894004,
    },
}

return table.freeze(EconomyConfig)
