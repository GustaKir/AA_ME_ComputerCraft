-- AA_ME Storage System Interface
local basalt = require("aame.modules.lib.basalt")
local log = require("aame.modules.lib.log")

-- Set log level to DEBUG to see all messages
log.setLevel("DEBUG")

-- Fuzzy search scoring
local function fuzzyScore(str, pattern)
    if not str or not pattern then return 0 end
    str, pattern = string.lower(str), string.lower(pattern)
    
    -- Exact match gets highest score
    if str == pattern then return 1000 end
    
    -- Start match gets high score
    if str:find("^" .. pattern) then return 750 end
    
    -- Contains match gets medium score
    local start = str:find(pattern, 1, true)
    if start then
        -- Earlier matches score higher
        return 500 - start
    end
    
    -- Word boundary match gets lower score
    for word in str:gmatch("%w+") do
        if word:find("^" .. pattern) then
            return 250
        end
    end
    
    return 0
end

local Interface = {}
Interface.__index = Interface

function Interface.new(system)
    local self = setmetatable({}, Interface)
    self.system = system
    self.activeTab = "storage"
    self.filter = ""
    
    if not self.system then
        log.error("Interface initialized without system")
    end
    
    return self
end

function Interface:start()
    log.info("Starting interface")
    
    -- Create main frame
    local main = basalt.createFrame()
    main:setBackground(colors.black)
    
    -- Store references we'll need
    self.main = main
    self.buttons = {}
    
    -- Add buttons spanning the portable computer width (26 chars total)
    self.buttons.storage = main:addButton()
    self.buttons.storage:setText("Storage")
    self.buttons.storage:setSize(9, 1)
    self.buttons.storage:setPosition(1, 1)
    self.buttons.storage:setBackground(colors.blue)
    self.buttons.storage:onClick(function() self:switchTab("storage") end)

    self.buttons.craft = main:addButton()
    self.buttons.craft:setText("Craft")
    self.buttons.craft:setSize(8, 1)
    self.buttons.craft:setPosition(10, 1)
    self.buttons.craft:setBackground(colors.gray)
    self.buttons.craft:onClick(function() self:switchTab("craft") end)

    self.buttons.settings = main:addButton()
    self.buttons.settings:setText("Settings")
    self.buttons.settings:setSize(9, 1)
    self.buttons.settings:setPosition(18, 1)
    self.buttons.settings:setBackground(colors.gray)
    self.buttons.settings:onClick(function() self:switchTab("settings") end)

    -- Create content frame
    self.contentFrame = main:addFrame()
    if not self.contentFrame then
        log.error("Failed to create contentFrame")
    end
    self.contentFrame:setPosition(1, 2) -- Changed from 3 to 2 to remove gap
    self.contentFrame:setSize(26, 18) -- Increased height by 1 to compensate
    self.contentFrame:setBackground(colors.black)

    -- Show initial tab
    self:switchTab("storage")

    -- Start Basalt
    basalt.run()
end

function Interface:switchTab(tabName)
    -- Update active tab
    self.activeTab = tabName
    
    -- Update button colors
    for name, button in pairs(self.buttons) do
        button:setBackground(name == tabName and colors.blue or colors.gray)
    end
    
    -- Verify contentFrame exists
    if not self.contentFrame then
        log.error("Cannot switch tab - contentFrame is nil")
        -- Try to recreate content frame
        if self.main then
            log.info("Attempting to recreate contentFrame")
            self.contentFrame = self.main:addFrame()
            self.contentFrame:setPosition(1, 2)
            self.contentFrame:setSize(26, 18)
            self.contentFrame:setBackground(colors.black)
        else
            log.error("Cannot recreate contentFrame - main is nil")
            return
        end
    end
    
    -- Clear content frame
    self.contentFrame:clear()
    
    -- Show appropriate content
    if tabName == "storage" then
        self:showStorageContent()
        -- Make sure to update the list with any existing filter
        if self.currentList then
            self:updateItemsList(self.currentList)
        end
    elseif tabName == "craft" then
        self:showCraftContent()
    elseif tabName == "settings" then
        self:showSettingsContent()
    end
