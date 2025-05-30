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

print("\nPart 3 complete!")
print("Run 'installer_part4' to complete installation...") 