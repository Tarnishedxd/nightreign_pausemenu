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
local function adapter(...)
    local fn = adapters[LT.Framework.GetResource()]
    if not fn then
        LT.Framework.MissingFramework()
        return false
    end
    return fn(...)
end
function LT.Framework.IsPlayerLoaded()
    return adapter()
end
