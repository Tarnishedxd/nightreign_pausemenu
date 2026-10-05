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

function LT.NUI.Focus(status, cursor)
    SetNuiFocus(status, (cursor == nil and status) or (type(cursor) == "boolean" and cursor))
    TriggerEvent(__LT_RESOURCE_NAME .. ':client:@NUI:FocusChanged', status, cursor)
end
