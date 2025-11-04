-- client/init.lua (FULL replacement)
-- Paste this entire file exactly and save (overwrite existing).

lib.locale()

require "client.evidences.evidences"

require "client.evidences.registry.blood"
require "client.evidences.registry.fingerprint"
require "client.evidences.registry.magazine"

require "client.dui.handler"

require "client.scanner.scanner"

require "client.items"

local config <const> = require "config"

RegisterNetEvent("evidences:notify", function(translation, type, duration)
    config.notify(translation, type, duration)
end)

-- ==========================
-- Laptop interaction (desk trigger)
-- ==========================
-- How this works:
-- 1) Stand at the desk and run /set_laptop to save the desk position for this session.
-- 2) Walk near the desk; a prompt will show "Press ~INPUT_CONTEXT~ to open laptop".
-- 3) Press E (default) to open the laptop (NUI). Close with Esc or /close_laptop.

local LaptopCoords = nil          -- will hold vector3 coords once set with /set_laptop
local LaptopDistance = 1.8        -- how close player must be to interact (meters)
local Draw3DTextAbove = true      -- set to true to draw small 3D marker; off if you don't want it

-- Utility: draw simple 3D text at world coords
local function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(1)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(_x, _y)
end

-- Helper: show a 2D help prompt in lower center
local function ShowHelpPromt(text)
    SetTextComponentFormat("STRING")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

-- Command: set the laptop trigger to the current player position (stand at desk then run)
RegisterCommand('set_laptop', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    LaptopCoords = vector3(coords.x, coords.y, coords.z)
    print(("[detective] Laptop trigger set at: %.3f, %.3f, %.3f"):format(coords.x, coords.y, coords.z))
    config.notify("Laptop position saved for this session.", "success", 3000)
end, false)

-- Keep the /open_laptop and /close_laptop commands (manual control)
RegisterCommand('open_laptop', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'open' })
    print("[detective] open_laptop called")
end, false)

RegisterCommand('close_laptop', function()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
    print("[detective] close_laptop called")
end, false)

-- NUI callback for HTML -> client POST (https://<resource>/close)
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
    if cb then cb('ok') end
end)

-- Defensive: ensure focus cleared when resource stops
AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)

-- Exports (optional) to open/close programmatically from other scripts
exports('OpenDetectiveLaptop', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'open' })
end)
exports('CloseDetectiveLaptop', function()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end)

-- Proximity thread: shows prompt and listens for E
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) -- default idle wait

        if LaptopCoords ~= nil then
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            local dist = #(pcoords - LaptopCoords)

            if dist <= 12.0 then
                -- when nearby, poll faster
                Citizen.Wait(0)
                if Draw3DTextAbove then
                    -- draw a little floating label just above the desk
                    Draw3DText(LaptopCoords.x, LaptopCoords.y, LaptopCoords.z + 0.9, "[ Desk ]")
                end
                if dist <= LaptopDistance then
                    -- show help prompt (Uses standard help text area)
                    ShowHelpPromt("Press ~INPUT_CONTEXT~ to open the detective laptop")
                    -- listen for E (control 38)
                    if IsControlJustReleased(0, 38) then
                        -- open NUI safely
                        SetNuiFocus(true, true)
                        SendNUIMessage({ type = 'open' })
                    end
                end
            end
        else
            -- No laptop coords set; do nothing (cheap sleep)
            Citizen.Wait(1500)
        end
    end
end)

-- Small UX: print reminder on resource start
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    print("[detective] If you want the laptop trigger at your desk, stand at the desk and run: /set_laptop")
end)
