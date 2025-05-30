-- Create required directories
local function ensureDirectory(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

ensureDirectory("aame")
ensureDirectory("aame/logs")
ensureDirectory("aame/modules")
ensureDirectory("aame/modules/interface")
ensureDirectory("aame/modules/lib")

-- Write all files
local function writeFile(path, content)
    local file = fs.open(path, "w")
    file.write(content)
    file.close()
    print("Created: " .. path)
end

-- Write logging module
writeFile("aame/modules/lib/log.lua", [[
local log = {}

local LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

local LOG_COLORS = {
    DEBUG = colors.lightGray,
    INFO = colors.white,
    WARN = colors.yellow,
    ERROR = colors.red
}

log.level = LOG_LEVELS.INFO
log.file = nil
log.initialized = false

local function ensureLogDirectory()
    if not fs.exists("aame/logs") then
        fs.makeDir("aame/logs")
    end
end

local function openLogFile()
    ensureLogDirectory()
    local filename = string.format("aame/logs/%s.log", os.date("%Y-%m-%d"))
    return fs.open(filename, "a")
end

local function writeLog(level, message)
    if not log.initialized then
        log.file = openLogFile()
        log.initialized = true
    end
    
    if LOG_LEVELS[level] >= log.level then
        local timestamp = os.date("%H:%M:%S")
        local logLine = string.format("[%s] [%s] %s\n", timestamp, level, message)
        
        -- Write to file
        if log.file then
            log.file.write(logLine)
            log.file.flush()
        end
        
        -- Write to terminal with color
        term.setTextColor(LOG_COLORS[level])
        print(logLine)
        term.setTextColor(colors.white)
    end
end

function log.setLevel(level)
    if LOG_LEVELS[level] then
        log.level = LOG_LEVELS[level]
    end
end

function log.debug(message) writeLog("DEBUG", message) end
function log.info(message) writeLog("INFO", message) end
function log.warn(message) writeLog("WARN", message) end
function log.error(message) writeLog("ERROR", message) end

function log.close()
    if log.file then
        log.file.close()
        log.file = nil
        log.initialized = false
    end
end

return log
]])

-- Write interface module
writeFile("aame/modules/interface/main.lua", [[
-- AA_ME Storage System
-- Main Interface

local log = require("aame.modules.lib.log")

local Interface = {}
Interface.__index = Interface

function Interface.new(system)
    local self = setmetatable({}, Interface)
    self.system = system
    self.term = term.current()
    self.width, self.height = self.term.getSize()
    self.selectedTab = 1
    self.tabs = {"Items", "Crafting", "Settings"}
    self.scroll = {items = 0, crafting = 0}
    self.filter = ""
    self.tabPositions = {}
    return self
end

function Interface:start()
    -- Set up event handlers
    while true do
        self:draw()
        local event = {os.pullEvent()}
        self:handleEvent(table.unpack(event))
    end
end

function Interface:draw()
    self.term.setBackgroundColor(colors.black)
    self.term.clear()
    
    -- Draw header
    self.term.setBackgroundColor(colors.gray)
    self.term.setTextColor(colors.white)
    self.term.setCursorPos(1, 1)
    self.term.clearLine()
    self.term.write(" AA_ME Storage System ")
    
    -- Draw tabs and store their positions
    local x = 1
    self.tabPositions = {}
    for i, tab in ipairs(self.tabs) do
        if i == self.selectedTab then
            self.term.setBackgroundColor(colors.blue)
        else
            self.term.setBackgroundColor(colors.gray)
        end
        self.term.setCursorPos(x, 2)
        self.term.write(" " .. tab .. " ")
        
        -- Store tab position and width for click detection
        self.tabPositions[i] = {
            x = x,
            width = #tab + 2
        }
        
        x = x + #tab + 2
    end
    
    -- Draw content area
    self.term.setBackgroundColor(colors.black)
    self.term.setTextColor(colors.white)
    
    if self.selectedTab == 1 then
        self:drawItemsTab()
    elseif self.selectedTab == 2 then
        self:drawCraftingTab()
    else
        self:drawSettingsTab()
    end
end

function Interface:drawItemsTab()
    -- Draw search bar
    self.term.setCursorPos(1, 4)
    self.term.write("Search: " .. self.filter)
    
    -- Draw items list
    local items = {}
    for name, item in pairs(self.system:getItems() or {}) do
        if self.filter == "" or string.find(string.lower(name), string.lower(self.filter)) then
            table.insert(items, {name = name, count = item.count})
        end
    end
    
    table.sort(items, function(a, b) return a.name < b.name end)
    
    -- Store item positions for click detection
    self.itemPositions = {}
    
    for i = 1, self.height - 5 do
        local idx = i + self.scroll.items
        local item = items[idx]
        
        self.term.setCursorPos(1, i + 4)
        self.term.clearLine()
        
        if item then
            self.term.write(string.format("%-30s %d", item.name, item.count))
            -- Store item position for click detection
            self.itemPositions[i + 4] = {
                item = item.name,
                count = item.count
            }
        end
    end
end

function Interface:drawCraftingTab()
    -- Draw crafting queue
    self.term.setCursorPos(1, 4)
    self.term.write("Crafting Queue:")
    
    local tasks = self.system:getTasks() or {}
    
    -- Store task positions for click detection
    self.taskPositions = {}
    
    for i = 1, self.height - 5 do
        local idx = i + self.scroll.crafting
        local task = tasks[idx]
        
        self.term.setCursorPos(1, i + 4)
        self.term.clearLine()
        
        if task then
            local status = task.status
            if status == "queued" then
                self.term.setTextColor(colors.yellow)
            elseif status == "crafting" then
                self.term.setTextColor(colors.lime)
            elseif status == "failed" then
                self.term.setTextColor(colors.red)
            else
                self.term.setTextColor(colors.white)
            end
            
            self.term.write(string.format("%-20s %-10s %d", task.item, status, task.count))
            self.term.setTextColor(colors.white)
            
            -- Store task position for click detection
            self.taskPositions[i + 4] = {
                id = idx,
                task = task
            }
        end
    end
end

function Interface:drawSettingsTab()
    self.term.setCursorPos(1, 4)
    self.term.write("Settings:")
    
    -- Draw connected peripherals
    self.term.setCursorPos(1, 6)
    self.term.write("Connected Peripherals:")
    
    local y = 7
    log.debug("Requesting peripherals from backend...")
    local peripherals = self.system:getPeripherals() or {}
    log.debug("Received peripherals: " .. textutils.serialize(peripherals))
    
    for name, info in pairs(peripherals) do
        log.debug("Drawing peripheral: " .. name)
        self.term.setCursorPos(2, y)
        self.term.write(string.format("- %s (%s on %s)", name, info.type, info.side))
        y = y + 1
    end
    
    if y == 7 then
        log.debug("No peripherals found")
        self.term.setCursorPos(2, y)
        self.term.setTextColor(colors.lightGray)
        self.term.write("No peripherals connected")
        self.term.setTextColor(colors.white)
    end
end

function Interface:handleClick(x, y)
    -- Check for tab clicks
    if y == 2 then
        for i, tab in ipairs(self.tabPositions) do
            if x >= tab.x and x < tab.x + tab.width then
                self.selectedTab = i
                return
            end
        end
    end
    
    -- Check for item clicks in Items tab
    if self.selectedTab == 1 and self.itemPositions[y] then
        -- Show item details or extraction menu
        self:showItemMenu(self.itemPositions[y].item)
    end
    
    -- Check for task clicks in Crafting tab
    if self.selectedTab == 2 and self.taskPositions[y] then
        -- Show task details or actions
        self:showTaskMenu(self.taskPositions[y].task)
    end
end

function Interface:showItemMenu(itemName)
    -- Clear the bottom portion of the screen for the menu
    local menuY = self.height - 3
    self.term.setCursorPos(1, menuY)
    self.term.clearLine()
    self.term.write("Extract " .. itemName .. "? (Enter count or ESC to cancel)")
    
    self.term.setCursorPos(1, menuY + 1)
    self.term.clearLine()
    self.term.write("> ")
    
    local input = read()
    if input and input ~= "" then
        local count = tonumber(input)
        if count and count > 0 then
            -- TODO: Get output inventory from config
            local extracted = self.system:extractItem(
                itemName,
                count,
                "minecraft:chest_0"
            )
            
            self.term.setCursorPos(1, menuY + 2)
            self.term.clearLine()
            if extracted and extracted > 0 then
                self.term.setTextColor(colors.lime)
                self.term.write("Extracted " .. extracted .. " items")
            else
                self.term.setTextColor(colors.red)
                self.term.write("Failed to extract items")
            end
            self.term.setTextColor(colors.white)
            os.sleep(1)
        end
    end
end

function Interface:showTaskMenu(task)
    -- Clear the bottom portion of the screen for the menu
    local menuY = self.height - 2
    self.term.setCursorPos(1, menuY)
    self.term.clearLine()
    self.term.write(string.format("Task: %s (%s)", task.item, task.status))
    
    if task.error then
        self.term.setCursorPos(1, menuY + 1)
        self.term.clearLine()
        self.term.setTextColor(colors.red)
        self.term.write("Error: " .. task.error)
        self.term.setTextColor(colors.white)
    end
    
    os.sleep(2)
end

function Interface:handleEvent(event, ...)
    if event == "mouse_click" then
        local button, x, y = ...
        if button == 1 then -- Left click
            self:handleClick(x, y)
        end
    elseif event == "key" then
        local key = ...
        if key == keys.tab then
            self.selectedTab = (self.selectedTab % #self.tabs) + 1
        elseif key == keys.up then
            if self.selectedTab == 1 then
                self.scroll.items = math.max(0, self.scroll.items - 1)
            elseif self.selectedTab == 2 then
                self.scroll.crafting = math.max(0, self.scroll.crafting - 1)
            end
        elseif key == keys.down then
            if self.selectedTab == 1 then
                self.scroll.items = self.scroll.items + 1
            elseif self.selectedTab == 2 then
                self.scroll.crafting = self.scroll.crafting + 1
            end
        end
    elseif event == "char" then
        local char = ...
        if self.selectedTab == 1 then
            self.filter = self.filter .. char
        end
    elseif event == "key_up" then
        local key = ...
        if key == keys.backspace and #self.filter > 0 then
            self.filter = string.sub(self.filter, 1, -2)
        end
    end
end

return Interface
]])

-- Write frontend startup
writeFile("aame/startup_frontend.lua", [[
-- Add module path
package.path = package.path .. ";/?;/?.lua"

local log = require("aame.modules.lib.log")
local Interface = require("aame.modules.interface.main")

-- Remote system proxy that communicates with the backend
local RemoteSystem = {}
RemoteSystem.__index = RemoteSystem

function RemoteSystem.new()
    local self = setmetatable({}, RemoteSystem)
    
    -- Try to open rednet (for pocket computers first)
    local ok = pcall(rednet.open)
    if not ok then
        -- If that fails, try all sides for regular computers
        local sides = {"top", "bottom", "left", "right", "front", "back"}
        local modemFound = false
        
        for _, side in ipairs(sides) do
            if peripheral.getType(side) == "modem" then
                ok = pcall(rednet.open, side)
                if ok then
                    modemFound = true
                    break
                end
            end
        end
        
        if not modemFound then
            error("Could not find a modem. Please attach a wireless or wired modem to any side of the computer.")
        end
    end
    
    -- Find storage system with retries
    local maxRetries = 5
    local retryDelay = 1
    local id = nil
    
    print("Looking for storage system backend...")
    for i = 1, maxRetries do
        id = rednet.lookup("aame_storage", "storage_system")
        if id then
            print("Found backend system with ID: " .. id)
            break
        end
        if i < maxRetries then
            print("Attempt " .. i .. " failed. Retrying in " .. retryDelay .. " seconds...")
            os.sleep(retryDelay)
        end
    end
    
    if not id then
        error([[Could not find storage system. Please check:
1. Is the backend computer running?
2. Does it have a modem attached?
3. Are both computers within wireless range?
4. Did the backend call rednet.host("aame_storage", "storage_system")?]])
    end
    
    self.backendId = id
    return self
end

function RemoteSystem:sendRequest(type, action, params)
    local message = {
        type = type,
        action = action
    }
    -- Add any additional parameters
    for k, v in pairs(params or {}) do
        message[k] = v
    end
    
    rednet.send(self.backendId, message, "aame_storage")
    local sender, response = rednet.receive("aame_storage", 5) -- 5 second timeout
    
    if not response then
        return nil, "Timeout waiting for response"
    end
    
    if not response.success then
        return nil, response.error
    end
    
    return response.data
end

-- Inventory proxy methods
function RemoteSystem:getItems()
    return self:sendRequest("inventory", "getItems")
end

function RemoteSystem:getPeripherals()
    return self:sendRequest("inventory", "getPeripherals")
end

function RemoteSystem:extractItem(itemName, count, toInventory, toSlot)
    return self:sendRequest("inventory", "extractItem", {
        itemName = itemName,
        count = count,
        toInventory = toInventory,
        toSlot = toSlot
    })
end

-- Crafting proxy methods
function RemoteSystem:getTasks()
    return self:sendRequest("crafting", "getTasks")
end

function RemoteSystem:craftItem(itemName, count)
    return self:sendRequest("crafting", "craftItem", {
        itemName = itemName,
        count = count
    })
end

-- Start the frontend
local function main()
    log.info("Starting AA_ME Storage System Frontend...")
    
    -- Create remote system proxy
    local system = RemoteSystem.new()
    
    -- Create and start interface
    local interface = Interface.new(system)
    interface:start()
end

-- Error handling wrapper
local ok, err = pcall(main)
if not ok then
    term.setTextColor(colors.red)
    print("\nError starting frontend:")
    print(err)
    print("\nPress any key to exit...")
    term.setTextColor(colors.white)
    os.pullEvent("key")
end
]])

-- Create startup file that runs the frontend
writeFile("startup.lua", [[
-- Run the AA_ME frontend
shell.run("aame/startup_frontend.lua")
]])

print("\nInstallation complete!")
print("The frontend will start automatically on next reboot.")
print("You can also run 'aame/startup_frontend.lua' manually.") 