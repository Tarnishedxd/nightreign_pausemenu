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
LT.Framework = LT.Framework or {}

local adapters = {
    ['es_extended'] = function(source)
        local xPlayer = LT.Framework.GetPlayer(source)
        if not xPlayer then return false end
        local group = xPlayer.getGroup()
        if group == 'admin' or group == 'superadmin' or group == 'god' then
            return true
        end
        return false
    end,
    ['qb-core'] = function(source)
        return QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god') or
            IsPlayerAceAllowed(source, 'command')
    end,
    ['qbx_core'] = function(source)
        return IsPlayerAceAllowed(source, 'admin')
    end,
}
local adapter = adapters[LT.Framework.GetResource()] or function(...)
    LT.printf('error', 'No supported framework found.')
    return nil
end
function LT.Framework.IsFrameworkAdmin(source)
    if not source then
        LT.printf('error', 'source is required')
        return false
    end
    return adapter(source)
end
