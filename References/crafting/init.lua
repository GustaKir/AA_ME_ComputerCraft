local class = require("artist.lib.class")
local log = require("artist.lib.log").get_logger(...)

local CraftingSystem = class "crafting.CraftingSystem"

function CraftingSystem:initialise(context)
    self.context = context
    self.items = context:require("artist.core.items")
    
    -- Recipe database
    self.recipes = {}
    -- Active crafting tasks
    self.activeTasks = {}
    -- Create mod interfaces
    self.createInterfaces = {}
    
    -- Load recipes from file
    self:loadRecipes()
    
    -- Start monitoring system
    self:startMonitoring()
end

function CraftingSystem:loadRecipes()
    -- TODO: Load recipes from a JSON/config file
    -- Format will be:
    -- {
    --   output = "minecraft:item",
    --   count = 1,
    --   inputs = {
    --     {item = "minecraft:item", count = 1},
    --     ...
    --   },
    --   method = "create_mechanical" | "create_mixing" | "create_pressing" etc
    -- }
end

function CraftingSystem:startMonitoring()
    self.context:spawn(function()
        while true do
            -- Check active crafting tasks
            for taskId, task in pairs(self.activeTasks) do
                self:updateCraftingTask(taskId, task)
            end
            os.sleep(1)
        end
    end)
end

function CraftingSystem:updateCraftingTask(taskId, task)
    -- Check if required items are available
    -- Monitor Create machines progress
    -- Update task status
end

function CraftingSystem:craftItem(itemHash, count)
    local recipe = self.recipes[itemHash]
    if not recipe then
        return false, "No recipe found"
    end
    
    -- Generate crafting tree
    local requirements = self:generateRequirements(recipe, count)
    
    -- Start crafting task
    local taskId = os.epoch("utc")
    self.activeTasks[taskId] = {
        recipe = recipe,
        count = count,
        requirements = requirements,
        status = "pending"
    }
    
    return taskId
end

function CraftingSystem:generateRequirements(recipe, count)
    local requirements = {}
    
    for _, input in ipairs(recipe.inputs) do
        local required = input.count * count
        local available = self:getItemCount(input.item)
        
        if available < required then
            -- Need to craft this input
            local subRecipe = self.recipes[input.item]
            if subRecipe then
                table.insert(requirements, {
                    item = input.item,
                    needed = required - available,
                    recipe = subRecipe
                })
            end
        end
    end
    
    return requirements
end

function CraftingSystem:getItemCount(itemHash)
    local entry = self.items:get_item(itemHash)
    return entry and entry.count or 0
end

function CraftingSystem:registerCreateInterface(name, interface)
    self.createInterfaces[name] = interface
end

return CraftingSystem 