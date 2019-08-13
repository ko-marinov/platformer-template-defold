require "modules.common"
local moduleFsm = require "modules.fsm"

local function reset_attack_tag(fsm)
	--fsm.attack_anim_in_progress = false
	msg.post(".", msgtype_tag, { id = tag_attack, value = false })
end

local function playAnim(fsm, animId)
	-- when interrupt animation "animation_done" is not come
	-- so reset all flags manually
	reset_attack_tag(fsm)
	msg.post(fsm.anim_controller, "anim_request", { animId = animId })
end

local function TryGetNameFromWeaponStats(weaponStats)
	if type(weaponStats) == "table" and type(weaponStats.animSet) == "string" then
		return "FSM:" .. weaponStats.animSet
	end
	return nil
end

local M = {}

--[[
weaponStats = {
	prepTime	= 0.5,									-- time before hit
	relaxTime	= 0.5,									-- time after hit and before next hit
	animSet 	= "sword",								-- set of owner's animations
	animNum 	= 3,									-- number of animations in animation set
	hitLogic	= function(relaxTransitionClbk) end		-- actions to do on hit
}

hitLogic takes [relaxTransitionClbk] as a param to call it after hit actions comleted
Calling [relaxTransitionClbk] causes transition from hit to relax
--]]

function M.new(anim_controller, weaponStats, dbgName)
	local fsm = moduleFsm.create({
		initial = "IDLE",
		events = {
			{ name = "prepare",		from = "IDLE",			to = "PREPARATION"	},
			{ name = "attack",		from = "PREPARATION",	to = "HIT"			},
			{ name = "relax",		from = "HIT",			to = "RELAX"		},
			{ name = "idle",		from = "RELAX",			to = "IDLE"			},
			{ name = "abort",		from = "PREPARATION",	to = "IDLE"			}
		},
		dbgName = dbgName or TryGetNameFromWeaponStats(weaponStats) or "FSM:Attack"
	})

	fsm.anim_controller = anim_controller
	fsm.weaponStats		= weaponStats
	fsm.prepTimer		= timer.INVALID_TIMER_HANDLE
	fsm.relaxTimer		= timer.INVALID_TIMER_HANDLE
	
	fsm.attack_num 				= 0
	fsm.attack_request 			= false
	fsm.attack_anim_in_progress = false

	-- INTERFACE --
	
	fsm.requestAttack = function()
		if type(fsm.weaponStats) ~= "table" then
			print("NO WEAPON!")
			return
		end
		fsm:prepare()
	end

	fsm.abort = function()
		fsm:abort()
	end

	fsm.isAttacking = function()
		return fsm.current ~= "IDLE" -- "PREPARATION" or fsm.current == "HIT"
	end

	-- INTERNAL LOGIC -- --TODO: Mark some code as private by comments - smells

	fsm.onPREPARATION = function(event, from, to)
		-- chose animation
		fsm.attack_num = math.fmod(fsm.attack_num, fsm.weaponStats.animNum) + 1
		local animId = hash(fsm.weaponStats.animSet .. "_prep_" .. fsm.attack_num)

		-- start animation
		playAnim(fsm, animId)

		-- start timer
		assert(fsm.prepTimer == timer.INVALID_TIMER_HANDLE)
		fsm.prepTimer = timer.delay(fsm.weaponStats.prepTime, false, fsm.EnterHitState)
		
		msg.post(".", msgtype_tag, { id = tag_attack, value = true })
	end

	fsm.onHIT = function(event, from, to)
		local animCounter = 1
		local animId = hash(fsm.weaponStats.animSet .. "_hit_" .. fsm.attack_num)

		-- start animation
		playAnim(fsm, animId)
		
		fsm.weaponStats.hitLogic("relax", fsm)
	end

	fsm.onRELAX = function(event, from, to)
		local animCounter = 1
		local animId = hash(fsm.weaponStats.animSet .. "_relax_" .. fsm.attack_num)

		-- start animation
		playAnim(fsm, animId)

		-- start timer
		assert(fsm.relaxTimer == timer.INVALID_TIMER_HANDLE)
		fsm.relaxTimer = timer.delay(fsm.weaponStats.relaxTime, false, fsm.EnterIdleState)
	end

	fsm.EnterHitState = function(self, handle, time_elapsed)
		timer.cancel(fsm.prepTimer)
		fsm.prepTimer = timer.INVALID_TIMER_HANDLE
		fsm:attack()
	end

	fsm.EnterIdleState = function(self, handle, time_elapsed)
		timer.cancel(fsm.relaxTimer)
		fsm.relaxTimer = timer.INVALID_TIMER_HANDLE
		fsm:idle()
	end

	fsm.SetWeaponStats = function(weaponStats)
		fsm.weaponStats = weaponStats
		-- TODO: validate?		
	end

	-- MESSAGE HANDLING --

	fsm.onmessageIDLE = function(message_id, message, sender)
		-- handle anim done
	end

	fsm.onmessagePREPARATION = function(message_id, message, sender)
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