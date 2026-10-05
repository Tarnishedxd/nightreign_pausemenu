fx_version 'cerulean'
game 'gta5'

name 'nightreign_pausemenu'
author 'laot'
description 'Nightreign pause menu'
version '1.0.0'

client_scripts {
    'ltbridge/modules/client.lua',
    'modules/**/client.lua',
    'client.lua'
}

server_scripts {
    'ltbridge/modules/server.lua',
    '@oxmysql/lib/MySQL.lua',
    'modules/**/server.lua',
}

shared_scripts {
    'ltbridge/modules/shared.lua',
    '@ox_lib/init.lua',
    'shared/*.lua'
}

files {
    'ltbridge/modules/imports/**/*.lua',
    'config/*.lua',
    'locales/*.json',
    'web/build/*.*',
    'web/build/**/*.*',
}
ui_page 'web/build/index.html'


dependencies {
    'ox_lib',
    'oxmysql',
}

escrow_ignore {
    '**/*.lua'
}

dependency '/assetpacks'