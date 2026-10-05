-- LTBridge Auto-Generated Client Loader

local RESOURCE <const> = GetCurrentResourceName()
local BASE_PATH <const> = "ltbridge/modules/imports/"

local modules = {
    "NUI/client.lua",
    "NUI/State/client.lua",
    "Framework/IsPlayerLoaded/client.lua",
    "LoadUnload/client.lua",
    "NUI/Message/client.lua",
    "NUI/Focus/client.lua",
    "NUI/Callback/client.lua",
    "Framework/GetPlayerData/client.lua",
    "Framework/GetPlayerName/client.lua",
    "Framework/GetPlayerCitizenId/client.lua"
}

local function loadModule(path)
    local fullPath = BASE_PATH .. path
    local content = LoadResourceFile(RESOURCE, fullPath)
    if not content then
        return print(("^6[LTBridge 1.3.5] ^1ERROR: Module file not found: %s^7"):format(path))
    end
    local chunk, err = load(content, ("@@%s/%s"):format(RESOURCE, fullPath))
    if not chunk then
        return print(("^6[LTBridge 1.3.5] ^1ERROR: Syntax error in module: %s\n%s^7"):format(fullPath, err))
    end
    local ok, runtimeErr = pcall(chunk)
    if not ok then
        print(("^6[LTBridge 1.3.5] ^1ERROR: Runtime error in module: %s\n%s^7"):format(fullPath, runtimeErr))
    end
end

for i = 1, #modules do
    loadModule(modules[i])
end
