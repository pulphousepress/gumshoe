\# Gumeshoe

Detective / investigation add-on for \*\*Qbox\*\* (standalone resource). Investigate player \& NPC corpses, reveal estimated time-of-death, cause, critical area highlight on ragdolls, randomized scene flavor, XP / payout rewards, and SQL persistence.


\## Features

\- Qbox-first detective add-on.

\- Investigate player \& NPC corpses.

\- Reveals:

&nbsp; - Estimated Time Of Death (human readable)

&nbsp; - Cause of death (gunshot, stabbing, blunt, explosion, fall, accident)

&nbsp; - Critical area (head/chest/abdomen/limb) and visual marker highlight on ragdolls

&nbsp; - Nearby clues (weapon prop, blood trail, footsteps proximity) via simple heuristics

\- Randomized scene flavor for roleplay

\- XP \& payout reward system (configurable)

\- Persists investigations to SQL (`dead\_investigations` table)

\- Optional support for `qtarget` / `qb-target` / `ox\_target`

\- No continuous polling — event-driven design (short live raycasts only)



---



\## Quick install

1\. Copy the `deadbody\_investigator/` folder to your server's `resources/\[police]/` (or any folder).

2\. Ensure DB wrapper available (prefer `oxmysql`). If using `mysql-async`, that's detected.

3\. Add `ensure deadbody\_investigator` to `server.cfg`.

4\. Import SQL: `sql/deadbody\_investigator.sql` into your MySQL/MariaDB database.

5\. Configure `config.lua` if needed (job names, rewards, target provider).

6\. (Optional) Integrate with your `qbx\_policejob` to call `deadbody:client:startInvestigation` when a death is reported (see examples/integration\_qbox.lua).



---



\## Files

\- `config.lua` — configuration options

\- `client/main.lua` — client logic + UI integration

\- `server/main.lua` — server DB persistence, reward calculation, permission checks

\- `html/ui/\*` — investigation UI

\- `sql/deadbody\_investigator.sql` — schema (MySQL)

\- `examples/integration\_qbox.lua` — integration snippet

\- `tests/\*` — manual checklist and a simple test runner



---



\## Config highlights

Open `config.lua` to tune:

\- `Config.Framework` — default `qbox`

\- `Config.DetectiveJobs` — list of Qbox job names allowed to investigate

\- `Config.UseTargetProvider` — `'auto'|'none'|'ox\_target'|'qb-target'|'qtarget'`

\- Reward XP / payout ranges

\- Camera settings and UI keys

\- DB table name and DB wrapper preferences



---



\## Events \& Exports (public)

\### Server events

\- `deadbody:server:saveInvestigation` — Save an investigation to DB.

&nbsp; - Payload: `{victim\_type, victim\_identifier, death\_time, estimated\_tod, cause, critical\_area, attacker\_identifier, scene\_data, investigator\_id, xp\_awarded, payout}`

&nbsp; - Returns investigation id via client event response (see example)

\- `deadbody:server:getInvestigation` — Request investigation by ID (server → client response)

&nbsp; - Args: `investigationId`

&nbsp; - Response via `deadbody:client:receiveInvestigation`



\- `deadbody:server:reportDeath` — (optional) register death metadata with server cache for quicker investigations

&nbsp; - Payload: `{netId, victim\_type, victim\_identifier, death\_time, cause, attacker\_identifier, critical\_area}`



\### Client events

\- `deadbody:client:startInvestigation` — Open UI for investigation

&nbsp; - Args: `{ entity\_netId }` or direct entity handle

\- `deadbody:client:highlightCriticalArea` — visually mark ragdoll

&nbsp; - Args: `{ entity, areaString }`

\- `deadbody:client:receiveInvestigation` — server response that returns saved investigation



\### Exports

\- `IsInvestigatable(entity) -> bool` — check if an entity looks investigatable (dead ragdoll)

\- `GetLastInvestigation(playerId) -> table | nil` — returns the last investigation data for this player (server export)



---



\## DB Installation

Import `sql/deadbody\_investigator.sql` into your MySQL/MariaDB database. The SQL uses a JSON column for `scene\_data`. If your DB does not support JSON, the script provides an alternate `scene\_data\_text` fallback.



Default wrapper: `oxmysql`. If only `mysql-async` is available the resource will fallback to that automatically.



---



\## Qbox integration hints

\- Qbox player object: we expect `exports.qbx\_core:GetPlayer(source)` may exist; but to keep this resource standalone we only check job via configurable job names and rely on the server to verify investigators' job via Qbox exports or permissions (see `server/main.lua`).

\- Example integration snippet for `qbx\_policejob` is in `examples/integration\_qbox.lua` (shows how to register death and call `deadbody:client:startInvestigation`).



---



\## Safety \& design tradeoffs

\- \*\*Teleporting\*\* players to scenes is optional and disabled by default. Auto-teleport can be harmful in some servers; toggle in `config.lua`.

\- \*\*Critical area detection\*\*: retrieving the exact bone that was hit reliably for all death events is not trivial across setups; this resource uses available data when provided (via `reportDeath`), otherwise uses heuristics and randomized selection for roleplay. Documented in README and server exports so other systems can feed better data.

\- Minimal runtime overhead — DB writes only on investigation completion.



---



\## Troubleshooting

\- If UI doesn't open: ensure `ui\_page` loaded and that NUI messages appear in console.

\- DB errors: check if `oxmysql` is installed and server.cfg includes credentials. If you use `mysql-async`, restart after enabling resource so fallback is detected.

\- Target provider not detected: set `Config.UseTargetProvider` explicitly to the provider you have.



---



\## License

MIT (see LICENSE)



---



Enjoy building crime scenes! 🕵️‍♂️

