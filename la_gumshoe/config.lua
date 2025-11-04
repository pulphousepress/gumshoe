-- config.lua (minimal safe defaults)
Config = {}

Config.Framework = "qbox"
Config.DetectiveJobs = { "police", "detective" }

-- UI enabled (we need this to test)
Config.EnableUI = true

-- Keys & safety
Config.OpenKey = 'f2'
Config.ForceCloseKey = 'f7'     -- local (may not work while NUI has focus)
Config.NUISafetyTimeout = 25    -- seconds; auto-unfocus after this time
Config.UICloseOnSave = true

-- DB table name
Config.DBTable = 'dead_investigations'

-- XP/payout defaults (for server save)
Config.XP = { min = 10, max = 30 }
Config.Payout = { min = 50, max = 150 }

Config.Debug = true
Config.LogToConsole = true

return Config
