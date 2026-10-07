local cfg <const> = require 'config.main'
local mapCfg <const> = cfg.threeDMap or {}
local camCfg <const> = cfg.camera or {}
local abs <const> = math.abs
local sqrt <const> = math.sqrt
local floor <const> = math.floor

local NOTICES <const> = {
    invalid = { 'ui.map3d.invalid', 'That blip could not be saved.' },
    cooldown = { 'ui.map3d.cooldown', 'Wait before creating another blip.' },
    shareCooldown = { 'ui.map3d.shareCooldown', 'Wait before sending another request.' },
    max = { 'ui.map3d.max', 'You already have the maximum number of blips.' },
    already = { 'ui.map3d.already', 'That player already has this blip.' },
    sent = { 'ui.map3d.sent', 'Request sent.' },
    player = { 'ui.map3d.player', 'Player not found.' },
    miss = { 'ui.map3d.miss', 'Click a spot on the map.' },
    noPermission = { 'ui.map3d.noPermission', 'You cannot do that.' },
    waypoint = { 'ui.map3d.waypointSet', 'Waypoint set' },
    waypointRemoved = { 'ui.map3d.waypointRemoved', 'Waypoint removed' },
}

local SUCCESS_NOTICES <const> = {
    sent = true,
    waypoint = true,
    waypointRemoved = true,
}

--- @param value any
--- @return integer, string
local function parseConfigSprite(value)
    local id = math.floor(tonumber(value) or 1)
    if id < 0 then id = 1 end
    return id, tostring(id)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- SERVER BLIPS (the places the GTA map shows)
-- ════════════════════════════════════════════════════════════════════════════════════════════

local MAX_SPRITE <const> = 1000
local NAMES_KVP <const> = 'nightreign_pausemenu_blipNames2'
--- Icons the GTA map legend did not list although such a blip was on the map.
local MISSING_KVP <const> = 'nightreign_pausemenu_blipMissing'
--- The player arrow and the waypoint have their own rows.
local SKIP_SPRITES <const> = { [6] = true, [8] = true }
--- What a blip is attached to (GET_BLIP_INFO_ID_TYPE): 2 ped, 3 object, 4 coord. Vehicles move;
--- pickups and radius / area outlines are not places.
local PLACE_TYPES <const> = { [2] = true, [3] = true, [4] = true }
--- SET_BLIP_DISPLAY modes that keep a blip off the big map (minimap only).
local MINIMAP_ONLY <const> = { [5] = true, [9] = true }

--- @param hex string|nil
--- @return number|nil, number|nil, number|nil
local function hexRgb(hex)
    if type(hex) ~= 'string' then return nil end
    local r, g, b = hex:match('^#(%x%x)(%x%x)(%x%x)$')
    if not r then return nil end
    return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

--- Blip names cannot be read through natives, only the GTA map legend has them. Its rows carry
--- the icon name (radar_*) rather than the sprite id, so web/build/blips.json (id -> icon name,
--- written by the UI build) links the two. Names are learned whenever the legend is read (the
--- map page) and kept between sessions.
BlipNames = { byIcon = {}, iconOf = {}, own = {}, missing = {} }

--- Same cleanup as the GTA map legend gives its labels.
--- @param label string|nil
--- @return string
local function legendLabel(label)
    return ((label or ''):gsub('%s+', ' '):match('^%s*(.-)%s*$')) or ''
end

--- Our own 2D blips (markers, globals) are in the legend too: their names must not end up on
--- another script's blip that shares the icon.
--- @param spriteId number
--- @param label string|nil
function BlipNames.markOwn(spriteId, label)
    local icon = BlipNames.iconOf[floor(tonumber(spriteId) or -1)]
    if icon then BlipNames.own[icon .. '\0' .. legendLabel(label)] = true end
end

local NAMES_KVP_OLD <const> = 'nightreign_pausemenu_blipNames'

