--!strict
--[[
    InventoryTypes.luau
    Inventory item slots, containers, and interaction payloads for ALIEN: NIGHTFALL.
]]

export type InventorySlot = {
    SlotIndex: number,
    ItemId: string,
    Quantity: number,
    Metadata: { [string]: any }?,
}

export type InventoryContainer = {
    OwnerUserId: number,
    Slots: { [number]: InventorySlot },
    MaxSlots: number,
    CurrentWeightKg: number,
    MaxWeightKg: number,
}

export type InventoryActionType =
    | "USE_ITEM"
    | "DROP_ITEM"
    | "MOVE_SLOT"
    | "SPLIT_STACK"
    | "EQUIP_WEAPON"
    | "UNEQUIP_WEAPON"

export type InventoryActionRequest = {
    Action: InventoryActionType,
    SourceSlot: number,
    TargetSlot: number?,
    Quantity: number?,
}

local InventoryTypes = {}
return InventoryTypes
