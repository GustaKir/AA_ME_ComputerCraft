-- AA_ME Storage System
-- Main Startup Script

-- Add module path
package.path = package.path .. ";/?;/?.lua"

local log = require("aame.modules.lib.log")

-- Function to check if a program is running
local function isProgramRunning(programName)
    for _, process in ipairs(multishell and multishell.list() or {}) do
        if multishell.getTitle(process):find(programName) then
            return true
        end
    end
    return false
end

-- Function to start the backend
local function startBackend()
    if multishell then
        multishell.launch({}, "aame/startup_backend.lua")
        return true
    else
        log.error("Cannot start backend: multishell not available")
        return false
    end
end

-- Function to start the frontend
local function startFrontend()
    if multishell then
        multishell.launch({}, "aame/startup_frontend.lua")
        return true
    else
        shell.run("aame/startup_frontend.lua")
        return true
    end
end

-- Main startup function
local function main()
    log.info("AA_ME Storage System starting...")
    
    -- Check if we're on a pocket computer (frontend only)
    if pocket then
        log.info("Detected pocket computer, starting frontend only")
        startFrontend()
        return
    end
    
    -- Check if we're on an advanced computer (can run both)
    if term.isColor() then
        log.info("Detected advanced computer, starting both backend and frontend")
        
        -- Start backend first
        if startBackend() then
            -- Wait a moment for the backend to initialize
            os.sleep(1)
            
            -- Then start frontend
            startFrontend()
        else
            log.error("Failed to start backend")
        end
        return
    end
    
    -- If we're on a basic computer, just start the backend
    log.info("Detected basic computer, starting backend only")
    shell.run("aame/startup_backend.lua")
end

-- Run the main function with error handling
local ok, err = pcall(main)
if not ok then
    term.setTextColor(colors.red)
    print("\nError starting AA_ME Storage System:")
    print(err)
    print("\nPress any key to exit...")
    term.setTextColor(colors.white)
    os.pullEvent("key")
end 