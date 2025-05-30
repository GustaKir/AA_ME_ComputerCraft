-- Storage System startup file
local function loadSystem()
    -- Initialize the core storage system
    local context = require("artist.init")()
    
    -- Initialize our custom modules
    local craftingSystem = require("crafting.init")(context)
    local userInterface = require("interface.init")(context, craftingSystem)
    
    -- Start the interface
    userInterface.start()
end

-- Error handling wrapper
local ok, err = pcall(loadSystem)
if not ok then
    term.setTextColor(colors.red)
    print("Error starting storage system:")
    print(err)
    term.setTextColor(colors.white)
end 