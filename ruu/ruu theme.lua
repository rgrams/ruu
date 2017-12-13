
local M = {}

local MODE_KEYBOARD = 1
local MODE_MOUSE = 2
local MODE_MOBILE = 3

M.mode = MODE_KEYBOARD

local normalcolor = vmath.vector4(0.3, 0.3, 0.3, 1)
local hovercolor = vmath.vector4(0.45, 0.45, 0.45, 1)
local presscolor = vmath.vector4(0.8, 0.8, 0.8, 1)
local checkedColor = vmath.vector4(1, 1, 1, 1)
local uncheckedColor = vmath.vector4(0.1, 0.1, 0.1, 1)

local zerovect = vmath.vector3()
local press_text_offset = vmath.vector3(0, -2, 0)

local group_offrightpos = vmath.vector3(1000, 325, 0)
local group_onpos = vmath.vector3(400, 325, 0)
local group_offpos = vmath.vector3(0, 325, 0)
local group_anim_t = 0.3

local inputText_focuscolor = vmath.vector4(1)
local inputText_unfocuscolor = vmath.vector4(0.7, 0.7, 0.7, 1)
local inputField_cursorBlinkCurve = vmath.vector({1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1})


function M.init_btn(self)
	gui.set_color(self.node, normalcolor)
	self.focusIndicator = gui.get_node(self.name .. "/focus indicator")
	gui.set_enabled(self.focusIndicator, false)
end

function M.init_toggleButton(self)
	gui.set_color(self.node, normalcolor)
	self.checknode = gui.get_node(self.name .. "/check")
	gui.set_color(self.checknode, self.checked and checkedColor or uncheckedColor)
	self.focusIndicator = gui.get_node(self.name .. "/focus indicator")
	gui.set_enabled(self.focusIndicator, false)
end

function M.init_radioButton(self)
	gui.set_color(self.node, normalcolor)
	self.checknode = gui.get_node(self.name .. "/check")
	gui.set_color(self.checknode, self.checked and checkedColor or uncheckedColor)
	self.focusIndicator = gui.get_node(self.name .. "/focus indicator")
	gui.set_enabled(self.focusIndicator, false)
end

function M.hover_btn(self)
	gui.set_color(self.node, hovercolor)
end

function M.unhover_btn(self)
	gui.set_color(self.node, normalcolor)
end

function M.focus_btn(self)
	if M.mode == MODE_KEYBOARD then
		gui.set_enabled(self.focusIndicator, true)
	end
end

function M.unfocus_btn(self)
	if M.mode == MODE_KEYBOARD then
		gui.set_enabled(self.focusIndicator, false)
	end
end

function M.press_btn(self)
	gui.set_color(self.node, presscolor)
	if self.textNode then
		gui.set_position(self.textNode, gui.get_position(self.textNode) + press_text_offset)
	end
end

function M.release_btn(self)
	if self.hovered then gui.set_color(self.node, hovercolor)
	else gui.set_color(self.node, normalcolor)
	end
	if self.textNode then
		gui.set_position(self.textNode, gui.get_position(self.textNode) - press_text_offset)
	end
end

function M.release_toggleButton(self)
	gui.set_color(self.checknode, self.checked and checkedColor or uncheckedColor)
	if self.hovered then gui.set_color(self.node, hovercolor)
	else gui.set_color(self.node, normalcolor)
	end
	gui.set_position(self.textNode, gui.get_position(self.textNode) - press_text_offset)
end

function M.release_radioButton(self)
	gui.set_color(self.checknode, self.checked and checkedColor or uncheckedColor)
	if self.hovered then gui.set_color(self.node, hovercolor)
	else gui.set_color(self.node, normalcolor)
	end
	gui.set_position(self.textNode, gui.get_position(self.textNode) - press_text_offset)
end

function M.uncheck_radioButton(self)
	gui.set_color(self.checknode, uncheckedColor)
end

function M.slider_setHandleLength(self)
	gui.set_size(self.focusIndicator, gui.get_size(self.node))
end

function M.init_inputField(self)
	gui.set_enabled(self.cursorNode, false)
	gui.set_color(self.textNode, inputText_unfocuscolor)
	self.focusIndicator = gui.get_node(self.name .. "/focus indicator")
	gui.set_enabled(self.focusIndicator, false)
end

function M.focus_inputField(self)
	gui.set_enabled(self.focusIndicator, true)
	gui.set_enabled(self.cursorNode, true)
	gui.set_color(self.textNode, inputText_focuscolor)
	gui.animate(self.cursorNode, "color.w", 0, inputField_cursorBlinkCurve, 0.8, 0, nil, gui.PLAYBACK_LOOP_FORWARD)
end

function M.unfocus_inputField(self)
	gui.set_enabled(self.focusIndicator, false)
	gui.set_enabled(self.cursorNode, false)
	gui.set_color(self.textNode, inputText_unfocuscolor)
	gui.cancel_animation(self.cursorNode, "color.w")
	gui.set_color(self.cursorNode, inputText_focuscolor)
end

function M.group_enable(self)
	gui.set_position(self.node, group_offrightpos)
	gui.animate(self.node, "position", group_onpos, gui.EASING_INOUTCUBIC, group_anim_t)
	gui.animate(self.node, "color.w", 1, gui.EASING_LINEAR, 0)
end

function M.group_disable(self)
	gui.animate(self.node, "position", group_offpos, gui.EASING_INOUTCUBIC, group_anim_t, 0, function() gui.set_enabled(self.node, false) end)
	gui.animate(self.node, "color.w", 0, gui.EASING_LINEAR, group_anim_t*0.8)
end


return M
