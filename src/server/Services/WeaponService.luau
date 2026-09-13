--!strict
--[[
    WeaponService.luau
    Authoritative weapon loadout, ammunition tracking, and reload coordinator.
    Never trusts client magazine or reserve ammo counts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponsConfig = require(ReplicatedStorage.AlienNightfall.Config.WeaponsConfig)
local CombatTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.CombatTypes)
local ServiceManager = require(script.Parent.Parent.ServiceManager)

local WeaponService = {
    Name = "WeaponService",
    _playerWeapons = {} :: { [number]: { [string]: CombatTypes.WeaponLiveState } },
}

function WeaponService:OnInit()
    print("[WeaponService] Initialized.")
end

function WeaponService:OnStart()
    print("[WeaponService] Started.")
end

function WeaponService:OnPlayerAdded(player: Player)
    self._playerWeapons[player.UserId] = {}
    -- Equip default starter weapon
    self:EquipWeapon(player, "PISTOL_STANDARD")
end

function WeaponService:OnPlayerRemoving(player: Player)
    self._playerWeapons[player.UserId] = nil
end

function WeaponService:EquipWeapon(player: Player, weaponId: string): boolean
    local config = WeaponsConfig[weaponId :: any]
    if not config then return false end

    local userWeapons = self._playerWeapons[player.UserId]
    if not userWeapons then return false end

    if not userWeapons[weaponId] then
        userWeapons[weaponId] = {
            WeaponId = weaponId,
            CurrentAmmo = config.MagazineCapacity,
            ReserveAmmo = config.MaxReserveAmmo,
            IsReloading = false,
            ReloadStartTime = 0,
            LastFireTime = 0,
        }
    end

    return true
end

function WeaponService:GetWeaponState(player: Player, weaponId: string): CombatTypes.WeaponLiveState?
    local userWeapons = self._playerWeapons[player.UserId]
    return userWeapons and userWeapons[weaponId]
end

function WeaponService:ConsumeAmmo(player: Player, weaponId: string): boolean
    local state = self:GetWeaponState(player, weaponId)
    if not state or state.CurrentAmmo <= 0 or state.IsReloading then
        return false
    end

    state.CurrentAmmo -= 1
    state.LastFireTime = os.clock()
    return true
end

function WeaponService:StartReload(player: Player, weaponId: string): boolean
    local state = self:GetWeaponState(player, weaponId)
    local config = WeaponsConfig[weaponId :: any]
    if not state or not config or state.IsReloading or state.ReserveAmmo <= 0 then
        return false
    end

    if state.CurrentAmmo >= config.MagazineCapacity then
        return false
    end

    state.IsReloading = true
    state.ReloadStartTime = os.clock()

    task.delay(config.ReloadDuration, function()
        if state.IsReloading then
            local needed = config.MagazineCapacity - state.CurrentAmmo
            local toTransfer = math.min(needed, state.ReserveAmmo)
            state.CurrentAmmo += toTransfer
            state.ReserveAmmo -= toTransfer
            state.IsReloading = false
        end
    end)

    return true
end

return WeaponService
