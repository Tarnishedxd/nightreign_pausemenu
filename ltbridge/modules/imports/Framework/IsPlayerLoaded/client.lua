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
        return ESX.IsPlayerLoaded()
    end,
    ['qb-core'] = function()
        return LocalPlayer.state.isLoggedIn or false
    end,
    ['qbx_core'] = function()
        return LocalPlayer.state.isLoggedIn or false
    end,
}
local adapter = adapters[LT.Framework.GetResource()] or function(...)
    LT.printf('error', 'No supported framework found.')
    return false
end
function LT.Framework.IsPlayerLoaded()
    return adapter()
end
