local M = {}

require "modules.common"

local MAX_HSPEED = 200
local MAX_VSPEED = 200
local JUMP_IMPULSE = 250

function printVec(v, name)
	local str = ""
	if name ~= nil then
		str = name .. ": "
	end
	---print(str .. "(" .. v.x .. ", " .. v.y .. ", " .. v.z .. ")")
end

-- TODO: calc velocity via dx/dt + use acceleration
local function update_velocity(mv, dt)
	local v = mv.velocity

	if mv.inRoll then
		v.x = mv.look_dir * MAX_HSPEED * 1.5
		v.y = 0
	else
		-- Vertical velocity
		if mv.ground_contact and v.y <= 0 then
			v.y = 0
		else
			v.y = v.y + mv.gravity * dt
			if v.y < -MAX_VSPEED then
				v.y = -MAX_VSPEED
			end
		end

		-- Horizontal velocity
		-- Control > smoothness
		if mv.dir == 0 then
			v.x = 0
		else
			v.x = mv.dir * MAX_HSPEED
		end
	end
	mv.velocity = v
end

local function handle_obstacle_contact(mv, position, normal, distance)
	local pos = go.get_position() + mv.offset

	-- find sprite's bottom Y-coordinate
	local offsetX = mv.size.x / 2 - 1
	local offsetY = mv.size.y / 2 - 0.5
	local worldThresholdY      = pos.y - offsetY
	local worldThresholdRightX = pos.x + offsetX
	local worldThresholdLeftX  = pos.x - offsetX
	if distance > 0 then
		-- First, project the accumulated correction onto
		-- the penetration vector
		local vVec = vmath.vector3(0, 1, 0)
		local ddd = vmath.project(vVec, normal)
		if ddd < 0.5 and position.y < worldThresholdY then 
			return 
		end

		if ddd > 0.7 and position.x < worldThresholdLeftX then 
			return 
		end

		if ddd > 0.7 and position.x > worldThresholdRightX then 
			return
		end
		
		local proj = vmath.project(mv.correction, normal * distance)
		if proj < 1 then
			-- Only care for projections that does not overshoot.
			local comp = (distance - distance * proj) * normal
			-- Apply compensation
			go.set_position(go.get_position() + comp)
			-- Accumulate correction done
			mv.correction = mv.correction + comp
		end
	end
end

function M.new(g, collisionBoxOffset, collisionBoxSize)
	local mv = {
		-- place members here
		frame_num = 0,
		dir = 0,
		look_dir = 0,
		inRoll = false,
		correction = vmath.vector3(),
		velocity = vmath.vector3(0, 0, 0),
		ground_contact = false,
		gravity = g,
		offset = collisionBoxOffset,
		size = collisionBoxSize
	}

	mv.StartRoll = function()
		mv.inRoll = true
	end

	mv.StopRoll = function()
		mv.inRoll = false
	end

	mv.update = function(dt)
		update_velocity(mv, dt)
		go.set_position(go.get_position() + mv.velocity * dt)
		msg.post(".", msgtype_param, { id = param_vvel, value = mv.velocity.y })

		mv.correction = vmath.vector3()
		mv.frame_num = mv.frame_num + 1
	end

	mv.on_message = function(message_id, message, sender)
		if message_id == hash("contact_point_response") then
			if message.group == hash("level") then
				handle_obstacle_contact(mv, message.position, message.normal, message.distance)
			end
		elseif message_id == msgtype_param then
			if message.id == param_move then
				mv.dir = message.value
				if mv.dir ~= 0 then
					mv.look_dir = mv.dir
				end
			end
		elseif message_id == msgtype_tag then
			if message.id == tag_grounded then
				mv.ground_contact = message.value
			end
		elseif message_id == msgtype_trigger then
			if message.id == trigger_damage then
				-- handle on damage received
			elseif message.id == trigger_jump then
				mv.velocity.y = JUMP_IMPULSE
			end
		elseif message_id == hash("die") then

		end
	end

	return mv
end

return M