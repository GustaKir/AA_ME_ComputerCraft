-- AA_ME Storage System Installer

local function downloadFile(url, path)
    local response = http.get(url)
    if response then
        local file = fs.open(path, "w")
        file.write(response.readAll())
        file.close()
        response.close()
        return true
    end
    return false
end

print("Installing AA_ME Storage System...")

-- Create directories
fs.makeDir("AA_ME")
fs.makeDir("AA_ME/modules")
fs.makeDir("AA_ME/modules/lib")
fs.makeDir("AA_ME/modules/core")
fs.makeDir("AA_ME/modules/interface")

-- Download Basalt
print("Downloading Basalt...")
if not downloadFile(
    "https://basalt.madefor.cc/install.lua",
    "AA_ME/modules/lib/basalt.lua"
) then
    error("Failed to download Basalt")
end

-- Copy startup scripts
print("Installing startup scripts...")
local startup = fs.open("startup.lua", "w")
startup.write([[
-- AA_ME Storage System Startup
shell.run("AA_ME/startup.lua")
]])
startup.close()

-- Create disk installer
print("Creating disk installer...")
fs.makeDir("disk")
local diskStartup = fs.open("disk/startup.lua", "w")
diskStartup.write([[
-- AA_ME Remote Terminal
shell.run("AA_ME/disk_startup.lua")
]])
diskStartup.close()

print("Installation complete!")
print("Run 'startup.lua' to start the system") 