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

local isServer <const> = IsDuplicityVersion()
function LT.Events.EmitNet(name, ...)
    local eventName = LT.Events.GetEventName(name, true)
    if isServer then
        local target = ...
        if type(target) == 'table' then
            for i = 1, #target do
                if type(target[i]) ~= 'number' then
                    LT.printf(
                        'error',
                        'EmitNet: invalid target type on event (%s) expected table of numbers, got %s',
                        name,
                        type(target[i])
                    )
                    return false
                end
                TriggerClientEvent(eventName, target[i], select(2, ...))
            end
        elseif type(target) == 'number' then
            TriggerClientEvent(eventName, target, select(2, ...))
        else
            LT.printf(
                'error',
                'EmitNet: invalid target type on event (%s) expected table or number, got %s',
                name,
                type(target)
            )
            return false
        end
    else
        TriggerServerEvent(eventName, ...)
    end
end
