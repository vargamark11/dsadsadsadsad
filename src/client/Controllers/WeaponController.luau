--!strict
--[[
    WeaponController.luau
    Client-side weapon handling, aiming, visual feedback, and remote fire dispatch.
    Calculates screen-center raycasts and applies procedural recoil.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponsConfig = require(ReplicatedStorage.AlienNightfall.Config.WeaponsConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ControllerManager = require(script.Parent.Parent.ControllerManager)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

local localPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local WeaponController = {
    Name = "WeaponController",
    AmmoUpdated = Signal.new(),
    HitConfirmed = Signal.new(),
    _activeWeaponId = "PISTOL_STANDARD",
    _currentAmmo = 12,
    _reserveAmmo = 60,
    _isFiring = false,
    _lastFireTimestamp = 0,
}

function WeaponController:OnInit()
    print("[WeaponController] Initialized.")
end

function WeaponController:OnStart()
    local InputController = ControllerManager.GetController("InputController") :: any
    local CameraController = ControllerManager.GetController("CameraController") :: any
    local AudioController = ControllerManager.GetController("AudioController") :: any

    -- Listen for trigger pull
    InputController.FireTriggered:Connect(function(isDown)
        self._isFiring = isDown
        if isDown then
            self:TryFire()
        end
    end)

    -- Listen for reload
    InputController.ReloadTriggered:Connect(function()
        NetworkProtocol.ClientFireServer("CombatRemotes", "ReloadRequest", self._activeWeaponId)
    end)

    -- Auto-fire tick for full-auto weapons
    RunService.RenderStepped:Connect(function()
        if self._isFiring then
            local config = WeaponsConfig[self._activeWeaponId :: any]
            if config and config.FireMode == "AUTOMATIC" then
                local interval = 1 / config.FireRate
                if (os.clock() - self._lastFireTimestamp) >= interval then
                    self:TryFire()
                end
            end
        end
    end)

    -- Listen for authoritative hit confirmations from server
    NetworkProtocol.ClientConnectEvent("CombatRemotes", "HitConfirmed", function(hitData: any)
        if AudioController then
            AudioController:PlayHitSound(hitData.IsHeadshot == true)
        end
        self.HitConfirmed:Fire(hitData)
    end)

    print("[WeaponController] Started.")
end

function WeaponController:TryFire()
    local config = WeaponsConfig[self._activeWeaponId :: any]
    if not config or self._currentAmmo <= 0 then return end

    local now = os.clock()
    local minInterval = 1 / config.FireRate
    if (now - self._lastFireTimestamp) < minInterval then
        return
    end

    self._lastFireTimestamp = now
    self._currentAmmo -= 1
    self.AmmoUpdated:Fire(self._currentAmmo, self._reserveAmmo)

    -- Camera Recoil Kick
    local CameraController = ControllerManager.GetController("CameraController") :: any
    if CameraController then
        local kickUp = config.RecoilVertical or 1.5
        local kickSide = (math.random() - 0.5) * (config.RecoilHorizontal or 0.8)
        CameraController:ApplyRecoil(kickUp, kickSide)
    end

    -- Aim direction from screen center
    local viewportCenter = Camera.ViewportSize / 2
    local unitRay = Camera:ViewportPointToRay(viewportCenter.X, viewportCenter.Y)

    local character = localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local origin = rootPart and (rootPart.Position + Vector3.new(0, 1.5, 0)) or unitRay.Origin

    -- Send shot request to server
    NetworkProtocol.ClientFireServer("CombatRemotes", "FireWeapon", {
        WeaponId = self._activeWeaponId,
        Origin = origin,
        Direction = unitRay.Direction,
        Timestamp = now,
    })
end

return WeaponController
