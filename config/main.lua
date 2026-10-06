-- ════════════════════════════════════════════════════════════════════════════════════════════
--
-- made by
--
-- ╭━━━━┳━━━┳━━━┳━╮╱╭┳━━┳━━━┳╮╱╭┳━━━┳━━━╮
-- ┃╭╮╭╮┃╭━╮┃╭━╮┃┃╰╮┃┣┫┣┫╭━╮┃┃╱┃┃╭━━┻╮╭╮┃
-- ╰╯┃┃╰┫┃╱┃┃╰━╯┃╭╮╰╯┃┃┃┃╰━━┫╰━╯┃╰━━╮┃┃┃┃
-- ╱╱┃┃╱┃╰━╯┃╭╮╭┫┃╰╮┃┃┃┃╰━━╮┃╭━╮┃╭━━╯┃┃┃┃
-- ╱╱┃┃╱┃╭━╮┃┃┃╰┫┃╱┃┃┣┫┣┫╰━╯┃┃╱┃┃╰━━┳╯╰╯┃
-- ╱╱╰╯╱╰╯╱╰┻╯╰━┻╯╱╰━┻━━┻━━━┻╯╱╰┻━━━┻━━━╯
--
-- Github - https://github.com/laot7490
-- 0Resmon Studio - https://0resmon.tebex.io
--
-- ════════════════════════════════════════════════════════════════════════════════════════════

