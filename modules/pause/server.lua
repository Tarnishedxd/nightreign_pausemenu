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

--- @return string[]
local function premiumResources()
    local value = premiumCfg.resource
    if type(value) == 'string' then return { value } end
    if type(value) == 'table' then return value end
    return {}
end

--- @param source number
--- @return boolean ok
--- @return any result
--- @return any extra
local function readPremium(source)
    if type(premiumCfg.get) == 'function' then
        return pcall(premiumCfg.get, source)
    end
    local export = premiumCfg.export
    if type(export) ~= 'string' or export == '' then return true, nil end
    local failure
    local resources = premiumResources()
    for i = 1, #resources do
        local resource = resources[i]
        -- Checked on every read: the coin shop may start after this resource, or restart.
        if type(resource) == 'string' and resource ~= '' and GetResourceState(resource) == 'started' then
            local ok, result, extra = pcall(function()
                local api = exports[resource]
                return api[export](api, source)
            end)
            if ok then return true, result, extra end
            failure = result
        end
    end
    if failure ~= nil then return false, failure end
    return true, nil
end

--- Optional add-on: a missing resource or export, or an error in it, only hides the points.
--- @param source number
--- @return number|nil
local function premiumPoints(source)
    if premiumCfg.enabled ~= true then return nil end
    local ok, result, extra = readPremium(source)
    -- Some exports answer `ok, amount`: take the number that follows a boolean.
    if ok and type(result) == 'boolean' then result = extra end
    local value = ok and tonumber(result) or nil
    if value and (value ~= value or math.abs(value) == math.huge) then value = nil end
    if value then return math.floor(value) end
    if not ok and not premiumWarned then
        premiumWarned = true
        LT.Debug.Warn('premium points are hidden, reading them failed: %s', tostring(result))
    end
    return nil
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
