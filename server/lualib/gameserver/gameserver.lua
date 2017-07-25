local skynet = require "skynet"

local gateserver = require "gameserver.gateserver"
local syslog = require "syslog"
local protoloader = require "protoloader"
local netpack = require "skynet.netpack"

local Utils = require "proto_2.utils"
local msg_define = require "proto_2.msg_define"
local Packer = require "proto_2.packer"

local gameserver = {}
local pending_msg = {}

function gameserver.forward (fd, agent)
	gateserver.forward (fd, agent)
end

function gameserver.kick (fd)
	gateserver.close_client (fd)
end

function gameserver.start (gamed)
	local handler = {}

	function handler.open (source, conf)
		return gamed.open (conf)
	end

	function handler.connect (fd, addr)
		syslog.noticef ("--- gameserver, connect from %s (fd = %d)", addr, fd)
		gateserver.open_client (fd)
	end

	function handler.disconnect (fd)
		syslog.noticef ("--- gameserver, fd (%d) disconnected", fd)
	end

    local function my_read_msg(fd, msg, sz)
        local msg = netpack.tostring(msg, sz)
        local proto_id, params = string.unpack(">Hs2", msg)
        local proto_name = msg_define.id_2_name(proto_id)
        local paramTab = Utils.str_2_table(params)
        print("--- proto_name:", proto_name)
        print("--- params:", params)
        return proto_name, paramTab
    end

	local function do_login (fd, msg, sz)
		local name, args = my_read_msg(fd, msg, sz)
		-- assert (type == "REQUEST")
		assert (name == "login")
		assert (args.session and args.token)
		local session = tonumber (args.session) or error ()
		local account = gamed.auth_handler (session, args.token) or error ()
		assert (account)
		return account
	end

	local traceback = debug.traceback
	function handler.message (fd, msg, sz)
		local queue = pending_msg[fd]
		if queue then -- 认证期间有多个数据发送上来，存储到队列中待处理
			table.insert (queue, { msg = msg, sz = sz })
		else
			pending_msg[fd] = {}

			local ok, account = xpcall (do_login, traceback, fd, msg, sz) -- 去登陆服认证
			if ok then
				syslog.noticef ("account %d login success", account)
				local agent = gamed.login_handler (fd, account)
				queue = pending_msg[fd]
				for _, t in pairs (queue) do -- 待处理消息逐一处理
					syslog.noticef ("forward pending message to agent %d", agent)
					skynet.rawcall(agent, "client", t.msg, t.sz)
				end
			else
				syslog.warningf ("%s login failed : %s", addr, account)
				gateserver.close_client (fd)
			end

			pending_msg[fd] = nil
		end
	end

	local CMD = {}

	function CMD.token (id, secret)
		local id = tonumber (id)
		login_token[id] = secret
		skynet.timeout (10 * 100, function ()
			if login_token[id] == secret then
				syslog.noticef ("account %d token timeout", id)
				login_token[id] = nil
			end
		end)
	end

	function handler.command (cmd, ...)
		local f = CMD[cmd]
		if f then
			return f (...)
		else
			return gamed.command_handler (cmd, ...)
		end
	end

	return gateserver.start (handler)
end

return gameserver
