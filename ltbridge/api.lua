--- @meta
--- LT Bridge API Reference
--- Auto-generated stub file for IDE intellisense.
--- Do NOT include this file in your fxmanifest.
--- For more information: https://github.com/laot7490/ltbridge

LT = LT or {}
LT.Alert = LT.Alert or {}
LT.Blip = LT.Blip or {}
LT.Cache = LT.Cache or {}
LT.Callback = LT.Callback or {}
LT.Class = LT.Class or {}
LT.Cooldown = LT.Cooldown or {}
LT.Debug = LT.Debug or {}
LT.Dispatch = LT.Dispatch or {}
LT.Events = LT.Events or {}
LT.Framework = LT.Framework or {}
LT.Fuel = LT.Fuel or {}
LT.Helpers = LT.Helpers or {}
LT.Hooks = LT.Hooks or {}
LT.Input = LT.Input or {}
LT.Inventory = LT.Inventory or {}
LT.LoadUnload = LT.LoadUnload or {}
LT.Locale = LT.Locale or {}
LT.Logger = LT.Logger or {}
LT.Math = LT.Math or {}
LT.Menu = LT.Menu or {}
LT.NUI = LT.NUI or {}
LT.Notify = LT.Notify or {}
LT.Phone = LT.Phone or {}
LT.Progress = LT.Progress or {}
LT.State = LT.State or {}
LT.Streaming = LT.Streaming or {}
LT.String = LT.String or {}
LT.Table = LT.Table or {}
LT.Target = LT.Target or {}
LT.TextUI = LT.TextUI or {}
LT.Utils = LT.Utils or {}
LT.VehicleKeys = LT.VehicleKeys or {}
LT.Version = LT.Version or {}

---@class BlipProperties
---@field label string Label of the blip
---@field coords? vector3 Coordinates of the blip
---@field entity? number Entity of the blip
---@field sprite? number Sprite of the blip
---@field color? number Color of the blip
---@field scale? number Scale of the blip
---@field shortRange? boolean|nil Whether the blip is a short range blip (default: true)
---@field display? number Display mode of the blip (default: 2)
---@field rotation? number Rotation of the blip
---@field alpha? number Alpha of the blip (default: 255)
---@field highDetail? boolean Whether the blip is a high detail blip (default: false)
---@field route? boolean Whether the blip is a route blip (default: false)
---@field routeColor? number Route color of the blip
---@field bright? boolean Whether the blip is a bright blip (default: false)
---@field flash? boolean Whether the blip is flashing (default: false)
---@field flashInterval? number Flash interval of the blip (default: 500ms)
---@field delete? fun(self: self) Delete the blip

--- @class Cache
--- @field ped number Entity ID of current player ped
--- @field playerId number Player ID
--- @field serverId number Server ID of current player
--- @field vehicle number|false Entity ID of current vehicle or false
--- @field seat number|false Seat index or false
--- @field weapon number|false Weapon hash or false
--- @field coords vector3 Current coordinates updated every 500ms
--- @field isDead boolean True if player is dead

--- **`ALERT` `CLIENT`**
--- Returns alert resource name.
--- @return 'ox_lib'|'lt-ui'|'lation_ui'|nil
function LT.Alert.GetResource() end

--- **`ALERT` `CLIENT`**
--- Force set alert resource.
--- Useful for config assignment.
--- @param name 'ox_lib'|'lt-ui'|'lation_ui'
function LT.Alert.SetResource(name) end

--- **`ALERT` `CLIENT`**
--- Send alert dialog to player.
--- @param data table { header: string, content: string, centered: boolean, size = 'xs'|'sm'|'md'|'lg'|'xl', cancel: boolean, labels: { cancel: string, confirm: string } }
--- ```lua
--- LT.Alert.Send({
---     header = 'Alert',
---     content = 'Alert',
---     centered = true,
---     size = 'md',
---     cancel = true,
---     labels = { cancel = 'Cancel', confirm = 'Confirm' }
--- })
--- ```
--- @return 'cancel'|'confirm'|nil
function LT.Alert.Send(data) end

--- **`BLIP` `CLIENT`**
--- Creates a new blip.
--- @param data BlipProperties Blip data
--- @return table|boolean Blip handler or false if failed
function LT.Blip.Create(data) end

--- **`BLIP` `CLIENT`**
--- Gets all blips.
--- @return table Blips
function LT.Blip.GetAll() end

--- **`BLIP` `CLIENT`**
--- Deletes all blips.
function LT.Blip.DeleteAll() end

--- **`CACHE` `CLIENT`**
--- Get a specific cache value or the whole table.
--- @param key? 'ped'|'vehicle'|'seat'|'weapon'|'coords'|'isDead'|'playerId'|'serverId'
--- @return any
function LT.Cache.Get(key) end

--- **`CACHE` `CLIENT`**
--- Listen for changes in cache values.
--- ```lua
--- LT.Cache.OnChange('vehicle', function(vehicle, oldVehicle)
---     print('Vehicle state changed', vehicle)
--- end)
--- ```
--- @param key string The cache key to listen for ('vehicle', 'seat', 'weapon', 'isDead')
--- @param cb fun(newValue: any, oldValue: any)
function LT.Cache.OnChange(key, cb) end

--- **`CALLBACK` `CLIENT`**
--- Register a client-side callback that the server can invoke.
--- @param name string Callback name
--- @param cb fun(...: any): ...any
function LT.Callback.Register(name, cb) end

--- **`CALLBACK` `CLIENT`**
--- Await a server callback synchronously (yields current thread).
--- ```lua
--- local money = LT.Callback.Await('getMoney', 'cash')
--- print(money)
--- ```
--- @param name string Callback name
--- @param ... any Arguments to send
--- @return any ...
function LT.Callback.Await(name, ...) end

--- **`CALLBACK` `CLIENT`**
--- Trigger a server callback asynchronously (non-blocking).
--- ```lua
--- LT.Callback.Trigger('getMoney', function(money)
---     print(money)
--- end, 'cash')
--- ```
--- @param name string Callback name
--- @param cb fun(...: any)
--- @param ... any Arguments to send
function LT.Callback.Trigger(name, cb, ...) end

--- **`CALLBACK` `SERVER`**
--- Register a server-side callback that clients can invoke.
--- @param name string Callback name
--- @param cb fun(source: number, ...: any): ...any
function LT.Callback.Register(name, cb) end

--- **`CALLBACK` `SERVER`**
--- Await a client callback synchronously (yields current thread).
--- ```lua
--- local result = LT.Callback.Await(source, 'getScreenData')
--- print(result)
--- ```
--- @param playerId number Player source
--- @param name string Callback name
--- @param ... any Arguments to send
--- @return any ...
function LT.Callback.Await(playerId, name, ...) end

--- **`CALLBACK` `SERVER`**
--- Trigger a client callback asynchronously (non-blocking).
--- ```lua
--- LT.Callback.Trigger(source, 'getScreenData', function(result)
---     print(result)
--- end)
--- ```
--- @param playerId number Player source
--- @param name string Callback name
--- @param cb fun(...: any)
--- @param ... any Arguments to send
function LT.Callback.Trigger(playerId, name, cb, ...) end

--- **`CLASS` `SHARED`**
--- Creates a new OOP class.
--- @param name string Class name.
--- @param super? table Parent class to inherit from.
--- @return table
function LT.Class.Create(name, super) end

--- **`COOLDOWN` `SERVER`**
--- Start a cooldown for a specific identifier and key.
--- ```lua
--- local citizenId = LT.Framework.GetPlayerCitizenId(source)
--- LT.Cooldown.Start(citizenId, 'gather', 5000) -- 5 seconds
--- ```
--- @param identifier string|number Cooldown identifier (like player citizenid)
--- @param key string Cooldown identifier
--- @param duration number Cooldown duration in milliseconds
function LT.Cooldown.Start(identifier, key, duration) end

