
-- RUU - Version 0.1

local M = {}

local theme = require "main.ruu.ruu theme"


-- ---------------------------------------------------------------------------------
--| 									CONFIG										|
-- ---------------------------------------------------------------------------------
--  				--  INPUT  --
-- adjust hashed values to change the action name required in your input bindings
M.INPUT_DIRKEY = {}
M.INPUT_DIRKEY[hash("up")] = "up"
M.INPUT_DIRKEY[hash("down")] = "down"
M.INPUT_DIRKEY[hash("left")] = "left"
M.INPUT_DIRKEY[hash("right")] = "right"
M.INPUT_CLICK = hash("mouse click")
M.INPUT_ENTER = hash("enter")
M.INPUT_SCROLLUP = hash("scroll up")
M.INPUT_SCROLLDOWN = hash("scroll down")
M.INPUT_TEXT = hash("text")
M.INPUT_BACKSPACE = hash("backspace")

M.INPUT_SCROLL_DIST = 10

--  				--  CONTROL MODE  --
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

-- the main table that stores all widgets and other data.
local wgts = {} -- FORMAT: wgts[key] = new_context_table()
-- Note: cur_hover stores a reference to the button "object"/table, not the button name

local function new_context_table()
	return {all = {}, active = {}, groups = {}, cur_hover = nil, cur_mouse_hover = nil, dragging = 0, hovered = {}}
end

local keyName = hash("arglefraster") -- this really doesn't matter
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
	wgts[keyCount] = new_context_table()
	return k
end

-- make default key and context
M[keyName] = 1
wgts[M[keyName]] = new_context_table()

local function verify_key(key, ctxString)
	ctxString = ctxString or ""
	if not wgts[key] then
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

local function clamp(x, max, min) -- much more legible than math.min(math.max(x, min), max)
	return x > max and max or (x < min and min or x)
end

-- ---------------------------------------------------------------------------------
--|					  PRIVATE FUNCTIONS 3: WIDGET BEHAVIOR							|
-- ---------------------------------------------------------------------------------

-- Button
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
	if not self.pressed then theme.press_btn(self) end
	self.pressed = true
	if self.pressfunc then self.pressfunc() end
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

local function button_hover_adjacent(self, dirstring) -- keyboard/gamepad navigation
	local newbtn = self["neighbor_" .. dirstring]
	if newbtn then
		newbtn:hover()
	end
end

-- Toggle Button
local function release_toggleButton(self, dontfire) -- default is to fire
	if self.pressed and self.hovered then
		self.pressed = false
		if not dontfire then
			self.checked = not self.checked
			if self.releasefunc then self.releasefunc(self.checked) end
		end
		theme.release_toggleButton(self)
	else
		self.pressed = false
	end
end

-- Radio Button
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

-- Slider
local function press_slider(self)
	self.pressed = true
	theme.press_btn(self)
	if self.pressfunc then self.pressfunc() end
	wgts[self.key].dragging = wgts[self.key].dragging + 1
end

local function release_slider(self, dontfire) -- default is to fire
	if self.pressed and self.hovered then
		theme.release_btn(self)
		self.pressed = false
		if self.releasefunc and not dontfire then self.releasefunc() end
		wgts[self.key].dragging = wgts[self.key].dragging - 1
	end
end

local function drag_slider(self, dx, dy)
	self.dragVec.x = dx;  self.dragVec.y = dy
	local dragDist = vmath.dot(self.dragVec, self.angleVec)
	self.pos.x = clamp(self.pos.x + dragDist, self.endx, self.startx)
	self.fraction = self.slideLength == 0 and 0 or (self.pos.x - self.startx)/self.slideLength -- have to avoid dividing by zero
	gui.set_position(self.node, self.pos)

	if self.dragfunc then self.dragfunc(self.fraction) end
end

