
local Button = require "ruu.widgets.Button"

local RadioButton = Button:extend()

-- self.siblings - Can be nil if it hasn't been set as part of a group yet.
function RadioButton.set(self, ruu, owner, nodeName, releaseFn, isChecked, wgtTheme)
	self.isChecked = isChecked -- Needs to be set before theme.init.
	RadioButton.super.set(self, ruu, owner, nodeName, releaseFn, wgtTheme)
end

function RadioButton.final(self)
	if self.siblings then
		for i,widget in ipairs(self.siblings) do
			if widget == self then
				table.remove(self.siblings, i)
				break
			end
		end
	end
	self:setChecked(false)
end

function RadioButton.release(self, dontFire, mx, my, isKeyboard)
	self.isPressed = false
	if not dontFire then
		if not self.isChecked then
			self.isChecked = true
			if self.siblings then
				for i,widget in ipairs(self.siblings) do
					if widget ~= self then  widget:siblingWasChecked()  end
				end
			end
		end
		-- Still call release function even if nothing happened (if we were already checked).
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

-- For outside scripts to manually check or uncheck buttons.
function RadioButton.setChecked(self, isChecked)
	if isChecked and not self.isChecked then -- Check.
		self.isChecked = true
		if self.siblings then
			for i,widget in ipairs(self.siblings) do
				if widget ~= self then  widget:siblingWasChecked()  end
			end
		end
		self.wgtTheme.setChecked(self, true)
	elseif self.isChecked and not isChecked then -- Un-check
		-- It's weird to un-check a radio button. Try setting the first sibling checked or do nothing.
		if self.siblings then
			for i,widget in ipairs(self.siblings) do
				if widget ~= self then
					widget:setChecked(true)
					break
				end
			end
		end
	end
end

function RadioButton.siblingWasChecked(self)
	self.isChecked = false
	self.wgtTheme.setChecked(self, false)
end

return RadioButton
