-- Add module path
package.path = package.path .. ";/?;/?.lua"

-- Initialize backend system components
local Inventory = require("aame.modules.core.inventory")
local Crafting = require("aame.modules.core.crafting")
local PeripheralManager = require("aame.modules.peripherals.manager")
local log = require("aame.modules.lib.log")

-- Backend system class
local BackendSystem = {}
BackendSystem.__index = BackendSystem

function BackendSystem.new()
    local self = setmetatable({}, BackendSystem)
    
    -- Initialize components
    self.inventory = Inventory.new()
    self.crafting = Crafting.new(self)
    self.peripheralManager = PeripheralManager.new(self)
    
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
    
    return self
end

function BackendSystem:handleRemoteCall(sender, message)
    if message.type == "inventory" then
        if message.action == "getItems" then
            local items = self.inventory:getItems()
            return items
        elseif message.action == "extractItem" then
            return self.inventory:extractItem(
                message.itemName,
                message.count,
                message.toInventory,
                message.toSlot
            )
        elseif message.action == "getPeripherals" then
            -- Return a list of connected peripherals
            local peripherals = {}
            local names = peripheral.getNames()
            
            for _, name in ipairs(names) do
                local types = {peripheral.getType(name)}
                peripherals[name] = {
                    type = table.concat(types, ", "),
                    side = name -- For named peripherals, the name might be a side or a network path
                }
            end
            
            return peripherals
        end
    elseif message.type == "crafting" then
        if message.action == "getTasks" then
            return self.crafting:getTasks()
        elseif message.action == "craftItem" then
            return self.crafting:craftItem(message.itemName, message.count)
        end
    end
    
    return nil, "Invalid request"
end

function BackendSystem:startNetworking()
    -- Host ID for the storage system
    log.info("Starting network service...")
    rednet.host("aame_storage", "storage_system")
    log.info("Network service hosted successfully. Waiting for connections...")
    
    while true do
        -- Use pcall to catch any errors in the networking code
        local success, err = pcall(function()
            local sender, message = rednet.receive("aame_storage", 5) -- Add timeout
            if message then
                -- Validate message format
                if type(message) ~= "table" or not message.type or not message.action then
                    rednet.send(sender, {
                        success = false,
                        error = "Invalid message format"
                    }, "aame_storage")
                    return
                end
                
                -- Handle the request with error catching
                local response, error = nil, nil
                local handleSuccess, handleErr = pcall(function()
                    response, error = self:handleRemoteCall(sender, message)
                end)
                
                if not handleSuccess then
                    log.error("Error handling request: " .. tostring(handleErr))
                    error = "Internal server error: " .. tostring(handleErr)
                end
                
                -- Send response
                rednet.send(sender, {
                    success = error == nil,
                    data = response,
                    error = error
                }, "aame_storage")
            end
        end)
        
        if not success then
            log.error("Error in networking: " .. tostring(err))
            -- Continue the loop rather than crashing
            os.sleep(1)
        end
    end
end

function BackendSystem:start()
    log.info("Starting AA_ME Storage System Backend...")
    
    -- Start all background tasks
    parallel.waitForAll(
        function() self.peripheralManager:startMonitoring() end,
        function() self.inventory:startScanning() end,
        function() self.crafting:startMonitoring() end,
        function() self:startNetworking() end
    )
end

-- Start the backend system
local system = BackendSystem.new()
system:start() 