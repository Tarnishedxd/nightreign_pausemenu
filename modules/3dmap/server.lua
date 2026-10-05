local cfg <const> = require 'config.main'
local mapCfg <const> = cfg.threeDMap or {}

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- @param value any
--- @return table
local function asTable(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end
    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then return decoded end
    return {}
end

--- @param list table
--- @param identifier string
--- @return boolean
--- @return integer|nil
local function findIdentifier(list, identifier)
    for i = 1, #list do
        local entry = list[i]
        if type(entry) == 'table' and entry.identifier == identifier then
            return true, i
        end
    end
    return false
end

--- @param list table
--- @param identifier string
--- @return table
local function withoutIdentifier(list, identifier)
    local kept = {}
    for i = 1, #list do
        local entry = list[i]
        if type(entry) ~= 'table' or entry.identifier ~= identifier then
            kept[#kept + 1] = entry
        end
    end
    return kept
end

--- @param list table
--- @return { name: string, identifier: string }[]
local function sharePeople(list)
    local people = {}
    for i = 1, #list do
        local entry = list[i]
        local name = type(entry) == 'table' and entry.name or nil
        local identifier = type(entry) == 'table' and entry.identifier or nil
        if type(name) == 'string' and name ~= '' and type(identifier) == 'string' and identifier ~= '' then
            people[#people + 1] = { name = name, identifier = identifier }
        end
    end
    return people
end

--- @param list table
--- @return string
local function encodeList(list)
    if type(list) ~= 'table' or #list == 0 then return '[]' end
    return json.encode(list)
end

--- @param row table
--- @return table
local function pointFrom(row)
    local coords = asTable(row.coords)
    return {
        id = row.id,
        label = row.label,
        sprite = row.sprite,
        spriteId = tonumber(row.sprite_id) or 1,
        colour = row.colour,
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0,
        showOn2d = row.show_on_2d == true or row.show_on_2d == 1,
        blipColour = tonumber(row.blip_colour) or 3,
        scale = tonumber(row.scale) or 0.8,
        shortRange = row.short_range == nil or row.short_range == true or row.short_range == 1,
    }
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- DATABASE
-- ════════════════════════════════════════════════════════════════════════════════════════════

---@class Database
---@field ready boolean
---@field new fun(self: Database): Database
---@field wait fun(self: Database): boolean
---@field fetch fun(self: Database, identifier: string): table
---@field count fun(self: Database, identifier: string): integer
---@field create fun(self: Database, identifier: string, label: string, sprite: string, spriteId: integer, colour: string, coords: table, showOn2d: boolean, blipColour: integer, scale: number, shortRange: boolean)
---@field row fun(self: Database, owner: string, id: integer): table|nil
---@field rowById fun(self: Database, id: integer): table|nil
---@field delete fun(self: Database, owner: string, id: integer): table|nil
---@field writeLists fun(self: Database, id: integer, shares: table, requests: table)
---@field missing boolean
local DatabaseClass = {}
DatabaseClass.__index = DatabaseClass

local MARKERS_SCHEMA <const> = [[
    CREATE TABLE IF NOT EXISTS nightreign_pausemenu_markers (
        id INT NOT NULL AUTO_INCREMENT,
        owner VARCHAR(150) NOT NULL,
        label VARCHAR(80) NOT NULL,
        sprite VARCHAR(64) NOT NULL,
        sprite_id INT NOT NULL DEFAULT 1,
        colour VARCHAR(16) NOT NULL,
        coords JSON NOT NULL,
        show_on_2d TINYINT(1) NOT NULL DEFAULT 0,
        blip_colour INT NOT NULL DEFAULT 3,
        scale FLOAT NOT NULL DEFAULT 0.8,
        short_range TINYINT(1) NOT NULL DEFAULT 1,
        shares JSON NOT NULL,
        requests JSON NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        INDEX idx_owner (owner)
    )
]]

local GLOBALS_SCHEMA <const> = [[
    CREATE TABLE IF NOT EXISTS nightreign_pausemenu_global_markers (
        id INT NOT NULL AUTO_INCREMENT,
        category VARCHAR(80) NOT NULL,
        label VARCHAR(80) NOT NULL,
        sprite VARCHAR(64) NOT NULL,
        sprite_id INT NOT NULL DEFAULT 1,
        colour VARCHAR(16) NOT NULL,
        coords JSON NOT NULL,
        show_on_2d TINYINT(1) NOT NULL DEFAULT 0,
        blip_colour INT NOT NULL DEFAULT 3,
        scale FLOAT NOT NULL DEFAULT 0.8,
        short_range TINYINT(1) NOT NULL DEFAULT 1,
        created_by VARCHAR(150) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        INDEX idx_category (category)
    )
]]

--- @return Database
function DatabaseClass:new()
    local self = setmetatable({ ready = false, missing = false }, DatabaseClass)

    if MySQL == nil then
        self.missing = true
        LT.Debug.Error('oxmysql is not loaded.')
    end

    return self
end

--- @return boolean
function DatabaseClass:wait()
    if self.missing then return false end
    local tries = 0
    while not self.ready and tries < 30 do
        tries += 1
        Wait(100)
    end
    return self.ready
end

--- @param identifier string
--- @return table
function DatabaseClass:fetch(identifier)
    local rows = MySQL.query.await([[
        SELECT id, owner, label, sprite, sprite_id, colour, coords,
               show_on_2d, blip_colour, scale, short_range, shares, requests
        FROM nightreign_pausemenu_markers
        WHERE owner = ?
           OR JSON_SEARCH(shares, 'one', ?, NULL, '$[*].identifier') IS NOT NULL
           OR JSON_SEARCH(requests, 'one', ?, NULL, '$[*].identifier') IS NOT NULL
    ]], { identifier, identifier, identifier }) or {}

    local markers, requests = {}, {}

    for i = 1, #rows do
        local row = rows[i]
        local shares = asTable(row.shares)
        local pending = asTable(row.requests)

        if row.owner == identifier then
            local point = pointFrom(row)
            point.kind = 'mine'
            point.shares = sharePeople(shares)
            markers[#markers + 1] = point
        elseif findIdentifier(shares, identifier) then
            local point = pointFrom(row)
            point.kind = 'shared'
            local _, shareIndex = findIdentifier(shares, identifier)
            local entry = shareIndex and shares[shareIndex] or nil
            if type(entry) == 'table' then
                point.from = type(entry.from) == 'string' and entry.from or ''
                point.sharedAt = tonumber(entry.at)
            end
            markers[#markers + 1] = point
        end

        local incoming, index = findIdentifier(pending, identifier)
        if incoming and index then
            local entry = pending[index]
            requests[#requests + 1] = {
                id = row.id,
                label = row.label,
                sprite = row.sprite,
                blipColour = tonumber(row.blip_colour) or 3,
                from = type(entry) == 'table' and entry.name or '',
            }
        end
    end

    return { markers = markers, requests = requests }
end

--- @param identifier string
--- @return integer
function DatabaseClass:count(identifier)
    return MySQL.scalar.await('SELECT COUNT(*) FROM nightreign_pausemenu_markers WHERE owner = ?', { identifier }) or 0
end

--- @param identifier string
--- @param label string
--- @param sprite string
--- @param spriteId integer
--- @param colour string
--- @param coords table
--- @param showOn2d boolean
--- @param blipColour integer
--- @param scale number
--- @param shortRange boolean
function DatabaseClass:create(identifier, label, sprite, spriteId, colour, coords, showOn2d, blipColour, scale, shortRange)
    MySQL.insert.await([[
        INSERT INTO nightreign_pausemenu_markers
            (owner, label, sprite, sprite_id, colour, coords, show_on_2d, blip_colour, scale, short_range, shares, requests)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '[]', '[]')
    ]], {
        identifier,
        label,
        sprite,
        spriteId,
        colour,
        json.encode(coords),
        showOn2d and 1 or 0,
        blipColour,
        scale,
        shortRange and 1 or 0,
    })
end

--- @param owner string
--- @param id integer
--- @return table|nil
function DatabaseClass:row(owner, id)
    return MySQL.single.await(
        'SELECT id, shares, requests FROM nightreign_pausemenu_markers WHERE id = ? AND owner = ?',
        { id, owner }
    )
end

--- @param id integer
--- @return table|nil
function DatabaseClass:rowById(id)
    return MySQL.single.await(
        'SELECT id, owner, shares, requests FROM nightreign_pausemenu_markers WHERE id = ?',
        { id }
    )
end

--- @param owner string
--- @param id integer
--- @return table|nil
function DatabaseClass:delete(owner, id)
    local row = self:row(owner, id)
    if not row then return nil end
    MySQL.update.await('DELETE FROM nightreign_pausemenu_markers WHERE id = ? AND owner = ?', { id, owner })
    return row
end

--- @param id integer
--- @param shares table
--- @param requests table
function DatabaseClass:writeLists(id, shares, requests)
    MySQL.update.await(
        'UPDATE nightreign_pausemenu_markers SET shares = ?, requests = ? WHERE id = ?',
        { encodeList(shares), encodeList(requests), id }
    )
end

--- @return table[]
function DatabaseClass:fetchGlobals()
    local rows = MySQL.query.await([[
        SELECT id, category, label, sprite, sprite_id, colour, coords,
               show_on_2d, blip_colour, scale, short_range
        FROM nightreign_pausemenu_global_markers
        ORDER BY category ASC, id ASC
    ]]) or {}

    local globals = {}
    for i = 1, #rows do
        local row = rows[i]
        local coords = asTable(row.coords)
        local x = tonumber(coords.x) or tonumber(coords[1])
        local y = tonumber(coords.y) or tonumber(coords[2])
        local z = tonumber(coords.z) or tonumber(coords[3])
        if x and y and z and type(row.category) == 'string' and row.category ~= '' then
            globals[#globals + 1] = {
                id = row.id,
                category = row.category,
                label = row.label,
                sprite = row.sprite,
                spriteId = tonumber(row.sprite_id) or 1,
                colour = row.colour,
                x = x + 0.0,
                y = y + 0.0,
                z = z + 0.0,
                showOn2d = row.show_on_2d == true or row.show_on_2d == 1,
                blipColour = tonumber(row.blip_colour) or 3,
                scale = tonumber(row.scale) or 0.8,
                shortRange = row.short_range == nil or row.short_range == true or row.short_range == 1,
            }
        end
    end
    return globals
end

--- @param category string
--- @param label string
--- @param sprite string
--- @param spriteId integer
--- @param colour string
--- @param coords table
--- @param showOn2d boolean
--- @param blipColour integer
--- @param scale number
--- @param shortRange boolean
--- @param createdBy string|nil
--- @return integer
function DatabaseClass:createGlobal(category, label, sprite, spriteId, colour, coords, showOn2d, blipColour, scale, shortRange, createdBy)
    return MySQL.insert.await([[
        INSERT INTO nightreign_pausemenu_global_markers
            (category, label, sprite, sprite_id, colour, coords, show_on_2d, blip_colour, scale, short_range, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        category,
        label,
        sprite,
        spriteId,
        colour,
        json.encode(coords),
        showOn2d and 1 or 0,
        blipColour,
        scale,
        shortRange and 1 or 0,
        createdBy,
    })
end

--- @param id integer
--- @return boolean
function DatabaseClass:deleteGlobal(id)
    local affected = MySQL.update.await('DELETE FROM nightreign_pausemenu_global_markers WHERE id = ?', { id })
    return (tonumber(affected) or 0) > 0
end

local db

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- LIMITS
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- @param value any
--- @return string|nil
local function cleanLabel(value)
    if type(value) ~= 'string' then return nil end
    local label = value:match('^%s*(.-)%s*$')
    if not label or label == '' or #label > 48 then return nil end
    return label
end

--- @param value any
--- @return string|nil
local function cleanSprite(value)
    if type(value) ~= 'string' then return nil end
    if #value > 64 or not value:match('^radar_[%w_]+$') then return nil end
    return value
end

--- @param value any
--- @return string|nil
local function cleanColour(value)
    if type(value) ~= 'string' then return nil end
    local colour = value:lower()
    if not colour:match('^#%x%x%x%x%x%x$') then return nil end
    return colour
end

--- @param value any
--- @return table|nil
local function cleanCoords(value)
    local kind = type(value)
    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'vector4' then return nil end
    local x = tonumber(value.x) or tonumber(value[1])
    local y = tonumber(value.y) or tonumber(value[2])
    local z = tonumber(value.z) or tonumber(value[3])
    if not x or not y or not z then return nil end
    return { x = x, y = y, z = z }
end

--- @param value any
--- @return integer|nil
local function cleanSpriteId(value)
    local id = tonumber(value)
    if not id then return nil end
    id = math.floor(id)
    if id < 0 or id > 1000 then return nil end
    return id
end

--- @param value any
--- @return integer|nil
local function cleanBlipColour(value)
    local id = tonumber(value)
    if not id then return nil end
    id = math.floor(id)
    if id < 0 or id > 85 then return nil end
    return id
end

--- @param value any
--- @return number|nil
local function cleanScale(value)
    local scale = tonumber(value)
    if not scale then return nil end
    if scale < 0.1 or scale > 4.0 then return nil end
    return scale + 0.0
end

--- @param src number
--- @return boolean
local function isAdmin(src)
    if mapCfg.adminCreator == false then return false end
    if LT.Framework.IsFrameworkAdmin(src) then return true end
    local ace = type(mapCfg.adminAce) == 'string' and mapCfg.adminAce or 'nightreign_pausemenu.globalblips'
    return IsPlayerAceAllowed(tostring(src), ace) == true
end

local function broadcastGlobals()
    if not db or not db:wait() then return end
    emitNet('3dmap:globals', -1, db:fetchGlobals())
end

--- @param identifier string
--- @return integer|nil
local function sourceOf(identifier)
    -- Offline owners are normal here; skip the bridge lookup that logs an error for them.
    if not LT.Framework.GetPlayerByCitizenId(identifier) then return nil end
    return LT.Framework.GetPlayerSourceByCitizenId(identifier)
end

--- @param src number
--- @return string|nil
local function citizenId(src)
    local identifier = LT.Framework.GetPlayerCitizenId(src)
    if type(identifier) ~= 'string' or identifier == '' then return nil end
    return identifier
end

--- @param src number
--- @return string
local function playerName(src)
    local name = LT.Framework.GetPlayerName(src, true)
    if type(name) == 'string' and name ~= '' then return name end
    return ('%s'):format(src)
end

--- @param key string
--- @return table
local function fail(key)
    return { error = key }
end

--- @param identifier string
--- @param noticeKey? string
--- @return table
local function sheet(identifier, noticeKey)
    local payload = db:fetch(identifier)
    if noticeKey then payload.notice = noticeKey end
    return payload
end

--- @param identifier string
local function sync(identifier)
    local src = sourceOf(identifier)
    if not src then return end
    if not db:wait() then return end
    emitNet('3dmap:sync', src, db:fetch(identifier))
end

--- @param row table
--- @param owner string
local function syncAudience(row, owner)
    local seen = { [owner] = true }
    local lists = { asTable(row.shares), asTable(row.requests) }
    for n = 1, #lists do
        local list = lists[n]
        for i = 1, #list do
            local entry = list[i]
            local identifier = type(entry) == 'table' and entry.identifier or nil
            if type(identifier) == 'string' and identifier ~= '' and not seen[identifier] then
                seen[identifier] = true
                sync(identifier)
            end
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ════════════════════════════════════════════════════════════════════════════════════════════

lib.callback.register(_e('3dmap:fetch'), function(src)
    local identifier = citizenId(src)
    if not db or not identifier or not db:wait() then
        return { markers = {}, requests = {} }
    end
    return db:fetch(identifier)
end)

lib.callback.register(_e('3dmap:create'), function(src, data)
    local identifier = citizenId(src)
    if not identifier or type(data) ~= 'table' or not db:wait() then return fail('invalid') end
    if mapCfg.playerCreator == false then return fail('noPermission') end

    local label = cleanLabel(data.label)
    local sprite = cleanSprite(data.sprite)
    local colour = cleanColour(data.colour)
    local coords = cleanCoords(data.coords)
    local blipColour = cleanBlipColour(data.blipColour)
    if not label or not sprite or not colour or not coords or blipColour == nil then return fail('invalid') end

    local spriteId = cleanSpriteId(data.spriteId) or 1
    local showOn2d = data.showOn2d == true
    local scale = 0.8
    local shortRange = true
    if showOn2d then
        local nextScale = cleanScale(data.scale)
        if nextScale == nil then return fail('invalid') end
        scale = nextScale
        shortRange = data.shortRange ~= false
    end

    if LT.Cooldown.Check(identifier, '3dmap:create') then return fail('cooldown') end
    local saved, result = pcall(function()
        if db:count(identifier) >= (mapCfg.maxMarkers or 16) then return fail('max') end
        db:create(identifier, label, sprite, spriteId, colour, coords, showOn2d, blipColour, scale, shortRange)
        LT.Cooldown.Start(identifier, '3dmap:create', mapCfg.createCooldown or 60000)
        return sheet(identifier)
    end)
    if not saved then
        LT.Debug.Error('Marker save failed: %s', result)
        return fail('invalid')
    end
    return result
end)

lib.callback.register(_e('3dmap:fetchGlobals'), function(src)
    if not db or not db:wait() then
        return { globals = {}, isAdmin = false }
    end
    return {
        globals = db:fetchGlobals(),
        isAdmin = isAdmin(src),
    }
end)

lib.callback.register(_e('3dmap:createGlobal'), function(src, data)
    if not isAdmin(src) or type(data) ~= 'table' or not db:wait() then return fail('noPermission') end

    local identifier = citizenId(src)
    local category = cleanLabel(data.category)
    local label = cleanLabel(data.label)
    local point = cleanCoords(data.coords)
    local sprite = cleanSprite(data.sprite)
    local colour = cleanColour(data.colour)
    if not category or not label or not point or not sprite or not colour then return fail('invalid') end

    local spriteId = cleanSpriteId(data.spriteId) or 1
    local blipColour = cleanBlipColour(data.blipColour)
    if blipColour == nil then return fail('invalid') end
    local showOn2d = data.showOn2d == true
    local scale = 0.8
    local shortRange = true
    if showOn2d then
        local nextScale = cleanScale(data.scale)
        if nextScale == nil then return fail('invalid') end
        scale = nextScale
        shortRange = data.shortRange ~= false
    end

    local saved, result = pcall(function()
        db:createGlobal(
            category,
            label,
            sprite,
            spriteId,
            colour,
            point,
            showOn2d,
            blipColour,
            scale,
            shortRange,
            identifier
        )
        return { globals = db:fetchGlobals(), isAdmin = true }
    end)
    if not saved then
        LT.Debug.Error('Global blip save failed: %s', result)
        return fail('invalid')
    end
    if type(result) == 'table' and result.error then return result end
    broadcastGlobals()
    return result
end)

lib.callback.register(_e('3dmap:deleteGlobal'), function(src, data)
    if not isAdmin(src) or type(data) ~= 'table' or not db:wait() then return fail('noPermission') end
    local id = tonumber(data.id)
    if not id or not db:deleteGlobal(id) then return fail('invalid') end

    local globals = db:fetchGlobals()
    broadcastGlobals()
    return { globals = globals, isAdmin = true }
end)

lib.callback.register(_e('3dmap:delete'), function(src, data)
    local identifier = citizenId(src)
    local id = type(data) == 'table' and tonumber(data.id) or nil
    if not identifier or not id or not db:wait() then return end

    local row = db:delete(identifier, id)
    if not row then return end
    syncAudience(row, identifier)
    return sheet(identifier)
end)

lib.callback.register(_e('3dmap:share'), function(src, data)
    local identifier = citizenId(src)
    local id = type(data) == 'table' and tonumber(data.id) or nil
    local target = type(data) == 'table' and tonumber(data.target) or nil
    if not identifier or not id or not db:wait() then return fail('invalid') end
    if not target or target ~= math.floor(target) or target == src then return fail('player') end
    if not GetPlayerName(target) then return fail('player') end

    local targetId = citizenId(target)
    if not targetId or targetId == identifier then return fail('player') end
    if LT.Cooldown.Check(identifier, '3dmap:share') then return fail('shareCooldown') end

    local row = db:row(identifier, id)
    if not row then return fail('invalid') end

    local shares = asTable(row.shares)
    local requests = asTable(row.requests)
    if findIdentifier(shares, targetId) or findIdentifier(requests, targetId) then return fail('already') end

    requests[#requests + 1] = { identifier = targetId, name = playerName(src) }
    db:writeLists(id, shares, requests)
    LT.Cooldown.Start(identifier, '3dmap:share', mapCfg.shareCooldown or 30000)
    sync(targetId)
    return sheet(identifier, 'sent')
end)

lib.callback.register(_e('3dmap:unshare'), function(src, data)
    local identifier = citizenId(src)
    local id = type(data) == 'table' and tonumber(data.id) or nil
    local targetId = type(data) == 'table' and data.identifier or nil
    if not identifier or not id or type(targetId) ~= 'string' or targetId == '' or not db:wait() then
        return fail('invalid')
    end

    local row = db:row(identifier, id)
    if not row then return fail('invalid') end

    local shares = asTable(row.shares)
    if not findIdentifier(shares, targetId) then return fail('invalid') end

    db:writeLists(id, withoutIdentifier(shares, targetId), asTable(row.requests))
    sync(targetId)
    return sheet(identifier)
end)

lib.callback.register(_e('3dmap:accept'), function(src, data)
    local identifier = citizenId(src)
    local id = type(data) == 'table' and tonumber(data.id) or nil
    if not identifier or not id or not db:wait() then return end

    local row = db:rowById(id)
    if not row then return end

    local requests = asTable(row.requests)
    local pending, requestIndex = findIdentifier(requests, identifier)
    if not pending or not requestIndex then return end

    local request = requests[requestIndex]
    local fromName = type(request) == 'table' and type(request.name) == 'string' and request.name or ''

    local shares = asTable(row.shares)
    if not findIdentifier(shares, identifier) then
        shares[#shares + 1] = {
            identifier = identifier,
            name = playerName(src),
            from = fromName,
            at = os.time(),
        }
    end

    db:writeLists(id, shares, withoutIdentifier(requests, identifier))
    if row.owner ~= identifier then sync(row.owner) end
    return sheet(identifier)
end)

lib.callback.register(_e('3dmap:decline'), function(src, data)
    local identifier = citizenId(src)
    local id = type(data) == 'table' and tonumber(data.id) or nil
    if not identifier or not id or not db:wait() then return end

    local row = db:rowById(id)
    if not row then return end

    local requests = asTable(row.requests)
    if not findIdentifier(requests, identifier) then return end

    db:writeLists(id, asTable(row.shares), withoutIdentifier(requests, identifier))
    return sheet(identifier)
end)

--- Tables created before the resource was renamed; their rows are kept.
local LEGACY_TABLES <const> = {
    { from = '0r_pausemenu_markers', to = 'nightreign_pausemenu_markers' },
    { from = '0r_pausemenu_global_markers', to = 'nightreign_pausemenu_global_markers' },
}

--- @param name string
--- @return boolean
local function tableExists(name)
    local rows = MySQL.query.await('SHOW TABLES LIKE ?', { (name:gsub('_', '\\_')) })
    return rows ~= nil and #rows > 0
end

local function migrateLegacyTables()
    for i = 1, #LEGACY_TABLES do
        local entry = LEGACY_TABLES[i]
        if not tableExists(entry.to) and tableExists(entry.from) then
            MySQL.query.await(('RENAME TABLE `%s` TO `%s`'):format(entry.from, entry.to))
            LT.Debug.Success('Renamed table %s to %s.', entry.from, entry.to)
        end
    end
end

--- @param database Database
local function bootDatabase(database)
    if database.missing then return end

    migrateLegacyTables()

    if mapCfg.autoDB == false then
        if not tableExists('nightreign_pausemenu_markers') then
            LT.Debug.Error('Marker table is missing. Set threeDMap.autoDB to create it.')
            return
        end
        if not tableExists('nightreign_pausemenu_global_markers') then
            LT.Debug.Error('Global marker table is missing. Set threeDMap.autoDB to create it.')
            return
        end
        database.ready = true
        return
    end

    MySQL.query.await(MARKERS_SCHEMA)
    MySQL.query.await(GLOBALS_SCHEMA)
    database.ready = true
    LT.Debug.Success('Marker database initialized.')
end

db = DatabaseClass:new()

if not db.missing then
    MySQL.ready(function()
        bootDatabase(db)
    end)
end
