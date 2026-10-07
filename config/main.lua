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

        --- Hide the HUD and minimap while the pause menu is open (map, 3D map and settings
        --- included) and show them again when it closes. Does nothing when the HUD resource is
        --- not started.
        --- @type boolean
        hideWaisHud = true,

        --- How the HUD is hidden and shown again. `hud` is exports[resource].
        --- If something comes back the wrong way round, swap the calls here.
        waisHud = {

            --- @type string
            resource = 'wais-hudv6',

            --- Pause menu opened.
            --- @param hud table
            hide = function(hud)
                hud:showHud()       -- wais-hudv6: showHud() hides the HUD (the names are swapped)
                hud:showRadar(true) -- true hides the minimap
            end,

            --- Pause menu closed.
            --- @param hud table
            show = function(hud)
                hud:hideHud()        -- wais-hudv6: hideHud() shows the HUD again
                hud:showRadar(false) -- false shows the minimap
            end,

        },

        --- Premium points shown next to cash and bank in the pause header (read on the server).
        --- Optional: while the resource below is not started (whatever the start order, or during
        --- a restart) or does not have the export, the points are simply not shown and the menu
        --- works as usual. Read at most once every 5 seconds per player.
        premium = {

            --- @type boolean
            enabled = true,

            --- Resource with the server export that returns a player's premium points. A list
            --- tries each name in order and uses the first one that is started and has the export.
            --- @type string | string[]
            resource = { 'g-coin-shop', 'g-coinshop' },

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

        --- Show the blips the server's scripts put on the map (shops, jobs, garages...) with the
        --- same icons, colours and names as the GTA map. Names are read from the GTA map legend:
        --- when a blip's name was never seen, opening the 3D map reads it first (a second of
        --- black screen, once per new kind of blip; the names are kept between sessions).
        --- Blips a script keeps off the legend stay "Unnamed place".
        --- @type boolean
        serverBlips = true,

        --- Extra static categories. Not written to the database and cannot be deleted.
        --- Category: `id`, `label` (locale key or plain string).
        --- Each entry in category `blips` is one placed blip with a single `coords` vector3.
        --- Same label + sprite inside a category are merged in the legend as a cycle.
        --- `sprite` = FiveM blip sprite id. `color` = FiveM blip colour 0-85.
        --- Optional 2D: `showOn2d`, `scale`, `shortRange`.
        --- Example:
        --- { id = 'events', label = 'Events', blips = {
        ---     { label = 'Car meet', sprite = 225, color = 5, coords = vec3(-210.0, -1320.0, 30.9) },
        --- } },
        --- @type { id: string, label: string, blips: { label: string, sprite: number, coords: vector3, color?: number, showOn2d?: boolean, scale?: number, shortRange?: boolean }[] }[]
        categories = {},
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
