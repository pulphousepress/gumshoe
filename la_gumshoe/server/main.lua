local Gumshoe = {}

local resourceName = GetCurrentResourceName()
local dbWrapper = require("server.db_wrapper")

local state = {
    config = {},
    log = function() end,
    db = nil,
    configSource = nil
}

local function loadConfig()
    local search = { "config.lua", "config.example.lua" }
    for _, fileName in ipairs(search) do
        local raw = LoadResourceFile(resourceName, fileName)
        if raw then
            local env = {}
            local chunk, err = load(raw, "@" .. fileName, "t", env)
            if not chunk then
                print(("[gumshoe][error] failed to load %s: %s"):format(fileName, err))
            else
                local ok, res = pcall(chunk)
                if not ok then
                    print(("[gumshoe][error] failed to execute %s: %s"):format(fileName, res))
                else
                    local cfg = env.Config or res
                    if type(cfg) == "table" then
                        return cfg, fileName
                    end
                end
            end
        end
    end
    print("[gumshoe][warn] no config.lua or config.example.lua found, using defaults")
    return {}, nil
end

local function makeLogger(config)
    config.Logging = config.Logging or {}
    local hook = config.Logging.Hook
    local level = string.lower(config.Logging.Level or "info")
    local levels = { error = 0, warn = 1, info = 2, debug = 3 }
    local threshold = levels[level] or 2

    return function(severity, message, context)
        local normalized = string.lower(severity or "info")
        local rank = levels[normalized] or 2
        if rank > threshold then
            return
        end
        local payload = ("[gumshoe][%s] %s"):format(normalized, message)
        print(payload)
        if type(hook) == "function" then
            hook(normalized, message, context)
        end
    end
end

local function computeReward(range)
    range = range or {}
    local minimum = tonumber(range.min) or 0
    local maximum = tonumber(range.max) or minimum
    if maximum < minimum then
        maximum = minimum
    end
    return math.random(minimum, maximum)
end

local function sanitizeString(value, fallback)
    if type(value) == "string" and value ~= "" then
        return value
    end
    return fallback
end

local function sanitizeSceneData(scene)
    local textValue = "{}"
    local jsonValue = "{}"
    if type(scene) == "table" then
        local ok, encoded = pcall(json.encode, scene)
        if ok then
            textValue = encoded
            jsonValue = encoded
        end
    elseif type(scene) == "string" then
        if scene ~= "" then
            textValue = scene
            local ok, decoded = pcall(json.decode, scene)
            if ok and type(decoded) == "table" then
                local okEncode, reencoded = pcall(json.encode, decoded)
                if okEncode then
                    jsonValue = reencoded
                end
            end
        end
    end
    return textValue, jsonValue
end

local function sanitizeMetadata(metadata)
    local textValue = "{}"
    if type(metadata) == "table" then
        local ok, encoded = pcall(json.encode, metadata)
        if ok then
            textValue = encoded
        end
    elseif type(metadata) == "string" and metadata ~= "" then
        textValue = metadata
    end
    return textValue
end

local function validateInvestigation(payload, src)
    if type(payload) ~= "table" then
        return false, "invalid_payload_type"
    end

    local investigator = sanitizeString(payload.investigator_id, tostring(src))
    if not investigator then
        return false, "missing_investigator"
    end

    local sceneText, sceneJson = sanitizeSceneData(payload.scene_data)
    local data = {
        victim_type = sanitizeString(payload.victim_type, "npc"),
        victim_identifier = sanitizeString(payload.victim_identifier, nil),
        death_time = sanitizeString(payload.death_time, os.date("%Y-%m-%d %H:%M:%S")),
        estimated_tod = sanitizeString(payload.estimated_tod, nil),
        cause = sanitizeString(payload.cause, "unknown"),
        critical_area = sanitizeString(payload.critical_area, "unknown"),
        attacker_identifier = sanitizeString(payload.attacker_identifier, nil),
        scene_data = sceneText,
        scene_data_json = sceneJson,
        investigator_id = investigator,
        metadata = sanitizeMetadata(payload.metadata)
    }

    return true, data
end

local function insertInvestigation(data, rewards)
    if not state.db or not state.db.ok then
        return { ok = false, err = "no_database_driver" }
    end

    local tableName = state.config.DB and state.config.DB.Table or "gumshoe_investigations"
    local query = string.format([[INSERT INTO `%s`
        (victim_type, victim_identifier, death_time, estimated_time_of_death, cause, critical_area,
         attacker_identifier, scene_data, scene_data_json, investigator_identifier, xp_awarded, payout, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], tableName)

    local params = {
        data.victim_type,
        data.victim_identifier,
        data.death_time,
        data.estimated_tod,
        data.cause,
        data.critical_area,
        data.attacker_identifier,
        data.scene_data,
        data.scene_data_json,
        data.investigator_id,
        rewards.xp,
        rewards.cash,
        data.metadata
    }

    local result = dbWrapper.insert(query, params)
    if not result or not result.ok then
        return result or { ok = false, err = "insert_failed" }
    end

    return {
        ok = true,
        data = {
            id = result.data and (result.data.insert_id or result.data.insertId) or nil,
            xp = rewards.xp,
            cash = rewards.cash
        }
    }
end

function Gumshoe.handleSaveInvestigation(src, payload)
    local ok, dataOrErr = validateInvestigation(payload, src)
    if not ok then
        state.log("warn", "invalid investigation payload", { source = src, err = dataOrErr })
        TriggerClientEvent("gumshoe:client:receiveInvestigation", src, { ok = false, err = dataOrErr })
        return
    end

    local rewards = {
        xp = computeReward(state.config.Rewards and state.config.Rewards.XP),
        cash = computeReward(state.config.Rewards and state.config.Rewards.Cash)
    }

    local result = insertInvestigation(dataOrErr, rewards)
    if not result.ok then
        state.log("error", "failed to insert investigation", { source = src, err = result.err })
        TriggerClientEvent("gumshoe:client:receiveInvestigation", src, { ok = false, err = result.err })
        return
    end

    state.log("info", "investigation saved", {
        source = src,
        investigation_id = result.data.id,
        xp = rewards.xp,
        cash = rewards.cash
    })

    TriggerClientEvent("gumshoe:client:receiveInvestigation", src, {
        ok = true,
        data = result.data
    })
end

function Gumshoe.init(cfg)
    local config, sourceName = loadConfig()
    state.config = config
    state.configSource = sourceName or "<defaults>"

    state.config.DB = state.config.DB or {}
    state.config.Rewards = state.config.Rewards or {}
    state.config.Rewards.XP = state.config.Rewards.XP or { min = 0, max = 0 }
    state.config.Rewards.Cash = state.config.Rewards.Cash or { min = 0, max = 0 }

    state.log = makeLogger(state.config)
    state.log("info", ("configuration loaded from %s"):format(state.configSource))

    state.db = dbWrapper.init({
        preferDriver = state.config.DB.Driver ~= "auto" and state.config.DB.Driver or nil,
        logger = state.log
    })

    if not state.db or not state.db.ok then
        state.log("error", "database driver unavailable; gumshoe persistence disabled", state.db)
    end

    RegisterNetEvent("gumshoe:server:saveInvestigation", function(payload)
        local src = source
        Gumshoe.handleSaveInvestigation(src, payload)
    end)

    return true
end

Gumshoe.init()

return Gumshoe
