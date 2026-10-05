local cfg <const> = require 'config.main'
local camCfg <const> = cfg.camera

local MAP_YAW <const> = 315.0
local GROUND_SAMPLE_RADIUS <const> = 80.0
local typingBlocked <const> = { 21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 36, 44, 75, 203 }

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- RETURN 3D ANIM
-- ════════════════════════════════════════════════════════════════════════════════════════════

local return3dAnimKvp <const> = '0r_pausemenu_return3dAnim'
--- @return boolean
local function isReturn3dAnimEnabled()
    local value = GetResourceKvpString(return3dAnimKvp)
    if not value or value == '' then
        return true
    end
    return value ~= '0'
end

--- @param enabled boolean
local function setReturn3dAnimEnabled(enabled)
    SetResourceKvp(return3dAnimKvp, enabled and '1' or '0')
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- CLASS
-- ════════════════════════════════════════════════════════════════════════════════════════════

---@class CameraClass
---@field new fun(self): self
---@field state table
---@field open boolean
---@field cam number|nil
---@field yaw number
---@field pitch number
---@field height number
---@field targetPos vector3
---@field targetYaw number
---@field targetPitch number
---@field transitioning boolean
---@field orbitPivot vector3|nil
---@field orbitRadius number|nil
---@field sync fun(self: CameraClass)
---@field update fun(self: CameraClass, data: table)
---@field isOpen fun(self: CameraClass): boolean
---@field isSettled fun(self: CameraClass): boolean
---@field openMap fun(self: CameraClass)
---@field closeMap fun(self: CameraClass, immediate?: boolean)
---@field focusPlayer fun(self: CameraClass)
---@field focusAt fun(self: CameraClass, x: number, y: number, z: number)
---@field pan fun(self: CameraClass, dx: number, dy: number)
---@field rotate fun(self: CameraClass, dx: number, dy: number, nx?: number, ny?: number)
---@field zoom fun(self: CameraClass, delta: number, nx: number, ny: number)
---@field refreshInfo fun(self: CameraClass)
---@field startHideLoop fun(self: CameraClass)
---@field stopHideLoop fun(self: CameraClass)
---@field startDeathWatch fun(self: CameraClass)
---@field returnToPause boolean
---@field hideThread boolean
---@field deathThread boolean
---@field concealedPlayers table<number, boolean>
---@field hiddenPeds number[]
---@field hiddenVehicles number[]
local CameraClass = {}
CameraClass.__index = CameraClass

--- Creates a new camera instance.
--- @return CameraClass
function CameraClass:new()
    local self = setmetatable({}, CameraClass)

    self.state = LT.NUI.CreateState('UpdateMap', {
        zone = '',
        street = '',
        altitude = 0,
    })

    self.open = false
    self.cam = nil
    self.yaw = 0.0
    self.pitch = camCfg.pitch
    self.height = camCfg.minHeight
    self.panBasis = camCfg.minHeight
    self.targetPos = vector3(0.0, 0.0, 0.0)
    self.targetYaw = 0.0
    self.targetPitch = camCfg.pitch
    self.transitioning = false
    self.focusBusy = false
    self.closing = false
    self.abortTransition = false
    self.pendingFocus = nil
    self.moveThread = false
    self.infoThread = false
    self.deathThread = false
    self.lastCollisionAt = 0
    self.lastFocusX = nil
    self.lastFocusY = nil
    self.lastGroundAt = 0
    self.movingUntil = 0
    self.wasDragging = false
    self.groundZ = 0.0
    self.groundX = nil
    self.groundY = nil
    self.hasGround = false
    self.staleTallProbed = false
    self.orbitPivot = nil
    self.orbitRadius = nil
    self.returnToPause = false
    self.typing = false
    self.hideThread = false
    self.concealedPlayers = {}
    self.hiddenPeds = {}
    self.hiddenVehicles = {}

    return self
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- STATE MANAGEMENT
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- Syncs the map state to NUI.
function CameraClass:sync()
    self.state:sync()
end

--- Updates the map state.
--- @param data table
function CameraClass:update(data)
    self.state:update(data)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════════════════════════════════

local function easeOut(t)
    return 1.0 - ((1.0 - t) ^ 3)
end

local function lerpVec(a, b, t)
    return vector3(LT.Math.Lerp(a.x, b.x, t), LT.Math.Lerp(a.y, b.y, t), LT.Math.Lerp(a.z, b.z, t))
