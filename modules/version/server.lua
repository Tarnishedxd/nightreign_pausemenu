local cfg <const> = require 'config.main'

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- CHECK VERSION
-- ════════════════════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    if not cfg.checkVersion then return end
    Wait(1000)
    LT.Version.Check({
        url = 'https://raw.githubusercontent.com/laot7490/laot-versions/refs/heads/master/check.json',
        downloadUrl = 'https://portal.cfx.re/assets/granted-assets'
    })
end)
