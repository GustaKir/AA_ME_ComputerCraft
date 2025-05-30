-- AA_ME Storage System
-- Inventory Management Module

local log = require("aame.modules.lib.log")

-- Helper function to check if a table contains a value
local function tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new()
    local self = setmetatable({}, Inventory)
    self.inventories = {}
    return self
end

function Inventory:startScanning()
    while true do
        self:scanInventories()
        os.sleep(1)
    end
end

function Inventory:scanInventories()
    -- Scan for connected inventories
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    local found = {}
    
    -- First check direct sides
    for _, side in ipairs(sides) do
        if peripheral.isPresent(side) then
            local pType = peripheral.getType(side)
            
            -- Check for inventory capabilities
            local p = peripheral.wrap(side)
            
            -- Check if it's a standard inventory
            if pType == "inventory" or 
               pType == "minecraft:chest" or
               pType == "minecraft:barrel" or
               pType == "minecraft:shulker_box" or
               pType == "minecraft:hopper" or
               pType == "minecraft:dispenser" or
               pType == "minecraft:dropper" or
               (pType and string.find(pType, "chest")) or
               (pType and string.find(pType, "storage")) then
                found[side] = {
                    type = pType,
                    side = side,
                    peripheral = p
                }
            -- Check if it has list() method (inventory API)
            elseif p and _G.type(p.list) == "function" then
                found[side] = {
                    type = pType,
                    side = side,
                    peripheral = p
                }
            -- Check if it has getItemDetail() method (another inventory API)
            elseif p and _G.type(p.getItemDetail) == "function" then
                found[side] = {
                    type = pType,
                    side = side,
                    peripheral = p
                }
            end
        end
    end
    
    -- Now check for networked peripherals
    local allPeripherals = peripheral.getNames()
    for _, name in ipairs(allPeripherals) do
        -- Skip direct sides we already checked
        if not found[name] and not tableContains(sides, name) then
            local pType = peripheral.getType(name)
            
            -- Check if it's a standard inventory
            local p = peripheral.wrap(name)
            
            -- Check if it's a standard inventory
            if pType == "inventory" or 
               pType == "minecraft:chest" or
               pType == "minecraft:barrel" or
               pType == "minecraft:shulker_box" or
               pType == "minecraft:hopper" or
               pType == "minecraft:dispenser" or
               pType == "minecraft:dropper" or
               (pType and string.find(pType, "chest")) or
               (pType and string.find(pType, "storage")) then
                found[name] = {
                    type = pType,
                    side = name,
                    peripheral = p
                }
            -- Check if it has list() method (inventory API)
            elseif p and _G.type(p.list) == "function" then
                found[name] = {
                    type = pType,
                    side = name,
                    peripheral = p
                }
            -- Check if it has getItemDetail() method (another inventory API)
            elseif p and _G.type(p.getItemDetail) == "function" then
                found[name] = {
                    type = pType,
                    side = name,
                    peripheral = p
                }
            end
        end
    end
    
    self.inventories = found
end

function Inventory:getItems()
    local items = {}
    local invCount = 0
    
    for name, inv in pairs(self.inventories) do
        invCount = invCount + 1
        
        -- Make sure we have a peripheral
        if not inv.peripheral then
            log.error("Missing peripheral for " .. name)
            goto continue
        end
        
        -- Try standard list() method first
        if _G.type(inv.peripheral.list) == "function" then
            local success, list = pcall(function() return inv.peripheral.list() end)
            if success and _G.type(list) == "table" then
                for slot, item in pairs(list) do
                    if item and _G.type(item) == "table" and item.name then
                        local name = item.name
                        if not items[name] then
                            items[name] = {count = 0}
                        end
                        items[name].count = items[name].count + item.count
                    end
                end
            else
                log.error("Failed to list items in " .. name)
            end
        -- Try alternative getItems() method
        elseif _G.type(inv.peripheral.getItems) == "function" then
            local success, invItems = pcall(function() return inv.peripheral.getItems() end)
            if success and _G.type(invItems) == "table" then
                for _, item in pairs(invItems) do
                    if item and _G.type(item) == "table" and item.name then
                        local name = item.name
                        if not items[name] then
                            items[name] = {count = 0}
                        end
                        items[name].count = items[name].count + item.count
                    end
                end
            else
                log.error("Failed to get items in " .. name)
            end
        -- Try alternative getItemDetail() method with size() for slots
        elseif _G.type(inv.peripheral.getItemDetail) == "function" and _G.type(inv.peripheral.size) == "function" then
            local success, size = pcall(function() return inv.peripheral.size() end)
            if not success then
                log.error("Failed to get size of " .. name)
                goto continue
            end
            
            for slot = 1, size do
                local success, item = pcall(function() return inv.peripheral.getItemDetail(slot) end)
                if success and item and _G.type(item) == "table" and item.name then
                    local name = item.name
                    if not items[name] then
                        items[name] = {count = 0}
                    end
                    items[name].count = items[name].count + item.count
                end
            end
        else
            log.error("No compatible inventory API found for " .. name)
        end
        
        ::continue::
    end
    
    return items
end

function Inventory:extractItem(itemName, count, toInventory, toSlot)
    local extracted = 0
    
    -- Find the item in connected inventories
    for _, inv in pairs(self.inventories) do
        local list = inv.peripheral.list()
        for slot, item in pairs(list) do
            if item.name == itemName then
                local toExtract = math.min(count - extracted, item.count)
                if toExtract > 0 then
                    -- Try to push items to the target inventory
                    local pushed = inv.peripheral.pushItems(toInventory, slot, toExtract, toSlot)
                    extracted = extracted + pushed
                    
                    if extracted >= count then
                        return extracted
                    end
                end
            end
        end
    end
    
    return extracted
end

return Inventory 