local cfg <const> = require 'config.main'
local dumpChunkSize <const> = 40
local returnTimeout <const> = 1000
local chunkTimeout <const> = 200
local legendColumn <const> = 0
local pauseMenu <const> = `FE_MENU_VERSION_SP_PAUSE`
local blockedControls <const> = {
    1, 2, 14, 15, 16, 17, 24, 25, 27,
    172, 173, 174, 175, 176, 177,
    187, 188, 189, 190, 191,
    201, 202, 203, 204, 205,
    237, 238, 239, 240, 241, 242,
}
local tagColours <const> = {
    r = '#f43f5e',
    b = '#60a5fa',
    g = '#4ade80',
    y = '#facc15',
    o = '#fb923c',
    p = '#c084fc',
    q = '#f472b6',
    w = '#ffffff',
}

---@class NativeMapClass
---@field state table
---@field open boolean
---@field opening boolean
---@field closing boolean
---@field frontendUp boolean
---@field frontendHeld boolean
---@field forceReleased boolean
---@field mode string
---@field dumpBusy boolean
---@field hideThread boolean
---@field cursorHideGen integer
---@field inputThread boolean
---@field inputLock boolean
---@field pointerOver boolean
---@field typing boolean
---@field returnToPause boolean
---@field loggedSample boolean
---@field rows table
---@field rowsById table
---@field cycles table
---@field toast table
---@field toastToken integer
---@field queue table
---@field queueRunning boolean
---@field refreshThread boolean
---@field refreshUntil integer
---@field legendVersion integer|nil
---@field forcePull boolean
---@field waypointKey string|nil
---@field waypointReady boolean
local NativeMapClass = {}
NativeMapClass.__index = NativeMapClass

local groupList <const> = {
    { id = 'default', label = 'Locations', order = 1 },
}

local function blankToast()
    return { token = 0, kind = '', label = '', cycle = 0, count = 0 }
end

local function blankState()
    return {
        status = 'idle',
        rows = {},
        groups = {},
        toast = blankToast(),
        focus = -1,
    }
end

local asBool = Scaleform.asBool
local split = Scaleform.split
local rowCount = Scaleform.rowCount
local addScaleformParams = Scaleform.addParams
local awaitReturn = Scaleform.awaitReturn

local function invokeFrontend(method, ...)
    if not BeginScaleformMovieMethodOnFrontend(method) then return false end
    addScaleformParams({ ... })
    EndScaleformMovieMethod()
    return true
end

local function invokeFrontendHeader(method, ...)
    if not BeginScaleformMovieMethodOnFrontendHeader(method) then return false end
    addScaleformParams({ ... })
    EndScaleformMovieMethod()
    return true
end

local function beginFrontendReturn(self, method, ...)
    self:holdFrontend()
    if not BeginScaleformMovieMethodOnFrontend(method) then return nil end
    addScaleformParams({ ... })
    return EndScaleformMovieMethodReturnValue()
end

--- @param value string
--- @return string, string|nil
local function cleanLabel(value)
    local code = value:match('~([rbgypqw])~')
    local colour = code and tagColours[code] or nil
    local text = value:gsub('~[%w_]+~', '')
    text = text:gsub('<[^>]*>', '')
    text = text:gsub('%^%d', '')
    text = text:gsub('%s+', ' ')
    text = text:match('^%s*(.-)%s*$') or ''
    return text, colour
end

--- @param sprite string
--- @param label string
--- @return string
local function rowKind(sprite, label)
    if sprite == 'radar_waypoint' or label:lower() == 'waypoint' then return 'waypoint' end
    if sprite == 'radar_centre' or sprite:find('^radar_player') then return 'player' end
    return 'blip'
end

--- @param parts string[]
--- @return string|nil
local function legendColour(parts)
    local red = tonumber(parts[8])
    local green = tonumber(parts[9])
    local blue = tonumber(parts[10])
    if not red or not green or not blue then return nil end
    if red < 0 or red > 255 or green < 0 or green > 255 or blue < 0 or blue > 255 then return nil end
    return ('#%02x%02x%02x'):format(math.floor(red), math.floor(green), math.floor(blue))
