# Manual Test Checklist - la_gumshoe

1. Installation
   - [ ] Place resource in `resources/[los_animales]/la_gumshoe` (or your chosen folder)
   - [ ] Ensure `ensure la_gumshoe` in server.cfg
   - [ ] Import `sql/gumshoe.sql` into DB (or run provided SQL)
   - [ ] Start server and check server console has no lua errors

2. Basic usage (no target provider)
   - [ ] Spawn an NPC and kill it (or use test runner)
   - [ ] On client, aim at corpse and run `/investigate`
   - [ ] UI opens with victim/cause/estimated TOD and clues
   - [ ] Click "Record Investigation" → server should write to DB and client should see saved message
   - [ ] Inspect DB `dead_investigations` table row

3. Qbox integration
   - [ ] Configure `Config.DetectiveJobs` and ensure a player with that job can use `/investigate` and save investigations
   - [ ] Players without allowed jobs cannot use detective commands (tested by server logic or integrations)

4. Target provider (optional)
   - [ ] Install one of qtarget/ox_target / qb-target and set `Config.UseTargetProvider='auto'` or explicit provider
   - [ ] Verify right-click targeting triggers `la_gumshoe:client:startInvestigation` (requires adding qbtarget glue in your server code)

5. Replay camera / teleport (optional)
   - [ ] After saving, test `la_gumshoe:server:getInvestigation` and verify you can fetch scene coordinates and use them to show or teleport (teleport disabled by default)

6. Tests
   - [ ] Run `tests/test_runner.lua` to simulate a corpse and investigation (automated simulation)

Notes:
- If DB writes fail, verify `oxmysql` or `mysql-async` and credentials.
- All interactions are event-driven; if your server uses different death events, ensure to call `la_gumshoe:server:reportDeath` to store better metadata.
