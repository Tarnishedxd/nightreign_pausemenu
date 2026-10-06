local cfg <const> = require 'config.main'

local dumpChunkSize <const> = 40
local returnTimeout <const> = 1000
local chunkTimeout <const> = 200
local settingsMenu <const> = `FE_MENU_VERSION_SP_PAUSE`
local keyMappingMenu <const> = `FE_MENU_VERSION_LANDING_KEYMAPPING_MENU`
local graphicsCategoryIndexes <const> = { [6] = true, [7] = true }
local keyBindingCategoryIndexes <const> = { [2] = true }
local veilFadeMs <const> = 400
local cursorHideDelayMs <const> = 280
local cursorHideIntervalMs <const> = 500

---@class SettingsBridgeClass
---@field active boolean
---@field busy boolean
---@field awaitingApplyConfirm boolean
---@field unsavedPrompt boolean
---@field applyHoldUntil integer
---@field restoreCategoryId string|nil
---@field discardCategoryId string|nil
---@field dumpBatchSize integer
---@field lastVersion integer
---@field state table
---@field hideThread boolean
---@field frontendHold boolean
---@field cursorHideGen integer
---@field pollThread boolean
---@field changeThread boolean
---@field dumpBusy boolean
---@field optionsColumn integer|nil
---@field groupColumn integer|nil
---@field navColumn integer
---@field calmUntil integer
---@field navRaw string
---@field categories table
---@field categoryById table
---@field rowByIndex table
---@field cache table
---@field pending table
---@field pendingSnapshots table
---@field lastRawByIndex table
---@field changeOrder table
---@field changeByRow table
---@field lastColumns table|nil
local SettingsBridgeClass = {}
SettingsBridgeClass.__index = SettingsBridgeClass

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- PARSE
-- ════════════════════════════════════════════════════════════════════════════════════════════

local asBool = Scaleform.asBool
local split = Scaleform.split
local rowCount = Scaleform.rowCount
local addScaleformParams = Scaleform.addParams
local awaitReturn = Scaleform.awaitReturn

local function asEnabled(value)
    if value == true or value == 'true' or value == '1' or value == 1 then return true end
    if value == false or value == 'false' or value == '0' or value == 0 then return false end
end

local function beginFrontendReturn(method, ...)
    if not BeginScaleformMovieMethodOnFrontend(method) then return nil end
    addScaleformParams({ ... })
    return EndScaleformMovieMethodReturnValue()
end

local function commandHash(value)
    return string.format('%08x', value & 0xFFFFFFFF)
end

local function validResourceName(value)
    return type(value) == 'string' and value ~= '' and value:match('^[%w_.-]+$') ~= nil
end

local function validCommand(value)
    return type(value) == 'string' and value ~= '' and value:match('^[^%s"]+$') ~= nil
end

local function isEmptyField(value)
    return value == nil or value == '' or value == 'undefined'
end

