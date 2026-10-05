-- LTBridge Auto-Generated Shared Loader

local RESOURCE <const> = GetCurrentResourceName()
local BASE_PATH <const> = "ltbridge/modules/imports/"

local modules = {
    "Core/shared.lua",
    "Debug/shared.lua",
    "Framework/shared.lua",
    "Events/shared.lua",
    "Events/Emit/shared.lua",
    "Events/EmitNet/shared.lua",
    "Events/Register/shared.lua",
    "Hooks/Stop/shared.lua",
    "Math/Clamp/shared.lua",
    "Math/Lerp/shared.lua"
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