end

local function lerpAngle(a, b, t)
    local d = b - a
    while d > 180.0 do d = d - 360.0 end
    while d < -180.0 do d = d + 360.0 end
    return a + d * t
end

local function clampPitch(pitch)
    return LT.Math.Clamp(pitch, camCfg.maxPitch, camCfg.minPitch)
end

--- @param yaw number
--- @param pitch number
--- @return vector3
local function lookDir(yaw, pitch)
    local pitchRad = math.rad(pitch)
    local yawRad = math.rad(yaw)
    local cosP = math.abs(math.cos(pitchRad))
    return vector3(
        -math.sin(yawRad) * cosP,
        math.cos(yawRad) * cosP,
        math.sin(pitchRad)
    )
end

--- @param dir vector3
--- @return number, number
local function yawPitchFromDir(dir)
    local len = #dir
    if len < 0.0001 then
        return 0.0, camCfg.pitch or -60.0
    end
    local nx, ny, nz = dir.x / len, dir.y / len, dir.z / len
    if nz > 1.0 then nz = 1.0 elseif nz < -1.0 then nz = -1.0 end
    local pitch = math.deg(math.asin(nz))
    local yaw = math.deg(math.atan(-nx, ny))
    return yaw, clampPitch(pitch)
end

local ORBIT_RAY_DIST <const> = 2500.0
local ORBIT_RAY_FLAGS <const> = 1 + 16

function CameraClass:clearOrbit()
    self.orbitPivot = nil
    self.orbitRadius = nil
end

function CameraClass:markMoving()
    self.movingUntil = GetGameTimer() + 300
    self.wasDragging = true
end

function CameraClass:fadeOut()
    local ms = camCfg.fadeMs or 250
    DoScreenFadeOut(ms)
    while not IsScreenFadedOut() do
        Wait(0)
    end
end

--- @param waitDone? boolean
function CameraClass:fadeIn(waitDone)
    local ms = camCfg.fadeMs or 250
    DoScreenFadeIn(ms)
    if waitDone then
        while not IsScreenFadedIn() do
            Wait(0)
        end
    end
end

--- Streams the world around the camera.
--- @param x number
--- @param y number
--- @param z number
function CameraClass:updateFocus(x, y, z)
    local now = GetGameTimer()
    local dragging = now < self.movingUntil
    local interval = camCfg.focusInterval or 1000
    if now - self.lastCollisionAt < interval then
        return
    end

    if dragging and self.lastFocusX then
        local dx = x - self.lastFocusX
        local dy = y - self.lastFocusY
        if (dx * dx + dy * dy) < (200.0 * 200.0) then
            return
        end
    end

    self.lastCollisionAt = now
    self.lastFocusX = x
    self.lastFocusY = y
    SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(x, y, z)
end

--- True when the stored ground sample still sits under the camera.
--- @return boolean
function CameraClass:groundIsLocal()
    if not self.hasGround or not self.groundX then return false end
    local dx = self.targetPos.x - self.groundX
    local dy = self.targetPos.y - self.groundY
    return (dx * dx + dy * dy) <= (GROUND_SAMPLE_RADIUS * GROUND_SAMPLE_RADIUS)
end

--- Samples ground Z under the camera.
--- @param force? boolean
function CameraClass:refreshGround(force)
    local now = GetGameTimer()
    local dragging = now < self.movingUntil
    local interval = dragging and 500 or 200
    if not force and now - self.lastGroundAt < interval then
        return
    end
    self.lastGroundAt = now

    local x, y, z = self.targetPos.x, self.targetPos.y, self.targetPos.z
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
    local stale = not self:groundIsLocal()
    if not found and (not dragging or (stale and not self.staleTallProbed)) then
        if dragging and stale then
            self.staleTallProbed = true
        end
        found, groundZ = GetGroundZFor_3dCoord(x, y, 1000.0, false)
    end

    if found then
        self.groundZ = groundZ
        self.groundX = x
        self.groundY = y
        self.hasGround = true
        self.staleTallProbed = false
    end
end

--- @return number
function CameraClass:minCamZ()
    local floor = camCfg.minHeight
    if not self:groundIsLocal() then return floor end

    local groundFloor = self.groundZ + camCfg.minHeightAboveGround
    if groundFloor > floor then
        floor = groundFloor
    end
    return floor
end

