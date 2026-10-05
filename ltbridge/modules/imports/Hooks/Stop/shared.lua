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
LT.Hooks = LT.Hooks or {}

function LT.Hooks.Stop(cb, resource)
    local checkResource = resource or __LT_RESOURCE_NAME
    AddEventHandler('onResourceStop', function (res)
        if res ~= checkResource then return end
        cb()
    end)
end
