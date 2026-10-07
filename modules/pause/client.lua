local cfg <const> = require 'config.main'
local portrait <const> = cfg.pause.portrait
local pauseAnim <const> = cfg.pause.pauseAnim or {}
local idleMale <const> = 'anim@heists@heist_corona@team_idles@male_a'
local idleFemale <const> = 'anim@heists@heist_corona@team_idles@female_a'
local portraitModeKvp <const> = 'portraitMode'
local waisHud <const> = 'wais-hudv6'
-- A camera move longer than this is a teleport / respawn: cut instead of easing across the map.
local SNAP_DISTANCE <const> = 8.0
-- The UI's black cover fades in this long (veil-fade).
local COVER_FADE_MS <const> = 400

--- @return boolean
local function isPortraitEnabled()
    local value = GetResourceKvpString(portraitModeKvp)
    if not value or value == '' then
        return true
    end
    return value ~= '0'
end

--- @param enabled boolean
local function setPortraitEnabled(enabled)
    SetResourceKvp(portraitModeKvp, enabled and '1' or '0')
end

---@class PauseClass
---@field new fun(self): self
---@field open boolean
---@field page string
---@field quitConfirm boolean
---@field cam number|nil
---@field retiredCam number|nil
---@field blending boolean
---@field anchorPos vector3|nil
---@field anchorLook vector3|nil
---@field portraitGen integer
---@field portraitSide integer
---@field idleDict string|nil
---@field headerBusy boolean
---@field headerAt integer
local PauseClass = {}
PauseClass.__index = PauseClass

--- @param ped number
--- @return integer
local function samplePortraitSide(ped)
    local rot = GetGameplayCamRot(2)
    local yaw = math.rad(rot.z)
    local camX = -math.sin(yaw)
    local camY = math.cos(yaw)
    local forward = GetEntityForwardVector(ped)
    local dot = (camX * forward.x) + (camY * forward.y)
    if dot > 0.0 then
        return -1
    end
    return 1
end

--- @param ped number
--- @param side integer 1 front | -1 behind
--- @return vector3 camPos
--- @return vector3 lookAt
local function portraitPose(ped, side)
    local look = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, portrait.lookZ)
    local camPos = GetOffsetFromEntityInWorldCoords(ped, 0.0, portrait.distance * side, portrait.height)

    local ray = StartShapeTestLosProbe(look.x, look.y, look.z, camPos.x, camPos.y, camPos.z, 1, ped, 7)
    local state, hit, endCoords = GetShapeTestResult(ray)
    local deadline = GetGameTimer() + 100
    while state == 1 and GetGameTimer() < deadline do
        Wait(0)
        state, hit, endCoords = GetShapeTestResult(ray)
    end
    if hit ~= 1 then
        return camPos, look
    end

    local dx = look.x - endCoords.x
    local dy = look.y - endCoords.y
    local dz = look.z - endCoords.z
    local len = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
    if len < 0.2 then
        return camPos, look
    end
    local pull = 0.18 / len
    return vector3(endCoords.x + (dx * pull), endCoords.y + (dy * pull), endCoords.z + (dz * pull)), look
end

--- @return boolean
local function isSettingsBusy()
    return SettingsBridge and SettingsBridge:isBusy() or false
end

--- @return boolean
local function nativeMapOpen()
    return NativeMap and NativeMap:isOpen() or false
end

--- @return PauseClass
function PauseClass:new()
    local self = setmetatable({}, PauseClass)
    self.open = false
    self.page = 'pause'
    self.quitConfirm = false
    self.suppressThread = false
    self.allowVanilla = false
    self.settingsOpening = false
    self.cam = nil
    self.retiredCam = nil
    self.blending = false
    self.anchorPos = nil
    self.anchorLook = nil
    self.portraitGen = 0
    self.portraitSide = 1
    self.idleDict = nil
    self.headerBusy = false
    self.headerAt = 0
    self.restoreRadar = false
    self.hudHidden = false
    self.waisHidden = false
    self.pauseAnimOn = false
    self.pauseAnimGen = 0
    self.pauseAnimPed = nil
    self.pauseAnimClip = nil
    self.pauseProp = nil
    self.portraitSuspended = false
    self.map3dOpening = false
    self.map3dGen = 0
    self.blipNamesFailures = 0
    return self
end

--- A task given a moment ago starts a frame or two later, so a menu closed right after opening
--- (ESC spammed) finds nothing to stop yet. Watch for a moment and end it once it shows up, or
--- a looping full-body clip would hold the player in place.
--- @param started fun(): boolean
--- @param stop fun()
--- @param superseded fun(): boolean true once a new run owns the ped again
local function endWhenStarted(started, stop, superseded)
    CreateThread(function()
        local deadline = GetGameTimer() + 2000
        while GetGameTimer() < deadline and not superseded() do
            if started() then
                stop()
                return
            end
            Wait(0)
        end
    end)
