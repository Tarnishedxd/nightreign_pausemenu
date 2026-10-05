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

function LT.Framework.GetPlayers()
    LT.Framework.GetResource()
    if ESX then
        local players = ESX.GetExtendedPlayers()
        local playerList = {}
        for _, xPlayer in pairs(players) do
            table.insert(playerList, xPlayer.source)
        end
        return playerList
    elseif QBCore then
        local players = QBCore.Functions.GetPlayers()
        local playerList = {}
        for _, src in pairs(players) do
            table.insert(playerList, src)
        end
        return playerList
    elseif QBX then
        local players = QBX:GetQBPlayers()
        local playerList = {}
        for src, _ in pairs(players) do
            table.insert(playerList, src)
        end
        return playerList
    end
    return {}
end
