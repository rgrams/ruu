
-- RUU - Version 0.1

local M = {}

local theme = require "main.ruu.ruu default theme"

--  INPUT
M.inputKeyDirs = {}
M.inputKeyDirs[hash("ui_up")] = "up"
M.inputKeyDirs[hash("ui_down")] = "down"
M.inputKeyDirs[hash("ui_left")] = "left"
M.inputKeyDirs[hash("ui_right")] = "right"

M.input_click = hash("mouse click")
M.input_enter = hash("enter")
M.input_scrollUp = hash("scroll up")
M.input_scrollDown = hash("scroll down")

M.input_scroll_dist = 10

-- For keyboard only, or keyboard and mouse - Buttons stay hovered until another is hovered. Always hovers a default initial button.
M.MODE_KEYBOARD = 1
-- Meant for mouse only, keys can still be used once the mouse hovers a button - buttons hover when mouse enters and unhover when it exits.
M.MODE_MOUSE = 2
-- For touch - no hover state used, cursor position only checked while a tap is held.
-- M.MODE_MOBILE = 3

local mode = M.MODE_KEYBOARD

-- ---------------------------------------------------------------------------------
--| 					PRIVATE FUNCTIONS 1: SETUP & KEYS							|
-- ---------------------------------------------------------------------------------

local btns = {} -- FORMAT = btns[key] = {all = {}, active = {}, groups = {}, cur_hover = nil, cur_mouse_hover = nil, dragging = false}
-- Note: cur_hover stores a reference to the button "object"/table, not the button name

local function new_context_table()
	return {all = {}, active = {}, groups = {}, cur_hover = nil, cur_mouse_hover = nil}
end

local keyName = hash("arglefraster")
local keyCount = 1

-- ##########  Context Keys  ##########
-- Each key defines a totally separate GUI context.
-- Unless you're doing multiplayer or something fancy, you only need the default one (i.e. you never need to call M.getkey())
--	 The 'key' given to all public functions is a table with a key 'keyName' mapped to a unique value (an integer).
--	 The default 'key' table is the module itself. (used by functions called with a colon, ruu:func())
function M.getkey()
	local k = {}
	keyCount = keyCount + 1
	k[keyName] = keyCount
	btns[keyCount] = new_context_table()
	return k
end

-- make default key and context
M[keyName] = 1
btns[M[keyName]] = new_context_table()

local function verify_key(key, ctxString)
	ctxString = ctxString or ""
	if not btns[key] then
		error("RUU -" .. ctxString .. "- ERROR: Invalid key. Call functions with a colon (ruu:func()) or with a key made with ruu.getkey(). (i.e. ruu.func(key)).")
	end
end

-- ---------------------------------------------------------------------------------
--| 					  PRIVATE FUNCTIONS 2: UTILITIES							|
-- ---------------------------------------------------------------------------------

local function nextval(t, i) -- looping, used for setting up button list neighbors
	if #t == 0 then return 0 end
	i = i + 1
	if i > #t then i = 1 end
	return t[i]
end

local function prevval(t, i) -- looping, used for setting up button list neighbors
	i = i - 1
	if i < 1 then i = #t end
	return t[i]
end

-- ---------------------------------------------------------------------------------
--|					  PRIVATE FUNCTIONS 3: WIDGET BEHAVIOR							|
-- ---------------------------------------------------------------------------------

local function hover_button(self)
	self.hovered = true
	theme.hover_btn(self)
end

local function unhover_button(self)
	self.hovered = false
	theme.unhover_btn(self)
	if self.pressed then self:release(true) end
end

local function press_button(self)
	self.pressed = true
	theme.press_btn(self)
	if self.pressfunc then self.pressfunc() end
end

local function press_slider(self)
	self.pressed = true
	theme.press_btn(self)
	if self.pressfunc then self.pressfunc() end
	btns[self.key].dragging = true
end

local function release_button(self, dontfire) -- default is to fire
	if self.pressed and self.hovered then
		theme.release_btn(self)
		self.pressed = false
		if self.releasefunc and not dontfire then self.releasefunc() end
	else
		self.pressed = false
	end
