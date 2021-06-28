
local Button = require "ruu.widgets.Button"
local ToggleButton = Button:extend()

function ToggleButton.set(self, ruu, owner, nodeName, releaseFn, isChecked, wgtTheme)
	self.isChecked = isChecked -- Needs to be set before theme.init.
	ToggleButton.super.set(self, ruu, owner, nodeName, releaseFn, wgtTheme)
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
	self.wgtTheme.release(self, dontFire, mx, my, isKeyboard)
end

function ToggleButton.setChecked(self, isChecked)
	self.isChecked = isChecked
	self.wgtTheme.setChecked(isChecked)
end

return ToggleButton
