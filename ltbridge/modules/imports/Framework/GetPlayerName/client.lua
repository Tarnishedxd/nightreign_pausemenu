--[[
 * @license LT Bridge
 * client.lua
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
    ['es_extended'] = function()
        return LT.Framework.GetPlayerData().firstName, LT.Framework.GetPlayerData().lastName
    end,
    ['qb-core'] = function()
        return LT.Framework.GetPlayerData().charinfo.firstname, LT.Framework.GetPlayerData().charinfo.lastname
    end,
    ['qbx_core'] = function()
        return LT.Framework.GetPlayerData().charinfo.firstname, LT.Framework.GetPlayerData().charinfo.lastname
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
function LT.Framework.GetPlayerName(asFullName)
    local firstname, lastname = adapter()
    if not firstname or not lastname then
        LT.printf('error', 'Player name or last name not found.')
        return nil
    end
    if asFullName then
        return firstname .. ' ' .. lastname
    else
        return firstname, lastname
    end
end