end

function PauseClass:playIdle(ped)
    -- The pause animation is the pose while it runs; the portrait idle would replace it.
    if self.pauseAnimOn then return end
    local gen <const> = self.portraitGen
    local dict = IsPedMale(ped) and idleMale or idleFemale
    if not pcall(lib.requestAnimDict, dict) then return end
    -- closed (or the pause animation started) while the clip loaded
    if self.portraitGen ~= gen or self.pauseAnimOn then return end
    TaskPlayAnim(ped, dict, 'idle', 2.0, 2.0, -1, 1, 0.0, false, false, false)
    self.idleDict = dict
end

function PauseClass:stopIdle()
    local dict = self.idleDict
    if not dict then return end
    self.idleDict = nil
    local ped <const> = cache.ped
    if ped and DoesEntityExist(ped) then
        local function playing() return IsEntityPlayingAnim(ped, dict, 'idle', 3) end
        local function stop() StopAnimTask(ped, dict, 'idle', 1.0) end
        if playing() then
            stop()
        else
            endWhenStarted(playing, stop, function() return self.idleDict ~= nil end)
        end
    end
    RemoveAnimDict(dict)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- PAUSE ANIMATION (what the character does while any pause screen is open)
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- 0 = waiting to start, 1 = performing; 7 = not found.
local SCRIPT_ANIM_TASKS <const> = { `SCRIPT_TASK_PLAY_ANIM`, `SCRIPT_TASK_SYNCHRONIZED_SCENE` }

--- @param ped number
--- @return boolean
local function animTaskActive(ped)
    for i = 1, #SCRIPT_ANIM_TASKS do
        local status = GetScriptTaskStatus(ped, SCRIPT_ANIM_TASKS[i])
        if status == 0 or status == 1 then return true end
    end
    return false
end

--- States where taking over the ped with an animation would break what it is doing.
--- @param ped number
--- @param ours? fun(): boolean true when the ped is still in our own pause animation (reopened
--- while it was ending): that is not another script's
--- @return boolean
local function canPlayPauseAnim(ped, ours)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedSwimming(ped) then return false end
    if IsPedInAnyVehicle(ped, true) or IsPedGettingIntoAVehicle(ped) or IsPedClimbing(ped) then return false end
    if IsPedCuffed(ped) or IsPedInParachuteFreeFall(ped) then return false end
    -- a scenario, an emote or another script's animation (sitting, leaning, hands up): do not
    -- stand them up
    if (IsPedUsingAnyScenario(ped) or animTaskActive(ped)) and not (ours and ours()) then return false end
    -- carried, escorted, taken hostage: another player's script owns the ped
    if IsEntityAttached(ped) then return false end
    if GetPedParachuteState(ped) > 0 then return false end
    -- A scenario puts the weapon away, which inventories see as an unequip.
    if IsPedArmed(ped, 7) then return false end
    return true
end

--- @return string|nil
local function pauseScenario()
    local name = pauseAnim.scenario
    if type(name) == 'string' and name ~= '' then return name end
    return nil
end

--- @param ped number
--- @param prop table
--- @return number|nil
local function createPauseProp(ped, prop)
    local ok, model = pcall(lib.requestModel, prop.model)
    if not ok or not model then
        LT.Debug.Error('config.pause.pauseAnim.prop: cannot load model %s', tostring(prop.model))
        return nil
    end
    local coords = GetEntityCoords(ped)
    -- Networked so other players see it; servers that block client entities still get a local one.
    local obj = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
    if not obj or obj == 0 then
        obj = CreateObject(model, coords.x, coords.y, coords.z + 0.2, false, false, false)
    end
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 then return nil end
    local offset = prop.offset or vector3(0.0, 0.0, 0.0)
    local rotation = prop.rotation or vector3(0.0, 0.0, 0.0)
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, prop.bone or 28422),
        offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, true, true, false, true, 1, true)
    return obj
end

--- @param obj number|nil
local function deletePauseProp(obj)
    if not obj or not DoesEntityExist(obj) then return end
    DetachEntity(obj, true, false)
    SetEntityAsMissionEntity(obj, true, true)
    DeleteEntity(obj)
end

--- Let go when something else takes over the ped (death, ragdoll, a vehicle, being carried,
--- another script's task) instead of leaving it holding the prop.
--- @param gen integer
--- @param ped number
--- @param stillOurs fun(): boolean
function PauseClass:watchPauseAnim(gen, ped, stillOurs)
    while self.pauseAnimGen == gen do
        Wait(500)
        if self.pauseAnimGen ~= gen then break end
        if cache.ped ~= ped or IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, true)
            or IsEntityAttached(ped) or not stillOurs()
        then
            self:releasePauseAnim()
            break
        end
    end
end

