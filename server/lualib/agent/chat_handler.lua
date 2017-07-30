local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"

local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local database
local chatserver

handler:init (function (u)
	user = u
    database = skynet.uniqueservice ("database")
    chatserver = skynet.uniqueservice ("chat_server")
end)

function RPC.rpc_server_world_chat (args)
    assert(args.msg)
    syslog.debugf("--- chat, nickName:%s, msg:%s, account:%d", user.info.nickName, args.msg, user.account)
    skynet.call(chatserver, "lua", "cmd_chat_world_broadcast", user.account, args.msg)
end

function CMD.cmd_chat_world( account, msg )
    -- local info = skynet.call (database, "lua", "account", "cmd_account_loadInfo", account)
    -- assert(info)
    -- info = dbpacker.unpack(info)

    syslog.debugf("--- cmd_chat_world, account:%s, msg:%s", account, msg)
    user.send_request ("rpc_client_word_chat", { account = account, nickName = "TestName", msg = msg })

end

return handler

