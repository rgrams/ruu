
local Class = require "ruu.base-class"
local defaultTheme = require "ruu.defaultTheme"
local util = require "ruu.ruutilities"

local Ruu = Class:extend()

local Button = require("ruu.widgets.Button")
local ToggleButton = require("ruu.widgets.ToggleButton")
local RadioButton = require("ruu.widgets.RadioButton")
local Slider = require("ruu.widgets.Slider")
local InputField = require("ruu.widgets.InputField")

Ruu.CLICK = hash("touch")
Ruu.ENTER = hash("enter")
Ruu.TEXT = hash("text")
Ruu.DELETE = hash("delete")
Ruu.BACKSPACE = hash("backspace")
Ruu.CANCEL = hash("cancel")
Ruu.NAV_DIRS = {
	[hash("up")] = "up", [hash("down")] = "down", [hash("left")] = "left", [hash("right")] = "right",
	[hash("next")] = "next", [hash("prev")] = "prev"
}
Ruu.END = hash("end")
Ruu.HOME = hash("home")
Ruu.SELECTION_MODIFIER = hash("selection modifier")
local IS_KEYBOARD = true
local IS_NOT_KEYBOARD = false

Ruu.layerPrecision = 10000 -- Number of different nodes allowed in each layer.
-- Layer index multiplied by this in getDrawIndex() calculation.

local function addWidget(self, name, widget)
	self.allWidgets[widget] = name
	self.enabledWidgets[widget] = true
	assert(not self.widgetsByName[name], "Ruu.addWidget - Name conflict with name '"..tostring(name).."'.")
	self.widgetsByName[name] = widget
end

function Ruu.rename(self, oldName, newName)
	local widget = self.widgetsByName[oldName]
	assert(widget, "Ruu.rename - No widget registered with name '"..tostring(oldName).."'.")
	if oldName == newName then  return  end
	assert(not self.widgetsByName[newName], "Ruu.rename - Name conflict with name '"..tostring(newName).."'.")
	self.widgetsByName[oldName] = nil
	self.widgetsByName[newName] = widget
	self.allWidgets[widget] = newName
end

function Ruu.Button(self, nodeName, releaseFn, wgtTheme)
	local btn = Button(self, self.owner, nodeName, releaseFn, wgtTheme or self.theme.Button)
	addWidget(self, nodeName, btn)
	return btn
end

function Ruu.ToggleButton(self, nodeName, releaseFn, isChecked, wgtTheme)
	local btn = ToggleButton(self, self.owner, nodeName, releaseFn, isChecked, wgtTheme or self.theme.ToggleButton)
	addWidget(self, nodeName, btn)
	return btn
end

function Ruu.RadioButton(self, nodeName, releaseFn, isChecked, wgtTheme)
	local btn = RadioButton(self, self.owner, nodeName, releaseFn, isChecked, wgtTheme or self.theme.RadioButton)
	addWidget(self, nodeName, btn)
	return btn
end

function Ruu.groupRadioButtons(self, widgets)
	local siblings = {} -- Copy the list so we're not messing with the user's table.
	for i,widget in ipairs(widgets) do
		if type(widget) == "string" then
			widget = self:get(widget)
		end
		siblings[i] = widget
		widget.siblings = siblings
	end
end

function Ruu.Slider(self, nodeName, releaseFn, fraction, length, wgtTheme)
	local btn = Slider(self, self.owner, nodeName, releaseFn, fraction, length, wgtTheme or self.theme.Slider)
	addWidget(self, nodeName, btn)
	return btn
end

function Ruu.InputField(self, nodeName, confirmFn, text, wgtTheme)
	local btn = InputField(self, self.owner, nodeName, confirmFn, text, wgtTheme or self.theme.InputField)
	addWidget(self, nodeName, btn)
	return btn
end

function Ruu.get(self, name)
	return self.widgetsByName[name]
end

function Ruu.setEnabled(self, widget, enabled)
	self.enabledWidgets[widget] = enabled or nil
	widget.isEnabled = enabled

	if not enabled then
		if self.dragsOnWgt[widget] then  self:stopDragsOnWidget(widget)  end
		if self.hoveredWidgets[widget] then
			self.hoveredWidgets[widget] = nil
			self:mouseMoved(self.mx, self.my, 0, 0)
		end
		if self.focusedWidget == widget then
			widget:unfocus()
			self.focusedWidget = nil
		end
		if widget.isPressed then  widget:release(true)  end
	end
end

