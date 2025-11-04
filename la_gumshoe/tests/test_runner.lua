-- tests/test_runner.lua
-- Simulated test harness for Gumshoe server events.
-- Provides smoke coverage for saveInvestigation event and logs structured output.

local jsonEncode
if type(json) == "table" and type(json.encode) == "function" then
    jsonEncode = function(value)
        local ok, encoded = pcall(json.encode, value)
        if ok then
            return encoded
        end
        return "<json-encode-error>"
    end
else
    jsonEncode = function(value)
        return tostring(value)
    end
end

local function simulateSaveInvestigation()
    local payload = {
        victim_type = "npc",
        victim_identifier = "npc_test_001",
        death_time = os.date("%Y-%m-%d %H:%M:%S", os.time() - 720),
        estimated_tod = os.date("%Y-%m-%d %H:%M:%S", os.time() - 690),
        cause = "gunshot",
        critical_area = "torso",
        attacker_identifier = "unknown",
        scene_data = {
            coords = { x = 441.02, y = -981.93, z = 30.68 },
            clues = { "bullet_casing", "security_camera" }
        },
        investigator_id = "test_runner",
        metadata = {
            notes = "simulated test payload",
            version = 1
        }
    }

    print("[tests] dispatching gumshoe:server:saveInvestigation with payload")
    print("[tests] payload:", jsonEncode(payload))
    TriggerEvent("gumshoe:server:saveInvestigation", payload)
end

local function registerClientSpy()
    RegisterNetEvent("gumshoe:client:receiveInvestigation", function(result)
        print("[tests] gumshoe:client:receiveInvestigation =>", jsonEncode(result))
    end)
end

local function run()
    registerClientSpy()
    simulateSaveInvestigation()
    print("[tests] simulation complete")
end

if GetCurrentResourceName and GetCurrentResourceName():find("la_gumshoe") then
    print("[tests] running Gumshoe simulated tests")
    run()
end

return {
    run = run
}