end

local function release_checkbox(self, dontfire) -- default is to fire
	if self.pressed and self.hovered then
		self.pressed = false
		if not dontfire then
			self.checked = not self.checked
			if self.releasefunc then self.releasefunc(self.checked) end
		end
		theme.release_checkbox(self)
	else
		self.pressed = false
	end
end

local function uncheck_radioButton(self)
	if self.checked then theme.uncheck_radioButton(self) end
	self.checked = false
end

local function release_radioButton(self, dontfire) -- default is to fire
	if self.pressed and self.hovered then
		self.pressed = false
		if not dontfire then
			if not self.checked then
				for i, btn in ipairs(self.siblings) do btn:uncheck() end
				self.checked = true
			end
			if self.releasefunc then
				self.releasefunc(self.name)
			end
		end
		theme.release_radioButton(self)
	else
		self.pressed = false
	end
end

local function release_slider(self, dontfire) -- default is to fire
	if self.pressed and self.hovered then
		theme.release_btn(self)
		self.pressed = false
		if self.releasefunc and not dontfire then self.releasefunc() end
		btns[self.key].dragging = false
	end
end

local function drag_slider(self, dx, dy)
	if self.horiz then
		self.pos.x = math.max(self.origin.x, math.min(self.origin.x + self.range, self.pos.x + dx))
		self.value = (self.pos.x - self.origin.x)/self.range
	else
		self.pos.y = math.max(self.origin.y, math.min(self.origin.y + self.range, self.pos.y + dy))
		self.value = (self.pos.y - self.origin.y)/self.range
	end
	gui.set_position(self.node, self.pos)
	if self.dragfunc then self.dragfunc(self.value) end
end

local function drag_scrollBar(self, dx, dy, dontfire)
	if self.horiz then
		self.pos.x = math.max(self.origin.x + self.width/2, math.min(self.origin.x + self.width/2 + self.range, self.pos.x + dx))
		if self.range > 0 then self.value = (self.pos.x - self.origin.x - self.width/2)/self.range
		else self.value = 0
		end
	else
		self.pos.y = math.max(self.origin.y + self.width/2, math.min(self.origin.y + self.width/2 + self.range, self.pos.y + dy))
		if self.range > 0 then self.value = (self.pos.y - self.origin.y - self.width/2)/self.range
		else self.value = 0
		end
	end
	gui.set_position(self.node, self.pos)
	if self.dragfunc and not dontfire then self.dragfunc(self.value) end
end

local function scrollBar_setWidth(self, newwidth)
	if newwidth > self.length then newwidth = self.length end
	self.width = newwidth
	self.range = self.length - self.width
	local size = gui.get_size(self.node)
	if self.horiz then
		size.x = self.width
		self.pos.x = self.origin.x + self.width/2 + self.value * self.range
	else
		size.y = self.width
		self.pos.y = self.origin.y + self.width/2 + self.value * self.range
	end
	gui.set_size(self.node, size)
	gui.set_position(self.node, self.pos)
end

local function scrollBox_scroll(self, percent)
	percent = 1 - percent
	local pos = gui.get_position(self.child)
	if self.horiz then pos.x = self.viewLength/2 + self.scrollLength * percent
	else pos.y = self.viewLength/2 + self.scrollLength * percent
	end
	gui.set_position(self.child, pos)
end

local function button_hover_adjacent(self, dirstring) -- keyboard/gamepad navigation
	local newbtn = self["neighbor_" .. dirstring]
	if newbtn then
		newbtn:hover()
	end
end

-- ---------------------------------------------------------------------------------
--| 							PUBLIC FUNCTIONS:									|
-- ---------------------------------------------------------------------------------