function Ruu.destroy(self, widget)
	if not self.allWidgets[widget] then
		local t = type(widget)
		if t ~= "table" then  error("Ruu.destroy - Requires a widget object, not '" .. tostring(widget) .. "' of type '" .. t .. "'.")
		else  error("Ruu.destroy - Widget not found " .. tostring(widget))  end
	end
	self.setEnabled(self, widget, false)
	local name = self.allWidgets[widget]
	self.allWidgets[widget] = nil
	self.widgetsByName[name] = nil
	if widget.final then  widget:final()  end
end

function Ruu.setFocus(self, widget, isKeyboard)
	if widget == self.focusedWidget then  return  end
	if self.focusedWidget then
		self.focusedWidget:unfocus(isKeyboard)
	end
	self.focusedWidget = widget
	if widget then  widget:focus(isKeyboard)  end
end

local function loopedIndex(list, index)
	return (index - 1) % #list + 1
end

local function findNextInMap(self, map, x, y, axis, dir)
	local foundWidget = nil
	while not foundWidget do
		if axis == "y" then
			y = loopedIndex(map, y + dir)
		elseif axis == "x" then
			x = loopedIndex(map[y], x + dir)
		end
		foundWidget = map[y][x]
		if foundWidget == self then  break  end
	end
	return foundWidget ~= self and foundWidget or nil
end

-- WARNING: EMPTY CELLS IN MAP MUST BE `FALSE`, not `NIL`!

function Ruu.mapNeighbors(self, map)
	for y,row in ipairs(map) do
		for x,widget in ipairs(row) do
			if widget then -- Skip empty cells.
				-- Up and Down
				if #map > 1 then
					widget.neighbor.up = findNextInMap(widget, map, x, y, "y", -1)
					widget.neighbor.down = findNextInMap(widget, map, x, y, "y", 1)
				end
				-- Left and Right
				if #row > 1 then
					widget.neighbor.left = findNextInMap(widget, map, x, y, "x", -1)
					widget.neighbor.right = findNextInMap(widget, map, x, y, "x", 1)
				end
			end
		end
	end
end

function Ruu.mapNextPrev(self, map)
	if #map <= 1 then  return  end

	map = { map } -- Make into a 2D array so findNextInMap just works.

	for i,widget in ipairs(map[1]) do
		if widget then
			widget.neighbor.next = findNextInMap(widget, map, i, 1, "x", 1)
			widget.neighbor.prev = findNextInMap(widget, map, i, 1, "x", -1)
		end
	end
end

function Ruu.startDrag(self, widget, dragType)
	if widget.drag then
		-- Keep track of whether or not we're dragging a widget as well as the number of different
		-- drags (generally only 1), so we can know when there it's no longer being dragged.
		local dragsOnWgt = (self.dragsOnWgt[widget] or 0) + 1
		self.dragsOnWgt[widget] = dragsOnWgt
		local drag = { widget = widget, type = dragType }
		table.insert(self.drags, drag)
	end
end

local function removeDrag(self, index)
	local drag = self.drags[index]
	self.drags[index] = nil
	local dragsOnWgt = self.dragsOnWgt[drag.widget] - 1
	dragsOnWgt = dragsOnWgt > 0 and dragsOnWgt or nil
	self.dragsOnWgt[drag.widget] = dragsOnWgt
end

function Ruu.stopDrag(self, dragType)
	for i=#self.drags,1,-1 do
		if self.drags[i].type == dragType then
			removeDrag(self, i)
		end
	end
end

function Ruu.stopDragsOnWidget(self, widget)
	for i=#self.drags,1,-1 do
		if self.drags[i].widget == widget then
			removeDrag(self, i)
		end
	end
end

function Ruu.mouseMoved(self, x, y, dx, dy)
	self.mx, self.my = x, y
	local foundHit = false

	if self.drags[1] then
		foundHit = true
		for i,drag in ipairs(self.drags) do
			drag.widget:drag(dx, dy, drag.type)
		end
	end

	for widget,_ in pairs(self.enabledWidgets) do
		local widgetIsHit
		if self.dragsOnWgt[widget] then
			widgetIsHit = true
		else
			widgetIsHit = widget:hitCheck(x, y)
			if widgetIsHit and widget.maskNode then
				widgetIsHit = gui.pick_node(widget.maskNode, x, y)
			end
		end
		if widgetIsHit then
			foundHit = true
			self.hoveredWidgets[widget] = true
		else
			self.hoveredWidgets[widget] = nil
			if widget.isHovered then  widget:unhover()  end
		end
	end

	if foundHit then
		-- If dragging, only use a/the dragged widget as the top hovered widget.
		local widgetDict = not self.drags[1] and self.hoveredWidgets or self.dragsOnWgt
		local topWidget = util.getTopWidget(widgetDict, "node", self.layerDepths)
		if self.topHoveredWgt and self.topHoveredWgt ~= topWidget then
			self.topHoveredWgt:unhover()
		end
		self.topHoveredWgt = topWidget
		if not self.topHoveredWgt.isHovered then
			self.topHoveredWgt:hover()
		end
	elseif self.topHoveredWgt then
		self.topHoveredWgt:unhover()
		self.topHoveredWgt = nil
	end
