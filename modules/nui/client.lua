--[[ Send Vue messages shortcut ]]
SendVue = LT.NUI.Message

CreateThread(function()
    local __start = GetGameTimer()
    local warned = false

    -- Wait for NUI to load. Ping the page so it re-sends its ready signal
    -- in case the first one arrived before this script registered the callback.
    while not LT.NUI.IsLoaded() do
        SendNUIMessage({ action = 'ltbridge_check_nui' })
        if not warned and GetGameTimer() - __start >= 15000 then
            warned = true
            LT.Debug.Error('NUI is not responding after %d milliseconds, still waiting. Check that web/build exists and the F8 console for NUI errors.', GetGameTimer() - __start)
        end
        Wait(500)
    end

    -- Log success
    LT.Debug.Success('NUI mounted successfully in ^2%.2f^7 milliseconds.', (GetGameTimer() - __start))

    -- Send translations to NUI
    SendVue('UpdateLocale', {
        locale = ActiveLocale,
        translations = GetLocaleTable()
    })
end)
