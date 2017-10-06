
local ruu = require "main.ruu.ruu"
local theme = require "main.ruu.ruu theme"

local M = {}


local function inputField_setText(self, text)
	self.text = text
	gui.set_text(self.textNode, self.text)
	self.cursorPos.x = gui.get_text_metrics(self.font, self.text .. self.endTag).width + self.textOriginX - self.endTagLength
	--self.cursorPos.x = self.textOriginX - self.endTagLength
	gui.set_position(self.cursorNode, self.cursorPos)
end

local function inputField_textInput(self, char)
	self:setText(self.text .. char)
end

local function inputField_backspace(self)
	self:setText(string.sub(self.text, 1, -2))
end

function ruu.new_inputField(key, name, active, editfunc, confirmfunc, placeholderText)
	if type(key) == "table" then key = key[ruu.keyName] end
	local self = ruu.new_baseWidget(key, name, active, nil, nil)
	self.textNode = gui.get_node(self.name .. "/text")
	self.cursorNode = gui.get_node(self.name .. "/cursor")
	self.font = gui.get_font(self.textNode)
	self.endTag = "."
	self.endTagLength = gui.get_text_metrics(self.font, self.endTag).width
	self.placeholderText = placeholderText or ""
	self.cursorPos = gui.get_position(self.cursorNode)
	self.textOriginX = gui.get_position(self.textNode).x
	self.setText = inputField_setText
	self.backspace = inputField_backspace
	self.textInput = inputField_textInput
	self:setText(placeholderText)
end


return M
