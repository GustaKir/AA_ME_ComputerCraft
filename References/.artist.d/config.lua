return {
    -- Storage system configuration
    inventories = {
        rescan = 10, -- Time between rescanning inventories
        ignored_names = {}, -- Ignored inventory names
        ignored_types = {"turtle"}, -- Ignored inventory types
    },
    
    -- Interface configuration
    interface = {
        pickup_chest = "", -- Will be configured on first run
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
        recipes_file = "crafting/recipes.json", -- Path to recipes file
    },
    
    -- Dropoff configuration
    dropoff = {
        chests = {}, -- Will be configured on first run
        cold_delay = 5,
        hot_delay = 0.2,
    },
} 