function M.update_mouse(key, actionx, actiony, dx, dy) -- should call this from gui script before click and release events
	-- If dragging, don't check for collisions or anything, just drag.
	-- When the mouse button is released the drag will end and things will go back to normal
	-- 			I might want to update mouse again after mouse release . . .
	if type(key) == "table" then key = key[keyName] end
	local hit = false

	if btns[key].dragging then
		btns[key].cur_hover:drag(dx, dy)
		local hit = true
	else
		for k, v in pairs(btns[key].active) do -- hit test all active widgets
			if gui.pick_node(v.node, actionx, actiony) then
				if btns[key].cur_hover and v ~= btns[key].cur_hover then
					btns[key].cur_hover:unhover()
				end
				if not v.hovered then
					v:hover()
				end
				hit = true
				btns[key].cur_mouse_hover = v
				btns[key].cur_hover = v
			elseif v.hovered and mode == M.MODE_MOUSE then
				v:unhover()
			end
		end
		if not hit then
			if btns[key].cur_mouse_hover then
				if btns[key].cur_mouse_hover.pressed then
					btns[key].cur_mouse_hover:release(true)
				end
				btns[key].cur_mouse_hover = nil
			end
		end
	end
	return hit -- for checking if input is consumed
end

function M.on_input(key, action_id, action)
	key = key[keyName]
	if not action_id then -- Mouse movement
		M.update_mouse(key, action.x, action.y, action.dx, action.dy)
		-- if you wish to tell if the mouse is over a button in your gui script you can call M.update_mouse directly and get the return value.
	elseif action_id == M.input_click then -- Mouse click
		if action.pressed then
			if btns[key].cur_mouse_hover then btns[key].cur_hover:press() end
		elseif action.released then
			if btns[key].cur_mouse_hover then btns[key].cur_hover:release() end
		end
	elseif action_id == M.input_enter then -- Keyboard/Gamepad enter
		if action.pressed then
			if btns[key].cur_hover then btns[key].cur_hover:press() end
		elseif action.released then
			if btns[key].cur_hover then btns[key].cur_hover:release() end
		end
	elseif action_id == M.input_scrollUp then
		if action.pressed then
			if btns[key].cur_hover and btns[key].cur_hover.drag then
				btns[key].cur_hover:drag(M.input_scroll_dist, M.input_scroll_dist)
			end
		end
	elseif action_id == M.input_scrollDown then
		if action.pressed then
			if btns[key].cur_hover and btns[key].cur_hover.drag then
				btns[key].cur_hover:drag(-M.input_scroll_dist, -M.input_scroll_dist)
			end
		end
	elseif M.inputKeyDirs[action_id] and action.pressed then -- Keyboard/Gamepad navigation
		if btns[key].cur_hover then btns[key].cur_hover:hover_adj(M.inputKeyDirs[action_id]) end
	end
end

function M.activate_btn(key, button)
	key = key[keyName]
	btns[key].active[button] = btns[key].all[button]
end

function M.deactivate_btn(key, button)
	key = key[keyName]
	local b = btns[key].all[button]
	btns[key].active[button] = nil
	if b.hovered then b:unhover() end
end

function M.btn_set_pressfunc(key, button, func)
	key = key[keyName]
	btns[key].all[button].pressfunc = func
end

function M.btn_set_releasefunc(key, button, func)
	key = key[keyName]
	btns[key].all[button].releasefunc = func
end

function M.btn_set_text(key, button, text)
	key = key[keyName]
	local b = btns[key].all[button]
	b.text = text
	gui.set_text(b.textnode, text)
end

function M.btn_set_neighbors(key, button, up, down, left, right)
	key = key[keyName]
	local b = btns[key].all[button]
	if up then b.neighbor_up = btns[key].all[up] end
	if down then b.neighbor_down = btns[key].all[down] end
	if left then b.neighbor_left = btns[key].all[left] end
	if right then b.neighbor_right = btns[key].all[right] end
end

-- Button List, Auto-set Neighbors - Set the buttons' neighbors so they are a wrapping list.
function M.btnlist_autoset_neighbors(key, list, vertical)
	key = key[keyName]
	local reflist = {}
	for i, v in ipairs(list) do
		table.insert(reflist, btns[key].all[v])
	end
	if vertical then -- vertical list
		for i, b in ipairs(reflist) do
			b.neighbor_up = prevval(reflist, i)
			b.neighbor_down = nextval(reflist, i)
		end
	else -- horizontal list (left-to-right)
		for i, b in ipairs(reflist) do
			b.neighbor_left = prevval(reflist, i)
			b.neighbor_right = nextval(reflist, i)
		end
	end
