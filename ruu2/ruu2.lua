
local Class = require "ruu2.base-class"
local defaultTheme = require "ruu2.defaultTheme"
local util = require "ruu2.ruutilities"

local Ruu = Class:extend()

local widgets = {
	Button = require("ruu2.base widgets.Button")
}

local CLICK = hash("touch")

local function addWidget(self, name, widget)
	self.allWidgets[widget] = name
	self.enabledWidgets[widget] = true
	assert(not self.widgetsByName[name], "Ruu.addWidget - Name conflict with name '"..tostring(name).."'.")
	self.widgetsByName[name] = widget
end

function Ruu.Button(self, nodeName, releaseFn, wgtTheme)
	local btn = widgets.Button(self, self.owner, nodeName, releaseFn, wgtTheme or self.theme.Button)
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
			self:mouseMoved(self.mx, self.my)
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

-- local destroyRadioButton

function Ruu.destroy(self, widget)
	setEnabled(self, widget, false)
	local name = self.allWidgets[widget]
	self.allWidgets[widget] = nil
	self.widgetsByName[name] = nil
	-- if widget.widgetType == "RadioButton" then
		-- destroyRadioButton(self, widget)
	-- end
end

function Ruu.mouseMoved(self, x, y)
	self.mx, self.my = x, y
	local foundHit = false
	for widget,_ in pairs(self.enabledWidgets) do
		local widgetIsHit = widget:hitCheck(x, y)
		if widgetIsHit and widget.maskNode then
			widgetIsHit = gui.pick_node(widget.maskNode, x, y)
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
		topWidget = util.getTopWidget(self.hoveredWidgets, "node", self.layers)
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
		self:mouseMoved(action.x, action.y)
	elseif action_id == CLICK then
		if action.pressed then
			if self.topHoveredWgt then  self.topHoveredWgt:press()  end
		elseif action.released then
			if self.topHoveredWgt and self.topHoveredWgt.isPressed then
				self.topHoveredWgt:release()
			end
		end
	end
end

function Ruu.set(self, owner, getInput, theme)
	assert(owner, "Ruu() - 'owner' must be specified.")
	assert(type(getInput) == "function", "Ruu() - Requires a function for getting current input values.")
	self.owner = owner
	self.allWidgets = {}
	self.enabledWidgets = {}
	self.hoveredWidgets = {}
	self.widgetsByName = {}
	self.theme = theme or defaultTheme
	self.mx, self.my = 0, 0
	self.layers = {}
end

return Ruu
