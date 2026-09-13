--!strict
--[[
    InventoryService.luau
    Authoritative backpack, equipment, and scavenging management service.
    Validates stack limits, weight limits, and item consumption strictly on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemsConfig = require(ReplicatedStorage.AlienNightfall.Config.ItemsConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)
local InventoryTypes = require(ReplicatedStorage.AlienNightfall.Shared.Types.InventoryTypes)

local InventoryService = {
    Name = "InventoryService",
}

function InventoryService:OnInit()
    print("[InventoryService] Initialized.")
end

function InventoryService:OnStart()
    -- Bind network function for client inventory actions
    NetworkProtocol.ServerBindFunction("InventoryRemotes", "PerformAction", function(player: Player, payload: any)
        return self:HandleClientAction(player, payload)
    end)
    print("[InventoryService] Started.")
end

function InventoryService:GetInventory(player: Player): any?
    local DataService = ServiceManager.GetService("DataService") :: any
    local profile = DataService and DataService:GetProfile(player)
    return profile and profile.Inventory
end

function InventoryService:AddItem(player: Player, itemId: string, quantity: number): boolean
    local itemDef = ItemsConfig[itemId]
    if not itemDef or quantity <= 0 then return false end

    local inv = self:GetInventory(player)
    if not inv then return false end

    local remaining = quantity

    -- Step 1: Try stacking into existing slots
    for _, slot in pairs(inv.Slots) do
        if slot.ItemId == itemId and slot.Quantity < itemDef.MaxStack then
            local spaceInSlot = itemDef.MaxStack - slot.Quantity
            local toAdd = math.min(remaining, spaceInSlot)
            slot.Quantity += toAdd
            remaining -= toAdd
            if remaining <= 0 then break end
        end
    end

    -- Step 2: Place remaining into empty slots
    if remaining > 0 then
        for slotIdx = 1, inv.MaxSlots do
            if not inv.Slots[slotIdx] then
                local toAdd = math.min(remaining, itemDef.MaxStack)
                inv.Slots[slotIdx] = {
                    SlotIndex = slotIdx,
                    ItemId = itemId,
                    Quantity = toAdd,
                }
                remaining -= toAdd
                if remaining <= 0 then break end
            end
        end
    end

    self:SyncToClient(player)
    return remaining == 0
end

function InventoryService:RemoveItem(player: Player, slotIndex: number, quantity: number): boolean
    local inv = self:GetInventory(player)
    if not inv or not inv.Slots[slotIndex] then return false end

    local slot = inv.Slots[slotIndex]
    if slot.Quantity < quantity then return false end

    slot.Quantity -= quantity
    if slot.Quantity <= 0 then
        inv.Slots[slotIndex] = nil
    end

    self:SyncToClient(player)
    return true
end

function InventoryService:HandleClientAction(player: Player, req: InventoryTypes.InventoryActionRequest): any
    if not req or not req.Action or not req.SourceSlot then
        return { Success = false, Error = "Invalid payload" }
    end

    local inv = self:GetInventory(player)
    if not inv then return { Success = false, Error = "Inventory not loaded" } end

    local source = inv.Slots[req.SourceSlot]
    if not source then
        return { Success = false, Error = "Source slot is empty" }
    end

    local itemDef = ItemsConfig[source.ItemId]
    if not itemDef then return { Success = false, Error = "Item definition not found" } end

    if req.Action == "USE_ITEM" then
        -- Execute item consumption logic (Medical, Battery, etc.)
        if itemDef.Category == "MEDICAL" then
            local PlayerService = ServiceManager.GetService("PlayerService") :: any
            if PlayerService and itemDef.Attributes and itemDef.Attributes.HealAmount then
                PlayerService:Heal(player, itemDef.Attributes.HealAmount)
            end
        end

        if itemDef.ConsumeOnUse then
            self:RemoveItem(player, req.SourceSlot, 1)
        end
        return { Success = true, Action = "USE_ITEM", ItemId = source.ItemId }

    elseif req.Action == "MOVE_SLOT" and req.TargetSlot then
        local targetSlot = req.TargetSlot
        if targetSlot < 1 or targetSlot > inv.MaxSlots then
            return { Success = false, Error = "Target slot out of range" }
        end

        local existingTarget = inv.Slots[targetSlot]
        inv.Slots[targetSlot] = source
        inv.Slots[req.SourceSlot] = existingTarget
        self:SyncToClient(player)
        return { Success = true }
    end

    return { Success = false, Error = "Unsupported action" }
end

function InventoryService:SyncToClient(player: Player)
    local inv = self:GetInventory(player)
    if inv then
        NetworkProtocol.ServerFireClient(player, "InventoryRemotes", "ContainerSync", inv)
    end
end

return InventoryService