end

local function newBaseWidget(key, name, active, pressfunc, releasefunc)
	verify_key(key, "newBaseWidget")
	active = active or false
	local widget = {
		name = name,
		node = gui.get_node(name .. "/body"),
		key = key,
		pressed = false,
		hovered = false,
		hover = hover_button,
		unhover = unhover_button,
		press = press_button,
		pressfunc = pressfunc,
		release = release_button,
		releasefunc = releasefunc,
		neighbor_up = nil,
		neighbor_down = nil,
		neighbor_left = nil,
		neighbor_right = nil,
		neighbor_next = nil,
		neighbor_prev = nil,
		hover_adj = button_hover_adjacent
	}
	btns[key].all[name] = widget
	if active then btns[key].active[name] = widget end
	return widget
end

function M.newButton(key, name, active, pressfunc, releasefunc)
	if type(key) == "table" then key = key[keyName] end
	local button = newBaseWidget(key, name, active, pressfunc, releasefunc)
	button.textnode = gui.get_node(name .. "/text")
	button.text = gui.get_text(button.textnode)
	theme.init_btn(button)
	return button
end

function M.newCheckbox(key, name, active, pressfunc, releasefunc, checked)
	if type(key) == "table" then key = key[keyName] end
	local button = newBaseWidget(key, name, active, pressfunc, releasefunc)
	button.checked = checked
	button.textnode = gui.get_node(name .. "/text")
	button.text = gui.get_text(button.textnode)
	button.release = release_checkbox
	theme.init_checkbox(button)
	return button
end

function M.newRadioButtonGroup(key, namesList, active, pressfunc, releasefunc, checkedName)
	if type(key) == "table" then key = key[keyName] end
	local buttons = {}
	for i, name in ipairs(namesList) do
		local button = newBaseWidget(key, name, active, pressfunc, releasefunc)
		button.textnode = gui.get_node(name .. "/text")
		button.text = gui.get_text(button.textnode)
		button.checked = name == checkedName
		button.siblings = {}
		button.release = release_radioButton
		button.uncheck = uncheck_radioButton
		theme.init_radioButton(button)
		table.insert(buttons, button)
	end
	for i, me in ipairs(buttons) do
		for i, sib in ipairs(buttons) do
			if sib ~= me then table.insert(me.siblings, sib) end
		end
	end
end

function M.newSlider(key, name, active, pressfunc, releasefunc, dragfunc, horiz, range, value)
	if type(key) == "table" then key = key[keyName] end
	local button = newBaseWidget(key, name, active, pressfunc, releasefunc)
	button.origin = gui.get_position(button.node)
	button.pos = vmath.vector3(button.origin)
	button.horiz = horiz -- true for horizontal slider, false for vertical
	button.range = range or 200 -- distance slider can move
	button.value = value or 0 -- 0.0-1.0 position of slider in its range. 0.0 --> left/bottom
	button.press = press_slider
	button.release = release_slider
	button.dragfunc = dragfunc -- called continuously whenever the slider is moved.
	button.drag = drag_slider
	if button.value > 0 then -- set initial position
		button.pos.x = horiz and (button.pos.x + button.value * button.range) or button.pos.x
		button.pos.y = not horiz and (button.pos.y + button.value * button.range) or button.pos.y
		gui.set_position(button.node, button.pos)
	end
	if not horiz then gui.set_rotation(gui.get_node(name .. "/bar"), vmath.vector3(0, 0, 90)) end
	theme.init_btn(button)
	return button
end