local function slider_setHandleLength(self, newLength)
	self.handleLength = clamp(newLength, self.length, 0)
	self.slideLength = self.length - self.handleLength
	self.startx = self.handleLength/2
	self.endx = self.startx + self.slideLength

	self.pos.x = vmath.lerp(self.fraction, self.startx, self.endx)
	gui.set_position(self.node, self.pos)

	if self.autoResize then -- for scroll bar style sliders
		local size = gui.get_size(self.node)
		size.x = self.handleLength
		gui.set_size(self.node, size)
	end
end

-- Scroll Box
local function scrollBox_hover(self)
	self.hovered = true
end

local function scrollBox_unhover(self)
	self.hovered = false
end

local function scrollBox_press(self)
	wgts[self.key].dragging = wgts[self.key].dragging + 1
end

local function scrollBox_release(self)
	wgts[self.key].dragging = wgts[self.key].dragging - 1
end

local function scrollBox_scroll(self, percent)
	percent = 1 - percent
	local pos = gui.get_position(self.child)
	if self.horiz then pos.x = self.viewLength/2 + self.scrollLength * percent
	else pos.y = self.viewLength/2 + self.scrollLength * percent
	end
	gui.set_position(self.child, pos)
end

-- ---------------------------------------------------------------------------------
--| 							PUBLIC FUNCTIONS:									|
-- ---------------------------------------------------------------------------------

function M.update_mouse(key, actionx, actiony, dx, dy) -- should call this from gui script before click and release events
	-- If dragging, don't check for collisions or anything, just drag.
	-- When the mouse button is released the drag will end and things will go back to normal
	-- 			I might want to update mouse again after mouse release . . .
	if type(key) == "table" then key = key[keyName] end
	local hitAny = false

	if wgts[key].dragging > 0 then
		for i, v in ipairs(wgts[key].hovered) do if v.drag then v:drag(dx, dy) end end
		local hitAny = true
	else
		for k, v in pairs(wgts[key].active) do -- hit test all active widgets
			if gui.pick_node(v.node, actionx, actiony) and (not v.stencilNode and true or gui.pick_node(v.stencilNode, actionx, actiony)) then
				-- hit
				hitAny = true
				if not v.hovered then
					print("Hover")
					table.insert(wgts[key].hovered, v) -- add to hovered list
					v:hover()
				end
			elseif v.hovered then
				for i, btn in ipairs(wgts[key].hovered) do
					if btn == v then
						print("Unhover")
						table.remove(wgts[key].hovered, i)
						v:unhover()
					end
				end
			end
		end
	end
	return hitAny -- for checking if input is consumed
end

function M.on_input(key, action_id, action)
	key = key[keyName]
	if not action_id then -- Mouse movement
		M.update_mouse(key, action.x, action.y, action.dx, action.dy)
		-- if you wish to tell if the mouse is over a button in your gui script you can call M.update_mouse directly and get the return value.
	elseif action_id == M.INPUT_CLICK then -- Mouse click
		if action.pressed then
			for i, v in ipairs(wgts[key].hovered) do v:press() end
		elseif action.released then
			for i, v in ipairs(wgts[key].hovered) do v:release() end
		end
	elseif action_id == M.INPUT_ENTER then -- Keyboard/Gamepad enter
		if action.pressed then
			for i, v in ipairs(wgts[key].hovered) do v:press() end
		elseif action.released then
			for i, v in ipairs(wgts[key].hovered) do v:release() end
		end
	elseif action_id == M.INPUT_SCROLLUP then
		if action.pressed then
			for i, v in ipairs(wgts[key].hovered) do if v.drag then v:drag(M.INPUT_SCROLL_DIST, M.INPUT_SCROLL_DIST) end end
			M.update_mouse(key, action.x, action.y, action.dx, action.dy)
		end
	elseif action_id == M.INPUT_SCROLLDOWN then
		if action.pressed then
			for i, v in ipairs(wgts[key].hovered) do if v.drag then v:drag(-M.INPUT_SCROLL_DIST, -M.INPUT_SCROLL_DIST) end end
			M.update_mouse(key, action.x, action.y, action.dx, action.dy)
		end
	elseif M.INPUT_DIRKEY[action_id] and action.pressed then -- Keyboard/Gamepad navigation
		if wgts[key].cur_hover then wgts[key].cur_hover:hover_adj(M.INPUT_DIRKEY[action_id]) end
	end
