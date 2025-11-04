local QBCore = nil
local ESX = nil
local json = json or require("json")

if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
    QBCore.Functions.CreateUseableItem("notepad", function(source, item)
        local noteId = item.info and item.info.noteId or tostring(source) .. "_slot" .. item.slot
        TriggerClientEvent("kurlie_notepad:notepad:openUI", source, { noteId = noteId })
    end)
elseif GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
    ESX.RegisterUsableItem("notepad", function(source)
        local noteId = tostring(source) .. "_default"
        TriggerEvent("notepad:requestNote", source, noteId)
    end)
end

RegisterNetEvent("notepad:saveText", function(data)
    local src = source
    local identifier

    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        identifier = xPlayer and xPlayer.identifier
    elseif QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        identifier = Player and Player.PlayerData.citizenid
    end

    if not identifier then
        print("[SERVER ERROR] No character identifier found for", src)
        return
    end

    if not data or not data.noteId then
        print("[SERVER ERROR] Missing noteId or data")
        return
    end
    local content = json.encode({
        pages = data.pages or {["1"] = ""},
        currentPage = data.currentPage or 1
    })

    MySQL.Async.execute([[
        INSERT INTO user_notepads (identifier, note_id, content)
        VALUES (@identifier, @note_id, @content)
        ON DUPLICATE KEY UPDATE content = @content
    ]], {
        ['@identifier'] = identifier,
        ['@note_id'] = data.noteId,
        ['@content'] = content
    }, function(rowsChanged)
    end)
end)

RegisterNetEvent("notepad:requestNote", function(src, noteId)
    if not src or src == 0 then
        print("[SERVER ERROR] Invalid player source")
        return
    end

    local identifier

    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        identifier = xPlayer and xPlayer.identifier
    elseif QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        identifier = Player and Player.PlayerData.citizenid
    end

    if not identifier then
        print("[SERVER ERROR] No character identifier found for", src)
        return
    end

    MySQL.Async.fetchScalar([[
        SELECT content FROM user_notepads WHERE identifier = @identifier AND note_id = @note_id
    ]], {
        ['@identifier'] = identifier,
        ['@note_id'] = noteId
    }, function(content)
        local data = json.decode(content or "{}")
        TriggerClientEvent("kurlie_notepad:notepad:openUI", src, {
            pages = data.pages or { ["1"] = "" },
            currentPage = data.currentPage or 1,
            noteId = noteId
        })
    end)
end)

-- RegisterCommand("opennotepad", function(source, args, rawCommand)
--     local noteId = args[1] or tostring(source) .. "_test"
--     TriggerEvent("notepad:requestNote", source, noteId)
-- end, false)
