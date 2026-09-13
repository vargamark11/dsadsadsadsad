--!strict
--[[
    PlayerService.spec.luau
    Unit tests for ServerScriptService.Services.PlayerService and PlayerConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local PlayerConfig = require(Config:WaitForChild("PlayerConfig"))

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

    print("[Server:PlayerService.spec] Running player system tests...")

    -- Test 1: Config thresholds
    Assert(PlayerConfig.MaxHealth == 100, "MaxHealth is 100")
    Assert(PlayerConfig.MaxStamina == 100, "MaxStamina is 100")
    Assert(PlayerConfig.SprintDrainRate == 18, "Sprint drain is 18 units/s")
    Assert(PlayerConfig.StaminaRecoveryRate == 22, "Stamina recovery is 22 units/s")
    Assert(PlayerConfig.MinimumSprintStamina == 10, "Min sprint stamina threshold is 10")

    -- Test 2: State transitions
    Assert(PlayerConfig.StateTransitions.ALIVE.DOWNED == true, "ALIVE can transition to DOWNED")
    Assert(PlayerConfig.StateTransitions.DOWNED.ALIVE == true, "DOWNED can transition to ALIVE (Revived)")
    Assert(PlayerConfig.StateTransitions.DEAD.SPAWNING == true, "DEAD can transition to SPAWNING")

    return passed, total
end

return { Run = RunTests }
