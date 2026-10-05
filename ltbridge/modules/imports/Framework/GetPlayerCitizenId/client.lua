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
        return LT.Framework.GetPlayerData().identifier
    end,
    ['qb-core'] = function()
        return LT.Framework.GetPlayerData().citizenid
    end,
    ['qbx_core'] = function()
        return LT.Framework.GetPlayerData().citizenid
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
function LT.Framework.GetPlayerCitizenId()
    return adapter()
end
