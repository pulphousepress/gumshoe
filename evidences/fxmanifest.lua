fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'noobsystems'
description 'Advanced FiveM evidence script'
version '1.0.4'

-- Required dependencies
dependencies {
    '/onesync',
    'oxmysql',
    'ox_lib',
    'ox_inventory',
    'ox_target'
}

-- Client scripts (entry points)
client_scripts {
    'client/init.lua',                         -- main client initializer (contains NUI handlers)
    'client/evidences/evidence_at_coords.lua',
    'client/evidences/utils.lua',              -- <- ensure utils is included for require("client.evidences.utils")
    'client/evidences/evidences.lua',         -- <- ensure evidences module is included for require("client.evidences.evidences")
    'client/dui/laptops/sync.lua'
}

-- Server scripts (entry points)
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/init.lua'
}

-- Shared scripts / libraries
shared_scripts {
    '@ox_lib/init.lua'
}

files {
    'locales/*.json',
    'config.lua',

    'common/*.lua',
    'common/events/**.lua',
    'common/frameworks/**/client.lua',
    'common/frameworks/framework.lua',

    'html/dui/laptop/dist/index.html',
    'html/dui/laptop/dist/assets/*',
    'html/dui/laptop/dist/*.png',
    'html/dui/laptop/dist/*.mp3',

    'html/dui/scanner/**',
    'html/nui/**'
}

ui_page 'html/dui/laptop/dist/index.html'
