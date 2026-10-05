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
LT.Events = LT.Events or {}

local isServer <const> = IsDuplicityVersion()
local format = string.format
function LT.Events.GetEventName(name, remote)
    local side
    if remote then
        side = isServer and 'client' or 'server'
    else
        side = isServer and 'server' or 'client'
    end
    return format('%s:%s:%s', __LT_RESOURCE_NAME, side, name)
end
