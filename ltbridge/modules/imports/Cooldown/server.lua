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
LT.Cooldown = LT.Cooldown or {}

local os_time = os.time
local lastTriggerTime = {}
function LT.Cooldown.Start(identifier, key, duration)
    if not identifier or not key then return end
    local identifierSrc = tostring(identifier)
    if not lastTriggerTime[identifierSrc] then lastTriggerTime[identifierSrc] = {} end
    local durationInSeconds = duration / 1000
    lastTriggerTime[identifierSrc][key] = os_time() + durationInSeconds
end
function LT.Cooldown.Check(identifier, key)
    if not identifier or not key then return false end
    local identifierSrc = tostring(identifier)
    if not lastTriggerTime[identifierSrc] or not lastTriggerTime[identifierSrc][key] then
        return false
    end
    if os_time() < lastTriggerTime[identifierSrc][key] then
        return true
    end
    lastTriggerTime[identifierSrc][key] = nil
    return false
end
function LT.Cooldown.Remaining(identifier, key)
    if not identifier or not key then return 0 end
    local identifierSrc = tostring(identifier)
    if not lastTriggerTime[identifierSrc] or not lastTriggerTime[identifierSrc][key] then
        return 0
    end
    local remaining = lastTriggerTime[identifierSrc][key] - os_time()
    if remaining > 0 then
        return math.floor(remaining * 1000)
    end
    lastTriggerTime[identifierSrc][key] = nil
    return 0
end
function LT.Cooldown.Clear(identifier, key)
    if not identifier or not key then return end
    local identifierSrc = tostring(identifier)
    if lastTriggerTime[identifierSrc] then
        lastTriggerTime[identifierSrc][key] = nil
    end
end
CreateThread(function()
    while true do
        if next(lastTriggerTime) then
            for identifier, data in pairs(lastTriggerTime) do
                for key, time in pairs(data) do
                    if os_time() > time then
                        lastTriggerTime[identifier][key] = nil
                    end
                end
            end
        else
            Wait(120000) 
        end
        Wait(60000)      
    end
end)
