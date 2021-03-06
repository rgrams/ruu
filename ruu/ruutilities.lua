
local M = {}

local PIVOT_VEC = { -- Vector from node center to pivot point.
	[gui.PIVOT_CENTER] = vmath.vector3(0, 0, 0),
	[gui.PIVOT_N] = vmath.vector3(0, 0.5, 0),
	[gui.PIVOT_NE] = vmath.vector3(0.5, 0.5, 0),
	[gui.PIVOT_E] = vmath.vector3(0.5, 0, 0),
	[gui.PIVOT_SE] = vmath.vector3(0.5, -0.5, 0),
	[gui.PIVOT_S] = vmath.vector3(0, -0.5, 0),
	[gui.PIVOT_SW] = vmath.vector3(-0.5, -0.5, 0),
	[gui.PIVOT_W] = vmath.vector3(-0.5, 0, 0),
	[gui.PIVOT_NW] = vmath.vector3(-0.5, 0.5, 0)
}
M.PIVOT_VEC = PIVOT_VEC

function M.getCenterPos(node) -- Pivot-independent get_position.
	local pivotVec = PIVOT_VEC[gui.get_pivot(node)]
	local size = gui.get_size(node)
	local px, py = pivotVec.x * size.x, pivotVec.y * size.y
	local pos = gui.get_position(node)
	pos.x, pos.y = pos.x - px, pos.y - py
	return pos
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

function M.getTopWidget(widgetDict, wgtNodeKey, layerDepths, conditionFn) -- find widget with highest drawIndex
	local maxIdx, topWidget = -1, nil
	for widget,_ in pairs(widgetDict) do
		local node = widget[wgtNodeKey]
		local drawIdx = M.getDrawIndex(node, layerDepths)
		if drawIdx > maxIdx then
			if conditionFn then
				if conditionFn(widget) then
					maxIdx = drawIdx
					topWidget = widget
				end
			else
				maxIdx = drawIdx
				topWidget = widget
			end
		end
	end
	return topWidget
end


return M
