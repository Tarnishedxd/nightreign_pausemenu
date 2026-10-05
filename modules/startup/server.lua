local resourceName <const> = GetCurrentResourceName()

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- STARTUP CHECKS
-- Files that, when missing, only show up in game as a menu that never opens.
-- ════════════════════════════════════════════════════════════════════════════════════════════

local requiredFiles <const> = {
    { path = 'web/build/index.html', hint = 'the pause menu UI cannot load. Use the full release or run: cd web && npm install && npm run build' },
    { path = 'stream/pause_menu_sp_content.gfx', hint = 'the settings page and the map need the patched GFX files in stream/' },
    { path = 'stream/pause_menu_header.gfx', hint = 'the settings page and the map need the patched GFX files in stream/' },
    { path = 'stream/pause_menu_instructional_buttons.gfx', hint = 'the settings page and the map need the patched GFX files in stream/' },
    { path = 'stream/popup_warning.gfx', hint = 'game popups in the settings page need the patched GFX files in stream/' },
}

CreateThread(function()
    for i = 1, #requiredFiles do
        local file = requiredFiles[i]
        if not LoadResourceFile(resourceName, file.path) then
            LT.Debug.Error('%s is missing: %s', file.path, file.hint)
        end
    end
end)
