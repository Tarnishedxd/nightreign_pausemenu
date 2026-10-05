local cfg <const> = require 'config.main'
local mapCfg <const> = cfg.threeDMap or {}
local camCfg <const> = cfg.camera or {}

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
                        self:addWorldBlip(('cfg:%s:%s'):format(group.id, n), {
                            x = pos.x,
                            y = pos.y,
                            z = pos.z,
                            label = entry.label or group.label or group.id,
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
    slot.id = id
    slot.x = x
    slot.y = y
    slot.scale = scale
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
    local draw = mapCfg.drawDistance or 2500.0
    local drawSq = draw * draw
    local count = 0
    local changed = false
    local seen = {}

    for i = 1, #self.points do
        local point = self.points[i]
        if not self.hiddenRows[point.id] then
            local dx = point.x - camPos.x
            local dy = point.y - camPos.y
            local dz = point.z - camPos.z
            local distSq = dx * dx + dy * dy + dz * dz
            if distSq <= drawSq then
                local onScreen, screenX, screenY = World3dToScreen2d(point.x, point.y, point.z)
                if onScreen then
                    count += 1
                    local dist = math.sqrt(distSq)
                    local scale = math.max(0.75, math.min(1.0, 1.0 - (dist / (draw * 4.0))))
                    self:fillSlot(count, point.id, screenX, screenY, scale)
                    seen[point.id] = true

                    local prev = self.prev[point.id]
                    if not prev
                        or math.abs(prev.x - screenX) > 0.0005
                        or math.abs(prev.y - screenY) > 0.0005
                        or math.abs(prev.scale - scale) > 0.01
                    then
                        changed = true
                        self.prev[point.id] = { x = screenX, y = screenY, scale = scale }
                    end
                end
            end
        end
    end

    if count ~= self.visible then changed = true end

    for id in pairs(self.prev) do
        if not seen[id] then
            self.prev[id] = nil
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

function ThreeDMapClass:onOpen()
    self.open = true
    self.gpsToken = nil
    self:syncGpsWaypoint()
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
