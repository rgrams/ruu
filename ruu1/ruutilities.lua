
local M = {}


M.layerPrecision = 1000 -- number of different nodes allowed in each layer
-- layer index multiplied by this in get_draw_index() calculation

-- ---------------------------------------------------------------------------------
--| 					  	LOOPING DICTIONARY FUNCTIONS							|
-- ---------------------------------------------------------------------------------
-- for getting adjacent nodes in a neighbor map

function M.nextval(t, i) -- looping, used for setting up button list neighbors
	if #t == 0 then return false end
	i = (i + 1) <= #t and (i + 1) or 1
	return t[i]
end

function M.prevval(t, i) -- looping, used for setting up button list neighbors
	if #t == 0 then return false end
	i = (i - 1) >= 1 and (i - 1) or #t
	return t[i]
end

function M.nexti(t, i) -- Next index in array (looping)
	if #t == 0 then return 0 end
	return (i + 1) <= #t and (i + 1) or 1
end

function M.previ(t, i) -- Previous index in array (looping)
	if #t == 0 then return 0 end
	return (i - 1) >= 1 and (i - 1) or #t
end

-- ---------------------------------------------------------------------------------
--| 						  	  BASIC MATH STUFF									|
-- ---------------------------------------------------------------------------------
function M.sign(x)
	return x >= 0 and 1 or -1
end

function M.clamp(x, max, min) -- much more convenient and legible than math.min(math.max(x, min), max)
	return x > max and max or (x < min and min or x)
end

-- ---------------------------------------------------------------------------------
--| 							OTHER NODE UTILITIES								|
-- ---------------------------------------------------------------------------------
local PIVOTS = {
	 [gui.PIVOT_CENTER] = vmath.vector3(0, 0, 0),
	 [gui.PIVOT_N] = vmath.vector3(0, 1, 0),
	 [gui.PIVOT_NE] = vmath.vector3(1, 1, 0),
	 [gui.PIVOT_E] = vmath.vector3(1, 0, 0),
	 [gui.PIVOT_SE] = vmath.vector3(1, -1, 0),
	 [gui.PIVOT_S] = vmath.vector3(0, -1, 0),
	 [gui.PIVOT_SW] = vmath.vector3(-1, -1, 0),
	 [gui.PIVOT_W] = vmath.vector3(-1, 0, 0),
	 [gui.PIVOT_NW] = vmath.vector3(-1, 1, 0)
 }

function M.get_center_position(node) -- pivot-independent get_position for scroll areas
	local pivotVec = PIVOTS[gui.get_pivot(node)]
	local size = gui.get_size(node)
	pivotVec.x = pivotVec.x * size.x * 0.5;  pivotVec.y = pivotVec.y * size.y * 0.5
	return gui.get_position(node) - pivotVec
end

function M.safe_get_node(id)
	if pcall(gui.get_node, id) then
		return gui.get_node(id)
	else
		return nil
	end
end

function M.get_draw_index(node, layers) -- combines layer and index to get an absolute draw index
	local layer = gui.get_layer(node)
	local index = gui.get_index(node)
	local li = layers[layer]
	if not li then
		print("WARNING: ruutil.get_draw_index() - layer not found in list. May not accurately get top widget unless you call ruu.register_layers")
	end
	return (li and (li * M.layerPrecision) or 0) + index
end

function M.get_top_widget(wgtList, wgtNodeKey, layers) -- find widget with highest drawIndex
	local maxI = -1
	local maxWgt = nil
	for i, wgt in ipairs(wgtList) do
		local drawI = M.get_draw_index(wgt[wgtNodeKey], layers)
		if drawI > maxI then
			maxI = drawI
			maxWgt = wgt
		end
	end
	return maxWgt
end


return M
