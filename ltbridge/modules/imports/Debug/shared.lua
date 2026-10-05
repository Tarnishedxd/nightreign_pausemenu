--[[
 * @license LT Bridge
 * shared.lua
 *
 * Copyright (c) LT Scripts.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]

--- @diagnostic disable
LT = LT or {}
LT.Debug = LT.Debug or {}

local debugMode = 1
local print = print
local string_format = string.format
local tonumber = tonumber
local debugTypes <const> = {
    ['success'] = { mode = 3, color = 2 },
    ['error'] = { mode = 1, color = 1 },
    ['warning'] = { mode = 2, color = 3 },
    ['info'] = { mode = 3, color = 4 },
    ['verbose'] = { mode = 4, color = 5 },
}
local function handleException(result, value)
    if type(value) == 'function' then
        return tostring(value)
    end
    return result
end
local function format(message, ...)
    local data = { ... }
    for i = 1, #data do
        local v = data[i]
        if type(v) == "table" then
            data[i] = json.encode(v, {
                indent = true,
                exception = handleException
            })
        elseif type(v) == "boolean" then
            data[i] = v and "true" or "false"
        elseif type(v) ~= "string" then
            data[i] = tostring(v)
        end
    end
    return string_format(message, table.unpack(data))
end
function LT.Debug.SetMode(mode)
    debugMode = mode or 1
end
function LT.Debug.Detailed(message, type, ...)
    if not type then type = 'verbose' end
    local data = debugTypes[type]
    if not data then return end
    if tonumber(debugMode) < tonumber(data.mode) then return end
    local info = debug.getinfo(2, 'Sl')
    local source = info and info.short_src or 'unknown'
    local line = info and info.currentline or -1
    print(string_format('^%d[%s] %s:%d: ^7%s^7', data.color, type:upper(), source, line, format(message, ...)))
end
function LT.Debug.Print(message, type, ...)
    if not type then type = 'verbose' end
    local data = debugTypes[type]
    if not data then return end
    if tonumber(debugMode) < tonumber(data.mode) then return end
    print(string_format('^%d[%s]^7 %s^7', data.color, type:upper(), format(message, ...)))
end
function LT.Debug.Info(message, ...)
    LT.Debug.Print(message, 'info', ...)
end
function LT.Debug.Success(message, ...)
    LT.Debug.Print(message, 'success', ...)
end
function LT.Debug.Error(message, ...)
    LT.Debug.Print(message, 'error', ...)
end
function LT.Debug.Warn(message, ...)
    LT.Debug.Print(message, 'warning', ...)
end
function LT.Debug.Verbose(message, ...)
    LT.Debug.Print(message, 'verbose', ...)
end