function BlipNames.load()
    local icons = {}
    local ok, decoded = pcall(json.decode, LoadResourceFile(GetCurrentResourceName(), 'web/build/blips.json') or '')
    if ok and type(decoded) == 'table' then
        for id, icon in pairs(decoded) do
            local sprite = tonumber(id)
            if sprite and type(icon) == 'string' then icons[floor(sprite)] = icon:lower() end
        end
    end
    BlipNames.iconOf = icons

    local missing = {}
    local okMissing, absent = pcall(json.decode, GetResourceKvpString(MISSING_KVP) or '')
    if okMissing and type(absent) == 'table' then
        for i = 1, #absent do
            if type(absent[i]) == 'string' and absent[i]:find('^radar_') then missing[absent[i]] = true end
        end
    end
    BlipNames.missing = missing

    -- names keyed by sprite id (first version) were often filed under the wrong sprite
    if GetResourceKvpString(NAMES_KVP_OLD) then DeleteResourceKvp(NAMES_KVP_OLD) end
    local stored
    ok, stored = pcall(json.decode, GetResourceKvpString(NAMES_KVP) or '')
    if not ok or type(stored) ~= 'table' then return end
    -- keep only well-formed entries: { [icon] = { { label, colour? }, ... } }
    local clean = {}
    for icon, list in pairs(stored) do
        if type(icon) == 'string' and icon:find('^radar_') and type(list) == 'table' then
            local entries = {}
            for i = 1, #list do
                local entry = list[i]
                if type(entry) == 'table' and type(entry.label) == 'string' and entry.label ~= '' then
                    entries[#entries + 1] = { label = entry.label, colour = type(entry.colour) == 'string' and entry.colour or nil }
                end
            end
            if #entries > 0 then clean[icon] = entries end
        end
    end
    BlipNames.byIcon = clean
end

function BlipNames.saveMissing()
    local list = {}
    for icon in pairs(BlipNames.missing) do list[#list + 1] = icon end
    if #list == 0 then
        DeleteResourceKvp(MISSING_KVP)
    else
        table.sort(list)
        SetResourceKvp(MISSING_KVP, json.encode(list))
    end
end

--- After a full legend read: icons it still did not name are not in the legend at all (blips a
--- script keeps off the legend), so opening the 3D map does not read it again for them.
--- @param icons string[]
function BlipNames.settle(icons)
    local added = false
    for i = 1, #icons do
        local icon = icons[i]
        if not BlipNames.byIcon[icon] and not BlipNames.missing[icon] then
            BlipNames.missing[icon] = true
            added = true
        end
    end
    if added then BlipNames.saveMissing() end
end

--- @param rows table[] parsed legend rows (label, sprite = icon name, colour, kind)
function BlipNames.learn(rows)
    local fresh = {}
    for i = 1, #(rows or {}) do
        local row = rows[i]
        local icon = type(row.sprite) == 'string' and row.sprite:lower() or ''
        if row.kind == 'blip' and icon:find('^radar_') and type(row.label) == 'string' and row.label ~= ''
            and not BlipNames.own[icon .. '\0' .. legendLabel(row.label)]
        then
            local list = fresh[icon] or {}
            local colour = hexRgb(row.colour) and row.colour:lower() or nil
            local known = false
            for n = 1, #list do
                if list[n].label == row.label and list[n].colour == colour then known = true end
            end
            if not known then list[#list + 1] = { label = row.label, colour = colour } end
            fresh[icon] = list
        end
    end
    if not next(fresh) then return end
    local found = false
    for icon in pairs(fresh) do
        if BlipNames.missing[icon] then
            BlipNames.missing[icon] = nil
            found = true
        end
    end
    if found then BlipNames.saveMissing() end
    -- the legend is read again on every change while the map page is open: only touch the
    -- stored names (a disk write) when one of them is new or different
    local changed = false
    for icon, list in pairs(fresh) do
        local known = BlipNames.byIcon[icon]
        if not known or #known ~= #list then
            changed = true
        else
            for n = 1, #list do
                if known[n].label ~= list[n].label or known[n].colour ~= list[n].colour then changed = true end
            end
        end
        if changed then break end
    end
    if not changed then return end
    -- icons missing from this legend (e.g. a job's blips while off duty) keep their names
    local merged = {}
    for icon, list in pairs(BlipNames.byIcon) do merged[icon] = list end
    for icon, list in pairs(fresh) do merged[icon] = list end
    BlipNames.byIcon = merged
    SetResourceKvp(NAMES_KVP, json.encode(merged))
end

--- @param spriteId integer
--- @param r number|nil
--- @param g number|nil
--- @param b number|nil
--- @return string|nil
function BlipNames.lookup(spriteId, r, g, b)
    local icon = BlipNames.iconOf[spriteId]
    local list = icon and BlipNames.byIcon[icon]
    if type(list) ~= 'table' or #list == 0 then return nil end
    if #list == 1 then return list[1].label end
    -- several names on one icon: the closest colour, all of them when that does not decide
    local best, labels, seen = math.huge, {}, {}
    for i = 1, #list do
        local cr, cg, cb = hexRgb(list[i].colour)
        local d = (cr and r) and ((cr - r) ^ 2 + (cg - g) ^ 2 + (cb - b) ^ 2) or math.huge
        if d < best then best, labels, seen = d, {}, {} end
        if d == best and not seen[list[i].label] then
            seen[list[i].label] = true
            labels[#labels + 1] = list[i].label
        end
    end
    return table.concat(labels, ' / ')
end

--- Every place blip on the map, as other scripts made it (not ours).
--- @param ours table<number, boolean>
--- @return table[]
local function scanServerBlips(ours)
    local found = {}
    local playerBlip = GetMainPlayerBlipId()
    for sprite = 1, MAX_SPRITE do
        if not SKIP_SPRITES[sprite] then
            local blip = GetFirstBlipInfoId(sprite)
            local guard = 0
            while blip and blip ~= 0 and guard < 4096 and DoesBlipExist(blip) do
                guard += 1
                local kind = GetBlipInfoIdType(blip)
                if blip ~= playerBlip and not ours[blip] and PLACE_TYPES[kind] and GetBlipAlpha(blip) > 0
                    and not MINIMAP_ONLY[GetBlipInfoIdDisplay(blip)]
                then
                    -- a ped / object blip counts while its entity is here and is not a player
                    local keep = kind == 4
                    if not keep then
                        local entity = GetBlipInfoIdEntityIndex(blip)
                        keep = entity ~= 0 and DoesEntityExist(entity) and not (kind == 2 and IsPedAPlayer(entity))
                    end
                    if keep then
                        local pos = GetBlipInfoIdCoord(blip)
                        local r, g, b = GetHudColour(GetBlipHudColour(blip))
                        found[#found + 1] = {
                            sprite = sprite,
                            x = pos.x + 0.0,
                            y = pos.y + 0.0,
                            z = pos.z + 0.0,
                            colour = GetBlipColour(blip),
                            r = r, g = g, b = b,
                        }
                    end
                end
                blip = GetNextBlipInfoId(sprite)
            end
        end
    end
    return found
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- CLASS
-- ════════════════════════════════════════════════════════════════════════════════════════════

---@class ThreeDMapClass
---@field new fun(self: ThreeDMapClass): ThreeDMapClass
---@field state table
---@field groups table
---@field points table
---@field markers table
---@field requests table
---@field hiddenRows table<string, boolean>
---@field placing boolean
---@field draft table|nil
---@field open boolean
---@field positions table
---@field prev table
---@field visible integer
---@field notice fun(self: ThreeDMapClass, key: string)
---@field rebuild fun(self: ThreeDMapClass)
---@field publish fun(self: ThreeDMapClass)
---@field find fun(self: ThreeDMapClass, id: string): table|nil
---@field fillSlot fun(self: ThreeDMapClass, index: integer, id: string, x: number, y: number, scale: number)
---@field project fun(self: ThreeDMapClass)
---@field clearPositions fun(self: ThreeDMapClass)
---@field place fun(self: ThreeDMapClass, nx: number, ny: number)
---@field onOpen fun(self: ThreeDMapClass)
---@field onClose fun(self: ThreeDMapClass)
---@field start fun(self: ThreeDMapClass)
---@field applySync fun(self: ThreeDMapClass, payload: table|nil)
---@field take fun(self: ThreeDMapClass, result: table|nil)
local ThreeDMapClass = {}
ThreeDMapClass.__index = ThreeDMapClass

--- @return ThreeDMapClass
function ThreeDMapClass:new()
    local self = setmetatable({}, ThreeDMapClass)

    self.state = LT.NUI.CreateState('UpdateMarkers', {
        groups = {},
        points = {},
        requests = {},
        placing = false,
        draft = false,
        playerCreator = mapCfg.playerCreator ~= false,
        adminCreator = mapCfg.adminCreator ~= false,
        isAdmin = false,
        placingMode = false,
    })

    self.groups = {}
    self.points = {}
    self.markers = {}
    self.globals = {}
    self.requests = {}
    self.hiddenRows = {}
    self.placing = false
    self.placingMode = nil
    self.draft = nil
    self.open = false
    self.isAdmin = false
    self.positions = {}
    self.prev = {}
    self.visible = 0
    self.worldBlips = {}
    self.serverBlips = {}
    self.gpsWaypoint = nil
    self.gpsToken = nil
    self.gpsPollAt = 0

    return self
end

--- @return string
local function gpsToken()
    if not IsWaypointActive() then return 'off' end
    local blip = GetFirstBlipInfoId(8)
    if blip == 0 or not DoesBlipExist(blip) then return 'on' end
    local coords = GetBlipInfoIdCoord(blip)
    return ('%d:%d'):format(math.floor(coords.x + 0.5), math.floor(coords.y + 0.5))
end

--- @param x number
--- @param y number
--- @param z? number
function ThreeDMapClass:setGpsWaypoint(x, y, z)
    self.gpsWaypoint = {
        x = x + 0.0,
        y = y + 0.0,
        z = (z or 0.0) + 0.0,
    }
    self.gpsToken = ('%d:%d'):format(math.floor(x + 0.5), math.floor(y + 0.5))
end

function ThreeDMapClass:clearGpsWaypoint()
    SetWaypointOff()
    self.gpsWaypoint = nil
    self.gpsToken = 'off'
    self:rebuild()
    self:publish()
    self:notice('waypointRemoved')
end

local GPS_TOGGLE_DIST2 = 40.0 * 40.0

--- @param x number
--- @param y number
--- @param z? number
function ThreeDMapClass:toggleGpsWaypoint(x, y, z)
    local gps = self.gpsWaypoint
    if gps and gps.x and gps.y then
        local dx = gps.x - x
        local dy = gps.y - y
        if (dx * dx + dy * dy) <= GPS_TOGGLE_DIST2 then
            self:clearGpsWaypoint()
            return
        end
    end
    SetNewWaypoint(x, y)
    PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    self:setGpsWaypoint(x, y, z)
    self:rebuild()
    self:publish()
    self:notice('waypoint')
end

--- @return boolean changed
function ThreeDMapClass:syncGpsWaypoint()
    local token = gpsToken()
    if token == self.gpsToken then return false end
    self.gpsToken = token
    if token == 'off' then
        self.gpsWaypoint = nil
        return true
    end
    local blip = GetFirstBlipInfoId(8)
    if blip == 0 or not DoesBlipExist(blip) then
        self.gpsWaypoint = nil
        return true
    end
    local coords = GetBlipInfoIdCoord(blip)
    self.gpsWaypoint = {
        x = coords.x + 0.0,
        y = coords.y + 0.0,
        z = coords.z + 0.0,
    }
    return true
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- LEGEND
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- @param point table
--- @return table
local function publicPoint(point)
    return {
        id = point.id,
        group = point.group,
        category = type(point.category) == 'string' and point.category or '',
        label = point.label,
        sprite = point.sprite,
        owned = point.owned == true,
        global = point.global == true,
        canDelete = point.canDelete == true,
        db = point.db,
        showOn2d = point.showOn2d == true,
        spriteId = tonumber(point.spriteId),
        blipColour = tonumber(point.blipColour) or 3,
        colourHex = type(point.colourHex) == 'string' and point.colourHex or nil,
        scale = tonumber(point.scale),
        shortRange = point.shortRange ~= false,
        shares = type(point.shares) == 'table' and point.shares or {},
        from = type(point.from) == 'string' and point.from or '',
        sharedAt = tonumber(point.sharedAt),
        metres = math.floor(#(GetEntityCoords(cache.ped) - vector3(point.x, point.y, point.z)) + 0.5),
    }
end

--- @param key string
function ThreeDMapClass:notice(key)
    local entry = NOTICES[key]
    if not entry then return end
    SendVue('UpdateMarkerNotice', {
        text = _t(entry[1], entry[2]),
        kind = SUCCESS_NOTICES[key] and 'success' or 'error',
    })
end

function ThreeDMapClass:rebuild()
    local groups, points = {}, {}
    local categories = mapCfg.categories or {}
    local seenGroups = {}

    groups[1] = {
        id = 'mine',
        label = 'ui.map3d.mine',
    }
    seenGroups.mine = true

    -- the places other scripts put on the map, named like the GTA map legend
    local server = self.serverBlips
    if #server > 0 then
        groups[#groups + 1] = { id = 'server', label = 'ui.map3d.server' }
        seenGroups.server = true
        local usedIds = {}
        for i = 1, #server do
            local blip = server[i]
            local id = ('srv:%d:%d:%d'):format(blip.sprite, floor(blip.x), floor(blip.y))
            while usedIds[id] do id = id .. '+' end
            usedIds[id] = true
            local hex = blip.r and ('#%02x%02x%02x'):format(floor(blip.r), floor(blip.g), floor(blip.b)) or nil
            points[#points + 1] = {
                id = id,
                group = 'server',
                category = 'ui.map3d.server',
                label = BlipNames.lookup(blip.sprite, blip.r, blip.g, blip.b) or '',
                sprite = tostring(blip.sprite),
                owned = false,
                x = blip.x,
                y = blip.y,
                z = blip.z,
                spriteId = blip.sprite,
                blipColour = (blip.colour and blip.colour >= 0 and blip.colour <= 85) and blip.colour or 0,
                colourHex = hex,
                scale = 0.8,
                shortRange = false,
            }
        end
        -- like the GTA map legend: by name, unnamed ones last
        local first = #points - #server + 1
        local slice = {}
        for i = first, #points do slice[#slice + 1] = points[i] end
        table.sort(slice, function(a, b)
            if (a.label == '') ~= (b.label == '') then return a.label ~= '' end
            if a.label ~= b.label then return a.label < b.label end
            return a.spriteId < b.spriteId
        end)
        for i = 1, #slice do points[first + i - 1] = slice[i] end
    end

    for i = 1, #categories do
        local group = categories[i]
        if type(group) == 'table' and type(group.id) == 'string' then
            local groupLabel = group.label or group.id
            if not seenGroups[group.id] then
                seenGroups[group.id] = true
                groups[#groups + 1] = {
                    id = group.id,
                    label = groupLabel,
                }
            end

            local entries = group.blips or {}
            for n = 1, #entries do
                local entry = entries[n]
                if type(entry) == 'table' then
                    local pos = entry.coords
                    if pos and pos.x and pos.y and pos.z then
                        local spriteId, sprite = parseConfigSprite(entry.sprite)
                        local blipColour = math.floor(tonumber(entry.color) or 3)
                        points[#points + 1] = {
                            id = ('cfg:%s:%s'):format(group.id, n),
                            group = group.id,
                            category = groupLabel,
                            label = type(entry.label) == 'string' and entry.label ~= '' and entry.label or groupLabel,
                            sprite = sprite,
                            owned = false,
                            x = pos.x + 0.0,
                            y = pos.y + 0.0,
                            z = pos.z + 0.0,
                            showOn2d = entry.showOn2d == true,
                            spriteId = spriteId,
                            blipColour = blipColour,
                            scale = tonumber(entry.scale) or 0.8,
                            shortRange = entry.shortRange ~= false,
                        }
                    end
                end
            end
        end
    end

    for i = 1, #self.globals do
        local marker = self.globals[i]
        local category = type(marker.category) == 'string' and marker.category or ''
        if category ~= '' and marker.x and marker.y and marker.z then
            local groupId = ('gcat:%s'):format(category)
            if not seenGroups[groupId] then
                seenGroups[groupId] = true
                groups[#groups + 1] = {
                    id = groupId,
                    label = category,
                }
            end
            points[#points + 1] = {
                id = ('global:%s'):format(marker.id),
                group = groupId,
                category = category,
                label = marker.label,
                sprite = marker.sprite or 'radar_level',
                owned = false,
                global = true,
                canDelete = self.isAdmin == true,
                db = marker.id,
                x = marker.x + 0.0,
                y = marker.y + 0.0,
                z = marker.z + 0.0,
                showOn2d = marker.showOn2d == true,
                spriteId = tonumber(marker.spriteId) or 1,
                blipColour = tonumber(marker.blipColour) or 3,
                scale = tonumber(marker.scale) or 0.8,
                shortRange = marker.shortRange ~= false,
            }
        end
    end

    local pedCoords = GetEntityCoords(cache.ped)
    points[#points + 1] = {
        id = 'mine:self',
        group = 'mine',
        label = 'ui.map3d.you',
        sprite = 'radar_centre',
        owned = false,
        canDelete = false,
        x = pedCoords.x + 0.0,
        y = pedCoords.y + 0.0,
        z = pedCoords.z + 0.0,
        spriteId = 1,
        blipColour = 0,
        scale = 0.8,
        shortRange = false,
    }

    local sharedCount = 0
    for i = 1, #self.markers do
        local marker = self.markers[i]
        local mine = marker.kind == 'mine'
        if not mine then sharedCount += 1 end
        points[#points + 1] = {
            id = ('%s:%s'):format(mine and 'mine' or 'shared', marker.id),
            group = mine and 'mine' or 'shared',
            label = marker.label,
            sprite = marker.sprite,
            owned = mine,
            canDelete = mine,
            shares = mine and marker.shares or nil,
            from = mine and nil or marker.from,
            sharedAt = mine and nil or marker.sharedAt,
            db = marker.id,
            showOn2d = marker.showOn2d == true,
            spriteId = tonumber(marker.spriteId),
            blipColour = tonumber(marker.blipColour) or 3,
            scale = tonumber(marker.scale) or 0.8,
            shortRange = marker.shortRange ~= false,
            x = marker.x + 0.0,
            y = marker.y + 0.0,
            z = marker.z + 0.0,
        }
    end

    if sharedCount > 0 then
        groups[#groups + 1] = {
            id = 'shared',
            label = 'ui.map3d.shared',
        }
    end

    local gps = self.gpsWaypoint
    if gps and gps.x and gps.y then
        points[#points + 1] = {
            id = 'gps:waypoint',
            group = 'mine',
            label = 'ui.map3d.waypointName',
            sprite = 'radar_waypoint',
            owned = false,
            canDelete = true,
            x = gps.x + 0.0,
            y = gps.y + 0.0,
            z = (gps.z or 0.0) + 0.0,
            spriteId = 8,
            blipColour = 27,
            scale = 0.8,
            shortRange = false,
        }
    end

    self.groups = groups
    self.points = points
end

function ThreeDMapClass:clearWorldBlips()
    for _, handle in pairs(self.worldBlips) do
        if handle and DoesBlipExist(handle) then
            RemoveBlip(handle)
        end
    end
    self.worldBlips = {}
    BlipNames.own = {}
end

--- @param key string
--- @param point table
function ThreeDMapClass:addWorldBlip(key, point)
    local spriteId = tonumber(point.spriteId)
    if not spriteId then return end
    local blip = AddBlipForCoord(point.x + 0.0, point.y + 0.0, point.z + 0.0)
    SetBlipSprite(blip, math.floor(spriteId))
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, (tonumber(point.scale) or 0.8) + 0.0)
    SetBlipColour(blip, math.floor(tonumber(point.blipColour) or 3))
    SetBlipAsShortRange(blip, point.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(point.label or '')
    EndTextCommandSetBlipName(blip)
    self.worldBlips[key] = blip
    BlipNames.markOwn(spriteId, point.label)
end

function ThreeDMapClass:syncWorldBlips()
    self:clearWorldBlips()

    local categories = mapCfg.categories or {}
    for i = 1, #categories do
        local group = categories[i]
        if type(group) == 'table' and type(group.id) == 'string' then
            local entries = group.blips or {}
            for n = 1, #entries do
                local entry = entries[n]
                if type(entry) == 'table' and entry.showOn2d == true then
                    local spriteId = parseConfigSprite(entry.sprite)
                    local pos = entry.coords
                    if pos and pos.x and pos.y and pos.z then
                        local label = entry.label or group.label or group.id
                        self:addWorldBlip(('cfg:%s:%s'):format(group.id, n), {
                            x = pos.x,
                            y = pos.y,
                            z = pos.z,
                            -- Config labels are locale keys; resolve them so the 2D map does not show raw keys.
                            label = _t(label, label),
                            spriteId = spriteId,
                            blipColour = math.floor(tonumber(entry.color) or 3),
                            scale = tonumber(entry.scale) or 0.8,
                            shortRange = entry.shortRange ~= false,
                        })
                    end
                end
            end
        end
    end

    for i = 1, #self.globals do
        local marker = self.globals[i]
        if marker.showOn2d == true and marker.x and marker.y and marker.z then
            self:addWorldBlip(('global:%s'):format(marker.id), {
                x = marker.x,
                y = marker.y,
                z = marker.z,
                label = marker.label,
                spriteId = marker.spriteId,
                blipColour = marker.blipColour,
                scale = marker.scale,
                shortRange = marker.shortRange,
            })
        end
    end

    for i = 1, #self.markers do
        local marker = self.markers[i]
        if marker.showOn2d == true and marker.x and marker.y and marker.z then
            local kind = marker.kind == 'mine' and 'mine' or 'shared'
            self:addWorldBlip(('%s:%s'):format(kind, marker.id), {
                x = marker.x,
                y = marker.y,
                z = marker.z,
                label = marker.label,
                spriteId = marker.spriteId,
                blipColour = marker.blipColour,
                scale = marker.scale,
                shortRange = marker.shortRange,
            })
        end
    end
end

function ThreeDMapClass:publish()
    local points = {}
    for i = 1, #self.points do
        points[i] = publicPoint(self.points[i])
    end

    local globalCategories, seen = {}, {}
    for i = 1, #self.globals do
        local category = self.globals[i].category
        if type(category) == 'string' and category ~= '' and not seen[category] then
            seen[category] = true
            globalCategories[#globalCategories + 1] = { id = category, label = category }
        end
    end

    self.state:set({
        groups = self.groups,
        points = points,
        requests = self.requests,
        placing = self.placing,
        draft = self.draft or false,
        playerCreator = mapCfg.playerCreator ~= false,
        adminCreator = mapCfg.adminCreator ~= false,
        isAdmin = self.isAdmin == true,
        placingMode = self.placingMode or false,
        globalCategories = globalCategories,
        -- names come from the GTA map legend: once it was read, a blip still unnamed is one the
        -- legend does not list, and asking to open the map again would not help
        legendLearned = next(BlipNames.byIcon) ~= nil,
    })
end

--- @param id string
--- @return table|nil
function ThreeDMapClass:find(id)
    for i = 1, #self.points do
        if self.points[i].id == id then return self.points[i] end
    end
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- PROJECTION
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- @param index integer
--- @param id string
--- @param x number
--- @param y number
--- @param scale number
function ThreeDMapClass:fillSlot(index, id, x, y, scale)
    local slot = self.positions[index]
    if not slot then
        slot = {}
        self.positions[index] = slot
    end
    -- Rounded so each message stays short (it is sent every frame while the camera moves):
    -- 0.0001 of the screen is a fifth of a pixel at 1920 wide.
    slot.id = id
    slot.x = floor(x * 10000 + 0.5) / 10000
    slot.y = floor(y * 10000 + 0.5) / 10000
    slot.scale = floor(scale * 100 + 0.5) / 100
end

function ThreeDMapClass:project()
    local cam = Camera and Camera.cam
    if not cam or not DoesCamExist(cam) then return end

    local selfPoint = self:find('mine:self')
    if selfPoint then
        local pedCoords = GetEntityCoords(cache.ped)
        selfPoint.x = pedCoords.x + 0.0
        selfPoint.y = pedCoords.y + 0.0
        selfPoint.z = pedCoords.z + 0.0
    end

    local camPos = GetCamCoord(cam)
    local camX, camY, camZ = camPos.x, camPos.y, camPos.z
    local draw = mapCfg.drawDistance or 2500.0
    local drawSq = draw * draw
    local count = 0
    local changed = false
    local prevById = self.prev
    local hiddenRows = self.hiddenRows
    local points = self.points
    -- Runs every frame while the camera moves: reuse the per-marker tables and mark
    -- the ones seen this pass with a counter instead of allocating new tables.
    local pass = (self.projectPass or 0) + 1
    self.projectPass = pass

    for i = 1, #points do
        local point = points[i]
        local id = point.id
        if not hiddenRows[id] then
            local dx = point.x - camX
            local dy = point.y - camY
            local dz = point.z - camZ
            local distSq = dx * dx + dy * dy + dz * dz
            if distSq <= drawSq then
                local onScreen, screenX, screenY = World3dToScreen2d(point.x, point.y, point.z)
                if onScreen then
                    count += 1
                    local scale = 1.0 - (sqrt(distSq) / (draw * 4.0))
                    if scale < 0.75 then scale = 0.75 elseif scale > 1.0 then scale = 1.0 end
                    self:fillSlot(count, id, screenX, screenY, scale)

                    local prev = prevById[id]
                    if not prev then
                        changed = true
                        prevById[id] = { x = screenX, y = screenY, scale = scale, pass = pass }
                    else
                        prev.pass = pass
                        if abs(prev.x - screenX) > 0.0005
                            or abs(prev.y - screenY) > 0.0005
                            or abs(prev.scale - scale) > 0.01
                        then
                            changed = true
                            prev.x, prev.y, prev.scale = screenX, screenY, scale
                        end
                    end
                end
            end
        end
    end

    if count ~= self.visible then changed = true end

    for id, prev in pairs(prevById) do
        if prev.pass ~= pass then
            prevById[id] = nil
            changed = true
        end
    end

    if not changed then return end

    for i = count + 1, #self.positions do
        self.positions[i] = nil
    end

    self.visible = count
    SendVue('UpdateMarkerPositions', { positions = self.positions })
end

function ThreeDMapClass:clearPositions()
    self.prev = {}
    self.visible = 0
    self.positions = {}
    SendVue('UpdateMarkerPositions', { positions = {} })
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- PLACE
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- @param nx number
--- @param ny number
--- @return number|nil
--- @return number|nil
--- @return number|nil
local function clickXY(nx, ny)
    local cam = Camera and Camera.cam
    if not cam or not DoesCamExist(cam) then return end

    local camPos = GetCamCoord(cam)
    local rot = GetCamRot(cam, 2)
    local pitch = math.rad(rot.x)
    local yaw = math.rad(rot.z)
    local cosPitch = math.abs(math.cos(pitch))
    local forward = vector3(-math.sin(yaw) * cosPitch, math.cos(yaw) * cosPitch, math.sin(pitch))
    local right = vector3(forward.y, -forward.x, 0.0)
    local rightLen = #right
    if rightLen < 0.001 then
        right = vector3(math.cos(yaw), math.sin(yaw), 0.0)
    else
        right = right / rightLen
    end

    local up = vector3(
        right.y * forward.z - right.z * forward.y,
        right.z * forward.x - right.x * forward.z,
        right.x * forward.y - right.y * forward.x
    )
    local upLen = #up
    if upLen > 0.001 then up = up / upLen end

    local screenX, screenY = GetActiveScreenResolution()
    local aspect = screenX / math.max(screenY, 1)
    local tanHalf = math.tan(math.rad(camCfg.fov or 72.5) * 0.5)
    local dir = forward + right * ((nx * 2.0 - 1.0) * tanHalf * aspect) + up * ((1.0 - ny * 2.0) * tanHalf)
    local dirLen = #dir
    if dirLen > 0.001 then dir = dir / dirLen end
    if math.abs(dir.z) < 0.001 then return end

    local groundZ = Camera.hasGround and Camera.groundZ or (camPos.z - (Camera.height or 200.0))
    local t = (groundZ - camPos.z) / dir.z
    if t <= 0.0 then return end

    return camPos.x + dir.x * t, camPos.y + dir.y * t, groundZ
end

local function restoreFocus()
    local cam = Camera and Camera.cam
    if not cam or not DoesCamExist(cam) then return end
    local camPos = GetCamCoord(cam)
    SetFocusPosAndVel(camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0)
    Camera.lastCollisionAt = 0
end

--- @param x number
--- @param y number
--- @return number|nil
local function holdFocus(x, y)
    if Camera then
        Camera.lastCollisionAt = GetGameTimer() + 800
    end
    SetFocusPosAndVel(x, y, 80.0, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(x, y, 1000.0)
end

local function sampleGround(x, y, waitMs)
    holdFocus(x, y)

    local deadline = GetGameTimer() + (waitMs or 800)
    while GetGameTimer() < deadline do
        if not Camera or not Camera:isOpen() then
            restoreFocus()
            return nil
        end
        holdFocus(x, y)
        local found, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, false)
        if not found then
            found, groundZ = GetGroundZFor_3dCoord(x, y, 100.0, false)
        end
        if found then
            restoreFocus()
            return groundZ
        end
        Wait(50)
    end

    restoreFocus()
    return nil
end

--- @param nx number
--- @param ny number
function ThreeDMapClass:place(nx, ny)
    if not self.placing then return end
    local x, y, planeZ = clickXY(nx, ny)
    if not x or not y or not planeZ then
        self:notice('miss')
        return
    end

    self.placing = false
    self.draft = { x = x, y = y, z = planeZ + 0.0 }
    self:publish()

    local stamp = self.draft
    CreateThread(function()
        local groundZ = sampleGround(x, y, 800)
        if not groundZ or self.draft ~= stamp then return end
        stamp.z = groundZ + 0.0
        if self.open then self:publish() end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- LOOP
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- @return table<number, boolean>
function ThreeDMapClass:ownBlips()
    local ours = {}
    for _, handle in pairs(self.worldBlips) do ours[handle] = true end
    return ours
end

--- Icons of the server's blips on the map now whose names were never read from the GTA map
--- legend (and which a full read did not find missing either).
--- @return string[]
function ThreeDMapClass:unknownIcons()
    if mapCfg.serverBlips == false then return {} end
    local ok, found = pcall(scanServerBlips, self:ownBlips())
    if not ok then return {} end
    local icons, seen = {}, {}
    for i = 1, #found do
        local icon = BlipNames.iconOf[found[i].sprite]
        if icon and not seen[icon] and not BlipNames.byIcon[icon] and not BlipNames.missing[icon] then
            seen[icon] = true
            icons[#icons + 1] = icon
        end
    end
    return icons
end

function ThreeDMapClass:onOpen()
    self.open = true
    self.gpsToken = nil
    self:syncGpsWaypoint()
    if mapCfg.serverBlips ~= false then
        local ok, found = pcall(scanServerBlips, self:ownBlips())
        self.serverBlips = ok and found or {}
        if not ok then LT.Debug.Error('reading the map blips failed: %s', tostring(found)) end
    else
        self.serverBlips = {}
    end
    self:rebuild()
    self:publish()
    CreateThread(function()
        local result = lib.callback.await(_e('3dmap:fetch'), false)
        if not self.open then return end
        self:take(result)
    end)
    CreateThread(function()
        local result = lib.callback.await(_e('3dmap:fetchGlobals'), false)
        if type(result) ~= 'table' then return end
        self:applyGlobals(result)
    end)
end

function ThreeDMapClass:onClose()
    self.open = false
    self.placing = false
    self.placingMode = nil
    self.draft = nil
    self.gpsPollAt = 0
    self:clearPositions()
end

function ThreeDMapClass:start()
    CreateThread(function()
        while true do
            if mapCfg.enabled and Camera and Camera:isOpen() then
                self:onOpen()
                while Camera:isOpen() do
                    local now = GetGameTimer()
                    if now >= (self.gpsPollAt or 0) then
                        self.gpsPollAt = now + 1000
                        if self:syncGpsWaypoint() then
                            self:rebuild()
                            self:publish()
                        end
                    end
                    self:project()
                    if Camera:isSettled() then
                        Wait(mapCfg.interval or 33)
                    else
                        Wait(0)
                    end
                end
                self:onClose()
            end
            Wait(200)
        end
    end)

    LT.OnPlayerLoad(function()
        local markers = lib.callback.await(_e('3dmap:fetch'), false)
        if type(markers) == 'table' then
            self:applySync(markers)
        end
        local globals = lib.callback.await(_e('3dmap:fetchGlobals'), false)
        if type(globals) == 'table' then
            self:applyGlobals(globals)
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- NUI / NET
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- @param payload table|nil
function ThreeDMapClass:applySync(payload)
    payload = payload or {}
    self.markers = payload.markers or {}
    self.requests = payload.requests or {}
    self:rebuild()
    self:syncWorldBlips()
    if self.open then self:publish() end
end

--- @param payload table|nil
function ThreeDMapClass:applyGlobals(payload)
    payload = payload or {}
    if type(payload.globals) == 'table' then
        self.globals = payload.globals
    elseif type(payload) == 'table' and (payload[1] ~= nil or next(payload) == nil) then
        self.globals = payload
    end
    if payload.isAdmin ~= nil then
        self.isAdmin = payload.isAdmin == true
    end
    self:rebuild()
    self:syncWorldBlips()
    if self.open then self:publish() end
end

--- @param result table|nil
function ThreeDMapClass:take(result)
    if type(result) ~= 'table' then return end
    if type(result.error) == 'string' then
        self:notice(result.error)
        return
    end
    if type(result.notice) == 'string' then
        self:notice(result.notice)
    end
    self:applySync(result)
end

local Map3d = ThreeDMapClass:new()
_G.ThreeDMap = Map3d
BlipNames.load()

if mapCfg.enabled then
    Map3d:start()
end

LT.Hooks.Stop(function()
    Map3d:clearWorldBlips()
end)

register('3dmap:sync', function(payload)
    Map3d:applySync(payload)
end)

register('3dmap:globals', function(payload)
    Map3d:applyGlobals(payload)
end)

LT.NUI.Callback('ThreeDMapReady', function(_, cb)
    cb('ok')
    Map3d.prev = {}
    Map3d.visible = -1
end)

LT.NUI.Callback('ThreeDMapFocus', function(data, cb)
    cb('ok')
    local point = type(data) == 'table' and Map3d:find(data.id) or nil
    if not point or not Camera then return end
    CreateThread(function()
        Camera:focusAt(point.x, point.y, point.z)
    end)
end)

LT.NUI.Callback('ThreeDMapBegin', function(data, cb)
    cb('ok')
    if not Camera or not Camera:isOpen() then return end
    local mode = type(data) == 'table' and data.mode or 'personal'
    if mode == 'global' then
        if mapCfg.adminCreator == false or not Map3d.isAdmin then return end
    elseif mapCfg.playerCreator == false then
        return
    end
    Map3d.placing = true
    Map3d.placingMode = mode == 'global' and 'global' or 'personal'
    Map3d.draft = nil
    Map3d:publish()
end)

LT.NUI.Callback('ThreeDMapCancel', function(_, cb)
    cb('ok')
    Map3d.placing = false
    Map3d.placingMode = nil
    Map3d.draft = nil
    Map3d:publish()
end)

LT.NUI.Callback('ThreeDMapPlace', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    Map3d:place(tonumber(data.nx) or -1, tonumber(data.ny) or -1)
end)

--- @param eventName string
--- @param payload table|nil
--- @param after? fun(result: any): boolean|nil
local function runCallback(eventName, payload, after)
    CreateThread(function()
        local ok, result = pcall(lib.callback.await, _e(eventName), false, payload)
        if not ok then
            Map3d:notice('invalid')
            return
        end
        if after and after(result) == false then return end
        Map3d:take(result)
    end)
end

LT.NUI.Callback('ThreeDMapCreate', function(data, cb)
    cb('ok')
    local draft = Map3d.draft
    if type(data) ~= 'table' or type(draft) ~= 'table' then
        Map3d:notice('invalid')
        return
    end
    if Map3d.placingMode == 'global' then
        Map3d:notice('invalid')
        return
    end
    runCallback('3dmap:create', {
        label = data.label,
        sprite = data.sprite,
        spriteId = data.spriteId,
        colour = data.colour,
        showOn2d = data.showOn2d == true,
        blipColour = data.blipColour,
        scale = data.scale,
        shortRange = data.shortRange,
        coords = { draft.x + 0.0, draft.y + 0.0, draft.z + 0.0 },
    }, function(result)
        if type(result) ~= 'table' then
            Map3d:notice('invalid')
            return false
        end
        if not result.error and Map3d.draft == draft then
            Map3d.draft = nil
            Map3d.placing = false
            Map3d.placingMode = nil
        end
    end)
end)

LT.NUI.Callback('ThreeDMapCreateGlobal', function(data, cb)
    cb('ok')
    local draft = Map3d.draft
    if type(data) ~= 'table' or type(draft) ~= 'table' then
        Map3d:notice('invalid')
        return
    end
    if Map3d.placingMode ~= 'global' then
        Map3d:notice('invalid')
        return
    end
    runCallback('3dmap:createGlobal', {
        category = data.category,
        label = data.label,
        sprite = data.sprite,
        spriteId = data.spriteId,
        colour = data.colour,
        showOn2d = data.showOn2d == true,
        blipColour = data.blipColour,
        scale = data.scale,
        shortRange = data.shortRange,
        coords = { draft.x + 0.0, draft.y + 0.0, draft.z + 0.0 },
    }, function(result)
        if type(result) ~= 'table' then
            Map3d:notice('invalid')
            return false
        end
        if type(result.error) == 'string' then
            Map3d:notice(result.error)
            return false
        end
        if Map3d.draft == draft then
            Map3d.draft = nil
            Map3d.placing = false
            Map3d.placingMode = nil
        end
        Map3d:applyGlobals(result)
        return false
    end)
end)

LT.NUI.Callback('ThreeDMapWaypoint', function(data, cb)
    cb('ok')
    local point = type(data) == 'table' and Map3d:find(data.id) or nil
    if not point then return end
    if point.id == 'gps:waypoint' then
        Map3d:clearGpsWaypoint()
        return
    end
    Map3d:toggleGpsWaypoint(point.x, point.y, point.z)
end)

LT.NUI.Callback('ThreeDMapWaypointAt', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local x, y, z = clickXY(tonumber(data.nx) or -1, tonumber(data.ny) or -1)
    if not x or not y then return end
    Map3d:toggleGpsWaypoint(x, y, z)
end)

LT.NUI.Callback('ThreeDMapDelete', function(data, cb)
    cb('ok')
    local point = type(data) == 'table' and Map3d:find(data.id) or nil
    if not point then return end
    if point.id == 'gps:waypoint' then
        Map3d:clearGpsWaypoint()
        return
    end
    if not point.db then return end
    if point.global then
        if not Map3d.isAdmin then return end
        runCallback('3dmap:deleteGlobal', { id = point.db }, function(result)
            if type(result) ~= 'table' then
                Map3d:notice('invalid')
                return false
            end
            if type(result.error) == 'string' then
                Map3d:notice(result.error)
                return false
            end
            Map3d:applyGlobals(result)
            return false
        end)
        return
    end
    if not point.owned then return end
    runCallback('3dmap:delete', { id = point.db })
end)

LT.NUI.Callback('ThreeDMapUnshare', function(data, cb)
    cb('ok')
    local point = type(data) == 'table' and Map3d:find(data.id) or nil
    local target = type(data) == 'table' and data.identifier or nil
    if not point or not point.owned or not point.db or type(target) ~= 'string' or target == '' then return end
    runCallback('3dmap:unshare', { id = point.db, identifier = target })
end)

LT.NUI.Callback('ThreeDMapShare', function(data, cb)
    cb('ok')
    local point = type(data) == 'table' and Map3d:find(data.id) or nil
    local target = type(data) == 'table' and tonumber(data.target) or nil
    if not point or not point.owned or not point.db or not target then return end
    runCallback('3dmap:share', { id = point.db, target = target })
end)

LT.NUI.Callback('ThreeDMapAccept', function(data, cb)
    cb('ok')
    local id = type(data) == 'table' and tonumber(data.id) or nil
    if not id then return end
    runCallback('3dmap:accept', { id = id })
end)

LT.NUI.Callback('ThreeDMapDecline', function(data, cb)
    cb('ok')
    local id = type(data) == 'table' and tonumber(data.id) or nil
    if not id then return end
    runCallback('3dmap:decline', { id = id })
end)

LT.NUI.Callback('ThreeDMapHide', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or type(data.id) ~= 'string' then return end
    Map3d.hiddenRows[data.id] = data.hidden == true
end)
