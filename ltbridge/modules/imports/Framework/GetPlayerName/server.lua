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
        return player.variables.firstName, player.variables.lastName
    end,
    ['qb-core'] = function(player)
        return player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname
    end,
    ['qbx_core'] = function(player)
        return player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname
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
function LT.Framework.GetPlayerName(source, asFullName)
        if not LT.ltassert(source, 'source is required') then return false end
    local player = LT.Framework.GetPlayer(source)
        if not LT.ltassert(player, 'player not found') then return false end
    local firstname, lastname = adapter(player)
        if not LT.ltassert(firstname, 'player name not found') then return false end
        if not LT.ltassert(lastname, 'player last name not found') then return false end
    if asFullName then
        return firstname .. ' ' .. lastname
    else
        return firstname, lastname
    end
end