--- Something else owns the ped now: stop holding the camera and drop our own prop, but leave
--- the ped's tasks alone (ending them could cancel e.g. the carry animation). Whatever is still
--- ours is ended when the menu closes.
function PauseClass:releasePauseAnim()
    if not self.pauseAnimOn then return end
    self.pauseAnimOn = false
    self.pauseAnimGen = self.pauseAnimGen + 1
    local obj = self.pauseProp
    self.pauseProp = nil
    deletePauseProp(obj)
end

function PauseClass:startPauseAnim()
    if pauseAnim.enabled ~= true or self.pauseAnimOn then return end
    local scenario <const> = pauseScenario()
    if not scenario and (type(pauseAnim.dict) ~= 'string' or type(pauseAnim.name) ~= 'string') then return end
    -- Character select / spawn screens animate the ped themselves.
    if not LT.Framework.IsPlayerLoaded() then return end
    local ped <const> = cache.ped
    local dict, name = pauseAnim.dict, pauseAnim.name
    local female = pauseAnim.female
    if not scenario and type(female) == 'table' and type(female.dict) == 'string' and type(female.name) == 'string'
        and not IsPedMale(ped)
    then
        dict, name = female.dict, female.name
    end
    local function ours()
        if scenario then return IsPedUsingScenario(ped, scenario) end
        return IsEntityPlayingAnim(ped, dict, name, 3)
    end
    if not canPlayPauseAnim(ped, ours) then return end
    self.pauseAnimOn = true
    self.pauseAnimGen = self.pauseAnimGen + 1
    self.pauseAnimPed = ped
    local gen <const> = self.pauseAnimGen

    if scenario then
        -- The game plays the enter clip, loops the scenario, picks the male or female clips and
        -- owns any prop; ClearPedTasks plays the exit clip.
        self.pauseAnimClip = { scenario = scenario }
        -- timeToLeave < 0 sets IdleForever: with 0 the game ends the scenario after its shortest run.
        TaskStartScenarioInPlace(ped, scenario, -1, true)
        CreateThread(function()
            self:watchPauseAnim(gen, ped, function() return IsPedUsingScenario(ped, scenario) end)
        end)
        return
    end

    self.pauseAnimClip = { dict = dict, name = name }
    CreateThread(function()
        local ok = pcall(lib.requestAnimDict, dict)
        if not ok then
            LT.Debug.Error('config.pause.pauseAnim: cannot load animation dictionary %s', dict)
            if self.pauseAnimGen == gen then self:stopPauseAnim() end
            return
        end
        if self.pauseAnimGen ~= gen then return end

        if type(pauseAnim.prop) == 'table' and pauseAnim.prop.model then
            local obj = createPauseProp(ped, pauseAnim.prop)
            -- The menu may have closed while the model loaded.
            if self.pauseAnimGen ~= gen then
                deletePauseProp(obj)
                return
            end
            self.pauseProp = obj
        end

        TaskPlayAnim(ped, dict, name, 2.0, 2.0, -1, tonumber(pauseAnim.flag) or 1, 0.0, false, false, false)
        self:watchPauseAnim(gen, ped, function() return IsEntityPlayingAnim(ped, dict, name, 3) end)
    end)
end

function PauseClass:stopPauseAnim()
    if not self.pauseAnimOn and not self.pauseAnimClip then return end
    self.pauseAnimOn = false
    self.pauseAnimGen = self.pauseAnimGen + 1
    local ped = self.pauseAnimPed
    local clip = self.pauseAnimClip or {}
    self.pauseAnimPed = nil
    self.pauseAnimClip = nil
    local alive = ped and DoesEntityExist(ped)
    local gen <const> = self.pauseAnimGen
    local function superseded() return self.pauseAnimGen ~= gen end
    -- Only end our own task: another script may have put the ped into something else meanwhile.
    if clip.scenario then
        if alive then
            local function using() return IsPedUsingScenario(ped, clip.scenario) end
            local function stop() ClearPedTasks(ped) end
            if using() then stop() else endWhenStarted(using, stop, superseded) end
        end
    elseif clip.dict then
        if alive then
            local function playing() return IsEntityPlayingAnim(ped, clip.dict, clip.name, 3) end
            local function stop() StopAnimTask(ped, clip.dict, clip.name, 2.0) end
            if playing() then stop() else endWhenStarted(playing, stop, superseded) end
        end
        RemoveAnimDict(clip.dict)
    end
    local obj = self.pauseProp
    self.pauseProp = nil
    deletePauseProp(obj)
end

--- @param coords vector3
--- @param look vector3
--- @param activate boolean
--- @return number|nil
local function createNewCamera(coords, look, activate)
    local ped = cache.ped
    if not ped or ped == 0 or IsPedInAnyVehicle(ped, false) then return nil end

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not cam or not DoesCamExist(cam) then return nil end
    SetCamCoord(cam, coords.x, coords.y, coords.z)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    SetCamFov(cam, portrait.fov)
    if activate then
        SetCamActive(cam, true)
    end
    return cam
