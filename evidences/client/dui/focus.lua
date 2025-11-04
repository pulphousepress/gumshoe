-- client/dui/focus.lua
-- Full replacement: manages camera, mouse, and NUI focus for the Evidence Laptop UI.
-- This file NEVER sets NUI focus itself unless the server explicitly tells this client to open the laptop.
-- Server triggers event: 'evidences:client:openLaptop' (see server/dui/laptops.lua).
-- Client notifies the server via ox_target onSelect (see client/dui/laptops/target.lua).

local Config = Config or {} -- fallback if config loaded elsewhere
local duiModule = require("client.dui.dui") -- your dui wrapper that constructs the lib.dui instance
local started = false
local duiObject = nil
local cam = nil
local laptopEntity = nil
local lastMouseX, lastMouseY = 0, 0
local inputThread = nil
local resourceName = GetCurrentResourceName()

-- Utility: send mouse movement to DUI scaled to its resolution (dui object handles target path)
local function handleMouse()
    if not duiObject then return end
    local x, y = GetNuiCursorPosition()
    if x ~= lastMouseX or y ~= lastMouseY then
        -- assume DUI built at 1920x1080 (common); scale according to actual game resolution
        local screenW, screenH = GetActiveScreenResolution()
        if screenW == 0 or screenH == 0 then screenW, screenH = 1920, 1080 end
        local scaleX = 1920 / screenW
        local scaleY = 1080 / screenH
        local dx = math.floor((x * scaleX) + 0.5)
        local dy = math.floor((y * scaleY) + 0.5)
        SendDuiMouseMove(duiObject, dx, dy)
        lastMouseX, lastMouseY = x, y
    end

    -- left click
    if IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 237) then
        SendDuiMouseDown(duiObject, "left")
    elseif IsDisabledControlJustReleased(0, 24) or IsControlJustReleased(0, 237) then
        SendDuiMouseUp(duiObject, "left")
    end

    -- mouse wheel
    if IsControlJustPressed(0, 241) then
        SendDuiMouseWheel(duiObject, 100, 0)
    elseif IsControlJustPressed(0, 242) then
        SendDuiMouseWheel(duiObject, -100, 0)
    end
end

-- Start focus for a given laptop entity; this will attach camera, set focus and begin input polling.
local function startFocus(entity, duiObj)
    if started then return end
    if not DoesEntityExist(entity) then return end
    if not duiObj then
        print(("[%s] startFocus called with nil duiObj"):format(resourceName))
        return
    end

    started = true
    duiObject = duiObj
    laptopEntity = entity

    -- attach camera
    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    local x, y, z = table.unpack(GetEntityCoords(entity))
    SetCamCoord(cam, x, y, z + 0.3)
    SetCamRot(cam, -20.0, 0.0, GetEntityHeading(entity))
    SetCamFov(cam, 45.0)
    RenderScriptCams(true, false, 0, true, false)

    -- telemetry to DUI
    SendNUIMessage({ type = "evidences:focus", payload = { playerName = GetPlayerName(PlayerId()) } })

    -- set NUI focus (we only do this when server has already authorized)
    SetNuiFocus(true, false)

    -- input thread
    inputThread = CreateThread(function()
        while started do
            DisablePlayerFiring(PlayerId(), true)
            handleMouse()
            Wait(0)
        end
    end)
end

local function stopFocus()
    if not started then return end
    started = false

    -- destroy camera
    RenderScriptCams(false, true, 250, true, true)
    if DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
    cam = nil
    laptopEntity = nil

    -- release focus
    SetNuiFocus(false, false)

    -- tell the DUI to switch to a neutral screen (not required but helps state)
    if duiObject then
        SendDuiMessage(duiObject, '{"action":"switchScreen","screen":"screensaver"}')
    end
end

-- Event: server instructed this client to open the laptop (authoritative)
RegisterNetEvent("evidences:client:openLaptop", function(coordsOrEntity)
    -- coordsOrEntity may be nil or be an object the client can find
    -- Find the nearest laptop entity if coords provided
    local entity = nil
    if type(coordsOrEntity) == "table" and coordsOrEntity.x then
        local x, y, z = coordsOrEntity.x, coordsOrEntity.y, coordsOrEntity.z
        -- find closest laptop prop to those coords within 1.5m
        local handle = GetClosestObjectOfType(x, y, z, 2.0, `p_laptop_02_s`, false, false, false)
        if handle and handle ~= 0 then entity = handle end
    elseif type(coordsOrEntity) == "number" and DoesEntityExist(coordsOrEntity) then
        entity = coordsOrEntity
    end

    -- if not found, fallback to the player's current forward object (best-effort)
    if not entity then
        -- try to raycast in front of player
        local ped = PlayerPedId()
        local px, py, pz = table.unpack(GetEntityCoords(ped))
        local forward = GetEntityForwardVector(ped)
        local tx, ty, tz = px + forward.x * 1.0, py + forward.y * 1.0, pz + forward.z * 1.0
        local ray = StartShapeTestRay(px, py, pz + 0.5, tx, ty, tz + 0.5, -1, ped, 0)
        local _, hit, hx, hy, hz, entHit = GetShapeTestResult(ray)
        if hit and entHit then entity = entHit end
    end

    -- create or reuse a DUI object from your dui module
    local duiObj = nil
    if duiModule and duiModule.duiObject then
        duiObj = duiModule.duiObject
    elseif duiModule and duiModule.createDui then
        duiObj = duiModule.createDui()
    end

    if not duiObj then
        print(("[%s] ERROR: no dui object available for laptop open"):format(resourceName))
        TriggerEvent("chat:addMessage", { args = { "^1[EVIDENCES] Failed to open laptop UI (dui missing)" } })
        return
    end

    startFocus(entity or PlayerPedId(), duiObj)
end)

-- Event: server told client to spawn laptops list (handled elsewhere in your client spawn code)
RegisterNetEvent("evidences:client:spawnLaptops", function(rows)
    -- noop: this client likely has a separate module that listens for this event and spawns laptop objects
    -- keep this noop to avoid nil event errors. Actual spawn logic is in client/dui/laptops/sync.lua
end)

-- Event: server denied open request
RegisterNetEvent("evidences:client:openDenied", function()
    -- politely notify the player (replace with your notify implementation if available)
    if lib and lib.notify then
        lib.notify({ title = "Laptop", description = "Access denied.", type = "error" })
    else
        TriggerEvent("chat:addMessage", { args = { "^1[EVIDENCES] Access denied to laptop" } })
    end
end)

-- NUI callback (from the UI) to close the laptop
RegisterNUICallback("closeLaptop", function(_, cb)
    stopFocus()
    cb({ ok = true })
end)

-- Clean up on resource stop
AddEventHandler("onResourceStop", function(name)
    if name ~= resourceName then return end
    stopFocus()
end)

-- Exported API (if other client modules want to call start/stop)
exports("focusStart", function(entity, duiObj) startFocus(entity, duiObj) end)
exports("focusStop", function() stopFocus() end)
