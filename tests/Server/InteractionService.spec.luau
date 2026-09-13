--!strict
--[[
    InteractionService.spec.luau
    Unit tests for ServerScriptService.Services.InteractionService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local InteractionConfig = require(Config:WaitForChild("InteractionConfig"))

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

    print("[Server:InteractionService.spec] Running interaction tests...")

    -- Test 1: Clearance hierarchy validation
    local hierarchy = InteractionConfig.ClearanceHierarchy
    Assert(hierarchy.KEYCARD_MASTER > hierarchy.KEYCARD_LEVEL_1, "Master clearance exceeds Level 1")
    Assert(hierarchy.KEYCARD_LEVEL_3 > hierarchy.KEYCARD_LEVEL_2, "Level 3 clearance exceeds Level 2")
    Assert(hierarchy.NONE == 0, "No clearance is rank 0")

    -- Test 2: Validation buffer limits
    Assert(InteractionConfig.Validation.DefaultDistance == 10.0, "Default distance matches 10 studs")
    Assert(InteractionConfig.Validation.LatencyToleranceBuffer == 2.5, "Latency buffer matches 2.5 studs")

    -- Test 3: Anti-spam cooldown
    Assert(InteractionConfig.Cooldowns.PlayerInteraction == 0.25, "Player cooldown matches 0.25s")

    return passed, total
end

return { Run = RunTests }
