-- one-shot unlocker for la_gumshoe
AddEventHandler('onResourceStart', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    print('[la_gumshoe] running one-shot unlocker: forcing NUI unfocus for all players')
    local players = GetPlayers()
    for _, pid in ipairs(players) do
        local num = tonumber(pid)
        if num then
            TriggerClientEvent('la_gumshoe:client:forceCloseNUI', num)
        end
    end
    -- optional: print done
    print('[la_gumshoe] unlock broadcast sent to all players')
end)
