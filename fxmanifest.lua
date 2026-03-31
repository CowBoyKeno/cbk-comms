fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'cbk-comms'
author 'CowBoyKeno'
description 'Standalone, Secure, departmental radio communications system for public FiveM servers'
version '1.0.0'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/app.css',
    'ui/app.js',
    'ui/fonts/Heebo-Regular.ttf',
    'ui/fonts/Heebo-Bold.ttf',
    'ui/images/field-frame.png'
}

shared_scripts {
    'config.lua',
    'config/*.lua',
    'shared/*.lua'
}

server_scripts {
    'server/services/*.lua',
    'server/departments/*.lua',
    'server/main.lua'
}

client_scripts {
    'client/*.lua'
}
