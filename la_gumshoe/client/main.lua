-- client/main.lua
-- La Gumshoe - client logic (fixed syntax, safe NUI + emergency handlers)
-- Purpose: handle investigation UI open/close, highlight ragdoll areas, expose exports.

-- Load config.lua safely
local Config = nil
do
    local cfgf = LoadResourceFile(GetCurrentResourceName(), "config.lua")
    if cfgf then
        local env = {}
        local ok, chunk = pcall(load, cfgf, "config.lua", "t", env)
        if ok and chunk then
            pcall(chunk)
            Config = env.Config or {}
        end
    end
    if not Config then Config = {} end
end

-- Default safety/behavior values
if Config.EnableUI == nil then Config.EnableUI = true end
if Config.NUISafetyTimeout == nil then Config.NUISafetyTimeout = 30 end
if Config.OpenKey == nil then Config.OpenKey = 'f2' end
if Config.ForceCloseKey == nil then Config.ForceCloseKey = 'f7' end

local lastInvestigation = nil
local nuiOpen = false
local safetyThread = nil

local function dbg(...)
    if Config.Debug then
        print("[la_gumshoe][client]", ...)
    end
end

local function netIdToEntity(netId)
    if not netId then return nil end
    return NetworkGetEntityFromNetworkId(netId)
end

local function isInvestigatableEntity(entity)
    if not DoesEntityExist(entity) then return false end
    if not IsEntityAPed(entity) then return false end
    return IsPedDeadOrDying(entity, true)
end

-- Exports
exports('IsInvestigatable', function(entity)
    return isInvestigatableEntity(entity)
end)

exports('GetLastInvestigation', function()
    return lastInvestigation
end)

-- Emergency: force-close NUI
RegisterNetEvent('la_gumshoe:client:forceCloseNUI', function()
    if Config.EnableUI then
        SendNUIMessage({ action = "close" })
    end
    SetNuiFocus(false, false)
    nuiOpen = false
    dbg("forceCloseNUI triggered")
end)

-- Local command & keymap to force-close (may not work if NUI has focus; server unlock exists)
RegisterCommand('la_gumshoe_forceclose', function()
    if Config.EnableUI then SendNUIMessage({ action = "close" }) end
    SetNuiFocus(false, false)
    nuiOpen = false
    dbg("la_gumshoe_forceclose executed")
end, false)
RegisterKeyMapping('la_gumshoe_forceclose', 'Close La Gumshoe UI (force)', 'keyboard', Config.ForceCloseKey or 'f7')

-- Safety timer: auto-unfocus NUI after timeout
local function startNuiSafetyTimer()
    if safetyThread then return end
    safetyThread = CreateThread(function()
        local startTime = GetGameTimer()
        local timeout = tonumber(Config.NUISafetyTimeout) or 30
        while nuiOpen do
            local elapsed = (GetGameTimer() - startTime) / 1000
            if elapsed >= timeout then
                if Config.EnableUI then SendNUIMessage({ action = "close" }) end
                SetNuiFocus(false, false)
                nuiOpen = false
                dbg("NUI safety timeout reached, auto-unfocused UI")
                break
            end
            Wait(500)
        end
        safetyThread = nil
    end)
end

-- Visual highlight of critical area on ragdoll
RegisterNetEvent('la_gumshoe:client:highlightCriticalArea', function(data)
    data = data or {}
    local ent = data.entity
    local area = data.areaString or "unknown"

    if not ent or not DoesEntityExist(ent) then
        dbg("highlightCriticalArea: invalid entity")
        return
    end

    local bone = nil
    if area == "head" then bone = GetPedBoneIndex(ent, 31086)
    elseif area == "chest" then bone = GetPedBoneIndex(ent, 24816)
    elseif area == "abdomen" then bone = GetPedBoneIndex(ent, 11816)
    else bone = GetPedBoneIndex(ent, 11816) end

    local coords = nil
    if bone then
        coords = GetWorldPositionOfEntityBone(ent, bone)
    end
    if not coords or coords == vector3(0,0,0) then
        coords = GetEntityCoords(ent)
    end

    CreateThread(function()
        local start = GetGameTimer()
        local duration = 7000
        while (GetGameTimer() - start) < duration do
            DrawMarker(28, coords.x, coords.y, coords.z + 0.2, 0,0,0, 0,0,0, 0.45,0.45,0.45, 255,80,80,180, false, true, 2, nil, nil, false)
            Wait(0)
        end
    end)
end)