return {

    -- ════════════════════════════════════════════════════════════════════════════════════════════
    -- ⚙️ Setup & Core Settings
    -- ════════════════════════════════════════════════════════════════════════════════════════════

    --- Set debug level.
    --- Recommended to stay 1 for production. (Errors only)
    --- @type 1 | 2 | 3 | 4
    debug = 1,

    --- Check updates for the script on startup.
    --- The feed belongs to the original release and is looked up by resource name,
    --- so it has no entry for nightreign_pausemenu. Off by default.
    --- @type boolean
    checkVersion = false,

    -- ════════════════════════════════════════════════════════════════════════════════════════════
    -- 🧩 General Settings
    -- ════════════════════════════════════════════════════════════════════════════════════════════

    --- Set the locale key.
    --- Must be a valid locale `locales/*.json` file.
    --- Available: 'en', 'tr', 'hu', 'de', 'fr', 'es', 'it', 'pl', 'ro'
    --- Missing keys fall back to English; an unknown locale falls back to English with a console warning.
    --- @type 'en' | 'tr' | 'hu' | 'de' | 'fr' | 'es' | 'it' | 'pl' | 'ro' | string
    locale = 'hu',

    --- @type string Currency symbol (e.g. USD, TRY, EUR etc.)
    currency = 'USD',

    --- @type string Currency format (e.g. en-US, tr-TR, de-DE etc.)
    currencyFormat = 'en-US',

    -- ════════════════════════════════════════════════════════════════════════════════════════════
    -- ⏸️ Pause Settings
    -- ════════════════════════════════════════════════════════════════════════════════════════════

    pause = {

        --- Shown beside the logo on the pause screen.
        --- @type string
        serverName = 'Nightreign Roleplay',

        --- Show logo + server name on pause / settings / stats / 3D map.
        --- The logo is web/build/branding/logo.webp.
        --- @type boolean
        showBranding = true,

        --- Show the Stats entry (skills, play time, distances) in the pause menu.
        --- @type boolean
        showStats = false,

        --- Show the online player count (e.g. 12 / 48) under cash and bank.
        --- @type boolean
        showPlayerCount = false,

        --- Hide the wais-hudv6 HUD and minimap while the pause menu is open
        --- (map, 3D map and settings included) and show them again when it closes.
        --- Does nothing when wais-hudv6 is not started.
        --- @type boolean
        hideWaisHud = true,

        --- Premium points shown next to cash and bank in the pause header (read on the server).
        --- Optional: while the resource below is not started (whatever the start order, or during
        --- a restart) or does not have the export, the points are simply not shown and the menu
        --- works as usual. Read at most once every 5 seconds per player.
        premium = {

            --- @type boolean
            enabled = true,

            --- Resource with the server export that returns a player's premium points.
            --- @type string
            resource = 'g-coinshop',

            --- Export name, called as exports[resource]:export(source).
            --- @type string
            export = 'GetPremiumPointsBySource',

            --- Instead of resource / export, a function can read the points (return a number, or
            --- nil to hide them). Errors in it are caught the same way:
            --- get = function(source) return exports['my-shop']:GetPoints(source) end,

        },

        --- Front torso shot while the pause screen is open.
        --- @type table
        portrait = {

            --- Metres in front of or behind the ped.
            --- @type number
            distance = 2.55,

            --- Camera height above the entity origin.
            --- @type number
            height = 0.55,

            --- Look-at height above the ped origin.
            --- @type number
            lookZ = 0.35,

            --- @type number
            fov = 38.0,

            --- Gameplay → portrait blend (ms).
            --- @type number
            blendInMs = 900,

            --- Portrait → gameplay blend (ms).
            --- @type number
            blendOutMs = 750,

            --- Follow the character when something moves it while the menu is open (carried,
            --- pushed, ragdolled, teleported). The camera always holds still while the pause
            --- animation plays, and hands over to the game camera if the character is put in a
            --- vehicle. false: the camera never moves after opening.
            --- @type boolean
            follow = true,

            --- Metres the character must move before the camera starts following.
            --- @type number
            followMove = 0.45,

            --- Roughly how long the camera takes to catch up when following (ms).
            --- @type number
            followBlendMs = 700,

        },

        --- What the character does while any pause screen is open (home, map, 3D map, settings).
        --- Ends the moment the menu closes. Other players see it too.
        --- Skipped in a vehicle, while dead, ragdolled, falling, swimming, climbing, cuffed, holding
        --- a weapon, or already in an emote / another script's animation.
        pauseAnim = {

            --- @type boolean
            enabled = true,

            --- GTA scenario to play instead of the animation below (the game picks the male /
            --- female version and handles any prop), e.g. WORLD_HUMAN_STAND_IMPATIENT,
            --- WORLD_HUMAN_TOURIST_MAP, WORLD_HUMAN_STAND_MOBILE.
            --- false: play the animation below.
            --- @type string | false
            scenario = false,

            --- Animation: stands and waits, now and then checks the watch. Loops until the menu
            --- closes.
            --- @type string
            dict = 'amb@world_human_stand_impatient@male@no_sign@idle_a',

            --- @type string
            name = 'idle_a',

            --- Version for female characters. false: they play the one above.
            --- @type { dict: string, name: string } | false
            female = {
                dict = 'amb@world_human_stand_impatient@female@no_sign@idle_a',
                name = 'idle_a',
            },

            --- TaskPlayAnim flag: 1 = loop (full body), 49 = loop (upper body only).
            --- @type integer
            flag = 1,

            --- Prop held during the animation. false: none.
            --- `bone`: 28422 = right hand, 60309 = left hand.
            --- `offset` / `rotation` fine-tune where it sits in the hand.
            --- e.g. { model = 'prop_npc_phone_02', bone = 28422, offset = vec3(0.0, 0.0, 0.0), rotation = vec3(0.0, 0.0, 0.0) }
            --- @type { model: string, bone: integer, offset: vector3, rotation: vector3 } | false
            prop = false,

        },

        --- Runs when the pause screen opens.
        --- @type fun()
        onPauseOpened = function()
        end,

        --- Runs when the pause screen closes.
        --- @type fun()
        onPauseClosed = function()
        end,

    },

    -- ════════════════════════════════════════════════════════════════════════════════════════════
    -- 🗺️ 3D Map Blips
    -- ════════════════════════════════════════════════════════════════════════════════════════════

    threeDMap = {

        --- Enable the 3D map and its legend.
        --- @type boolean
        enabled = true,

        --- Create `nightreign_pausemenu_markers` / `nightreign_pausemenu_global_markers` when missing.
        --- Old `0r_pausemenu_*` tables are renamed to these automatically, keeping their blips.
        --- @type boolean
        autoDB = true,

        --- Markers farther than this from the camera are not drawn.
        --- @type number
        drawDistance = 2500.0,

        --- How often on-screen chips are projected while the map is open (ms).
        --- @type number
        interval = 50,

        --- Milliseconds a player must wait before creating another marker.
        --- @type number
        createCooldown = 30000,

        --- Maximum markers one player can own.
        --- Shared copies on other players do not count toward this.
        --- @type number
        maxMarkers = 16,

        --- Milliseconds a player must wait before sending another share request.
        --- @type number
        shareCooldown = 30000,

        --- Allow players to create personal 3D map blips.
        --- @type boolean
        playerCreator = true,

        --- Allow admins (ACE) to create global 3D / optional 2D blips.
        --- @type boolean
        adminCreator = true,

        --- ACE permission required for the global blip creator.
        --- @type string
        adminAce = 'nightreign_pausemenu.globalblips',

        --- Static categories. Not written to the database and cannot be deleted.
        --- Category: `id`, `label` (locale key or plain string).
        --- Each entry in category `blips` is one placed blip with a single `coords` vector3.
        --- Same label + sprite inside a category are merged in the legend as a cycle.
        --- `sprite` = FiveM blip sprite id. `color` = FiveM blip colour 0-85.
        --- Optional 2D: `showOn2d`, `scale`, `shortRange`.
        --- @type { id: string, label: string, blips: { label: string, sprite: number, coords: vector3, color?: number, showOn2d?: boolean, scale?: number, shortRange?: boolean }[] }[]
        categories = {
            {
                id = 'services',
                label = 'ui.map3d.services.label',
                blips = {
                    --[[ Shops ]]
                    { label = 'ui.map3d.services.shop',     sprite = 59,  color = 69, coords = vec3(25.7, -1347.3, 29.49) },
                    { label = 'ui.map3d.services.shop',     sprite = 59,  color = 69, coords = vec3(-3038.71, 585.9, 7.9) },
                    { label = 'ui.map3d.services.shop',     sprite = 59,  color = 69, coords = vec3(-3241.47, 1001.14, 12.83) },
                    { label = 'ui.map3d.services.shop',     sprite = 59,  color = 69, coords = vec3(1728.66, 6414.16, 35.03) },
                    { label = 'ui.map3d.services.shop',     sprite = 59,  color = 69, coords = vec3(1697.99, 4924.4, 42.06) },
                    { label = 'ui.map3d.services.shop',     sprite = 59,  color = 69, coords = vec3(1961.48, 3739.96, 32.34) },
                    { label = 'ui.map3d.services.shop',     sprite = 59,  color = 69, coords = vec3(547.79, 2671.79, 42.15) },
                    { label = 'ui.map3d.services.shop',     sprite = 59,  color = 69, coords = vec3(2679.25, 3280.12, 55.24) },
                    { label = 'ui.map3d.services.shop',     sprite = 59,  color = 69, coords = vec3(2557.94, 382.05, 108.62) },
                    { label = 'ui.map3d.services.shop',     sprite = 59,  color = 69, coords = vec3(373.55, 325.56, 103.56) },
                    --[[ Rob's Liquor Store ]]
                    { label = 'ui.map3d.services.rob',      sprite = 93,  color = 69, coords = vec3(1135.808, -982.281, 46.415) },
                    { label = 'ui.map3d.services.rob',      sprite = 93,  color = 69, coords = vec3(-1222.915, -906.983, 12.326) },
                    { label = 'ui.map3d.services.rob',      sprite = 93,  color = 69, coords = vec3(-1487.553, -379.107, 40.163) },
                    { label = 'ui.map3d.services.rob',      sprite = 93,  color = 69, coords = vec3(-2968.243, 390.910, 15.043) },
                    { label = 'ui.map3d.services.rob',      sprite = 93,  color = 69, coords = vec3(1166.024, 2708.930, 38.157) },
                    { label = 'ui.map3d.services.rob',      sprite = 93,  color = 69, coords = vec3(1392.562, 3604.684, 34.980) },
                    { label = 'ui.map3d.services.rob',      sprite = 93,  color = 69, coords = vec3(-1393.409, -606.624, 30.319) },
                    --[[ Gas Stations ]]
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(174.5, -1562.5, 29.3) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(265.6, -1261.3, 29.3) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(-526.0, -1211.0, 18.2) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(-70.2, -1761.8, 29.5) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(-724.6, -935.2, 19.2) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(-1437.6, -276.7, 46.2) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(-2096.2, -320.3, 13.2) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(-1799.8, 803.7, 138.7) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(620.8, 269.1, 103.1) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(1181.4, -330.8, 69.3) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(1208.9, -1402.6, 35.2) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(819.7, -1028.8, 26.4) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(-319.3, -1471.7, 30.5) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(2581.3, 362.0, 108.5) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(2005.1, 3773.9, 32.4) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(2679.9, 3264.0, 55.2) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(1039.9, 2671.1, 39.5) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(1687.2, 4929.4, 42.1) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(179.9, 6602.8, 31.9) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(-94.5, 6419.6, 31.5) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(1701.3, 6416.0, 32.8) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(-2554.9, 2334.4, 33.1) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(2539.7, 2594.2, 37.9) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(1207.3, 2660.2, 37.9) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(263.9, 2606.5, 45.0) },
                    { label = 'ui.map3d.services.gas',      sprite = 361, color = 6,  coords = vec3(49.4, 2778.8, 58.0) },
                    --[[ Clothing Stores ]]
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(1693.32, 4823.48, 41.06) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(-712.215881, -155.352982, 37.4151268) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(-1192.94495, -772.688965, 17.3255997) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(425.236, -806.008, 28.491) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(-162.658, -303.397, 38.733) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(75.950, -1392.891, 28.376) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(-822.194, -1074.134, 10.328) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(-1450.711, -236.83, 48.809) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(4.254, 6512.813, 30.877) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(615.180, 2762.933, 41.088) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(1196.785, 2709.558, 37.222) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(-3171.453, 1043.857, 19.863) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(-1100.959, 2710.211, 18.107) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(-1207.65, -1456.88, 4.378) },
                    { label = 'ui.map3d.services.clothing', sprite = 73,  color = 17, coords = vec3(121.76, -224.6, 53.56) },
                    --[[ Barber ]]
                    { label = 'ui.map3d.services.barber',   sprite = 71,  color = 0,  coords = vec3(-814.3, -183.8, 36.6) },
                    { label = 'ui.map3d.services.barber',   sprite = 71,  color = 0,  coords = vec3(136.8, -1708.4, 28.3) },
                    { label = 'ui.map3d.services.barber',   sprite = 71,  color = 0,  coords = vec3(-1282.6, -1116.8, 6.0) },
                    { label = 'ui.map3d.services.barber',   sprite = 71,  color = 0,  coords = vec3(1931.5, 3729.7, 31.8) },
                    { label = 'ui.map3d.services.barber',   sprite = 71,  color = 0,  coords = vec3(1212.8, -472.9, 65.2) },
                    { label = 'ui.map3d.services.barber',   sprite = 71,  color = 0,  coords = vec3(-32.9, -152.3, 56.1) },
                    { label = 'ui.map3d.services.barber',   sprite = 71,  color = 0,  coords = vec3(-278.1, 6228.5, 30.7) },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════════════════════════════════════════════
    -- 📷 3D Map Camera
    -- ════════════════════════════════════════════════════════════════════════════════════════════

    camera = {

        --- Metres above the player when the map camera opens.
        --- @type number
        startAt = 150.0,

        --- Minimum absolute world height (Z).
        --- @type number
        minHeight = 150.0,

        --- Maximum absolute world height (Z).
        --- @type number
        maxHeight = 675.0,

        --- Minimum height above the ground under the camera.
        --- @type number
        minHeightAboveGround = 50.0,

        --- Camera field of view.
        --- @type number
        fov = 72.5,

        --- How long the open/close rise takes (ms).
        --- @type number
        transitionMs = 800,

        --- Metres the camera slides per mouse pixel.
        --- @type number
        panSpeed = 0.185,

        --- How fast will rotate feel (degrees per mouse pixel).
        --- @type number
        rotateSpeed = 0.075,

        --- Metres per wheel (zoom) tick.
        --- @type number
        zoomStep = 24.0,

        --- Drag follow rate.
        --- @type number
        moveLerp = 8.0,

        --- Default look pitch.
        --- @type number
        pitch = -60.0,

        --- Highest look angle, toward the horizon.
        --- @type number
        minPitch = 75.0,

        --- Lowest look angle, toward straight down.
        --- @type number
        maxPitch = -75.0,

        --- How often will street data refresh on the UI (ms).
        --- @type number
        infoInterval = 500,

        --- How often will world streaming under the camera be updated (ms).
        --- @type number
        focusInterval = 1000,

        --- Full-screen fade duration when entering the map cam (ms).
        --- @type number
        fadeMs = 250,

        --- Fly duration multiplier.
        --- Duration (ms) is the flight distance in metres times this value.
        --- @type number
        flyDistanceScale = 0.5,

        --- Minimum fly duration (ms).
        --- @type number
        minFlyMs = 500.0,

        --- How long the look-down (top view) transition takes (ms).
        --- @type number
        lookDownMs = 750,

        --- Scripted → gameplay cam blend duration on close (ms).
        --- @type number
        blendMs = 750,

        --- While the 3D map is open, hide other players.
        --- @type boolean
        hideOtherPlayers = true,

        --- While the 3D map is open, hide other peds (including NPCs) locally.
        --- @type boolean
        hidePeds = true,

        --- While the 3D map is open, hide other vehicles locally.
        --- The vehicle the local player is in stays visible.
        --- @type boolean
        hideVehicles = true,

        --- How often the hide loop rescans ped/vehicle pools (ms).
        --- @type number
        hideRefreshMs = 200,

    },

}
