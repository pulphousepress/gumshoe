-- server/main.lua
-- Minimal server logic: DB wrapper detection, saveInvestigation, getInvestigation, unlock command

local cfgf = LoadResourceFile(GetCurrentResourceName(), "config.lua")
local Config = {}
if cfgf then
    local env = {}
    local ok, chunk = pcall(load, cfgf, "config.lua", "t", env)
    if ok and chunk then pcall(chunk); Config = env.Config or {} end
end
if not Config then Config = {} end

local oxmysql_available = false
local mysql_async_available = false
if exports and exports.oxmysql then oxmysql_available = true end
if MySQL and MySQL.Async and MySQL.Async.execute then mysql_async_available = true end

print(("[la_gumshoe] server starting. DB wrappers - oxmysql: %s mysql-async: %s"):format(tostring(oxmysql_available), tostring(mysql_async_available)))

local function dbExecute(query, params, cb)
    if oxmysql_available then
        exports.oxmysql:execute(query, params or {}, function(res) if cb then cb(true, res) end end)
    elseif mysql_async_available then
        MySQL.Async.execute(query, params or {}, function(res) if cb then cb(true, res) end end)
    else
        if Config.LogToConsole then print("[la_gumshoe] No MySQL wrapper available. Skipping DB write.") end
        if cb then cb(false) end
    end
end

local function dbQuery(query, params, cb)
    if oxmysql_available then
        exports.oxmysql:fetch(query, params or {}, function(rows) if cb then cb(rows) end end)
    elseif mysql_async_available then
        MySQL.Async.fetchAll(query, params or {}, function(rows) if cb then cb(rows) end end)
    else
        if Config.LogToConsole then print("[la_gumshoe] No MySQL wrapper available. Skipping DB query.") end
        if cb then cb(nil) end
    end
end

-- Save investigation (called by client NUI)
RegisterNetEvent('la_gumshoe:server:saveInvestigation', function(payload)
    local src = source
    if not payload then
        print("[la_gumshoe] saveInvestigation called without payload")
        return
    end

    local xp = math.random(Config.XP.min or 10, Config.XP.max or 30)
    local payout = math.random(Config.Payout.min or 50, Config.Payout.max or 150)
    local sceneJSON = "{}"
    if payload.scene_data then
        if type(payload.scene_data) == "table" then sceneJSON = json.encode(payload.scene_data) elseif type(payload.scene_data) == "string" then sceneJSON = payload.scene_data end
    end

    local q = string.format([[
        INSERT INTO `%s` (victim_type, victim_identifier, death_time, estimated_time_of_death, cause, critical_area, attacker_identifier, scene_data, investigator_id, xp_awarded, payout)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], Config.DBTable or "dead_investigations")

    local params = {
        payload.victim_type or "npc",
        payload.victim_identifier or nil,
        payload.death_time or os.date("%Y-%m-%d %H:%M:%S"),
        payload.estimated_tod or nil,
        payload.cause or "unknown",
        payload.critical_area or "unknown",
        payload.attacker_identifier or nil,
        sceneJSON,
        payload.investigator_id or tostring(src),
        xp,
        payout
    }

    dbExecute(q, params, function(ok, res)
        if ok then
            if Config.LogToConsole then print(("[la_gumshoe] Investigation saved by src=%s victim=%s xp=%s payout=%s"):format(tostring(src), tostring(params[2]), tostring(xp), tostring(payout))) end
            TriggerClientEvent('la_gumshoe:client:investigationSaved', src, { id = nil, xp = xp, payout = payout })
        else
            TriggerClientEvent('la_gumshoe:client:investigationSaved', src, { id = nil, xp = 0, payout = 0 })
        end
    end)
end)

-- Simple getter (client provides callback event name)
RegisterNetEvent('la_gumshoe:server:getInvestigation', function(id, cbEvent)
    local src = source
    if not id or not cbEvent then
        TriggerClientEvent(cbEvent, src, nil)
        return
    end
    local q = string.format("SELECT * FROM `%s` WHERE id = ? LIMIT 1", Config.DBTable or "dead_investigations")
    dbQuery(q, { tonumber(id) }, function(rows)
        if rows and #rows > 0 then
            local row = rows[1]
            if row.scene_data and type(row.scene_data) == "string" then
                local ok, parsed = pcall(json.decode, row.scene_data)
                if ok then row.scene_data = parsed end
            end
            TriggerClientEvent(cbEvent, src, row)
        else
            TriggerClientEvent(cbEvent, src, nil)
        end
    end)
end)

-- Console command to force-unfocus NUI on all clients (console-only)
RegisterCommand('la_gumshoe_unlock', function(source, args, raw)
    if source ~= 0 then print("This command must be run from the server console.") return end
    print("[la_gumshoe] unlock broadcast invoked from console")
    for _, pid in ipairs(GetPlayers()) do
        TriggerClientEvent('la_gumshoe:client:forceCloseNUI', tonumber(pid))
    end
end, false)

print("[la_gumshoe] server loaded")