--- @param z number
--- @return number
function CameraClass:clampZ(z)
    local maxZ = camCfg.maxHeight
    local minZ = self:minCamZ()

    if minZ > maxZ then
        return maxZ
    end
    if z < minZ then
        z = minZ
    end
    if z > maxZ then
        z = maxZ
    end
    return z
end

function CameraClass:clampToGround()
    self:refreshGround(false)
    if self.orbitPivot and self.orbitRadius then
        if self:groundIsLocal() then
            self.height = self.targetPos.z - self.groundZ
        end
        return
    end

    local z = self:clampZ(self.targetPos.z)
    if z ~= self.targetPos.z then
        self.targetPos = vector3(self.targetPos.x, self.targetPos.y, z)
    end
    if self:groundIsLocal() then
        self.height = z - self.groundZ
    end
end

--- @param camPos vector3
--- @param forward vector3
--- @return vector3
function CameraClass:groundLookPivot(camPos, forward)
    self:refreshGround(false)
    local groundZ = self:groundIsLocal() and self.groundZ or (self.targetPos.z - self.height)

    if math.abs(forward.z) > 0.001 then
        local t = (groundZ - camPos.z) / forward.z
        if t > 0.0 then
            return vector3(camPos.x + forward.x * t, camPos.y + forward.y * t, groundZ)
        end
    end

    return vector3(camPos.x, camPos.y, groundZ)
end

--- @param camPos vector3
--- @param dir vector3
--- @return vector3
function CameraClass:raycastPivot(camPos, dir)
    local endPos = camPos + (dir * ORBIT_RAY_DIST)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        camPos.x, camPos.y, camPos.z,
        endPos.x, endPos.y, endPos.z,
        ORBIT_RAY_FLAGS,
        0,
        7
    )
    local _ret, hit, hitPos = GetShapeTestResult(handle)
    if hit == 1 and hitPos then
        return hitPos
    end

    return self:groundLookPivot(camPos, dir)
end

--- @return vector3
function CameraClass:getLookPivot()
    return self:raycastPivot(self.targetPos, lookDir(self.targetYaw, self.targetPitch))
end

--- @param nx number
--- @param ny number
--- @return vector3
function CameraClass:screenDir(nx, ny)
    local forward = lookDir(self.targetYaw, self.targetPitch)
    local yaw = math.rad(self.targetYaw)

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
    if upLen > 0.001 then
        up = up / upLen
    end

    local screenX, screenY = GetActiveScreenResolution()
    local aspect = screenX / math.max(screenY, 1)
    local tanHalf = math.tan(math.rad(camCfg.fov) * 0.5)
    local ndcX = (nx or 0.5) * 2.0 - 1.0
    local ndcY = 1.0 - (ny or 0.5) * 2.0
    local dir = forward + right * (ndcX * tanHalf * aspect) + up * (ndcY * tanHalf)
    local dirLen = #dir
    if dirLen > 0.001 then
        dir = dir / dirLen
    end
    return dir
end

--- @param pivot vector3
--- @param yaw number
--- @param flatR number
function CameraClass:setOrbit(pivot, yaw, flatR)
    flatR = math.max(5.0, flatR)
    local yawRad = math.rad(yaw)
    self.targetYaw = yaw
    self.orbitRadius = flatR
    self.targetPos = vector3(
        pivot.x + math.sin(yawRad) * flatR,
        pivot.y - math.cos(yawRad) * flatR,
        self.targetPos.z
    )
end

--- @return boolean
function CameraClass:isSettled()
    if self.transitioning then return false end
    if GetGameTimer() < (self.movingUntil or 0) then return false end
    if not self.cam or not DoesCamExist(self.cam) then return true end

    local current = GetCamCoord(self.cam)
    local ddx = self.targetPos.x - current.x
    local ddy = self.targetPos.y - current.y
    local ddz = self.targetPos.z - current.z
    local yawErr = math.abs(((self.targetYaw - self.yaw + 540.0) % 360.0) - 180.0)
    local pitchErr = math.abs(self.targetPitch - self.pitch)
    return (ddx * ddx + ddy * ddy + ddz * ddz) < 0.0001 and yawErr < 0.02 and pitchErr < 0.02
end

