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
LT.Math = LT.Math or {}

function LT.Math.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end
