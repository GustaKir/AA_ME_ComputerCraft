-- Add module path
package.path = package.path .. ";/?;/?.lua"

local log = require("aame.modules.lib.log")
local Interface = require("aame.modules.interface.basalt_main")

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
    
    -- Try to send the request with retries
    local maxRetries = 3
    local retryDelay = 1
    
    for attempt = 1, maxRetries do
        -- Send the request
        rednet.send(self.backendId, message, "aame_storage")
        
        -- Wait for response with timeout
        local sender, response = rednet.receive("aame_storage", 2) -- 2 second timeout
    
        if response then
    if not response.success then
        return nil, response.error
    end
    
    return response.data
        end
        
        -- If this wasn't the last attempt, wait before retrying
        if attempt < maxRetries then
            os.sleep(retryDelay)
        end
    end
    
    -- If we get here, all retries failed
    log.error("All retries failed, backend may be down")
    return nil, "Timeout waiting for response"
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