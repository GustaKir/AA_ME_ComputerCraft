-- AA_ME Storage System Installer
-- This script will install the complete storage system

-- First, ensure we're in the root directory where modules should be installed
if not fs.exists("disk") then
    fs.makeDir("disk")
end

local files = {
    ["disk/AA_ME/init.lua"] = [[-- AA_ME Storage System
local StorageSystem = {}
StorageSystem.__index = StorageSystem

function StorageSystem.new()
    local self = setmetatable({}, StorageSystem)
    self.version = "1.0.0"
    
    -- Initialize core components
    self.inventory = require("disk.AA_ME.core.inventory").new()
    self.crafting = require("disk.AA_ME.core.crafting").new(self)
    self.interface = require("disk.AA_ME.interface.main").new(self)
    self.config = require("disk.AA_ME.core.config").load()
    self.peripheralManager = require("disk.AA_ME.peripherals.manager").new(self)
    
    return self
end

function StorageSystem:startBackgroundTasks()
    parallel.waitForAll(
        function() self.inventory:startScanning() end,
        function() self.crafting:startMonitoring() end,
        function() self.peripheralManager:startMonitoring() end
    )
end

function StorageSystem:start()
    -- Start background tasks in parallel with interface
    parallel.waitForAll(
        function() self:startBackgroundTasks() end,
        function() self.interface:start() end
    )
end

return StorageSystem]],

    ["disk/startup.lua"] = [[-- AA_ME Storage System Startup
local function printHeader()
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.yellow)
    print("=========================")
    print("   AA_ME Storage System  ")
    print("=========================")
    print()
    term.setTextColor(colors.white)
end

local function main()
    printHeader()
    print("Initializing storage system...")
    
    -- Load system
    local StorageSystem = require("disk.AA_ME.init")
    local system = StorageSystem.new()
    
    -- Start system
    system:start()
end

local ok, err = pcall(main)
if not ok then
    term.setTextColor(colors.red)
    print("\nError starting storage system:")
    print(err)
    print("\nPress any key to exit...")
    term.setTextColor(colors.white)
    os.pullEvent("key")
end]],

    ["disk/AA_ME/data/recipes.json"] = [[{
    "minecraft:iron_ingot": {
        "output": {"item": "minecraft:iron_ingot", "count": 1},
        "inputs": [
            {"item": "minecraft:iron_ore", "count": 1}
        ],
        "method": "create_crushing"
    }
}]],

    ["disk/AA_ME/config.json"] = [[{
    "inventories": {
        "rescan_interval": 1,
        "ignored_names": {},
        "ignored_types": ["turtle"]
    },
    "interface": {
        "output_chest": "minecraft:chest_0",
        "input_chest": "minecraft:chest_1"
    },
    "create": {
        "interfaces": {}
    },
    "crafting": {
        "recipes_file": "disk/AA_ME/data/recipes.json"
    }
}]]
}

-- Create base directories
print("Installing AA_ME Storage System...")
print("Creating directory structure...")

local dirs = {
    "disk/AA_ME",
    "disk/AA_ME/core",
    "disk/AA_ME/interface",
    "disk/AA_ME/peripherals",
    "disk/AA_ME/lib",
    "disk/AA_ME/data",
    "disk/AA_ME/logs"
}

for _, dir in ipairs(dirs) do
    if not fs.exists(dir) then
        fs.makeDir(dir)
        print("Created directory: " .. dir)
    end
end

-- Create files
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

print("\nCreating files...")
for path, content in pairs(files) do
    createFile(path, content)
    print("Created: " .. path)
end

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

