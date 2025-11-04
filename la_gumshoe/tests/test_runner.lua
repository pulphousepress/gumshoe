-- tests/test_runner.lua
-- Simple smoke test script for local development.
-- Purpose: simulate death reporting and investigation flow.
-- Run: ensure this file is included for testing or manually execute its events

local function simulate()
    local src = 0 -- server origin (simulate)
    -- a random netId
    local netId = tostring(math.random(100000,999999))
    TriggerEvent('la_gumshoe:server:reportDeath', {
        netId = netId,
        victim_type = 'npc',
        victim_identifier = 'npc_test_001',
        death_time = os.date("%Y-%m-%d %H:%M:%S", os.time() - 3600),
        cause = 'stabbing',
        attacker_identifier = 'unknown',
        critical_area = 'chest'
    })

    print("[tests] simulated death reported, netId:", netId)

    local cbEvent = 'la_gumshoe:test:cb'
    AddEventHandler(cbEvent, function(data)
        print("[tests] received cb:", data and json.encode(data) or "nil")
    end)

    TriggerEvent('la_gumshoe:server:requestDeathMeta', { netId = netId }, cbEvent)

    TriggerEvent('la_gumshoe:server:saveInvestigation', {
        victim_type = 'npc',
        victim_identifier = 'npc_test_001',
        death_time = os.date("%Y-%m-%d %H:%M:%S", os.time() - 3600),
        estimated_tod = os.date("%Y-%m-%d %H:%M:%S", os.time() - 3500),
        cause = 'stabbing',
        critical_area = 'chest',
        attacker_identifier = 'unknown',
        scene_data = { coords = { x=0,y=0,z=0 }, clues = { "knife_found" } },
        investigator_id = 'test_runner'
    })

    print("[tests] simulate save triggered")
end

if GetCurrentResourceName():find('la_gumshoe') then
    print("[tests] running simulate()")
    simulate()
end
