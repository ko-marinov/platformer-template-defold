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
	-------------------------------------------------------------------------------------------------
	-- ** Name convention **
	--
	-- I. Events
	--
	-- 1. Active verb
	-- 2, Lowercase
	-- 3. In one word
	-- Examples: attack, fall, die, takedamage
	--
	-- II. States
	--
	-- 1. Clear nouns without '-ing' and '-ed'
	-- 2. Uppercase
	-- 3. Words splitted up by underscores
	-- Examples: OFFENSIVE (instead of ATTACKING ('-ing' is forbidden) or ATTACK (unclear, 'to attack'))
	--           IN_AIR or AIRBORNE (instead of FALLING or FALL)
	--           IDLE (its known word for inactivity state, so there is no ambiguity)
	-------------------------------------------------------------------------------------------------

	local fsm = moduleFsm.create({
		initial = "IDLE",
		events = {
			{ name = "run", 			from = "IDLE", 									to = "IN_MOTION"	},
			{ name = "stop",  			from = "IN_MOTION", 							to = "IDLE" 		},
			{ name = "attack", 			from = { "IDLE", "IN_MOTION", "OFFENSIVE" },	to = "OFFENSIVE"	},
			{ name = "finishattack",	from = { "OFFENSIVE" },							to = "IDLE" 		},
			{ name = "fall", 			from = { "IDLE", "IN_MOTION", "OFFENSIVE" }, 	to = "AIRBORNE"		},
			{ name = "takedamage", 		from = "*", 									to = "INJURY"		},
			{ name = "die", 			from = "*", 									to = "DEATH" 		},
			{ name = "land", 			from = "AIRBORNE", 								to = "IDLE" 		},
			{ name = "toidle",	 		from = "*", 									to = "IDLE" 		}
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
	-- Attack should be processed in its own sub-fsm
	fsm.attack_num 				= 1
	fsm.attack_request 			= false
	fsm.attack_anim_in_progress = false

	-- on enter state IDLE
	fsm.onIDLE = function(event, from, to)
		playAnim(fsm, hash("idle"))
	end

	--fsm.onupdateIDLE = function(dt)
	--	local b = fsm.blackboard
	--	if b[tag_hurt] then
	--		fsm:takedamage()
	--	elseif not b[tag_grounded] then
	--		fsm:fall()
	--	elseif b[param_move] ~= 0 then
	--		fsm:run()
	--	end
	--end

	-- on enter state IN_MOTION
	fsm.onIN_MOTION = function(event, from, to)
		playAnim(fsm, hash("run"))
	end

	--fsm.onupdateIN_MOTION = function(dt)
	--	local b = fsm.blackboard
	--	if b[tag_hurt] then
	--		fsm:takedamage()
	--	elseif not b[tag_grounded] then
	--		fsm:fall()
	--	elseif b[param_move] == 0 then
	--		fsm:stop()
	--	end
	--end

	fsm.onOFFENSIVE = function(event, from, to)
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

	fsm.onmessageOFFENSIVE = function(message_id, message, sender)
		if message_id == hash("animation_done") then
			reset_attack_tag(fsm)
			if fsm.attack_request == true then
				fsm:attack()
			else
				fsm:finishattack()
			end
		end
	end

	-- on enter state AIRBORNE
	fsm.onAIRBORNE = function(event, from, to)
		playAnim(fsm, hash("fall"))
	end

	--fsm.onupdateAIRBORNE = function(dt)
	--	local b = fsm.blackboard
	--	if b[tag_hurt] then
	--		fsm:takedamage()
	--	elseif b[tag_grounded] then
	--		fsm:land()
	--	end
	--end

	-- on enter state INJURY
	fsm.onINJURY = function(event, from, to)
		playAnim(fsm, hash("hurt"))
		msg.post(".", msgtype_tag, { id = tag_hurt, value = true })
	end

	fsm.onbeforetakedamage = function(event, from, to)
		if fsm.current == "INJURY" or fsm.current == "DEATH" then
			return false
		end

		return true
	end

	fsm.onmessageINJURY = function(message_id, message, sender)
		if message_id == hash("animation_done") then
			msg.post(".", msgtype_tag, { id = tag_hurt, value = false })
			fsm:toidle()
		end
	end

	-- on enter state DEATH
	fsm.onDEATH = function(event, from, to)
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
	fsm.tryDie = function()
		if fsm.blackboard[tag_dead] then fsm:die() end
	end

	fsm.tryTakeDamage = function()
		if fsm.blackboard[tag_hurt] then fsm:takedamage() end
	end

	fsm.updateAirborne = function()
		if fsm.blackboard[tag_grounded] then 
			fsm:land()
		else
			fsm:fall()
		end
	end

	fsm.updateMovement = function()
		if fsm.blackboard[param_move] == 0 then
			fsm:stop()
		else
			fsm:run()
		end
	end

	fsm.updateDirection = function()
		if fsm.blackboard[param_move] ~= 0 then
			sprite.set_hflip("#sprite", fsm.blackboard[param_move] < 0)
		end
	end

	fsm.update = function(dt)
		-- local updatehandlername = "onupdate" .. fsm.current
		-- if fsm[updatehandlername] ~= nil then
		-- 	fsm[updatehandlername](fsm, dt)
		-- end
		-- if fsm.blackboard[param_move] ~= 0 then
		-- 	sprite.set_hflip("#sprite", fsm.blackboard[param_move] < 0)
		-- end
		fsm.tryDie()
		fsm.tryTakeDamage()
		fsm.updateAirborne()
		fsm.updateMovement()
		fsm.updateDirection()
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
					fsm:takedamage()
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