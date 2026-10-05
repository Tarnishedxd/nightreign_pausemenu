--[[
 * @license LT Bridge
 * server.lua
 *
 * Copyright (c) LT Scripts.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
]]

--- @diagnostic disable
LT = LT or {}
LT.Framework = LT.Framework or {}

local adapters = {
    ['es_extended'] = function(source)
        return ESX.GetPlayerFromId(source)
    end,
    ['qb-core'] = function(source)
        return QBCore.Functions.GetPlayer(source)
    end,
    ['qbx_core'] = function(source)
        return QBX:GetPlayer(source)
    end,
}
local function adapter(...)
    local fn = adapters[LT.Framework.GetResource()]
    if not fn then
        LT.Framework.MissingFramework()
        return nil
    end
    return fn(...)
end
function LT.Framework.GetPlayer(source)
        if not LT.ltassert(source, 'source is required') then return false end
    return adapter(source)
end
