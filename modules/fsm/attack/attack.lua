local moduleFsm = require "modules.fsm"

local M = {}

function M.new()
	local fsm = moduleFsm.create({
		initial = "IDLE",
		events = {
			{ name = "request",		from = "IDLE",			to = "BEFORE_ATTACK"	},
			{ name = "request",		from = "AFTER_ATTACK",	to = "BEFORE_ATTACK"	},
			{ name = "doattack",	from = "BEFORE_ATTACK",	to = "AFTER_ATTACK"		},
			{ name = "finish",		from = "AFTER_ATTACK",	to = "IDLE"				},
			{ name = "abort",		from = "BEFORE_ATTACK",	to = "IDLE"				}
		}
	})

	-- INTERFACE --
	
	fsm.attack = function()
		fsm:request()
	end

	fsm.abort = function()
		fsm:abort()
	end

	fsm.isAttacking = function()
		return fsm.current ~= "IDLE"
	end

	-- INTERNAL LOGIC -- --TODO: Mark some code as private by comments - smells

	fsm.onBEFORE_ATTACK = function(event, from, to)
		-- chose animation
		-- start animation
	end

	fsm.onAFTER_ATTACK = function(event, from, to)
		-- recover before next attack
	end

	-- MESSAGE HANDLING --

	fsm.onmessageIDLE = function(message_id, message, sender)
		-- handle anim done
	end

	fsm.onmessageBEFORE_ATTACK = function(message_id, message, sender)
		-- attack (do melee damage, throw arrow, cast fireball, etc.)
	end
	
	fsm.on_message = function(message_id, message, sender)
		if message_id == msgtype_param or message_id == msgtype_tag then
			if fsm.blackboard[message.id] ~= nil then		-- to avoid blackboard polution
				assert(message.value ~= nil)
				fsm.blackboard[message.id] = message.value
			end
		else
			local messagehandler = "onmessage" .. fsm.current
			if fsm[messagehandler] ~= nil then
				fsm[messagehandler](message_id, message, sender)
			end
		end
	end

	return fsm
end

return M