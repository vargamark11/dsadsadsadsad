--!strict
--[[
    RateLimiter.luau
    Token-bucket rate limiter for network requests, remote event validation,
    and anti-spam protection across server services.
]]

export type RateLimiter = {
    Check: (self: RateLimiter, key: string, maxTokens: number, refillRatePerSec: number) -> boolean,
    Reset: (self: RateLimiter, key: string) -> (),
    ClearAll: (self: RateLimiter) -> (),
}

type Bucket = {
    tokens: number,
    lastRefill: number,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(): RateLimiter
    local self = setmetatable({
        _buckets = {} :: { [string]: Bucket },
    }, RateLimiter)
    return (self :: any) :: RateLimiter
end

function RateLimiter:Check(key: string, maxTokens: number, refillRatePerSec: number): boolean
    local now = os.clock()
    local bucket = self._buckets[key]

    if not bucket then
        bucket = {
            tokens = maxTokens - 1,
            lastRefill = now,
        }
        self._buckets[key] = bucket
        return true
    end

    local elapsed = now - bucket.lastRefill
    bucket.tokens = math.min(maxTokens, bucket.tokens + (elapsed * refillRatePerSec))
    bucket.lastRefill = now

    if bucket.tokens >= 1 then
        bucket.tokens -= 1
        return true
    else
        return false
    end
end

function RateLimiter:Reset(key: string)
    self._buckets[key] = nil
end

function RateLimiter:ClearAll()
    table.clear(self._buckets)
end

return RateLimiter
