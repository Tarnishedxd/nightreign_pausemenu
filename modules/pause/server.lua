local PLAYER_TTL <const> = 60000
local MONEY_TTL <const> = 35000

local playerCount = {
    at = nil,
    count = 0,
    max = 48,
}

local money = {}

local function countPlayers()
    local now = GetGameTimer()
    -- `at` starts unset: the server timer starts at 0, so 0 would serve "0 players" for the first minute.
    if playerCount.at and now - playerCount.at < PLAYER_TTL then
        return playerCount.count, playerCount.max
    end

    local players = LT.Framework.GetPlayers() or {}
    local count = #players
    if count == 0 then
        for _ in pairs(players) do
            count = count + 1
        end
    end

    playerCount.at = now
    playerCount.count = count
    playerCount.max = GetConvarInt('sv_maxclients', 48)
    return playerCount.count, playerCount.max
end

--- @param source number
--- @return number cash
--- @return number bank
local function playerMoney(source)
    local now = GetGameTimer()
    local row = money[source]
    if row and now - row.at < MONEY_TTL then
        return row.cash, row.bank
    end

    row = {
        at = now,
        cash = LT.Framework.GetMoney(source, 'cash') or 0,
        bank = LT.Framework.GetMoney(source, 'bank') or 0,
    }
    money[source] = row
    return row.cash, row.bank
end

lib.callback.register(_e('pause:header'), function(source)
    local count, maxPlayers = countPlayers()
    local cash, bank = playerMoney(source)
    return {
        cash = cash,
        bank = bank,
        players = count,
        maxPlayers = maxPlayers,
    }
end)

LT.OnPlayerUnload(function()
    money[source] = nil
end)
