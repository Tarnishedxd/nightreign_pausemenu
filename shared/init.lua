--[[ Load config ]]
local cfg <const> = require 'config.main'

--[[ Resource name ]]
local resourceName <const> = GetCurrentResourceName()

--[[ Set debug mode ]]
LT.Debug.SetMode(cfg.debug)

--[[ Load locale ]]
local requestedLocale <const> = type(cfg.locale) == 'string' and cfg.locale ~= '' and cfg.locale or 'en'
local localeKey <const> = LoadResourceFile(resourceName, ('locales/%s.json'):format(requestedLocale)) and requestedLocale or 'en'
if localeKey ~= requestedLocale then
    print(('^3[%s] Locale "%s" was not found in locales/, falling back to English.^7'):format(resourceName, requestedLocale))
end
lib.locale(localeKey)

--- Locale that was actually loaded (after the English fallback).
ActiveLocale = localeKey

--- @param source table
--- @param target table
--- @param prefix? string
--- @return table
local function flattenLocale(source, target, prefix)
    for key, value in pairs(source) do
        local fullKey = prefix and (prefix .. '.' .. key) or tostring(key)
        if type(value) == 'table' then
            flattenLocale(value, target, fullKey)
        elseif type(value) == 'string' then
            target[fullKey] = value
        end
    end
    return target
end

--[[ English strings fill any key a translation is missing ]]
local fallbackLocale = {}
if localeKey ~= 'en' then
    local raw = LoadResourceFile(resourceName, 'locales/en.json')
    local ok, decoded = pcall(json.decode, raw or '')
    if ok and type(decoded) == 'table' then
        fallbackLocale = flattenLocale(decoded, {})
    end
end

--- Flat translation table for the NUI (active locale merged over English).
--- @return table<string, string>
function GetLocaleTable()
    local merged = {}
    for key, value in pairs(fallbackLocale) do
        merged[key] = value
    end
    for key, value in pairs(lib.getLocales() or {}) do
        merged[key] = value
    end
    return merged
end

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
    local found, retval = pcall(locale, str, ...)
    if found and retval ~= str then
        return retval
    end
    local text = fallbackLocale[str] or fallback
    if text == nil then return str end
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
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
