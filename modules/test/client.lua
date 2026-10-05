local cfg <const> = require 'config.main'

if cfg.debug < 4 then return end

RegisterCommand('key', function(source, args, raw)
    local keyControls = {
        ['right'] = 190,
        ['left'] = 189,
        ['up'] = 191,
        ['down'] = 192,
        ['enter'] = 20,
        ['escape'] = 21,
        ['backspace'] = 199,
    }
    local presses = tonumber(args[2]) or 1
    local wait = tonumber(args[3]) or 0
    local control = keyControls[args[1]]
    if not control then return LT.Debug.Error('Invalid key') end
    ReleaseControlOfFrontend()
    Wait(wait)
    for _ = 1, presses do
        EnableControlAction(0, control, true)
        EnableControlAction(2, control, true)
        SetInputExclusive(2, control)
        SetControlNormal(0, control, 1.0)
        SetControlNormal(2, control, 1.0)
        Wait(0)
    end
    Wait(wait)
    TakeControlOfFrontend()
end)
