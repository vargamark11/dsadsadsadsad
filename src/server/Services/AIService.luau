--!strict
--[[
    AIService.luau
    Sensory perception and hearing propagation coordinator in ALIEN: NIGHTFALL.
    Broadcasts sound stimuli across the colony, evaluates sensory cones,
    and dispatches auditory/visual awareness to active alien state machines.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AlienTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.AlienTypes)
local ServiceManager = require(script.Parent.Parent.ServiceManager)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

local AIService = {
    Name = "AIService",
    SoundBroadcasted = Signal.new(),
}

function AIService:OnInit()
    print("[AIService] Initialized.")
end

function AIService:OnStart()
    print("[AIService] Started.")
end

function AIService:BroadcastSoundStimulus(stimulus: AlienTypes.SoundStimulus)
    local AlienService = ServiceManager.GetService("AlienService") :: any
    local WeatherService = ServiceManager.GetService("WeatherService") :: any
    if not AlienService then return end

    local _, hearingFactor = 1.0, 1.0
    if WeatherService then
        _, hearingFactor = WeatherService:GetSensoryMultipliers()
    end

    local effectiveRadius = stimulus.Radius * hearingFactor

    -- Propagate sound to all active aliens within hearing distance
    local aliens = AlienService:GetActiveAliens()
    for _, alien in pairs(aliens) do
        if alien.RootPart and alien.RootPart.Parent then
            local dist = (alien.RootPart.Position - stimulus.Position).Magnitude
            local maxHearing = alien.Config.Sensory.HearingDistance * hearingFactor

            if dist <= effectiveRadius and dist <= maxHearing then
                if stimulus.Amplitude >= alien.Config.Sensory.SoundThreshold then
                    -- Dispatch auditory stimulus to alien state machine
                    AlienService:OnAlienHeardSound(alien.EntityId, stimulus)
                end
            end
        end
    end

    self.SoundBroadcasted:Fire(stimulus)
end

function AIService:CheckLineOfSight(fromPosition: Vector3, targetPart: BasePart, maxDistance: number): (boolean, number)
    local toTarget = targetPart.Position - fromPosition
    local dist = toTarget.Magnitude

    if dist > maxDistance then
        return false, dist
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { targetPart.Parent }
    raycastParams.IgnoreWater = true

    local result = Workspace:Raycast(fromPosition, toTarget.Unit * dist, raycastParams)
    local hasLOS = (result == nil)

    return hasLOS, dist
end

function AIService:IsInFieldOfView(alienRootPart: BasePart, targetPosition: Vector3, fovDegrees: number): boolean
    local forward = alienRootPart.CFrame.LookVector
    local toTarget = (targetPosition - alienRootPart.Position).Unit
    local dot = forward:Dot(toTarget)
    local halfFovRadians = math.rad(fovDegrees / 2)
    local threshold = math.cos(halfFovRadians)
    return dot >= threshold
end

return AIService
