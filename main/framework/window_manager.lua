local M = {}

-- These are set from the render script. Defined here for autocomplete purposes
M.worldHalfx = 400
M.worldHalfy = 275
M.halfx = 400
M.halfy = 275

M.scale = 1 -- view scale factor from render script
M.barOffset = vmath.vector3() -- x, y size of black bars outside viewport

M.playerPos = vmath.vector3()

function M.mouse_to_world(mx, my) -- Uses screen_x, screen_y
	return (mx - M.halfx)/M.scale, (my - M.halfy)/M.scale
end

return M
