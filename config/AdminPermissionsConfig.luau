--!strict
--[[
    AdminPermissionsConfig.luau
    Authoritative permission hierarchy, authorized UserIds, and command access levels.
    Evaluated strictly server-side by PermissionService and AdminService.
    Never trusted from client input.
]]

export type AdminRank = "NONE" | "MODERATOR" | "ADMIN" | "HEAD_ADMIN" | "OWNER"

export type AdminCommandDef = {
    CommandId: string,
    MinimumRank: AdminRank,
    RequiresTarget: boolean,
    RateLimitSeconds: number,
    AuditLogCategory: string,
    Description: string,
}

local RankValues: { [AdminRank]: number } = {
    NONE = 0,
    MODERATOR = 1,
    ADMIN = 2,
    HEAD_ADMIN = 3,
    OWNER = 4,
}

local AdminPermissionsConfig: {
    RankValues: { [AdminRank]: number },
    AuthorizedUserIds: { [number]: AdminRank },
    GroupRankMapping: {
        GroupId: number,
        Ranks: { [number]: AdminRank },
    }?,
    Commands: { [string]: AdminCommandDef },
} = {
    RankValues = RankValues,

    -- Authorized Developer / Admin UserIds
    AuthorizedUserIds = {
        [1] = "OWNER",          -- Placeholder / Test Owner
        [2] = "HEAD_ADMIN",
    },

    Commands = {
        SPECTATE = {
            CommandId = "SPECTATE",
            MinimumRank = "MODERATOR",
            RequiresTarget = true,
            RateLimitSeconds = 1.0,
            AuditLogCategory = "MODERATION",
            Description = "View camera perspective of target player.",
        },
        TELEPORT = {
            CommandId = "TELEPORT",
            MinimumRank = "ADMIN",
            RequiresTarget = true,
            RateLimitSeconds = 2.0,
            AuditLogCategory = "GAMEPLAY",
            Description = "Teleport admin to target player or coordinates.",
        },
        BRING = {
            CommandId = "BRING",
            MinimumRank = "ADMIN",
            RequiresTarget = true,
            RateLimitSeconds = 2.0,
            AuditLogCategory = "GAMEPLAY",
            Description = "Teleport target player to admin location.",
        },
        HEAL = {
            CommandId = "HEAL",
            MinimumRank = "ADMIN",
            RequiresTarget = true,
            RateLimitSeconds = 1.0,
            AuditLogCategory = "GAMEPLAY",
            Description = "Restore target player health and stamina to 100%.",
        },
        RESPAWN = {
            CommandId = "RESPAWN",
            MinimumRank = "ADMIN",
            RequiresTarget = true,
            RateLimitSeconds = 2.0,
            AuditLogCategory = "GAMEPLAY",
            Description = "Force revive or respawn target player at base.",
        },
        FREEZE = {
            CommandId = "FREEZE",
            MinimumRank = "MODERATOR",
            RequiresTarget = true,
            RateLimitSeconds = 1.0,
            AuditLogCategory = "MODERATION",
            Description = "Anchor player humanoid root part.",
        },
        KICK = {
            CommandId = "KICK",
            MinimumRank = "MODERATOR",
            RequiresTarget = true,
            RateLimitSeconds = 3.0,
            AuditLogCategory = "DISCIPLINE",
            Description = "Disconnect player from server with custom reason.",
        },
        BAN = {
            CommandId = "BAN",
            MinimumRank = "HEAD_ADMIN",
            RequiresTarget = true,
            RateLimitSeconds = 5.0,
            AuditLogCategory = "DISCIPLINE",
            Description = "Store permanent or timed ban entry in DataStore.",
        },
        GIVE_ITEM = {
            CommandId = "GIVE_ITEM",
            MinimumRank = "ADMIN",
            RequiresTarget = true,
            RateLimitSeconds = 2.0,
            AuditLogCategory = "ECONOMY",
            Description = "Grant specified item and quantity to target inventory.",
        },
        GIVE_CURRENCY = {
            CommandId = "GIVE_CURRENCY",
            MinimumRank = "OWNER",
            RequiresTarget = true,
            RateLimitSeconds = 5.0,
            AuditLogCategory = "ECONOMY",
            Description = "Credit player balance with ColonyCredits or DarkNanites.",
        },
        START_MISSION = {
            CommandId = "START_MISSION",
            MinimumRank = "ADMIN",
            RequiresTarget = false,
            RateLimitSeconds = 5.0,
            AuditLogCategory = "MISSION",
            Description = "Force start a specific mission template chain.",
        },
        SPAWN_ALIEN = {
            CommandId = "SPAWN_ALIEN",
            MinimumRank = "ADMIN",
            RequiresTarget = false,
            RateLimitSeconds = 3.0,
            AuditLogCategory = "AI_SPAWN",
            Description = "Spawn alien archetype at specified location or near player.",
        },
        TRIGGER_EVENT = {
            CommandId = "TRIGGER_EVENT",
            MinimumRank = "ADMIN",
            RequiresTarget = false,
            RateLimitSeconds = 10.0,
            AuditLogCategory = "WORLD_EVENT",
            Description = "Initiate world event: BLACKOUT, ALIEN_HUNT, STORM, etc.",
        },
        SET_WEATHER = {
            CommandId = "SET_WEATHER",
            MinimumRank = "MODERATOR",
            RequiresTarget = false,
            RateLimitSeconds = 3.0,
            AuditLogCategory = "ENVIRONMENT",
            Description = "Transition current atmospheric weather state.",
        },
        SERVER_ANNOUNCEMENT = {
            CommandId = "SERVER_ANNOUNCEMENT",
            MinimumRank = "MODERATOR",
            RequiresTarget = false,
            RateLimitSeconds = 10.0,
            AuditLogCategory = "BROADCAST",
            Description = "Broadcast banner alert across all client HUDs.",
        },
    },
}

return table.freeze(AdminPermissionsConfig)