end

--- @param cam number|nil
local function destroyCam(cam)
    if cam and DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
end

function PauseClass:startPortrait()
    if not isPortraitEnabled() then return end
    local ped <const> = cache.ped
    if not ped or ped == 0 or IsPedInAnyVehicle(ped, false) then return end
    -- another script's camera (character select, death cam, CCTV...): taking over would leave
    -- the game camera behind it on close
    local rendering <const> = GetRenderingCam()
    if rendering ~= -1 and rendering ~= self.cam and rendering ~= self.retiredCam and DoesCamExist(rendering) then return end

    self.portraitGen = self.portraitGen + 1
    self.portraitSide = samplePortraitSide(ped)
    local side <const> = self.portraitSide

    local coords, look = portraitPose(ped, side)
    if not self.cam or not DoesCamExist(self.cam) then
        self.cam = createNewCamera(coords, look, true)
    else
        -- reopened while the last camera was still blending out: re-aim it at the new pose
        SetCamCoord(self.cam, coords.x, coords.y, coords.z)
        PointCamAtCoord(self.cam, look.x, look.y, look.z)
        SetCamActive(self.cam, true)
    end
    if self.retiredCam and self.retiredCam ~= self.cam then
        destroyCam(self.retiredCam)
    end
    self.retiredCam = nil
    self.blending = false
    self.anchorPos = coords
    self.anchorLook = look
    RenderScriptCams(true, true, portrait.blendInMs, true, true)
    -- the idle pose only when nothing else (pause animation, carry, cuffs...) owns the ped
    if canPlayPauseAnim(ped) then self:playIdle(ped) end
    if portrait.follow == false then return end
    self:followPortrait(self.portraitGen, side)
end

--- The camera holds still while the pause animation plays (its clips shuffle and turn the
--- character). Otherwise it eases after the character: carried, pushed, ragdolled. Teleports and
--- respawns cut straight to the new place, and a vehicle hands over to the game camera.
--- @param gen integer
--- @param side integer
function PauseClass:followPortrait(gen, side)
    local target, targetLook = nil, nil
    local snap = false
    local speed <const> = 3000.0 / math.max(100.0, tonumber(portrait.followBlendMs) or 700.0)
    local deadzone <const> = tonumber(portrait.followMove) or 0.45

    -- where the camera should be: needs a shape test, so a few times a second
    CreateThread(function()
        while self.open and self.portraitGen == gen do
            local ped = cache.ped
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                if IsPedInAnyVehicle(ped, false) then
                    self:suspendPortrait()
                    return
                end
                local camPos, look = portraitPose(ped, side)
                local from = target or self.anchorPos
                local drift = from and #(camPos - from) or 0.0
                if drift > SNAP_DISTANCE then
                    target, targetLook, snap = camPos, look, true
                elseif not self.pauseAnimOn and (target or drift > deadzone) then
                    target, targetLook = camPos, look
                end
            end
            Wait(150)
        end
    end)

    -- ease the camera toward it, every frame while it is moving
    CreateThread(function()
        while self.open and self.portraitGen == gen do
            local cam = self.cam
            local pos, lookAt = self.anchorPos, self.anchorLook
            if target and targetLook and cam and DoesCamExist(cam) and pos and lookAt then
                if snap then
                    pos, lookAt, snap = target, targetLook, false
                else
                    local k = 1.0 - math.exp(-GetFrameTime() * speed)
                    pos = pos + (target - pos) * k
                    lookAt = lookAt + (targetLook - lookAt) * k
                end
                SetCamCoord(cam, pos.x, pos.y, pos.z)
                PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
                self.anchorPos, self.anchorLook = pos, lookAt
                if #(target - pos) < 0.02 and #(targetLook - lookAt) < 0.02 then
                    target, targetLook = nil, nil
                end
                Wait(0)
            else
                Wait(100)
            end
        end
    end)
end

--- Put in a vehicle while paused (arrested, kidnapped): blend back to the game camera, which
--- follows the vehicle, and bring the portrait back once the character is out again.
function PauseClass:suspendPortrait()
    if self.portraitSuspended then return end
    self.portraitSuspended = true
    self:stopPortrait(true)
    CreateThread(function()
        while self.open and self.portraitSuspended do
            Wait(250)
            local ped = cache.ped
            local onPage = self.page == 'pause' or self.page == 'settings'
            if onPage and ped and ped ~= 0 and not IsPedInAnyVehicle(ped, false)
                and not (Camera and Camera:isOpen()) and not nativeMapOpen()
            then
                self.portraitSuspended = false
                self:startPortrait()
            end
        end
        self.portraitSuspended = false
    end)
end

