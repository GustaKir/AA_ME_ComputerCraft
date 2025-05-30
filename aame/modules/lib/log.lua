-- AA_ME Storage System
-- Logging Utility

local log = {}

local LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

local LOG_COLORS = {
    DEBUG = colors.lightGray,
    INFO = colors.white,
    WARN = colors.yellow,
    ERROR = colors.red
}

log.level = LOG_LEVELS.INFO
log.file = nil
log.initialized = false

local function ensureLogDirectory()
    if not fs.exists("aame/logs") then
        fs.makeDir("aame/logs")
    end
end

local function openLogFile()
    ensureLogDirectory()
    local filename = string.format("aame/logs/%s.log", os.date("%Y-%m-%d"))
    return fs.open(filename, "a")
end

local function writeLog(level, message)
    if not log.initialized then
        log.file = openLogFile()
        log.initialized = true
    end
    
    if LOG_LEVELS[level] >= log.level then
        local timestamp = os.date("%H:%M:%S")
        local logLine = string.format("[%s] [%s] %s\n", timestamp, level, message)
        
        -- Write to file
        if log.file then
            log.file.write(logLine)
            log.file.flush()
        end
        
        -- Write to terminal with color
        term.setTextColor(LOG_COLORS[level])
        print(logLine)
        term.setTextColor(colors.white)
    end
end

function log.setLevel(level)
    if LOG_LEVELS[level] then
        log.level = LOG_LEVELS[level]
    end
end

function log.debug(message) writeLog("DEBUG", message) end
function log.info(message) writeLog("INFO", message) end
function log.warn(message) writeLog("WARN", message) end
function log.error(message) writeLog("ERROR", message) end

function log.close()
    if log.file then
        log.file.close()
        log.file = nil
        log.initialized = false
    end
end

return log 