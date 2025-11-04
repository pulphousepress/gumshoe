local Config = {
    Version = "1.0.0",
    Framework = "qbx", -- qbx, qbox, la_core, standalone
    FrameworkOptions = {
        qbx = {
            PlayerExport = "qbx_core:GetPlayer"
        },
        la_core = {
            PlayerLookupExport = "la_core:getPlayerData"
        }
    },
    DetectiveJobs = {
        "police",
        "detective"
    },
    UseTargetProvider = {
        Enabled = false,
        Provider = "auto", -- auto, ox_target, qtarget, qb-target
        InteractionDistance = 1.2,
        Providers = {
            ox_target = {
                Resource = "ox_target"
            },
            ["qb-target"] = {
                Resource = "qb-target"
            },
            qtarget = {
                Resource = "qtarget"
            }
        }
    },
    Rewards = {
        XP = { min = 10, max = 30 },
        Cash = { min = 50, max = 150 }
    },
    DB = {
        Table = "gumshoe_investigations",
        Driver = "auto", -- auto, oxmysql, mysql-async
        Schema = "gumshoe",
    },
    AutoTeleport = {
        Enabled = false,
        SafeCoords = { x = 441.1, y = -982.7, z = 30.6, heading = 90.0 }
    },
    Integrations = {
        la_core = {
            Enabled = true,
            PermissionGroup = "command"
        },
        la_codex = {
            Enabled = true,
            WeaponLookupExport = "la_codex:getWeaponData"
        },
        la_engine = {
            Enabled = true,
            EventPrefix = "la_engine:gumshoe"
        },
        la_rp_casefiles = {
            Enabled = true,
            LinkingTable = "casefile_investigations"
        }
    },
    Logging = {
        Level = "info",
        Hook = nil,
        ForwardToTxAdmin = false
    }
}

return Config
