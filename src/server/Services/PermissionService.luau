--!strict
--[[
    PermissionService.luau
    Authoritative player permission evaluator in ALIEN: NIGHTFALL.
    Resolves ranks from AdminPermissionsConfig. Never relies on client claims.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AdminPermissionsConfig = require(ReplicatedStorage.AlienNightfall.Config.AdminPermissionsConfig)

export type AdminRank = "NONE" | "MODERATOR" | "ADMIN" | "HEAD_ADMIN" | "OWNER"

local PermissionService = {
    Name = "PermissionService",
    _playerRanks = {} :: { [number]: AdminRank },
}

function PermissionService:OnInit()
    print("[PermissionService] Initialized.")
end

function PermissionService:OnStart()
    print("[PermissionService] Started.")
end

function PermissionService:OnPlayerAdded(player: Player)
    -- Resolve rank strictly server-side
    local assignedRank: AdminRank = AdminPermissionsConfig.AuthorizedUserIds[player.UserId] or "NONE"

    -- Check Roblox Group role if configured
    if AdminPermissionsConfig.GroupRankMapping then
        local groupId = AdminPermissionsConfig.GroupRankMapping.GroupId
        local success, playerGroupRank = pcall(function()
            return player:GetRankInGroup(groupId)
        end)
        if success and playerGroupRank then
            local mappedRank = AdminPermissionsConfig.GroupRankMapping.Ranks[playerGroupRank]
            if mappedRank then
                local currentVal = AdminPermissionsConfig.RankValues[assignedRank] or 0
                local groupVal = AdminPermissionsConfig.RankValues[mappedRank] or 0
                if groupVal > currentVal then
                    assignedRank = mappedRank
                end
            end
        end
    end

    self._playerRanks[player.UserId] = assignedRank
    if assignedRank ~= "NONE" then
        print(string.format("[PermissionService] Player %s (%d) verified as %s", player.Name, player.UserId, assignedRank))
    end
end

function PermissionService:OnPlayerRemoving(player: Player)
    self._playerRanks[player.UserId] = nil
end

function PermissionService:GetRank(player: Player): AdminRank
    return self._playerRanks[player.UserId] or "NONE"
end

function PermissionService:HasRank(player: Player, requiredRank: AdminRank): boolean
    local playerRank = self:GetRank(player)
    local pVal = AdminPermissionsConfig.RankValues[playerRank] or 0
    local rVal = AdminPermissionsConfig.RankValues[requiredRank] or 0
    return pVal >= rVal
end

function PermissionService:CanExecuteCommand(player: Player, commandId: string): (boolean, string?)
    local cmdDef = AdminPermissionsConfig.Commands[commandId]
    if not cmdDef then
        return false, "Command does not exist"
    end

    if not self:HasRank(player, cmdDef.MinimumRank) then
        return false, string.format("Insufficient permissions. Required: %s", cmdDef.MinimumRank)
    end

    return true, nil
end

return PermissionService
