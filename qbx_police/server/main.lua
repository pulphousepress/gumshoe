local sharedConfig = require 'config.shared'
Plates = {}
local playerStatus = {}
local casings = {}
local bloodDrops = {}
local fingerDrops = {}
local updatingCops = false

---@param player Player
---@param minGrade? integer
---@return boolean?
function IsLeoAndOnDuty(player, minGrade)
    local job = player.PlayerData.job
    if job and job.type == 'leo' and job.onduty then
        return job.grade.level >= (minGrade or 0)
    end
end

-- Functions
local function updateBlips()
    local dutyPlayers = {}
    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        local playerData = player.PlayerData
        local job = playerData.job
        if (job.type == 'leo' or job.type == 'ems') and job.onduty then
            local source = playerData.source
            local ped = GetPlayerPed(source)
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            dutyPlayers[#dutyPlayers + 1] = {
                job = job.name,
                source = source,
                label = playerData.metadata.callsign,
                location = vec4(coords.x, coords.y, coords.z, heading)
            }
        end
    end
    TriggerClientEvent('police:client:UpdateBlips', -1, dutyPlayers)
end

local function generateId(table)
    local id = lib.string.random('11111')
    if not table then return id end
    while table[id] do
        id = lib.string.random('11111')
    end
    return id
end

RegisterNetEvent('police:server:SendTrackerLocation', function(coords, requestId)
    local target = exports.qbx_core:GetPlayer(source)
    local msg = locale('info.target_location', target.PlayerData.charinfo.firstname, target.PlayerData.charinfo.lastname)
    local alertData = {
        title = locale('info.anklet_location'),
        coords = coords,
        description = msg
    }
    TriggerClientEvent('police:client:TrackerMessage', requestId, msg, coords)
    TriggerClientEvent('qb-phone:client:addPoliceAlert', requestId, alertData)
end)

-- Items
exports.qbx_core:CreateUseableItem('handcuffs', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player.Functions.GetItemByName('handcuffs') then return end
    TriggerClientEvent('police:client:CuffPlayerSoft', source)
end)

exports.qbx_core:CreateUseableItem('moneybag', function(source, item)
    if not item.info or item.info == '' then return end
    local player = exports.qbx_core:GetPlayer(source)
    if not player
        or player.PlayerData.job.type == 'leo'
        or not player.Functions.GetItemByName('moneybag')
        or not player.Functions.RemoveItem('moneybag', 1, item.slot)
    then
        return
    end
    player.Functions.AddMoney('cash', tonumber(item.info.cash), 'used-moneybag')
end)

-- Callbacks
lib.callback.register('police:server:isPlayerDead', function(_, playerId)
    local player = exports.qbx_core:GetPlayer(playerId)
    return player.PlayerData.metadata.isdead
end)

lib.callback.register('police:GetPlayerStatus', function(_, targetSrc)
    local player = exports.qbx_core:GetPlayer(targetSrc)
    if not player or not next(playerStatus[targetSrc]) then return {} end
    local status = playerStatus[targetSrc]
    local statList = {}
    for i = 1, #status do
        statList[#statList + 1] = status[i].text
    end
    return statList
end)

lib.callback.register('police:GetImpoundedVehicles', function()
    return FetchImpoundedVehicles()
end)

-- Restrict spawnable police vehicles to vintage models only
local allowedModels = {
    `policeold1`,
    `policeold2`,
    `policeold3`
}

lib.callback.register('qbx_policejob:server:spawnVehicle', function(source, model, coords, plate, giveKeys, vehId)
    local modelHash = joaat(model)
    if not lib.table.contains(allowedModels, modelHash) then
        exports.qbx_core:Notify(source, 'This vehicle is not in service for this era.', 'error')
        return
    end

    local netId, veh = qbx.spawnVehicle({
        model = model,
        spawnSource = coords,
        warp = GetPlayerPed(source)
    })

    if not netId or netId == 0 or not veh or veh == 0 then return end
    SetVehicleNumberPlateText(veh, plate)
    if giveKeys == true then exports.qbx_vehiclekeys:GiveKeys(source, veh) end
    if vehId then Entity(veh).state.vehicleid = vehId end
    return netId
end)

-- [the rest of your evidence, jail, escort, cuffing, etc. remains unchanged …]

-- Threads
CreateThread(function()
    Wait(1000)
    while true do
        Wait(1000 * 60 * 10)
        local curCops = exports.qbx_core:GetDutyCountType('leo')
        TriggerClientEvent('police:SetCopCount', -1, curCops)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        updateBlips()
    end
end)