function CameraClass:applyMove()
    if not self.cam or not DoesCamExist(self.cam) then return end

    local now = GetGameTimer()
    local probeAfterFocus = false
    if now < self.movingUntil then
        self:clampToGround()
    elseif self.wasDragging then
        self.wasDragging = false
        self.lastCollisionAt = 0
        probeAfterFocus = true
    end

    if self:isSettled() then
        if probeAfterFocus then
            self.lastGroundAt = 0
            self:clampToGround()
        end
        return
    end

    local dt = GetFrameTime()
    if dt <= 0.0 then dt = 0.016 end
    local t = 1.0 - math.exp(-(camCfg.moveLerp or 8.0) * dt)

    local current = GetCamCoord(self.cam)
    local nextPos = lerpVec(current, self.targetPos, t)
    local nextYaw = lerpAngle(self.yaw, self.targetYaw, t)
    local nextPitch = lerpAngle(self.pitch, self.targetPitch, t)

    self.yaw = nextYaw
    self.pitch = nextPitch
    SetCamCoord(self.cam, nextPos.x, nextPos.y, nextPos.z)
    SetCamRot(self.cam, nextPitch, 0.0, nextYaw, 2)
    self:updateFocus(nextPos.x, nextPos.y, nextPos.z)

    if probeAfterFocus then
        self.lastGroundAt = 0
        self:clampToGround()
    end
end

function CameraClass:startMoveThread()
    if self.moveThread then return end
    self.moveThread = true

    CreateThread(function()
        while self.open and self.moveThread do
            if self.typing then
                for i = 1, #typingBlocked do
                    DisableControlAction(0, typingBlocked[i], true)
                    DisableControlAction(2, typingBlocked[i], true)
                end
            end
            if not self.transitioning then
                self:applyMove()
            end
            Wait(0)
        end
        self.moveThread = false
    end)
end

function CameraClass:startInfoThread()
    if self.infoThread then return end
    self.infoThread = true

    CreateThread(function()
        while self.open and self.infoThread do
            self:refreshInfo()
            Wait(camCfg.infoInterval)
        end
        self.infoThread = false
    end)
end

function CameraClass:startDeathWatch()
    if self.deathThread then return end
    self.deathThread = true

    CreateThread(function()
        while self.open and self.deathThread do
            if cache.isDead then
                self.deathThread = false
                CreateThread(function()
                    self:closeMap(true)
                end)
                return
            end
            Wait(750)
        end
        self.deathThread = false
    end)
end

--- @param durationMs? number
--- @return boolean finished
function CameraClass:runTransition(fromPos, toPos, fromYaw, toYaw, fromPitch, toPitch, durationMs)
    if not self.cam or not DoesCamExist(self.cam) then return false end

    local duration = durationMs or camCfg.transitionMs
    local start = GetGameTimer()

    while self.cam and DoesCamExist(self.cam) do
        if self.abortTransition then
            local pos = GetCamCoord(self.cam)
            local rot = GetCamRot(self.cam, 2)
            self.yaw = rot.z
            self.targetYaw = rot.z
            self.pitch = rot.x
            self.targetPitch = rot.x
            self.targetPos = pos
            return false
        end

        local elapsed = GetGameTimer() - start
        local t = math.min(elapsed / duration, 1.0)
        local e = easeOut(t)

        local pos = lerpVec(fromPos, toPos, e)
        local yaw = lerpAngle(fromYaw, toYaw, e)
        local pitch = lerpAngle(fromPitch, toPitch, e)

        SetCamCoord(self.cam, pos.x, pos.y, pos.z)
        SetCamRot(self.cam, pitch, 0.0, yaw, 2)
        self:updateFocus(pos.x, pos.y, pos.z)

        if t >= 1.0 then break end
        Wait(0)
    end

    self.yaw = toYaw
    self.targetYaw = toYaw
    self.pitch = toPitch
    self.targetPitch = toPitch
    self.targetPos = toPos
    return true
end

function CameraClass:transition(fromPos, toPos, fromYaw, toYaw, fromPitch, toPitch, durationMs)
    self.transitioning = true
    self:runTransition(fromPos, toPos, fromYaw, toYaw, fromPitch, toPitch, durationMs)
    self.transitioning = false
end

