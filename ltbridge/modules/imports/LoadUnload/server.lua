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

function LT.OnPlayerLoad(cb)
    local eventName = __LT_RESOURCE_NAME..':server:@LoadUnload:Loaded'
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, cb)
end
function LT.OnPlayerUnload(cb)
    AddEventHandler('playerDropped', cb)
end
