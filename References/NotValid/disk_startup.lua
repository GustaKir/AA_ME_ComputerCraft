-- AA_ME Remote Storage Terminal

-- Add the AA_ME directory to the package path
package.path = package.path .. ";AA_ME/?.lua;AA_ME/?/init.lua"

-- Load required modules
local RemoteSystem = require("aame.modules.core.remote")
local Interface = require("aame.modules.interface.basalt_main")

-- Find the storage system computer
print("Searching for storage system...")
local modem = peripheral.find("modem")
if not modem then
    error("No modem found! Please attach a modem or networking cable.")
end

-- Initialize remote system
local system = RemoteSystem.new(modem)

-- Initialize and start interface
local interface = Interface.new(system)
interface:start() 