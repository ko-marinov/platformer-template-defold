local M = {}

local moduleFsm = require "modules.fsm.animation.biped"

function M.new(anim_controller)
	local fsm = moduleFsm.new(anim_controller, "FSM:PlayerAnim")
	return fsm
end

return M