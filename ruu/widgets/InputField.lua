
local Button = require "ruu.widgets.Button"
local InputField = Button:extend()

local endChar = "|"

function InputField.set(self, ruu, owner, nodeName, confirmFn, text, wgtTheme)
	self.text = text or ""
	self.oldText = self.text
	self._maskNode = gui.get_node(nodeName .. "/mask")
	self.textNode = gui.get_node(nodeName .. "/text")
	gui.set_text(self.textNode, self.text)
	self.font = gui.get_font(self.textNode)
	self.endCharWidth = gui.get_text_metrics(self.font, endChar).width
	self.textOriginX = gui.get_position(self.textNode).x
	self.textScrollX = 0
	self.confirmFn = confirmFn

	local releaseFn = nil
	InputField.super.set(self, ruu, owner, nodeName, releaseFn, wgtTheme)

	self:updateCursorPos()
end

function InputField.onEdit(self, editFn)
	self.editFn = editFn
	return self -- Allow chaining.
end

local function _sendCb(self, fn)
	if fn then
		if self.releaseArgs then
			return fn(self.owner, self, unpack(self.releaseArgs))
		else
			return fn(self.owner, self)
		end
	end
end

function InputField.release(self, dontFire, mx, my, isKeyboard)
	self.isPressed = false
	if self.releaseFn and not dontFire then
		_sendCb(self, self.releaseFn)
	end
	if isKeyboard and self.confirmFn and not dontFire then
		local rejectedText = self.text
		local isRejected = _sendCb(self, self.confirmFn)
		if isRejected then
			self:cancel()
			self.wgtTheme.textRejected(self, rejectedText)
		else
			self.oldText = self.text
		end
	end
	self.wgtTheme.release(self, dontFire, mx, my, isKeyboard)
end

function InputField.focus(self, isKeyboard)
	if not self.isFocused then
		self.isFocused = true
		self.oldText = self.text -- Save in case of cancel.
	end
	self.wgtTheme.focus(self)
end

function InputField.unfocus(self, isKeyboard)
	self.isFocused = false
	if self.isPressed then  self:release(true)  end -- Release without firing.
	if isKeyboard and self.confirmFn then
		local rejectedText = self.text
		local isRejected = _sendCb(self, self.confirmFn)
		if isRejected then
			self:cancel()
			self.wgtTheme.textRejected(self, rejectedText)
		else
			self.oldText = self.text
		end
	end
	self.wgtTheme.unfocus(self, isKeyboard)
end

function InputField.cancel(self)
	self.text = self.oldText
	gui.set_text(self.textNode, self.text)
	self:updateCursorPos()
	self.wgtTheme.updateText(self)
end

local function getTextWidth(font, text, endCharWidth)
	local width = gui.get_text_metrics(font, text .. endChar).width
	width = width - endCharWidth
	return width
end

function InputField.updateCursorPos(self)
	local textWidth = getTextWidth(self.font, self.text, self.endCharWidth)
	self.cursorX = self.textOriginX + textWidth

	local maskWidth = gui.get_size(self._maskNode).x
	local maskPosX = gui.get_position(self._maskNode).x
	local maskRightX = maskPosX + maskWidth/2

	if self.cursorX > maskRightX then -- Move text so cursor is in view.
		local distOutside = self.cursorX - maskRightX
		self.cursorX = self.cursorX - distOutside
		self.textScrollX = -distOutside
		local pos = gui.get_position(self.textNode)
		pos.x = self.textOriginX + self.textScrollX
		gui.set_position(self.textNode, pos)
	elseif self.textScrollX ~= 0 then
		self.textScrollX = 0
		local pos = gui.get_position(self.textNode)
		pos.x = self.textOriginX + self.textScrollX
		gui.set_position(self.textNode, pos)
	end

	self.wgtTheme.updateCursor(self)
end

function InputField.textInput(self, text)
	self.text = self.text .. text
	_sendCb(self, self.editFn) -- Can modify self.text.
	gui.set_text(self.textNode, self.text)
	self:updateCursorPos()
	self.wgtTheme.updateText(self)
end

function InputField.backspace(self)
	self.text = self.text:sub(1, -2)
	_sendCb(self, self.editFn) -- Can modify self.text.
	gui.set_text(self.textNode, self.text)
	self:updateCursorPos()
	self.wgtTheme.updateText(self)
end

function InputField.setText(self, text)
	self.text = text ~= nil and tostring(text) or ""
	_sendCb(self, self.editFn) -- Can modify self.text.
	gui.set_text(self.textNode, self.text)
	self:updateCursorPos()
	self.wgtTheme.updateText(self)
end

return InputField