--- @param mode 'focus'|'close'
function CameraClass:flyToPlayer(mode)
    if not self.cam or not DoesCamExist(self.cam) then return end

    local ped = cache.ped
    local pedCoords = GetEntityCoords(ped)
    local pedHeading = GetEntityHeading(ped)
    local fromPos = GetCamCoord(self.cam)
    local fromYaw = self.yaw
    local fromPitch = self.pitch
    local lookDownMs = camCfg.lookDownMs or 1200

    SetFocusPosAndVel(pedCoords.x, pedCoords.y, pedCoords.z, 0.0, 0.0, 0.0)

    local aboveZ
    if mode == 'focus' then
        aboveZ = fromPos.z
        if aboveZ < camCfg.minHeight then
            aboveZ = camCfg.minHeight
        elseif aboveZ > camCfg.maxHeight then
            aboveZ = camCfg.maxHeight
        end
    else
        aboveZ = math.min(pedCoords.z + self.height, camCfg.maxHeight)
    end
    local abovePos = vector3(pedCoords.x, pedCoords.y, aboveZ)
    local flyDistance = #(fromPos - abovePos)
    local flyMs = math.max(flyDistance * (camCfg.flyDistanceScale or 1.5), 500.0)
    local cruisePitch = camCfg.pitch
    local endYaw = mode == 'focus' and MAP_YAW or pedHeading

    if not self:runTransition(fromPos, abovePos, fromYaw, endYaw, fromPitch, cruisePitch, flyMs) then
        return
    end

    self:refreshGround(true)

    local topZ
    if mode == 'close' then
        topZ = self:clampZ(pedCoords.z + math.min(self.height, 35.0))
    elseif self:groundIsLocal() then
        topZ = self:minCamZ()
    else
        topZ = pedCoords.z + camCfg.minHeightAboveGround
        if topZ < camCfg.minHeight then
            topZ = camCfg.minHeight
        end
    end
    if mode == 'focus' and topZ > camCfg.maxHeight then
        topZ = camCfg.maxHeight
    end

    local topPos = vector3(pedCoords.x, pedCoords.y, topZ)
    local topPitch = -85.0
    if not self:runTransition(abovePos, topPos, endYaw, endYaw, cruisePitch, topPitch, lookDownMs) then
        return
    end

    self.targetPos = topPos
    self:refreshGround(true)
    self.height = self:groundIsLocal() and (topPos.z - self.groundZ) or (topPos.z - pedCoords.z)
    self.targetYaw = endYaw
    self.targetPitch = mode == 'focus' and camCfg.pitch or topPitch
    self.yaw = endYaw
    self.pitch = self.targetPitch

    if mode == 'focus' then
        if not self:runTransition(topPos, topPos, endYaw, endYaw, topPitch, camCfg.pitch, lookDownMs) then
            return
        end
        SetCamCoord(self.cam, topPos.x, topPos.y, topPos.z)
        SetCamRot(self.cam, camCfg.pitch, 0.0, endYaw, 2)
    end
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- @return boolean
function CameraClass:isOpen()
    return self.open
end

function CameraClass:startHideLoop()
    if self.hideThread then return end

    self.hideThread = true
    self.concealedPlayers = {}
    self.hiddenPeds = {}
    self.hiddenVehicles = {}

    local refreshMs = tonumber(camCfg.hideRefreshMs) or 200
    if refreshMs < 50 then refreshMs = 50 end

    CreateThread(function()
        while self.hideThread do
            local myPlayer = PlayerId()
            local myPed = cache.ped
            local myVehicle = cache.vehicle
            if not myVehicle or myVehicle == 0 then
                myVehicle = GetVehiclePedIsIn(myPed, false)
            end

            local skipPlayerPeds = camCfg.hideOtherPlayers ~= false

            if skipPlayerPeds then
                local active = {}
                local players = GetActivePlayers()
                for i = 1, #players do
                    local player = players[i]
                    if player ~= myPlayer then
                        active[player] = true
                        if not self.concealedPlayers[player] then
                            NetworkConcealPlayer(player, true, false)
                            self.concealedPlayers[player] = true
                        end
                    end
                end

                for player in pairs(self.concealedPlayers) do
                    if not active[player] then
                        NetworkConcealPlayer(player, false, false)
                        self.concealedPlayers[player] = nil
                    end
                end
            end

            if camCfg.hidePeds ~= false then
                local peds = GetGamePool('CPed')
                local nextPeds = {}
                local n = 0
                for i = 1, #peds do
                    local ped = peds[i]
                    if ped ~= myPed and (not skipPlayerPeds or not IsPedAPlayer(ped)) then
                        n = n + 1
                        nextPeds[n] = ped
                    end
                end
                self.hiddenPeds = nextPeds
            else
                self.hiddenPeds = {}
            end

            if camCfg.hideVehicles ~= false then
                local vehicles = GetGamePool('CVehicle')
                local nextVehicles = {}
                local n = 0
                for i = 1, #vehicles do
                    local veh = vehicles[i]
                    if veh ~= myVehicle then
                        n = n + 1
                        nextVehicles[n] = veh
                    end
                end
                self.hiddenVehicles = nextVehicles
            else
                self.hiddenVehicles = {}
            end

            Wait(refreshMs)
        end
    end)

    CreateThread(function()
        while self.hideThread do
            local peds = self.hiddenPeds
            for i = 1, #peds do
                SetEntityLocallyInvisible(peds[i])
            end

            local vehicles = self.hiddenVehicles
            for i = 1, #vehicles do
                SetEntityLocallyInvisible(vehicles[i])
            end

            if camCfg.hidePeds ~= false then
                SetPedDensityMultiplierThisFrame(0.0)
                SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
            end

            if camCfg.hideVehicles ~= false then
                SetVehicleDensityMultiplierThisFrame(0.0)
                SetRandomVehicleDensityMultiplierThisFrame(0.0)
                SetParkedVehicleDensityMultiplierThisFrame(0.0)
            end

            Wait(0)
        end
    end)
