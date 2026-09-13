--!strict
--[[
    LoggingService.luau
    Centralized server logging and audit trail system for ALIEN: NIGHTFALL.
    Tracks player actions, admin commands, anti-cheat flags, economy events,
    and server state changes with timestamps and JobId metadata.
]]

export type LogEntry = {
    Timestamp: number,
    Category: "ADMIN" | "ANTI_CHEAT" | "ECONOMY" | "COMBAT" | "MISSION" | "SYSTEM",
    ActorUserId: number?,
    ActorName: string?,
    TargetUserId: number?,
    TargetName: string?,
    Action: string,
    Details: { [string]: any },
}

local LoggingService = {
    Name = "LoggingService",
    _logBuffer = {} :: { LogEntry },
    _maxBufferSize = 2000,
}

function LoggingService:OnInit()
    print("[LoggingService] Initialized.")
end

function LoggingService:OnStart()
    print("[LoggingService] Started.")
end

function LoggingService:Log(
    category: "ADMIN" | "ANTI_CHEAT" | "ECONOMY" | "COMBAT" | "MISSION" | "SYSTEM",
    action: string,
    details: { [string]: any },
    actor: Player?,
    target: Player?
)
    local entry: LogEntry = {
        Timestamp = os.time(),
        Category = category,
        ActorUserId = actor and actor.UserId or nil,
        ActorName = actor and actor.Name or nil,
        TargetUserId = target and target.UserId or nil,
        TargetName = target and target.Name or nil,
        Action = action,
        Details = details or {},
    }

    table.insert(self._logBuffer, entry)
    if #self._logBuffer > self._maxBufferSize then
        table.remove(self._logBuffer, 1)
    end

    local prefix = string.format("[LOG::%s][%s]", category, action)
    if actor then
        prefix = prefix .. string.format(" Actor=%s(%d)", actor.Name, actor.UserId)
    end
    if target then
        prefix = prefix .. string.format(" Target=%s(%d)", target.Name, target.UserId)
    end
    -- In production, high-priority entries can be dispatched to external webhooks or DataStore logs
end

function LoggingService:GetRecentLogs(count: number?, categoryFilter: string?): { LogEntry }
    local limit = math.min(count or 100, #self._logBuffer)
    local results: { LogEntry } = {}

    for i = #self._logBuffer, 1, -1 do
        local item = self._logBuffer[i]
        if not categoryFilter or item.Category == categoryFilter then
            table.insert(results, item)
            if #results >= limit then
                break
            end
        end
    end

    return results
end

return LoggingService
