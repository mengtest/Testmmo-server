local skynet = require "skynet"

local syslog = require "syslog"
local handler = require "agent.handler"
local aoi_handler = require "agent.aoi_handler"


local RPC = {}
local user
handler = handler.new (RPC)

handler:init (function (u)
	user = u
end)

function RPC.move (args)
	assert (args and args.pos)

	local npos = args.pos -- new pos
	local opos = user.character.movement.pos -- old pos
	for k, v in pairs (opos) do
		if not npos[k] then
			npos[k] = v
		end
	end
	user.character.movement.pos = npos -- 保存新的移动位置

	local ok = skynet.call (user.map, "lua", "move_blink", npos)
	if not ok then
		user.character.movement.pos = opos 
		error ()
	end

	return { pos = npos }
end

return handler
