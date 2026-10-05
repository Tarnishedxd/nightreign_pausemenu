local sessionAt <const> = GetGameTimer()

local skillIds <const> = {
    'stamina',
    'shooting',
    'strength',
    'stealth',
    'flying',
    'driving',
    'lung',
}

local skillStats <const> = {
    stamina = 'STAMINA',
    shooting = 'SHOOTING_ABILITY',
    strength = 'STRENGTH',
    stealth = 'STEALTH_ABILITY',
    flying = 'FLYING_ABILITY',
    driving = 'DRIVING_ABILITY',
    lung = 'LUNG_CAPACITY',
}

--- @param value number
--- @return integer
local function clampSkill(value)
    return LT.Math.Clamp(math.floor(tonumber(value) or 0), 0, 100)
end

--- @param name string
--- @return number
local function readInt(name)
    local ok, value = StatGetInt(joaat(name), -1)
    if ok == false or type(value) ~= 'number' then return 0 end
    return value
end

--- @param name string
--- @return number
local function readNumber(name)
    local value = readInt(name)
    if value ~= 0 then return value end
    local ok, floatValue = StatGetFloat(joaat(name), -1)
    if ok == false or type(floatValue) ~= 'number' then return 0 end
    return floatValue
end

--- @return integer
local function charIndex()
    local ok, index = StatGetInt(`MPPLY_LAST_MP_CHAR`, -1)
    if ok ~= false and (index == 0 or index == 1) then return index end
    return 0
end

--- @return table
local function snapshot()
    local prefix <const> = ('MP%d_'):format(charIndex())
    local skills = {}
    for index = 1, #skillIds do
        local id <const> = skillIds[index]
        skills[index] = {
            id = id,
            value = clampSkill(readInt(prefix .. skillStats[id])),
        }
    end

    local elapsed = GetGameTimer() - sessionAt
    if elapsed < 0 then elapsed = 0 end

    return {
        skills = skills,
        career = {
            session = elapsed,
            played = math.max(0, readInt(prefix .. 'TOTAL_PLAYING_TIME')),
            deaths = math.max(0, math.floor(readInt(prefix .. 'DEATHS'))),
            onFoot = math.max(0, readNumber(prefix .. 'DIST_WALKING')),
            driven = math.max(0, readNumber(prefix .. 'DIST_DRIVING_CAR')),
        },
    }
end

_G.Stats = {
    snapshot = snapshot,
}