--- @param blend boolean
function PauseClass:stopPortrait(blend)
    self.portraitGen = self.portraitGen + 1
    local gen = self.portraitGen
    local cam = self.cam
    local retired = self.retiredCam
    self.blending = false
    self.anchorPos = nil
    self.anchorLook = nil
    self.portraitSide = 1
    self.retiredCam = nil
    if not cam or not DoesCamExist(cam) then
        self.cam = nil
        if retired ~= cam then
            destroyCam(retired)
        end
        self:stopIdle()
        return
    end

    if not blend then
        RenderScriptCams(false, false, 0, true, true)
        destroyCam(cam)
        if retired ~= cam then
            destroyCam(retired)
        end
        self.cam = nil
        self:stopIdle()
        return
    end

    RenderScriptCams(false, true, portrait.blendOutMs, true, true)
    CreateThread(function()
        Wait(portrait.blendOutMs)
        if self.portraitGen ~= gen then
            if retired ~= self.cam and retired ~= self.retiredCam then
                destroyCam(retired)
            end
            return
        end
        destroyCam(cam)
        if retired ~= cam then
            destroyCam(retired)
        end
        if self.cam == cam then
            self.cam = nil
        end
        self:stopIdle()
    end)
end

function PauseClass:killNativePause()
    if SettingsBridge and SettingsBridge.active then return end
    if nativeMapOpen() then return end
    SetPauseMenuActive(false)
    ReleaseControlOfFrontend()
    SetFrontendActive(false)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- NUI
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- @param page string
function PauseClass:setPage(page)
    self.page = page
    SendVue('UpdatePage', { page = page })
end

function PauseClass:showNui()
    SendVue('UpdateVisibility', { visible = true })
    LT.NUI.Focus(true, true)
end

function PauseClass:hideNui()
    LT.NUI.Focus(false)
    SendVue('UpdateVisibility', { visible = false })
    SendVue('UpdateCover', { cover = false })
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- HEADER
-- ════════════════════════════════════════════════════════════════════════════════════════════