local function parseDumpRow(segment, index, asKeys)
    local parts = split(segment, '|')
    local offset = asBool(parts[5]) ~= nil and 0 or 1
    local enabled = asEnabled(parts[5 + offset])
    if enabled == nil then enabled = true end

    ---@type integer?
    local labelIndex = 6 + offset
    while labelIndex <= #parts and isEmptyField(parts[labelIndex]) do
        labelIndex += 1
    end
    local label = parts[labelIndex]
    if not label or tonumber(label) or asBool(label) ~= nil then
        local texts = {}
        for partIndex = 1, #parts do
            local part = parts[partIndex]
            if not isEmptyField(part) and tonumber(part) == nil and asBool(part) == nil then
                texts[#texts + 1] = part
            end
        end
        label = texts[1]
        if not label then return nil end
        labelIndex = nil
        for partIndex = 1, #parts do
            if parts[partIndex] == label then
                labelIndex = partIndex
                break
            end
        end
    end

    local choices = {}
    if labelIndex then
        for partIndex = labelIndex + 1, #parts do
            local part = parts[partIndex]
            if not isEmptyField(part) and tonumber(part) == nil and asBool(part) == nil then
                choices[#choices + 1] = part
            end
        end
    end

    local selectedIndex = tonumber(parts[4 + offset])
    local rowType = tonumber(parts[3 + offset]) or 0
    local kind = 'info'
    local value = ''
    local maxIndex = 0
    local step

    if not enabled then
        local hasExtra = false
        if labelIndex then
            for partIndex = labelIndex + 1, #parts do
                if not isEmptyField(parts[partIndex]) then
                    hasExtra = true
                    break
                end
            end
        end
        if #choices == 0 and not hasExtra then
            kind = 'info'
        else
            kind = 'locked'
            value = (selectedIndex and choices[selectedIndex + 1]) or choices[1] or ''
            maxIndex = math.max(#choices - 1, selectedIndex or 0)
        end
        selectedIndex = selectedIndex or 0
    elseif #choices > 1 then
        kind = asKeys and 'button' or 'options'
        maxIndex = #choices - 1
        if selectedIndex == nil or selectedIndex < 0 or selectedIndex > maxIndex then
            selectedIndex = 0
        end
        value = choices[selectedIndex + 1] or choices[1]
    elseif #choices == 1 then
        kind = 'cycled'
        value = choices[1]
        selectedIndex = 0
        maxIndex = 0
    elseif selectedIndex ~= nil then
        local maxBound
        local trailing = 0
        local displayValue
        if labelIndex then
            for partIndex = labelIndex + 1, #parts do
                if not isEmptyField(parts[partIndex]) then
                    trailing += 1
                    if not displayValue then displayValue = parts[partIndex] end
                end
            end
            local nextNumber = tonumber(parts[labelIndex + 1])
            local wideSlider = rowType == 2 and tonumber(parts[labelIndex + 2]) == 116
            local maxLimit = wideSlider and nextNumber or 32
            if nextNumber and nextNumber >= selectedIndex and nextNumber <= maxLimit then
                if not (trailing == 1 and selectedIndex == 0 and nextNumber <= 1) then
                    maxBound = nextNumber
                end
            end
        end
        if maxBound then
            kind = 'slider'
            maxIndex = maxBound
            value = tostring(selectedIndex)
            if maxBound > 32 and rowType == 2 and labelIndex and tonumber(parts[labelIndex + 2]) == 116 then
                step = 10
            end
        elseif displayValue then
            kind = 'cycled'
            value = displayValue
            choices = { displayValue }
            selectedIndex = 0
            maxIndex = 0
        else
            kind = 'button'
            selectedIndex = 0
        end
    elseif enabled then
        kind = 'button'
        selectedIndex = 0
    end

    return {
        type = 'setting',
        id = ('%s:%s'):format(tonumber(parts[2 + offset]) or index, index),
        index = index,
        menuId = tonumber(parts[1 + offset]) or 0,
        uniqueId = tonumber(parts[2 + offset]) or index,
        rowType = rowType,
        label = label,
        kind = kind,
        editable = enabled and kind ~= 'info' and kind ~= 'locked',
        value = value,
        selectedIndex = selectedIndex or 0,
        maxIndex = maxIndex,
        step = step,
        choices = choices,
        raw = segment,
    }
end

local function parseDump(raw, asKeys)
    local rows = {}
    local index = 0
    for segment in ((raw or '') .. '##'):gmatch('(.-)##') do
        if segment ~= '' then
            local row = parseDumpRow(segment, index, asKeys)
            if row then
                rows[#rows + 1] = row
            else
                rows[#rows + 1] = {
                    type = 'setting',
                    id = ('spacer:%s'):format(index),
                    index = index,
                    menuId = 0,
                    uniqueId = index,
                    rowType = 0,
                    label = '',
                    kind = 'spacer',
                    editable = false,
                    value = '',
                    selectedIndex = 0,
                    maxIndex = 0,
                    choices = {},
                    raw = segment,
                }
            end
            index += 1
        end
    end
    return rows
end

---@return SettingsBridgeClass
function SettingsBridgeClass:new()
    local self = setmetatable({}, SettingsBridgeClass)
    self.active = false
    self.busy = false
    self.hideThread = false
    self.frontendHold = false
    self.cursorHideGen = 0
    self.pollThread = false
    self.changeThread = false
    self.dumpBusy = false
    self.navColumn = 0
    self.optionsColumn = nil
    self.groupColumn = nil
    self.navRaw = ''
    self.lastVersion = -1
    self.calmUntil = 0
    self.dumpBatchSize = 16
    self.categories = {}
    self.categoryById = {}
    self.rowByIndex = {}
    self.cache = {}
    self.pending = {}
    self.pendingSnapshots = {}
    self.lastRawByIndex = {}
    self.awaitingApplyConfirm = false
    self.unsavedPrompt = false
    self.applyHoldUntil = 0
    self.restoreCategoryId = nil
    self.discardCategoryId = nil
    self.changeOrder = {}
    self.changeByRow = {}
    self.listening = false
    self.keyButtonIds = {}
    self.state = LT.NUI.CreateState('UpdateSettings', {
        status = 'idle',
        build = '',
        error = '',
        categories = {},
        activeCategoryId = '',
        rows = {},
        version = 0,
        busy = false,
        keyBindings = false,
        keyGroups = {},
        activeKeyGroupId = '',
        listenIndex = -1,
        listenSlot = '',
        listenPhase = '',
        keyPrompt = false,
        vram = '',
        vramPercent = -1,
        pendingCount = 0,
        veil = false,
    })
    return self
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- FRONTEND
-- ════════════════════════════════════════════════════════════════════════════════════════════

---@param timeout number?
---@return boolean
function SettingsBridgeClass:acquireDump(timeout)
    local deadline = GetGameTimer() + (timeout or returnTimeout)
    while (self.dumpBusy or (NativeMap and NativeMap:isDumping())) and GetGameTimer() < deadline do Wait(0) end
    if self.dumpBusy or (NativeMap and NativeMap:isDumping()) then return false end
    self.dumpBusy = true
    return true
end

function SettingsBridgeClass:releaseDump()
    self.dumpBusy = false
end

---@param method string
---@return boolean
function SettingsBridgeClass:call(method, ...)
    if not BeginScaleformMovieMethodOnFrontend(method) then return false end
    addScaleformParams({ ... })
    EndScaleformMovieMethod()
    return true
end

---@param method string
---@return boolean
function SettingsBridgeClass:callHeader(method, ...)
    if not BeginScaleformMovieMethodOnFrontendHeader(method) then return false end
    addScaleformParams({ ... })
    EndScaleformMovieMethod()
    return true
end

---@param method string
---@param timeout number?
---@return integer|nil
function SettingsBridgeClass:readInt(method, timeout, ...)
    local value = awaitReturn(beginFrontendReturn(method, ...), 'int', timeout)
    if type(value) ~= 'number' then return nil end
    return value
end

---@param method string
---@param timeout number?
---@return string
function SettingsBridgeClass:readString(method, timeout, ...)
    local value = awaitReturn(beginFrontendReturn(method, ...), 'string', timeout)
    if type(value) ~= 'string' then return '' end
    return value
end

function SettingsBridgeClass:hideFrontend()
    if cfg.debug >= 5 then return end
    self:call('BRIDGE_HIDE', true)
    self:callHeader('BRIDGE_HIDE', true)
end

function SettingsBridgeClass:showFrontend()
    self:call('BRIDGE_HIDE', false)
    self:callHeader('BRIDGE_HIDE', false)
end

function SettingsBridgeClass:hideGameCursor()
    SetMouseCursorVisible(false)
end

function SettingsBridgeClass:showGameCursor()
    self.cursorHideGen = self.cursorHideGen + 1
    SetMouseCursorVisible(true)
end

function SettingsBridgeClass:scheduleHideGameCursor()
    self.cursorHideGen = self.cursorHideGen + 1
    local generation = self.cursorHideGen
    CreateThread(function()
        Wait(cursorHideDelayMs)
        if self.cursorHideGen ~= generation or not self.active then return end
        self:hideGameCursor()
    end)
end

function SettingsBridgeClass:focusUi()
    LT.NUI.Focus(true, true)
end

function SettingsBridgeClass:clearUiFocus()
    LT.NUI.Focus(false)
end

---@param value boolean
function SettingsBridgeClass:setBusy(value)
    self.busy = value
    self.state.busy = value
end

--- Runs fn on its own thread with the page busy. An error must not leave it busy: the menu
--- only closes once the page is idle, so the player would be stuck in it.
--- @param fn fun(): boolean|nil return true to stay busy (the popup answer clears it)
function SettingsBridgeClass:busyThread(fn)
    self:setBusy(true)
    CreateThread(function()
        local ok, keep = pcall(fn)
        if not ok then LT.Debug.Error('settings action failed: %s', tostring(keep)) end
        if not ok or keep ~= true then self:setBusy(false) end
    end)
end

function SettingsBridgeClass:startHideLoop()
    if self.hideThread then return end
    self.hideThread = true
    CreateThread(function()
        local nextCursorHide = 0
        while self.active and self.hideThread do
            if not self.frontendHold then
                self:hideFrontend()
            end
            if not self.listening and not self.passControls then
                DisableControlAction(0, 187, true)
                DisableControlAction(0, 188, true)
                DisableControlAction(0, 189, true)
                DisableControlAction(0, 190, true)
                DisableControlAction(2, 187, true)
                DisableControlAction(2, 188, true)
                DisableControlAction(2, 189, true)
                DisableControlAction(2, 190, true)
            end
            if self.active and not self.passControls and GetGameTimer() >= nextCursorHide then
                self:hideGameCursor()
                nextCursorHide = GetGameTimer() + cursorHideIntervalMs
            end
            Wait(0)
        end
        self.hideThread = false
    end)
end

function SettingsBridgeClass:withVisibleFrontend(fn)
    if self.frontendHold or not self.active then
        fn()
        return
    end
    self.frontendHold = true
    self.state.veil = true
    Wait(veilFadeMs)
    local ok, err = true, nil
    if self.active then
        self:showFrontend()
        ok, err = pcall(fn)
        self:hideFrontend()
    else
        ok, err = pcall(fn)
    end
    self.state.veil = false
    Wait(veilFadeMs)
    self.frontendHold = false
    if not ok then error(err) end
end

function SettingsBridgeClass:withKeyScreen(fn)
    if self.frontendHold or not self.active then
        fn()
        return
    end
    self.frontendHold = true
    self.state.keyPrompt = true
    self.state:sync()
    Wait(veilFadeMs)
    local ok, err = true, nil
    if self.active then
        self:showFrontend()
        self:clearUiFocus()
        ReleaseControlOfFrontend()
        ok, err = pcall(fn)
        TakeControlOfFrontend()
        self:hideFrontend()
        if self.active then
            self:hideGameCursor()
            self:focusUi()
        end
    else
        ok, err = pcall(fn)
    end
    self.state.keyPrompt = false
    if self.active then self.state:sync() end
    Wait(veilFadeMs)
    self.frontendHold = false
    if not ok then error(err) end
end

---@param timeout number?
---@return boolean
function SettingsBridgeClass:waitFrontend(timeout)
    local deadline = GetGameTimer() + (timeout or 2000)
    while GetGameTimer() < deadline do
        if IsPauseMenuActive() and not IsPauseMenuRestarting() and IsFrontendReadyForControl() then
            return true
        end
        Wait(0)
    end
    return false
end

function SettingsBridgeClass:readDumpParts(partCount, batchSize)
    local values = {}
    local part = 0
    while part < partCount do
        local handles = {}
        local batchEnd = math.min(partCount, part + batchSize)
        for partIndex = part, batchEnd - 1 do
            handles[#handles + 1] = {
                index = partIndex,
                handle = beginFrontendReturn('GET_BRIDGE_DUMP', partIndex),
            }
        end
        for handleIndex = 1, #handles do
            local entry = handles[handleIndex]
            local value = awaitReturn(entry.handle, 'string', chunkTimeout)
            if value == nil then return nil end
            values[entry.index + 1] = value
        end
        part = batchEnd
    end
    return table.concat(values)
end

---@param column integer
---@return string
function SettingsBridgeClass:readDump(column)
    if not self:acquireDump(returnTimeout) then return '' end
    local expectedRows = self:readInt('GET_BRIDGE_COUNT', returnTimeout, column) or 0
    local partCount = self:readInt('BRIDGE_DUMP', returnTimeout, column, dumpChunkSize) or 0
    if partCount <= 0 then
        self:releaseDump()
        return ''
    end
    local preferred = GetGameTimer() < self.calmUntil and math.min(4, self.dumpBatchSize) or self.dumpBatchSize
    local attempts = { preferred, 8, 4, 1 }
    local tried = {}
    for attempt = 1, #attempts do
        local batchSize = math.max(1, math.min(16, attempts[attempt]))
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

---@return table
function SettingsBridgeClass:readColumns()
    local columns = {}
    for column = 0, 2 do
        columns[column] = self:readDump(column)
    end
    return columns
end

---@return string, integer
function SettingsBridgeClass:readVram()
    local chunks = {}
    for part = 0, 15 do
        local chunk = self:readString('GET_BRIDGE_VIDMEM', chunkTimeout, part)
        if chunk == '' then break end
        chunks[#chunks + 1] = chunk
        if #chunk < dumpChunkSize then break end
    end
    local raw = table.concat(chunks)
    if raw == '' then return '', -1 end
    local label, percentText = raw:match('^(.*)|(%-?%d+)%s*$')
    if not label or label == '' then return '', -1 end
    local percent = tonumber(percentText)
    return label, percent or -1
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- NAVIGATION
-- ════════════════════════════════════════════════════════════════════════════════════════════

---@return boolean
function SettingsBridgeClass:isGraphicsPage()
    local category = self.categoryById[self.state.activeCategoryId]
    return category and graphicsCategoryIndexes[category.index] == true
end

---@return boolean
function SettingsBridgeClass:usesKeyBindings()
    local category = self.categoryById[self.state.activeCategoryId]
    return category and keyBindingCategoryIndexes[category.index] == true or false
end

---@param raw string
---@return boolean
function SettingsBridgeClass:buildCategories(raw)
    local rows = parseDump(raw)
    local categories = {}
    local categoryById = {}
    for index = 1, #rows do
        local row = rows[index]
        local id = ('%s:%s'):format(row.uniqueId, row.index)
        local category = {
            id = id,
            label = row.label,
            index = row.index,
            pending = self.pending[id] and self.pending[id].count or 0,
        }
        categories[#categories + 1] = category
        categoryById[id] = category
    end
    self.categories = categories
    self.categoryById = categoryById
    self.state.categories = categories
    return #categories > 0
end

---@return boolean
function SettingsBridgeClass:findNavigation()
    local columns = self:readColumns()
    self.lastColumns = columns
    local parsedColumns = {}
    for column = 0, 2 do
        local raw = columns[column] or ''
        parsedColumns[column] = {
            raw = raw,
            rows = parseDump(raw),
            segments = rowCount(raw),
        }
    end

    local function accept(column)
        local candidate = parsedColumns[column]
        if not candidate or #candidate.rows == 0 then return false end
        self.navColumn = column
        self.navRaw = candidate.raw
        return self:buildCategories(candidate.raw)
    end

    if accept(0) then return true end

    local bestColumn, bestRatio = nil, 0
    for column = 1, 2 do
        local candidate = parsedColumns[column]
        if candidate.segments > 0 then
            local ratio = #candidate.rows / candidate.segments
            local shorter = bestColumn and candidate.segments < parsedColumns[bestColumn].segments
            if ratio > bestRatio or (ratio == bestRatio and shorter) then
                bestColumn = column
                bestRatio = ratio
            end
        end
    end
    return bestColumn ~= nil and accept(bestColumn) or false
end

---@param timeout number?
---@return 'ready'|'unparsed'|'empty'
function SettingsBridgeClass:waitForNavigation(timeout)
    local deadline = GetGameTimer() + (timeout or 2500)
    while self.active and GetGameTimer() < deadline do
        if self:findNavigation() then return 'ready' end
        Wait(0)
    end
    local columns = self.lastColumns or {}
    local hasDump = false
    for column = 0, 2 do
        if rowCount(columns[column] or '') > 0 then hasDump = true end
    end
    return hasDump and 'unparsed' or 'empty'
end

---@return string?
---@return integer?
function SettingsBridgeClass:readyOptions()
    for column = 0, 2 do
        if column ~= self.navColumn then
            local raw = self:readDump(column)
            if raw ~= '' and raw ~= self.navRaw and rowCount(raw) > 0 then
                return raw, column
            end
        end
    end
    return nil, nil
end

---@return integer
function SettingsBridgeClass:leaveTopMenu()
    local state = self:readInt('GET_BRIDGE_STATE', chunkTimeout) or 0
    if state ~= 0 then return state end
    self:call('PRESS_SHIFT_DEPTH', 1)
    local deadline = GetGameTimer() + 500
    while self.active and GetGameTimer() < deadline do
        state = self:readInt('GET_BRIDGE_STATE', chunkTimeout) or 0
        if state ~= 0 then break end
        Wait(0)
    end
    return state
end

---@param version integer
---@param timeout number?
---@return string?
---@return integer?
---@return integer?
function SettingsBridgeClass:waitForOptions(version, timeout)
    local deadline = GetGameTimer() + (timeout or 450)
    local openedKeyMappings = false
    local leftSettingsAt = 0
    local changedAt = 0
    local observedVersion = version
    while self.active and GetGameTimer() < deadline do
        if IsPauseMenuRestarting() then
            self:waitFrontend(1000)
            self.calmUntil = GetGameTimer() + 200
            leftSettingsAt = 0
        else
            local menu = GetCurrentFrontendMenuVersion()
            if menu == keyMappingMenu then
                openedKeyMappings = true
            elseif self.allowKeyMapping and not openedKeyMappings and not IsPauseMenuActive() and menu ~= settingsMenu then
                if leftSettingsAt == 0 then
                    leftSettingsAt = GetGameTimer()
                elseif GetGameTimer() - leftSettingsAt >= 120 then
                    openedKeyMappings = true
                    ActivateFrontendMenu(keyMappingMenu, true, -1)
                    self:waitFrontend(1000)
                    self.calmUntil = GetGameTimer() + 200
                    deadline = math.max(deadline, GetGameTimer() + 500)
                end
            else
                leftSettingsAt = 0
            end
        end
        local currentVersion = self:readInt('GET_BRIDGE_VERSION', chunkTimeout) or version
        if currentVersion ~= observedVersion then
            observedVersion = currentVersion
            changedAt = GetGameTimer()
        elseif changedAt > 0 and GetGameTimer() - changedAt >= 40 then
            local raw, column = self:readyOptions()
            if raw and column then return raw, column, observedVersion end
        end
        Wait(0)
    end
    local raw, column = self:readyOptions()
    if raw and column then return raw, column, observedVersion end
    return nil, nil, nil
end

local function splitBindingLabel(label)
    local resource = label:match('%(([%w_.-]+)%)') or ''
    local name = label:gsub('<%s*[Ff][Oo][Nn][Tt][^>]*>', ''):gsub('<%s*/%s*[Ff][Oo][Nn][Tt]%s*>', '')
    name = name:gsub('%s*%([%w_.-]+%)%s*', ' ')
    name = (name:gsub('%s+', ' '):match('^%s*(.-)%s*$')) or ''
    return name, resource
end

local function instructionalLabel(button)
    button = (button or ''):gsub('~', '')
    button = button:match('^%s*(.-)%s*$') or ''
    if button == '' then return '' end
    local parts = {}
    for token in (button .. '%'):gmatch('(.-)%%') do
        token = token:match('^%s*(.-)%s*$') or ''
        if token ~= '' then
            local lower = token:lower()
            if lower == 'b_995' then
                -- unbound or key-removed sprite idk
            elseif lower == '+' or lower == 'b_998' then
                parts[#parts + 1] = '+'
            else
                local typed = token:match('^[tTwW]_(.+)$')
                if typed and typed ~= '' then
                    parts[#parts + 1] = typed:upper()
                else
                    local mapped = InstructionalKeys[lower]
                    if mapped and mapped ~= '' then
                        parts[#parts + 1] = mapped
                    end
                end
            end
        end
    end
    if #parts == 0 then return '' end
    return table.concat(parts, ' / ')
end

local function isBoundButton(button)
    button = (button or ''):gsub('~', '')
    button = button:match('^%s*(.-)%s*$') or ''
    if button == '' then return false end
    local lower = button:lower()
    if lower == 'b_995' or lower == 'b_996' or lower == 'b_997' or lower == 'b_999' then
        return false
    end
    if button:find('%', 1, true) then return false end
    if button:match('^[tT]_.+') then return true end
    return InstructionalKeys[lower] ~= nil
end

local function hashToControl(hashHex)
    local n = tonumber(hashHex, 16)
    if type(n) ~= 'number' then return nil end
    local control = (n & 0xFFFFFFFF) | 0x80000000
    if control >= 0x80000000 then
        control = control - 0x100000000
    end
    return control
end

local function dumpMapperHash(raw)
    if type(raw) ~= 'string' or raw == '' then return nil end
    return raw:lower():match('input_([%x][%x][%x][%x][%x][%x][%x][%x])')
end

local function dumpGtaControl(raw)
    if type(raw) ~= 'string' or raw == '' then return nil, false end
    local named = raw:upper():match('(INPUT_[A-Z0-9_]+)')
    if not named then return nil, false end
    local indexed = ControlIndex[named]
    if indexed ~= nil then return indexed, false end
    return hashToControl(commandHash(GetHashKey(named))), true
end

local function buttonLabel(control, mapper)
    if control == nil then return '' end
    local raw = GetControlInstructionalButton(2, control, mapper == true) or ''
    if not isBoundButton(raw) then return '' end
    return instructionalLabel(raw)
end

local function keyPrimary(raw)
    local mapperHash = dumpMapperHash(raw)
    if mapperHash then
        return buttonLabel(hashToControl(mapperHash), true)
    end
    local control, hashed = dumpGtaControl(raw)
    if control ~= nil then
        return buttonLabel(control, hashed)
    end
    return ''
end

function SettingsBridgeClass:buildCommandLookup()
    local lookup = {}
    for _, command in ipairs(GetRegisteredCommands()) do
        local name = command.name
        if validCommand(name) then
            local record = { command = name, resource = command.resource or '' }
            lookup[commandHash(GetHashKey(name))] = record
            if joaat then lookup[commandHash(joaat(name))] = record end
        end
    end
    return lookup
end

---@param rows table
---@return table
---@return table
function SettingsBridgeClass:makeKeyBindingRows(rows)
    local lookup = self:buildCommandLookup()
    local category = self.categoryById[self.state.activeCategoryId]
    local fallbackLabel = category and category.label ~= '' and category.label or 'Key Bindings'
    local groups = {}
    local group = nil
    local bindings = {}

    local function useGroup(id, label, groupIndex)
        group = { id = id, label = label, index = groupIndex }
        groups[#groups + 1] = group
        return group
    end

    for index = 1, #rows do
        local row = rows[index]
        local label = row.label or ''
        if row.kind ~= 'spacer' and label ~= '' then
            if row.kind == 'info' then
                local plain = splitBindingLabel(label)
                useGroup(('group:%s'):format(row.index), plain ~= '' and plain or label, row.index)
            else
                local activeGroup = group
                if not activeGroup then
                    activeGroup = useGroup('group:default', fallbackLabel, 0)
                end
                local mapperHash = dumpMapperHash(row.raw)
                local command = (mapperHash and lookup[mapperHash])
                    or (type(row.uniqueId) == 'number' and lookup[commandHash(row.uniqueId)])
                    or nil
                local actionName, taggedResource = splitBindingLabel(label)
                local commandName = command and command.command or ''
                local bindResource = (command and command.resource ~= '' and command.resource) or taggedResource
                local alternate = commandName:sub(1, 2) == '~!'
                local canBind = not alternate and validResourceName(bindResource) and validCommand(commandName)
                local primary = (not alternate) and keyPrimary(row.raw) or ''
                local binding = {
                    type = 'keybind',
                    id = row.id,
                    index = row.index,
                    groupId = activeGroup.id,
                    action = actionName,
                    resource = taggedResource,
                    primary = primary,
                    secondary = '',
                    editable = row.kind ~= 'locked' and not alternate,
                    command = canBind and commandName or '',
                }
                bindings[#bindings + 1] = binding
            end
        end
    end

    local used = {}
    for index = 1, #bindings do
        used[bindings[index].groupId] = true
    end
    local kept = {}
    for index = 1, #groups do
        if used[groups[index].id] then
            kept[#kept + 1] = groups[index]
        end
    end
    return bindings, kept
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- ROWS
-- ════════════════════════════════════════════════════════════════════════════════════════════

---@param groups table
function SettingsBridgeClass:publishKeyGroups(groups)
    self.keyButtonIds = {}
    for index = 1, #groups do
        local group = groups[index]
        if group.button then
            self.keyButtonIds[group.id] = true
        end
    end
    self.state.keyGroups = groups
    local active = self.state.activeKeyGroupId
    for index = 1, #groups do
        if groups[index].id == active then return end
    end
    self.state.activeKeyGroupId = groups[1] and groups[1].id or ''
end

---@param group table|nil
---@return boolean
function SettingsBridgeClass:isKeyGroupButton(group)
    if not group then return false end
    if self.keyButtonIds and self.keyButtonIds[group.id] then return true end
    if group.button then return true end
    local label = (group.label or ''):lower()
    return label:find('restore', 1, true) ~= nil and label:find('default', 1, true) ~= nil
end

---@param actionColumn integer|nil
---@return integer|nil
---@return table|nil
function SettingsBridgeClass:readKeyGroupColumn(actionColumn)
    local actionRaw = actionColumn and self:readDump(actionColumn) or ''
    local chosenColumn, chosenRows, chosenLabels
    for column = 0, 2 do
        if column ~= actionColumn then
            local raw = self:readDump(column)
            if raw ~= '' and raw ~= self.navRaw and raw ~= actionRaw then
                local parsed = parseDump(raw)
                local labels, keyed = 0, 0
                for index = 1, #parsed do
                    local row = parsed[index]
                    if row.kind ~= 'spacer' and (row.label or '') ~= '' then
                        labels = labels + 1
                        if type(row.choices) == 'table' and #row.choices > 0 then
                            keyed = keyed + 1
                        end
                    end
                end
                local score = labels * 2 - keyed
                if labels >= 2 and (not chosenLabels or score > chosenLabels) then
                    chosenColumn = column
                    chosenRows = parsed
                    chosenLabels = score
                end
            end
        end
    end
    if not chosenRows then return nil, nil end
    local groups = {}
    for index = 1, #chosenRows do
        local row = chosenRows[index]
        if row.kind ~= 'spacer' and (row.label or '') ~= '' then
            groups[#groups + 1] = {
                id = ('keygroup:%s'):format(row.index),
                label = row.label,
                index = row.index,
            }
        end
    end
    if #groups > 0 then
        groups[#groups].button = true
    end
    if #groups == 0 then return nil, nil end
    return chosenColumn, groups
end

---@param rows table
---@param column integer
---@param version integer|nil
function SettingsBridgeClass:publishRows(rows, column, version)
    local keyBindings = self:usesKeyBindings()
    local outputRows = rows
    if keyBindings then
        local bindings, headerGroups = self:makeKeyBindingRows(rows)
        local groupColumn, columnGroups = self:readKeyGroupColumn(column)
        if columnGroups and #columnGroups > 1 then
            self.groupColumn = groupColumn
            local activeKnown = false
            for index = 1, #columnGroups do
                if columnGroups[index].id == self.state.activeKeyGroupId then
                    activeKnown = true
                    break
                end
            end
            if not activeKnown then
                local highlighted = groupColumn and self:readInt('GET_BRIDGE_ROW', chunkTimeout, groupColumn)
                if type(highlighted) == 'number' and highlighted >= 0 then
                    for index = 1, #columnGroups do
                        if columnGroups[index].index == highlighted then
                            self.state.activeKeyGroupId = columnGroups[index].id
                            break
                        end
                    end
                end
            end
            self:publishKeyGroups(columnGroups)
            local active = self.state.activeKeyGroupId
            for index = 1, #bindings do
                bindings[index].groupId = active
            end
            outputRows = bindings
        elseif self.groupColumn and #(self.state.keyGroups or {}) > 1 then
            local active = self.state.activeKeyGroupId
            for index = 1, #bindings do
                bindings[index].groupId = active
            end
            outputRows = bindings
        else
            self.groupColumn = nil
            outputRows = bindings
            if #headerGroups > 1 then
                self:publishKeyGroups(headerGroups)
            else
                self.state.keyGroups = {}
                self.state.activeKeyGroupId = ''
            end
        end
    end
    local pendingRows = self.pending[self.state.activeCategoryId]
    if not keyBindings and pendingRows then
        for index = 1, #outputRows do
            local out = outputRows[index]
            if pendingRows.rows[out.id] then
                out.pending = true
                local snap = self.pendingSnapshots[out.id]
                if snap then
                    if type(snap.expectedIndex) == 'number' then
                        out.selectedIndex = snap.expectedIndex
                    end
                    if snap.expectedValue and snap.expectedValue ~= '' then
                        out.value = snap.expectedValue
                    end
                end
            end
        end
    end
    self.optionsColumn = column
    self.rowByIndex = {}
    for index = 1, #outputRows do
        self.rowByIndex[outputRows[index].index] = outputRows[index]
    end
    local categoryId = self.state.activeCategoryId
    self.cache[categoryId] = outputRows
    self.state.rows = outputRows
    self.state.keyBindings = keyBindings
    if keyBindings then
        self.state.vram = ''
        self.state.vramPercent = -1
    else
        self.state.keyGroups = {}
        self.state.activeKeyGroupId = ''
        self.groupColumn = nil
        local vram, vramPercent = self:readVram()
        self.state.vram = vram
        self.state.vramPercent = vramPercent
    end
    self.state.version = version or self.state.version
    self.state.status = 'ready'
end

---@param rows table
---@return table
function SettingsBridgeClass:captureRawByIndex(rows)
    local next = {}
    for index = 1, #rows do
        local row = rows[index]
        if row and row.index ~= nil then
            next[row.index] = {
                value = row.value or '',
                selectedIndex = tonumber(row.selectedIndex) or 0,
                kind = row.kind,
                id = row.id,
            }
        end
    end
    return next
end

---@param rows table
function SettingsBridgeClass:storeRawByIndex(rows)
    self.lastRawByIndex = self:captureRawByIndex(rows)
end

---@param row table
function SettingsBridgeClass:updateRawForRow(row)
    if not row or row.index == nil then return end
    self.lastRawByIndex = self.lastRawByIndex or {}
    self.lastRawByIndex[row.index] = {
        value = row.value or '',
        selectedIndex = tonumber(row.selectedIndex) or 0,
        kind = row.kind,
        id = row.id,
    }
end

function SettingsBridgeClass:labelFor(row, index, fallback)
    if row.kind == 'cycled' then
        return row.choices[1] or row.value or ''
    end
    if row.kind == 'options' and type(row.choices) == 'table' and row.choices[index + 1] then
        return row.choices[index + 1]
    end
    if row.kind == 'slider' and type(index) == 'number' then
        return tostring(index)
    end
    if fallback and fallback ~= '' then return fallback end
    return row.value or ''
end

function SettingsBridgeClass:writeStepValue(row, stepped, label)
    local selectedIndex = tonumber(row.selectedIndex) or 0
    local value = row.value or ''
    local maxIndex = tonumber(row.maxIndex) or 0
    local choices = row.choices
    if row.kind == 'cycled' then
        selectedIndex = 0
        maxIndex = 0
        if label and label ~= '' then
            value = label
            choices = { label }
        end
    else
        if type(stepped) ~= 'number' or stepped < 0 then return end
        selectedIndex = stepped
        if row.kind == 'options' and row.choices[stepped + 1] then
            value = row.choices[stepped + 1]
        elseif row.kind == 'slider' then
            value = tostring(stepped)
            if stepped > maxIndex then maxIndex = stepped end
        elseif label and label ~= '' then
            value = label
        end
    end
    local nextRow = {}
    for key, field in pairs(row) do
        nextRow[key] = field
    end
    nextRow.selectedIndex = selectedIndex
    nextRow.value = value
    nextRow.maxIndex = maxIndex
    nextRow.choices = choices
    for index = 1, #self.state.rows do
        local stateRow = self.state.rows[index]
        if stateRow and stateRow.index == row.index then
            self.state.rows[index] = nextRow
            break
        end
    end
    self.rowByIndex[row.index] = nextRow
    local categoryId = self.state.activeCategoryId
    local cached = categoryId and self.cache[categoryId]
    if cached then
        for cacheIndex = 1, #cached do
            if cached[cacheIndex].index == row.index then
                cached[cacheIndex] = nextRow
                break
            end
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- CATEGORY
-- ════════════════════════════════════════════════════════════════════════════════════════════

---@param categoryId string
---@return boolean
function SettingsBridgeClass:selectCategory(categoryId)
    if not self.active or self:isBusy() then return false end
    local category = self.categoryById[categoryId]
    if not category then return false end
    local current = self.categoryById[self.state.activeCategoryId]
    local leavingKeys = current and keyBindingCategoryIndexes[current.index] == true
    local openingKeys = keyBindingCategoryIndexes[category.index] == true
    if leavingKeys and not openingKeys and categoryId ~= self.state.activeCategoryId then
        self:restartCategory(categoryId)
        return true
    end
    if categoryId ~= self.state.activeCategoryId and self:hasUnsavedGraphics() then
        self:promptUnsaved(categoryId)
        return false
    end

    self:setBusy(true)
    self.state.status = 'loading'
    self.allowKeyMapping = keyBindingCategoryIndexes[category.index] == true
    if self.allowKeyMapping then
        self.state.keyBindings = true
        self.state.rows = {}
        self.state.keyGroups = {}
        self.state.activeKeyGroupId = ''
        self.state:sync()
        Wait(0)
    else
        self.state.keyBindings = false
        self.state.keyGroups = {}
        self.state.activeKeyGroupId = ''
        self.groupColumn = nil
    end

    local success = false
    local lastEnter
    local lastVersion = self.lastVersion
    local lastNext = self.lastVersion
    for attempt = 1, 3 do
        self:leaveTopMenu()
        lastVersion = self:readInt('GET_BRIDGE_VERSION', chunkTimeout) or self.lastVersion
        lastEnter = self:readInt('BRIDGE_PRESS', returnTimeout, category.index, self.navColumn)
        local raw, column, nextVersion = self:waitForOptions(lastVersion, 450)
        lastNext = nextVersion or lastVersion
        if raw and column then
            self.state.activeCategoryId = categoryId
            self.lastVersion = lastNext
            local rows = parseDump(raw, self:usesKeyBindings())
            self:storeRawByIndex(rows)
            self:publishRows(rows, column, self.lastVersion)
            if cfg.debug >= 4 then
                emitNet('settings:writeDump', {
                    index = category.index,
                    label = category.label,
                    raw = raw,
                    parsed = json.encode(rows),
                })
            end
            if column ~= self.navColumn then
                self:call('M_PRESS_EVENT', 0, column, false, true)
            end
            success = true
            break
        end
        Wait(0)
    end

    if not success then
        self.state.status = 'error'
        self.state.error = _t('client.errors.category', 'Category %s did not open after 3 attempts.', category.label)
        LT.Debug.Warn('settings category %s failed enter=%s version=%s->%s', category.index, tostring(lastEnter), lastVersion, lastNext)
    else
        self.state.error = ''
        if not self:isGraphicsPage() then
            local entry = self.pending[categoryId]
            if entry then
                for rowId in pairs(entry.rows) do
                    self.pendingSnapshots[rowId] = nil
                end
                self.state.pendingCount = math.max(0, self.state.pendingCount - (entry.count or 0))
                self.pending[categoryId] = nil
                category.pending = 0
                for index = 1, #self.categories do
                    if self.categories[index].id == categoryId then
                        self.state.categories[index].pending = 0
                        break
                    end
                end
                for index = 1, #self.state.rows do
                    self.state.rows[index].pending = false
                end
            end
        end
    end
    self:focusUi()
    self:setBusy(false)
    return success
end

---@param force boolean?
---@return boolean
function SettingsBridgeClass:refreshActive(force)
    local column = self.optionsColumn
    if not self.active or not column then return false end
    if self.busy and not force then return false end
    local raw = self:readDump(column)
    if raw == '' or raw == self.navRaw then return false end
    local rows = parseDump(raw, self:usesKeyBindings())
    if #rows == 0 then return false end
    local previous = self.lastRawByIndex or {}
    local version = self:readInt('GET_BRIDGE_VERSION', chunkTimeout)
    if type(version) == 'number' then
        self.lastVersion = version
    end
    self:noteGraphicsDrift(rows, previous)
    self:storeRawByIndex(rows)
    self:publishRows(rows, column, self.lastVersion)
    local changes = {}
    for index = 1, #rows do
        local row = rows[index]
        local old = previous[row.index]
        if old and old.value ~= (row.value or '') then
            changes[#changes + 1] = ('%s %s->%s'):format(row.label ~= '' and row.label or row.index, old.value, row.value or '')
        end
    end
    if #changes > 0 then
        LT.Debug.Info('settings redraw ver=%s changed %s', self.lastVersion, table.concat(changes, ' | '))
    else
        LT.Debug.Info('settings redraw ver=%s unchanged', self.lastVersion)
    end
    return true
end

function SettingsBridgeClass:noteGraphicsDrift(rows, previous)
    if not self:isGraphicsPage() then return end
    for index = 1, #rows do
        local row = rows[index]
        local old = previous[row.index]
        local trackable = row.editable and (row.kind == 'options' or row.kind == 'slider' or row.kind == 'cycled')
        if old and trackable then
            local newValue = row.value or ''
            local newIndex = tonumber(row.selectedIndex) or 0
            local changed = old.value ~= newValue
            if row.kind ~= 'cycled' then
                changed = changed or old.selectedIndex ~= newIndex
            end
            if changed then
                local snap = self.pendingSnapshots[row.id]
                local backToOriginal = snap and (
                    (row.kind == 'cycled' and (snap.previousValue or '') == newValue)
                    or (row.kind ~= 'cycled'
                        and tonumber(snap.selectedIndex) == newIndex
                        and (snap.previousValue or '') == newValue)
                )
                if backToOriginal then
                    self:clearPendingRow(row.id)
                else
                    self:markPending(row, old.selectedIndex, old.value)
                end
            end
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- CHANGES
-- ════════════════════════════════════════════════════════════════════════════════════════════

function SettingsBridgeClass:markPending(row, previousIndex, previousValue)
    if not self:isGraphicsPage() then return end
    local categoryId = self.state.activeCategoryId
    self.pending[categoryId] = self.pending[categoryId] or { rows = {}, count = 0 }
    local entry = self.pending[categoryId]
    if previousIndex ~= nil or previousValue ~= nil then
        if self.pendingSnapshots[row.id] == nil then
            self.pendingSnapshots[row.id] = {
                index = row.index,
                selectedIndex = previousIndex or 0,
                previousValue = previousValue or '',
                expectedIndex = tonumber(row.selectedIndex) or 0,
                expectedValue = row.value or '',
            }
        else
            local snap = self.pendingSnapshots[row.id]
            snap.expectedIndex = tonumber(row.selectedIndex) or 0
            snap.expectedValue = row.value or ''
        end
    end
    if not entry.rows[row.id] then
        entry.rows[row.id] = true
        entry.count += 1
        self.state.pendingCount += 1
        local category = self.categoryById[categoryId]
        if category then
            category.pending = entry.count
            for index = 1, #self.categories do
                if self.categories[index].id == categoryId then
                    self.state.categories[index].pending = entry.count
                    break
                end
            end
        end
        row.pending = true
        for index = 1, #self.state.rows do
            local stateRow = self.state.rows[index]
            if stateRow and stateRow.id == row.id then
                stateRow.pending = true
                break
            end
        end
    end
end

function SettingsBridgeClass:clearPendingRow(rowId)
    if not rowId then return end
    local entry = self.pending[self.state.activeCategoryId]
    if entry and entry.rows[rowId] then
        entry.rows[rowId] = nil
        entry.count = math.max(0, entry.count - 1)
        self.state.pendingCount = math.max(0, self.state.pendingCount - 1)
        local category = self.categoryById[self.state.activeCategoryId]
        if category then
            category.pending = entry.count
            for index = 1, #self.categories do
                if self.categories[index].id == self.state.activeCategoryId then
                    self.state.categories[index].pending = entry.count
                    break
                end
            end
        end
        if entry.count <= 0 then
            self.pending[self.state.activeCategoryId] = nil
        end
    end
    self.pendingSnapshots[rowId] = nil
    for index = 1, #self.state.rows do
        local stateRow = self.state.rows[index]
        if stateRow and stateRow.id == rowId then
            stateRow.pending = false
            break
        end
    end
end

---@param change table
---@return boolean
function SettingsBridgeClass:applyChange(change)
    local column = self.optionsColumn
    local row = self.rowByIndex[change.index]
    if not row or row.editable == false or self.state.keyBindings or not column then return false end

    local previousIndex = tonumber(row.selectedIndex) or 0
    local previousLabel = row.value or ''
    local versionBefore = self:readInt('GET_BRIDGE_VERSION', chunkTimeout) or self.lastVersion
    local target = tonumber(change.targetIndex)
    local direction = tonumber(change.direction)
    direction = (direction and direction < 0) and -1 or 1
    local isCycled = row.kind == 'cycled'
    LT.Debug.Info('settings step label=%s kind=%s index=%s value=%s idx=%s target=%s dir=%s ver=%s',
        row.label, row.kind, row.index, previousLabel, previousIndex, tostring(target), direction, versionBefore)

    if not isCycled and target ~= nil and target == previousIndex then
        return true
    end

    local stepSize = tonumber(row.step) or 1
    if row.kind == 'slider' and stepSize > 1 and target == nil then
        local presses = math.max(1, tonumber(change.steps) or 1)
        local nextIndex = previousIndex
        for _ = 1, presses do
            if direction > 0 then
                nextIndex = math.floor(nextIndex / stepSize) * stepSize + stepSize
            else
                nextIndex = math.ceil(nextIndex / stepSize) * stepSize - stepSize
            end
        end
        local maxIndex = tonumber(row.maxIndex) or 0
        target = math.max(0, math.min(nextIndex, maxIndex))
    elseif row.kind == 'slider' and stepSize > 1 and target ~= nil then
        local maxIndex = tonumber(row.maxIndex) or 0
        target = math.floor((target / stepSize) + 0.5) * stepSize
        target = math.max(0, math.min(target, maxIndex))
    end

    local stepped
    local label = previousLabel
    local dir = direction
    local steps = math.max(1, tonumber(change.steps) or 1)
    local cycledRefreshed = false
    if target ~= nil and not isCycled then
        dir = target > previousIndex and 1 or -1
        steps = math.abs(target - previousIndex)
        if steps < 1 then return true end
    end
    if isCycled then
        local settingsColumn = self.optionsColumn
        if not settingsColumn or settingsColumn == self.navColumn then
            LT.Debug.Warn('settings cycle skipped left column=%s', tostring(settingsColumn))
            return false
        end
        local heldPass = self.passControls == true
        self.passControls = true
        self:call('M_PRESS_EVENT', row.index, settingsColumn, false, true)
        Wait(0)
        local control = dir < 0 and 189 or 190
        ReleaseControlOfFrontend()
        Wait(0)
        for _ = 1, steps do
            EnableControlAction(0, control, true)
            EnableControlAction(2, control, true)
            SetInputExclusive(2, control)
            SetControlNormal(0, control, 1.0)
            SetControlNormal(2, control, 1.0)
            Wait(0)
        end
        Wait(0)
        TakeControlOfFrontend()
        if not heldPass then self.passControls = false end
        if self.active and not self.passControls then self:hideGameCursor() end

        local function readCycleLabel()
            local raw = self:readDump(settingsColumn)
            local rows = parseDump(raw)
            for readIndex = 1, #rows do
                if rows[readIndex].index == row.index then
                    return rows[readIndex].value or ''
                end
            end
            return nil
        end

        local deadline = GetGameTimer() + 200
        repeat
            local readLabel = readCycleLabel()
            if readLabel ~= nil then label = readLabel end
            if label ~= '' and label ~= previousLabel then break end
            Wait(0)
        until GetGameTimer() >= deadline
        cycledRefreshed = self:refreshActive(true)
        self:writeStepValue(self.rowByIndex[row.index] or row, 0, label)
    else
        for _ = 1, steps do
            stepped = self:readInt('BRIDGE_STEP_ROW', returnTimeout, column, row.index, dir)
            if stepped == nil or stepped < 0 then break end
            if target ~= nil and stepped == target then break end
        end
        if stepped == nil or stepped < 0 then
            LT.Debug.Warn('settings bridge step failed label=%s kind=%s index=%s', row.label, row.kind, row.index)
            return false
        end
        if row.kind == 'options' or row.kind == 'slider' then
            local maxIndex = tonumber(row.maxIndex) or 0
            local nextIndex = target ~= nil and target or (previousIndex + dir)
            if row.kind == 'slider' then
                nextIndex = math.max(0, math.min(nextIndex, maxIndex))
            else
                if nextIndex < 0 then nextIndex = maxIndex end
                if nextIndex > maxIndex then nextIndex = 0 end
            end
            label = self:labelFor(row, nextIndex)
            self:writeStepValue(row, nextIndex, label)
            stepped = nextIndex
        else
            label = self:labelFor(row, stepped)
            self:writeStepValue(row, stepped, label)
        end
    end
    local written = self.rowByIndex[row.index] or row
    local versionAfter = self:readInt('GET_BRIDGE_VERSION', chunkTimeout) or versionBefore
    self.lastVersion = versionAfter
    LT.Debug.Info('settings step done label=%s kind=%s stepped=%s wrote=%s idx=%s changed=%s ver=%s->%s',
        written.label, written.kind, tostring(stepped), written.value or '', tostring(written.selectedIndex),
        tostring((written.value or '') ~= previousLabel or (tonumber(written.selectedIndex) or 0) ~= previousIndex), versionBefore, versionAfter)

    local changed
    if isCycled then
        changed = label ~= '' and label ~= previousLabel
        if changed and not cycledRefreshed then
            local snap = self.pendingSnapshots[row.id]
            local backToOriginal = snap and (snap.previousValue or '') == label
            if backToOriginal then
                self:clearPendingRow(row.id)
            else
                self:markPending(written, previousIndex, previousLabel)
            end
        end
        self:updateRawForRow(written)
    else
        changed = stepped ~= previousIndex or (label ~= '' and label ~= previousLabel)
        if changed then
            local snap = self.pendingSnapshots[row.id]
            local backToOriginal = snap and (
                tonumber(snap.selectedIndex) == stepped
                and (snap.previousValue or '') == (written.value or label or '')
            )
            if backToOriginal then
                self:clearPendingRow(row.id)
            else
                self:markPending(written, previousIndex, previousLabel)
            end
        end
        self:updateRawForRow(written)
    end

    if changed and PopupBridge then PopupBridge:capture(400) end

    if not (PopupBridge and PopupBridge:isOpen()) then
        self:focusUi()
    end
    return changed
end

function SettingsBridgeClass:runChangeQueue()
    if self.changeThread then return end
    self.changeThread = true
    CreateThread(function()
        while self.active and #self.changeOrder > 0 do
            local key = table.remove(self.changeOrder, 1)
            local change = self.changeByRow[key]
            self.changeByRow[key] = nil
            if change then
                self:setBusy(true)
                -- a failed change must not leave the page busy (and the queue dead) for the session
                local ok, err = pcall(self.applyChange, self, change)
                self:setBusy(false)
                if not ok then LT.Debug.Error('settings change failed: %s', tostring(err)) end
            end
        end
        self.changeThread = false
    end)
end

---@param data table
---@return boolean
function SettingsBridgeClass:queueChange(data)
    if not self.active or self.state.keyBindings then return false end
    local index = tonumber(data and data.index)
    local row = index and self.rowByIndex[index]
    if not row or row.editable == false then return false end
    if row.kind == 'info' or row.kind == 'button' or row.kind == 'locked' or row.kind == 'spacer' then return false end
    local key = tostring(index)
    local targetIndex = tonumber(data.targetIndex)
    local direction = tonumber(data.direction)
    if targetIndex == nil and direction == nil then return false end

    if not self.changeByRow[key] then
        self.changeOrder[#self.changeOrder + 1] = key
    end
    local existing = self.changeByRow[key]
    if targetIndex ~= nil then
        self.changeByRow[key] = { index = index, targetIndex = targetIndex }
    else
        local stepDir = direction < 0 and -1 or 1
        local steps = 1
        if existing and existing.targetIndex == nil and existing.direction == stepDir then
            steps = (existing.steps or 1) + 1
        end
        self.changeByRow[key] = { index = index, direction = stepDir, steps = steps }
    end
    self:runChangeQueue()
    return true
end

function SettingsBridgeClass:clearPending()
    self.pending = {}
    self.pendingSnapshots = {}
    self.state.pendingCount = 0
    for index = 1, #self.categories do
        self.categories[index].pending = 0
        self.state.categories[index].pending = 0
    end
    for index = 1, #self.state.rows do
        local row = self.state.rows[index]
        if row and row.pending then row.pending = false end
    end
end

function SettingsBridgeClass:pulseSpaceApply()
    if PopupBridge then PopupBridge:setSuppressPaused(true) end
    self:pulseControl(203, 3)
    LT.Debug.Info('settings pulse space apply')
    self:refreshActive(true)
    self:clearPending()
    if PopupBridge then PopupBridge:setSuppressPaused(false) end
end

---@param control number
---@param presses? integer
---@param keepReleased? boolean
function SettingsBridgeClass:pulseControl(control, presses, keepReleased)
    presses = presses or 1
    local held = self.passControls == true
    self.passControls = true
    ReleaseControlOfFrontend()
    Wait(0)
    for _ = 1, presses do
        EnableControlAction(0, control, true)
        EnableControlAction(2, control, true)
        SetInputExclusive(2, control)
        SetControlNormal(0, control, 1.0)
        SetControlNormal(2, control, 1.0)
        Wait(0)
    end
    Wait(0)
    if not held then
        self.passControls = false
    end
    if not keepReleased then
        TakeControlOfFrontend()
        if self.active and not self.passControls then self:hideGameCursor() end
    end
end

---@return boolean
function SettingsBridgeClass:applyGraphics()
    if not self.active or self.busy or self.state.pendingCount <= 0 then return false end
    if PopupBridge and PopupBridge:isOpen() then return false end
    self.awaitingApplyConfirm = true
    local count = self.state.pendingCount
    local raw = ('%s##%s##%s####k:Enter|%s;k:Backspace|%s'):format(
        _t('client.popup.apply.title', 'Apply changes'),
        _t('client.popup.apply.body', 'Apply %d pending graphics changes?', count),
        _t('client.popup.apply.prompt', 'Confirm to apply, or cancel to keep editing.'),
        _t('client.popup.apply.confirm', 'Confirm'),
        _t('client.popup.apply.cancel', 'Cancel'))
    if not PopupBridge or not PopupBridge:open(raw) then
        self.awaitingApplyConfirm = false
        return false
    end
    return true
end

---@param data table
---@return boolean
function SettingsBridgeClass:activateSetting(data)
    local column = self.optionsColumn
    if not self.active or self.busy or self.state.keyBindings or not column or column == self.navColumn then return false end
    local index = tonumber(data and data.index)
    local row = index and self.rowByIndex[index]
    if not row or row.kind ~= 'button' or row.editable == false then return false end

    self:busyThread(function()
        if not self:call('M_PRESS_EVENT', row.index, column, false, true) then
            LT.Debug.Warn('settings activate failed press index=%s', tostring(row.index))
            return
        end
        local versionBefore = self:readInt('GET_BRIDGE_VERSION', chunkTimeout) or self.lastVersion
        Wait(60)
        self:withVisibleFrontend(function()
            self:pulseControl(201, 30)
        end)
        local deadline = GetGameTimer() + 1000
        local version = versionBefore
        while GetGameTimer() < deadline do
            local readVersion = self:readInt('GET_BRIDGE_VERSION', 0)
            if readVersion ~= nil and readVersion ~= versionBefore then
                version = readVersion
                break
            end
            Wait(0)
        end
        if version == versionBefore then
            LT.Debug.Warn('settings activate failed version=%s', tostring(versionBefore))
        else
            self.lastVersion = version
            if PopupBridge then PopupBridge:capture(400) end
            self:refreshActive(true)
            LT.Debug.Info('settings activate version %s -> %s', tostring(versionBefore), tostring(version))
        end
    end)
    return true
end

function SettingsBridgeClass:activateKeyButton(data)
    if not self.active then
        LT.Debug.Warn('settings key button rejected inactive')
        return false
    end
    if self:isBusy() then
        LT.Debug.Warn('settings key button rejected busy')
        return false
    end
    if not self.state.keyBindings then
        LT.Debug.Warn('settings key button rejected not keyBindings')
        return false
    end
    local column = self.groupColumn
    local groups = self.state.keyGroups or {}
    local group
    for index = 1, #groups do
        if groups[index].id == (data and data.id) then
            group = groups[index]
            break
        end
    end
    if not group then
        LT.Debug.Warn('settings key button rejected missing group id=%s', tostring(data and data.id))
        return false
    end
    if not self:isKeyGroupButton(group) then
        LT.Debug.Warn('settings key button rejected not button id=%s label=%s', tostring(group.id), tostring(group.label))
        return false
    end
    if type(column) ~= 'number' then
        LT.Debug.Warn('settings key button rejected column=%s nav=%s', tostring(column), tostring(self.navColumn))
        return false
    end
    if column == self.navColumn and self:readDump(column) == self.navRaw then
        LT.Debug.Warn('settings key button rejected column=%s nav=%s', tostring(column), tostring(self.navColumn))
        return false
    end

    self:busyThread(function()
        LT.Debug.Info('settings key button activate id=%s index=%s', tostring(group.id), tostring(group.index))
        self:leaveTopMenu()
        self:readInt('BRIDGE_PRESS', returnTimeout, group.index, column)
        local versionBefore = self:readInt('GET_BRIDGE_VERSION', chunkTimeout) or self.lastVersion
        Wait(60)
        self:withVisibleFrontend(function()
            self:pulseControl(201, 30)
        end)
        local deadline = GetGameTimer() + 1000
        local version = versionBefore
        while GetGameTimer() < deadline do
            local readVersion = self:readInt('GET_BRIDGE_VERSION', 0)
            if readVersion ~= nil and readVersion ~= versionBefore then
                version = readVersion
                break
            end
            Wait(0)
        end
        local opened = false
        if version ~= versionBefore then
            self.lastVersion = version
            opened = PopupBridge and PopupBridge:capture(400) or false
            LT.Debug.Info('settings key button version %s -> %s', tostring(versionBefore), tostring(version))
        else
            opened = PopupBridge and PopupBridge:capture(400) or false
            if not opened then
                LT.Debug.Warn('settings key button failed version=%s', tostring(versionBefore))
            end
        end
        if self.active and (opened or version ~= versionBefore) then
            self:refreshActive(true)
        end
    end)
    return true
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- UNSAVED
-- ════════════════════════════════════════════════════════════════════════════════════════════

---@return boolean
function SettingsBridgeClass:hasUnsavedGraphics()
    return self:isGraphicsPage() and (self.state.pendingCount or 0) > 0
end

---@param categoryId string|nil
---@return boolean
function SettingsBridgeClass:promptUnsaved(categoryId)
    if self.unsavedPrompt or not PopupBridge or PopupBridge:isOpen() then return false end
    if not self:hasUnsavedGraphics() then return false end
    self.unsavedPrompt = true
    self.discardCategoryId = categoryId
    local raw = ('%s##%s##%s####k:Enter|%s;k:Backspace|%s;k:Space|%s'):format(
        _t('client.popup.unsaved.title', 'Unsaved changes'),
        _t('client.popup.unsaved.body', 'Graphics changes are not applied.'),
        _t('client.popup.unsaved.prompt', 'Apply them, stay on this page, or discard them.'),
        _t('client.popup.unsaved.apply', 'Apply'),
        _t('client.popup.unsaved.stay', 'Stay'),
        _t('client.popup.unsaved.discard', 'Discard'))
    if not PopupBridge:open(raw) then
        self.unsavedPrompt = false
        self.discardCategoryId = nil
        return false
    end
    return true
end

function SettingsBridgeClass:commitGraphics()
    self:busyThread(function()
        self.applyHoldUntil = GetGameTimer() + 500
        self:pulseSpaceApply()
        local opened = PopupBridge and PopupBridge:capture(500) or false
        self.applyHoldUntil = 0
        -- the confirm popup is up: its answer clears busy
        if opened then return true end
        if self.active then
            self:hideFrontend()
            self:focusUi()
        end
    end)
end

---@param categoryId string
function SettingsBridgeClass:restartCategory(categoryId)
    CreateThread(function()
        self.restoreCategoryId = categoryId
        self.state.veil = true
        self.state:sync()
        Wait(veilFadeMs)
        self:stop()
        Wait(250)
        if Pause then Pause:openSettings() end
    end)
end

function SettingsBridgeClass:discardUnsaved()
    local categoryId = self.discardCategoryId
    self.discardCategoryId = nil
    if categoryId and categoryId ~= '' then
        self:restartCategory(categoryId)
        return
    end
    CreateThread(function()
        self:stop()
        if Pause then Pause:close() end
    end)
end

---@param control integer
function SettingsBridgeClass:onCustomAlert(control)
    control = tonumber(control) or 201
    if self.unsavedPrompt then
        self.unsavedPrompt = false
        if control == 201 then
            self.discardCategoryId = nil
            self:commitGraphics()
        elseif control == 203 then
            self:discardUnsaved()
        else
            self.discardCategoryId = nil
            if self.active then
                self:reclaimInput()
            end
        end
        return
    end
    if self.awaitingApplyConfirm then
        self.awaitingApplyConfirm = false
        if control ~= 202 then
            self:commitGraphics()
        elseif self.active then
            self:reclaimInput()
        end
    end
end

function SettingsBridgeClass:reclaimInput()
    if not self.active then return end
    self:hideFrontend()
    TakeControlOfFrontend()
    self:hideGameCursor()
    self:focusUi()
    if self.listening then self:finishListen() end
end

---@param confirmed boolean
---@param mode string|nil
function SettingsBridgeClass:onPopupResolved(confirmed, mode)
    if self.listening or self.state.keyBindings then
        self:reclaimInput()
    elseif self.active then
        self:hideFrontend()
        self:focusUi()
    end
    if not self.changeThread and not self.listening then
        self:setBusy(false)
    end
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- BINDINGS
-- ════════════════════════════════════════════════════════════════════════════════════════════

---@param data table
---@return boolean
function SettingsBridgeClass:listenForKey(data)
    if not self.active or not self.state.keyBindings or self:isBusy() then return false end
    local row = self.rowByIndex[tonumber(data and data.index)]
    local slot = 'primary'
    local column = self.optionsColumn
    if not row or row.type ~= 'keybind' or row.editable == false or not column then return false end

    self:setBusy(true)
    self.listening = true
    self.state.listenIndex = row.index
    self.state.listenSlot = slot
    self.state.listenPhase = 'wait'
    self.state:sync()
    Wait(0)
    CreateThread(function()
        -- always finish the listen below, or the row stays waiting for a key until the page closes
        local ok, err = pcall(self.withKeyScreen, self, function()
            if not self.active or not self.listening then return end
            if column ~= self.navColumn then
                self:call('M_PRESS_EVENT', row.index, column, false, true)
            end
            Wait(250)
            if not self.active or not self.listening then return end
            self:pulseControl(201, 1, true)
            self.state.listenPhase = 'press'
            self.state:sync()
            Wait(0)

            local function slotValue()
                local actionColumn = self.optionsColumn
                if not actionColumn then return '' end
                local raw = self:readDump(actionColumn)
                if raw == '' or raw == self.navRaw then return nil end
                local bindings = self:makeKeyBindingRows(parseDump(raw, true))
                for index = 1, #bindings do
                    if bindings[index].index == row.index then
                        return bindings[index][slot] or ''
                    end
                end
                return ''
            end

            local previous = slotValue() or ''
            local seenVersion = self:readInt('GET_BRIDGE_VERSION', chunkTimeout) or self.lastVersion
            local deadline = GetGameTimer() + 5000
            local pausedAt = 0
            local accepted = false
            local function dropKeyPrompt()
                if not self.state.keyPrompt then return end
                self.state.keyPrompt = false
                self.state:sync()
            end
            local function cancelPressed()
                return IsControlJustPressed(0, 200) or IsControlJustPressed(0, 202)
                    or IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 202)
                    or IsControlJustPressed(2, 200) or IsControlJustPressed(2, 202)
                    or IsDisabledControlJustPressed(2, 200) or IsDisabledControlJustPressed(2, 202)
            end
            local function popupWaiting()
                if not PopupBridge then return false end
                if PopupBridge:isOpen() then return true end
                local raw = PopupBridge:dumpBridgePopup()
                if raw == '' then return false end
                PopupBridge:capture(0)
                return true
            end
            while self.active and self.listening do
                if cancelPressed() then break end
                if popupWaiting() then
                    if pausedAt == 0 then
                        pausedAt = GetGameTimer()
                        dropKeyPrompt()
                    end
                    Wait(50)
                else
                    if pausedAt > 0 then
                        break
                    end
                    if GetGameTimer() >= deadline then break end
                    local current = self:readInt('GET_BRIDGE_VERSION', chunkTimeout) or seenVersion
                    if current ~= seenVersion then
                        seenVersion = current
                        dropKeyPrompt()
                        local nextValue = slotValue()
                        if nextValue ~= nil and nextValue ~= previous then
                            accepted = true
                            local actionColumn = self.optionsColumn
                            local raw = actionColumn and self:readDump(actionColumn) or ''
                            self.lastVersion = current
                            if raw ~= '' and raw ~= self.navRaw and actionColumn then
                                self:publishRows(parseDump(raw, true), actionColumn, self.lastVersion)
                            end
                            break
                        end
                        if nextValue ~= nil then previous = nextValue end
                    end
                    Wait(0)
                end
            end
            while self.active and self.listening and PopupBridge and (PopupBridge:isOpen() or PopupBridge:dumpBridgePopup() ~= '') do
                if not PopupBridge:isOpen() then PopupBridge:capture(0) end
                Wait(50)
            end
        end)
        if not ok then LT.Debug.Error('key binding failed: %s', tostring(err)) end
        if self.active then
            self:finishListen()
        end
    end)
    return true
end

function SettingsBridgeClass:finishListen()
    self.listening = false
    if not self.active then return end
    self.state.listenIndex = -1
    self.state.listenSlot = ''
    self.state.listenPhase = ''
    self:setBusy(false)
end

function SettingsBridgeClass:cancelListen()
    self.listening = false
    return true
end

function SettingsBridgeClass:startPollLoop()
    if self.pollThread then return end
    self.pollThread = true
    CreateThread(function()
        local changedAt = 0
        while self.active and self.pollThread do
            if not self.busy and not (PopupBridge and PopupBridge:isOpen()) then
                local version = self:readInt('GET_BRIDGE_VERSION', chunkTimeout) or self.lastVersion
                if version ~= self.lastVersion then
                    LT.Debug.Info('settings version %s -> %s', self.lastVersion, version)
                    self.lastVersion = version
                    changedAt = GetGameTimer()
                elseif changedAt > 0 and GetGameTimer() - changedAt >= 40 then
                    changedAt = 0
                    self:refreshActive()
                end
            end
            Wait(50)
        end
        self.pollThread = false
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- LIFECYCLE
-- ════════════════════════════════════════════════════════════════════════════════════════════

---@param message string
---@return boolean
function SettingsBridgeClass:fail(message)
    self.state.status = 'error'
    self.state.error = message
    self.active = false
    self.hideThread = false
    self.pollThread = false
    self:closeFrontend()
    self:clearUiFocus()
    LT.NUI.Focus(true, true)
    self.state.veil = false
    return false
end

---@return boolean
function SettingsBridgeClass:start()
    if self.active then return true end
    if NativeMap and (NativeMap:isOpen() or NativeMap:isDumping()) then return false end
    self.categories = {}
    self.categoryById = {}
    self.rowByIndex = {}
    self.cache = {}
    self.pending = {}
    self.pendingSnapshots = {}
    self.lastRawByIndex = {}
    self.changeOrder = {}
    self.changeByRow = {}
    self.optionsColumn = nil
    self.groupColumn = nil
    self.navRaw = ''
    self.allowKeyMapping = false
    self.dumpBusy = false
    self.active = true
    self.awaitingApplyConfirm = false
    self.unsavedPrompt = false
    self.applyHoldUntil = 0
    local restoreId = self.restoreCategoryId
    self.restoreCategoryId = nil
    self.state:set({
        status = 'loading',
        build = '',
        error = '',
        categories = {},
        activeCategoryId = '',
        rows = {},
        version = 0,
        busy = false,
        keyBindings = false,
        keyGroups = {},
        activeKeyGroupId = '',
        listenIndex = -1,
        listenSlot = '',
        listenPhase = '',
        keyPrompt = false,
        vram = '',
        vramPercent = -1,
        pendingCount = 0,
        veil = restoreId ~= nil,
    })

    ActivateFrontendMenu(settingsMenu, false, 6)
    self:startHideLoop()
    if not self:waitFrontend(2000) then
        return self:fail(_t('client.errors.frontend', 'The GTA settings frontend did not become ready.'))
    end

    self.calmUntil = GetGameTimer() + 200
    TakeControlOfFrontend()
    self:hideFrontend()
    self:scheduleHideGameCursor()
    local build = self:readString('GET_BRIDGE_BUILD', returnTimeout)
    self.state.build = build
    if build ~= tostring(BridgeVersion) then
        LT.Debug.Error('settings gfx build=%s expected=%s', build, BridgeVersion)
        return self:fail(_t('client.errors.gfx', 'Patched GFX not loaded. Please restart the FiveM client.'))
    end

    local batchSize = GetConvarInt('nightreign_pausemenu_dump_batch', 16)
    self.dumpBatchSize = math.max(1, math.min(16, batchSize))
    self.lastVersion = self:readInt('GET_BRIDGE_VERSION', returnTimeout) or 0
    local navigation = self:waitForNavigation(2500)
    if navigation == 'empty' then
        return self:fail(_t('client.errors.empty', 'The game returned no settings categories.'))
    end
    if navigation ~= 'ready' then
        self.state.status = 'error'
        self.state.error = _t('client.errors.parse', 'Settings categories were read but could not be parsed.')
        self.state.veil = false
        self:focusUi()
        return false
    end

    self.state.version = self.lastVersion
    self:focusUi()
    self:startPollLoop()
    local target = restoreId and self.categoryById[restoreId] or self.categories[1]
    if target then self:selectCategory(target.id) end
    if restoreId then self.state.veil = false end
    return true
end

function SettingsBridgeClass:closeFrontend()
    self:showGameCursor()
    if not IsPauseMenuActive() and not IsFrontendReadyForControl() then return end
    TakeControlOfFrontend()
    self:showFrontend()
    SetPauseMenuActive(false)
    ReleaseControlOfFrontend()
    SetFrontendActive(false)
end

function SettingsBridgeClass:stop()
    if not self.active then
        self:closeFrontend()
        return
    end
    self.active = false
    self.listening = false
    self.hideThread = false
    self.frontendHold = false
    self.pollThread = false
    self.changeOrder = {}
    self.changeByRow = {}
    self.pending = {}
    self.pendingSnapshots = {}
    self.lastRawByIndex = {}
    self.cache = {}
    self.categories = {}
    self.categoryById = {}
    self.rowByIndex = {}
    self.optionsColumn = nil
    self.groupColumn = nil
    self.navRaw = ''
    self.dumpBusy = false
    self.awaitingApplyConfirm = false
    self.unsavedPrompt = false
    self.applyHoldUntil = 0
    self.discardCategoryId = nil
    self:setBusy(false)
    if PopupBridge and PopupBridge:isOpen() then PopupBridge:clear() end
    self:closeFrontend()
    self:clearUiFocus()
    self.state:set({
        status = 'idle',
        build = '',
        error = '',
        categories = {},
        activeCategoryId = '',
        rows = {},
        version = 0,
        busy = false,
        keyBindings = false,
        keyGroups = {},
        activeKeyGroupId = '',
        listenIndex = -1,
        listenSlot = '',
        listenPhase = '',
        keyPrompt = false,
        vram = '',
        vramPercent = -1,
        pendingCount = 0,
        veil = self.restoreCategoryId ~= nil,
    })
end

---@return boolean
function SettingsBridgeClass:isBusy()
    if self.busy or self.changeThread or #self.changeOrder > 0 then return true end
    if GetGameTimer() < (self.applyHoldUntil or 0) then return true end
    return PopupBridge and PopupBridge:isOpen() or false
end

---@return boolean
function SettingsBridgeClass:reopen()
    self:stop()
    Wait(250)
    if Pause then Pause:openSettings() end
    return true
end

function SettingsBridgeClass:useEnglish()
    local category
    for index = 1, #self.categories do
        if self.categories[index].index == 5 then
            category = self.categories[index]
            break
        end
    end
    if not category or not self:selectCategory(category.id) then return false end
    local languageRow
    for index = 1, #self.state.rows do
        local row = self.state.rows[index]
        if row.id == '35:10' then
            languageRow = row
            break
        end
    end
    if not languageRow or not self:queueChange({ index = languageRow.index, targetIndex = 0 }) then return false end
    local deadline = GetGameTimer() + 3000
    while self.active and (self.changeThread or #self.changeOrder > 0) and GetGameTimer() < deadline do
        Wait(0)
    end
    return self:reopen()
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- NUI
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- Always answers the page (it waits for the reply), and a failed action does not leave the
--- settings page busy: the menu only closes once it is idle.
--- @param name string
--- @param fn fun(data: table): boolean
local function settingsCallback(name, fn)
    LT.NUI.Callback(name, function(data, cb)
        local ok, result = pcall(fn, type(data) == 'table' and data or {})
        if not ok then
            LT.Debug.Error('%s failed: %s', name, tostring(result))
            SettingsBridge:setBusy(false)
            result = false
        end
        cb({ ok = result })
    end)
end

LT.NUI.Callback('SettingsLanguage', function(_, cb)
    cb({ language = GetCurrentLanguage() or 0 })
end)

settingsCallback('SettingsUseEnglish', function(_) return SettingsBridge:useEnglish() end)

settingsCallback('SettingsReopen', function(_) return SettingsBridge:reopen() end)

settingsCallback('SettingsSetCategory', function(data) return SettingsBridge:selectCategory(data.id or '') end)

settingsCallback('SettingsUnsaved', function(_) return SettingsBridge:promptUnsaved() end)

settingsCallback('SettingsChange', function(data) return SettingsBridge:queueChange(data) end)

settingsCallback('SettingsApply', function(_) return SettingsBridge:applyGraphics() end)

settingsCallback('SettingsActivate', function(data) return SettingsBridge:activateSetting(data) end)

settingsCallback('SettingsActivateKey', function(data) return SettingsBridge:activateKeyButton(data) end)

settingsCallback('SettingsListen', function(data) return SettingsBridge:listenForKey(data) end)

settingsCallback('SettingsListenCancel', function(_) return SettingsBridge:cancelListen() end)

function SettingsBridgeClass:selectKeyGroup(groupId)
    if not self.active or not self.state.keyBindings or self:isBusy() then return false end
    local group
    local groups = self.state.keyGroups or {}
    for index = 1, #groups do
        if groups[index].id == groupId then
            group = groups[index]
            break
        end
    end
    if not group then return false end
    if self:isKeyGroupButton(group) then
        return self:activateKeyButton({ id = group.id })
    end
    if not self.groupColumn then
        self.state.activeKeyGroupId = groupId
        return true
    end

    self:setBusy(true)
    self.state.status = 'loading'
    self.state.rows = {}
    self.state:sync()
    Wait(0)
    self.state.activeKeyGroupId = groupId

    local success = false
    for _ = 1, 3 do
        self:leaveTopMenu()
        local lastVersion = self:readInt('GET_BRIDGE_VERSION', chunkTimeout) or self.lastVersion
        self:readInt('BRIDGE_PRESS', returnTimeout, group.index, self.groupColumn)
        local raw, column, nextVersion = self:waitForOptions(lastVersion, 450)
        if raw and column and column ~= self.groupColumn then
            self.lastVersion = nextVersion or lastVersion
            self:publishRows(parseDump(raw, true), column, self.lastVersion)
            if column ~= self.navColumn then
                self:call('M_PRESS_EVENT', 0, column, false, true)
            end
            success = true
            break
        end
        Wait(0)
    end
    if not success then
        self.state.status = 'ready'
    end
    self:focusUi()
    self:setBusy(false)
    return true
end

settingsCallback('SettingsSetKeyGroup', function(data) return SettingsBridge:selectKeyGroup(data.id or '') end)

LT.Hooks.Stop(function()
    SettingsBridge:stop()
end)

--[[ Initialize ]]
_G.SettingsBridge = SettingsBridgeClass:new()
