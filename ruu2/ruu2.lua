
local Class = require "ruu2.base-class"
local defaultTheme = require "ruu2.defaultTheme"
local util = require "ruu2.ruutilities"

local Ruu = Class:extend()

local Button = require("ruu2.widgets.Button")
local ToggleButton = require("ruu2.widgets.ToggleButton")
local RadioButton = require("ruu2.widgets.RadioButton")
local SliderHandle = require("ruu2.widgets.SliderHandle")

local CLICK = hash("touch")
local ENTER = hash("enter")
local TEXT = hash("text")
local BACKSPACE = hash("backspace")
local NAV_DIRS = {
	[hash("up")] = "up", [hash("down")] = "down", [hash("left")] = "left", [hash("right")] = "right",
	[hash("next")] = "next", [hash("prev")] = "prev"
}
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
	local btn = RadioButton(self, self.owner, nodeName, releaseFn, isChecked, wgtTheme or self.theme.ToggleButton)
	addWidget(self, nodeName, btn)
	return btn
end

function Ruu.groupRadioButtons(self, widgets)
	for i,widget in ipairs(widgets) do
		if type(widget) == "string" then
			widget = self:get(widget)
			widgets[i] = widget
		end
		widget.siblings = widgets
	end
end

function Ruu.Slider(self, nodeName, releaseFn, fraction, length, wgtTheme)
	local btn = SliderHandle(self, self.owner, nodeName, releaseFn, fraction, length, wgtTheme or self.theme.SliderHandle)
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
		if self.hoveredWidgets[widget] then
			self.hoveredWidgets[widget] = nil
			self:mouseMoved(self.mx, self.my, 0, 0)
		end
		-- if self.objDragCount[widget] then  stopDrag(self, "object", widget)  end
		-- if self.focusedWidget == widget then
			-- widget:call("unfocus")
			-- self.focusedWidget = nil -- Just remove it, don't change ancestor panel focus.
		-- end
		if widget.isHovered then  widget:call("unhover")  end
		if widget.isPressed then  widget:call("release", true)  end
	end
end

function Ruu.destroy(self, widget)
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
	widget:focus(isKeyboard)
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

function Ruu.stopDrag(self, dragType)
	for i=#self.drags,1,-1 do
		local drag = self.drags[i]
		if drag.type == dragType then
			self.drags[i] = nil
			local dragsOnWgt = self.dragsOnWgt[drag.widget] - 1
			dragsOnWgt = dragsOnWgt > 0 and dragsOnWgt or nil
			self.dragsOnWgt[drag.widget] = dragsOnWgt
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

function Ruu.input(self, action_id, action)
	if not action_id then
		self:mouseMoved(action.x, action.y, action.dx, action.dy)
	elseif action_id == CLICK then
		if action.pressed then
			if self.topHoveredWgt then
				self.topHoveredWgt:press(self.mx, self.my, IS_NOT_KEYBOARD)
				self:startDrag(self.topHoveredWgt)
				self:setFocus(self.topHoveredWgt, IS_NOT_KEYBOARD)
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
	elseif action_id == ENTER then
		if action.pressed then
			if self.focusedWidget then
				self.focusedWidget:press(nil, nil, IS_KEYBOARD)
			end
		elseif action.released then
			if self.focusedWidget and self.focusedWidget.isPressed then
				self.focusedWidget:release(false, nil, nil, IS_KEYBOARD)
			end
		end
	elseif action.pressed and NAV_DIRS[action_id] then
		if self.focusedWidget then
			local dirStr = NAV_DIRS[action_id]
			local neighbor = self.focusedWidget:getFocusNeighbor(dirStr)
			if neighbor == 1 then -- No neighbor, but used input.
				return true
			elseif neighbor then
				self:setFocus(neighbor, IS_KEYBOARD)
			end
		end
	elseif action == TEXT then
		local widget = self.focusedWidget
		if widget and widget.textInput then
			widget:textInput(action.text)
			return true
		end
	elseif action == BACKSPACE and action.pressed then
		local widget = self.focusedWidget
		if widget and widget.backspace then
			widget:backspace()
			return true
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
end

return Ruu
