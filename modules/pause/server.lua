local cfg <const> = require 'config.main'
local premiumCfg <const> = cfg.pause.premium or {}
local showPlayerCount <const> = cfg.pause.showPlayerCount == true
local PLAYER_TTL <const> = 60000
-- Only absorbs repeated requests: the client asks at most every 8 s, and money spent a moment ago
-- must already show when the menu opens again.
local MONEY_TTL <const> = 5000

local playerCount = {
    at = nil,
    count = 0,
    max = 48,
}

local money = {}
local premiumWarned = false

--- @param source number
--- @return number|nil
local function premiumPoints(source)
    if premiumCfg.enabled ~= true or type(premiumCfg.get) ~= 'function' then return nil end
    local ok, result, extra = pcall(premiumCfg.get, source)
    -- Some exports answer `ok, amount`: take the number that follows a boolean.
    if ok and type(result) == 'boolean' then result = extra end
    local value = ok and tonumber(result) or nil
    if value and (value ~= value or math.abs(value) == math.huge) then value = nil end
    if not value then
        if not premiumWarned then
            premiumWarned = true
            if ok then
                LT.Debug.Error('config.pause.premium.get returned no number for player %s, premium points are hidden for them. If this happens for everyone, put your coin shop export in it or set premium.enabled = false.', tostring(source))
            else
                LT.Debug.Error('config.pause.premium.get failed: %s', tostring(result))
            end
        end
        return nil
    end
    return math.floor(value)
end

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
--- @return number|nil premium
local function playerMoney(source)
    local now = GetGameTimer()
    local row = money[source]
    if row and now - row.at < MONEY_TTL then
        return row.cash, row.bank, row.premium
    end

    row = {
        at = now,
        cash = LT.Framework.GetMoney(source, 'cash') or 0,
        bank = LT.Framework.GetMoney(source, 'bank') or 0,
        premium = premiumPoints(source),
    }
    money[source] = row
    return row.cash, row.bank, row.premium
end

lib.callback.register(_e('pause:header'), function(source)
    local cash, bank, premium = playerMoney(source)
    local header = {
        cash = cash,
        bank = bank,
        premium = premium,
    }
    if showPlayerCount then
        header.players, header.maxPlayers = countPlayers()
    end
    return header
end)

LT.OnPlayerUnload(function()
    money[source] = nil
end)
