function TriggerHook(hookType, ...)
    if not hookType or not Events[hookType] then return end

    local hooks = Events[hookType]?.hooks
    if not hooks then return end

    for i = 1, #hooks do
        -- TODO: Add further logic here, like filtering.
        if hooks[i] then
            local _, response = pcall(hooks[i].fn, ...)
            if response == false then
                return false
            end
        end
    end
end

function TriggerListener(listenerType, ...)
    if not listenerType or not Events[listenerType] then return end

    local listeners = Events[listenerType]?.listeners
    if not listeners then return end

    for i = 1, #listeners do
        -- TODO: Add further logic here, like filtering.
        if listeners[i] then
            pcall(listeners[i].fn, ...)
        end
    end
end

-- Hook Helpers

local function buildPlayerInventory(player)
    return {
        slots = Config.MaxSlots,
        maxweight = Config.MaxWeight,
        items = player?.PlayerData?.items or {},
    }
end

local function resolveInventoryContext(inventory, id, player)
    if not inventory or not id then return end
    local inventoryType = GetInventoryType(inventory)
    if inventoryType == 'player' then
        player = player or exports['qb-core']:GetPlayer(id)
        return inventoryType, buildPlayerInventory(player)
    end
    if inventoryType == 'drop' then return inventoryType, Drops[id] end

    return inventoryType, Inventories[id]
end

local function buildMovedData(fromInventory, toInventory, fromId, toId, fromSlot, toSlot, toAmount, fromPlayer, toPlayer)
    local fromType, fromInventoryData = resolveInventoryContext(fromInventory, fromId, fromPlayer)
    local toType, toInventoryData = resolveInventoryContext(toInventory, toId, toPlayer)
    return {
        fromType = fromType,
        toType = toType,
        fromInventory = fromInventoryData,
        toInventory = toInventoryData,
        fromId = fromId,
        toId = toId,
        fromSlot = fromSlot,
        toSlot = toSlot,
        amount = toAmount,
    }
end

local function buildItemDroppedData(source, player, coords, slot)
    return {
        source = source,
        sourceInventory = buildPlayerInventory(player),
        coords = coords,
        item = player.PlayerData.items[slot],
    }
end

local function buildUsedData(source, player, item)
    return {
        source = source,
        sourceInventory = buildPlayerInventory(player),
        item = item,
    }
end

local function buildItemAddedData(identifier, item, slot, amount, player, reason, resource)
    local inventoryType, inventoryData = resolveInventoryContext(identifier, identifier, player)
    return {
        toId = identifier,
        toInventory = inventoryData,
        toType = inventoryType,
        toSlot = slot,
        item = item,
        amount = amount,
        reason = reason,
        resource = resource,
    }
end

local function buildItemRemovedData(identifier, item, slot, amount, player, reason, resource)
    local inventoryType, inventoryData = resolveInventoryContext(identifier, identifier, player)
    return {
        fromId = identifier,
        fromInventory = inventoryData,
        fromType = inventoryType,
        fromSlot = slot,
        item = item,
        amount = amount,
        reason = reason,
        resource = resource,
    }
end

local function buildShopData(shopType, shopId, itemSlot, amount, toId)
    local shopData = RegisteredShops[shopId]
    local itemData = shopData.items[itemSlot]
    return {
        shopType = shopType,
        shop = shopData,
        toId = toId,
        item = itemData,
        amount = amount,
        totalPrice = itemData.price * amount,
    }
end

local function buildOpenedData(id, player, otherId, otherPlayer)
    local _, otherInventoryData = resolveInventoryContext(otherId, otherId, otherPlayer)
    return {
        source = id,
        sourceInventory = buildPlayerInventory(player),
        inventoryId = otherId,
        inventory = otherInventoryData,
    }
end

local function buildShopOpenedData(source, player, shopName)
    return {
        source = source,
        sourceInventory = buildPlayerInventory(player),
        shop = RegisteredShops[shopName],
    }
end

function GetInventoryType(identifier)
    if not identifier then return end
    if identifier == 'player' or type(identifier) == 'number' then return 'player' end
    if identifier:match('otherplayer%-') then return 'player' end
    if identifier:match('trunk%-') then return 'trunk' end
    if identifier:match('glovebox%-') then return 'glovebox' end
    if Inventories[identifier] then return 'inventory' end
    if Drops[identifier] then return 'drop' end
    local shopData = RegisteredShops[identifier]
    if shopData then return shopData.type or (shopData.name:gsub('%d+$', '')) end -- infer type from name if necessary
end

local hookBuilders = {
    ItemMoved = buildMovedData,
    ItemDropped = buildItemDroppedData,
    ItemUsed = buildUsedData,
    ItemBought = buildShopData,
    ItemAdded = buildItemAddedData,
    ItemRemoved = buildItemRemovedData,
    InventoryOpened = buildOpenedData,
    ShopOpened = buildShopOpenedData,
}

function buildHookData(hookType, ...)
    local builder = hookBuilders[hookType]
    if builder then return builder(...) end
end