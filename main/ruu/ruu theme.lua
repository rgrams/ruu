
local M = {}

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

local focus_scale = vmath.vector3(1)
local unfocus_scale = vmath.vector3(0.9)


function M.init_btn(self)
	gui.set_color(self.node, normalcolor)
end

function M.init_toggleButton(self)
	gui.set_color(self.node, normalcolor)
	self.checknode = gui.get_node(self.name .. "/check")
	gui.set_color(self.checknode, self.checked and checkedColor or uncheckedColor)
end

function M.init_radioButton(self)
	gui.set_color(self.node, normalcolor)
	self.checknode = gui.get_node(self.name .. "/check")
	gui.set_color(self.checknode, self.checked and checkedColor or uncheckedColor)
end

function M.hover_btn(self)
	gui.set_color(self.node, hovercolor)
end

function M.unhover_btn(self)
	gui.set_color(self.node, normalcolor)
end

function M.focus_btn(self)
	gui.set_scale(self.node, focus_scale)
end

function M.unfocus_btn(self)
	gui.set_scale(self.node, unfocus_scale)
end

function M.press_btn(self)
	gui.set_color(self.node, presscolor)
	if self.textnode then
		gui.set_position(self.textnode, gui.get_position(self.textnode) + press_text_offset)
	end
end

function M.release_btn(self)
	if self.hovered then gui.set_color(self.node, hovercolor)
	else gui.set_color(self.node, normalcolor)
	end
	if self.textnode then
		gui.set_position(self.textnode, gui.get_position(self.textnode) - press_text_offset)
	end
end

function M.release_toggleButton(self)
	gui.set_color(self.checknode, self.checked and checkedColor or uncheckedColor)
	if self.hovered then gui.set_color(self.node, hovercolor)
	else gui.set_color(self.node, normalcolor)
	end
	gui.set_position(self.textnode, gui.get_position(self.textnode) - press_text_offset)
end

function M.release_radioButton(self)
	gui.set_color(self.checknode, self.checked and checkedColor or uncheckedColor)
	if self.hovered then gui.set_color(self.node, hovercolor)
	else gui.set_color(self.node, normalcolor)
	end
	gui.set_position(self.textnode, gui.get_position(self.textnode) - press_text_offset)
end

function M.uncheck_radioButton(self)
	gui.set_color(self.checknode, uncheckedColor)
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
