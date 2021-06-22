
local Class = require "ruu2.base-class"
local defaultTheme = require "ruu2.defaultTheme"

local Ruu = Class:extend()

local widgets = {
	Button = require("ruu2.base widgets.Button")
}

local CLICK = hash("touch")

function Ruu.Button(self, nodeName, releaseFn, wgtTheme)
	local btn = widgets.Button(self, self.owner, nodeName, releaseFn, wgtTheme or self.theme.Button)
	self.allWidgets[btn] = true
	self.enabledWidgets[btn] = true
	return btn
end

function Ruu.mouseMoved(self, x, y)
	self.mx, self.my = x, y
	local foundHit = false
	for widget,_ in pairs(self.enabledWidgets) do
		local widgetIsHit = widget:hitCheck(x, y)
		if widgetIsHit then
			foundHit = true
			if self.hoveredWgt and self.hoveredWgt ~= widget then
				self.hoveredWgt:unhover()
			end
			if not widget.isHovered then
				widget:hover()
			end
			self.hoveredWgt = widget
			break
		end
	end

	if self.hoveredWgt and not foundHit then
		self.hoveredWgt:unhover()
		self.hoveredWgt = nil
	end
end

function Ruu.input(self, action_id, action)
	if not action_id then
		self:mouseMoved(action.x, action.y)
	elseif action_id == CLICK then
		if action.pressed then
			if self.hoveredWgt then  self.hoveredWgt:press()  end
		elseif action.released then
			if self.hoveredWgt and self.hoveredWgt.isPressed then
				self.hoveredWgt:release()
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
	self.theme = theme or defaultTheme
	self.mx, self.my = 0, 0
	self.layers = {}
end

return Ruu