function M.newScrollBar(key, name, active, pressfunc, releasefunc, dragfunc, horiz, length, value, width)
	if type(key) == "table" then key = key[keyName] end
	local button = newBaseWidget(key, name, active, pressfunc, releasefunc)
	button.origin = gui.get_position(button.node)
	button.pos = vmath.vector3(button.origin)
	button.horiz = horiz -- true for horizontal slider, false for vertical
	button.width = width or gui.get_size(button.node).x -- width of slider handle
	button.length = range or 200 -- length of bar
	button.range = button.length - button.width -- distance slider can move
	button.value = value or 0 -- 0.0-1.0 position of slider in its range. 0.0 --> left/bottom
	button.press = press_slider
	button.release = release_slider
	button.dragfunc = dragfunc -- called continuously whenever the slider is moved.
	button.drag = drag_scrollBar
	button.setWidth = scrollBar_setWidth
	if button.value > 0 then -- set initial position
		button.pos.x = horiz and (button.pos.x + button.value * button.range) or button.pos.x
		button.pos.y = not horiz and (button.pos.y + button.value * button.range) or button.pos.y
		gui.set_position(button.node, button.pos)
	end
	button:setWidth(button.width)
	if not horiz then gui.set_rotation(gui.get_node(name .. "/bar"), vmath.vector3(0, 0, 90)) end
	theme.init_btn(button)
	return button
end

function M.newScrollBox(key, name, childname, active, horiz, scrollbarname)
	if type(key) == "table" then key = key[keyName] end
	local box = newBaseWidget(key, name, active)
	box.horiz = horiz
	box.child = gui.get_node(childname)
	box.viewLength = horiz and gui.get_size(box.node).x or gui.get_size(box.node).y -- size of mask
	box.scrollLength = (horiz and gui.get_size(box.child).x or gui.get_size(box.child).y) - box.viewLength -- max movement of child
	box.range = math.max(0, box.scrollLength)
	box.scroll = scrollBox_scroll
	box.hover = function() end
	box.unhover, box.press, box.release = box.hover, box.hover, box.hover

	local barwidth = box.viewLength/(box.scrollLength + box.viewLength) * box.viewLength -- assuming the scrollbar is the same length as the mask
	local scrollbar = M.newScrollBar(key, scrollbarname, active, nil, nil, function(value) box:scroll(value) end, false, box.viewLength, 1, barwidth)
	scrollbar.scrollBox = box
	box.scrollbar = scrollbar
	box.drag = box.scrollbar.drag
	return box
end

-- Group, Enable - Activates all buttons in the group and makes sure the root node is enabled (visible).
--		Activate_btn() will enable the buttons if they are disabled
--		Use theme.group_enable() for custom animations, etc.
function M.group_enable(key, name)
	key = key[keyName]
	local g = btns[key].groups[name]
	gui.set_enabled(g.node, true)
	theme.group_enable(g)
	for i, v in ipairs(g.children) do
		M.activate_btn(key, v)
	end
	if mode == M.MODE_KEYBOARD then btns[key].all[g.children[1]]:hover() end
end

-- It's up to the theme hide the node or not.
function M.group_disable(key, name)
	key = key[keyName]
	local g = btns[key].groups[name]
	theme.group_disable(g)
	for i, v in ipairs(g.children) do
		M.deactivate_btn(key, v)
	end
end

-- Convenience function to disable one group and enable another
function M.group_swap(key, from, to)
	key = key[keyName]
	M.group_disable(key, from)
	M.group_enable(key, to)
end

function M.new_group(key, name, rootnode, children, autoset_btns_vert, autoset_btns_horiz, disable)
	key = key[keyName]
	verify_key(key, "new_group")
	autoset_btns_vert = autoset_btns_vert or false
	autoset_btns_horiz = autoset_btns_horiz or false
	disable = disable or false
	local group = {
		name = name,
		key = key,
		node = gui.get_node(rootnode),
		children = children -- list of button names
	}
	if disable then gui.set_enabled(group.node, false) end
	btns[key].groups[name] = group
	if autoset_btns_vert then M.btnlist_autoset_neighbors(key, children, true)
	elseif autoset_btns_horiz then M.btnlist_autoset_neighbors(key, children, false)
	end
end


return M
