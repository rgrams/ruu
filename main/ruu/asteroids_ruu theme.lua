
local M = {}

local normalcolor = vmath.vector4(0.4, 0.4, 0.4, 1)
local normal_text_color = vmath.vector4(1, 1, 1, 0.5)
local hovercolor = vmath.vector4(0.6, 0.6, 0.6, 1)
local presscolor = vmath.vector4(0.8, 0.8, 0.8, 1)

local hoverflashcolor = vmath.vector4(0.3, 1, 0.7, 1)--vmath.vector4(1, 0, 0.3, 1)

local zerovect = vmath.vector3()
local text_x = 20
local text_offset = vmath.vector3(0, 5, 0)
local press_text_offset = vmath.vector3(0, -2, 0)
local corner_x_normal = 142
local corner_x_hover = 150
local corner_x_press = 130

local group_on_x = 400
local group_off_x = 0
local group_offright_x = 1000
local group_anim_t = 0.3


function M.init_btn(self)
	gui.set_color(self.node, normalcolor)
	gui.set_color(self.textnode, normal_text_color)
	self.leftcorners = gui.get_node(self.name .. "/corners_left")
	self.rightcorners = gui.get_node(self.name .. "/corners_right")
	gui.set_color(self.leftcorners, normalcolor)
	gui.set_color(self.rightcorners, normalcolor)
end

function M.hover_btn(self)
	msg.post("main:/root#soundman", "play sound", {sound = "beep"})
	gui.set_color(self.node, hovercolor)
	gui.animate(self.node, "color", hoverflashcolor, gui.EASING_OUTCUBIC, 0.1, 0, nil, gui.PLAYBACK_ONCE_BACKWARD)
	gui.animate(self.textnode, "position.x", -text_x, gui.EASING_OUTCUBIC, 0.15)
	gui.animate(self.textnode, "color.w", 1, gui.EASING_INOUTSINE, 0.3)
	gui.animate(self.leftcorners, "position.x", -corner_x_hover, gui.EASING_OUTCUBIC, 0.2)
	gui.animate(self.rightcorners, "position.x", corner_x_hover, gui.EASING_OUTCUBIC, 0.2)
end

function M.unhover_btn(self)
	gui.set_color(self.node, normalcolor)
	gui.animate(self.textnode, "position.x", text_x, gui.EASING_OUTCUBIC, 0.6)
	gui.animate(self.textnode, "color.w", 0.5, gui.EASING_INOUTSINE, 0.3)
	gui.animate(self.leftcorners, "position.x", -corner_x_normal, gui.EASING_OUTCUBIC, 0.2)
	gui.animate(self.rightcorners, "position.x", corner_x_normal, gui.EASING_OUTCUBIC, 0.2)
end

function M.press_btn(self)
	msg.post("main:/root#soundman", "play sound", {sound = "button_press"})
	gui.set_color(self.node, presscolor)
	gui.set_position(self.textnode, gui.get_position(self.textnode) + press_text_offset)
	gui.animate(self.leftcorners, "position.x", -corner_x_press, gui.EASING_OUTCUBIC, 0.2)
	gui.animate(self.rightcorners, "position.x", corner_x_press, gui.EASING_OUTCUBIC, 0.2)
end

function M.release_btn(self)
	if self.hovered then
		gui.set_color(self.node, hovercolor)
		gui.animate(self.leftcorners, "position.x", -corner_x_hover, gui.EASING_OUTCUBIC, 0.2)
		gui.animate(self.rightcorners, "position.x", corner_x_hover, gui.EASING_OUTCUBIC, 0.2)
	end
	if self.pressed then
		gui.set_position(self.textnode, gui.get_position(self.textnode) - press_text_offset)
		msg.post("main:/root#soundman", "play sound", {sound = "button_release"})
	end
end

function M.group_enable(self)
	local pos = gui.get_position(self.node)
	pos.x = group_offright_x
	gui.set_position(self.node, pos)
	gui.animate(self.node, "position.x", group_on_x, gui.EASING_INOUTCUBIC, 0.3)
	gui.animate(self.node, "color.w", 1, gui.EASING_LINEAR, 0)
	gui.animate(gui.get_node(self.name .. ".bg"), "position.x", 700, gui.EASING_INOUTQUINT, 0.45, 0, nil, gui.PLAYBACK_ONCE_BACKWARD)
end

function M.group_disable(self)
	gui.animate(self.node, "position.x", group_off_x, gui.EASING_INOUTCUBIC, group_anim_t, 0, function() gui.set_enabled(self.node, false) end)
	gui.animate(self.node, "color.w", 0, gui.EASING_LINEAR, group_anim_t*0.8)
end


return M