-- Start investigation (called by integration or commands)
RegisterNetEvent('la_gumshoe:client:startInvestigation', function(args)
    args = args or {}
    local entity = args.entity or (args.entity_netId and netIdToEntity(args.entity_netId))
    if not entity or not DoesEntityExist(entity) then
        TriggerEvent('chat:addMessage', { args = { "[La Gumshoe]", "No valid entity to investigate." } })
        return
    end
    if not isInvestigatableEntity(entity) then
        TriggerEvent('chat:addMessage', { args = { "[La Gumshoe]", "Entity is not investigatable (not dead)." } })
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    local cbEvent = 'la_gumshoe:client:startInvestigation:cb:' .. tostring(math.random(999999))

    RegisterNetEvent(cbEvent, function(serverData)
        local scene_data = serverData and serverData.scene_data or {}
        local death_time = serverData and serverData.death_time or os.date("%Y-%m-%d %H:%M:%S")
        local cause = serverData and serverData.cause or "unknown"
        local attacker = serverData and serverData.attacker_identifier or nil
        local critical_area = serverData and serverData.critical_area or "unknown"

        local accuracy = tonumber(Config.TODAccuracyMinutes) or 15
        local est_seconds = accuracy * 60
        local est_offset = math.random(-est_seconds, est_seconds)
        local estimatedHuman = os.date("%Y-%m-%d %H:%M:%S", os.time() + est_offset)

        local uiPayload = {
            victim = serverData and serverData.victim_identifier or "Unknown",
            victim_type = serverData and serverData.victim_type or "npc",
            death_time = death_time,
            estimated_tod = estimatedHuman,
            cause = cause,
            critical_area = critical_area,
            scene = scene_data or {},
            attacker = attacker
        }

        -- Send NUI open
        if Config.EnableUI then
            SendNUIMessage({ action = "open", data = uiPayload })
            CreateThread(function() Wait(150); SetNuiFocus(true, true); nuiOpen = true; startNuiSafetyTimer() end)
        else
            -- If UI disabled, show basic chat preview
            TriggerEvent('chat:addMessage', { args = { "[La Gumshoe]", ("Inspecting: %s | Cause: %s | ETA: %s"):format(uiPayload.victim, uiPayload.cause, uiPayload.estimated_tod) } })
        end

        -- Visual critical area highlight
        if uiPayload.critical_area and uiPayload.critical_area ~= "unknown" then
            TriggerEvent('la_gumshoe:client:highlightCriticalArea', { entity = entity, areaString = uiPayload.critical_area })
        end

        lastInvestigation = uiPayload
    end)

    -- Ask server for cached death meta (server should reply via cbEvent)
    TriggerServerEvent('la_gumshoe:server:requestDeathMeta', { netId = netId }, cbEvent)
end)

-- NUI callbacks
RegisterNUICallback('saveInvestigation', function(data, cb)
    local payload = data or {}
    payload.investigator_id = tostring(PlayerId())
    TriggerServerEvent('la_gumshoe:server:saveInvestigation', payload)
    cb({ ok = true })
    if Config.UICloseOnSave then
        if Config.EnableUI then SendNUIMessage({ action = "close" }) end
        SetNuiFocus(false, false)
        nuiOpen = false
    end
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    nuiOpen = false
    cb({ ok = true })
end)

-- Fallback investigate command (aim at corpse)
RegisterCommand('investigate', function()
    local ped = PlayerPedId()
    local _, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())
    local aimEnt = nil

    if entity and DoesEntityExist(entity) and IsEntityAPed(entity) and IsPedDeadOrDying(entity, true) then
        aimEnt = entity
    else
        -- Raycast forward
        local coords = GetEntityCoords(ped)
        local to = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.6, 0.0)
        local ray = StartShapeTestRay(coords.x, coords.y, coords.z + 1.0, to.x, to.y, to.z + 1.0, 12, ped, 0)
        local _, hit, _, _, ent = GetShapeTestResult(ray)
        if hit and DoesEntityExist(ent) and IsEntityAPed(ent) and IsPedDeadOrDying(ent, true) then aimEnt = ent end
    end

    if aimEnt then
        TriggerEvent('la_gumshoe:client:startInvestigation', { entity = aimEnt })
    else
        TriggerEvent('chat:addMessage', { args = { "[La Gumshoe]", "No nearby dead ped found. Aim at a corpse and try again." } })
    end
end, false)

RegisterKeyMapping('investigate', 'Start Investigation (la_gumshoe)', 'keyboard', Config.OpenKey or 'f2')

-- Notify when an investigation saved message is received
RegisterNetEvent('la_gumshoe:client:investigationSaved', function(resp)
    if resp and resp.id then
        TriggerEvent('chat:addMessage', { args = { "[La Gumshoe]", ("Investigation saved (ID: %s) XP: %s Payout: $%s"):format(tostring(resp.id), tostring(resp.xp or 0), tostring(resp.payout or 0)) } })
    else
        TriggerEvent('chat:addMessage', { args = { "[La Gumshoe]", "Investigation saved (no id returned)." } })
    end
end)

-- Ensure cleanup on resource stop
AddEventHandler('onResourceStop', function(resName)
    if resName == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        nuiOpen = false
    end
end)

dbg("client script loaded (fixed)")