end

local function isDraggable(widget)
	return widget.drag
end

local function callIfExists(widget, fnName, ...)
	if widget and widget[fnName] then
		widget[fnName](widget, ...)
		return true
	end
end

function Ruu.input(self, action_id, action)
	if not action_id then
		self:mouseMoved(action.x, action.y, action.dx, action.dy)
	elseif action_id == self.CLICK then
		if action.pressed then
			if self.topHoveredWgt then
				self.topHoveredWgt:press(self.mx, self.my, IS_NOT_KEYBOARD)
				self:setFocus(self.topHoveredWgt, IS_NOT_KEYBOARD)
				-- Start drag - do it on mouse down instead of mouse move so we can easily set up initial drag offsets, etc.
				local topDraggableWgt = util.getTopWidget(self.hoveredWidgets, "node", self.layerDepths, isDraggable)
				if topDraggableWgt then  self:startDrag(topDraggableWgt)  end
				return true
			else
				self:setFocus(nil, IS_NOT_KEYBOARD)
			end
		elseif action.released then
			local wasDragging = self.drags[1]
			if wasDragging then  self:stopDrag()  end
			if self.topHoveredWgt and self.topHoveredWgt.isPressed then
				self.topHoveredWgt:release(nil, self.mx, self.my, IS_NOT_KEYBOARD)
			end
			-- Want to release the dragged node before updating hover.
			if wasDragging then  self:mouseMoved(self.mx, self.my, 0, 0)  end
		end
	elseif action_id == self.ENTER then
		if action.pressed then
			if self.focusedWidget then
				self.focusedWidget:press(nil, nil, IS_KEYBOARD)
			end
		elseif action.released then
			if self.focusedWidget and self.focusedWidget.isPressed then
				self.focusedWidget:release(false, nil, nil, IS_KEYBOARD)
			end
		end
	elseif self.NAV_DIRS[action_id] and (action.pressed or action.repeated) then
		if self.focusedWidget then
			local dirStr = self.NAV_DIRS[action_id]
			local neighbor = self.focusedWidget:getFocusNeighbor(dirStr)
			if neighbor == 1 then -- No neighbor, but used input.
				return true
			elseif neighbor then
				self:setFocus(neighbor, IS_KEYBOARD)
			end
		end
	elseif action_id == self.TEXT then
		return callIfExists(self.focusedWidget, "textInput", action.text)
	elseif action_id == self.BACKSPACE and (action.pressed or action.repeated) then
		return callIfExists(self.focusedWidget, "backspace")
	elseif action_id == self.DELETE and (action.pressed or action.repeated) then
		return callIfExists(self.focusedWidget, "delete")
	elseif action_id == self.HOME and action.pressed then
		return callIfExists(self.focusedWidget, "home")
	elseif action_id == self.END and action.pressed then
		return callIfExists(self.focusedWidget, "end")
	elseif action_id == self.CANCEL and action.pressed then
		return callIfExists(self.focusedWidget, "cancel")
	elseif action_id == self.SELECTION_MODIFIER then
		if action.pressed then
			self.selectionModifierPresses = self.selectionModifierPresses + 1
		elseif action.released then
			self.selectionModifierPresses = self.selectionModifierPresses - 1
		end
	end
end

function Ruu.registerLayers(self, layerList)
	self.layerDepths = {}
	for i,layer in ipairs(layerList) do
		if type(layer) == "string" then  layer = hash(layer)
		elseif type(layer) ~= "userdata" then
			error("Ruu.registerLayers() - Invalid layer '" .. tostring(layer) .. "'. Must be a string or a hash.")
		end
		self.layerDepths[layer] = i * Ruu.layerPrecision
	end
end

function Ruu.set(self, owner, getInput, theme)
	assert(owner, "Ruu() - 'owner' must be specified.")
	assert(type(getInput) == "function", "Ruu() - Requires a function for getting current input values.")
	self.owner = owner
	self.allWidgets = {}
	self.widgetsByName = {}
	self.enabledWidgets = {}
	self.hoveredWidgets = {}
	self.focusedWidget = nil
	self.theme = theme or defaultTheme
	self.mx, self.my = 0, 0
	self.layerDepths = {}
	self.drags = {}
	-- A dictionary of currently dragged widgets, with the number of active drags on each (in case of custom drags).
	self.dragsOnWgt = {}
	self.selectionModifierPresses = 0
end

return Ruu
