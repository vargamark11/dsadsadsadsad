--!strict
--[[
    AudioController.luau
    Authoritative sound effect player and horror ambiance manager in ALIEN: NIGHTFALL.
    Drives heartbeat audio during low health/downed states and combat stingers.
]]

local SoundService = game:GetService("SoundService")

local AudioController = {
    Name = "AudioController",
    _heartbeatSound = nil :: Sound?,
}

function AudioController:OnInit()
    -- Initialize programmatic audio groups/containers
    local sound = Instance.new("Sound")
    sound.Name = "LowHealthHeartbeat"
    sound.SoundId = "rbxassetid://9114223170" -- Atmospheric heartbeat asset placeholder
    sound.Volume = 0
    sound.Looped = true
    sound.Parent = SoundService
    self._heartbeatSound = sound
    print("[AudioController] Initialized.")
end

function AudioController:OnStart()
    print("[AudioController] Started.")
end

function AudioController:SetLowHealthState(isCritical: boolean)
    if not self._heartbeatSound then return end

    if isCritical then
        if not self._heartbeatSound.IsPlaying then
            self._heartbeatSound:Play()
        end
        self._heartbeatSound.Volume = 0.8
    else
        self._heartbeatSound.Volume = 0
        if self._heartbeatSound.IsPlaying then
            self._heartbeatSound:Stop()
        end
    end
end

function AudioController:PlayHitSound(isHeadshot: boolean)
    local hit = Instance.new("Sound")
    hit.SoundId = isHeadshot and "rbxassetid://9114221580" or "rbxassetid://9114221340"
    hit.Volume = 0.7
    hit.PlayOnRemove = true
    hit.Parent = SoundService
    hit:Destroy()
end

return AudioController