--- **`COOLDOWN` `SERVER`**
--- Check if a specific cooldown is active.
--- ```lua
--- local citizenId = LT.Framework.GetPlayerCitizenId(source)
--- if LT.Cooldown.Check(citizenId, 'gather') then return end
--- ```
--- @param identifier string|number Cooldown identifier (like player citizenid)
--- @param key string Cooldown identifier
--- @return boolean
function LT.Cooldown.Check(identifier, key) end

--- **`COOLDOWN` `SERVER`**
--- Get remaining cooldown time in milliseconds.
--- @param identifier string|number Cooldown identifier (like player citizenid)
--- @param key string Cooldown identifier
--- @return number remainingMs
function LT.Cooldown.Remaining(identifier, key) end

--- **`COOLDOWN` `SERVER`**
--- Clear a specific cooldown early.
--- @param identifier string|number Cooldown identifier (like player citizenid)
--- @param key string Cooldown identifier
function LT.Cooldown.Clear(identifier, key) end

--- **`DEBUG` `SHARED`**
--- Set debug mode.
---
--- **0**: `Disabled` (Not Recommended)
---
--- **1**: `Errors` (Default)
---
--- **2**: `Errors + Warnings`
---
--- **3**: `Except Verbose`
---
--- **4**: `All Messages`
---
--- @param mode? number
function LT.Debug.SetMode(mode) end

--- **`DEBUG` `SHARED`**
--- Prints a formatted and detailed (with file and line info) debug message.
--- @param message string Message to print.
--- @param type? 'info'|'success'|'error'|'warning'|'verbose'
--- @param ...? any Format parameters.
function LT.Debug.Detailed(message, type, ...) end

--- **`DEBUG` `SHARED`**
--- Prints a formatted debug message.
--- @param message string Message to print.
--- @param type? 'info'|'success'|'error'|'warning'|'verbose'
--- @param ...? any Format parameters.
function LT.Debug.Print(message, type, ...) end

--- **`DEBUG` `SHARED`**
--- Send a info debug mesage.
--- @param message string Message to print.
--- @param ...? any Format parameters.
function LT.Debug.Info(message, ...) end

--- **`DEBUG` `SHARED`**
--- Send a success debug mesage.
--- @param message string Message to print.
--- @param ...? any Format parameters.
function LT.Debug.Success(message, ...) end

--- **`DEBUG` `SHARED`**
--- Send a error debug mesage.
--- @param message string Message to print.
--- @param ...? any Format parameters.
function LT.Debug.Error(message, ...) end

--- **`DEBUG` `SHARED`**
--- Send a warning debug mesage.
--- @param message string Message to print.
--- @param ...? any Format parameters.
function LT.Debug.Warn(message, ...) end

--- **`DEBUG` `SHARED`**
--- Send a verbose debug mesage.
--- @param message string Message to print.
--- @param ...? any Format parameters.
function LT.Debug.Verbose(message, ...) end

--- **`DISPATCH` `CLIENT`**
--- Returns dispatch resource name.
--- @return 'ps-dispatch'|'cd_dispatch'|'tk_dispatch'|'qs-dispatch'|'emergencydispatch'|'wasabi_mdt'|'linden_outlawalert'|nil
function LT.Dispatch.GetResource() end

--- **`DISPATCH` `CLIENT`**
--- Force set dispatch resource.
--- Useful for config assignment.
--- @param name 'ps-dispatch'|'cd_dispatch'|'tk_dispatch'|'qs-dispatch'|'emergencydispatch'|'wasabi_mdt'|'linden_outlawalert'
function LT.Dispatch.SetResource(name) end

--- **`DISPATCH` `CLIENT`**
--- Send dispatch alert to given jobs.
--- @param data table Dispatch data
function LT.Dispatch.Send(data) end

--- **`EVENTS` `SHARED`**
--- Triggers local event with formatted name.
--- **Lua Example:**
--- ```lua
--- local emit = LT.Events.Emit
---
--- -- Client example:
--- emit('event', 'arg1', 'arg2')
--- ```
--- @param name string Event name
--- @param ...? any Event arguments (Optional)
function LT.Events.Emit(name, ...) end

--- **`EVENTS` `SHARED`**
--- Triggers network event with formatted name.
---
--- `Client` -> `Server`
---
--- `Server` -> `Client`
---
--- **Lua Example:**
--- ```lua
--- local emitNet = LT.Events.EmitNet
---
--- -- Client example:
--- emitNet('exampleEvent', 'arg1', 'arg2')
--- -- Turns into:
--- TriggerServerEvent('resourcename:server:exampleEvent', 'arg1', 'arg2')
---
--- -- Server example:
--- emitNet('exampleEvent', source, 'arg1', 'arg2')
--- -- Turns into:
--- TriggerClientEvent('resourcename:client:exampleEvent', source, 'arg1', 'arg2')
--- ```
--- @param name string Event name
--- @param ...? any Event arguments (Optional)
function LT.Events.EmitNet(name, ...) end

--- **`EVENTS` `SHARED`**
--- Register a event with formatted name.
--- **Lua Example:**
--- ```lua
--- local register = LT.Events.Register
---
--- -- Client example:
--- register('event', function(arg1, arg2)
---     print(arg1, arg2)
--- end)
---
--- -- Server example:
--- register('event', function(arg1, arg2)
---     local src = source
---     print(src, arg1, arg2)
--- end)
--- ```
--- @param name string Event name.
--- @param cb? function Callback function.
function LT.Events.Register(name, cb) end

--- **`FRAMEWORK` `SERVER`**
--- This will return the jobs registered in the framework in a table.
--- @return table<number, { name: string, label: string, grades: table<string, {name: string, label: string, grade: number }>}>
function LT.Framework.GetFrameworkJobs() end

--- **`FRAMEWORK` `CLIENT`**
--- Returns player job data.
--- @return table<{name: string, label: string, grade: number, gradeName: string, gradeLabel: string, isBoss: boolean, onDuty: boolean}>|nil
function LT.Framework.GetPlayerJobData() end

--- **`FRAMEWORK` `SERVER`**
--- Returns player job data.
--- @param source number Player source
--- @return table<{name: string, label: string, grade: number, gradeName: string, gradeLabel: string, isBoss: boolean, onDuty: boolean}>|nil
function LT.Framework.GetPlayerJobData(source) end

--- **`FRAMEWORK` `SERVER`**
--- Set player job to given job and grade.
--- @param source number Player source
--- @param name string Job name
--- @param grade number Job grade
--- @return boolean
function LT.Framework.SetPlayerJob(source, name, grade) end

--- **`FRAMEWORK` `SERVER`**
--- Add money to player account.
--- @param source number Player source
--- @param account? string Money type (default: cash) (cash, bank, black_money, crypto etc.)
--- @param amount number Amount to add
--- @return boolean
function LT.Framework.AddMoney(source, account, amount) end

--- **`FRAMEWORK` `SERVER`**
--- Returns players money on account.
--- @param source number Player source
--- @param account? string Money type (default: cash) (cash, bank, black_money, crypto etc.)
--- @return number amount
function LT.Framework.GetMoney(source, account) end

--- **`FRAMEWORK` `SERVER`**
--- Removes money from player account.
--- @param source number Player source
--- @param account? string Money type (default: cash) (cash, bank, black_money, crypto etc.)
--- @param amount number Amount to add
--- @return boolean `true` if success, `false` if anything goes wrong or player does not have that much money on account.
function LT.Framework.RemoveMoney(source, account, amount) end

--- **`FRAMEWORK` `SERVER`**
--- Add hunger to player.
--- @param source number Player source
--- @param value number Amount to add
--- @return boolean
function LT.Framework.AddHunger(source, value) end

--- **`FRAMEWORK` `SERVER`**
--- Add thirst to player.
--- @param source number Player source
--- @param value number Amount to add
--- @return boolean
function LT.Framework.AddThirst(source, value) end

