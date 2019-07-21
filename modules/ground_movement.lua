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

local function update_velocity(mv, dt)
	local v = mv.velocity

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
	mv.velocity = v
end

local function handle_obstacle_contact(mv, normal, distance)
	if distance > 0 then
		-- First, project the accumulated correction onto
		-- the penetration vector
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

function M.new(g)
	local mv = {
		-- place members here
		frame_num = 0,
		dir = 0,
		correction = vmath.vector3(),
		velocity = vmath.vector3(0, 0, 0),
		ground_contact = false,
		gravity = g
	}

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
				handle_obstacle_contact(mv, message.normal, message.distance)
			end
		elseif message_id == msgtype_param then
			if message.id == param_move then
				mv.dir = message.value
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