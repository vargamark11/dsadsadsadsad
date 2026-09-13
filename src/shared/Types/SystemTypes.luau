--!strict
--[[
    SystemTypes.luau
    Core foundational system types, service/controller lifecycle interfaces,
    and result wrappers for ALIEN: NIGHTFALL.
]]

export type ServiceLifecycle = {
    Name: string,
    OnInit: (self: any) -> (),
    OnStart: (self: any) -> (),
    OnPlayerAdded: ((self: any, player: Player) -> ())?,
    OnPlayerRemoving: ((self: any, player: Player) -> ())?,
}

export type ControllerLifecycle = {
    Name: string,
    OnInit: (self: any) -> (),
    OnStart: (self: any) -> (),
}

export type Result<T, E> = {
    Success: true,
    Value: T,
} | {
    Success: false,
    Error: E,
}

export type ServerJobContext = {
    PlaceId: number,
    GameId: number,
    JobId: string,
    ServerStartTime: number,
    MaxPlayers: number,
}

local SystemTypes = {}
return SystemTypes