--- **`FRAMEWORK` `CLIENT`**
--- Returns player hunger
--- @return number
function LT.Framework.GetHunger() end

--- **`FRAMEWORK` `SERVER`**
--- Returns player hunger
--- @param source number Player source
--- @return number
function LT.Framework.GetHunger(source) end

--- **`FRAMEWORK` `CLIENT`**
--- Returns player metadata of the given key.
--- @param key string Metadata key
--- @return any
function LT.Framework.GetPlayerMetadata(key) end

--- **`FRAMEWORK` `SERVER`**
--- Returns player metadata of the given key.
--- @param source number Player source
--- @param key string Metadata key
--- @return any
function LT.Framework.GetPlayerMetadata(source, key) end

--- **`FRAMEWORK` `CLIENT`**
--- Returns player thirst
--- @return number
function LT.Framework.GetThirst() end

--- **`FRAMEWORK` `SERVER`**
--- Returns player thirst
--- @param source number Player source
--- @return number
function LT.Framework.GetThirst(source) end

--- **`FRAMEWORK` `CLIENT`**
--- Returns true if the player is dead, false otherwise.
--- @return boolean
function LT.Framework.IsPlayerDead() end

--- **`FRAMEWORK` `SERVER`**
--- Returns true if the player is dead, false otherwise.
--- @param source number Player source
--- @return boolean
function LT.Framework.IsPlayerDead(source) end

--- **`FRAMEWORK` `CLIENT`**
--- Returns true if player loaded, false otherwise.
--- @return boolean
function LT.Framework.IsPlayerLoaded() end

--- **`FRAMEWORK` `SERVER`**
--- Sets player metadata for the given key.
--- @param source number Player source
--- @param key string Metadata key
--- @param value table | string | number | boolean Value to assign
function LT.Framework.SetPlayerMetadata(source, key, value) end

--- **`FRAMEWORK` `SERVER`**
--- Returns players owned vehicles.
--- @param source number Player source
--- @return table { vehicle, plate }
function LT.Framework.GetOwnedVehicles(source) end

--- **`FRAMEWORK` `SERVER`**
--- Check if a vehicle owned by player. Returns vehicle data if owned by player, false otherwise.
--- @param source number Player source
--- @param plate string Vehicle plate
--- @return table|boolean {id = id, vehicle = model, plate = plate}
function LT.Framework.IsVehicleOwnedByPlayer(source, plate) end

--- **`FRAMEWORK` `SERVER`**
--- Returns player object of framework default.
--- @param source number Player source
--- @return table|nil
function LT.Framework.GetPlayer(source) end

--- **`FRAMEWORK` `CLIENT`**
--- Returns player date of birth.
--- @return string|nil
function LT.Framework.GetPlayerBirthdate() end

--- **`FRAMEWORK` `SERVER`**
--- Returns player date of birth.
--- @param source number Player source
--- @return string|nil
function LT.Framework.GetPlayerBirthdate(source) end

--- **`FRAMEWORK` `SERVER`**
--- Returns player object by identifier|citizenid.
--- @param citizenid string Player identifier|citizenid
--- @return table|nil Player or nil
function LT.Framework.GetPlayerByCitizenId(citizenid) end

--- **`FRAMEWORK` `CLIENT`**
--- Returns player citizenid | identifier.
--- @return string|nil
function LT.Framework.GetPlayerCitizenId() end

--- **`FRAMEWORK` `SERVER`**
--- Returns player citizenid | identifier from source.
--- @param source number Player source
--- @return string|nil
function LT.Framework.GetPlayerCitizenId(source) end

--- **`FRAMEWORK` `CLIENT`**
--- Returns player data in the framework default format.
--- @return table|nil PlayerData
function LT.Framework.GetPlayerData() end

--- **`FRAMEWORK` `CLIENT`**
--- Returns player character name.
--- @param asFullName? boolean Whether to return the full name or just the first name (Default: false)
--- @return string? Firstname (or full name if `asFullName` is true)
--- @return string? Lastname (or `nil` if `asFullName` is true)
function LT.Framework.GetPlayerName(asFullName) end

--- **`FRAMEWORK` `SERVER`**
--- @param source number Player source
--- @param asFullName? boolean Whether to return the full name or just the first name (Default: false)
--- @return string? Firstname (or full name if `asFullName` is true)
--- @return string? Lastname (or `nil` if `asFullName` is true)
function LT.Framework.GetPlayerName(source, asFullName) end

--- **`FRAMEWORK` `SERVER`**
--- Returns players phone number.
--- @param source number Player source
--- @return string|nil
function LT.Framework.GetPlayerPhoneNumber(source) end

--- **`FRAMEWORK` `SERVER`**
--- Returns all connected players.
--- @return table
function LT.Framework.GetPlayers() end

--- **`FRAMEWORK` `SERVER`**
--- Returns player source from citizen id | identifier.
---@param citizenid string Player citizen id | identifier.
---@return number|nil
function LT.Framework.GetPlayerSourceByCitizenId(citizenid) end

--- **`FRAMEWORK` `SERVER`**
--- Returns true if player is admin, false otherwise.
--- @param source number Player source
--- @return boolean
function LT.Framework.IsFrameworkAdmin(source) end

--- **`FRAMEWORK` `SERVER`**
--- Register usable item on framework default format.
--- @param name string Item name
--- @param cb fun(source: number, item?: table)
function LT.Framework.RegisterUsableItem(name, cb) end

--- **`FRAMEWORK` `SHARED`**
--- Returns framework name.
--- @return 'es_extended'|'qb-core'|'qbx_core'|nil
function LT.Framework.GetResource() end

--- **`FUEL` `CLIENT`**
--- Get fuel percentage of vehicle.
--- @param vehicle number Vehicle entity.
--- @return number Fuel
function LT.Fuel.GetFuel(vehicle) end

--- **`FUEL` `CLIENT`**
--- Set fuel percentage of vehicle.
--- @param vehicle number Vehicle entity.
--- @param fuel number Fuel level to assign.
function LT.Fuel.SetFuel(vehicle, fuel) end

--- **`FUEL` `CLIENT`**
--- Returns fuel resource name.
--- @return 'ox_fuel'|'lt-fuel'|'LegacyFuel'|'qb-fuel'|'qs-fuelstations'|'cdn-fuel'|'x-fuel'|'okokGasStation'|'esx-sna-fuel'|'ps-fuel'|'BigDaddy-Fuel'|'Renewed-Fuel'|'lc_fuel'|nil
function LT.Fuel.GetResource() end

--- **`FUEL` `CLIENT`**
--- Force set fuel resource.
--- Useful for config assignment.
--- @param name 'ox_fuel'|'lt-fuel'|'LegacyFuel'|'qb-fuel'|'qs-fuelstations'|'cdn-fuel'|'x-fuel'|'okokGasStation'|'esx-sna-fuel'|'ps-fuel'|'BigDaddy-Fuel'|'Renewed-Fuel'|'lc_fuel'
function LT.Fuel.SetResource(name) end

--- **`HOOKS` `SHARED`**
--- Execute a callback when a resource starts.
--- @param cb fun()
--- @param resource? string Defaults to the current resource name.
--- ```lua
--- LT.Hooks.Start(function()
---     print("Resource started.")
--- end)
--- ```
function LT.Hooks.Start(cb, resource) end

--- **`HOOKS` `SHARED`**
--- Execute a callback when a resource stops.
--- @param cb fun()
--- @param resource? string Defaults to the current resource name.
--- ```lua
--- LT.Hooks.Stop(function()
---     print("Resource stopped.")
--- end)
--- ```
function LT.Hooks.Stop(cb, resource) end

--- **`INPUT` `CLIENT`**
--- Returns input resource name.
--- @return 'ox_lib'|'lt-ui'|'qb-input'|'lation_ui'|nil
function LT.Input.GetResource() end