end

function Interface:showStorageContent()
    -- Create content frame for storage
    self.contentFrame:clear()
    
    -- Add search bar taking full width
    local searchInput = self.contentFrame:addInput()
    searchInput:setPosition(1, 1)
    searchInput:setSize(26, 1)
    searchInput:setBackground(colors.gray)
    searchInput:setForeground(colors.white)
    
    -- Create frame for items
    local itemsFrame = self.contentFrame:addFrame()
    itemsFrame:setPosition(1, 2)
    itemsFrame:setSize(26, 16)
    itemsFrame:setBackground(colors.black)
    
    -- Store references we need
    self.currentList = itemsFrame  -- Change from list to frame
    self.searchInput = searchInput
    self.filter = ""
    
    -- Update search without delay
    local function updateSearch()
        -- Get current search term
        local searchTerm = searchInput:getText() or ""
        
        -- Only update if the filter has changed
        if self.filter ~= searchTerm then
            self.filter = searchTerm
            
            -- Show searching state
            local searchingLabel = itemsFrame:addLabel()
            searchingLabel:setText("Searching...")
            searchingLabel:setPosition(1, 1)
            searchingLabel:setForeground(colors.white)
            
            -- Perform search
            self:updateItemsList(itemsFrame)
        end
    end

    -- Handle input events - now just directly update without delay
    searchInput:onChar(function()
        updateSearch()
    end)
    
    searchInput:onKey(function(_, key)
        if key == keys.backspace or key == keys.delete or key == keys.enter then
            updateSearch()
        end
    end)

    -- Initial items list population (without search term)
    self:updateItemsList(itemsFrame)
end

