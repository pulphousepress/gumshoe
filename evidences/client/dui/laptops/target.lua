-- client/dui/laptops/target.lua
-- Full replacement: ox_target registration for laptop prop.
-- Behavior:
--  - canInteract returns true only for visual hover (no unsolicited DUI messages).
--  - onSelect requests server authorization to open the laptop (server triggers open if allowed).
--  - pickup option uses a server callback to pickup and returns item via server.

local resourceName = GetCurrentResourceName()

-- ox_target usage: wrap in pcall in case ox_target is not installed
local success, ox_target = pcall(function() return exports.ox_target end)
if not success or not ox_target then
    print(("[%s] WARNING: ox_target not found; laptop target will not be registered."):format(resourceName))
    return
end

local models = {
    `p_laptop_02_s`,
    `p_cs_laptop`,
    `prop_laptop_01a`
}

local laptopOptions = {
    {
        -- Interact (open) option
        label = "Open Evidence Laptop",
        icon = "fa-solid fa-laptop",
        distance = 2.0,
        onSelect = function(data)
            -- data.entity is the targeted entity
            local ent = data.entity
            if not ent or ent == 0 then return end

            -- send server request to open (server will validate groups)
            local coords = GetEntityCoords(ent)
            TriggerServerEvent("evidences:laptops:requestOpen", { x = coords.x, y = coords.y, z = coords.z })
        end,
        canInteract = function(data)
            -- allow the option to be shown (visual), but do NOT open client-side UI here
            -- we return true to show the option in the target; actual open is server-authorized.
            return true
        end
    },
    {
        -- Pickup laptop (only for players with permission). This calls a server callback for security.
        label = "Pick Up Laptop",
        icon = "fa-solid fa-box-up",
        distance = 2.0,
        onSelect = function(data)
            local ent = data.entity
            if not ent or ent == 0 then return end
            local coords = GetEntityCoords(ent)
            -- ask server to pickup; server checks permissions and DB
            lib.callback("evidences:laptops:pickup", false, function(success)
                if success then
                    if lib and lib.notify then
                        lib.notify({ title = "Laptop", description = "Picked up and returned to inventory.", type = "success" })
                    else
                        TriggerEvent("chat:addMessage", { args = { "^2Laptop picked up" } })
                    end
                else
                    if lib and lib.notify then
                        lib.notify({ title = "Laptop", description = "Could not pick up laptop (permission/DB).", type = "error" })
                    else
                        TriggerEvent("chat:addMessage", { args = { "^1Failed to pick up laptop" } })
                    end
                end
            end, { x = coords.x, y = coords.y, z = coords.z })
        end,
        canInteract = function(data)
            -- We allow the option to show. The server callback will actually validate the player's groups.
            return true
        end
    }
}

-- Register the models with ox_target
for _, model in ipairs(models) do
    exports.ox_target:addModel(model, laptopOptions)
end
