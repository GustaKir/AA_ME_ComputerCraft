-- AA_ME Storage System
-- Configuration System

local defaultConfig = {
    -- Storage system configuration
    inventories = {
        rescan_interval = 1, -- Time between inventory scans
        ignored_names = {}, -- Ignored inventory names
        ignored_types = {"turtle"}, -- Ignored inventory types
    },
    
    -- Interface configuration
    interface = {
        output_chest = "", -- Chest for item extraction
        input_chest = "", -- Chest for item insertion
    },
    
    -- Create mod interfaces
    create = {
        interfaces = {
            -- Example:
            -- mechanical_crafter = "create:mechanical_crafter_0",
            -- mixer = "create:mixer_0",
        },
    },
    
    -- Crafting configuration
    crafting = {
        recipes_file = "AA_ME/data/recipes.json", -- Path to recipes file
    },
}

local function load()
    -- Try to load existing config
    local configFile = fs.open("AA_ME/config.json", "r")
    local config = defaultConfig
    
    if configFile then
        local content = configFile.readAll()
        configFile.close()
        
        local ok, loaded = pcall(textutils.unserializeJSON, content)
        if ok and loaded then
            -- Merge with defaults
            for k, v in pairs(loaded) do
                if type(v) == "table" then
                    config[k] = config[k] or {}
                    for k2, v2 in pairs(v) do
                        config[k][k2] = v2
                    end
                else
                    config[k] = v
                end
            end
        end
    end
    
    return config
end

local function save(config)
    -- Create config directory if needed
    if not fs.exists("AA_ME") then
        fs.makeDir("AA_ME")
    end
    
    -- Save config
    local configFile = fs.open("AA_ME/config.json", "w")
    if configFile then
        configFile.write(textutils.serializeJSON(config))
        configFile.close()
        return true
    end
    return false
end

return {
    load = load,
    save = save,
    default = defaultConfig
} 