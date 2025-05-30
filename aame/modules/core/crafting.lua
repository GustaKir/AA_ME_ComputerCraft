-- AA_ME Storage System
-- Crafting Management Module

local log = require("aame.modules.lib.log")

local Crafting = {}
Crafting.__index = Crafting

function Crafting.new(system)
    local self = setmetatable({}, Crafting)
    self.system = system
    self.tasks = {}
    self.nextTaskId = 1
    return self
end

function Crafting:startMonitoring()
    while true do
        self:processTasks()
        os.sleep(1)
    end
end

function Crafting:getTasks()
    local taskList = {}
    for id, task in pairs(self.tasks) do
        table.insert(taskList, {
            id = id,
            item = task.item,
            count = task.count,
            status = task.status,
            error = task.error
        })
    end
    return taskList
end

function Crafting:craftItem(itemName, count)
    local taskId = self.nextTaskId
    self.nextTaskId = self.nextTaskId + 1
    
    self.tasks[taskId] = {
        item = itemName,
        count = count,
        status = "queued",
        error = nil
    }
    
    return taskId
end

function Crafting:processTasks()
    for id, task in pairs(self.tasks) do
        if task.status == "queued" then
            task.status = "crafting"
            -- TODO: Implement actual crafting logic
            -- For now, just simulate crafting
            os.sleep(2)
            task.status = "completed"
        end
    end
end

return Crafting 