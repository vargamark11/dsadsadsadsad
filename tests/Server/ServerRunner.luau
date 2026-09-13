--!strict
--[[
    ServerRunner.luau
    Automated test executor for server-side services and shared logic.
]]

local ServerRunner = {}

function ServerRunner.RunAll(): boolean
    print("==================================================")
    print("  ALIEN: NIGHTFALL — SERVER TEST SUITE RUNNER     ")
    print("==================================================")

    local passedCount = 0
    local totalCount = 0

    -- Run Shared Specs
    local sharedFolder = script.Parent.Parent:FindFirstChild("Shared")
    if sharedFolder then
        local utilSpec = sharedFolder:FindFirstChild("Utilities.spec")
        if utilSpec and utilSpec:IsA("ModuleScript") then
            local specModule = require(utilSpec) :: any
            if specModule and specModule.Run then
                local p, t = specModule.Run()
                passedCount += p
                totalCount += t
            end
        end
    end

    print(string.format("[ServerRunner] Complete: %d/%d tests passed.", passedCount, totalCount))
    return passedCount == totalCount
end

return ServerRunner
