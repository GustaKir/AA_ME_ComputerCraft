local class = require("artist.lib.class")
local interface = require("artist.gui.interface")

local Interface = class "interface.Interface"

function Interface:initialise(context, craftingSystem)
    self.context = context
    self.craftingSystem = craftingSystem
    self.items = context:require("artist.core.items")
    
    -- Create base interface
    self.baseInterface = interface(context, function(hash, quantity)
        -- Default extract handler
        if self.config.pickup_chest ~= "" then
            self.items:extract(self.config.pickup_chest, hash, quantity)
        end
    end)
    
    -- Load config
    self.config = context.config
        :group("interface", "Interface options")
        :define("pickup_chest", "Chest to extract items to", "", nil)
        :get()
    
    -- Initialize UI components
    self:initializeComponents()
end

function Interface:initializeComponents()
    -- Main menu options
    self.menuItems = {
        {name = "Search", action = self.showSearch},
        {name = "Craft", action = self.showCrafting},
        {name = "Dump", action = self.showDump},
        {name = "Tasks", action = self.showTasks},
    }
end

function Interface:start()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        
        -- Draw header
        print("=== Storage System ===")
        print()
        
        -- Draw menu
        for i, item in ipairs(self.menuItems) do
            print(i .. ". " .. item.name)
        end
        
        -- Get input
        print()
        write("Select option (1-" .. #self.menuItems .. "): ")
        local input = read()
        local option = tonumber(input)
        
        if option and self.menuItems[option] then
            self.menuItems[option].action(self)
        end
    end
end

function Interface:showSearch()
    -- Use ARTIST's built-in search
    self.baseInterface.show()
end

function Interface:showCrafting()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Crafting Interface ===")
    print()
    
    -- Get item to craft
    write("Enter item name: ")
    local item = read()
    
    write("Enter amount: ")
    local count = tonumber(read()) or 1
    
    -- Start crafting
    local taskId = self.craftingSystem:craftItem(item, count)
    if type(taskId) == "string" then
        print("Error: " .. taskId)
    else
        print("Started crafting task #" .. taskId)
    end
    
    write("Press any key to continue...")
    read()
end

function Interface:showDump()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Dump Items ===")
    print()
    
    -- TODO: Implement item dumping from inventory to system
    print("Not implemented yet")
    
    write("Press any key to continue...")
    read()
end

function Interface:showTasks()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Active Tasks ===")
    print()
    
    local tasks = self.craftingSystem.activeTasks
    if next(tasks) == nil then
        print("No active tasks")
    else
        for id, task in pairs(tasks) do
            print(string.format("#%s: Crafting %d x %s (%s)",
                id,
                task.count,
                task.recipe.output,
                task.status
            ))
        end
    end
    
    write("Press any key to continue...")
    read()
end

return Interface 