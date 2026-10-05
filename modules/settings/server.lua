local resourceName <const> = GetCurrentResourceName()
local cfg <const> = require 'config.main'

local function sanitizeLabel(label)
    local safe = tostring(label or 'category'):gsub('%s+', '_'):gsub('[^%w%-_]', '')
    if safe == '' then safe = 'category' end
    return safe
end

register('settings:writeDump', function(payload)
    if cfg.debug < 4 then return end
    if type(payload) ~= 'table' then return end
    local catIndex = math.floor(tonumber(payload.index) or 0)
    local safeLabel = sanitizeLabel(payload.label)
    local prefix = ('logs/%02d_%s'):format(catIndex, safeLabel)

    local raw = payload.raw
    if type(raw) == 'string' and raw ~= '' then
        local ok = SaveResourceFile(resourceName, prefix .. '_raw.txt', raw, #raw)
        if not ok then
            LT.Debug.Error('failed to write %s_raw.txt', prefix)
        end
    end

    local parsed = payload.parsed
    if type(parsed) == 'string' and parsed ~= '' then
        local ok = SaveResourceFile(resourceName, prefix .. '_parsed.json', parsed, #parsed)
        if not ok then
            LT.Debug.Error('failed to write %s_parsed.json', prefix)
        else
            LT.Debug.Info('wrote settings dump %s ({raw,parsed})', prefix)
        end
    end
end)
