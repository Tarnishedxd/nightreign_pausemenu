local cfg <const> = require 'config.main'
local portrait <const> = cfg.pause.portrait
local mapAnim <const> = cfg.pause.mapAnim or {}
local idleMale <const> = 'anim@heists@heist_corona@team_idles@male_a'
local idleFemale <const> = 'anim@heists@heist_corona@team_idles@female_a'
local portraitModeKvp <const> = 'portraitMode'
local waisHud <const> = 'wais-hudv6'

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
    self.mapAnimOn = false
    self.mapAnimGen = 0
    self.mapAnimPed = nil
    self.mapProp = nil
    return self
end

function PauseClass:playIdle(ped)
    -- The map animation is the pose while it runs; the portrait idle would replace it.
    if self.mapAnimOn then return end
    local dict = IsPedMale(ped) and idleMale or idleFemale
    lib.requestAnimDict(dict)
    TaskPlayAnim(ped, dict, 'idle', 2.0, 2.0, -1, 1, 0.0, false, false, false)
    self.idleDict = dict
end

function PauseClass:stopIdle()
    local dict = self.idleDict
    if not dict then return end
    self.idleDict = nil
    local ped <const> = cache.ped
    if ped and DoesEntityExist(ped) then
        StopAnimTask(ped, dict, 'idle', 1.0)
    end
    RemoveAnimDict(dict)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- MAP ANIMATION (the character holds a map while any pause screen is open)
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- States where taking over the ped with an animation would break what it is doing.
--- @param ped number
--- @return boolean
local function canPlayMapAnim(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedSwimming(ped) then return false end
    if IsPedInAnyVehicle(ped, true) or IsPedGettingIntoAVehicle(ped) or IsPedClimbing(ped) then return false end
    if IsPedCuffed(ped) or IsPedUsingAnyScenario(ped) or IsPedInParachuteFreeFall(ped) then return false end
    if GetPedParachuteState(ped) > 0 then return false end
    return true
end

--- @param ped number
--- @param prop table
--- @return number|nil
local function createMapProp(ped, prop)
    local ok, model = pcall(lib.requestModel, prop.model)
    if not ok or not model then
        LT.Debug.Error('config.pause.mapAnim.prop: cannot load model %s', tostring(prop.model))
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
local function deleteMapProp(obj)
    if not obj or not DoesEntityExist(obj) then return end
    DetachEntity(obj, true, false)
    SetEntityAsMissionEntity(obj, true, true)
    DeleteEntity(obj)
end

function PauseClass:startMapAnim()
    if mapAnim.enabled ~= true or self.mapAnimOn then return end
    if type(mapAnim.dict) ~= 'string' or type(mapAnim.name) ~= 'string' then return end
    -- Character select / spawn screens animate the ped themselves.
    if not LT.Framework.IsPlayerLoaded() then return end
    local ped <const> = cache.ped
    if not canPlayMapAnim(ped) then return end
    self.mapAnimOn = true
    self.mapAnimGen = self.mapAnimGen + 1
    self.mapAnimPed = ped
    local gen <const> = self.mapAnimGen
    local dict <const>, name <const> = mapAnim.dict, mapAnim.name

    CreateThread(function()
        local ok = pcall(lib.requestAnimDict, dict)
        if not ok then
            LT.Debug.Error('config.pause.mapAnim: cannot load animation dictionary %s', dict)
            if self.mapAnimGen == gen then self:stopMapAnim() end
            return
        end
        if self.mapAnimGen ~= gen then return end

        if type(mapAnim.prop) == 'table' and mapAnim.prop.model then
            local obj = createMapProp(ped, mapAnim.prop)
            -- The menu may have closed while the model loaded.
            if self.mapAnimGen ~= gen then
                deleteMapProp(obj)
                return
            end
            self.mapProp = obj
        end

        TaskPlayAnim(ped, dict, name, 2.0, 2.0, -1, tonumber(mapAnim.flag) or 1, 0.0, false, false, false)

        -- Let go when something else takes over the ped (death, ragdoll, a vehicle,
        -- another script's animation) instead of leaving the prop in its hand.
        while self.mapAnimGen == gen do
            Wait(500)
            if self.mapAnimGen ~= gen then break end
            if cache.ped ~= ped or IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, true)
                or not IsEntityPlayingAnim(ped, dict, name, 3)
            then
                self:stopMapAnim()
                break
            end
        end
    end)
end

function PauseClass:stopMapAnim()
    if not self.mapAnimOn then return end
    self.mapAnimOn = false
    self.mapAnimGen = self.mapAnimGen + 1
    local ped = self.mapAnimPed
    self.mapAnimPed = nil
    local dict, name = mapAnim.dict, mapAnim.name
    -- Only stop our own clip: another script may have put the ped into something else meanwhile.
    if ped and DoesEntityExist(ped) and IsEntityPlayingAnim(ped, dict, name, 3) then
        StopAnimTask(ped, dict, name, 2.0)
    end
    local obj = self.mapProp
    self.mapProp = nil
    deleteMapProp(obj)
    if type(dict) == 'string' then RemoveAnimDict(dict) end
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

--- @param coords vector3
--- @param look vector3
function PauseClass:blendPortrait(coords, look)
    local currentCam = self.cam
    if not currentCam or not DoesCamExist(currentCam) then
        local cam = createNewCamera(coords, look, true)
        if not cam then return end
        self.cam = cam
        self.anchorPos = coords
        self.anchorLook = look
        return
    end

    local newCam = createNewCamera(coords, look, false)
    if not newCam then return end

    local duration <const> = portrait.followBlendMs
    local gen <const> = self.portraitGen
    local retired <const> = currentCam
    if self.retiredCam and self.retiredCam ~= retired then
        destroyCam(self.retiredCam)
    end
    self.retiredCam = retired
    self.cam = newCam
    self.anchorPos = coords
    self.anchorLook = look
    self.blending = true
    SetCamActiveWithInterp(newCam, retired, duration, 1, 1)

    CreateThread(function()
        Wait(duration)
        if self.portraitGen ~= gen then return end
        if self.cam ~= retired then
            destroyCam(retired)
        end
        if self.retiredCam == retired then
            self.retiredCam = nil
        end
        if self.cam == newCam then
            self.blending = false
        end
    end)
end

function PauseClass:startPortrait()
    if not isPortraitEnabled() then return end
    local ped <const> = cache.ped
    if not ped or ped == 0 or IsPedInAnyVehicle(ped, false) then return end

    self.portraitGen = self.portraitGen + 1
    self.portraitSide = samplePortraitSide(ped)
    local side <const> = self.portraitSide

    local coords, look = portraitPose(ped, side)
    if not self.cam or not DoesCamExist(self.cam) then
        self.cam = createNewCamera(coords, look, true)
    end
    if self.retiredCam and self.retiredCam ~= self.cam then
        destroyCam(self.retiredCam)
    end
    self.retiredCam = nil
    self.blending = false
    self.anchorPos = coords
    self.anchorLook = look
    RenderScriptCams(true, true, portrait.blendInMs, true, true)
    local gen <const> = self.portraitGen
    CreateThread(function()
        while self.open and self.portraitGen == gen do
            local currentPed = cache.ped
            if currentPed and currentPed ~= 0 and not IsPedInAnyVehicle(currentPed, false) and not self.blending then
                local anchorPos = self.anchorPos
                local anchorLook = self.anchorLook
                if anchorPos and anchorLook then
                    local newCamPos, newLook = portraitPose(currentPed, side)
                    local difference = #(newCamPos - anchorPos) + #(newLook - anchorLook)
                    if difference > portrait.followMove then
                        self:blendPortrait(newCamPos, newLook)
                    end
                end
            end
            Wait(200)
        end
    end)
    self:playIdle(ped)
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
    if GetResourceState(waisHud) ~= 'started' then return false end
    local ok, err = pcall(function()
        local hud = exports[waisHud]
        if hidden then
            hud:hideHud()
            hud:showRadar(true) -- wais-hudv6: true hides the minimap
        else
            hud:showHud()
            hud:showRadar(false) -- false shows the minimap again
        end
    end)
    if not ok and not waisFailed then
        waisFailed = true
        LT.Debug.Error('%s export failed: %s', waisHud, tostring(err))
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
--- vanilla pause): the hidden HUD and the map animation.
--- @param paused boolean
function PauseClass:setPaused(paused)
    self:setHudHidden(paused)
    if paused then
        self:startMapAnim()
    else
        self:stopMapAnim()
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
                if cam and DoesCamExist(cam) and not IsCamRendering(cam) then
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
    self.open = false
    self.page = 'pause'
    self.quitConfirm = false
    self.suppressThread = false
    self.settingsOpening = false
    self.allowVanilla = true
    self:hideNui()
    -- The vanilla pause counts as paused too: keep the HUD hidden and the map out until it closes.
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

function PauseClass:openMap3d()
    if not cfg.threeDMap or not cfg.threeDMap.enabled then return end
    if not Camera or Camera:isOpen() then return end
    if nativeMapOpen() then return end
    self.quitConfirm = false
    self:stopPortrait(false)
    Camera.returnToPause = false
    self:hideNui()
    LT.Debug.Info('opening the 3d map')
    CreateThread(function()
        Camera:openMap()
    end)
end

function PauseClass:openStats()
    if not cfg.pause.showStats then return end
    if self.settingsOpening then return end
    if SettingsBridge and SettingsBridge.active then return end
    if nativeMapOpen() then return end
    if Camera and Camera:isOpen() then return end
    self:cancelQuit()
    self:setPage('stats')
end

function PauseClass:openSettings()
    if not SettingsBridge then return end
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
    -- Give the HUD back and drop the map if the menu was up when the resource stopped.
    Pause:setPaused(false)
end)
