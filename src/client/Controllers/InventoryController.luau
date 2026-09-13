--!strict
--[[
    InventoryController.luau
    Client inventory caching and interaction mediator in ALIEN: NIGHTFALL.
    Maintains slot selection, handles quick-use keys, and syncs container updates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local Signal = require(ReplicatedStorage.AlienNightfall.Shared.Utility.Signal)

local InventoryController = {
    Name = "InventoryController",
    InventoryUpdated = Signal.new(),
    _slots = {} :: { [number]: { ItemId: string, Quantity: number } },
    _maxSlots = 16,
    _selectedSlot = 1,
}

function InventoryController:OnInit()
    print("[InventoryController] Initialized.")
end

function InventoryController:OnStart()
    -- Sync container from server
    NetworkProtocol.ClientConnectEvent("InventoryRemotes", "ContainerSync", function(container: any)
        if not container then return end
        self._slots = container.Slots or {}
        self._maxSlots = container.MaxSlots or 16
        self.InventoryUpdated:Fire(self._slots)
    end)
    print("[InventoryController] Started.")
end

function InventoryController:UseItem(slotIndex: number)
    task.spawn(function()
        local result = NetworkProtocol.ClientInvokeServer("InventoryRemotes", "PerformAction", {
            Action = "USE_ITEM",
            SourceSlot = slotIndex,
        })
        if result and not result.Success then
            warn("[InventoryController] Failed to use item:", result.Error)
        end
    end)
end

function InventoryController:GetSlots(): { [number]: { ItemId: string, Quantity: number } }
    return self._slots
end

return InventoryController
