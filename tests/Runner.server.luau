--!strict
--[[
    Runner.server.luau
    Automated unit testing harness for ALIEN: NIGHTFALL.
    Executes all spec suites and reports pass/fail diagnostics.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProgressionConfig = require(ReplicatedStorage.AlienNightfall.Config.ProgressionConfig)
local EconomyConfig = require(ReplicatedStorage.AlienNightfall.Config.EconomyConfig)
local TableUtil = require(ReplicatedStorage.AlienNightfall.Shared.Utility.TableUtil)
local RateLimiter = require(ReplicatedStorage.AlienNightfall.Shared.Utility.RateLimiter)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

print("==================================================")
print("[ALIEN: NIGHTFALL TEST HARNESS] Running Test Suites...")
print("==================================================")

local passedCount = 0
local failedCount = 0

local function runTest(testName: string, testFn: () -> ())
    local success, err = pcall(testFn)
    if success then
        passedCount += 1
        print(string.format("  ✓ [PASS] %s", testName))
    else
        failedCount += 1
        warn(string.format("  ✗ [FAIL] %s -> %s", testName, tostring(err)))
    end
end

-- Suite 1: Utility Tests
runTest("Signal Observer Pattern", function()
    local sig = Signal.new()
    local fired = false
    local testPayload = 42

    local conn = sig:Connect(function(val)
        fired = true
        assert(val == testPayload, "Signal payload mismatch")
    end)

    sig:Fire(testPayload)
    assert(fired, "Signal did not invoke connected listener")
    conn:Disconnect()
end)

runTest("TableUtil DeepCopy & Reconcile", function()
    local original = { a = 1, b = { c = "test" } }
    local copy = TableUtil.DeepCopy(original)
    copy.b.c = "mutated"
    assert(original.b.c == "test", "DeepCopy failed isolation test")

    local template = { x = 10, y = 20, z = 30 }
    local target = { x = 99 }
    local reconciled = TableUtil.Reconcile(target, template)
    assert(reconciled.x == 99, "Reconcile overwrote existing value")
    assert(reconciled.y == 20 and reconciled.z == 30, "Reconcile did not backfill missing keys")
end)

runTest("RateLimiter Token Bucket", function()
    local limiter = RateLimiter.new(10, 5) -- 10 tokens max, refill 5/sec
    assert(limiter:Consume(5), "Failed to consume within initial capacity")
    assert(limiter:Consume(5), "Failed to consume second half of bucket")
    assert(not limiter:Consume(1), "Allowed consumption beyond empty bucket")
end)

-- Suite 2: Progression Formula Tests
runTest("Progression XP Curve & Scaling", function()
    local lvl1 = ProgressionConfig.GetXPRequired(1)
    local lvl2 = ProgressionConfig.GetXPRequired(2)
    local lvl10 = ProgressionConfig.GetXPRequired(10)

    assert(lvl1 == 0, "Level 1 base XP must be 0")
    assert(lvl2 > 0, "Level 2 XP must be greater than 0")
    assert(lvl10 > lvl2, "Level 10 XP must be greater than Level 2 XP")
end)

-- Suite 3: Economy Integrity Tests
runTest("Economy Balance Bounds", function()
    local maxCredits = EconomyConfig.Currencies.ColonyCredits.MaxBalance
    assert(maxCredits == 1000000, "Economy MaxBalance constant mismatch")
end)

-- Suite 4: Phase 2 Player System Specifications
local PlayerSystemSpec = require(script.Parent["PlayerSystem.spec"])
PlayerSystemSpec.RunTests(runTest)

-- Suite 5: Phase 3 Interaction System Specifications
local InteractionSystemSpec = require(script.Parent["InteractionSystem.spec"])
InteractionSystemSpec.RunTests(runTest)

print("==================================================")
print(string.format("[TEST SUMMARY] Completed with %d Passed, %d Failed", passedCount, failedCount))
print("==================================================")