function Interface:updateItemsList(list)
    if not list then
        log.debug("updateItemsList called with nil list")
        return
    end
    
    -- Ensure the list is clear (defensive)
    list:clear()
    
    -- Get items with error handling
    local success, items = pcall(function() 
        return self.system:getItems()
    end)
    
    if not success or not items or _G.type(items) ~= "table" then
        list:addItem("No items available")
        return
    end
    
    -- Process search term and build scored results
    local searchTerm = self.filter or ""
    local results = {}
    local mergedItems = {} -- Merge items with the same display name
    
    -- First pass: Merge items with the same name and calculate total counts
    for name, item in pairs(items) do
        -- Get item count safely
        local itemCount = 0
        if _G.type(item) == "table" and item.count then
            itemCount = tonumber(item.count) or 0
        elseif _G.type(item) == "number" then
            itemCount = item
        end
        
        if itemCount > 0 then
            -- Format display name - just remove the prefix and underscores
            local displayName = tostring(name)
            -- Handle special case where there might be additional colons or slashes
            displayName = displayName:gsub("^c/", "") -- Remove leading c/
            displayName = displayName:gsub("^[^:]+:", "") -- Remove mod prefix
            displayName = displayName:gsub("/", " ") -- Convert remaining slashes to spaces
            displayName = displayName:gsub("_", " ") -- Convert underscores to spaces
            
            -- Merge items with the same display name
            if not mergedItems[displayName] then
                mergedItems[displayName] = {
                    originalName = name,
                    count = itemCount,
                    names = {name}
                }
            else
                mergedItems[displayName].count = mergedItems[displayName].count + itemCount
                table.insert(mergedItems[displayName].names, name)
            end
        end
    end
    
    -- Second pass: Calculate search scores and build results
    for displayName, itemData in pairs(mergedItems) do
        -- Calculate search score safely
        local score = 0
        if searchTerm == "" then
            score = 1
        else
            local lowerSearch = searchTerm:lower()
            
            -- Score against display name
            score = math.max(score, fuzzyScore(displayName:lower(), lowerSearch))
            
            -- Score against all original names
            for _, name in ipairs(itemData.names) do
                -- Score against original name
                score = math.max(score, fuzzyScore(tostring(name):lower(), lowerSearch))
                
                -- Score against name without mod prefix for non-@ searches
                if not searchTerm:find("^@") then
                    local itemName = tostring(name):gsub("^[^:]+:", ""):gsub("_", " "):lower()
                    score = math.max(score, fuzzyScore(itemName, lowerSearch))
                end
                
                -- Score against mod name for @mod searches
                if searchTerm:find("^@") then
                    local modName = tostring(name):match("^([^:]+):")
                    if modName then
                        local modSearch = searchTerm:match("^@(.+)")
                        if modSearch then
                            score = math.max(score, fuzzyScore(modName:lower(), modSearch:lower()) * 2)
                        end
                    end
                end
            end
        end

        if score > 0 then
            table.insert(results, {
                name = itemData.originalName,
                displayName = displayName,
                count = itemData.count,
                score = score
            })
        end
    end
    
    -- Sort results by score, then quantity, then name
    table.sort(results, function(a, b)
        if a.score == b.score then
            -- If scores are equal, sort by quantity (highest first)
            if a.count ~= b.count then
                return a.count > b.count
            end
            -- If quantities are also equal, sort by name
            return a.displayName < b.displayName
        end
        -- Primary sort by score
        return a.score > b.score
    end)
    
    -- Clear the list again before adding results (extra protection against duplicates)
    list:clear()
    if self.contentFrame then
        self.contentFrame:removeChildren()
    else
        -- Just log the error and continue
        log.debug("contentFrame is nil when trying to removeChildren")
        return
    end
    
    -- Create new search input every time to avoid event handling issues
    local searchInput = self.contentFrame:addInput()
    searchInput:setPosition(1, 1)
    searchInput:setSize(26, 1)
    searchInput:setBackground(colors.gray)
    searchInput:setForeground(colors.white)
    searchInput:setText(self.filter or "")
    
    -- Handle input events - now just directly update without delay
    searchInput:onChar(function()
        self.filter = searchInput:getText() or ""
        self:updateItemsList(list)
    end)
    
    searchInput:onKey(function(_, key)
        if key == keys.backspace or key == keys.delete or key == keys.enter then
            self.filter = searchInput:getText() or ""
            self:updateItemsList(list)
        end
    end)
    
    -- Create item list with buttons
    local itemsFrame = self.contentFrame:addFrame()
    itemsFrame:setPosition(1, 2)
    itemsFrame:setSize(26, 16)
    itemsFrame:setBackground(colors.black)
    
    -- Display results with buttons
    if #results == 0 then
        local emptyLabel = itemsFrame:addLabel()
        if searchTerm ~= "" then
            emptyLabel:setText("No items matching '" .. searchTerm .. "'")
        else
            emptyLabel:setText("No items available")
        end
        emptyLabel:setPosition(1, 1)
        emptyLabel:setForeground(colors.white)
    else
        -- Create item buttons
        for i, item in ipairs(results) do
            -- Format the display string with proper spacing and handle long names
            local displayName = item.displayName
            if #displayName > 18 then
                displayName = displayName:sub(1, 15) .. "..."
            end
            
            -- Item label
            local itemLabel = itemsFrame:addLabel()
            itemLabel:setText(string.format("%-18s%4d", displayName, item.count))
            itemLabel:setPosition(1, i)
            itemLabel:setForeground(colors.white)
            
            -- Add details button
            local detailsButton = itemsFrame:addButton()
            detailsButton:setText("↓")
            detailsButton:setSize(2, 1)
            detailsButton:setPosition(24, i)
            detailsButton:setBackground(colors.blue)
            
            -- Store data for the button to use
            local buttonData = {
                name = item.name,
                displayName = item.displayName,
                count = item.count
            }
            
            -- Safe click handler
            detailsButton:onClick(function()
                -- Using a safe approach that doesn't rely on selectedText
                self:showSimpleItemOverlay(buttonData.displayName, buttonData.count, buttonData.name)
            end)
        end
    end
    
    -- Store reference to search input
    self.searchInput = searchInput
end

