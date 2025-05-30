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