end

function M.activate_btn(key, button)
	key = key[keyName]
	wgts[key].active[button] = wgts[key].all[button]
end

function M.deactivate_btn(key, button)
	key = key[keyName]
	local b = wgts[key].all[button]
	wgts[key].active[button] = nil
	if b.hovered then b:unhover() end
end

function M.btn_set_pressfunc(key, button, func)
	key = key[keyName]
	wgts[key].all[button].pressfunc = func
end

function M.btn_set_releasefunc(key, button, func)
	key = key[keyName]
	wgts[key].all[button].releasefunc = func
end

function M.btn_set_text(key, button, text)
	key = key[keyName]
	local b = wgts[key].all[button]
	b.text = text
	gui.set_text(b.textnode, text)
end

function M.btn_set_neighbors(key, button, up, down, left, right)
	key = key[keyName]
	local b = wgts[key].all[button]
	if up then b.neighbor_up = wgts[key].all[up] end
	if down then b.neighbor_down = wgts[key].all[down] end
	if left then b.neighbor_left = wgts[key].all[left] end
	if right then b.neighbor_right = wgts[key].all[right] end
end

-- Button List, Auto-set Neighbors - Set the buttons' neighbors so they are a wrapping list.
function M.btnlist_autoset_neighbors(key, list, vertical)
	key = key[keyName]
	local reflist = {}
	for i, v in ipairs(list) do
		table.insert(reflist, wgts[key].all[v])
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

function M.widgets_setStencil(key, stencilNode, ...)
	key = key[keyName]
	for i, v in ipairs({...}) do
		wgts[key].all[v].stencilNode = stencilNode
	end
end

local function new_baseWidget(key, name, active, pressfunc, releasefunc)
	verify_key(key, "new_baseWidget")
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
	wgts[key].all[name] = widget
	if active then wgts[key].active[name] = widget end
	return widget
end

function M.new_button(key, name, active, pressfunc, releasefunc)
	if type(key) == "table" then key = key[keyName] end
	local button = new_baseWidget(key, name, active, pressfunc, releasefunc)
	button.textnode = gui.get_node(name .. "/text")
	button.text = gui.get_text(button.textnode)
	theme.init_btn(button)
	return button
end

function M.new_toggleButton(key, name, active, pressfunc, releasefunc, checked)
	if type(key) == "table" then key = key[keyName] end
	local button = new_baseWidget(key, name, active, pressfunc, releasefunc)
	button.checked = checked
	button.textnode = gui.get_node(name .. "/text")
	button.text = gui.get_text(button.textnode)
	button.release = release_toggleButton
	theme.init_toggleButton(button)
	return button
end

function M.new_radioButtonGroup(key, namesList, active, pressfunc, releasefunc, checkedName)
	if type(key) == "table" then key = key[keyName] end
	local buttons = {}
	for i, name in ipairs(namesList) do
		local button = new_baseWidget(key, name, active, pressfunc, releasefunc)
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

