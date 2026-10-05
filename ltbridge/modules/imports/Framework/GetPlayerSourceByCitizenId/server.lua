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
    ['es_extended'] = function(player)
        return player.source
    end,
    ['qb-core'] = function(player)
        return player.PlayerData.source
    end,
    ['qbx_core'] = function(player)
        return player.PlayerData.source
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
function LT.Framework.GetPlayerSourceByCitizenId(citizenid)
        if not LT.ltassert(citizenid, 'citizenid is required') then return false end
    local player = LT.Framework.GetPlayerByCitizenId(citizenid)
        if not LT.ltassert(player, 'player not found') then return false end
    return adapter(player) or nil
end
