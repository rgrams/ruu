
local Class = require "ruu.base-class"

local M = {}

--##############################  BUTTON  ##############################
local Button = Class:extend()
M.Button = Button

local function setValue(self, val)
	local col = gui.get_color(self.node)
	col.x, col.y, col.z = val, val, val
	gui.set_color(self.node, col)
end

function Button.init(self, nodeName)
	setValue(self, 0.4)
	self.focusNode = gui.get_node(nodeName .. "/focus")
	gui.set_enabled(self.focusNode, false)
end

function Button.hover(self)
	setValue(self, 0.5)
end

function Button.unhover(self)
	setValue(self, 0.4)
end

function Button.focus(self, isKeyboard)
	gui.set_enabled(self.focusNode, true)
end

function Button.unfocus(self, isKeyboard)
	gui.set_enabled(self.focusNode, false)
end

function Button.press(self, mx, my, isKeyboard)
	setValue(self, 0.8)
end

function Button.release(self, dontFire, mx, my, isKeyboard)
	setValue(self, self.isHovered and 0.5 or 0.4)
end

--##############################  TOGGLE-BUTTON  ##############################
local ToggleButton = Button:extend()
M.ToggleButton = ToggleButton

function ToggleButton.init(self, nodeName)
	ToggleButton.super.init(self, nodeName)
	local rot = vmath.quat_rotation_z(self.isChecked and math.pi/6 or 0)
	gui.set_rotation(self.node, rot)
end

function ToggleButton.release(self, dontFire, mx, my, isKeyboard)
	ToggleButton.super.release(self, dontFire, mx, my, isKeyboard)
	local rot = vmath.quat_rotation_z(self.isChecked and math.pi/6 or 0)
	gui.set_rotation(self.node, rot)
end

function ToggleButton.setChecked(self, isChecked)
	local rot = vmath.quat_rotation_z(self.isChecked and math.pi/6 or 0)
	gui.set_rotation(self.node, rot)
end

--##############################  RADIO-BUTTON  ##############################
local RadioButton = ToggleButton:extend()
M.RadioButton = RadioButton


--##############################  INPUT-FIELD  ##############################
local InputField = Button:extend()
M.InputField = InputField

function InputField.init(self, nodeName)
	InputField.super.init(self, nodeName)
	self.cursorNode = gui.get_node(nodeName .. "/cursor")
	gui.set_enabled(self.cursorNode, self.isFocused)
end

function InputField.focus(self, isKeyboard)
	InputField.super.focus(self, isKeyboard)
	gui.set_enabled(self.cursorNode, self.isFocused)
end

function InputField.unfocus(self, isKeyboard)
	InputField.super.unfocus(self, isKeyboard)
	gui.set_enabled(self.cursorNode, self.isFocused)
end

function InputField.updateCursor(self)
	local pos = gui.get_position(self.cursorNode)
	pos.x = self.cursorX
	gui.set_position(self.cursorNode, pos)
end

function InputField.updateText(self)
end

function InputField.textRejected(self, rejectedText)
end

--##############################  SLIDER - HANDLE  ##############################
local SliderHandle = Button:extend()
M.SliderHandle = SliderHandle

function SliderHandle.init(self, nodeName)
	SliderHandle.super.init(self, nodeName)
	SliderHandle.drag(self)
end

function SliderHandle.drag(self)
	-- self.angle = self.fraction * math.pi
end

--[[
--##############################  SLIDER - BAR  ##############################
local SliderBar = Button:extend()
M.SliderBar = SliderBar

function SliderBar.hover(self)  end
function SliderBar.unhover(self)  end

function SliderBar.focus(self)  end
function SliderBar.unfocus(self)  end

function SliderBar.press(self)
	setValue(self, 1)
end

function SliderBar.release(self)
	setValue(self, 0.55)
end

--##############################  SCROLL-AREA  ##############################
local ScrollArea = Button:extend()
M.ScrollArea = ScrollArea

function ScrollArea.init(self)  end
function ScrollArea.hover(self)  end
function ScrollArea.unhover(self)  end
function ScrollArea.focus(self)  end
function ScrollArea.unfocus(self)  end
function ScrollArea.press(self)  end
function ScrollArea.release(self)  end

--##############################  PANEL  ##############################
local Panel = Class:extend()
M.Panel = Panel

function Panel.init(self)  end
function Panel.hover(self)  end
function Panel.unhover(self)  end
function Panel.focus(self)  end
function Panel.unfocus(self)  end
function Panel.press(self)  end
function Panel.release(self)  end
--]]

return M