end

--- @param parts string[]
--- @param uniqueId integer
--- @param count integer
--- @return integer|nil
local function legendSpriteId(parts, uniqueId, count)
    for partIndex = 7, #parts do
        local spriteId = tonumber(parts[partIndex])
        if spriteId then
            spriteId = math.floor(spriteId)
            if (spriteId == 6 or spriteId == 8) and spriteId ~= uniqueId and spriteId ~= count then
                return spriteId
            end
        end
    end
end

--- @param segment string
--- @param index integer
--- @return table|nil
local function parseLegendRow(segment, index)
    local parts = split(segment, '|')
    local uniqueId = tonumber(parts[3])
    local rawLabel = parts[7]
    if not uniqueId or not rawLabel or rawLabel == '' or rawLabel == 'undefined' then return nil end

    local label, colour = cleanLabel(rawLabel)
    if label == '' then return nil end

    local sprite = ''
    for partIndex = 1, #parts do
        local name = parts[partIndex]:match('(radar_[%w_]+)')
        if name then
            sprite = name
            break
        end
    end

    local count = tonumber(parts[12])
    if not count or count < 1 or count > 999 then count = 1 end

    local spriteId = legendSpriteId(parts, uniqueId, count)
    local blipSprite = spriteId
    if not blipSprite then
        for partIndex = 1, #parts do
            if parts[partIndex]:find('radar_', 1, true) then
                local near = tonumber(parts[partIndex + 1]) or tonumber(parts[partIndex - 1])
                if near and near >= 1 and near <= 921 and near ~= uniqueId and near ~= count then
                    blipSprite = math.floor(near)
                end
                break
            end
        end
    end
    local isNew = asBool(parts[14]) == true
    local kind = rowKind(sprite, label)
    if spriteId == 6 then kind = 'player' end
    if spriteId == 8 then kind = 'waypoint' end
    colour = legendColour(parts) or colour

    return {
        id = tostring(uniqueId),
        index = index,
        uniqueId = uniqueId,
        label = label,
        sprite = sprite,
        spriteId = spriteId,
        blipSprite = blipSprite,
        colour = colour or '#ffffff',
        count = count,
        isNew = isNew,
        kind = kind,
        fixed = kind ~= 'blip',
        group = 'default',
    }
end

