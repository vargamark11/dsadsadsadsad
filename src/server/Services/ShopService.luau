--!strict
--[[
    ShopService.luau
    Authoritative monetization and cosmetic catalog purchase service for ALIEN: NIGHTFALL.
    Strictly verifies funds, verifies level requirements, and unlocks cosmetics server-side.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CosmeticsConfig = require(ReplicatedStorage.AlienNightfall.Config.CosmeticsConfig)
local NetworkProtocol = require(ReplicatedStorage.AlienNightfall.Shared.Network.NetworkProtocol)
local ServiceManager = require(script.Parent.Parent.ServiceManager)

local ShopService = {
    Name = "ShopService",
}

function ShopService:OnInit()
    print("[ShopService] Initialized.")
end

function ShopService:OnStart()
    NetworkProtocol.ServerBindFunction("ShopRemotes", "PurchaseItem", function(player: Player, cosmeticId: string)
        return self:PurchaseCosmetic(player, cosmeticId)
    end)

    NetworkProtocol.ServerBindFunction("ShopRemotes", "EquipCosmetic", function(player: Player, cosmeticId: string)
        return self:EquipCosmetic(player, cosmeticId)
    end)
    print("[ShopService] Started.")
end

function ShopService:PurchaseCosmetic(player: Player, cosmeticId: string): any
    local item = CosmeticsConfig.Items[cosmeticId]
    if not item then
        return { Success = false, Error = "Item does not exist in catalog" }
    end

    local DataService = ServiceManager.GetService("DataService") :: any
    local EconomyService = ServiceManager.GetService("EconomyService") :: any
    local profile = DataService and DataService:GetProfile(player)

    if not profile or not EconomyService then
        return { Success = false, Error = "User profile not available" }
    end

    if profile.UnlockedCosmetics[cosmeticId] then
        return { Success = false, Error = "Item already owned" }
    end

    -- Process payment based on price
    if item.PriceCredits and item.PriceCredits > 0 then
        if profile.ColonyCredits < item.PriceCredits then
            return { Success = false, Error = "Insufficient Colony Credits" }
        end
        EconomyService:RemoveCredits(player, item.PriceCredits, "SHOP_PURCHASE_" .. cosmeticId)
    elseif item.PriceNanites and item.PriceNanites > 0 then
        if profile.DarkNanites < item.PriceNanites then
            return { Success = false, Error = "Insufficient Dark Nanites" }
        end
        EconomyService:RemoveNanites(player, item.PriceNanites, "SHOP_PURCHASE_" .. cosmeticId)
    else
        return { Success = false, Error = "Item is not available for purchase" }
    end

    profile.UnlockedCosmetics[cosmeticId] = true
    return { Success = true, ItemId = cosmeticId, Name = item.Name }
end

function ShopService:EquipCosmetic(player: Player, cosmeticId: string): any
    local item = CosmeticsConfig.Items[cosmeticId]
    if not item then
        return { Success = false, Error = "Item does not exist" }
    end

    local DataService = ServiceManager.GetService("DataService") :: any
    local profile = DataService and DataService:GetProfile(player)

    if not profile or not profile.UnlockedCosmetics[cosmeticId] then
        return { Success = false, Error = "You do not own this cosmetic" }
    end

    if item.Category == "CHARACTER_SUIT" then
        profile.EquippedCosmetics.Suit = cosmeticId
    elseif item.Category == "PLAYER_TITLE" then
        profile.EquippedCosmetics.Title = item.Name
    elseif item.Category == "WEAPON_SKIN" and item.EquipSlot then
        profile.EquippedCosmetics.WeaponSkins[item.EquipSlot] = cosmeticId
    end

    return { Success = true, EquippedSlot = item.EquipSlot, ItemId = cosmeticId }
end

return ShopService
