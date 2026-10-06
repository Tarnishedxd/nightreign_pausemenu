---@class PopupBridgeClass
---@field pollThread boolean
---@field lastRaw string
---@field lastWatchVer integer
---@field suppressPaused boolean
---@field dismissing boolean
---@field state table
local PopupBridgeClass = {}
PopupBridgeClass.__index = PopupBridgeClass

local chunkTimeout <const> = 200
local dumpChunkSize <const> = 40

local function trim(value)
    return (value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function cleanAlertText(value)
    if not value or value == '' then return '' end
    value = value:gsub('<[Ff][Oo][Nn][Tt][^>]*>', '')
    value = value:gsub('</[Ff][Oo][Nn][Tt]>', '')
    value = value:gsub('<[Bb][Rr]%s*/?>', '\n')
    value = value:gsub('~n~', '\n')
    value = value:gsub('~%a~', '')
    value = value:gsub('#', '\n')
    value = value:gsub('[ \t]+\n', '\n'):gsub('\n[ \t]+', '\n')
    value = value:gsub('[ \t]+', ' ')
    return trim(value)
end

local function splitPopup(raw)
    local fields = {}
    for value in ((raw or '') .. '##'):gmatch('(.-)##') do
        fields[#fields + 1] = trim(value:gsub('undefined', ''))
    end
    return fields
end

local function isBlankRaw(raw)
    return raw == '' or raw == '######' or (raw and raw:match('^%s*$') ~= nil)
end

local keyControls <const> = {
    enter = 201,
    ['return'] = 201,
    ret = 201,
    ent = 201,
    numpadenter = 201,
    backspace = 202,
    back = 202,
    bksp = 202,
    escape = 202,
    esc = 202,
    space = 203,
    spacebar = 203,
}

local iconControls <const> = {
    [30] = 201,
    [31] = 202,
    [32] = 203,
    [199] = 202,
    [1003] = 201,
    [2000] = 202,
}

local function controlForKey(name)
    local key = (name or ''):lower():gsub('%s+', '')
    return keyControls[key]
end

local function parseButtons(field)
    if not field or field == '' then return {} end
    local buttons = {}
    for token in (field .. ';'):gmatch('(.-);') do
        token = trim(token)
        if token ~= '' then
            local spec, label = token:match('^(.-)|(.*)$')
            if not spec then
                spec = token
                label = ''
            end
            spec = trim(spec)
            label = trim(label)
            local control
            local keyName
            local icon = spec:match('^b:(%d+)$')
            local key = spec:match('^k:(.*)$')
            if icon then
                local id = tonumber(icon)
                control = iconControls[id]
                if not control and (id == 201 or id == 202 or id == 203) then
                    control = id
                end
            elseif key and key ~= '' then
                keyName = key
                control = controlForKey(key)
            else
                keyName = spec
                control = controlForKey(spec)
            end
            if control then
                label = cleanAlertText(label)
                buttons[#buttons + 1] = {
                    label = label ~= '' and label or keyName,
                    control = control,
                }
            end
        end
    end
    return buttons
end

local function logPopup(raw, buttons)
    LT.Debug.Verbose('^3Popup^7')
    LT.Debug.Verbose(raw or '')
    for index = 1, #buttons do
        local button = buttons[index]
        LT.Debug.Verbose(('^3button^7 control=%s label=%s'):format(button.control, button.label or ''))
    end
end

local function isButtonSpec(field)
    if not field or field == '' then return false end
    return field:find('k:', 1, true) ~= nil or field:find('b:', 1, true) ~= nil
end

local function buttonsFromFields(fields)
    if fields[5] and fields[5] ~= '' then
        return parseButtons(fields[5])
    end
    if isButtonSpec(fields[4]) then
        return parseButtons(fields[4])
    end
    return {}
end

local function closedAlert()
    return {
        open = false,
        title = '',
        body = '',
        prompt = '',
        detail = '',
        buttons = {},
    }
end

---@return PopupBridgeClass
function PopupBridgeClass:new()
    local self = setmetatable({}, PopupBridgeClass)
    self.pollThread = false
    self.lastRaw = ''
    self.lastWatchVer = -1
    self.suppressPaused = false
    self.dismissing = false
    self.state = LT.NUI.CreateState('UpdateGtaAlert', closedAlert())
    return self
end

---@return boolean
function PopupBridgeClass:isOpen()
    return self.state.open == true
end

function PopupBridgeClass:hideNativeUi()
    if not (SettingsBridge and SettingsBridge.active) then return end
    SettingsBridge:call('SHOW_WARNING_MESSAGE', false)
    SettingsBridge:call('BRIDGE_POPUP', 'HIDE_POPUP_WARNING', 0)
end

---@param paused boolean
function PopupBridgeClass:setSuppressPaused(paused)
    self.suppressPaused = paused == true
end

---@return string
function PopupBridgeClass:dumpBridgePopup()
    if not SettingsBridge then return '' end
    if not SettingsBridge:acquireDump(0) then return '' end
    local partCount = SettingsBridge:readInt('BRIDGE_POPUP_DUMP', chunkTimeout, dumpChunkSize) or 0
    local length = SettingsBridge:readInt('GET_BRIDGE_DUMP_LEN', chunkTimeout) or 0
    if partCount <= 0 and length <= 0 then
        SettingsBridge:releaseDump()
        return ''
    end
    if partCount <= 0 then partCount = math.ceil(length / dumpChunkSize) end
    local parts = {}
    for part = 0, partCount - 1 do
        local value = SettingsBridge:readString('GET_BRIDGE_DUMP', chunkTimeout, part)
        parts[#parts + 1] = value
        if #value < dumpChunkSize and part < partCount - 1 then break end
    end
    SettingsBridge:releaseDump()
    local raw = table.concat(parts)
    if isBlankRaw(raw) then return '' end
    return raw
end

---@param raw string
---@return boolean
function PopupBridgeClass:open(raw)
    if self.dismissing then return false end
    local fields = splitPopup(raw)
    local title = cleanAlertText(fields[1])
    local body = cleanAlertText(fields[2])
    local prompt = cleanAlertText(fields[3])
    local detail = fields[4] or ''
    if not isButtonSpec(detail) then detail = cleanAlertText(detail) end
    if isButtonSpec(detail) and (not fields[5] or fields[5] == '') then
        detail = ''
    end
    if title == '' and body == '' and prompt == '' and detail == '' then
        return false
    end
    local buttons = buttonsFromFields(fields)
    logPopup(raw, buttons)
    self.lastRaw = raw or ''
    self.state:set({
        open = true,
        title = title ~= '' and title or _t('client.popup.alert', 'Alert'),
        body = body,
        prompt = prompt,
        detail = detail,
        buttons = buttons,
    })
    if SettingsBridge and SettingsBridge.active then
        LT.NUI.Focus(true, true)
    end
    self:hideNativeUi()
    return true
end

---@return boolean
function PopupBridgeClass:tryOpenFromVersion()
    if self.dismissing then return false end
    if self:isOpen() and SettingsBridge and SettingsBridge.awaitingApplyConfirm then
        return true
    end
    if not SettingsBridge then return false end
    local ver = SettingsBridge:readInt('GET_BRIDGE_VERSION', chunkTimeout)
    if ver == nil then return false end
    if ver == self.lastWatchVer then return self:isOpen() end
    self.lastWatchVer = ver
    local raw = self:dumpBridgePopup()
    if raw == '' then return false end
    if raw == self.lastRaw and self:isOpen() then return true end
    return self:open(raw)
end

---@param timeout number?
---@return boolean
function PopupBridgeClass:capture(timeout)
    if self.dismissing then return false end
    if self:isOpen() or not SettingsBridge then return self:isOpen() end
    local deadline = GetGameTimer() + (timeout or 0)
    repeat
        local ver = SettingsBridge:readInt('GET_BRIDGE_VERSION', chunkTimeout)
        if ver ~= nil and ver ~= self.lastWatchVer then
            self.lastWatchVer = ver
            local raw = self:dumpBridgePopup()
            if raw ~= '' then return self:open(raw) end
        else
            local raw = self:dumpBridgePopup()
            if raw ~= '' and raw ~= self.lastRaw then
                return self:open(raw)
            end
        end
        if not timeout or timeout <= 0 then break end
        Wait(0)
    until GetGameTimer() >= deadline
    return false
end

function PopupBridgeClass:clear()
    if SettingsBridge then
        SettingsBridge:call('BRIDGE_SET_POPUP', '')
    end
    self:hideNativeUi()
    self.lastRaw = ''
    self.state:set(closedAlert())
end

---@param control integer
---@param frames integer?
function PopupBridgeClass:pulseFrontend(control, frames)
    frames = frames or 3
    ReleaseControlOfFrontend()
    Wait(0)
    for _ = 1, frames do
        EnableControlAction(0, control, true)
        EnableControlAction(2, control, true)
        SetInputExclusive(2, control)
        SetControlNormal(0, control, 1.0)
        SetControlNormal(2, control, 1.0)
        Wait(0)
    end
    Wait(0)
    TakeControlOfFrontend()
end

function PopupBridgeClass:closeAlert()
    self.lastRaw = ''
    self.state:set(closedAlert())
end

function PopupBridgeClass:waitPopupClear()
    local emptyFrames = 0
    local deadline = GetGameTimer() + 400
    while emptyFrames < 3 and GetGameTimer() < deadline do
        local raw = self:dumpBridgePopup()
        if raw == '' then
            emptyFrames = emptyFrames + 1
        else
            emptyFrames = 0
            self:hideNativeUi()
        end
        Wait(0)
    end
end

---@param control integer
---@return boolean
function PopupBridgeClass:resolve(control)
    if not self:isOpen() or not SettingsBridge then return false end
    control = tonumber(control) or 201
    if control ~= 201 and control ~= 202 and control ~= 203 then
        control = 201
    end
    local hasSpace = false
    local buttons = self.state.buttons or {}
    for index = 1, #buttons do
        if buttons[index].control == 203 then
            hasSpace = true
            break
        end
    end
    local confirmed = control ~= 202
    local customPrompt = SettingsBridge.unsavedPrompt == true or SettingsBridge.awaitingApplyConfirm == true
    if customPrompt then
        self:clear()
        if SettingsBridge.active then
            SettingsBridge:onCustomAlert(control)
        else
            LT.NUI.Focus(true, true)
        end
        return true
    end

    local mode = nil
    if hasSpace and control == 203 then
        mode = 'restore'
    elseif hasSpace and control == 202 then
        mode = 'dismiss'
    end

    self.dismissing = true
    -- `dismissing` blocks every later popup: it must come back down even if a step fails
    local ok, err = pcall(function()
        self:closeAlert()
        self:pulseFrontend(control, 30)
        self:clear()
        if SettingsBridge.active then
            SettingsBridge:onPopupResolved(confirmed, mode)
        end
        self:waitPopupClear()
    end)
    self.dismissing = false
    if not ok then LT.Debug.Error('popup answer failed: %s', tostring(err)) end
    return true
end

function PopupBridgeClass:start()
    if self.pollThread then return end
    self.pollThread = true
    CreateThread(function()
        while self.pollThread do
            if SettingsBridge and SettingsBridge.active then
                if not self.suppressPaused and not self.dismissing then
                    -- one bad read must not end popup watching for the rest of the session
                    local ok, err = pcall(function()
                        self:tryOpenFromVersion()
                        self:hideNativeUi()
                    end)
                    if not ok then
                        LT.Debug.Error('popup watch failed: %s', tostring(err))
                        Wait(500)
                    end
                end
                Wait(0)
            else
                self.lastWatchVer = -1
                Wait(250)
            end
        end
    end)
end

function PopupBridgeClass:stop()
    self.pollThread = false
    self.dismissing = false
    self:clear()
end

_G.PopupBridge = PopupBridgeClass:new()
PopupBridge:start()

LT.NUI.Callback('GtaAlertPress', function(data, cb)
    -- the popup buttons stay locked until this answers
    local ok, resolved = pcall(PopupBridge.resolve, PopupBridge, type(data) == 'table' and data.control or nil)
    if not ok then LT.Debug.Error('popup answer failed: %s', tostring(resolved)) end
    cb({ ok = ok and resolved == true })
end)

LT.Hooks.Stop(function()
    PopupBridge:stop()
end)