-- AA_ME Storage System Installer (Part 3)
local files = {
    ["disk/AA_ME/core/crafting.lua"] = [[-- AA_ME Storage System
-- Core Crafting System

local log = require("disk.AA_ME.lib.log")

local Crafting = {}
Crafting.__index = Crafting

function Crafting.new(system)
    if type(system) ~= "table" then error("system must be a table", 2) end
    
    local self = setmetatable({}, Crafting)
    self.system = system
    self.recipes = {}
    self.tasks = {}
    self.createInterfaces = {}
    self:loadRecipes()
    return self
end

function Crafting:loadRecipes()
    local recipesFile = fs.open("disk/AA_ME/data/recipes.json", "r")
    if not recipesFile then
        log.warn("No recipes file found")
        return
    end
    
    local content = recipesFile.readAll()
    recipesFile.close()
    
    local ok, recipes = pcall(textutils.unserializeJSON, content)
    if not ok or not recipes then
        log.error("Failed to parse recipes file")
        return
    end
    
    self.recipes = recipes
end

function Crafting:startMonitoring()
    while true do
        self:updateTasks()
        os.sleep(1)
    end
end

function Crafting:updateTasks()
    for id, task in pairs(self.tasks) do
        if task.status == "pending" then
            self:processTask(id, task)
        elseif task.status == "crafting" then
            self:monitorTask(id, task)
        end
    end
end

function Crafting:processTask(id, task)
    -- Check if we have all required items
    local missingItems = {}
    for _, req in ipairs(task.requirements) do
        local available = self.system.inventory:findItem(req.item)
        if not available or available.count < req.count then
            table.insert(missingItems, {
                item = req.item,
                needed = req.count,
                available = available and available.count or 0
            })
        end
    end
    
    if #missingItems > 0 then
        -- Try to craft missing items
        for _, missing in ipairs(missingItems) do
            if self.recipes[missing.item] then
                local subTaskId = self:craftItem(
                    missing.item,
                    missing.needed - missing.available
                )
                if subTaskId then
                    task.dependencies = task.dependencies or {}
                    task.dependencies[subTaskId] = true
                end
            end
        end
        return
    end
    
    -- All items available, start crafting
    local interface = self:findCreateInterface(task.recipe.method)
    if not interface then
        task.status = "failed"
        task.error = "No interface available for method: " .. task.recipe.method
        return
    end
    
    -- Move items to crafter
    for _, req in ipairs(task.requirements) do
        local moved = self.system.inventory:extractItem(
            req.item,
            req.count,
            interface.name
        )
        if moved < req.count then
            task.status = "failed"
            task.error = "Failed to move items to crafter"
            return
        end
    end
    
    -- Start crafting
    local ok, err = interface:craft(task.recipe, task.count)
    if not ok then
        task.status = "failed"
        task.error = err
        return
    end
    
    task.status = "crafting"
    task.interface = interface.name
end

function Crafting:monitorTask(id, task)
    local interface = self.createInterfaces[task.interface]
    if not interface then
        task.status = "failed"
        task.error = "Lost connection to crafter"
        return
    end
    
    local status = interface:getStatus()
    if status.done then
        task.status = "completed"
    elseif status.error then
        task.status = "failed"
        task.error = status.error
    else
        task.progress = status.progress
    end
end

function Crafting:craftItem(itemName, count)
    local recipe = self.recipes[itemName]
    if not recipe then
        return nil, "No recipe found"
    end
    
    -- Generate requirements
    local requirements = {}
    for _, input in ipairs(recipe.inputs) do
        table.insert(requirements, {
            item = input.item,
            count = input.count * count
        })
    end
    
    -- Create task
    local id = tostring(os.epoch("utc"))
    self.tasks[id] = {
        recipe = recipe,
        count = count,
        requirements = requirements,
        status = "pending",
        created = os.epoch("utc")
    }
    
    return id
end

function Crafting:registerCreateInterface(name, interface)
    self.createInterfaces[name] = interface
end

function Crafting:unregisterCreateInterface(name)
    -- Remove the interface
    self.createInterfaces[name] = nil
    
    -- Update any tasks using this interface
    for id, task in pairs(self.tasks) do
        if task.status == "crafting" and task.interface == name then
            task.status = "failed"
            task.error = "Lost connection to crafter"
        end
    end
end

function Crafting:findCreateInterface(method)
    for _, interface in pairs(self.createInterfaces) do
        if interface:supportsMethod(method) then
            return interface
        end
    end
    return nil
end

return Crafting]],

    ["disk/AA_ME/peripherals/create.lua"] = [[-- AA_ME Storage System
-- Create Mod Interface

local log = require("disk.AA_ME.lib.log")

local CreateInterface = {}
CreateInterface.__index = CreateInterface

function CreateInterface.new(name, peripheral_name)
    if type(name) ~= "string" then error("name must be a string", 2) end
    if type(peripheral_name) ~= "string" then error("peripheral_name must be a string", 2) end
    
    local self = setmetatable({}, CreateInterface)
    self.name = name
    self.peripheral = peripheral.wrap(peripheral_name)
    
    if not self.peripheral then
        error("Could not find Create peripheral: " .. peripheral_name)
    end
    
    -- Register supported crafting methods
    self.methods = {
        create_mechanical = self.mechanicalCraft,
        create_mixing = self.mixing,
        create_pressing = self.pressing,
        create_crushing = self.crushing,
        create_compacting = self.compacting,
        create_haunting = self.haunting,
        create_milling = self.milling,
        create_deploying = self.deploying,
        create_spout_filling = self.spoutFilling
    }
    
    return self
end

function CreateInterface:mechanicalCraft(recipe, count)
    local crafter = self.peripheral
    if not crafter.isRunning() then
        return false, "Crafter is not running"
    end
    local ok, err = crafter.craft(count)
    if not ok then
        return false, err or "Crafting failed"
    end
    return true
end

function CreateInterface:mixing(recipe, count)
    local mixer = self.peripheral
    if not mixer.isRunning() then
        return false, "Mixer is not running"
    end
    local ok, err = mixer.mix(count)
    if not ok then
        return false, err or "Mixing failed"
    end
    return true
end

function CreateInterface:pressing(recipe, count)
    local press = self.peripheral
    if not press.isRunning() then
        return false, "Press is not running"
    end
    local ok, err = press.press(count)
    if not ok then
        return false, err or "Pressing failed"
    end
    return true
end

function CreateInterface:crushing(recipe, count)
    local crusher = self.peripheral
    if not crusher.isRunning() then
        return false, "Crusher is not running"
    end
    local ok, err = crusher.crush(count)
    if not ok then
        return false, err or "Crushing failed"
    end
    return true
end

function CreateInterface:compacting(recipe, count)
    local compactor = self.peripheral
    if not compactor.isRunning() then
        return false, "Compactor is not running"
    end
    local ok, err = compactor.compact(count)
    if not ok then
        return false, err or "Compacting failed"
    end
    return true
end

function CreateInterface:haunting(recipe, count)
    local haunter = self.peripheral
    if not haunter.isRunning() then
        return false, "Haunter is not running"
    end
    local ok, err = haunter.haunt(count)
    if not ok then
        return false, err or "Haunting failed"
    end
    return true
end

function CreateInterface:milling(recipe, count)
    local mill = self.peripheral
    if not mill.isRunning() then
        return false, "Mill is not running"
    end
    local ok, err = mill.mill(count)
    if not ok then
        return false, err or "Milling failed"
    end
    return true
end

function CreateInterface:deploying(recipe, count)
    local deployer = self.peripheral
    if not deployer.isRunning() then
        return false, "Deployer is not running"
    end
    local ok, err = deployer.deploy(count)
    if not ok then
        return false, err or "Deploying failed"
    end
    return true
end

function CreateInterface:spoutFilling(recipe, count)
    local spout = self.peripheral
    if not spout.isRunning() then
        return false, "Spout is not running"
    end
    local ok, err = spout.fill(count)
    if not ok then
        return false, err or "Filling failed"
    end
    return true
end

function CreateInterface:supportsMethod(method)
    return self.methods[method] ~= nil
end

function CreateInterface:craft(recipe, count)
    local method = self.methods[recipe.method]
    if not method then
        return false, "Unsupported crafting method: " .. recipe.method
    end
    return method(self, recipe, count)
end

function CreateInterface:getStatus()
    local p = self.peripheral
    if not p then
        return {error = "Lost connection to peripheral"}
    end
    
    local status = {
        busy = p.isRunning(),
        progress = p.getProgress and p.getProgress() or 0,
        error = nil,
        done = false
    }
    
    if not status.busy and status.progress >= 1 then
        status.done = true
    end
    
    return status
end

return CreateInterface]]
}

