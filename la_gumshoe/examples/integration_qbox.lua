-- examples/integration_qbox.lua
-- Snippet showing how qbx_policejob (or other server scripts) can integrate with la_gumshoe.
-- Purpose: register a death and call the client investigation UI for a nearby cop/detective.

-- When a player dies (server-side), call la_gumshoe:server:reportDeath with metadata.
-- Example usage inside your qbx_policejob death handling logic:

local function onPlayerDeath(victimSource, attackerIdentifier, cause)
    local netId = nil -- optional; supply if available
    TriggerEvent('la_gumshoe:server:reportDeath', {
        netId = tostring(netId),
        victim_type = 'player',
        victim_identifier = "player:" .. tostring(victimSource),
        death_time = os.date("%Y-%m-%d %H:%M:%S"),
        cause = cause or "unknown",
        attacker_identifier = attackerIdentifier,
        critical_area = nil
    })
end

-- How to trigger client-side investigation from qbx_policejob when officer interacts:
-- Example: when officer right-clicks a corpse via qtarget, call:
-- TriggerClientEvent('la_gumshoe:client:startInvestigation', officerSource, { entity_netId = netId })

-- If you want to gate the tool, ensure only players with job names in Config.DetectiveJobs can trigger startInvestigation.
-- Example server-side permission check before sending client event:

local function tryOpenInvestigation(officerSource, targetNetId)
    local accepted = false
    local player = nil
    -- Example: adapt to your Qbox player API
    if exports.qbx_core and exports.qbx_core:GetPlayer then
        player = exports.qbx_core:GetPlayer(officerSource)
    end
    if player and player.getJob and type(player.getJob) == "function" then
        local jobname = player:getJob() or nil
        for _, allowed in ipairs({"police","detective"}) do
            if jobname == allowed then accepted = true; break end
        end
    end
    if accepted then
        TriggerClientEvent('la_gumshoe:client:startInvestigation', officerSource, { entity_netId = targetNetId })
    else
        TriggerClientEvent('chat:addMessage', officerSource, { args = { "[La Gumshoe]", "You are not authorized to use detective tools." } })
    end
end

-- Note: exact Qbox APIs may vary; adapt player job retrieval accordingly.