function Interface:showSimpleItemOverlay(displayName, count, itemId)
    -- Create overlay
    local overlay = self.main:addFrame()
    overlay:setSize(24, 10)
    overlay:setPosition(2, 4) -- Center in screen
    overlay:setBackground(colors.gray)
    overlay:setForeground(colors.white)
    overlay:setBorder(colors.lightGray)
    
    -- Item name header
    local nameLabel = overlay:addLabel()
    nameLabel:setText(displayName)
    nameLabel:setPosition(2, 1)
    nameLabel:setForeground(colors.white)
    
    -- Item info
    local quantityLabel = overlay:addLabel()
    quantityLabel:setText("Quantity: " .. count)
    quantityLabel:setPosition(2, 3)
    
    -- ID info (only if we have it)
    if itemId then
        local idLabel = overlay:addLabel()
        idLabel:setText("ID: " .. itemId)
        idLabel:setPosition(2, 4)
        idLabel:setForeground(colors.lightGray)
    end
    
    -- Extract options
    local extractLabel = overlay:addLabel()
    extractLabel:setText("Extract:")
    extractLabel:setPosition(2, 6)
    
    -- Extract quantity input
    local extractInput = overlay:addInput()
    extractInput:setPosition(12, 6)
    extractInput:setSize(6, 1)
    extractInput:setBackground(colors.black)
    extractInput:setForeground(colors.white)
    extractInput:setText("1")
    
    -- Extract button
    local extractButton = overlay:addButton()
    extractButton:setText("Extract")
    extractButton:setPosition(6, 8)
    extractButton:setSize(12, 1)
    extractButton:setBackground(colors.blue)
    
    -- Create a fixed click handler with proper itemId handling
    local function doExtract()
        local extractAmount = tonumber(extractInput:getText()) or 1
        if extractAmount > 0 and extractAmount <= count then
            -- Use provided itemId or try to look it up if not provided
            local idToExtract = itemId
            if not idToExtract then
                idToExtract = self:findItemIdByDisplayName(displayName)
            end
            
            if idToExtract and self.system and self.system.extractItem then
                -- Log what we're about to extract for debugging
                log.debug("Extracting " .. extractAmount .. " of " .. idToExtract)
                
                -- Safely call extract
                pcall(function()
                    self.system:extractItem(idToExtract, extractAmount)
                end)
            else
                log.debug("Cannot extract - missing itemId or extract function")
            end
            
            -- Always close and refresh regardless of success
            overlay:remove()
            
            -- Safely refresh the list if it exists
            if self.currentList then
                self:updateItemsList(self.currentList)
            else
                log.debug("Cannot refresh list - currentList is nil")
            end
        end
    end
    
    -- Attach the extract handler
    extractButton:onClick(doExtract)
    
    -- Close button
    local closeButton = overlay:addButton()
    closeButton:setText("X")
    closeButton:setPosition(21, 1)
    closeButton:setSize(2, 1)
    closeButton:setBackground(colors.red)
    closeButton:setForeground(colors.white)
    
    closeButton:onClick(function()
        overlay:remove()
        end)
end

-- Helper function to safely find an item ID by display name
function Interface:findItemIdByDisplayName(targetDisplayName)
    -- Get items with error handling
    local success, items = pcall(function() 
        return self.system:getItems()
    end)
    
    if not success or not items or _G.type(items) ~= "table" then
        return nil
    end
    
    -- Check each item to find one with matching display name
    for name, _ in pairs(items) do
        -- Format display name consistently
        local currentDisplayName = tostring(name)
            :gsub("^c/", "")
            :gsub("^[^:]+:", "")
            :gsub("/", " ")
            :gsub("_", " ")
        
        if currentDisplayName == targetDisplayName then
            return name
        end
    end
    
    return nil
end

function Interface:showCraftContent()
    local label = self.contentFrame:addLabel()
    label:setText("Crafting interface coming soon...")
    label:setForeground(colors.white)
    label:setPosition(1, 1)
end

function Interface:showSettingsContent()
    local label = self.contentFrame:addLabel()
    label:setText("Settings panel coming soon...")
    label:setForeground(colors.white)
    label:setPosition(1, 1)
end

return Interface 