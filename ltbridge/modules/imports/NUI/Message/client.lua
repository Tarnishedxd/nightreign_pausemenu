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

local SendNUIMessage = SendNUIMessage
local function checkTable(tbl)
    for k, v in pairs(tbl) do
        if type(v) == "function" or type(v) == 'thread' then
            return false, ('functions and threads are not supported on NUI messages. (%s : %s)'):format(k, v)
        elseif type(v) == 'table' then
            local success, error = checkTable(v)
            if not success then return false, error end
        end
    end
    return true, nil
end
function LT.NUI.Message(action, data)
        if not LT.ltassert(action, 'action is required.') then return false end
    local payload = {}
    if data ~= nil then
                if not LT.ltassert(type(data) == 'table', 'data must be a table, got %s instead.', type(data)) then return false end
        local success, error = checkTable(data)
                if not LT.ltassert(success, '%s', error) then return false end
        for k, v in pairs(data) do
            payload[k] = v
        end
    end
    payload.action = action
    SendNUIMessage(payload)
end
