fx_version 'cerulean'
game 'gta5'

author 'Iga / gs-reports'
description 'Reports system with React NUI, MySQL, ox_lib notify, goto/bring helpers, Discord webhook'
version '1.1.0'

lua54 'yes'

ui_page 'web/dist/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'web/dist/index.html',
    'web/dist/assets/*',
}
