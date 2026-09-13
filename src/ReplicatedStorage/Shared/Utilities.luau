--!strict
--[[
    Utilities.luau
    Universal math, networking, and spatial utility functions for ALIEN: NIGHTFALL.
    Synchronized to ReplicatedStorage.Shared.Utilities via Rojo.
]]

local Utilities = {}

-- Calculates Euclidean distance between two Vector3 positions or BaseParts
function Utilities.Distance(posA: Vector3 | BasePart, posB: Vector3 | BasePart): number
    local vA = if typeof(posA) == "Instance" and posA:IsA("BasePart") then posA.Position else posA :: Vector3
    local vB = if typeof(posB) == "Instance" and posB:IsA("BasePart") then posB.Position else posB :: Vector3
    return (vA - vB).Magnitude
end

-- Line of Sight Raycast check with configurable filter
function Utilities.HasLineOfSight(origin: Vector3, target: Vector3, filterInstances: { Instance }?): boolean
    local direction = target - origin
    local distance = direction.Magnitude

    if distance < 0.1 then
        return true
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = RaycastFilterType.Exclude
    if filterInstances then
        raycastParams.FilterDescendantsInstances = filterInstances
    end
    raycastParams.IgnoreWater = true

    local result = workspace:Raycast(origin, direction.Unit * distance, raycastParams)
    return result == nil
end

-- Deep clone for pure data tables
function Utilities.DeepCopy<T>(original: T): T
    if typeof(original) ~= "table" then
        return original
    end

    local copy = {}
    for k, v in pairs(original :: any) do
        copy[k] = Utilities.DeepCopy(v)
    end
    return copy :: any
end

-- Format seconds into MM:SS string
function Utilities.FormatTime(seconds: number): string
    local clamped = math.max(0, math.floor(seconds))
    local mins = math.floor(clamped / 60)
    local secs = clamped % 60
    return string.format("%02d:%02d", mins, secs)
end

-- Token-bucket rate limiter for remote abuse mitigation
export type RateLimiter = {
    Check: (self: RateLimiter, id: string) -> boolean,
    Reset: (self: RateLimiter, id: string) -> (),
}

function Utilities.CreateRateLimiter(ratePerSecond: number, burstLimit: number?): RateLimiter
    local burst = burstLimit or ratePerSecond
    local buckets: { [string]: { tokens: number, lastCheck: number } } = {}

    local limiter = {}

    function limiter:Check(id: string): boolean
        local now = os.clock()
        local record = buckets[id]

        if not record then
            buckets[id] = { tokens = burst - 1, lastCheck = now }
            return true
        end

        local elapsed = now - record.lastCheck
        record.lastCheck = now
        record.tokens = math.min(burst, record.tokens + (elapsed * ratePerSecond))

        if record.tokens >= 1 then
            record.tokens -= 1
            return true
        end

        return false
    end

    function limiter:Reset(id: string)
        buckets[id] = nil
    end

    return limiter
end

-- Lightweight Signal Implementation (RBXScriptSignal alternative)
export type SignalConnection = {
    Disconnect: (self: SignalConnection) -> (),
    Connected: boolean,
}

export type Signal = {
    Connect: (self: Signal, fn: (...any) -> ()) -> SignalConnection,
    Fire: (self: Signal, ...any) -> (),
    Destroy: (self: Signal) -> (),
}

function Utilities.CreateSignal(): Signal
    local listeners: { [(...any) -> ()]: boolean } = {}

    local sig = {}

    function sig:Connect(fn: (...any) -> ()): SignalConnection
        listeners[fn] = true
        local conn = { Connected = true }
        function conn:Disconnect()
            if self.Connected then
                self.Connected = false
                listeners[fn] = nil
            end
        end
        return conn
    end

    function sig:Fire(...: any)
        for fn in pairs(listeners) do
            task.spawn(fn, ...)
        end
    end

    function sig:Destroy()
        table.clear(listeners)
    end

    return sig
end

return table.freeze(Utilities)
