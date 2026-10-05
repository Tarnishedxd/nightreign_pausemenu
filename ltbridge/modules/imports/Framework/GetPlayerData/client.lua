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
        return ESX.GetPlayerData()
    end,
    ['qb-core'] = function()
        return QBCore.Functions.GetPlayerData()
    end,
    ['qbx_core'] = function()
        return QBX:GetPlayerData()
    end,
}
local adapter = adapters[LT.Framework.GetResource()] or function()
    LT.printf('error', 'No supported framework found.')
    return nil
end
function LT.Framework.GetPlayerData()
    return adapter()
end
