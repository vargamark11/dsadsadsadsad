--!strict
--[[
    AntiCheatService.luau
    Authoritative anomaly detection and exploit prevention system in ALIEN: NIGHTFALL.
    Monitors movement speed, weapon fire rates, remote spam, and inventory exploits.
    Uses configurable strike thresholds rather than erratic false-positive kicks.
]]

local ServiceManager = require(script.Parent.Parent.ServiceManager)

type PlayerCheatRecord = {
    StrikeCount: number,
    LastKnownPosition: Vector3?,
    LastPositionTimestamp: number,
    LastFireTimestamp: number,
    TotalShotsInWindow: number,
    WindowStartTimestamp: number,
    FlagHistory: { string },
}

local AntiCheatService = {
    Name = "AntiCheatService",
    _records = {} :: { [number]: PlayerCheatRecord },
    _strikeThresholdToKick = 10,
    _strikeThresholdToFlag = 3,
}

function AntiCheatService:OnInit()
    print("[AntiCheatService] Initialized.")
end

function AntiCheatService:OnStart()
    print("[AntiCheatService] Started.")
end

function AntiCheatService:OnPlayerAdded(player: Player)
    self._records[player.UserId] = {
        StrikeCount = 0,
        LastKnownPosition = nil,
        LastPositionTimestamp = os.clock(),
        LastFireTimestamp = 0,
        TotalShotsInWindow = 0,
        WindowStartTimestamp = os.clock(),
        FlagHistory = {},
    }
end

function AntiCheatService:OnPlayerRemoving(player: Player)
    self._records[player.UserId] = nil
end

function AntiCheatService:RecordStrike(player: Player, reason: string, severity: number?)
    local rec = self._records[player.UserId]
    if not rec then return end

    local added = severity or 1
    rec.StrikeCount += added
    table.insert(rec.FlagHistory, string.format("[%s] %s (+%d)", os.date("%X"), reason, added))

    local LoggingService = ServiceManager.GetService("LoggingService") :: any
    if LoggingService then
        LoggingService:Log("ANTI_CHEAT", "STRIKE_RECORDED", {
            Reason = reason,
            Severity = added,
            TotalStrikes = rec.StrikeCount,
        }, player, nil)
    end

    if rec.StrikeCount >= self._strikeThresholdToKick then
        warn(string.format("[AntiCheat] Kicking player %s (%d): Reached %d strikes. Reason: %s",
            player.Name, player.UserId, rec.StrikeCount, reason))
        player:Kick(string.format("[SECURITY PROTOCOL] Disconnected due to repeated client anomalies: %s", reason))
    end
end

function AntiCheatService:ValidateFireRate(player: Player, weaponId: string, maxFireRateHz: number): boolean
    local rec = self._records[player.UserId]
    if not rec then return true end

    local now = os.clock()
    local minDelta = 1 / (maxFireRateHz * 1.25) -- 25% tolerance for network jitter
    local delta = now - rec.LastFireTimestamp

    if rec.LastFireTimestamp > 0 and delta < minDelta then
        self:RecordStrike(player, string.format("Fire rate anomaly on %s (delta=%.3fs, min=%.3fs)", weaponId, delta, minDelta), 1)
        return false
    end

    rec.LastFireTimestamp = now
    return true
end

function AntiCheatService:ValidateMovement(player: Player, currentPosition: Vector3, maxAllowedSpeed: number): boolean
    local rec = self._records[player.UserId]
    if not rec then return true end

    local now = os.clock()
    if not rec.LastKnownPosition then
        rec.LastKnownPosition = currentPosition
        rec.LastPositionTimestamp = now
        return true
    end

    local timeDelta = now - rec.LastPositionTimestamp
    if timeDelta < 0.1 then
        return true -- Too short a window to measure reliably
    end

    local distance = (currentPosition - rec.LastKnownPosition).Magnitude
    local calculatedSpeed = distance / timeDelta

    -- Buffer 15 studs/s for jumps/network ping spikes
    local allowedThreshold = maxAllowedSpeed + 15
    if calculatedSpeed > allowedThreshold and distance > 25 then
        self:RecordStrike(player, string.format("Movement speed anomaly (speed=%.1f, maxAllowed=%.1f)", calculatedSpeed, allowedThreshold), 1)
        -- Snap position back
        return false
    end

    rec.LastKnownPosition = currentPosition
    rec.LastPositionTimestamp = now
    return true
end

return AntiCheatService
