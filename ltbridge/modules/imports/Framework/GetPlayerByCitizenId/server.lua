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
    ['es_extended'] = function(citizenid)
        return ESX.GetPlayerFromIdentifier(citizenid)
    end,
    ['qb-core'] = function(citizenid)
        return QBCore.Functions.GetPlayerByCitizenId(citizenid)
    end,
    ['qbx_core'] = function(citizenid)
        return QBX:GetPlayerByCitizenId(citizenid)
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
function LT.Framework.GetPlayerByCitizenId(citizenid)
        if not LT.ltassert(citizenid, 'citizenid is required') then return false end
    return adapter(citizenid) or nil
end
