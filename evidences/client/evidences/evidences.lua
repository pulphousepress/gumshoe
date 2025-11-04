-- client/evidences/evidences.lua
-- Full replacement: client-side evidence manager for the evidences resource.

local utils = require("client.evidences.utils")

local resourceName = GetCurrentResourceName()
local EvidenceManager = {}
EvidenceManager.registry = {} -- local cache: key -> { id, type, coords, metadata, entity }

-- EVENT names used between client/server
local EVT_CREATE_REQ = "evidences:server:createEvidence" -- server side is expected to exist
local EVT_DELETE_REQ = "evidences:server:deleteEvidence"

-- Local helpers
local function makeKey(coords)
    if not coords then return nil end
    -- stable key for coordinates (rounded)
    local x = string.format("%.3f", tonumber(coords.x) or 0.0)
    local y = string.format("%.3f", tonumber(coords.y) or 0.0)
    local z = string.format("%.3f", tonumber(coords.z) or 0.0)
    return x .. ":" .. y .. ":" .. z
end

-- Add a local registry entry (not authoritative — server should also store)
function EvidenceManager.addLocal(evidence)
    if not evidence or not evidence.coords then return false end
    local key = makeKey(evidence.coords)
    EvidenceManager.registry[key] = evidence
    return true
end

function EvidenceManager.removeLocalByCoords(coords)
    local key = makeKey(coords)
    if EvidenceManager.registry[key] then
        EvidenceManager.registry[key] = nil
        return true
    end
    return false
end

function EvidenceManager.findNearby(coords, radius)
    radius = radius or 1.5
    local found = {}
    for k, v in pairs(EvidenceManager.registry) do
        if v and v.coords then
            local d = utils.distance3D(v.coords, coords)
            if d <= radius then
                table.insert(found, v)
            end
        end
    end
    return found
end

-- Create evidence locally and attempt to persist via server
-- data: { type = "blood"|"fingerprint"|..., coords = {x,y,z}, metadata = { ... } }
function EvidenceManager.createEvidence(data, cb)
    if not data or not data.type or not data.coords then
        if cb then cb(false, "invalid_params") end
        return
    end

    -- Create a local entry first for immediate UX
    local entry = {
        id = nil,
        type = data.type,
        coords = { x = tonumber(data.coords.x), y = tonumber(data.coords.y), z = tonumber(data.coords.z) },
        metadata = data.metadata or {},
        createdAt = os.time()
    }

    EvidenceManager.addLocal(entry)

    -- Authoritative persistence: ask the server to store it (server should validate)
    -- Prefer lib.callback if available (ox_lib)
    if lib and lib.callback then
        lib.callback("evidences:server:createEvidence", false, function(success, serverData)
            if success and serverData and serverData.id then
                entry.id = serverData.id
                if cb then cb(true, entry) end
            else
                -- server failed: remove local entry
                EvidenceManager.removeLocalByCoords(entry.coords)
                if cb then cb(false, "server_failed") end
            end
        end, entry)
    else
        -- fallback: fire an event and hope server listens
        TriggerServerEvent(EVT_CREATE_REQ, entry)
        -- no immediate confirmation; respond success locally
        if cb then cb(true, entry) end
    end
end

-- Request deletion of evidence (server authoritative)
function EvidenceManager.requestDelete(coords, cb)
    if not coords then if cb then cb(false) end return end

    if lib and lib.callback then
        lib.callback("evidences:server:deleteEvidence", false, function(success)
            if success then
                EvidenceManager.removeLocalByCoords(coords)
            end
            if cb then cb(success) end
        end, coords)
    else
        TriggerServerEvent(EVT_DELETE_REQ, coords)
        -- local immediate remove (optimistic) - server should re-sync
        EvidenceManager.removeLocalByCoords(coords)
        if cb then cb(true) end
    end
end

-- When server broadcasts evidence spawns (on resource start or DB sync)
RegisterNetEvent("evidences:client:syncEvidenceSet", function(rows)
    -- Expected rows: array of { id, type, x, y, z, metadata? }
    if not rows or type(rows) ~= "table" then return end
    for _, row in ipairs(rows) do
        local coords = { x = tonumber(row.x), y = tonumber(row.y), z = tonumber(row.z) }
        local entry = {
            id = row.id,
            type = row.type or row.t or "unknown",
            coords = coords,
            metadata = row.metadata or {},
            createdAt = row.created_at or os.time()
        }
        EvidenceManager.addLocal(entry)
    end
end)

-- When server tells us to spawn a single evidence (DB insert)
RegisterNetEvent("evidences:client:spawnEvidence", function(row)
    if not row then return end
    local coords = { x = tonumber(row.x), y = tonumber(row.y), z = tonumber(row.z) }
    local entry = {
        id = row.id,
        type = row.type or row.t or "unknown",
        coords = coords,
        metadata = row.metadata or {},
        createdAt = row.created_at or os.time()
    }
    EvidenceManager.addLocal(entry)
end)

-- When server tells us to remove evidence
RegisterNetEvent("evidences:client:destroyEvidence", function(coords)
    EvidenceManager.removeLocalByCoords(coords)
end)

-- Example helper: attach evidence metadata to an entity via StateBag (server preferred)
function EvidenceManager.attachToEntity(entity, evidenceData)
    if not DoesEntityExist(entity) or not evidenceData then return false end
    -- prefer Server authoritative state setting via server event if available
    -- But if you must set client state for local effects:
    if Entity and Entity(entity) and Entity(entity).state then
        Entity(entity).state["evidences:data"] = evidenceData
        return true
    end

    -- Fallback: locally store in registry mapping by entity network id
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId then
        EvidenceManager.registry["ent:" .. tostring(netId)] = evidenceData
        return true
    end

    return false
end

-- Expose a small API to other client modules
exports("getAllLocal", function() return EvidenceManager.registry end)
exports("createEvidence", function(data, cb) return EvidenceManager.createEvidence(data, cb) end)
exports("requestDelete", function(coords, cb) return EvidenceManager.requestDelete(coords, cb) end)
exports("findNearby", function(coords, radius) return EvidenceManager.findNearby(coords, radius) end)

-- Minimal self-test on resource start (helps debugging)
CreateThread(function()
    Wait(1000)
    -- announce that client evidence manager loaded
    print(("[evidences] client evidence manager loaded (%s entries cached)"):format(#(next(EvidenceManager.registry) and 1 or 0)))
end)

return EvidenceManager
