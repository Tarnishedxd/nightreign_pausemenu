local DEFAULT_RETURN_TIMEOUT <const> = 1000

Scaleform = {}

--- @param value any
--- @return boolean|nil
function Scaleform.asBool(value)
    if value == true or value == 'true' then return true end
    if value == false or value == 'false' then return false end
end

--- @param value string|nil
--- @param separator string
--- @return string[]
function Scaleform.split(value, separator)
    local values = {}
    for part in ((value or '') .. separator):gmatch('(.-)' .. separator) do
        values[#values + 1] = part
    end
    return values
end

--- @param raw string|nil
--- @return integer
function Scaleform.rowCount(raw)
    if not raw or raw == '' then return 0 end
    local count = 0
    for segment in (raw .. '##'):gmatch('(.-)##') do
        if segment ~= '' then count += 1 end
    end
    return count
end

--- @param values any[]
function Scaleform.addParams(values)
    for index = 1, #values do
        local value = values[index]
        if type(value) == 'boolean' then
            ScaleformMovieMethodAddParamBool(value)
        elseif type(value) == 'number' then
            ScaleformMovieMethodAddParamInt(value)
        elseif type(value) == 'string' then
            ScaleformMovieMethodAddParamPlayerNameString(value)
        end
    end
end

---@param handle integer|nil
---@param kind 'int'|'string'
---@param timeout integer|nil
---@return string|integer|nil
function Scaleform.awaitReturn(handle, kind, timeout)
    if not handle then return nil end
    local deadline = GetGameTimer() + (timeout or DEFAULT_RETURN_TIMEOUT)
    while not IsScaleformMovieMethodReturnValueReady(handle) and GetGameTimer() < deadline do
        Wait(0)
    end
    if not IsScaleformMovieMethodReturnValueReady(handle) then return nil end
    if kind == 'string' then
        return GetScaleformMovieMethodReturnValueString(handle)
    end
    return GetScaleformMovieMethodReturnValueInt(handle)
end
