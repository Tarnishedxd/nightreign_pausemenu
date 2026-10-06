local cfg <const> = require 'config.main'

--[[ Client start time ]]
local __start = GetGameTimer()

---@class ClientClass
---@field new fun(self): self
---@field state table
---@field sync fun(self: ClientClass)
---@field update fun(self: ClientClass, data: table)
---@field __init fun(self: ClientClass)
local ClientClass = {}
ClientClass.__index = ClientClass

--- Creates a new client instance.
--- @return ClientClass
function ClientClass:new()
    local self = setmetatable({}, ClientClass)

    self.state = LT.NUI.CreateState('UpdatePlayer', {
        source = cache.serverId,
        name = '',
        serverName = cfg.pause.serverName,
        cash = 0,
        bank = 0,
        premium = -1,
        players = 0,
        maxPlayers = GetConvarInt('sv_maxclients', 48),
        currency = cfg.currency,
        currencyFormat = cfg.currencyFormat,
        enable3DMap = cfg.threeDMap and cfg.threeDMap.enabled == true,
        showBranding = cfg.pause.showBranding ~= false,
        showStats = cfg.pause.showStats == true,
        showPlayerCount = cfg.pause.showPlayerCount == true,
    })

    -- Initialize the client.
    self:__init()

    return self
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- STATE MANAGEMENT
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- Syncs the client state.
function ClientClass:sync()
    self.state:sync()
end

--- Updates the client state.
--- @param data table Data to update.
function ClientClass:update(data)
    self.state:update(data)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- LIFECYCLE
-- ════════════════════════════════════════════════════════════════════════════════════════════

--- Initializes the client.
function ClientClass:__init()
    self:sync()

    LT.Debug.Success('Client initialized in ^2%.2f^7 milliseconds.', (GetGameTimer() - __start))
end

--[[ Client instance ]]
_G.Client = nil

LT.OnPlayerLoad(function()
    _G.Client = ClientClass:new()
end)
