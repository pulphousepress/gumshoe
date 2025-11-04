fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Kurlie'
version '1.0.0'

client_script 'client/client.lua'
server_script {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/*.**',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

escrow_ignore {
    'client/client.lua',
    'server/server.lua',
    'html/*.**',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
dependency '/assetpacks'