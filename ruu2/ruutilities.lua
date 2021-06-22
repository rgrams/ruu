
local M = {}

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

function M.getCenterPos(node) -- pivot-independent get_position for scroll areas
	local pivotVec = PIVOTS[gui.get_pivot(node)]
	local size = gui.get_size(node)
	pivotVec.x = pivotVec.x * size.x * 0.5;  pivotVec.y = pivotVec.y * size.y * 0.5
	return gui.get_position(node) - pivotVec
end

function M.safeGetNode(id)
	if pcall(gui.get_node, id) then
		return gui.get_node(id)
	else
		return nil
	end
end

function M.getDrawIndex(node, layerDepths) -- combines layer and index to get an absolute draw index
	local layer = gui.get_layer(node)
	local index = gui.get_index(node)
	local layerDepth = layerDepths[layer]
	if not layerDepth then
		print("WARNING: ruutil.getDrawIndex() - layer not found in list. May not accurately get top widget unless you call ruu.registerLayers")
		return index
	end
	return layerDepth + index
end

function M.getTopWidget(widgetDict, wgtNodeKey, layerDepths) -- find widget with highest drawIndex
	local maxIdx, topWidget = -1, nil
	for widget,_ in pairs(widgetDict) do
		local node = widget[wgtNodeKey]
		local drawIdx = M.getDrawIndex(node, layerDepths)
		if drawIdx > maxIdx then
			maxIdx = drawIdx
			topWidget = widget
		end
	end
	return topWidget
end


return M
