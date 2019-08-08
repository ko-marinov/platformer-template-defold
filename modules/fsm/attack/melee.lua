local attackFsm = require "modules.fsm.attack.attack"

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
	local fsm = attackFsm.new()

	fsm.attack_num 				= 1
	fsm.attack_request 			= false
	fsm.attack_anim_in_progress = false

	-- INTERNAL LOGIC -- --TODO: Mark some code as private by comments - smells

	fsm.onBEFORE_ATTACK = function(event, from, to)
		local attackAnim = hash("attack" .. fsm.attack_num)
		playAnim(fsm, attackAnim)
		msg.post(".", msgtype_tag, { id = tag_attack, value = true })
		fsm.attack_request = false
		fsm.attack_anim_in_progress = true
		fsm.attack_num = math.fmod(fsm.attack_num, 3) + 1
	end

	fsm.onAFTER_ATTACK = function(event, from, to)
		reset_attack_tag(fsm)
		fsm:finish()
	end

	-- MESSAGE HANDLING --

	fsm.onmessageIDLE = function(message_id, message, sender)
		-- handle anim done
	end

	fsm.onmessageBEFORE_ATTACK = function(message_id, message, sender)
		if message_id == hash("animation_done") then
			fsm:doattack()
		end
	end
	
	return fsm
end

return M