function M.new_slider(key, name, active, pressfunc, releasefunc, dragfunc, length, handleLength, startFraction, autoResizeHandle)
	if type(key) == "table" then key = key[keyName] end
	local button = new_baseWidget(key, name, active, pressfunc, releasefunc)
	button.rootNode = gui.get_node(name .. "/root")
	button.endpointNode = gui.get_node(name .. "/endpoint")
	local rot = math.rad(gui.get_rotation(button.rootNode).z)
	button.angleVec = vmath.vector3(math.cos(rot), math.sin(rot), 0)
	button.length = length or gui.get_position(button.endpointNode).x -- length of slider range
	button.handleLength = handleLength or gui.get_size(button.node).x -- "physical" length of slider handle - default to x of node, input 0 if desired.
	-- meant for scroll bar style sliders where the handle fits inside the bar.

	--			The following are set in button:setHandleLength()
	--button.slideLength = length - handleLength : actual distance slider can move
	--button.startx = origin X (0.0) + handle length/2
	--button.endx = startx + slideLength

	button.fraction = startFraction or 0 -- 0.0-1.0 position of slider in its range. 0.0 --> left/bottom
	button.dragVec = vmath.vector3() -- used for (dx, dy) in drag function to avoid creating a new vector every frame of dragging
	button.autoResize = autoResizeHandle -- should resize the actual handle node to match `handleLength`. Defaults to nil/false
	button.press = press_slider
	button.release = release_slider
	button.dragfunc = dragfunc -- called continuously whenever the slider is moved.
	button.drag = drag_slider
	button.setHandleLength = slider_setHandleLength

	-- set starting pos, etc.
	button.pos = gui.get_position(button.node) -- will use the current Y and Z and only change X
	button:setHandleLength(button.handleLength)
	theme.init_btn(button)
	return button
end

function M.new_scrollBox(key, name, childname, active, horiz, scrollbarname)
	if type(key) == "table" then key = key[keyName] end
	local box = new_baseWidget(key, name, active)
	box.horiz = horiz
	box.child = gui.get_node(childname)
	box.viewLength = horiz and gui.get_size(box.node).x or gui.get_size(box.node).y -- size of mask
	box.scrollLength = (horiz and gui.get_size(box.child).x or gui.get_size(box.child).y) - box.viewLength -- max movement of child
	box.range = math.max(0, box.scrollLength)
	box.scroll = scrollBox_scroll
	box.hover = scrollBox_hover
	box.unhover = scrollBox_unhover
	box.press = scrollBox_press
	box.release = scrollBox_release

	local handleLength = box.viewLength/(box.scrollLength) * box.viewLength -- assuming the scrollbar is the same length as the mask
	local scrollbar = M.new_slider(key, scrollbarname, active, nil, nil, function(value) box:scroll(value) end, box.viewLength, handleLength, 1, true)
	scrollbar.scrollBox = box
	box.scrollbar = scrollbar
	box.touchScroll = false -- click-drag to scroll or not.
	box.drag = function(self, dx, dy) local a = 1 if self.touchScroll then a = -self.viewLength / self.scrollLength end box.scrollbar:drag(dx*a, dy*a) end
	return box
end

-- Group, Enable - Activates all buttons in the group and makes sure the root node is enabled (visible).
--		Activate_btn() will enable the buttons if they are disabled
--		Use theme.group_enable() for custom animations, etc.
function M.group_enable(key, name)
	key = key[keyName]
	local g = wgts[key].groups[name]
	gui.set_enabled(g.node, true)
	theme.group_enable(g)
	for i, v in ipairs(g.children) do
		M.activate_btn(key, v)
	end
	if mode == M.MODE_KEYBOARD then wgts[key].all[g.children[1]]:hover() end
end

-- It's up to the theme hide the node or not.
function M.group_disable(key, name)
	key = key[keyName]
	local g = wgts[key].groups[name]
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

function M.new_group(key, name, rootnode, children, autoset_wgts_vert, autoset_wgts_horiz, disable)
	key = key[keyName]
	verify_key(key, "new_group")
	autoset_wgts_vert = autoset_wgts_vert or false
	autoset_wgts_horiz = autoset_wgts_horiz or false
	disable = disable or false
	local group = {
		name = name,
		key = key,
		node = gui.get_node(rootnode),
		children = children -- list of button names
	}
	if disable then gui.set_enabled(group.node, false) end
	wgts[key].groups[name] = group
	if autoset_wgts_vert then M.btnlist_autoset_neighbors(key, children, true)
	elseif autoset_wgts_horiz then M.btnlist_autoset_neighbors(key, children, false)
	end
end


return M
