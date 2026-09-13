--!strict
--[[
    Utilities.spec.luau
    Unit tests for ReplicatedStorage.Shared.Utilities functions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Utilities = require(Shared:WaitForChild("Utilities"))

local function RunTests(): (number, number)
    local passed = 0
    local total = 0

    local function Assert(condition: boolean, testName: string)
        total += 1
        if condition then
            passed += 1
            print(string.format("  ✓ %s", testName))
        else
            warn(string.format("  ✕ FAILED: %s", testName))
        end
    end

    print("[Shared:Utilities.spec] Running test suite...")

    -- Test 1: Distance calculation
    local v1 = Vector3.new(0, 0, 0)
    local v2 = Vector3.new(3, 4, 0)
    Assert(Utilities.Distance(v1, v2) == 5, "Euclidean 3-4-5 distance check")

    -- Test 2: FormatTime
    Assert(Utilities.FormatTime(65) == "01:05", "FormatTime 65s -> 01:05")
    Assert(Utilities.FormatTime(0) == "00:00", "FormatTime 0s -> 00:00")
    Assert(Utilities.FormatTime(3599) == "59:59", "FormatTime 3599s -> 59:59")

    -- Test 3: DeepCopy
    local original = { a = 1, b = { c = "test" } }
    local copy = Utilities.DeepCopy(original)
    Assert(copy.b.c == "test" and copy ~= original and copy.b ~= original.b, "DeepCopy isolates references")

    -- Test 4: RateLimiter
    local limiter = Utilities.CreateRateLimiter(2, 2)
    Assert(limiter:Check("user1") == true, "RateLimiter initial token grant")
    Assert(limiter:Check("user1") == true, "RateLimiter second token grant")
    Assert(limiter:Check("user1") == false, "RateLimiter third token exhausted")

    return passed, total
end

return { Run = RunTests }
