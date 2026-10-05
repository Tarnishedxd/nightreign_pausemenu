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
    ['es_extended'] = function(player, account)
        if account == 'cash' then
            return player.getMoney()
        elseif account == 'bank' then
            return player.getAccount('bank').money
        elseif account == 'black' or account == 'black_money' then
            return player.getAccount('black_money').money
        end
    end,
    ['qb-core'] = function(player, account)
        return player.PlayerData.money[account] or 0
    end,
    ['qbx_core'] = function(player, account)
        return player.PlayerData.money[account] or 0
    end,
}
local function adapter(...)
    local fn = adapters[LT.Framework.GetResource()]
    if not fn then
        LT.Framework.MissingFramework()
        return nil
    end
    return fn(...)
end
function LT.Framework.GetMoney(source, account)
        if not LT.ltassert(source, 'source is required') then return false end
    local player = LT.Framework.GetPlayer(source)
        if not LT.ltassert(player, 'player not found') then return false end
    return adapter(player, account or 'cash') or 0
end
