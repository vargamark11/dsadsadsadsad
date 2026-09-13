--!strict
--[[
    CameraController.luau
    Immersive horror camera system for ALIEN: NIGHTFALL.
    Handles dynamic sprint FOV transitions, procedural trauma shake,
    and weapon recoil offsets.
]]

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local CameraController = {
    Name = "CameraController",
    _baseFOV = 70,
    _sprintFOV = 82,
    _trauma = 0,
    _recoilOffset = Vector2.zero,
}

function CameraController:OnInit()
    Camera.FieldOfView = self._baseFOV
    print("[CameraController] Initialized.")
end

function CameraController:OnStart()
    -- RenderStepped camera shake and recoil recovery loop
    RunService.RenderStepped:Connect(function(dt: number)
        if self._trauma > 0 then
            self._trauma = math.max(0, self._trauma - (dt * 1.5))
            local shakeAmount = self._trauma ^ 2
            local yaw = (math.noise(os.clock() * 20, 0, 0) - 0.5) * shakeAmount * 0.05
            local pitch = (math.noise(0, os.clock() * 20, 0) - 0.5) * shakeAmount * 0.05
            Camera.CFrame = Camera.CFrame * CFrame.Angles(pitch, yaw, 0)
        end

        -- Smooth recoil return
        if self._recoilOffset.Magnitude > 0.01 then
            self._recoilOffset = self._recoilOffset:Lerp(Vector2.zero, math.clamp(dt * 8, 0, 1))
        end
    end)
    print("[CameraController] Started.")
end

function CameraController:SetSprinting(isSprinting: boolean)
    local targetFOV = isSprinting and self._sprintFOV or self._baseFOV
    local tween = TweenService:Create(Camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        FieldOfView = targetFOV,
    })
    tween:Play()
end

function CameraController:AddTrauma(amount: number)
    self._trauma = math.clamp(self._trauma + amount, 0, 1.0)
end

function CameraController:ApplyRecoil(kickUp: number, kickSide: number)
    self._recoilOffset += Vector2.new(kickSide, kickUp)
    Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(kickUp), math.rad(kickSide), 0)
end

return CameraController
