
local Class = require "ruu2.base-class"
local Button = Class:extend()

Button.isHovered = false
Button.isPressed = false
Button.isFocused = false

-- For dynamically-created nodes, use gui.set_id to give the node a name.
function Button.set(self, ruu, owner, nodeName, releaseFn, wgtTheme)
	self.ruu = ruu
	self.owner = owner
	self.node = gui.get_node(nodeName .. "/body")
	self.releaseFn = releaseFn
	self.isEnabled = true
	self.neighbor = {}
	self.wgtTheme = wgtTheme
	self.wgtTheme.init(self, nodeName)
end

function Button.args(self, arg1, ...)
	self.releaseArgs = arg1 ~= nil and {arg1,...} or nil
	return self -- Allow chaining.
end

function Button.hitCheck(self, x, y)
	return gui.pick_node(self.node, x, y)
end

function Button.hover(self)
	self.isHovered = true
	self.wgtTheme.hover(self)
end

function Button.unhover(self)
	self.isHovered = false
	self.wgtTheme.unhover(self)
	if self.isPressed then  self:release(true)  end -- Release without firing.
end

function Button.focus(self, isKeyboard)
	self.isFocused = true
	self.wgtTheme.focus(self, isKeyboard)
end

function Button.unfocus(self, isKeyboard)
	self.isFocused = false
	self.wgtTheme.unfocus(self, isKeyboard)
	if self.isPressed then  self:release(true)  end -- Release without firing.
end

function Button.press(self, mx, my, isKeyboard)
	self.isPressed = true
	self.wgtTheme.press(self, mx, my, isKeyboard)
	if self.pressFn then  self:pressFn(mx, my, isKeyboard)  end
end

function Button.release(self, dontFire, mx, my, isKeyboard)
	self.isPressed = false
	self.wgtTheme.release(self, dontFire, mx, my, isKeyboard)
	if self.releaseFn and not dontFire then
		if self.releaseArgs then
			self.releaseFn(self.owner, self, unpack(self.releaseArgs))
		else
			self.releaseFn(self.owner, self)
		end
	end
end

function Button.getFocusNeighbor(self, dir)
	return self.neighbor[dir]
end

return Button