\# Gumeshoe

Detective / investigation add-on for \*\*Qbox\*\* (standalone resource). Investigate player \& NPC corpses, reveal estimated time-of-death, cause, critical area highlight on ragdolls, randomized scene flavor, XP / payout rewards, and SQL persistence.




---



\## Features

\- Qbox-first detective add-on.

\- Investigate player \& NPC corpses.

\- Reveals:

&nbsp; - Estimated Time Of Death (human readable)

&nbsp; - Cause of death (gunshot, stabbing, blunt, explosion, fall, accident)

&nbsp; - Critical area (head/chest/abdomen/limb) and visual marker highlight on ragdolls

&nbsp; - Nearby clues (weapon prop, blood trail, footsteps proximity) via simple heuristics

\- Randomized scene flavor for roleplay

\- XP \& payout reward system (configurable)

\- Persists investigations to SQL (`dead\_investigations` table)

\- Optional support for `qtarget` / `qb-target` / `ox\_target`

\- No continuous polling — event-driven design (short live raycasts only)



---



\## Quick install

1\. Copy the `deadbody\_investigator/` folder to your server's `resources/\[police]/` (or any folder).

2\. Ensure DB wrapper available (prefer `oxmysql`). If using `mysql-async`, that's detected.

3\. Add `ensure deadbody\_investigator` to `server.cfg`.

4\. Import SQL: `sql/deadbody\_investigator.sql` into your MySQL/MariaDB database.

5\. Configure `config.lua` if needed (job names, rewards, target provider).

6\. (Optional) Integrate with your `qbx\_policejob` to call `deadbody:client:startInvestigation` when a death is reported (see examples/integration\_qbox.lua).



---



\## Files

\- `config.lua` — configuration options

\- `client/main.lua` — client logic + UI integration

\- `server/main.lua` — server DB persistence, reward calculation, permission checks

\- `html/ui/\*` — investigation UI

\- `sql/deadbody\_investigator.sql` — schema (MySQL)

\- `examples/integration\_qbox.lua` — integration snippet

\- `tests/\*` — manual checklist and a simple test runner



---



\## Config highlights

Open `config.lua` to tune:

\- `Config.Framework` — default `qbox`

\- `Config.DetectiveJobs` — list of Qbox job names allowed to investigate

\- `Config.UseTargetProvider` — `'auto'|'none'|'ox\_target'|'qb-target'|'qtarget'`

\- Reward XP / payout ranges

\- Camera settings and UI keys

\- DB table name and DB wrapper preferences



---



\## Events \& Exports (public)

\### Server events

\- `deadbody:server:saveInvestigation` — Save an investigation to DB.

&nbsp; - Payload: `{victim\_type, victim\_identifier, death\_time, estimated\_tod, cause, critical\_area, attacker\_identifier, scene\_data, investigator\_id, xp\_awarded, payout}`

&nbsp; - Returns investigation id via client event response (see example)

\- `deadbody:server:getInvestigation` — Request investigation by ID (server → client response)

&nbsp; - Args: `investigationId`

&nbsp; - Response via `deadbody:client:receiveInvestigation`



\- `deadbody:server:reportDeath` — (optional) register death metadata with server cache for quicker investigations

&nbsp; - Payload: `{netId, victim\_type, victim\_identifier, death\_time, cause, attacker\_identifier, critical\_area}`



\### Client events

\- `deadbody:client:startInvestigation` — Open UI for investigation

&nbsp; - Args: `{ entity\_netId }` or direct entity handle

\- `deadbody:client:highlightCriticalArea` — visually mark ragdoll

&nbsp; - Args: `{ entity, areaString }`

\- `deadbody:client:receiveInvestigation` — server response that returns saved investigation



\### Exports

\- `IsInvestigatable(entity) -> bool` — check if an entity looks investigatable (dead ragdoll)

\- `GetLastInvestigation(playerId) -> table | nil` — returns the last investigation data for this player (server export)



---



\## DB Installation

Import `sql/deadbody\_investigator.sql` into your MySQL/MariaDB database. The SQL uses a JSON column for `scene\_data`. If your DB does not support JSON, the script provides an alternate `scene\_data\_text` fallback.



Default wrapper: `oxmysql`. If only `mysql-async` is available the resource will fallback to that automatically.



---



\## Qbox integration hints

\- Qbox player object: we expect `exports.qbx\_core:GetPlayer(source)` may exist; but to keep this resource standalone we only check job via configurable job names and rely on the server to verify investigators' job via Qbox exports or permissions (see `server/main.lua`).

\- Example integration snippet for `qbx\_policejob` is in `examples/integration\_qbox.lua` (shows how to register death and call `deadbody:client:startInvestigation`).



---



\## Safety \& design tradeoffs

\- \*\*Teleporting\*\* players to scenes is optional and disabled by default. Auto-teleport can be harmful in some servers; toggle in `config.lua`.

\- \*\*Critical area detection\*\*: retrieving the exact bone that was hit reliably for all death events is not trivial across setups; this resource uses available data when provided (via `reportDeath`), otherwise uses heuristics and randomized selection for roleplay. Documented in README and server exports so other systems can feed better data.

\- Minimal runtime overhead — DB writes only on investigation completion.



---



\## Troubleshooting

\- If UI doesn't open: ensure `ui\_page` loaded and that NUI messages appear in console.

\- DB errors: check if `oxmysql` is installed and server.cfg includes credentials. If you use `mysql-async`, restart after enabling resource so fallback is detected.

\- Target provider not detected: set `Config.UseTargetProvider` explicitly to the provider you have.



---



\## License

MIT (see LICENSE)






Enjoy building crime scenes! 🕵️‍♂️



