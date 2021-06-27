
local Button = require "ruu2.widgets.Button"
local InputField = Button:extend()

local endChar = "|"

function InputField.set(self, ruu, owner, nodeName, releaseFn, text, wgtTheme)
	self.text = text or ""
	self._maskNode = gui.get_node(nodeName .. "/mask")
	self.textNode = gui.get_node(nodeName .. "/text")
	gui.set_text(self.textNode, self.text)
	self.font = gui.get_font(self.textNode)
	self.endCharWidth = gui.get_text_metrics(self.font, endChar).width
	self.textOriginX = gui.get_position(self.textNode).x
	self.textScrollX = 0

	InputField.super.set(self, ruu, owner, nodeName, releaseFn, wgtTheme)

	self:updateCursorPos()
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
	gui.set_text(self.textNode, self.text)
	self:updateCursorPos()
	self.wgtTheme.updateText(self)
end

function InputField.backspace(self)
	self.text = self.text:sub(1, -2)
	gui.set_text(self.textNode, self.text)
	self:updateCursorPos()
	self.wgtTheme.updateText(self)
end

return InputField