-- Create files
print("Installing AA_ME Storage System (Part 3)...")
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

-- AA_ME Storage System Installer (Part 4)
local files = {
    ["disk/AA_ME/interface/main.lua"] = [[-- AA_ME Storage System
-- Main Interface

local log = require("disk.AA_ME.lib.log")

local Interface = {}
Interface.__index = Interface

function Interface.new(system)
    if type(system) ~= "table" then error("system must be a table", 2) end
    
    local self = setmetatable({}, Interface)
    self.system = system
    self.monitor = nil
    self.term = term.current()
    self.width, self.height = self.term.getSize()
    self.selectedTab = "inventory"
    self.scroll = 0
    self.searchTerm = ""
    self.selectedItem = nil
    self.craftAmount = 1
    return self
end

function Interface:setMonitor(name)
    if name then
        self.monitor = peripheral.wrap(name)
        if self.monitor then
            self.term = self.monitor
            self.width, self.height = self.term.getSize()
            self.monitor.setTextScale(0.5)
        else
            log.error("Failed to connect to monitor: " .. name)
        end
    else
        self.term = term.current()
        self.width, self.height = self.term.getSize()
    end
end

function Interface:start()
    while true do
        self:draw()
        local event = {os.pullEvent()}
        self:handleEvent(table.unpack(event))
    end
end

function Interface:draw()
    self.term.clear()
    self.term.setCursorPos(1, 1)
    
    -- Draw header
    self:drawHeader()
    
    -- Draw content based on selected tab
    if self.selectedTab == "inventory" then
        self:drawInventory()
    elseif self.selectedTab == "crafting" then
        self:drawCrafting()
    elseif self.selectedTab == "tasks" then
        self:drawTasks()
    end
    
    -- Draw footer
    self:drawFooter()
end

function Interface:drawHeader()
    local tabs = {
        {name = "inventory", label = "Inventory"},
        {name = "crafting", label = "Crafting"},
        {name = "tasks", label = "Tasks"}
    }
    
    for i, tab in ipairs(tabs) do
        local x = (i - 1) * 12 + 1
        local selected = tab.name == self.selectedTab
        
        self.term.setCursorPos(x, 1)
        if selected then
            self.term.setBackgroundColor(colors.blue)
            self.term.setTextColor(colors.white)
        else
            self.term.setBackgroundColor(colors.gray)
            self.term.setTextColor(colors.lightGray)
        end
        
        self.term.write(string.format("%-11s", tab.label))
    end
    
    -- Reset colors
    self.term.setBackgroundColor(colors.black)
    self.term.setTextColor(colors.white)
    
    -- Draw search bar
    self.term.setCursorPos(1, 3)
    self.term.write("Search: " .. self.searchTerm .. "_")
end

function Interface:drawInventory()
    local items = self.system.inventory:getItems()
    local filtered = {}
    
    -- Filter items
    for _, item in pairs(items) do
        if self.searchTerm == "" or string.find(string.lower(item.name), string.lower(self.searchTerm)) then
            table.insert(filtered, item)
        end
    end
    
    -- Sort items
    table.sort(filtered, function(a, b)
        return a.name < b.name
    end)
    
    -- Draw items
    local y = 5
    for i = 1 + self.scroll, math.min(#filtered, self.scroll + self.height - 7) do
        local item = filtered[i]
        self.term.setCursorPos(1, y)
        
        if item == self.selectedItem then
            self.term.setBackgroundColor(colors.blue)
            self.term.setTextColor(colors.white)
        end
        
        self.term.write(string.format("%-30s %d", item.name, item.count))
        
        -- Reset colors
        self.term.setBackgroundColor(colors.black)
        self.term.setTextColor(colors.white)
        
        y = y + 1
    end
end

function Interface:drawCrafting()
    if not self.selectedItem then
        self.term.setCursorPos(1, 5)
        self.term.write("Select an item to craft")
        return
    end
    
    local recipe = self.system.crafting.recipes[self.selectedItem.name]
    if not recipe then
        self.term.setCursorPos(1, 5)
        self.term.write("No recipe available for " .. self.selectedItem.name)
        return
    end
    
    -- Draw recipe info
    self.term.setCursorPos(1, 5)
    self.term.write("Recipe for: " .. self.selectedItem.name)
    
    self.term.setCursorPos(1, 7)
    self.term.write("Inputs:")
    local y = 8
    for _, input in ipairs(recipe.inputs) do
        self.term.setCursorPos(3, y)
        self.term.write(string.format("%s x%d", input.item, input.count * self.craftAmount))
        y = y + 1
    end
    
    -- Draw crafting controls
    self.term.setCursorPos(1, y + 1)
    self.term.write("Amount: " .. self.craftAmount)
    self.term.setCursorPos(1, y + 2)
    self.term.write("[+/-] Adjust amount")
    self.term.setCursorPos(1, y + 3)
    self.term.write("[Enter] Start crafting")
end

function Interface:drawTasks()
    local tasks = self.system.crafting.tasks
    local y = 5
    
    for id, task in pairs(tasks) do
        if y >= self.height - 2 then break end
        
        self.term.setCursorPos(1, y)
        self.term.write(string.format(
            "%-20s %d x%d %s",
            task.recipe.output.item,
            task.count,
            task.recipe.output.count,
            task.status
        ))
        
        if task.error then
            y = y + 1
            self.term.setCursorPos(3, y)
            self.term.setTextColor(colors.red)
            self.term.write("Error: " .. task.error)
            self.term.setTextColor(colors.white)
        end
        
        if task.progress then
            y = y + 1
            self.term.setCursorPos(3, y)
            self.term.write(string.format("Progress: %.1f%%", task.progress * 100))
        end
        
        y = y + 2
    end
end

function Interface:drawFooter()
    self.term.setCursorPos(1, self.height)
    self.term.write("[Tab] Switch view | [Arrow keys] Navigate | [Esc] Exit")
end

function Interface:handleEvent(event, ...)
    if event == "key" then
        local key = ...
        if key == keys.tab then
            local tabs = {"inventory", "crafting", "tasks"}
            for i, tab in ipairs(tabs) do
                if tab == self.selectedTab then
                    self.selectedTab = tabs[i % #tabs + 1]
                    break
                end
            end
        elseif key == keys.up then
            if self.scroll > 0 then
                self.scroll = self.scroll - 1
            end
        elseif key == keys.down then
            self.scroll = self.scroll + 1
        elseif key == keys.enter and self.selectedTab == "crafting" then
            if self.selectedItem and self.craftAmount > 0 then
                local id = self.system.crafting:craftItem(
                    self.selectedItem.name,
                    self.craftAmount
                )
                if id then
                    self.selectedTab = "tasks"
                end
            end
        elseif key == keys.equals or key == keys.plus then
            self.craftAmount = self.craftAmount + 1
        elseif key == keys.minus then
            self.craftAmount = math.max(1, self.craftAmount - 1)
        end
    elseif event == "char" then
        local char = ...
        if self.selectedTab == "inventory" then
            self.searchTerm = self.searchTerm .. char
        end
    elseif event == "key_up" then
        local key = ...
        if key == keys.backspace then
            self.searchTerm = string.sub(self.searchTerm, 1, -2)
        end
    end
end

return Interface]],

    ["disk/AA_ME/core/config.lua"] = [[-- AA_ME Storage System
-- Configuration Management

local defaultConfig = {
    inventories = {
        rescan_interval = 1,
        ignored_names = {},
        ignored_types = {"turtle"},
    },
    interface = {
        output_chest = "",
        input_chest = "",
    },
    create = {
        interfaces = {},
    },
    crafting = {
        recipes_file = "disk/AA_ME/data/recipes.json",
    },
}

local function load()
    local configFile = fs.open("disk/AA_ME/config.json", "r")
    local config = defaultConfig
    if configFile then
        local content = configFile.readAll()
        configFile.close()
        local ok, loaded = pcall(textutils.unserializeJSON, content)
        if ok and loaded then
            for k, v in pairs(loaded) do
                if type(v) == "table" then
                    config[k] = config[k] or {}
                    for k2, v2 in pairs(v) do
                        config[k][k2] = v2
                    end
                else
                    config[k] = v
                end
            end
        end
    end
    return config
end

local function save(config)
    if not fs.exists("disk/AA_ME") then fs.makeDir("disk/AA_ME") end
    local configFile = fs.open("disk/AA_ME/config.json", "w")
    if configFile then
        configFile.write(textutils.serializeJSON(config))
        configFile.close()
        return true
    end
    return false
end

return {load = load, save = save, default = defaultConfig}]]
}

-- Create files
print("Installing AA_ME Storage System (Part 4)...")
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

print("\nInstallation complete!")
print("\nTo configure the system:")
print("1. Edit disk/AA_ME/config.json")
print("2. Edit disk/AA_ME/data/recipes.json")
print("\nTo start the system:")
print("- Run 'startup'")
print("- Or reboot the computer") 