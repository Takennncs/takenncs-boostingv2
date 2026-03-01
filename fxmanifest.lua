fx_version 'cerulean'
game 'gta5'

author 'takenncs'
description 'Advanced Boosting System v3.0'

ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/levels.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

files {
    'web/index.html',
    'web/script.js'
}

lua54 'yes'