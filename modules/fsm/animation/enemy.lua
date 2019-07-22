local M = {}

require "modules.common"
local moduleFsm = require "modules.fsm"

local function reset_attack_tag(fsm)
	fsm.attack_anim_in_progress = false
	msg.post(".", msgtype_tag, { id = tag_attack, value = false })
end

local function playAnim(fsm, anim_id)
	-- when interrupt animation "animation_done" is not come
	-- so reset all flags manually
	reset_attack_tag(fsm)
	msg.post("#sprite", "play_animation", { id = anim_id })
end

function M.new()
	-------------------------------------------------------------------------------------------------
	----------------------------- Player animation finite state machine -----------------------------
	local fsm = moduleFsm.create({
		initial = "idle",
		events = { -- TODO: event/state naming convention
			{ name = "startrun", 		from = "idle", 								to = "running"		},
			{ name = "stoprun",  		from = "running", 							to = "idle" 		},
			{ name = "attack", 			from = { "idle", "running", "attacking" },	to = "attacking"	},
			{ name = "attackfinished",	from = { "attacking" },						to = "idle" 		},
			{ name = "fall", 			from = { "idle", "running", "attacking" }, 	to = "falling"		},
			{ name = "damaged", 		from = "*", 								to = "hurt"			},
			{ name = "death", 			from = "*", 								to = "dead" 		},
			{ name = "stopfall", 		from = "falling", 							to = "idle" 		},
			{ name = "toidle",	 		from = "*", 								to = "idle" 		},
			{ name = "jump",			from = { "idle", "running" },				to = "jumpup"		}
		},
	})
	
	-- fsm extension --
	fsm.blackboard					= {}
	fsm.blackboard[param_move]		= 0
	fsm.blackboard[param_vvel]		= 0
	fsm.blackboard[tag_grounded]	= false
	fsm.blackboard[tag_attack]		= false
	fsm.blackboard[tag_hurt]		= false
	fsm.blackboard[tag_dead]		= false
	
	
	-- TODO: temporary implementation, attack MUST be refactored
	-- on enter state attack1
	fsm.attack_num 				= 1
	fsm.attack_request 			= false
	fsm.attack_anim_in_progress = false
	
	-- on enter state idle
	fsm.onidle = function(event, from, to)
		playAnim(fsm, hash("idle"))
	end
	
	fsm.onupdateidle = function(dt)
		local b = fsm.blackboard
		if b[tag_dead] then
			fsm:death()
		elseif b[tag_hurt] then
			fsm:damaged()
		elseif not b[tag_grounded] then
			fsm:fall()
		elseif b[param_move] ~= 0 then
			fsm:startrun()
		end
	end
	
	-- on enter state running
	fsm.onrunning = function(event, from, to)
		playAnim(fsm, hash("run"))
	end
	
	fsm.onupdaterunning = function(dt)
		local b = fsm.blackboard
		if b[tag_dead] then
			fsm:death()
		elseif b[tag_hurt] then
			fsm:damaged()
		elseif not b[tag_grounded] then
			fsm:fall()
		elseif b[param_move] == 0 then
			fsm:stoprun()
		end
	end
	
	fsm.onattacking = function(event, from, to)
		local attackAnim = hash("attack" .. fsm.attack_num)
		playAnim(fsm, attackAnim)
		msg.post(".", msgtype_tag, { id = tag_attack, value = true })
		fsm.attack_request = false
		fsm.attack_anim_in_progress = true
		fsm.attack_num = math.fmod(fsm.attack_num, 3) + 1
	end
	
	fsm.onbeforeattack = function(event, from, to)
		if fsm.attack_anim_in_progress then
			fsm.attack_request = true
			return false
		end
	
		return true
	end
	
	fsm.onmessageattacking = function(message_id, message, sender)
		if message_id == hash("animation_done") then
			reset_attack_tag(fsm)
			if fsm.attack_request == true then
				fsm:attack()
			else
				fsm:attackfinished()
			end
		end
	end
	
	-- on enter state falling
	fsm.onfalling = function(event, from, to)
		playAnim(fsm, hash("fall"))
	end
	
	fsm.onupdatefalling = function(dt)
		local b = fsm.blackboard
		if b[tag_dead] then
			fsm:death()
		elseif b[tag_hurt] then
			fsm:damaged()
		elseif b[tag_grounded] then
			fsm:stopfall()
		end
	end
	
	-- on enter state hurt
	fsm.onhurt = function(event, from, to)
		playAnim(fsm, hash("hurt"))
		msg.post(".", msgtype_tag, { id = tag_hurt, value = true })
	end
	
	fsm.onmessagehurt = function(message_id, message, sender)
		if message_id == hash("animation_done") then
			msg.post(".", msgtype_tag, { id = tag_hurt, value = false })
			fsm:toidle()
		end
	end
	
	-- on enter state dead
	fsm.ondead = function(event, from, to)
		playAnim(fsm, hash("die"))
	end
	
	-- For debug purpose --
	fsm.onstatechange = function(fsm, event, from, to) 
		print("[PlayerAnimFsm] event: " .. event .. ", transition: " .. from .. " --> " .. to) 
	end
	
	----------------------------------------------
	-- fsm extension 							--
	-- can be added into module					--
	----------------------------------------------
	fsm.update = function(dt)
		local updatehandlername = "onupdate" .. fsm.current
		if fsm[updatehandlername] ~= nil then
			fsm[updatehandlername](fsm, dt)
		end
		if fsm.blackboard[param_move] ~= 0 then
			sprite.set_hflip("#sprite", fsm.blackboard[param_move] < 0)
		end
	end
	
	fsm.on_message = function(message_id, message, sender)
		if message_id == msgtype_param or message_id == msgtype_tag then
			if fsm.blackboard[message.id] ~= nil then		-- to avoid blackboard polution
				assert(message.value ~= nil)
				fsm.blackboard[message.id] = message.value
			end
		else
			if message_id == msgtype_trigger then
				if message.id == trigger_attack then
					fsm:attack()
				elseif message.id == trigger_damage then
					fsm:damaged()
				end
			end
			local messagehandler = "onmessage" .. fsm.current
			if fsm[messagehandler] ~= nil then
				fsm[messagehandler](message_id, message, sender)
			end
		end
	end

	return fsm
end

return M