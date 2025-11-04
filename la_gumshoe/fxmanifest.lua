-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'Pulphouse Press'
description 'La Gumshoe - detective UI test + core integration (minimal safe)'
version '1.0.0'

server_script 'server/main.lua'
client_script 'client/main.lua'

ui_page 'html/ui/index.html'
files {
  'html/ui/index.html',
  'html/ui/style.css',
  'html/ui/app.js'
}

dependency 'qbx_core' -- optional
lua54 'yes'

export 'IsInvestigatable'
export 'GetLastInvestigation'
