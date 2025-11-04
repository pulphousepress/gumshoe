RegisterNetEvent("kurlie_notepad:notepad:openUI", function(savedData)
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, "CODE_HUMAN_MEDIC_TIME_OF_DEATH", 0, false)

    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "openNotepad",
        pages = savedData.pages or {["1"] = ""},
        currentPage = savedData.currentPage or 1,
        noteId = savedData.noteId or "default"
    })
end)


RegisterNUICallback("saveNotepad", function(data, cb)
    TriggerServerEvent("notepad:saveText", data)
    cb({})
end)

RegisterNUICallback("closeNotepad", function(_, cb)
    ClearPedTasks(PlayerPedId())
    SetNuiFocus(false, false)
    cb({})
end)
