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

function LT.OnPlayerLoad(cb)
    CreateThread(function()
        while not LT.Framework.IsPlayerLoaded() do
            Wait(100)
        end
        cb()
    end)
end
CreateThread(function()
    while not LT.Framework.IsPlayerLoaded() do
        Wait(100)
    end
    TriggerServerEvent(__LT_RESOURCE_NAME..':server:@LoadUnload:Loaded')
end)
