
local Button = require "ruu2.widgets.Button"
local ToggleButton = Button:extend()

function ToggleButton.set(self, ruu, owner, nodeName, releaseFn, isChecked, wgtTheme)
	ToggleButton.super.set(self, ruu, owner, nodeName, releaseFn, wgtTheme)
	self.isChecked = isChecked
end

function ToggleButton.release(self, dontFire, mx, my, isKeyboard)
	self.isPressed = false
	if not dontFire then
		self.isChecked = not self.isChecked
		if self.releaseFn then
			if self.releaseArgs then
				self.releaseFn(self.owner, self, unpack(self.releaseArgs))
			else
				self.releaseFn(self.owner, self)
			end
		end
	end
	self.wgtTheme.release(self, dontFire, mx, my)
end

return ToggleButton
