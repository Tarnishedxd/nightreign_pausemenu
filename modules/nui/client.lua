local cfg <const> = require 'config.main'

--[[ Send Vue messages shortcut ]]
SendVue = LT.NUI.Message

CreateThread(function()
    local __start = GetGameTimer()

    -- Wait for NUI to load
    local try = 0
    while not LT.NUI.IsLoaded() and try < 15 do
        try += 1
        Wait(1000)
    end

    -- If NUI is not loaded, error and return
    if not LT.NUI.IsLoaded() then
        error('NUI is not responding after ' .. GetGameTimer() - __start .. ' milliseconds.')
        return
    end

    -- Log success
    LT.Debug.Success('NUI mounted successfully in ^2%.2f^7 milliseconds.', (GetGameTimer() - __start))

    -- Send translations to NUI
    SendVue('UpdateLocale', {
        locale = cfg.locale,
        translations = GetLocaleTable()
    })
end)