end

function CameraClass:stopHideLoop()
    self.hideThread = false
    self.hiddenPeds = {}
    self.hiddenVehicles = {}

    if self.concealedPlayers then
        for player in pairs(self.concealedPlayers) do
            NetworkConcealPlayer(player, false, false)
        end
        self.concealedPlayers = {}
    end
end

function CameraClass:openMap()
    if not cfg.threeDMap or not cfg.threeDMap.enabled then return end
    if self.open then return end

    local ped = cache.ped
    local pedCoords = GetEntityCoords(ped)
    local gameplayPos = GetGameplayCamCoord()
    local gameplayRot = GetGameplayCamRot(2)

    self.closing = false
    self.focusBusy = false
    self.abortTransition = false
    self.pendingFocus = nil

    self:fadeOut()
    self:startHideLoop()

    self:clearOrbit()

    self.targetPos = vector3(pedCoords.x, pedCoords.y, pedCoords.z)
    self:refreshGround(true)

    local groundZ = self.hasGround and self.groundZ or pedCoords.z
    local startZ = pedCoords.z + (tonumber(camCfg.startAt) or 0.0)
    startZ = self:clampZ(startZ)

    self.height = startZ - groundZ
    self.panBasis = math.max(math.abs(self.height), 1.0)
    self.targetPos = vector3(pedCoords.x, pedCoords.y, startZ)
    local targetPos = self.targetPos

    self.yaw = gameplayRot.z
    self.targetYaw = MAP_YAW
    self.pitch = gameplayRot.x
    self.targetPitch = camCfg.pitch

    self.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(self.cam, gameplayPos.x, gameplayPos.y, gameplayPos.z)
    SetCamRot(self.cam, gameplayRot.x, 0.0, gameplayRot.z, 2)
    SetCamFov(self.cam, camCfg.fov)
    SetCamActive(self.cam, true)
    RenderScriptCams(true, false, 0, true, true)

    self.open = true
    self:fadeIn(false)
    self:transition(gameplayPos, targetPos, gameplayRot.z, MAP_YAW, gameplayRot.x, camCfg.pitch)
    while not IsScreenFadedIn() do
        Wait(0)
    end
    self:updateFocus(targetPos.x, targetPos.y, targetPos.z)

    self:startMoveThread()
    self:startInfoThread()
    self:startDeathWatch()
    self:refreshInfo()
    self:sync()

    SendVue('UpdatePage', { page = 'map' })
    SendVue('UpdateVisibility', { visible = true })
    LT.NUI.Focus(true)
end

--- @param target { kind: 'at'|'player', x?: number, y?: number, z?: number }
function CameraClass:requestFocus(target)
    if not self.open or self.closing then return end
    if not self.cam or not DoesCamExist(self.cam) then return end

    if self.focusBusy then
        self.pendingFocus = target
        self.abortTransition = true
        return
    end

    if self.transitioning then return end

    self.pendingFocus = target
    self:drainPendingFocus()
end

