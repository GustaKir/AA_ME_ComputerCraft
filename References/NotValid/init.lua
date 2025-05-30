-- AA_ME Storage System
-- Main initialization file

local Inventory = require("aame.modules.core.inventory")
local Crafting = require("aame.modules.core.crafting")
local Interface = require("aame.modules.interface.main")
local PeripheralManager = require("aame.modules.peripherals.manager")

local StorageSystem = {}
StorageSystem.__index = StorageSystem

function StorageSystem.new()
    local self = setmetatable({}, StorageSystem)
    
    -- Initialize components
    self.inventory = Inventory.new()
    self.crafting = Crafting.new(self)
    self.interface = Interface.new(self)
    self.peripheralManager = PeripheralManager.new(self)
    
    return self
end

function StorageSystem:start()
    -- Start background tasks
    parallel.waitForAll(
        function() self.peripheralManager:startMonitoring() end,
        function() self.inventory:startScanning() end,
        function() self.crafting:startMonitoring() end,
        function() self.interface:start() end
    )
end

return StorageSystem 