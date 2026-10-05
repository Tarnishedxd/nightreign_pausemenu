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

local RegisterNUICallback = RegisterNUICallback

function LT.NUI.Callback(name, cb)
    RegisterNUICallback(name, cb)
end
