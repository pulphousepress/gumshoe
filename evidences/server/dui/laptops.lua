-- server/dui/laptops.lua
-- Full replacement: authoritative laptop DB, place/pickup callbacks, and open-request handler.
-- Requires: oxmysql (MySQL.*.await), qbx_core export to check player groups, ox_inventory for giving items back.

local RESOURCE = GetCurrentResourceName()

-- Utility: server-side permission check for laptop actions
local function has_laptop_permission(source)
    if not source or source == 0 then return false end
    local ok, pdata = pcall(function() return exports.qbx_core and exports.qbx_core:GetPlayerData(source) end)
    if not ok or not pdata then return false end

    -- `groups` is expected to be a table: { police = { grade = ... }, detective = {...} }
    local groups = pdata.groups or {}
    if groups["police"] or groups["detective"] or groups["fib"] then
        return true
    end

    return false
end

-- Ensure DB table exists
local function ensure_tables()
    local q = [[
        CREATE TABLE IF NOT EXISTS `evidence_laptops` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `w` DOUBLE DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]
    -- MySQL.query / execute with await varies; use MySQL.query.await if available
    if MySQL and MySQL.execute then
        pcall(function() MySQL.execute(q) end)
    else
        print(("[%s] WARNING: MySQL.execute not found. Table ensure skipped."):format(RESOURCE))
    end
end

-- Load all laptops from DB and broadcast spawn to clients
local function load_and_broadcast_laptops()
    if not (MySQL and MySQL.query) then
        print(("[%s] WARNING: MySQL.query not available; cannot load laptops."):format(RESOURCE))
        return
    end

    local ok, rows = pcall(function()
        return MySQL.query.await("SELECT id, x, y, z, w FROM evidence_laptops")
    end)

    if not ok then
        print(("[%s] ERROR: failed to query evidence_laptops"):format(RESOURCE))
        return
    end

    -- Broadcast the entire set to clients (client will spawn based on these)
    TriggerClientEvent("evidences:client:spawnLaptops", -1, rows or {})
end

-- Insert a laptop into DB and broadcast spawn
local function place_laptop(coords)
    if not (coords and coords.x and coords.y and coords.z) then return false end
    local w = coords.w or 0.0
    local ok, insertId = pcall(function()
        return MySQL.insert.await("INSERT INTO evidence_laptops (x, y, z, w) VALUES (?, ?, ?, ?)", {
            tostring(coords.x), tostring(coords.y), tostring(coords.z), tostring(w)
        })
    end)
    if not ok or not insertId then return false end

    -- include id in broadcast so clients can map entity <-> DB
    local row = {
        id = insertId,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = w
    }
    TriggerClientEvent("evidences:client:spawnLaptops", -1, { row })
    return true
end

-- Remove laptop from DB and broadcast destroy
local function pickup_laptop(coords)
    if not (coords and coords.x and coords.y and coords.z) then return false end

    local ok, affected = pcall(function()
        return MySQL.update.await("DELETE FROM evidence_laptops WHERE x = ? AND y = ? AND z = ? LIMIT 1", {
            tostring(coords.x), tostring(coords.y), tostring(coords.z)
        })
    end)

    if not ok or (not affected) or (tonumber(affected) <= 0) then
        return false
    end

    TriggerClientEvent("evidences:client:destroyLaptop", -1, coords)
    return true
end

-- Server RPC: client requests to open laptop. Server validates and triggers client event to open.
RegisterNetEvent("evidences:laptops:requestOpen", function(coords)
    local src = source
    if not has_laptop_permission(src) then
        -- Inform client politely (clientside code should show a notify)
        TriggerClientEvent("evidences:client:openDenied", src)
        return
    end

    -- All good: instruct this client to open the laptop UI
    TriggerClientEvent("evidences:client:openLaptop", src, coords)
end)

-- Callback for placing laptop (e.g., ox_inventory recorded use)
lib.callback.register("evidences:laptops:place", function(source, coords)
    if not has_laptop_permission(source) then
        return false
    end

    local ok = false
    local suc, res = pcall(function() return place_laptop(coords) end)
    if suc and res then ok = true end

    return ok
end)

lib.callback.register("evidences:laptops:pickup", function(source, coords)
    if not has_laptop_permission(source) then
        return false
    end

    local ok, res = pcall(function() return pickup_laptop(coords) end)
    if not ok or not res then
        return false
    end

    -- attempt to give the player the laptop item back
    local giveOk = false
    local sucGive, giveRes = pcall(function()
        -- Use dot-access to check function existence (obj:method is call syntax)
        if exports.ox_inventory and exports.ox_inventory.AddItem then
            -- call using colon syntax so ox_inventory handles self correctly if needed
            return exports.ox_inventory:AddItem(source, "evidence_laptop", 1)
        end
        return false
    end)
    if sucGive and giveRes then giveOk = true end

    return giveOk
end)

-- Server-side helper: admin command to reload laptops from DB (for testing)
RegisterCommand("evidences_reload_laptops", function(src)
    if src == 0 or has_laptop_permission(src) then
        load_and_broadcast_laptops()
    else
        if src ~= 0 then TriggerClientEvent("evidences:client:openDenied", src) end
    end
end, false)

-- Resource lifecycle
AddEventHandler("onResourceStart", function(resName)
    if resName ~= RESOURCE then return end
    print(("[%s] starting: ensuring tables and loading laptops"):format(RESOURCE))
    ensure_tables()
    -- give a tiny delay to let DB connect if needed
    CreateThread(function()
        Wait(1000)
        load_and_broadcast_laptops()
    end)
end)