--- **`INPUT` `CLIENT`**
--- Force set input resource.
--- Useful for config assignment.
--- @param name 'ox_lib'|'lt-ui'|'qb-input'|'lation_ui'
function LT.Input.SetResource(name) end

--- **`INPUT` `CLIENT`**
--- Opens a input dialog.
--- @param header string Title of input dialog
--- @param data table Data table (`{ inputs = ... }` for QB; ox field array or `{ inputs = ... }` otherwise)
--- @param isQB? boolean If data table is sent with QB format set to true, default: false
--- @param submitText? string Submit button text, only for `qb-input`
--- @return table|nil
function LT.Input.Open(header, data, isQB, submitText) end

--- **`INVENTORY` `SERVER`**
--- Add item to player.
--- @param source number Player source
--- @param item string Item name
--- @param count? number Item count (default: 1)
--- @param slot? number Item slot (optional)
--- @param metadata? table Item metadata (optional)
--- @return boolean
function LT.Inventory.AddItem(source, item, count, slot, metadata) end

--- **`INVENTORY` `SERVER`**
--- Check if player can carry item.
--- @param source number Player source
--- @param item string Item name
--- @param count? number Item count (default: 1)
--- @return boolean
function LT.Inventory.CanCarryItem(source, item, count) end

--- **`INVENTORY` `SERVER`**
--- Returns the specified slot item data as a table.
--- @param source number Player source
--- @param slot number Slot to search
--- @return table|nil {name, label, count, slot, weight, metadata, stack, description}
function LT.Inventory.GetItemBySlot(source, slot) end

--- **`INVENTORY` `CLIENT`**
--- Returns count of items on players inventory. If there is none returns 0.
--- @param item string Item name
--- @param metadata? any Metadata (optional)
--- @return number
function LT.Inventory.GetItemCount(item, metadata) end

--- **`INVENTORY` `SERVER`**
--- Returns count of items on players inventory. If there is none returns 0.
--- @param source number Player source
--- @param item string Item name
--- @param metadata? any Metadata (optional)
--- @return number
function LT.Inventory.GetItemCount(source, item, metadata) end

--- **`INVENTORY` `SERVER`**
--- Returns item image path.
--- @param item string Item name
--- @return string|nil
function LT.Inventory.GetItemImage(item) end

--- **`INVENTORY` `SERVER`**
--- Returns item info as a table.
--- @param item string Item name
--- @return table|nil {name, label, stack, weight, description, image}
function LT.Inventory.GetItemInfo(item) end

--- **`INVENTORY` `SERVER`**
--- Returns player inventory as table.
--- @param source number Player source
--- @return table {name,label?,weight?,description?,count,slot,metadata}
function LT.Inventory.GetPlayerInventory(source) end

--- **`INVENTORY` `CLIENT`**
--- Check if player has item.
--- @param item string Item name
--- @param count? number Required count (default: 1)
--- @return boolean
function LT.Inventory.HasItem(item, count) end

--- **`INVENTORY` `SERVER`**
--- Check if player has item.
--- @param source number Player source
--- @param item string Item name
--- @param count? number Required count (optional)
--- @return boolean
function LT.Inventory.HasItem(source, item, count) end

--- **`INVENTORY` `SERVER`**
--- Remove item from player.
--- @param source number Player source
--- @param item string Item name
--- @param count? number Item count (default: 1)
--- @param slot? number Item slot (optional)
--- @param metadata? table Item metadata (optional)
--- @return boolean
function LT.Inventory.RemoveItem(source, item, count, slot, metadata) end

--- **`INVENTORY` `SERVER`**
--- Set/change metadata of item.
--- @param source number Player source
--- @param item string Item name
--- @param slot number Item slot
--- @param metadata any New metadata
function LT.Inventory.SetItemMetadata(source, item, slot, metadata) end

--- **`INVENTORY` `SHARED`**
--- Returns inventory resource name.
--- @return 'ox_inventory'|'qs-inventory'|'qb-inventory'|'tgiann-inventory'|'origen_inventory'|'one_inventory'|nil
function LT.Inventory.GetResource() end

--- **`INVENTORY` `SHARED`**
--- Force set inventory resource.
--- @param name 'ox_inventory'|'qs-inventory'|'qb-inventory'|'tgiann-inventory'|'origen_inventory'|'one_inventory'
function LT.Inventory.SetResource(name) end

--- **`LOADUNLOAD` `CLIENT`**
--- Execute a callback when a player loads.
--- @param cb fun()
--- ```lua
--- LT.OnPlayerLoad(function()
---     print("Player loaded.")
--- end)
--- ```
function LT.OnPlayerLoad(cb) end

--- **`LOADUNLOAD` `SERVER`**
--- Execute a callback when a player loads.
--- @param cb fun()
--- ```lua
--- LT.OnPlayerLoad(function()
---     local src = source
---     print("Player loaded: ".. src)
--- end)
--- ```
function LT.OnPlayerLoad(cb) end

--- **`LOADUNLOAD` `SERVER`**
--- Execute a callback when a player unloads/drops.
--- @param cb fun()
--- ```lua
--- LT.OnPlayerUnload(function()
---     local src = source
---     print("Player disconnected: ".. src)
--- end)
--- ```
function LT.OnPlayerUnload(cb) end

--- **`LOCALE` `SHARED`**
--- Load and prepare localization from `locales` folder of resource.
--- Don't forget to add `locales/*.{json,lua}` to `files` in `fxmanifest.lua`
---
--- **JSON**:
--- ```lua
--- LT.Locale.Init('en', 'json') -- Setup a JSON locale.
---
--- -- locales/en.json
--- ```
--- ```JSON
--- {
---     "client": {
---         "hello": "Hello!",
---         "how_are_you": "How are you, %s?",
---         "hello_how_are_you": "${client.hello} ${client.how_are_you}"
---     }
--- }
--- ```
---
--- **LUA**:
--- ```lua
--- LT.Locale.Init('en', 'lua') -- Setup a LUA locale.
---
--- -- locales/en.lua
--- return {
---     client = {
---         hello = 'Hello!',
---         how_are_you = 'How are you, %s?',
---         hello_how_are_you = '${client.hello} ${client.how_are_you}'
---     },
--- }
--- ```
--- **Using the locales:**
---
--- ```lua
--- local _t = LT.Locale.Get -- Simplify the function.
---
--- _t('client.hello') -> Hello!
--- _t('client.how_are_you', 'John') -> How are you, John?
--- _t('client.hello_how_are_you', 'John') -> Hello! How are you, John?
--- ```
--- @param key string Locale key (e.g. 'en', 'tr')
--- @param fileType? 'json'|'lua' Default: `json`
function LT.Locale.Init(key, fileType) end

--- **`LOCALE` `SHARED`**
--- Get localized string with formatting.
--- @param str string Locale key.
--- @param ...? any Format parameters (Optional)
--- ```lua
--- -- Simplify the function.
--- local _t = LT.Locale.Get
---
--- _t('client.hello') -> Hello.
--- _t('client.hello_name', 'John') -> Hello, John.
--- ```
--- @return string
function LT.Locale.Get(str, ...) end

--- **`LOCALE` `SHARED`**
--- Returns all translated strings as a table.
--- Useful for sending translations to NUI.
---
--- By default, the dictionary is flattened:
--- Nested keys like `client -> hello` become a single key (`"client.hello"`).
---
--- If `keepNesting` is set to `true`, the original nested structure is preserved:
--- `{ client = { hello = "..." } }`
---
---@param keepNesting? boolean Whether to preserve the original nested structure
---@return table<string, string|table> `Translated strings`
function LT.Locale.GetAllStrings(keepNesting) end

--- **`LOCALE` `SHARED`**
--- Returns the current locale key.
--- @return string?
function LT.Locale.GetCurrentKey() end

