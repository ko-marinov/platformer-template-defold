local M = {}

local moduleFsm = require "modules.fsm.animation.biped"

function M.new()
	local fsm = moduleFsm.new()
	return fsm
end

return M