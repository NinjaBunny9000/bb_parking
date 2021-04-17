fx_version 'cerulean'

game 'gta5'

description 'BadBunny\'s Parking System''

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'shared/helpers.lua',
	'shared/config.lua',
	'server/main.lua'
}

client_scripts {
	'@PolyZone/client.lua',
	'@PolyZone/BoxZone.lua',
	'@PolyZone/EntityZone.lua',
	'@PolyZone/CircleZone.lua',
	'@PolyZone/ComboZone.lua',
	'@menuv/menuv.lua',
	'shared/helpers.lua',
	'shared/config.lua',
	'client/zones.lua',
	'client/main.lua'
}