--- **`LOGGER` `SERVER`**
--- Initialize logger.
--- **NOTE:** If using `txt` type, you need to create the folder manually `logs` (by default) in your resource folder.
--- @param logType 'discord'|'txt'|'fivemanage'|'fivemerr'
--- @param data? table { `webhook: string` (If using discord), `folder: string` (If using txt, optional), `interval: number` (optional), `fivemerrAPIKey: string` (If using fivemerr, optional) }
--- ```lua
--- LT.Logger.Init('discord', {
---     webhook = '', -- Webhook URL if using discord.
---     folder = 'custom_logs_folder', -- Custom folder if using txt logs. Must be manually created in resource directory.
---     fivemerrAPIKey = '', -- Fivemerr API key if using it.
---     interval = 60000, -- Log write/send interval to prevent spam or rate limits. (default: 60000 -> every minute)
--- })
--- ```
function LT.Logger.Init(logType, data) end

--- **`LOGGER` `SERVER`**
--- Creates a log message.
--- Use `LT.Logger.Init()` before using this function.
--- @param message string The message to log.
--- @param status? 'info'|'warn'|'error' (optional)
function LT.Logger.Create(message, status) end

--- **`MATH` `SHARED`**
--- Clamp a value between min and max.
--- @param value number
--- @param min number
--- @param max number
--- @return number
function LT.Math.Clamp(value, min, max) end

--- **`MATH` `SHARED`**
--- Format a number as money with currency symbol.
--- ```lua
--- LT.Math.FormatMoney(1234567) -- "$1,234,567"
--- LT.Math.FormatMoney(1234567, '€') -- "€1,234,567"
--- ```
--- @param num number
--- @param symbol? string Currency symbol, defaults to "$"
--- @return string
function LT.Math.FormatMoney(num, symbol) end

--- **`MATH` `SHARED`**
--- Format a number with thousand separators.
--- ```lua
--- LT.Math.FormatNumber(1234567) -- "1,234,567"
--- ```
--- @param num number
--- @return string
function LT.Math.FormatNumber(num) end

--- **`MATH` `SHARED`**
--- Linear interpolation between two values.
--- @param a number Start value
--- @param b number End value
--- @param t number Interpolation factor (0-1)
--- @return number
function LT.Math.Lerp(a, b, t) end

--- **`MATH` `SHARED`**
--- Map a value from one range to another.
--- ```lua
--- LT.Math.MapRange(50, 0, 100, 0, 1) -- 0.5
--- ```
--- @param value number
--- @param inMin number
--- @param inMax number
--- @param outMin number
--- @param outMax number
--- @return number
function LT.Math.MapRange(value, inMin, inMax, outMin, outMax) end

--- **`MATH` `SHARED`**
--- Get a random float in range.
--- @param min number
--- @param max number
--- @return number
function LT.Math.RandomFloat(min, max) end

--- **`MATH` `SHARED`**
--- Round a number to given decimal places.
--- @param num number
--- @param decimals? number Defaults to 0
--- @return number
function LT.Math.Round(num, decimals) end

--- **`MENU` `CLIENT`**
--- Returns menu resource name.
--- @return 'ox_lib'|'lt-ui'|'qb-menu'|'lation_ui'|'wasabi_uikit'|nil
function LT.Menu.GetResource() end

--- **`MENU` `CLIENT`**
--- Force set menu resource.
--- Useful for config assignment.
--- @param name 'ox_lib'|'lt-ui'|'qb-menu'|'lation_ui'|'wasabi_uikit'
function LT.Menu.SetResource(name) end

--- **`MENU` `CLIENT`**
--- Opens a interactable menu.
--- @param id string Menu unique ID
--- @param data table Menu data
--- @param isQB? boolean If data table is sent with QB format set to true, default: false
--- @return table|nil
function LT.Menu.Open(id, data, isQB) end

--- **`NOTIFY` `CLIENT`**
--- Returns notify resource name.
--- @return 'ox_lib'|'lt-ui'|'esx_notify'|'okokNotify'|'pNotify'|'mythic_notify'|'brutal_notify'|'wasabi_notify'|'origen_notify'|'lation_ui'|'qb-notify'|nil
function LT.Notify.GetResource() end

--- **`NOTIFY` `CLIENT`**
--- Force set notify resource.
--- Useful for config assignment.
--- @param name 'ox_lib'|'lt-ui'|'esx_notify'|'okokNotify'|'pNotify'|'mythic_notify'|'brutal_notify'|'wasabi_notify'|'origen_notify'|'lation_ui'|'qb-notify'
function LT.Notify.SetResource(name) end

--- **`NOTIFY` `CLIENT`**
--- Send notification to player.
--- @param title? string Title for notification.
--- @param message string Notify message.
--- @param variant? 'success'|'error'|'info'|'warning' Type of notification.
--- @param length? number Duration in milliseconds. Defaults to 3500.
function LT.Notify.Send(title, message, variant, length) end

--- **`NOTIFY` `SERVER`**
--- Send notification to player.
--- @param source number Player source
--- @param title? string Title
--- @param message string Messsage section
--- @param variant? 'success'|'error'|'info'|'warning' Type of notification.
--- @param length? number Duration in milliseconds. Defaults to 3500.
function LT.Notify.Send(source, title, message, variant, length) end

--- **`NUI` `CLIENT`**
--- Registers a NUI callback/listener.
--- ```lua
--- LT.NUI.Callback('closeMenu', function(data, cb)
---     LT.NUI.Focus(false)
---     cb('ok')
--- end)
--- ```
--- @param name string Callback name
--- @param cb fun(data: table, cb: fun(response: any))
function LT.NUI.Callback(name, cb) end

--- **`NUI` `CLIENT`**
--- Set NUI focus and optional mouse cursor. Also triggers an event that can be listened to.
---
--- **Lua Example:**
--- ```lua
--- LT.NUI.Focus(true, true) -- Focus + Mouse
--- LT.NUI.Focus(false)      -- Close All
---
--- AddEventHandler(GetCurrentResourceName() .. ':client:@NUI:FocusChanged', function(status, cursor)
---     print('NUI Focus Changed:', status, cursor)
--- end)
--- ```
---
--- @param status boolean Focus status
--- @param cursor? boolean Optional mouse cursor status (defaults to status)
function LT.NUI.Focus(status, cursor) end

--- **`NUI` `CLIENT`**
--- Sends a message to the NUI.
---
--- **Lua Example:**
--- ```lua
--- LT.NUI.Message('open_shop', { items = {1, 2, 3} })
--- ```
---
--- **NUI (JS) Example:**
--- ```javascript
--- window.addEventListener('message', (event) => {
---     if (event.data.action === 'open_shop') {
---         console.log('Shop items:', event.data.items);
---     }
--- });
--- ```
--- @param action string Action name
--- @param data? table Optional data payload
function LT.NUI.Message(action, data) end