--- @param raw string
--- @return table
local function parseLegend(raw)
    local rows = {}
    local index = 0
    for segment in ((raw or '') .. '##'):gmatch('(.-)##') do
        if segment ~= '' then
            local row = parseLegendRow(segment, index)
            if row then rows[#rows + 1] = row end
        end
        index += 1
    end
    return rows
end

--- @return NativeMapClass
function NativeMapClass:new()
    local self = setmetatable({}, NativeMapClass)
    self.state = LT.NUI.CreateState('UpdateLegend', blankState())
    self.open = false
    self.opening = false
    self.closing = false
    self.frontendUp = false
    self.frontendHeld = false
    self.forceReleased = false
    self.mode = 'idle'
    self.dumpBusy = false
    self.hideThread = false
    self.cursorHideGen = 0
    self.inputThread = false
    self.inputLock = false
    self.pointerOver = false
    self.typing = false
    self.returnToPause = false
    self.loggedSample = false
    self.rows = {}
    self.rowsById = {}
    self.cycles = {}
    self.toast = blankToast()
    self.toastToken = 0
    self.focus = -1
    self.focusAt = 0
    self.queue = {}
    self.queueRunning = false
    self.refreshThread = false
    self.refreshUntil = 0
    self.legendVersion = nil
    self.forcePull = false
    self.waypointKey = nil
    self.waypointReady = false
    return self
end

--- @return boolean
function NativeMapClass:isOpen()
    return self.open or self.opening
end

--- @return boolean
function NativeMapClass:isDumping()
    return self.dumpBusy
end

--- @return boolean
function NativeMapClass:wantsFrontend()
    return self.pointerOver or self.typing
end

---@param force boolean|nil
function NativeMapClass:holdFrontend(force)
    if self.forceReleased or self.frontendHeld then return end
    if not force and not self:wantsFrontend() then return end
    TakeControlOfFrontend()
    self.frontendHeld = true
end

function NativeMapClass:yieldFrontend()
    if not self.frontendHeld then return end
    if not self.forceReleased and self:wantsFrontend() then return end
    if self.mode == 'legend' and not self.forceReleased then
        invokeFrontend('BRIDGE_MAP_HIDE', true)
        invokeFrontendHeader('BRIDGE_HIDE', true)
    end
    ReleaseControlOfFrontend()
    self.frontendHeld = false
end

function NativeMapClass:syncFrontend()
    if self.forceReleased or not self:wantsFrontend() then
        self:yieldFrontend()
        return
    end
    self:holdFrontend()
end

---@param method string
---@return boolean
function NativeMapClass:call(method, ...)
    self:holdFrontend()
    return invokeFrontend(method, ...)
end

---@param method string
---@return boolean
function NativeMapClass:callHeader(method, ...)
    self:holdFrontend()
    return invokeFrontendHeader(method, ...)
end

---@param method string
---@param timeout number?
---@return integer|nil
function NativeMapClass:readInt(method, timeout, ...)
    local value = awaitReturn(beginFrontendReturn(self, method, ...), 'int', timeout)
    if type(value) ~= 'number' then return nil end
    return value
end

---@param method string
---@param timeout number?
---@return string
function NativeMapClass:readString(method, timeout, ...)
    local value = awaitReturn(beginFrontendReturn(self, method, ...), 'string', timeout)
    if type(value) ~= 'string' then return '' end
    return value
end

---@param timeout number?
---@return boolean
function NativeMapClass:acquireDump(timeout)
    local deadline = GetGameTimer() + (timeout or returnTimeout)
    while (self.dumpBusy or (SettingsBridge and SettingsBridge.dumpBusy)) and GetGameTimer() < deadline do
        Wait(0)
    end
    if self.dumpBusy or (SettingsBridge and SettingsBridge.dumpBusy) then return false end
    self.dumpBusy = true
    return true
end

function NativeMapClass:releaseDump()
    self.dumpBusy = false
end

---@param partCount integer
---@param batchSize integer
---@return string|nil
function NativeMapClass:readDumpParts(partCount, batchSize)
    local values = {}
    local part = 0
    while part < partCount do
        local handles = {}
        local batchEnd = math.min(partCount, part + batchSize)
        for partIndex = part, batchEnd - 1 do
            handles[#handles + 1] = {
                index = partIndex,
                handle = beginFrontendReturn(self, 'GET_BRIDGE_DUMP', partIndex),
            }
        end
        for handleIndex = 1, #handles do
            local entry = handles[handleIndex]
            local value = awaitReturn(entry.handle, 'string', chunkTimeout)
            if type(value) ~= 'string' then return nil end
            values[entry.index + 1] = value
        end
        part = batchEnd
    end
    return table.concat(values)
end

---@param column integer
---@return string
function NativeMapClass:readDump(column)
    if not self:acquireDump(returnTimeout) then return '' end
    local expectedRows = self:readInt('GET_BRIDGE_COUNT', returnTimeout, column) or 0
    local partCount = self:readInt('BRIDGE_DUMP', returnTimeout, column, dumpChunkSize) or 0
    if partCount <= 0 then
        self:releaseDump()
        return ''
    end
    local attempts = { 16, 8, 4, 1 }
    local tried = {}
    for attempt = 1, #attempts do
        local batchSize = attempts[attempt]
        if not tried[batchSize] then
            tried[batchSize] = true
            local raw = self:readDumpParts(partCount, batchSize)
            if raw and raw ~= '' and (expectedRows == 0 or rowCount(raw) >= math.max(1, expectedRows - 1)) then
                self:releaseDump()
                return raw
            end
            partCount = self:readInt('BRIDGE_DUMP', returnTimeout, column, dumpChunkSize) or partCount
        end
    end
    self:releaseDump()
    return ''
end

---@param timeout number
---@return boolean
function NativeMapClass:waitFrontend(timeout)
    local deadline = GetGameTimer() + timeout
    while GetGameTimer() < deadline do
        if not self.opening and not self.open then return false end
        if IsPauseMenuActive() and not IsPauseMenuRestarting() and IsFrontendReadyForControl() then
            return true
        end
        Wait(0)
    end
    return false
end

---@param id string
---@return table|nil
function NativeMapClass:rowFor(id)
    return self.rowsById[id]
end

---@param raw string
function NativeMapClass:applyDump(raw)
    if not self.loggedSample then
        self.loggedSample = true
        for segment in ((raw or '') .. '##'):gmatch('(.-)##') do
            if segment ~= '' then
                LT.Debug.Verbose('map legend row %s', segment)
            end
        end
    end
    local rows = parseLegend(raw)
    local rowsById = {}
    for index = 1, #rows do
        rowsById[rows[index].id] = rows[index]
    end
    self.rows = rows
    self.rowsById = rowsById
end

function NativeMapClass:publish()
    local rows = {}
    for index = 1, #self.rows do
        local row = self.rows[index]
        rows[#rows + 1] = {
            id = row.id,
            index = row.index,
            label = row.label,
            sprite = row.sprite,
            colour = row.colour,
            count = row.count,
            isNew = row.isNew,
            fixed = row.fixed,
            kind = row.kind,
            group = row.group,
            cycle = self.cycles[row.id] or 1,
        }
    end
    self.state:set({
        status = self.mode == 'fallback' and 'fallback' or 'ready',
        rows = rows,
        groups = groupList,
        toast = self.toast,
        focus = self.focus or -1,
    })
end

---@param kind string
---@param row table
---@param cycle integer
---@param count integer
function NativeMapClass:pushToast(kind, row, cycle, count)
    self.toastToken += 1
    self.toast = {
        token = self.toastToken,
        kind = kind,
        label = row and row.label or '',
        cycle = cycle or 0,
        count = count or 0,
    }
    self:publish()
end

---@param control integer
function NativeMapClass:pulse(control)
    self.inputLock = true
    self.forceReleased = true
    ReleaseControlOfFrontend()
    self.frontendHeld = false
    Wait(0)
    SetControlNormal(0, control, 0.0)
    SetControlNormal(2, control, 0.0)
    Wait(0)
    EnableControlAction(0, control, true)
    EnableControlAction(2, control, true)
    SetInputExclusive(2, control)
    SetControlNormal(0, control, 1.0)
    SetControlNormal(2, control, 1.0)
    Wait(0)
    SetControlNormal(0, control, 0.0)
    SetControlNormal(2, control, 0.0)
    Wait(0)
    self.forceReleased = false
end

function NativeMapClass:selectRow(row)
    if self.mode ~= 'legend' or not row.index or row.index < 0 then return end
    self:readInt('BRIDGE_MAP_SELECT', returnTimeout, legendColumn, row.index)
    self:hideChrome()
    LT.Debug.Info('legend selected %s', row.label)
    self:armRefresh(1000)
end

function NativeMapClass:route(row)
    if self.mode ~= 'legend' then return end
    if row.fixed and row.kind == 'player' then return end
    if row.kind ~= 'waypoint' and self.placedId == row.id and GetGameTimer() < (self.placedUntil or 0) then
        return
    end
    self:pulse(201)
    local active = self:readWaypoint(row.kind ~= 'waypoint')
    if row.kind == 'waypoint' then
        if active then
            LT.Debug.Warn('waypoint did not stick')
            self:pushToast('none', row, 0, 0)
        else
            LT.Debug.Info('waypoint cleared')
            self.placedId = nil
            self.placedUntil = 0
            self:pushToast('removed', row, 0, 0)
        end
        self:armRefresh(1000)
        return
    end
    if not active then
        LT.Debug.Warn('waypoint did not stick for %s', row.label)
        self:pushToast('none', row, 0, 0)
        self:armRefresh(1000)
        return
    end
    LT.Debug.Info('waypoint set on %s', row.label)
    PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    self.placedId = row.id
    self.placedUntil = GetGameTimer() + 500
    self:pushToast('set', row, self.cycles[row.id] or 1, math.max(row.count or 1, 1))
    self:armRefresh(1000)
end

--- @param wantActive boolean
--- @return boolean
function NativeMapClass:readWaypoint(wantActive)
    local deadline = GetGameTimer() + 250
    local active = IsWaypointActive()
    while GetGameTimer() < deadline and self.mode == 'legend' do
        active = IsWaypointActive()
        if active == wantActive then break end
        Wait(0)
    end
    self.inputLock = false
    self:hideChrome()
    return active
end

---@param id string
---@param dir integer
function NativeMapClass:stepRow(id, dir)
    local row = self:rowFor(id)
    if not row or row.fixed or (row.count or 1) < 2 then return end
    local count = row.count
    local cycle = self.cycles[id] or 1
    if dir > 0 then
        cycle = cycle % count + 1
    else
        cycle = (cycle - 2) % count + 1
    end
    self.cycles[id] = cycle
    LT.Debug.Info('legend stepped %s to %s/%s', row.label, cycle, count)
    if row.index and row.index >= 0 then
        self.inputLock = true
        self:readInt('BRIDGE_MAP_SELECT', returnTimeout, legendColumn, row.index)
        self:readInt('BRIDGE_MAP_STEP', returnTimeout, legendColumn, dir > 0 and 1 or -1)
        self:hideChrome()
        self.inputLock = false
    end
    self:publish()
    self:armRefresh(1000)
end

function NativeMapClass:blockControls()
    if self.inputLock then return end
    if not self.pointerOver and not self.typing then return end
    for index = 1, #blockedControls do
        DisableControlAction(0, blockedControls[index], true)
        DisableControlAction(2, blockedControls[index], true)
    end
end

function NativeMapClass:hideChrome()
    self:holdFrontend()
    invokeFrontend('BRIDGE_MAP_HIDE', true)
    invokeFrontendHeader('BRIDGE_HIDE', true)
end

function NativeMapClass:enterMapPage()
    ReleaseControlOfFrontend()
    self.frontendHeld = false
    PauseMenuceptionGoDeeper(0)
    local deadline = GetGameTimer() + 1500
    while GetPauseMenuState() ~= 15 and GetGameTimer() < deadline do
        if not self.opening and not self.open then return end
        Wait(0)
    end
    self:holdFrontend(true)
    LT.Debug.Info('map page state %s', GetPauseMenuState())
end

local function legendStamp(rows)
    local parts = {}
    for index = 1, #rows do
        local row = rows[index]
        parts[index] = ('%s|%s|%s|%s|%s|%s'):format(
            row.id,
            row.label,
            row.sprite,
            row.colour,
            row.count,
            row.isNew and 1 or 0
        )
    end
    return table.concat(parts, '\n')
end

---@return boolean
function NativeMapClass:pullLegend()
    if self.mode ~= 'legend' or self.dumpBusy or self.inputLock then return false end
    local raw = self:readDump(legendColumn)
    if raw == '' then return false end
    local rows = parseLegend(raw)
    local stamp = legendStamp(rows)
    if stamp == self.legendStamp then return true end
    self.legendStamp = stamp
    self:applyDump(raw)
    self:publish()
    LT.Debug.Info('legend refreshed, %s rows', #self.rows)
    return true
end

---@param ms integer|nil
function NativeMapClass:armRefresh(ms)
    local deadline = GetGameTimer() + (ms or 1000)
    if deadline > (self.refreshUntil or 0) then
        self.refreshUntil = deadline
    end
    if self.refreshThread then return end
    self.refreshThread = true
    CreateThread(function()
        while self.open and self.mode == 'legend' and GetGameTimer() < self.refreshUntil do
            if self.inputLock or self.dumpBusy or self.queueRunning then
                Wait(0)
            else
                self.versionBusy = true
                local version = self:readInt('GET_BRIDGE_VERSION', chunkTimeout)
                self.versionBusy = false
                local changed = version ~= nil and version ~= self.legendVersion
                if self.forcePull or changed then
                    local forced = self.forcePull
                    self.forcePull = false
                    if self:pullLegend() then
                        if version ~= nil then self.legendVersion = version end
                    elseif forced then
                        self.forcePull = true
                    end
                end
                Wait(50)
            end
        end
        self.refreshThread = false
        if self.open and self.mode == 'legend' and GetGameTimer() < self.refreshUntil then
            self:armRefresh(self.refreshUntil - GetGameTimer())
        end
    end)
end

---@param fn fun()
function NativeMapClass:enqueue(fn)
    self.queue[#self.queue + 1] = fn
    if self.queueRunning then return end
    self.queueRunning = true
    CreateThread(function()
        while self.queueRunning and self.mode == 'legend' do
            local job = table.remove(self.queue, 1)
            if not job then
                self.queueRunning = false
                if self.queue[1] and self.mode == 'legend' then
                    self.queueRunning = true
                end
            else
                job()
            end
        end
        if self.mode ~= 'legend' then
            self.queue = {}
            self.queueRunning = false
        end
    end)
end

---@return string
function NativeMapClass:waypointToken()
    if not IsWaypointActive() then return 'off' end
    local blip = GetFirstBlipInfoId(8)
    if blip == 0 or not DoesBlipExist(blip) then return 'on' end
    local coords = GetBlipInfoIdCoord(blip)
    return ('%d:%d'):format(math.floor(coords.x + 0.5), math.floor(coords.y + 0.5))
end

function NativeMapClass:noteWaypoint()
    local key = self:waypointToken()
    if not self.waypointReady then
        self.waypointKey = key
        self.waypointReady = true
        return
    end
    if key == self.waypointKey then return end
    self.waypointKey = key
    self.forcePull = true
    self:armRefresh(1000)
end

function NativeMapClass:noteFocus()
    if self.pointerOver then
        if self.focus ~= -1 then
            self.focus = -1
            self:publish()
        end
        return
    end
    if self.inputLock or self.dumpBusy or self.versionBusy or self.queueRunning then return end
    local now = GetGameTimer()
    if now < (self.focusAt or 0) then return end
    self.focusAt = now + 150
    local gameIndex = self:readInt('GET_BRIDGE_ROW', chunkTimeout, legendColumn)
    if gameIndex == nil then return end
    local focus = gameIndex
    if focus < 0 then focus = -1 end
    if focus == self.focus then return end
    self.focus = focus
    self:publish()
end

function NativeMapClass:startCursorHideLoop()
    self.cursorHideGen = self.cursorHideGen + 1
    local generation = self.cursorHideGen
    CreateThread(function()
        while self.frontendUp and self.cursorHideGen == generation do
            if not self.inputLock then
                SetMouseCursorVisible(false)
            end
            Wait(500)
        end
    end)
end

function NativeMapClass:startLegendLoop()
    if self.hideThread then return end
    self.hideThread = true
    CreateThread(function()
        while self.open and self.hideThread and self.mode == 'legend' do
            DisableControlAction(0, 202, true)
            self:syncFrontend()
            if self.frontendHeld and self.open and not self.dumpBusy and not self.versionBusy and not self.inputLock then
                invokeFrontend('BRIDGE_MAP_HIDE', true)
                invokeFrontendHeader('BRIDGE_HIDE', true)
            end
            self:blockControls()
            self:noteWaypoint()
            self:noteFocus()
            if not self.typing and (
                    IsDisabledControlJustPressed(0, 200)
                    or IsDisabledControlJustPressed(0, 202)
                    or IsControlJustPressed(0, 202)
                ) then
                Pause:close()
                break
            end
            Wait(0)
        end
        self.hideThread = false
    end)
end

function NativeMapClass:startFallbackLoop()
    if self.inputThread then return end
    self.inputThread = true
    CreateThread(function()
        while self.open and self.inputThread and self.mode == 'fallback' do
            if IsDisabledControlJustPressed(0, 200)
                or IsDisabledControlJustPressed(0, 202)
                or IsControlJustPressed(0, 202)
            then
                Pause:close()
                break
            end
            Wait(0)
        end
        self.inputThread = false
    end)
end

--- @param timeout number
--- @return string
function NativeMapClass:waitLegend(timeout)
    local deadline = GetGameTimer() + timeout
    local announced = false
    while GetGameTimer() < deadline do
        if not self.opening and not self.open then return '' end
        local raw = self:readDump(legendColumn)
        if raw ~= '' and #parseLegend(raw) > 0 then return raw end
        self:hideChrome()
        if not announced then
            announced = true
            LT.Debug.Verbose('legend dump still empty, waiting')
        end
        Wait(50)
    end
    return ''
end

function NativeMapClass:enterFallback(message)
    LT.Debug.Error(message)
    LT.Debug.Warn('leaving the vanilla legend on screen')
    self:call('BRIDGE_MAP_HIDE', false)
    self:callHeader('BRIDGE_HIDE', true)
    ReleaseControlOfFrontend()
    self.frontendHeld = false
    self.mode = 'fallback'
    self.open = true
    self.toast = blankToast()
    self.state:set({
        status = 'fallback',
        rows = {},
        groups = {},
        toast = self.toast,
        focus = -1,
    })
    self:startFallbackLoop()
end

--- @return boolean
function NativeMapClass:begin()
    self.mode = 'idle'
    self.loggedSample = false
    self.cycles = {}
    self.toast = blankToast()
    self.focus = -1
    self.focusAt = 0
    self.state:set({
        status = 'loading',
        rows = {},
        groups = groupList,
        toast = self.toast,
        focus = -1,
    })
    if Pause then
        Pause.open = true
        Pause:setPage('gtaMap')
    end
    LT.NUI.Focus(true, true)
    SetNuiFocusKeepInput(true)

    ActivateFrontendMenu(pauseMenu, false, -1)
    self.frontendUp = true
    self:startCursorHideLoop()
    if not self:waitFrontend(2000) then
        LT.Debug.Error('map frontend did not become ready')
        return false
    end

    self.forceReleased = false
    self:holdFrontend(true)
    self:enterMapPage()
    self:hideChrome()
    local build = self:readString('GET_BRIDGE_BUILD', returnTimeout)
    if build ~= BridgeVersion then
        self:enterFallback(('map: gfx build=%s expected=%s, using the game legend'):format(
            build ~= '' and build or 'nil', BridgeVersion))
        return true
    end

    local raw = self:waitLegend(2500)
    if raw == '' then
        self:enterFallback('map: legend not found, using the game legend')
        return true
    end

    self.mode = 'legend'
    self.open = true
    self:applyDump(raw)
    self:publish()
    self.legendStamp = legendStamp(self.rows)
    self.legendVersion = self:readInt('GET_BRIDGE_VERSION', chunkTimeout)
    self.waypointReady = false
    self:startLegendLoop()
    LT.Debug.Success('map ready, %s legend rows, build %s', #self.rows, build)
    return true
end

function NativeMapClass:openMap()
    if self.open or self.opening then
        LT.Debug.Warn('map open skipped, it is already up')
        return
    end
    if Camera and Camera:isOpen() then
        LT.Debug.Warn('map open skipped, 3d camera is still open')
        return
    end
    if SettingsBridge and SettingsBridge.active then
        LT.Debug.Warn('map open skipped, settings bridge is open')
        return
    end
    if SettingsBridge and SettingsBridge.dumpBusy then
        LT.Debug.Warn('map open skipped, settings bridge is in the middle of a dump')
        return
    end
    self.opening = true
    self.returnToPause = true
    CreateThread(function()
        local ok = self:begin()
        self.opening = false
        if not ok then self:close() end
    end)
end

function NativeMapClass:close()
    if self.closing then return end
    if not self.open and not self.opening and not self.frontendUp then return end
    self.closing = true
    self.open = false
    self.opening = false
    self.hideThread = false
    self.cursorHideGen = self.cursorHideGen + 1
    self.inputThread = false
    self.pointerOver = false
    self.typing = false
    self.inputLock = false
    self.refreshUntil = 0
    self.forcePull = false
    self.versionBusy = false
    self.queue = {}
    self.queueRunning = false
    self.waypointReady = false
    self.waypointKey = nil
    self.forceReleased = false
    SetNuiFocusKeepInput(false)

    if self.frontendUp then
        if self.mode == 'legend' then
            self:holdFrontend(true)
            invokeFrontend('BRIDGE_MAP_HIDE', false)
            invokeFrontendHeader('BRIDGE_HIDE', false)
        end
        ReleaseControlOfFrontend()
        self.frontendHeld = false
        SetPauseMenuActive(false)
        SetFrontendActive(false)
        self.frontendUp = false
    end

    self.mode = 'idle'
    self.focus = -1
    self.toast = blankToast()
    self.state:set(blankState())
    local back = self.returnToPause
    self.returnToPause = false
    self.closing = false
    if back and Pause then
        LT.Debug.Info('map closed, back to the pause menu')
        Pause:onMapClosed()
    else
        LT.Debug.Info('map closed, back to the game')
    end
end

_G.NativeMap = NativeMapClass:new()

LT.NUI.Callback('GtaMapClose', function(_, cb)
    cb('ok')
    if not NativeMap:isOpen() then return end
    CreateThread(function()
        Pause:close()
    end)
end)

LT.NUI.Callback('GtaMapPointer', function(data, cb)
    cb('ok')
    local over = data and data.over == true
    if over == NativeMap.pointerOver then return end
    NativeMap.pointerOver = over
    if over then
        LT.Debug.Verbose('cursor entered the legend')
    else
        LT.Debug.Verbose('cursor left the legend')
    end
end)

LT.NUI.Callback('GtaMapTyping', function(data, cb)
    cb('ok')
    local typing = data and data.typing == true
    if typing == NativeMap.typing then return end
    NativeMap.typing = typing
    SetNuiFocusKeepInput(not typing)
    if typing then
        LT.Debug.Verbose('search focused')
    else
        LT.Debug.Verbose('search blurred')
    end
end)

LT.NUI.Callback('GtaMapSelect', function(data, cb)
    cb('ok')
    local id = data and data.id
    if not id or NativeMap.mode ~= 'legend' then return end
    local place = data.place == true
    NativeMap:enqueue(function()
        local row = NativeMap:rowFor(id)
        if not row then return end
        if place then
            NativeMap:route(row)
        else
            NativeMap:selectRow(row)
        end
    end)
end)

LT.NUI.Callback('GtaMapStep', function(data, cb)
    cb('ok')
    local id = data and data.id
    if not id or NativeMap.mode ~= 'legend' then return end
    local dir = tonumber(data.dir) or 1
    NativeMap:enqueue(function()
        NativeMap:stepRow(id, dir)
    end)
end)

LT.Hooks.Stop(function()
    if not NativeMap:isOpen() then return end
    LT.Debug.Warn('resource stopping, closing the map')
    -- Do not reopen the pause screen (and its portrait camera) while stopping.
    NativeMap.returnToPause = false
    NativeMap:close()
end)
