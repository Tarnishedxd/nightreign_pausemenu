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

__LT_RESOURCE_NAME = GetCurrentResourceName()
__LT_VERSION = '1.3.5'
__LT_DISABLE_DEBUG = true
local print = print
local format = string.format
function LT.GetBridgeVersion()
    return __LT_VERSION
end
function LT.printf(type, message, ...)
    if __LT_DISABLE_DEBUG and type ~= 'error' then
        return
    end
    local info = debug.getinfo(4, 'Sl')
    local source = info and info.short_src or 'unknown'
    local line = info and info.currentline or -1
    local prefix = {
        error = '^6[LTBridge %s] ^1ERROR:',
        warning = '^6[LTBridge %s] ^3WARNING:',
        info = '^6[LTBridge %s] ^6INFO:',
    }
    source = format(' %s:%d: ', source, line)
    if source:find('modules', 1, true) then
        source = ' '
    end
    local label = prefix[type] or prefix.info
    message = tostring(message)
    print(
        format(label, __LT_VERSION)
        .. source
        .. format(message, ...)
        .. '^7'
    )
end
function LT.ltassert(v, message, ...)
    if not v then
        LT.printf('error', message, ...)
        return false
    end
    return v
end