--- **`NUI` `CLIENT`**
--- Sends a message to the NUI and waits for a response.
---
--- **Lua Example:**
--- ```lua
--- local name = LT.NUI.Request('get_name', { title = 'Enter' }, 5000)
--- print(name)
--- ```
---
--- **NUI (JS) Example:**
--- ```javascript
--- window.addEventListener('message', (event) => {
---     if (event.data.action === 'get_name') {
---         fetch(`https://${GetParentResourceName()}/ltbridge:response`, {
---             method: 'POST',
---             body: JSON.stringify({ requestId: event.data.requestId, data: 'John Doe' })
---         });
---     }
--- });
--- ```
--- @param action string Action name
--- @param data? any Optional data to send
--- @param timeout? number Optional timeout in ms (default: 5000)
--- @return any? result The data returned from the NUI, or nil if timed out.
function LT.NUI.Request(action, data, timeout) end

--- **`NUI` `CLIENT`**
--- @deprecated
--- **DEPRECATED**: Use `LT.NUI.Message` instead.
---
--- Sends a message to the NUI.
---
--- **Lua Example:**
--- ```lua
--- LT.NUI.Send('open_shop', { items = {1, 2, 3} })
--- ```
---
--- **NUI (JS) Example:**
--- ```javascript
--- window.addEventListener('message', (event) => {
---     if (event.data.action === 'open_shop') {
---         console.log('Shop items:', event.data.payload.items);
---     }
--- });
--- ```
--- @param action string Action name
--- @param payload? any Optional data payload
function LT.NUI.Send(action, payload) end

--- **`NUI` `CLIENT`**
--- Creates a reactive state table for NUI.
---
--- The returned proxy behaves like a normal Lua table.
--- Nested writes are tracked and same-tick changes are batched into one NUI message.
--- Assigning `nil` deletes the key and sends the deleted path in `deletes`.
---
--- ```lua
--- local player = LT.NUI.CreateState("UpdatePlayer", {
---     hud = {
---         health = 100,
---         armor = 100
---     },
---     inventory = {
---         items = {
---             { id = 1, name = "Apple", quantity = 1, secret = "123" }
---         }
---     },
---     localOnly = {
---         secret = "123"
---     }
--- }, { "localOnly", "inventory.items.1.secret" })
---
--- player.hud.health = 50
--- player.hud.armor = 25
--- player.inventory.items[1].name = nil
--- player:update({ hud = { health = 75 } })
--- player:set({ hud = { health = 100, armor = 100 } })
--- player:sync()
--- ```
---
--- **Pinia / Vue**
--- ```javascript
--- window.addEventListener("message", (event) => {
---   const data = event.data;
---   const store = usePlayerStore();
---
---   if (data.action === "UpdatePlayer") {
---     store.$patch(data.batch || {});
---     for (const path of data.deletes || []) unsetByPath(store.$state, path);
---   }
---
---   if (data.action === "UpdatePlayer_sync" || data.action === "UpdatePlayer_set") {
---     store.$state = data.state;
---   }
--- });
--- ```
---
--- @param action string Base update action. Example: `UpdatePlayer`.
--- @param tbl? table Initial state table.
--- @param ignoreList? string[] Dot-path list that will never be sent to NUI (ignored). Example: `{ "hud.health", "inventory.items.1.secret" }`
--- @return table proxy Reactive state proxy (`:sync`, `:set`, `:update`, `:raw`, `:snapshot`).
function LT.NUI.CreateState(action, tbl, ignoreList) end

--- **`NUI` `CLIENT`**
--- Yields the current thread until NUI signals its ready.
---
--- **Lua Example:**
--- ```lua
--- LT.NUI.Check()
--- ```
---
--- **NUI (JS) Example:**
--- ```javascript
--- window.addEventListener('message', function(event) {
---     if (event.data.action === 'ltbridge_check_nui') {
---         fetch(`https://${GetParentResourceName()}/ltbridge:ready`, { method: 'POST' });
---     }
--- });
--- ```
--- @param action? string NUI message to send (defaults to 'ltbridge_check_nui').
--- @return boolean
function LT.NUI.Check(action) end

--- **`NUI` `CLIENT`**
--- Returns `true` if NUI is loaded, `false` otherwise.
--- @return boolean
function LT.NUI.IsLoaded() end

--- **`PHONE` `SERVER`**
--- Returns players phone number using active phone resource. Fallbacks to framework function.
--- @param source number Player source
--- @return string|nil `Phone number` if found, `nil` otherwise.
function LT.Phone.GetNumber(source) end

--- **`PHONE` `CLIENT`**
--- Send mail to player. Recommend to use `server` side function.
--- @param mail string Sender mail
--- @param title string Mail title
--- @param message string Content of mail
--- @return boolean
function LT.Phone.SendMail(mail, title, message) end

--- **`PHONE` `SERVER`**
--- Send mail to player.
--- @param source number Player source
--- @param mail string Sender mail
--- @param title string Mail title
--- @param message string Content of mail
--- @return boolean
function LT.Phone.SendMail(source, mail, title, message) end

--- **`PHONE` `SHARED`**
--- Returns phone resource name.
--- @return 'lb-phone'|'qb-phone'|'okokPhone'|'qs-smartphone-pro'|'gksphone'|'cylex_phone'|nil
function LT.Phone.GetResource() end

--- **`PHONE` `SHARED`**
--- Force set phone resource.
--- Useful for config assignment.
--- @param name 'lb-phone'|'qb-phone'|'okokPhone'|'qs-smartphone-pro'|'gksphone'|'cylex_phone'
function LT.Phone.SetResource(name) end

--- **`PROGRESS` `CLIENT`**
--- Returns progress bar resource name.
--- @return 'ox_lib'|'lt-ui'|'progressbar'|'lation_ui'|'wasabi_uikit'|nil
function LT.Progress.GetResource() end

--- **`PROGRESS` `CLIENT`**
--- Force set progress bar resource.
--- Useful for config assignment.
--- @param name 'ox_lib'|'lt-ui'|'progressbar'|'lation_ui'|'wasabi_uikit'
function LT.Progress.SetResource(name) end

--- **`PROGRESS` `CLIENT`**
--- Open progress bar.
--- @param options table Options
--- @param cb? fun(success: boolean)
--- @param isQB? boolean If options are sent in "qb-progressbar" format, set to true. If not set, it will be assumed as "ox_lib" progress bar format.
--- @return boolean success
function LT.Progress.Open(options, cb, isQB) end

--- **`STATE` `SHARED`**
--- Get entity state value.
--- ```lua
--- local fuel = LT.State.Get(vehicle, 'fuel')
--- ```
--- @param entity number Entity handle
--- @param key string State key
--- @return any
function LT.State.Get(entity, key) end

--- **`STATE` `CLIENT`**
--- Get local player state value.
--- ```lua
--- local isBusy = LT.State.GetPlayer('busy')
--- ```
--- @param key string State key
--- @return any
function LT.State.GetPlayer(key) end

--- **`STATE` `SERVER`**
--- Get player state value.
--- ```lua
--- local isWanted = LT.State.GetPlayer(source, 'wanted')
--- ```
--- @param source number Player source
--- @param key string State key
--- @return any
function LT.State.GetPlayer(source, key) end

--- **`STATE` `SHARED`**
--- Register a handler for state bag changes across all entities.
--- ```lua
--- LT.State.OnChange('fuel', function(value, bagName)
---     local entity = GetEntityFromStateBagName(bagName)
---     if entity > 0 then
---         print(('Entity %s fuel changed to %s'):format(entity, value))
---     end
--- end)
--- ```
--- @param key string State key to watch
--- @param handler fun(value: any, bagName: string)
--- @return number Handler ID (use RemoveStateBagChangeHandler to remove)
function LT.State.OnChange(key, handler) end

--- **`STATE` `SHARED`**
--- Set entity state value.
--- ```lua
--- LT.State.Set(vehicle, 'fuel', 100.0)
--- LT.State.Set(ped, 'busy', true, false) -- not replicated
--- ```
--- @param entity number Entity handle
--- @param key string State key
--- @param value any State value
--- @param replicated? boolean Replicate to network (default: true)
function LT.State.Set(entity, key, value, replicated) end

--- **`STATE` `CLIENT`**
--- Set local player state value.
--- ```lua
--- LT.State.SetPlayer('busy', true)
--- ```
--- @param key string State key
--- @param value any State value
--- @param replicated? boolean Replicate to server (default: true)
function LT.State.SetPlayer(key, value, replicated) end

--- **`STATE` `SERVER`**
--- Set player state value.
--- ```lua
--- LT.State.SetPlayer(source, 'wanted', true)
--- ```
--- @param source number Player source
--- @param key string State key
--- @param value any State value
--- @param replicated? boolean Replicate to clients (default: true)
function LT.State.SetPlayer(source, key, value, replicated) end

--- **`STREAMING` `CLIENT`**
--- Request and await an animation dictionary load.
--- @param dict string Animation dictionary name
--- @param timeout? number Timeout in ms (default: 5000)
--- @return boolean
function LT.Streaming.RequestAnimDict(dict, timeout) end

--- **`STREAMING` `CLIENT`**
--- Request and await an animation set load.
--- @param set string Animation set name
--- @param timeout? number Timeout in ms (default: 5000)
--- @return boolean
function LT.Streaming.RequestAnimSet(set, timeout) end

--- **`STREAMING` `CLIENT`**
--- Request and await a clip set load.
--- @param set string Clip set name
--- @param timeout? number Timeout in ms (default: 5000)
--- @return boolean
function LT.Streaming.RequestClipSet(set, timeout) end

--- **`STREAMING` `CLIENT`**
--- Request and await a model load.
--- ```lua
--- if LT.Streaming.RequestModel('prop_cs_cardbox_01') then
---     -- model loaded
--- end
--- ```
--- @param model string|number Model name or hash
--- @param timeout? number Timeout in ms (default: 5000)
--- @return boolean
function LT.Streaming.RequestModel(model, timeout) end

--- **`STREAMING` `CLIENT`**
--- Request and await a named PTFX asset load.
--- @param asset string PTFX asset name
--- @param timeout? number Timeout in ms (default: 5000)
--- @return boolean
function LT.Streaming.RequestPtfxAsset(asset, timeout) end

--- **`STREAMING` `CLIENT`**
--- Request and await a texture dictionary load.
--- @param dict string Texture dictionary name
--- @param timeout? number Timeout in ms (default: 5000)
--- @return boolean
function LT.Streaming.RequestTexture(dict, timeout) end

--- **`STREAMING` `CLIENT`**
--- Request and await a weapon asset load.
--- @param hash number|string Weapon hash or name
--- @param timeout? number Timeout in ms (default: 5000)
--- @return boolean
function LT.Streaming.RequestWeaponAsset(hash, timeout) end

--- **`STRING` `SHARED`**
--- Capitalize first letter of a string.
--- @param str string
--- @return string
function LT.String.Capitalize(str) end

--- **`STRING` `SHARED`**
--- Check if string ends with given suffix.
--- @param str string
--- @param suffix string
--- @return boolean
function LT.String.EndsWith(str, suffix) end

--- **`STRING` `SHARED`**
--- Split a string by delimiter.
--- ```lua
--- LT.String.Split('hello-world-test', '-') -- {'hello', 'world', 'test'}
--- ```
--- @param str string
--- @param delimiter string
--- @return table
function LT.String.Split(str, delimiter) end

--- **`STRING` `SHARED`**
--- Check if string starts with given prefix.
--- @param str string
--- @param prefix string
--- @return boolean
function LT.String.StartsWith(str, prefix) end

--- **`STRING` `SHARED`**
--- Capitalize first letter of each word.
--- ```lua
--- LT.String.TitleCase('hello world') -- 'Hello World'
--- ```
--- @param str string
--- @return string
function LT.String.TitleCase(str) end

--- **`STRING` `SHARED`**
--- Trim whitespace from both ends of a string.
--- @param str string
--- @return string
function LT.String.Trim(str) end

--- **`TABLE` `SHARED`**
--- Check if a table contains a value.
--- @param tbl table
--- @param value any
--- @param iter? boolean|function If true, uses ipairs. If function, uses as iterator. Default pairs.
--- @return boolean
function LT.Table.Contains(tbl, value, iter) end

--- **`TABLE` `SHARED`**
--- Deep copy a table recursively.
--- @param tbl table
--- @param iter? boolean|function If true, uses ipairs. If function, uses as iterator. Default pairs.
--- @return table
function LT.Table.DeepCopy(tbl, iter) end

--- **`TABLE` `SHARED`**
--- Filter a table by a predicate function.
--- ```lua
--- local evens = LT.Table.Filter({1, 2, 3, 4}, function(v) return v % 2 == 0 end)
--- -- {2, 4}
--- ```
--- @param tbl table
--- @param predicate fun(value: any, key: any): boolean
--- @param iter? boolean|function If true, uses ipairs. If function, uses as iterator. Default pairs.
--- @return table
function LT.Table.Filter(tbl, predicate, iter) end

--- **`TABLE` `SHARED`**
--- Get all keys of a table.
--- @param tbl table
--- @param iter? boolean|function If true, uses ipairs. If function, uses as iterator. Default pairs.
--- @return table
function LT.Table.Keys(tbl, iter) end

--- **`TABLE` `SHARED`**
--- Map a table by a transform function.
--- ```lua
--- local doubled = LT.Table.Map({1, 2, 3}, function(v) return v * 2 end)
--- -- {2, 4, 6}
--- ```
--- @param tbl table
--- @param transform fun(value: any, key: any): any
--- @param iter? boolean|function If true, uses ipairs. If function, uses as iterator. Default pairs.
--- @return table
function LT.Table.Map(tbl, transform, iter) end

--- **`TABLE` `SHARED`**
--- Merge two tables. Override values take priority.
--- Performs deep merge for nested tables.
--- @param base table
--- @param override table
--- @param iter? boolean|function If true, uses ipairs. If function, uses as iterator. Default pairs.
--- @return table
function LT.Table.Merge(base, override, iter) end

--- **`TABLE` `SHARED`**
--- Get size of a table (works for non-sequential tables by default).
--- @param tbl table
--- @param iter? boolean|function If true, uses ipairs. If function, uses as iterator. Default pairs.
--- @return number
function LT.Table.Size(tbl, iter) end

--- **`TABLE` `SHARED`**
--- Get all values of a table.
--- @param tbl table
--- @param iter? boolean|function If true, uses ipairs. If function, uses as iterator. Default pairs.
--- @return table
function LT.Table.Values(tbl, iter) end

--- **`TARGET` `CLIENT`**
--- Create target box zone.
--- @param name string Box name
--- @param coords table Box cooords {x,y,z}
--- @param size table Box size {x,y,z}
--- @param heading number Box heading
--- @param options table Options
--- @param debug? boolean Debug
function LT.Target.AddBoxZone(name, coords, size, heading, options, debug) end

--- **`TARGET` `CLIENT`**
--- Add target options to peds (excluding players).
--- @param options table Options
function LT.Target.AddGlobalPed(options) end

--- **`TARGET` `CLIENT`**
--- Add target options to all players.
--- @param options table Options
function LT.Target.AddGlobalPlayer(options) end

--- **`TARGET` `CLIENT`**
--- Add target options to all vehicles.
--- @param options table Options
function LT.Target.AddGlobalVehicle(options) end

--- **`TARGET` `CLIENT`**
--- Create target options on non-networked entity(s).
--- @param entities table|number Entity(s)
--- @param options table Options
function LT.Target.AddLocalEntity(entities, options) end

--- **`TARGET` `CLIENT`**
--- Create target options for specified model(s).
--- @param models table|number Model(s)
--- @param options table Options
function LT.Target.AddModel(models, options) end

--- **`TARGET` `CLIENT`**
--- Create target options on networked entity(s).
--- @param netids table|number Net id(s)
--- @param options table Options
function LT.Target.AddNetworkedEntity(netids, options) end

--- **`TARGET` `CLIENT`**
--- Create target sphere zone.
---@param name string Zone name
---@param coords table Zone coords
---@param radius number Radius
---@param options table Options
---@param debug? boolean Debug mode
function LT.Target.AddSphereZone(name, coords, radius, options, debug) end

--- **`TARGET` `CLIENT`**
--- Remove all target options from all Peds.
--- @param options? table Options
function LT.Target.RemoveGlobalPed(options) end

--- **`TARGET` `CLIENT`**
--- Remove all target options from all players.
--- @param options? table Options
function LT.Target.RemoveGlobalPlayer(options) end

--- **`TARGET` `CLIENT`**
--- Remove all target options from all vehicles.
--- @param options table Options
function LT.Target.RemoveGlobalVehicle(options) end

--- **`TARGET` `CLIENT`**
--- Remove target options on non-networked entity(s).
--- @param entities table|number Entity(s)
--- @param optionNames string|table Option(s)
function LT.Target.RemoveLocalEntity(entities, optionNames) end

--- **`TARGET` `CLIENT`**
--- Remove specified target options for specified model(s).
--- @param models table|number Model(s)
--- @param optionNames string|table Option name(s)
function LT.Target.RemoveModel(models, optionNames) end

--- **`TARGET` `CLIENT`**
--- Remove target options from networked entity(s).
--- @param netids table|number Net id(s)
--- @param optionNames string|table Option name(s)
function LT.Target.RemoveNetworkedEntity(netids, optionNames) end

--- **`TARGET` `CLIENT`**
--- Toggle on/off targeting.
--- @param state boolean `true` Can target | `false` Can't target.
function LT.Target.ToggleTargeting(state) end

--- **`TARGET` `CLIENT`**
--- Returns target resource name.
--- @return 'ox_target'|'qb-target'|nil
function LT.Target.GetResource() end

--- **`TARGET` `CLIENT`**
--- Remove a target zone.
--- @param name string
function LT.Target.RemoveZone(name) end

--- **`TEXTUI` `CLIENT`**
--- Hides Text UI from screen.
function LT.TextUI.Hide() end

--- **`TEXTUI` `CLIENT`**
--- Show Text UI on screen.
--- @param text string Text to show on screen.
function LT.TextUI.Show(text) end

--- **`TEXTUI` `CLIENT`**
--- Returns TextUI resource name.
--- @return 'ox_lib'|'lt-ui'|'jg-textui'|'esx_textui'|'okokTextUI'|'cd_drawtextui'|'lation_ui'|'lab-HintUI'|nil
function LT.TextUI.GetResource() end

--- **`TEXTUI` `CLIENT`**
--- Force set TextUI resource.
--- Useful for config assignment.
--- @param name 'ox_lib'|'lt-ui'|'jg-textui'|'esx_textui'|'okokTextUI'|'cd_drawtextui'|'lation_ui'|'lab-HintUI'
function LT.TextUI.SetResource(name) end

--- **`UTILS` `CLIENT`**
--- Get the closest object to given coords.
--- @param coords? vector3 Coords of area (default: Player coords)
--- @param maxDistance? number Max search radius (default: 50.0)
--- @return number? object, number? distance
function LT.Utils.GetClosestObject(coords, maxDistance) end

--- **`UTILS` `CLIENT`**
--- Get the closest ped to given coords (excluding players).
--- @param coords? vector3 Coords of area (default: Player coords)
--- @param maxDistance? number Max search radius (default: 50.0)
--- @return number? ped, number? distance
function LT.Utils.GetClosestPed(coords, maxDistance) end

--- **`UTILS` `CLIENT`**
--- Get the closest player to given coords.
--- ```lua
--- local playerId, ped, dist = LT.Utils.GetClosestPlayer()
--- ```
--- @param coords? vector3 Coords of area (default: Player coords)
--- @param maxDistance? number Max search radius (default: 50.0)
--- @return number? playerId, number? ped, number? distance
function LT.Utils.GetClosestPlayer(coords, maxDistance) end

--- **`UTILS` `CLIENT`**
--- Get the closest vehicle to given coords.
--- @param coords? vector3 Coords of area (default: Player coords)
--- @param maxDistance? number Max search radius (default: 50.0)
--- @return number? vehicle, number? distance
function LT.Utils.GetClosestVehicle(coords, maxDistance) end

--- **`UTILS` `CLIENT`**
--- Get all players within a radius.
--- @param coords? vector3 Coords of area (default: Player coords)
--- @param radius number
--- @return table Array of { id, ped, dist }
function LT.Utils.GetPlayersInArea(coords, radius) end

--- **`UTILS` `CLIENT`**
--- Spawns a networked vehicle at the given position.
--- @param model string Model name
--- @param coords vector3 Coordinates
--- @param heading number? Heading. Default: `0.0`
--- @return boolean success
--- @return number|nil entity
--- @return number|nil netId
function LT.Utils.SpawnVehicle(model, coords, heading) end

--- **`UTILS` `SHARED`**
--- Basic switch statement for Lua.
---```lua
---local result = LT.Utils.Switch(value, {
---    [1] = function() return 'one' end,
---    [2] = function() return 'two' end,
---    default = function() return 'default' end
---})
---```
---@generic T
---@param value T The value to match against the cases
---@param cases table<T|'default', fun(): any> Table with case functions and an optional default.
---@return any|nil result The return value of the matched case function, or nil if none matched
function LT.Utils.Switch(value, cases) end

--- **`UTILS` `SHARED`**
--- Yields the coroutine until the condition returns a non-nil value, or the timeout is reached.
--- If timeout is reached and no value is returned, the function returns `nil`.
--- @generic T
--- @param cb fun(): T?
--- @param timeout number? Timeout in milliseconds. Default: `1000` ms, unless set to `false`.
--- @param interval number? Interval in milliseconds to check the condition. Default: `0` ms.
--- @return T
function LT.WaitFor(cb, timeout, interval) end

--- **`VEHICLEKEYS` `CLIENT`**
--- Give player(self) the keys of specified vehicle.
--- @param vehicle number Vehicle entity.
--- @param plate? string Plate of vehicle
--- @return boolean
function LT.VehicleKeys.Give(vehicle, plate) end

--- **`VEHICLEKEYS` `CLIENT`**
--- Remove specified vehicle keys from player(self).
--- @param vehicle number Vehicle entity.
--- @param plate? string Plate of vehicle
--- @return boolean
function LT.VehicleKeys.Remove(vehicle, plate) end

--- **`VEHICLEKEYS` `CLIENT`**
--- Returns vehicle key resource name.
--- @return 'qb-vehiclekeys'|'qbx_vehiclekeys'|'qs-vehiclekeys'|'mk_vehiclekeys'|'0r-vehiclekeys'|'MrNewbVehicleKeys'|'t1ger_keys'|'mVehicle'|'okokGarage'|nil
function LT.VehicleKeys.GetResource() end

--- **`VEHICLEKEYS` `CLIENT`**
--- Force set vehicle key resource.
--- Useful for config assignment.
--- @param name 'qb-vehiclekeys'|'qbx_vehiclekeys'|'qs-vehiclekeys'|'mk_vehiclekeys'|'0r-vehiclekeys'|'MrNewbVehicleKeys'|'t1ger_keys'|'mVehicle'|'okokGarage'
function LT.VehicleKeys.SetResource(name) end

--- **`VERSION` `SHARED`**
--- Check if a resource dependency is met.
--- ```lua
--- if not LT.Version.CheckDependency('resourceName', '1.0.0') then
---     error()
--- end
--- ```
--- @param resourceName string Resource to check
--- @param minVersion string Minimum required version (e.g. "1.0.0")
--- @return boolean
function LT.Version.CheckDependency(resourceName, minVersion) end

--- **`VERSION` `SERVER`**
--- Compares `GetResourceMetadata(..., 'version')` to GitHub latest release or a remote URL.
---
--- `data` (pick GitHub **or** URL mode):
--- - `repository` / `repo`: `owner/repo`; semver from latest non-prerelease `tag_name`.
--- - `url` + optional `fileType` (`JSON` default, or `PLAIN`): remote version string or JSON map keyed by `resourceName`.
--- - `resourceName`, `downloadUrl`: optional overrides (name defaults to current resource).
--- - `sendUpToDate`: set `true` to print when already current; default is silent (no up-to-date line).
---
--- `messages`: optional `{ upToDate, updateAvailable, download }` printf-style format strings.
--- @param data table
--- @param messages? table
function LT.Version.Check(data, messages) end

--- **`VERSION` `SERVER`**
--- Returns the specific resource's version.
--- @param resourceName? string Defaults to current resource name.
--- @return string?
function LT.Version.Get(resourceName) end

--- **`GENERAL` `SHARED`**
--- Returns the current version of LTBridge.
--- @return string
function LT.GetBridgeVersion() end