function PauseClass:refreshHeader()
    if Client then
        local name = LT.Framework.GetPlayerName(true)
        Client:update({
            source = cache.serverId,
            name = name or '',
        })
        Client:sync()
    end

    local now = GetGameTimer()
    if self.headerBusy or (now - self.headerAt) < 8000 then return end
    self.headerBusy = true

    CreateThread(function()
        local data = lib.callback.await(_e('pause:header'), false)
        self.headerBusy = false
        self.headerAt = GetGameTimer()
        if type(data) ~= 'table' or not Client then return end
        Client:update({
            cash = data.cash or 0,
            bank = data.bank or 0,
            premium = tonumber(data.premium) or -1,
            players = data.players or 0,
            maxPlayers = data.maxPlayers or 48,
        })
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- OPEN / CLOSE
-- ════════════════════════════════════════════════════════════════════════════════════════════

local waisFailed = false

--- @param hidden boolean
--- @return boolean called false when wais-hudv6 is off in the config or not started
local function setWaisHud(hidden)
    if not cfg.pause.hideWaisHud then return false end
    local hudCfg = type(cfg.pause.waisHud) == 'table' and cfg.pause.waisHud or {}
    local resource = type(hudCfg.resource) == 'string' and hudCfg.resource or waisHud
    if GetResourceState(resource) ~= 'started' then return false end
    local fn = hidden and hudCfg.hide or hudCfg.show
    if type(fn) ~= 'function' then
        -- a config without the waisHud block: the same calls as the default config
        fn = hidden and function(hud) hud:showHud(); hud:showRadar(true) end
            or function(hud) hud:hideHud(); hud:showRadar(false) end
    end
    local ok, err = pcall(fn, exports[resource])
    if not ok and not waisFailed then
        waisFailed = true
        LT.Debug.Error('config.pause.waisHud.%s failed: %s', hidden and 'hide' or 'show', tostring(err))
    end
    return true
end

--- Hides third-party HUDs while any pause screen (home, maps, settings, vanilla) is up.
--- @param hidden boolean
function PauseClass:setHudHidden(hidden)
    if self.hudHidden == hidden then return end
    self.hudHidden = hidden
    if hidden then
        -- Before a character is loaded (multicharacter, spawn select) the HUD is not ours to
        -- touch: closing the menu there must not show it over those screens.
        if not LT.Framework.IsPlayerLoaded() then return end
        self.waisHidden = setWaisHud(true)
    elseif self.waisHidden then
        self.waisHidden = false
        setWaisHud(false)
    end
end

--- Everything that lasts exactly as long as a pause screen is up (home, maps, settings,
--- vanilla pause): the hidden HUD and the pause animation.
--- @param paused boolean
function PauseClass:setPaused(paused)
    self:setHudHidden(paused)
    if paused then
        self:startPauseAnim()
    else
        self:stopPauseAnim()
    end
end

--- @param name 'onPauseOpened'|'onPauseClosed'
function PauseClass:runHook(name)
    local fn = cfg.pause[name]
    if type(fn) ~= 'function' then return end
    -- A broken user hook must not leave the pause menu half open/closed.
    local ok, err = pcall(fn)
    if not ok then
        LT.Debug.Error('config.pause.%s failed: %s', name, tostring(err))
    end
end

function PauseClass:startSuppressLoop()
    if self.suppressThread then return end
    self.suppressThread = true
    local showRadar = not IsRadarHidden()
    self.restoreRadar = showRadar
    CreateThread(function()
        while self.suppressThread and (self.open or (Camera and Camera:isOpen()) or (SettingsBridge and SettingsBridge.active) or nativeMapOpen()) do
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            HideHudComponentThisFrame(14)
            DisplayRadar(false)
            local settingsOwns = self.page == 'settings' or self.settingsOpening or (SettingsBridge and SettingsBridge.active)
            local mapOwns = self.page == 'gtaMap' or nativeMapOpen()
            if settingsOwns then
                local cam = self.cam
                -- not while the portrait is handing over to the game camera (put in a vehicle)
                if cam and DoesCamExist(cam) and not self.portraitSuspended and not IsCamRendering(cam) then
                    SetCamActive(cam, true)
                    RenderScriptCams(true, false, 0, true, true)
                end
            elseif not mapOwns then
                SetPauseMenuActive(false)
                if IsPauseMenuActive() then
                    SetFrontendActive(false)
                end
            end
            Wait(0)
        end
        self.suppressThread = false
        self.restoreRadar = false
        if showRadar then
            DisplayRadar(true)
        end
    end)
end

function PauseClass:openHome()
    if self.allowVanilla then return end
    if Camera and Camera:isOpen() then return end
    if nativeMapOpen() then return end
    if SettingsBridge and SettingsBridge.active and isSettingsBusy() then return end
    if SettingsBridge and SettingsBridge.active then
        SettingsBridge:stop()
    end
    self.open = true
    self.quitConfirm = false
    self:setPage('pause')
    self:showNui()
    self:setPaused(true)
    self:startSuppressLoop()
    self:killNativePause()
    self:startPortrait()
    self:refreshHeader()
    self:runHook('onPauseOpened')
end

local function callFrontend(method, visible)
    if not BeginScaleformMovieMethodOnFrontend(method) then return end
    ScaleformMovieMethodAddParamBool(visible)
    EndScaleformMovieMethod()
end

local function callFrontendHeader(method, visible)
    if not BeginScaleformMovieMethodOnFrontendHeader(method) then return end
    ScaleformMovieMethodAddParamBool(visible)
    EndScaleformMovieMethod()
end

local function revealVanillaPause()
    TakeControlOfFrontend()
    callFrontend('BRIDGE_HIDE', false)
    callFrontend('BRIDGE_MAP_HIDE', false)
    callFrontendHeader('BRIDGE_HIDE', false)
    ReleaseControlOfFrontend()
end

function PauseClass:openVanilla()
    if self.allowVanilla then return end
    if Camera then Camera.returnToPause = false end
    if NativeMap then NativeMap.returnToPause = false end
    self:cancelMap3dOpen()
    self.open = false
    self.page = 'pause'
    self.quitConfirm = false
    self.suppressThread = false
    self.settingsOpening = false
    self.allowVanilla = true
    self:hideNui()
    -- The vanilla pause counts as paused too: keep the HUD hidden and the animation on until it closes.
    self:setPaused(true)
    self:runHook('onPauseClosed')
    local function vanillaDone()
        if not self.open then
            self:setPaused(false)
        end
    end
    CreateThread(function()
        Wait(0)
        if Camera and Camera:isOpen() then
            Camera:closeMap()
        end
        if nativeMapOpen() then
            NativeMap:close()
        end
        if SettingsBridge and SettingsBridge.active then
            SettingsBridge:stop()
        end
        self:stopPortrait(false)

        local deadline = GetGameTimer() + 2000
        while self.allowVanilla and (IsPauseMenuActive() or IsPauseMenuRestarting()) and GetGameTimer() < deadline do
            Wait(0)
        end
        if not self.allowVanilla then
            vanillaDone()
            return
        end
        Wait(0)

        local started = GetGameTimer()
        local shown = false
        local nextTry = 0
        while self.allowVanilla and not shown and GetGameTimer() - started < 3000 do
            if IsPauseMenuActive() and not IsPauseMenuRestarting() and IsFrontendReadyForControl() then
                revealVanillaPause()
                shown = true
                break
            end
            if not IsPauseMenuActive() and not IsPauseMenuRestarting() and GetGameTimer() >= nextTry then
                ActivateFrontendMenu(`FE_MENU_VERSION_SP_PAUSE`, true, -1)
                nextTry = GetGameTimer() + 500
            end
            Wait(0)
        end

        while self.allowVanilla do
            if shown then
                if not IsPauseMenuActive() and not IsPauseMenuRestarting() then
                    self.allowVanilla = false
                    break
                end
            elseif GetGameTimer() - started >= 3000 then
                self.allowVanilla = false
                break
            end
            Wait(100)
        end
        vanillaDone()
    end)
end

function PauseClass:close()
    if SettingsBridge and SettingsBridge.active and isSettingsBusy() then return end
    self:cancelMap3dOpen()
    self.settingsOpening = false
    self.page = 'pause'
    if SettingsBridge and SettingsBridge.active then
        SettingsBridge:stop()
    end
    if Camera and Camera:isOpen() then
        Camera.returnToPause = false
        Camera:closeMap()
        return
    end
    if nativeMapOpen() then
        NativeMap.returnToPause = false
        NativeMap:close()
        self.open = false
        self.quitConfirm = false
        self.suppressThread = false
        self:hideNui()
        self:setPaused(false)
        self:runHook('onPauseClosed')
        return
    end
    self.open = false
    self.quitConfirm = false
    self.suppressThread = false
    self:stopPortrait(true)
    self:killNativePause()
    self:hideNui()
    self:setPaused(false)
    self:runHook('onPauseClosed')
end

function PauseClass:toggle()
    if self.allowVanilla then return end
    if Camera and Camera:isOpen() then
        return
    end
    if nativeMapOpen() then
        return
    end
    if self.open then
        self:close()
    else
        self:openHome()
    end
end

function PauseClass:onMapClosed()
    self.open = true
    self.quitConfirm = false
    self:setPage('pause')
    self:showNui()
    self:setPaused(true)
    self:startSuppressLoop()
    self:killNativePause()
    self:startPortrait()
    self:refreshHeader()
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- ACTIONS
-- ════════════════════════════════════════════════════════════════════════════════════════════

function PauseClass:continueGame()
    self:close()
end

function PauseClass:openMap()
    if self.map3dOpening then return end
    if not NativeMap or NativeMap:isOpen() then return end
    if Camera and Camera:isOpen() then return end
    if SettingsBridge and (SettingsBridge.active or SettingsBridge.dumpBusy) then return end
    self.quitConfirm = false
    self:stopPortrait(false)
    self:setPage('gtaMap')
    NativeMap.returnToPause = true
    LT.Debug.Info('opening the map')
    NativeMap:openMap()
end

--- Closing the pause meanwhile drops a 3D map that is still on its way.
function PauseClass:cancelMap3dOpen()
    self.map3dGen += 1
    self.map3dOpening = false
end

--- The 3D map names the server's blips from the GTA map legend. When blips are on the map whose
--- names were never read, read the legend first, with the screen covered (once per new icon).
--- @param gen integer
--- @return boolean covered
function PauseClass:learnBlipNames(gen)
    if self.blipNamesFailures >= 2 or not NativeMap or not ThreeDMap or not BlipNames then return false end
    if not NativeMap:canLearn() then return false end
    local icons = ThreeDMap:unknownIcons()
    if #icons == 0 then return false end
    LT.Debug.Info('3d map: %s blip icons without a name, reading the map legend first', #icons)
    SendVue('UpdateCover', { cover = true })
    Wait(COVER_FADE_MS)
    if self.map3dGen ~= gen or not self.open then return true end
    self:stopPortrait(false)
    if NativeMap:learnNames() then
        BlipNames.settle(icons)
    elseif self.map3dGen == gen and self.open then
        -- not closed by the player: the legend could not be read; try once more, then stop
        -- holding up every 3D map open for it
        self.blipNamesFailures += 1
    end
    return true
end

function PauseClass:openMap3d()
    if not cfg.threeDMap or not cfg.threeDMap.enabled then return end
    if not Camera or Camera:isOpen() or self.map3dOpening then return end
    if nativeMapOpen() or self.settingsOpening then return end
    self.quitConfirm = false
    self.map3dGen += 1
    local gen = self.map3dGen
    self.map3dOpening = true
    LT.Debug.Info('opening the 3d map')
    CreateThread(function()
        local ok, covered = pcall(self.learnBlipNames, self, gen)
        if not ok then
            LT.Debug.Error('reading the blip names failed: %s', tostring(covered))
            covered = true
        end
        if self.map3dGen ~= gen then return end
        self.map3dOpening = false
        if (covered and not self.open) or Camera:isOpen() or nativeMapOpen() then
            if covered then SendVue('UpdateCover', { cover = false }) end
            return
        end
        self:stopPortrait(false)
        Camera.returnToPause = false
        -- straight from the cover into the 3D map's own fade: the game view does not flash between
        if covered then DoScreenFadeOut(0) end
        self:hideNui()
        Camera:openMap()
    end)
end

function PauseClass:openStats()
    if not cfg.pause.showStats then return end
    if self.map3dOpening then return end
    if self.settingsOpening then return end
    if SettingsBridge and SettingsBridge.active then return end
    if nativeMapOpen() then return end
    if Camera and Camera:isOpen() then return end
    self:cancelQuit()
    self:setPage('stats')
end

function PauseClass:openSettings()
    if not SettingsBridge then return end
    -- the 3D map is on its way (its names are read behind the cover): menu keys wait for it
    if self.map3dOpening then return end
    if self.settingsOpening then return end
    if SettingsBridge.active then return end
    if nativeMapOpen() then return end
    self.quitConfirm = false
    self.settingsOpening = true
    self:setPage('settings')
    CreateThread(function()
        SettingsBridge:start()
        self.settingsOpening = false
    end)
end

function PauseClass:requestQuit()
    if self.map3dOpening then return end
    self.quitConfirm = true
    SendVue('UpdateQuitConfirm', { confirm = true })
end

function PauseClass:cancelQuit()
    self.quitConfirm = false
    SendVue('UpdateQuitConfirm', { confirm = false })
end

function PauseClass:confirmQuit()
    self:close()
    QuitGame()
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- INSTANCE & INPUT
-- ════════════════════════════════════════════════════════════════════════════════════════════

_G.Pause = PauseClass:new()

local mpPause <const> = `FE_MENU_VERSION_MP_PAUSE`

local function pauseOwnsInput()
    if Pause.allowVanilla or Pause.settingsOpening or Pause.open then return true end
    if Camera and Camera:isOpen() then return true end
    if nativeMapOpen() then return true end
    if Pause.page == 'settings' or Pause.page == 'gtaMap' then return true end
    if SettingsBridge and SettingsBridge.active then return true end
    return false
end

CreateThread(function()
    while true do
        if Pause.allowVanilla then
            Wait(200)
        else
            if IsPauseMenuActive()
                and not IsPauseMenuRestarting()
                and GetCurrentFrontendMenuVersion() == mpPause
                and not pauseOwnsInput()
            then
                SetFrontendActive(false)
                if not IsNuiFocused() then
                    Pause:openHome()
                end
            end
            Wait(0)
        end
    end
end)

LT.NUI.Callback('GetPortraitMode', function(_, cb)
    cb({ enabled = isPortraitEnabled() })
end)

LT.NUI.Callback('SetPortraitMode', function(data, cb)
    local enabled = data and data.enabled == true
    setPortraitEnabled(enabled)
    if Pause.open then
        if enabled then
            Pause:startPortrait()
        else
            Pause:stopPortrait(false)
        end
    end
    cb({ enabled = enabled })
end)

LT.NUI.Callback('PauseOpenVanilla', function(_, cb)
    cb('ok')
    Pause:openVanilla()
end)

RegisterCommand('regularpausemenu', function()
    Pause:openVanilla()
end, false)

LT.NUI.Callback('PauseContinue', function(_, cb)
    cb('ok')
    Pause:continueGame()
end)

LT.NUI.Callback('PauseOpenMap', function(_, cb)
    cb('ok')
    Pause:openMap()
end)

LT.NUI.Callback('PauseOpenMap3d', function(_, cb)
    cb('ok')
    Pause:openMap3d()
end)

LT.NUI.Callback('PauseOpenSettings', function(_, cb)
    cb('ok')
    Pause:openSettings()
end)

LT.NUI.Callback('PauseOpenStats', function(_, cb)
    if not cfg.pause.showStats then
        cb(false)
        return
    end
    local payload = { skills = {}, career = { session = 0, played = 0, deaths = 0, onFoot = 0, driven = 0 } }
    if Stats and Stats.snapshot then
        payload = Stats.snapshot()
    end
    Pause:openStats()
    cb(payload)
end)

LT.NUI.Callback('PauseCloseStats', function(_, cb)
    cb('ok')
    Pause:close()
end)

LT.NUI.Callback('PauseQuitRequest', function(_, cb)
    cb('ok')
    Pause:requestQuit()
end)

LT.NUI.Callback('PauseQuitCancel', function(_, cb)
    cb('ok')
    Pause:cancelQuit()
end)

LT.NUI.Callback('PauseQuitConfirm', function(_, cb)
    cb('ok')
    Pause:confirmQuit()
end)

LT.NUI.Callback('PauseBack', function(_, cb)
    if Pause.settingsOpening then
        cb({ ok = false })
        return
    end
    if Pause.page == 'settings' then
        if isSettingsBusy() then
            cb({ ok = false })
            return
        end
        if SettingsBridge and SettingsBridge:hasUnsavedGraphics() then
            SettingsBridge:promptUnsaved()
            cb({ ok = false })
            return
        end
    end
    cb({ ok = true })
    Pause:close()
end)

LT.Hooks.Stop(function()
    Pause:stopPortrait(false)
    -- The suppress loop dies with the resource; give the radar back if it hid it.
    if Pause.restoreRadar then
        Pause.restoreRadar = false
        DisplayRadar(true)
    end
    -- Give the HUD back and end the animation if the menu was up when the resource stopped.
    Pause:setPaused(false)
end)
