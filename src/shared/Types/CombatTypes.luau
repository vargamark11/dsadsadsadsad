--!strict
--[[
    CombatTypes.luau
    Authoritative types for weapons, projectiles, raycast validations, and damage events.
]]

export type WeaponSlot = "PRIMARY" | "SECONDARY" | "MELEE" | "TACTICAL"

export type ClientFireRequest = {
    WeaponId: string,
    Origin: Vector3,
    Direction: Vector3,
    HitInstance: Instance?,
    HitPosition: Vector3?,
    ClientTimestamp: number,
}

export type ServerHitValidation = {
    IsValid: boolean,
    FailureReason: string?,
    CalculatedDamage: number,
    IsHeadshot: boolean,
    TargetDied: boolean,
    Attacker: Player,
    TargetEntityId: string?,
    TargetPlayer: Player?,
}

export type WeaponLiveState = {
    WeaponId: string,
    CurrentAmmo: number,
    ReserveAmmo: number,
    IsReloading: boolean,
    ReloadStartTime: number,
    LastFireTime: number,
}

export type DamageEvent = {
    DamageAmount: number,
    DamageType: "BALLISTIC" | "ALIEN_MELEE" | "ACID" | "EXPLOSIVE" | "ENVIRONMENTAL",
    SourceEntityId: string?,
    SourcePlayer: Player?,
    VictimEntityId: string?,
    VictimPlayer: Player?,
    IsHeadshot: boolean,
    Timestamp: number,
}

local CombatTypes = {}
return CombatTypes
