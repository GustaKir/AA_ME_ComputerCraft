-- AA_ME Storage System Installer
-- This script will install the complete storage system

-- First, ensure we're in the root directory where modules should be installed
if not fs.exists("disk") then
    fs.makeDir("disk")
end

local files = {
    ["disk/AA_ME/init.lua"] = [[-- AA_ME Storage System
local StorageSystem = {}
StorageSystem.__index = StorageSystem

function StorageSystem.new()
    local self = setmetatable({}, StorageSystem)
    self.version = "1.0.0"
    
    -- Initialize core components
    self.inventory = require("disk.AA_ME.core.inventory").new()
    self.crafting = require("disk.AA_ME.core.crafting").new(self)
    self.interface = require("disk.AA_ME.interface.main").new(self)
    self.config = require("disk.AA_ME.core.config").load()
    self.peripheralManager = require("disk.AA_ME.peripherals.manager").new(self)
    
    return self
end

function StorageSystem:startBackgroundTasks()
    parallel.waitForAll(
        function() self.inventory:startScanning() end,
        function() self.crafting:startMonitoring() end,
        function() self.peripheralManager:startMonitoring() end
    )
end

function StorageSystem:start()
    -- Start background tasks in parallel with interface
    parallel.waitForAll(
        function() self:startBackgroundTasks() end,
        function() self.interface:start() end
    )
end

return StorageSystem]],

    ["disk/startup.lua"] = [[-- AA_ME Storage System Startup
local function printHeader()
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.yellow)
    print("=========================")
    print("   AA_ME Storage System  ")
    print("=========================")
    print()
    term.setTextColor(colors.white)
end

local function main()
    printHeader()
    print("Initializing storage system...")
    
    -- Load system
    local StorageSystem = require("disk.AA_ME.init")
    local system = StorageSystem.new()
    
    -- Start system
    system:start()
end

local ok, err = pcall(main)
if not ok then
    term.setTextColor(colors.red)
    print("\nError starting storage system:")
    print(err)
    print("\nPress any key to exit...")
    term.setTextColor(colors.white)
    os.pullEvent("key")
end]],

    ["disk/AA_ME/data/recipes.json"] = [[{
    "minecraft:iron_ingot": {
        "output": {"item": "minecraft:iron_ingot", "count": 1},
        "inputs": [
            {"item": "minecraft:iron_ore", "count": 1}
        ],
        "method": "create_crushing"
    }
}]],

    ["disk/AA_ME/config.json"] = [[{
    "inventories": {
        "rescan_interval": 1,
        "ignored_names": {},
        "ignored_types": ["turtle"]
    },
    "interface": {
        "output_chest": "minecraft:chest_0",
        "input_chest": "minecraft:chest_1"
    },
    "create": {
        "interfaces": {}
    },
    "crafting": {
        "recipes_file": "disk/AA_ME/data/recipes.json"
    }
}]]
}

-- Create base directories
print("Installing AA_ME Storage System...")
print("Creating directory structure...")

local dirs = {
    "disk/AA_ME",
    "disk/AA_ME/core",
    "disk/AA_ME/interface",
    "disk/AA_ME/peripherals",
    "disk/AA_ME/lib",
    "disk/AA_ME/data",
    "disk/AA_ME/logs"
}

for _, dir in ipairs(dirs) do
    if not fs.exists(dir) then
        fs.makeDir(dir)
        print("Created directory: " .. dir)
    end
end

-- Create files
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

print("\nCreating files...")
for path, content in pairs(files) do
    createFile(path, content)
    print("Created: " .. path)
end

print("\nInstallation started!")
print("Run 'installer_part2' to continue installation...") 