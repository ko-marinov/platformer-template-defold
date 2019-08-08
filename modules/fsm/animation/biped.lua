require "modules.common"
local moduleFsm = require "modules.fsm"
local moduleMeleeFsm = require "modules.fsm.attack.melee"

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

local M = {}

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
	--
	-- TODO: Each transition in separate line
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
		}
	})

	-- fsm extension --
	fsm.blackboard					= {}
	fsm.blackboard[param_move]		= 0
	fsm.blackboard[param_vvel]		= 0
	fsm.blackboard[tag_grounded]	= false
	fsm.blackboard[tag_attack]		= false
	fsm.blackboard[tag_hurt]		= false
	fsm.blackboard[tag_dead]		= false

	fsm.meleeFsm					= moduleMeleeFsm.new()
	
	-- on enter state IDLE
	fsm.onIDLE = function(event, from, to)
		playAnim(fsm, hash("idle"))
	end

	-- on enter state IN_MOTION
	fsm.onIN_MOTION = function(event, from, to)
		playAnim(fsm, hash("run"))
	end

	fsm.onbeforeattack = function(event, from, to)
		fsm.meleeFsm.attack()
	end

	fsm.onmessageOFFENSIVE = function(message_id, message, sender)
		fsm.meleeFsm.on_message(message_id, message, sender)
	end

	-- on enter state AIRBORNE
	fsm.onAIRBORNE = function(event, from, to)
		playAnim(fsm, hash("fall"))
	end

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
	fsm.abortMelee = function()
		fsm.meleeFsm.abort()
	end
	
	fsm.tryDie = function()
		if fsm.blackboard[tag_dead] then
			fsm.abortMelee()
			fsm:die()
		end
	end

	fsm.tryTakeDamage = function()
		if fsm.blackboard[tag_hurt] then
			fsm.abortMelee()
			fsm:takedamage()
		end
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

	fsm.updateOffensive = function()
		if fsm.current ~= "OFFENSIVE" and fsm.meleeFsm.isAttacking() then
			fsm:attack()
		elseif fsm.current == "OFFENSIVE" and not fsm.meleeFsm.isAttacking() then
			fsm:finishattack()
		end
	end

	fsm.updateDirection = function()
		if fsm.blackboard[param_move] ~= 0 then
			sprite.set_hflip("#sprite", fsm.blackboard[param_move] < 0)
		end
	end

	fsm.update = function(dt)
		fsm.tryDie()
		fsm.tryTakeDamage()
		fsm.updateAirborne()
		fsm.updateOffensive()
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