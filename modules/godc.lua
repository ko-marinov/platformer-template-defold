-- Game Objects Data Container

local M = {}

local godc = {}

function M.register(id, data)
	godc[id] = data
end

function M.unregister(id)
	godc[id] = nil
end

function M.getInCircle(mask)
	local result = {}
	for k, v in pairs(godc) do
		
	end
end

return M