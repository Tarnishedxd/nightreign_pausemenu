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
LT.Framework = LT.Framework or {}

local frameworkName = nil
local GetResourceState = GetResourceState
ESX = nil
QBCore = nil
QBX = nil
local function isStarted(res)
    return GetResourceState(res) == 'started'
end
local function detectFramework()
    if isStarted('es_extended') then
        ESX = exports.es_extended:getSharedObject()
        frameworkName = 'es_extended'
    elseif isStarted('qb-core') and not isStarted('qbx_core') then
        QBCore = exports['qb-core']:GetCoreObject()
        frameworkName = 'qb-core'
    elseif isStarted('qbx_core') then
        QBX = exports.qbx_core
        frameworkName = 'qbx_core'
    end
end
local lastMissingLog = -1
function LT.Framework.MissingFramework()
    local now = GetGameTimer()
    if lastMissingLog >= 0 and now - lastMissingLog < 10000 then return end
    lastMissingLog = now
    LT.printf('error', 'No supported framework found (es_extended, qb-core or qbx_core). Start it before %s in server.cfg.', __LT_RESOURCE_NAME)
end
function LT.Framework.GetResource()
    -- The framework can start after this resource; keep looking until it is up.
    if not frameworkName then
        detectFramework()
    end
    return frameworkName
end
detectFramework()
