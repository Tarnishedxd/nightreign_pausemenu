--[[ Load config ]]
local cfg <const> = require 'config.main'

--[[ Resource name ]]
local resourceName <const> = GetCurrentResourceName()

--[[ Set debug mode ]]
LT.Debug.SetMode(cfg.debug)

--[[ Load locale ]]
lib.locale(cfg.locale)

--[[ Set ox_lib additions ]]
math = lib.math
string = lib.string
array = lib.array
table = lib.table

--- Localization function with fallback.
--- @param str string Locale key. Example: `client.hello`
--- @param fallback? string Fallback string if given key not found. (Optional)
--- @param ...? any Format arguments (Optional)
--- @return string
function _t(str, fallback, ...)
    local retval = locale(str, ...)
    if retval == str then
        return string.format(fallback or str, ...)
    end
    return retval
end

--- Resource event shortcut.
--- @param event string Event name. Example: `client:event`
--- @return string Event Example: `resource:client:event`
function _e(event)
    return resourceName .. ':' .. event
end

--[[ Shortcut of event functions ]]
emit = LT.Events.Emit
emitNet = LT.Events.EmitNet
register = LT.Events.Register
