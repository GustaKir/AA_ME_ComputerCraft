-- AA_ME Storage System Installer (Part 2)
local files = {
    ["disk/AA_ME/core/inventory.lua"] = [[-- AA_ME Storage System
-- Core Inventory Management

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new()
    local self = setmetatable({}, Inventory)
    self.inventories = {}
    self.items = {}
    self.onItemsChanged = nil
    return self
end

function Inventory:startScanning()
    while true do
        self:scanInventories()
        os.sleep(1)
    end
end

function Inventory:scanInventories()
    for name, inv in pairs(self.inventories) do
        if peripheral.isPresent(name) then
            local contents = inv.peripheral.list()
            if contents then
                self:updateInventoryContents(name, contents)
            end
        else
            self:removeInventory(name)
        end
    end
end

function Inventory:updateInventoryContents(invName, contents)
    local inv = self.inventories[invName]
    if not inv then return end
    
    local changes = {}
    
    -- Check for removed or changed items
    for slot, oldItem in pairs(inv.slots or {}) do
        local newItem = contents[slot]
        if not newItem or newItem.name ~= oldItem.name or newItem.count ~= oldItem.count then
            self:updateItemCount(oldItem.name, invName, slot, 0)
            changes[oldItem.name] = true
        end
    end
    
    -- Check for new or changed items
    for slot, newItem in pairs(contents) do
        local oldItem = inv.slots and inv.slots[slot]
        if not oldItem or newItem.name ~= oldItem.name or newItem.count ~= oldItem.count then
            self:updateItemCount(newItem.name, invName, slot, newItem.count)
            changes[newItem.name] = true
        end
    end
    
    -- Update inventory state
    inv.slots = contents
    inv.lastUpdate = os.epoch("utc")
    
    -- Notify of changes
    if next(changes) and self.onItemsChanged then
        self.onItemsChanged(changes)
    end
end

function Inventory:updateItemCount(itemName, invName, slot, count)
    local item = self.items[itemName] or {name = itemName, count = 0, locations = {}}
    local oldCount = item.locations[invName] and item.locations[invName][slot] or 0
    
    if count > 0 then
        -- Add or update item location
        item.locations[invName] = item.locations[invName] or {}
        item.locations[invName][slot] = count
    else
        -- Remove item location
        if item.locations[invName] then
            item.locations[invName][slot] = nil
            if not next(item.locations[invName]) then
                item.locations[invName] = nil
            end
        end
    end
    
    -- Update total count
    item.count = item.count - oldCount + count
    
    -- Update or remove item from tracking
    if item.count > 0 then
        self.items[itemName] = item
    else
        self.items[itemName] = nil
    end
end

function Inventory:addInventory(name)
    if self.inventories[name] then return end
    
    local p = peripheral.wrap(name)
    if not p or not peripheral.hasType(p, "inventory") then
        return false, "Not an inventory peripheral"
    end
    
    -- Add inventory
    self.inventories[name] = {
        peripheral = p,
        slots = {},
        lastUpdate = 0
    }
    
    -- Scan initial contents
    local contents = p.list()
    if contents then
        self:updateInventoryContents(name, contents)
    end
    
    return true
end

function Inventory:removeInventory(name)
    local inv = self.inventories[name]
    if not inv then return end
    
    -- Remove all items from this inventory
    for itemName, item in pairs(self.items) do
        if item.locations[name] then
            for slot, count in pairs(item.locations[name]) do
                self:updateItemCount(itemName, name, slot, 0)
            end
        end
    end
    
    -- Remove inventory
    self.inventories[name] = nil
end

function Inventory:findItem(itemName, count)
    local item = self.items[itemName]
    if not item then return nil end
    
    local locations = {}
    local foundCount = 0
    
    -- Find all locations of the item
    for invName, slots in pairs(item.locations) do
        if peripheral.isPresent(invName) then
            for slot, slotCount in pairs(slots) do
                table.insert(locations, {
                    inventory = invName,
                    slot = slot,
                    count = slotCount
                })
                foundCount = foundCount + slotCount
                if count and foundCount >= count then
                    break
                end
            end
        end
    end
    
    return locations, foundCount
end

function Inventory:extractItem(itemName, count, toInventory, toSlot)
    if type(itemName) ~= "string" then error("itemName must be a string", 2) end
    if type(count) ~= "number" then error("count must be a number", 2) end
    if type(toInventory) ~= "string" then error("toInventory must be a string", 2) end
    
    -- Find item locations
    local locations = self:findItem(itemName, count)
    if not locations or #locations == 0 then
        return 0, "Item not found"
    end
    
    -- Extract items
    local extracted = 0
    for _, loc in ipairs(locations) do
        if extracted >= count then break end
        
        local toMove = math.min(loc.count, count - extracted)
        local moved = self.inventories[loc.inventory].peripheral.pushItems(
            toInventory,
            loc.slot,
            toMove,
            toSlot
        )
        
        if moved and moved > 0 then
            extracted = extracted + moved
        end
    end
    
    return extracted
end

function Inventory:getItems()
    return self.items
end

return Inventory]],

    ["disk/AA_ME/lib/log.lua"] = [[-- AA_ME Storage System
-- Logging System

local LOG_LEVELS = {DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4}
local currentLevel = LOG_LEVELS.INFO
local logFile = nil

local function init()
    if not fs.exists("disk/AA_ME/logs") then
        fs.makeDir("disk/AA_ME/logs")
    end
    local filename = string.format("disk/AA_ME/logs/%s.log", os.date("%Y-%m-%d"))
    logFile = fs.open(filename, "a")
end

local function log(level, message, ...)
    if not logFile then init() end
    
    if LOG_LEVELS[level] >= currentLevel then
        local timestamp = os.date("%H:%M:%S")
        local formatted = string.format(message, ...)
        local entry = string.format("[%s] [%s] %s", timestamp, level, formatted)
        
        -- Write to log file
        if logFile then
            logFile.writeLine(entry)
            logFile.flush()
        end
        
        -- Print errors to terminal
        if level == "ERROR" then
            term.setTextColor(colors.red)
            print(entry)
            term.setTextColor(colors.white)
        end
    end
end

local function setLevel(level)
    if LOG_LEVELS[level] then
        currentLevel = LOG_LEVELS[level]
    end
end

local function close()
    if logFile then
        logFile.close()
        logFile = nil
    end
end

return {
    debug = function(msg, ...) log("DEBUG", msg, ...) end,
    info = function(msg, ...) log("INFO", msg, ...) end,
    warn = function(msg, ...) log("WARN", msg, ...) end,
    error = function(msg, ...) log("ERROR", msg, ...) end,
    setLevel = setLevel,
    close = close
}]]
}

-- Create files
print("Installing AA_ME Storage System (Part 2)...")
print("Creating files...")

local function createFile(path, content)
    -- Ensure directory exists
    local dir = fs.getDir(path)
    if not fs.exists(dir) then
        fs.makeDir(dir)
    end
    
    -- Write file
    local file = fs.open(path, "w")
    file.write(content)
    file.close()
end

for path, content in pairs(files) do
    createFile(path, content)
    print("Created: " .. path)
end

print("\nPart 2 complete!")
print("Run 'installer_part3' to continue installation...") 