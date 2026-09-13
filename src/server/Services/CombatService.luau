--!strict
--[[
    CombatService.luau
    Server-authoritative ballistic raycasting and damage evaluation in ALIEN: NIGHTFALL.
    Strictly validates shot origin, range, ray trajectory, weapon ammo, fire rate,
    and headshot multipliers. Never trusts client damage parameters.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponsConfig = require(ReplicatedStorage.AlienNightfall.Config.WeaponsConfig)
local CombatTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.CombatTypes)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)
local GameConstants = require(ReplicatedStorage.AlienNightfall.Shared.Constants.GameConstants)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

local CombatService = {
    Name = "CombatService",
    EntityDamaged = Signal.new(),
    EntityKilled = Signal.new(),
}

function CombatService:OnInit()
    print("[CombatService] Initialized.")
end

function CombatService:OnStart()
    -- Bind FireWeapon RemoteEvent
    NetworkProtocol.ServerConnectEvent("CombatRemotes", "FireWeapon", function(player: Player, payload: any)
        self:HandleFireRequest(player, payload)
    end, 25) -- Max 25 shots per second token bucket

    -- Bind ReloadRequest
    NetworkProtocol.ServerConnectEvent("CombatRemotes", "ReloadRequest", function(player: Player, weaponId: any)
        local WeaponService = ServiceManager.GetService("WeaponService") :: any
        if WeaponService and type(weaponId) == "string" then
            WeaponService:StartReload(player, weaponId)
        end
    end, 5)

    print("[CombatService] Started.")
end

function CombatService:HandleFireRequest(player: Player, req: CombatTypes.ClientFireRequest)
    if not req or not req.WeaponId or not req.Direction then return end

    local weaponConfig = WeaponsConfig[req.WeaponId :: any]
    if not weaponConfig then return end

    local WeaponService = ServiceManager.GetService("WeaponService") :: any
    local AntiCheatService = ServiceManager.GetService("AntiCheatService") :: any
    local AIService = ServiceManager.GetService("AIService") :: any

    -- 1. Anti-Cheat: Validate fire rate
    if AntiCheatService and not AntiCheatService:ValidateFireRate(player, req.WeaponId, weaponConfig.FireRate) then
        return
    end

    -- 2. Authoritative Ammo Consumption
    if WeaponService and not WeaponService:ConsumeAmmo(player, req.WeaponId) then
        return
    end

    -- 3. Emit Gunshot Sound to Alien AI
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if rootPart and AIService then
        AIService:BroadcastSoundStimulus({
            Position = rootPart.Position,
            Amplitude = 90,
            Radius = weaponConfig.NoiseRadius,
            SourcePlayer = player,
            Timestamp = os.clock(),
            Category = "GUNFIRE",
        })
    end

    -- 4. Server-Side Raycast Hit Verification
    local origin = rootPart and (rootPart.Position + Vector3.new(0, 1.5, 0)) or req.Origin
    local direction = req.Direction.Unit * math.min(weaponConfig.MaxRange, GameConstants.CombatMaxRayDistance)

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { character }
    raycastParams.IgnoreWater = true

    local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
    if not raycastResult then return end

    local hitPart = raycastResult.Instance
    local hitModel = hitPart and hitPart:FindFirstAncestorOfClass("Model")
    if not hitModel then return end

    -- Check if target is an Alien
    local AlienService = ServiceManager.GetService("AlienService") :: any
    local alienEntity = AlienService and AlienService:GetAlienFromModel(hitModel)

    if alienEntity then
        local isHeadshot = (hitPart.Name == "Head")
        local distance = (raycastResult.Position - origin).Magnitude
        local damage = weaponConfig.BaseDamage

        -- Apply distance falloff
        if distance > weaponConfig.EffectiveRange then
            local falloffProgress = math.clamp((distance - weaponConfig.EffectiveRange) / (weaponConfig.MaxRange - weaponConfig.EffectiveRange), 0, 1)
            local mult = 1 - (falloffProgress * (1 - weaponConfig.FalloffMinPercent))
            damage = damage * mult
        end

        if isHeadshot then
            damage = damage * weaponConfig.HeadshotMultiplier
        end

        AlienService:DamageAlien(alienEntity.EntityId, damage, player, isHeadshot)

        -- Send hit confirmation to client HUD
        NetworkProtocol.ServerFireClient(player, "CombatRemotes", "HitConfirmed", {
            Damage = math.floor(damage),
            IsHeadshot = isHeadshot,
            Position = raycastResult.Position,
        })
    end
end

return CombatService
