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
LT.NUI = LT.NUI or {}

local isNUILoaded = false
local actionToSend = 'ltbridge_check_nui'
RegisterNUICallback('ltbridge:ready', function(_, cb)
    isNUILoaded = true
    if cb then cb('ok') end
end)
function LT.NUI.Check(action)
    if isNUILoaded then return true end
    if action then
        actionToSend = action
    end
    while not isNUILoaded do
        SendNUIMessage({
            action = actionToSend
        })
        Wait(500)
    end
    return true
end
function LT.NUI.IsLoaded()
    return isNUILoaded
end
