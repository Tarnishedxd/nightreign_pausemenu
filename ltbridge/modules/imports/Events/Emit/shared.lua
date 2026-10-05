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
LT.Events = LT.Events or {}

function LT.Events.Emit(name, ...)
    TriggerEvent(LT.Events.GetEventName(name), ...)
end
