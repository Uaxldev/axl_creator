fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'axl_creator'
author 'UnityDev - Axldev'
description 'Character creator UnityDev - Axldev'
version '1.0.0'

-- Interface em HTML/CSS/JS puro: pra mexer, edite os arquivos em nui/ e
-- reinicie o resource. Não tem passo de build.
ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/*.css',
    'nui/js/*.js',
    'nui/*.png',
    'nui/*.jpg',
    'nui/*.jpeg',
    'nui/*.svg',
    'nui/*.webp',
    'nui/*.ico',
    'nui/*.mp4',
    'nui/*.webm',
}

shared_scripts {
    '@vrp/lib/utils.lua',
    'config.lua',
    'bridges.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'helpers.lua',
    'server.lua',
}

dependencies {
    'vrp',
    'oxmysql',
    'spawnmanager',
    'axl_spawn',  -- exporta cinematicSpawn (fonte única da cinematic)
}
