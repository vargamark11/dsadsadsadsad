--!strict
--[[
    ModerationService.luau
    Authoritative player discipline and enforcement service in ALIEN: NIGHTFALL.
    Handles Kick, Ban, Unban, and Freeze with DataStore ban registry.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServiceManager = require(script.Parent.Parent.ServiceManager)

local ModerationService = {
    Name = "ModerationService",
    _banStore = nil :: GlobalDataStore?,
}

function ModerationService:OnInit()
    pcall(function()
        self._banStore = DataStoreService:GetDataStore("AlienNightfall_BanRegistry_v1")
    end)
    print("[ModerationService] Initialized.")
end

function ModerationService:OnStart()
    print("[ModerationService] Started.")
end

function ModerationService:OnPlayerAdded(player: Player)
    -- Check ban record on join
    if self._banStore then
        local success, banRecord = pcall(function()
            return self._banStore:GetAsync("Ban_" .. tostring(player.UserId))
        end)
        if success and banRecord and type(banRecord) == "table" then
            if banRecord.ExpiresAt == 0 or os.time() < banRecord.ExpiresAt then
                player:Kick(string.format("[MODERATION BAN] You are banned from ALIEN: NIGHTFALL.\nReason: %s", banRecord.Reason or "Violation of community standards"))
            end
        end
    end
end

function ModerationService:KickPlayer(admin: Player, target: Player, reason: string): boolean
    local LoggingService = ServiceManager.GetService("LoggingService") :: any
    if LoggingService then
        LoggingService:Log("ADMIN", "KICK_PLAYER", { Reason = reason }, admin, target)
    end
    target:Kick(string.format("[COLONY DISCIPLINE] Kicked by moderator: %s", reason))
    return true
end

function ModerationService:BanPlayer(admin: Player, targetUserId: number, targetName: string, reason: string, durationSeconds: number?): boolean
    local expiresAt = (durationSeconds and durationSeconds > 0) and (os.time() + durationSeconds) or 0
    local banData = {
        UserId = targetUserId,
        Username = targetName,
        BannedByUserId = admin.UserId,
        BannedByUsername = admin.Name,
        Reason = reason,
        BannedAt = os.time(),
        ExpiresAt = expiresAt,
    }

    if self._banStore then
        pcall(function()
            self._banStore:SetAsync("Ban_" .. tostring(targetUserId), banData)
        end)
    end

    local onlinePlayer = Players:GetPlayerByUserId(targetUserId)
    if onlinePlayer then
        onlinePlayer:Kick(string.format("[BANNED] %s", reason))
    end

    local LoggingService = ServiceManager.GetService("LoggingService") :: any
    if LoggingService then
        LoggingService:Log("ADMIN", "BAN_PLAYER", banData, admin, onlinePlayer)
    end

    return true
end

function ModerationService:FreezePlayer(admin: Player, target: Player, freeze: boolean): boolean
    local char = target.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then
        root.Anchored = freeze
        return true
    end
    return false
end

return ModerationService
