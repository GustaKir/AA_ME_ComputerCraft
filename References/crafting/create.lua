local class = require("artist.lib.class")
local expect = require("cc.expect").expect

local CreateInterface = class "crafting.CreateInterface"

function CreateInterface:initialise(context, name, peripheral_name)
    expect(1, context, "table")
    expect(2, name, "string")
    expect(3, peripheral_name, "string")
    
    self.context = context
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
    }
end

function CreateInterface:mechanicalCraft(recipe, count)
    -- Interface with mechanical crafter
    -- Returns: success, message
end

function CreateInterface:mixing(recipe, count)
    -- Interface with mixer
    -- Returns: success, message
end

function CreateInterface:pressing(recipe, count)
    -- Interface with mechanical press
    -- Returns: success, message
end

function CreateInterface:crushing(recipe, count)
    -- Interface with crusher
    -- Returns: success, message
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
    -- Get current machine status
    -- Returns: {busy = boolean, progress = number}
    return {
        busy = false,
        progress = 0
    }
end

return CreateInterface 