function CameraClass:drainPendingFocus()
    if self.focusBusy then return end
    self.focusBusy = true

    while self.open and not self.closing and self.pendingFocus do
        local pending = self.pendingFocus
        self.pendingFocus = nil
        self.abortTransition = false
        self.transitioning = true
        self:clearOrbit()

        if pending.kind == 'player' then
            self:flyToPlayer('focus')
        else
            local x, y, z = pending.x + 0.0, pending.y + 0.0, pending.z + 0.0
            local fromPos = GetCamCoord(self.cam)
            local endZ = z + camCfg.minHeightAboveGround
            if endZ < camCfg.minHeight then endZ = camCfg.minHeight end
            if endZ > camCfg.maxHeight then endZ = camCfg.maxHeight end
            local yaw = math.rad(self.yaw)
            local back = math.max(endZ - z, 0.0) * 0.5
            local forwardX = -math.sin(yaw)
            local forwardY = math.cos(yaw)
            local toPos = vector3(x - forwardX * back, y - forwardY * back, endZ)
            local flyMs = math.max(#(fromPos - toPos) * (camCfg.flyDistanceScale), camCfg.minFlyMs)

            if self:runTransition(fromPos, toPos, self.yaw, self.yaw, self.pitch, camCfg.pitch, flyMs) then
                self.targetPos = toPos
                self:refreshGround(true)
                self.height = self.hasGround and (toPos.z - self.groundZ) or math.max(endZ - z, 0.0)
                self.targetYaw = self.yaw
                self.targetPitch = camCfg.pitch
            end
        end

        self.transitioning = false
    end

    self.focusBusy = false
    self.abortTransition = false
end

--- @param x number
--- @param y number
--- @param z number
function CameraClass:focusAt(x, y, z)
    self:requestFocus({ kind = 'at', x = x, y = y, z = z })
end

function CameraClass:focusPlayer()
    self:requestFocus({ kind = 'player' })
end

--- @param immediate? boolean
function CameraClass:closeMap(immediate)
    if not self.open then return end

    self.closing = true
    self.pendingFocus = nil
    self.abortTransition = true
    while self.focusBusy do
        Wait(0)
    end
    self.abortTransition = false

    self.moveThread = false
    self.infoThread = false
    self.deathThread = false
    self.typing = false
    self:clearOrbit()
    self.transitioning = true

    LT.NUI.Focus(false)
    SendVue('UpdateVisibility', { visible = false })

    local fadeReturn = false
    if immediate then
        RenderScriptCams(false, false, 0, true, true)
    elseif self.cam and DoesCamExist(self.cam) then
        if isReturn3dAnimEnabled() then
            local blendMs = camCfg.blendMs or 1400
            self:flyToPlayer('close')
            RenderScriptCams(false, true, blendMs, true, true)
            Wait(blendMs)
        else
            fadeReturn = true
            self:fadeOut()
            RenderScriptCams(false, false, 0, true, true)
        end
    else
        RenderScriptCams(false, false, 0, true, true)
    end

    ClearFocus()

    if self.cam and DoesCamExist(self.cam) then
        DestroyCam(self.cam, false)
    end

    self.cam = nil
    self:stopHideLoop()

    self.open = false
    self.closing = false
    self.transitioning = false

    if fadeReturn then
        self:fadeIn(false)
    end

    local back = self.returnToPause
    self.returnToPause = false
    if back and Pause then
        Pause:onMapClosed()
    elseif Pause and Pause.open then
        Pause:close()
    end
end

--- @param dx number
--- @param dy number
function CameraClass:pan(dx, dy)
    if not self.open or self.transitioning then return end

    self:clearOrbit()
    self:markMoving()

    local rad = math.rad(self.targetYaw)
    local forward = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local right = vector3(math.cos(rad), math.sin(rad), 0.0)
    local basis = self.panBasis
    if not basis or basis < 1.0 then
        basis = 1.0
    end
    local scale = camCfg.panSpeed * (self.height / basis)

    self.targetPos = self.targetPos + (right * (-dx * scale)) + (forward * (dy * scale))
end

--- @param dx number
--- @param dy number
--- @param nx? number
--- @param ny? number
function CameraClass:rotate(dx, dy, nx, ny)
    if not self.open or self.transitioning then return end

    self:markMoving()

    if not self.orbitPivot then
        nx = nx or 0.5
        ny = ny or 0.5
        local camPos = self.targetPos
        local dir = self:screenDir(nx, ny)
        self.orbitPivot = self:raycastPivot(camPos, dir)

        local ox = camPos.x - self.orbitPivot.x
        local oy = camPos.y - self.orbitPivot.y
        self.orbitRadius = math.max(5.0, math.sqrt(ox * ox + oy * oy))
        local yaw = yawPitchFromDir(self.orbitPivot - camPos)
        self.targetYaw = yaw
    end

    local speed = camCfg.rotateSpeed
    if dx ~= 0.0 then
        self:setOrbit(self.orbitPivot, self.targetYaw - (dx * speed), self.orbitRadius)
    end
    if dy ~= 0.0 then
        self.targetPitch = clampPitch(self.targetPitch - (dy * speed))
    end
end

--- @param delta number
--- @param nx number
--- @param ny number
function CameraClass:zoom(delta, nx, ny)
    if not self.open or self.transitioning then return end

    nx = nx or 0.5
    ny = ny or 0.5

    self:clearOrbit()
    self:markMoving()
    self:refreshGround(false)

    local camPos = self.targetPos
    local dir = self:screenDir(nx, ny)
    local focus = self:raycastPivot(camPos, dir)

    local ox = camPos.x - focus.x
    local oy = camPos.y - focus.y
    local oz = camPos.z - focus.z
    local dist = math.sqrt(ox * ox + oy * oy + oz * oz)
    if dist < 1.0 then return end

    local nextDist = dist + (delta * camCfg.zoomStep)
    if nextDist < 5.0 then nextDist = 5.0 end
    if math.abs(nextDist - dist) < 0.01 then return end

    local scale = nextDist / dist
    local newPos = vector3(
        focus.x + ox * scale,
        focus.y + oy * scale,
        focus.z + oz * scale
    )

    local z = self:clampZ(newPos.z)
    if math.abs(z - camPos.z) < 0.01 and math.abs(z - newPos.z) > 0.01 then
        return
    end
    newPos = vector3(newPos.x, newPos.y, z)

    self.targetPos = newPos
    if self:groundIsLocal() then
        self.height = z - self.groundZ
    end
end

function CameraClass:refreshInfo()
    if not self.cam or not DoesCamExist(self.cam) then return end

    local coords = GetCamCoord(self.cam)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

    if zone == 'NULL' or zone == nil or zone == '' then
        zone = 'Unknown'
    end
    if street == nil or street == '' then
        street = 'Unknown'
    end

    self.state.zone = zone
    self.state.street = street
    self.state.altitude = math.floor(coords.z)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- INSTANCE & COMMAND
-- ════════════════════════════════════════════════════════════════════════════════════════════

--[[ Camera instance ]]
_G.Camera = CameraClass:new()

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ════════════════════════════════════════════════════════════════════════════════════════════

LT.NUI.Callback('MapPan', function(data, cb)
    if Camera and Camera:isOpen() then
        Camera:pan(data.dx or 0.0, data.dy or 0.0)
    end
    cb('ok')
end)

LT.NUI.Callback('MapRotate', function(data, cb)
    if Camera and Camera:isOpen() then
        Camera:rotate(data.dx or 0.0, data.dy or 0.0, data.nx or 0.5, data.ny or 0.5)
    end
    cb('ok')
end)

LT.NUI.Callback('MapZoom', function(data, cb)
    if Camera and Camera:isOpen() then
        Camera:zoom(data.delta or 0.0, data.nx or 0.5, data.ny or 0.5)
    end
    cb('ok')
end)

LT.NUI.Callback('MapTyping', function(data, cb)
    cb('ok')
    if not Camera then return end
    local typing = type(data) == 'table' and data.typing == true
    Camera.typing = typing
    if typing then
        SetNuiFocusKeepInput(false)
    end
end)

LT.NUI.Callback('MapFocusPlayer', function(_, cb)
    cb('ok')
    if Camera and Camera:isOpen() then
        CreateThread(function()
            Camera:focusPlayer()
        end)
    end
end)

LT.NUI.Callback('CloseMap', function(_, cb)
    cb('ok')
    if Camera and Camera:isOpen() then
        CreateThread(function()
            Camera:closeMap()
        end)
    end
end)

LT.NUI.Callback('GetReturn3dAnim', function(_, cb)
    cb({ enabled = isReturn3dAnimEnabled() })
end)

LT.NUI.Callback('SetReturn3dAnim', function(data, cb)
    local enabled = data and data.enabled == true
    setReturn3dAnimEnabled(enabled)
    cb({ enabled = enabled })
end)

LT.Hooks.Stop(function()
    if Camera then
        Camera:stopHideLoop()
    end
end)
