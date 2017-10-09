
-- RUU - Version 0.1

local M = {}

local theme = require "main.ruu.ruu theme"


-- ---------------------------------------------------------------------------------
--| 							CONFIG: DEFAULT VALUES								|
-- ---------------------------------------------------------------------------------
-- ##########  INPUT  ##########
-- Hashed values are the action names required in your input bindings
M.INPUT_DIRKEY = {}
M.INPUT_DIRKEY[hash("up")] = "neighbor_up"
M.INPUT_DIRKEY[hash("down")] = "neighbor_down"
M.INPUT_DIRKEY[hash("left")] = "neighbor_left"
M.INPUT_DIRKEY[hash("right")] = "neighbor_right"
M.INPUT_CLICK = hash("mouse click")
M.INPUT_ENTER = hash("enter")
M.INPUT_SCROLLUP = hash("scroll up")
M.INPUT_SCROLLDOWN = hash("scroll down")
M.INPUT_TEXT = hash("text")
M.INPUT_BACKSPACE = hash("backspace")

M.INPUT_SCROLL_DIST = 10

-- ##########  CONTROL MODE  ##########
-- KEYBOARD: For keyboard only, or keyboard and mouse - Buttons stay hovered until another is hovered. Always hovers a default initial button.
M.MODE_KEYBOARD = 1

-- MOUSE: For mouse only, keys still work once the mouse hovers a button (if you give Ruu key input) - buttons hover when mouse enters and unhover when it exits.
M.MODE_MOUSE = 2

-- MOBILE: For touch - no hover state used, cursor position only checked while a tap is held.
-- Rather, everything is unhovered on touch release.
M.MODE_MOBILE = 3

M.mode = M.MODE_KEYBOARD

local sysInfo = sys.get_sys_info()
if sysInfo.system_name == "Android" or sysInfo.system_name == "iPhone OS" then print("mobile build") M.mode = M.MODE_MOBILE end


-- ---------------------------------------------------------------------------------
--| 					PRIVATE FUNCTIONS 1: SETUP & KEYS							|
-- ---------------------------------------------------------------------------------

-- the main table that stores all widgets and other data.
local wgts = {} -- FORMAT: wgts[key] = new_context_table()

local function new_context_table()
	return {all = {}, active = {}, groups = {}, cur_focus = nil, dragging = {}, dragCount = 0, hovered = {}}
	-- widgets are keyed by their node name (string).
	-- cur_focus = current widget with keyboard focus
end

M.keyName = hash("arglefraster") -- this really doesn't matter
local keyCount = 1

-- ##########  Context Keys  ##########
-- Each key defines a totally separate GUI context.
-- Unless you're doing multiplayer or something fancy, you only need the default one (i.e. you never need to call M.getkey())
--	 The 'key' given to all public functions is a table with a key 'M.keyName' mapped to a unique value (an integer).
--	 The default 'key' table is the module itself. (used by functions called with a colon, ruu:func())
function M.getkey()
	local k = {}
	keyCount = keyCount + 1
	k[M.keyName] = keyCount
	wgts[keyCount] = new_context_table()
	return k
end

-- make default key and context
M[M.keyName] = 1
wgts[M[M.keyName]] = new_context_table()

local function verify_key(key, ctxString)
	ctxString = ctxString or ""
	if not wgts[key] then
		key = tostring(key)
		error("RUU -" .. ctxString .. "- ERROR: Invalid key: '" .. key .. "'. Call functions with a colon (ruu:func()) or with a key made with ruu.getkey(). (i.e. ruu.func(key)).")
	end
end

-- ---------------------------------------------------------------------------------
--| 					  PRIVATE FUNCTIONS 2: UTILITIES							|
-- ---------------------------------------------------------------------------------

local function nextval(t, i) -- looping, used for setting up button list neighbors
	if #t == 0 then return false end
	i = i + 1
	if i > #t then i = 1 end
	return t[i]
end

local function prevval(t, i) -- looping, used for setting up button list neighbors
	if #t == 0 then return false end
	i = i - 1
	if i < 1 then i = #t end
	return t[i]
end

local function clamp(x, max, min) -- much more legible than math.min(math.max(x, min), max)
	return x > max and max or (x < min and min or x)
end

local pivots = {
	 [gui.PIVOT_CENTER] = vmath.vector3(0, 0, 0),
	 [gui.PIVOT_N] = vmath.vector3(0, 1, 0),
	 [gui.PIVOT_NE] = vmath.vector3(1, 1, 0),
	 [gui.PIVOT_E] = vmath.vector3(1, 0, 0),
	 [gui.PIVOT_SE] = vmath.vector3(1, -1, 0),
	 [gui.PIVOT_S] = vmath.vector3(0, -1, 0),
	 [gui.PIVOT_SW] = vmath.vector3(-1, -1, 0),
	 [gui.PIVOT_W] = vmath.vector3(-1, 0, 0),
	 [gui.PIVOT_NW] = vmath.vector3(-1, 1, 0)
 }

local function get_center_position(node) -- pivot-independent get_position for scroll areas
	local pivotVec = pivots[gui.get_pivot(node)]
	local size = gui.get_size(node)
	pivotVec.x = pivotVec.x * size.x * 0.5;  pivotVec.y = pivotVec.y * size.y * 0.5
	return gui.get_position(node) - pivotVec
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

local function focus_button(self)
	if not self.focused then
		self.focused = true
		theme.focus_btn(self)
	end
end

local function unfocus_button(self)
	if self.focused then
		if self.pressed then self:release(true) end
		self.focused = false
		theme.unfocus_btn(self)
	end
end

local function press_button(self)
	if not self.pressed then theme.press_btn(self) end
	self.pressed = true
	if self.pressfunc then self.pressfunc() end
end

local function release_button(self, dontfire) -- default is to fire
	if self.pressed and (self.hovered or self.focused) then
		theme.release_btn(self)
		self.pressed = false
		if self.releasefunc and not dontfire then self.releasefunc() end
	else
		self.pressed = false
	end
end

local function button_focus_neighbor(self, action_id)
	local neighbor = self[M.INPUT_DIRKEY[action_id]]
	if neighbor then
		self:unfocus()
		neighbor:focus()
		wgts[self.key].cur_focus = neighbor
	end
end

-- Toggle Button
local function release_toggleButton(self, dontfire) -- default is to fire
	if self.pressed and (self.hovered or self.focused) then
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
	if self.pressed and (self.hovered or self.focused) then
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
	wgts[self.key].dragging[self] = true
	wgts[self.key].dragCount = wgts[self.key].dragCount + 1
end

local function release_slider(self, dontfire) -- default is to fire
	if self.pressed and self.hovered then
		theme.release_btn(self)
		self.pressed = false
		if self.releasefunc and not dontfire then self.releasefunc() end
		wgts[self.key].dragging[self] = nil
		wgts[self.key].dragCount = wgts[self.key].dragCount - 1
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
	theme.slider_setHandleLength(self)
end

-- Scroll Box
local function scrollBox_hover(self)
	self.hovered = true
end

local function scrollBox_unhover(self)
	self.hovered = false
end

local function scrollBox_press(self)
	self.pressed = true
	wgts[self.key].dragging[self] = true
	wgts[self.key].dragCount = wgts[self.key].dragCount + 1
end

local function scrollBox_release(self)
	if self.pressed then
		self.pressed = false
		wgts[self.key].dragging[self] = nil
		wgts[self.key].dragCount = wgts[self.key].dragCount - 1
	end
end

local function scrollBox_scroll(self, fraction)
	fraction = 1 - fraction -- flip scroll bar
	local pos = gui.get_position(self.child)
	local starty = self.viewLength/2
	local endy = self.childHeight - starty
	pos.y = vmath.lerp(fraction, starty, endy)
	gui.set_position(self.child, pos)
end

-- Input Field
local function press_inputField(self)
	if not self.pressed then theme.press_btn(self) end
	self.pressed = true
	if self.pressfunc then self.pressfunc() end
end

local function release_inputField(self, dontfire, keyboard)
	if self.pressed and (self.hovered or self.focused) then
		theme.release_btn(self)
		self.pressed = false
		if self.confirmfunc and keyboard and not dontfire then self.confirmfunc(self.text) end
	else
		self.pressed = false
	end
end

local function focus_inputField(self)
	if not self.focused then
		self.focused = true
		theme.focus_inputField(self)
		self:setText(self.text)
	end
end

local function unfocus_inputField(self)
	if self.focused then
		if self.pressed then self:release(true) end
		self.focused = false
		theme.unfocus_inputField(self)
		gui.set_position(self.textNode, self.textOriginPos)
		gui.set_position(self.cursorNode, self.cursorPos)
	end
end

local function inputField_setText(self, text)
	self.text = text
	gui.set_text(self.textNode, self.text)
	self.cursorPos.x = gui.get_text_metrics(self.font, self.text .. self.endTag).width + self.textOriginPos.x - self.endTagLength

	if self.cursorPos.x > self.halfInsideWidth then -- cursor is out of view, scroll it to the left
		local offset = self.cursorPos.x - self.halfInsideWidth
		self.textPos.x = self.textOriginPos.x - offset
		gui.set_position(self.textNode, self.textPos)
		local x = self.cursorPos.x
		self.cursorPos.x = self.halfInsideWidth
		gui.set_position(self.cursorNode, self.cursorPos)
		self.cursorPos.x = x -- store un-scrolled value of cursorPos for unfocus
	else -- make sure text gets back to the origin pos
		gui.set_position(self.textNode, self.textOriginPos)
		gui.set_position(self.cursorNode, self.cursorPos)
	end

	if self.editfunc then self.editfunc(self.text) end
end

local function inputField_textInput(self, char)
	self:setText(self.text .. char)
end

local function inputField_backspace(self)
	self:setText(string.sub(self.text, 1, -2))
end


-- ---------------------------------------------------------------------------------
--| 							PUBLIC FUNCTIONS:									|
-- ---------------------------------------------------------------------------------

function M.update_mouse(key, actionx, actiony, dx, dy) -- should call this from gui script before click and release events
	if type(key) == "table" then key = key[M.keyName] end
	local hitAny = false

	if wgts[key].dragCount > 0 then
		for wgt, v in pairs(wgts[key].dragging) do if wgt.drag then wgt:drag(dx, dy) end end
		local hitAny = true
	end
	for name, wgt in pairs(wgts[key].active) do -- hit test all active
		if not wgts[key].dragging[wgt] then -- skip hit test for widgets we're currently dragging
			if gui.pick_node(wgt.node, actionx, actiony) and (not wgt.stencilNode and true or gui.pick_node(wgt.stencilNode, actionx, actiony)) then
				-- hit
				hitAny = true
				if not wgt.hovered then
					table.insert(wgts[key].hovered, wgt) -- add to hovered list
					wgt:hover()
				end
			elseif wgt.hovered then
				-- Not hit, but hovered - find & remove from hovered list, and unhover
				for i, v in ipairs(wgts[key].hovered) do
					if v == wgt then
						table.remove(wgts[key].hovered, i)
						wgt:unhover()
					end
				end
			end
		end
	end
	return hitAny -- for checking if input is consumed
end

function M.on_input(key, action_id, action)
	key = key[M.keyName]
	if not action_id then -- Mouse movement
		M.update_mouse(key, action.x, action.y, action.dx, action.dy)
		-- if you wish to tell if the mouse is over a button in your gui script you can call M.update_mouse directly and get the return value.
	elseif action_id == M.INPUT_CLICK then -- Mouse click
		if M.mode == M.MODE_MOBILE then M.update_mouse(key, action.x, action.y, action.dx, action.dy) end
		if action.pressed then
			for i, v in ipairs(wgts[key].hovered) do v:press() end -- press all hovered nodes

			-- give keyboard focus to first hovered node ###  SHOULD HAVE A BETTER CHOOSING METHOD  ###
			if wgts[key].hovered[1] then
				if wgts[key].cur_focus ~= wgts[key].hovered[1] then
					if wgts[key].cur_focus then wgts[key].cur_focus:unfocus() end
					wgts[key].cur_focus = wgts[key].hovered[1]
					wgts[key].cur_focus:focus()
				end
			end
		elseif action.released then
			for i, v in ipairs(wgts[key].hovered) do
				v:release()
				if M.mode == M.MODE_MOBILE then v:unhover() wgts[key].hovered[i] = nil end
			end
		end
	elseif action_id == M.INPUT_ENTER then -- Keyboard/Gamepad enter
		if action.pressed then
			if wgts[key].cur_focus then wgts[key].cur_focus:press() end
		elseif action.released then
			if wgts[key].cur_focus then wgts[key].cur_focus:release(false, true) end
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
		if wgts[key].cur_focus then
			wgts[key].cur_focus:focus_neighbor(action_id)
		end
	elseif action_id == M.INPUT_BACKSPACE and (action.pressed or action.repeated) then
		local v = wgts[key].cur_focus
		if v and v.backspace then v:backspace() end
	elseif action_id == M.INPUT_TEXT then
		local v = wgts[key].cur_focus
		if v and v.textInput then v:textInput(action.text) end
	end
end

function M.activate_btn(key, button)
	key = key[M.keyName]
	wgts[key].active[button] = wgts[key].all[button]
end

function M.deactivate_btn(key, button)
	key = key[M.keyName]
	local b = wgts[key].all[button]
	wgts[key].active[button] = nil
	if b.hovered then b:unhover() end
end

function M.btn_set_pressfunc(key, button, func)
	key = key[M.keyName]
	wgts[key].all[button].pressfunc = func
end

function M.btn_set_releasefunc(key, button, func)
	key = key[M.keyName]
	wgts[key].all[button].releasefunc = func
end

function M.btn_set_text(key, button, text)
	key = key[M.keyName]
	local b = wgts[key].all[button]
	b.text = text
	gui.set_text(b.textnode, text)
end

function M.btn_set_neighbors(key, button, up, down, left, right)
	key = key[M.keyName]
	local b = wgts[key].all[button]
	if up then b.neighbor_up = wgts[key].all[up] end
	if down then b.neighbor_down = wgts[key].all[down] end
	if left then b.neighbor_left = wgts[key].all[left] end
	if right then b.neighbor_right = wgts[key].all[right] end
end

-- Button List, Auto-set Neighbors - Set the buttons' neighbors so they are a wrapping list.
function M.btnlist_autoset_neighbors(key, list, vertical)
	key = key[M.keyName]
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

function M.map_neighbors(key, map)
	key = key[M.keyName]
	-- validate map values and convert from string names to widget objects
	for iy, list in ipairs(map) do
		for ix, wgt in ipairs(list) do
			if wgt and type(wgt) == "string" then
				list[ix] = wgts[key].all[wgt]
			else
				list[ix] = false
			end
		end
	end
	-- set neighbors
	for iy, list in ipairs(map) do
		for ix, wgt in ipairs(list) do
			if #map > 1 then -- don't loop to self if there are no others in this dimension
				wgt.neighbor_up = prevval(map, iy)[ix]
				wgt.neighbor_down = nextval(map, iy)[ix]
			end
			if #list > 1 then -- don't loop to self if there are no others in this dimension
				wgt.neighbor_left = prevval(list, ix)
				wgt.neighbor_right = nextval(list, ix)
			end
		end
	end

	--[[
	local map_horizontal = {
		{ 1, 2, 3 }
	}
	local map_vertical = {
		{ 1 },
		{ 2 },
		{ 3 }
	}
	local map_square = {
		{ 1, 2, 3 },
		{ 1, 2, 3 },
		{ 1, 2, 3 }
	}
	]]
end

function M.widgets_setStencil(key, stencilNode, ...)
	key = key[M.keyName]
	for i, v in ipairs({...}) do
		wgts[key].all[v].stencilNode = stencilNode
	end
end

function M.new_baseWidget(key, name, active, pressfunc, releasefunc, theme_type)
	verify_key(key, "new_baseWidget")
	active = active or false
	local widget = {
		name = name,
		node = gui.get_node(name .. "/body"),
		key = key,
		pressed = false,
		hovered = false,
		focused = false,
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
		focus = focus_button,
		unfocus = unfocus_button,
		focus_neighbor = button_focus_neighbor,
		theme_type = theme_type
	}
	wgts[key].all[name] = widget
	if active then wgts[key].active[name] = widget end
	return widget
end

function M.new_button(key, name, active, pressfunc, releasefunc, theme_type)
	if type(key) == "table" then key = key[M.keyName] end
	local button = M.new_baseWidget(key, name, active, pressfunc, releasefunc, theme_type)
	button.textnode = gui.get_node(name .. "/text")
	button.text = gui.get_text(button.textnode)
	theme.init_btn(button)
	return button
end

function M.new_toggleButton(key, name, active, pressfunc, releasefunc, checked, theme_type)
	if type(key) == "table" then key = key[M.keyName] end
	local button = M.new_baseWidget(key, name, active, pressfunc, releasefunc, theme_type)
	button.checked = checked
	button.textnode = gui.get_node(name .. "/text")
	button.text = gui.get_text(button.textnode)
	button.release = release_toggleButton
	theme.init_toggleButton(button)
	return button
end

function M.new_radioButtonGroup(key, namesList, active, pressfunc, releasefunc, checkedName, theme_type)
	if type(key) == "table" then key = key[M.keyName] end
	local buttons = {}
	for i, name in ipairs(namesList) do
		local button = M.new_baseWidget(key, name, active, pressfunc, releasefunc, theme_type)
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

function M.new_slider(key, name, active, pressfunc, releasefunc, dragfunc, length, handleLength, startFraction, autoResizeHandle, theme_type)
	if type(key) == "table" then key = key[M.keyName] end
	local button = M.new_baseWidget(key, name, active, pressfunc, releasefunc, theme_type)
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
	theme.init_btn(button)
	button.pos = gui.get_position(button.node) -- will use the current Y and Z and only change X
	button:setHandleLength(button.handleLength)
	return button
end

function M.new_scrollBox(key, name, childname, active, horiz, scrollbarname, theme_type)
	if type(key) == "table" then key = key[M.keyName] end
	local box = M.new_baseWidget(key, name, active, nil, nil, theme_type)
	box.horiz = horiz
	box.child = gui.get_node(childname)
	box.viewLength = horiz and gui.get_size(box.node).x or gui.get_size(box.node).y -- size of mask
	box.childHeight = gui.get_size(box.child).y
	box.scrollLength = (horiz and gui.get_size(box.child).x or gui.get_size(box.child).y) - box.viewLength -- max movement of child
	box.range = math.max(0, box.scrollLength)
	box.scroll = scrollBox_scroll
	box.hover = scrollBox_hover
	box.unhover = scrollBox_unhover
	box.press = scrollBox_press
	box.release = scrollBox_release
	box.focus = function() end

	local handleLength = box.viewLength/(box.scrollLength) * box.viewLength -- assuming the scrollbar is the same length as the mask
	local scrollbar = M.new_slider(key, scrollbarname, active, nil, nil, function(fraction) box:scroll(fraction) end, box.viewLength, handleLength, 1, true)
	scrollbar.scrollBox = box
	box.scrollbar = scrollbar
	box.touchScroll = M.mode == M.MODE_MOBILE -- click-drag to scroll (in opposite direction) or not.
	box.drag = function(self, dx, dy) local a = 1 if self.touchScroll then a = -self.viewLength/(self.scrollLength + self.viewLength) end box.scrollbar:drag(dx*a, dy*a) end
	return box
end

function M.new_inputField(key, name, active, editfunc, confirmfunc, placeholderText, theme_type)
	if type(key) == "table" then key = key[M.keyName] end
	local self = M.new_baseWidget(key, name, active, nil, nil, theme_type)
	self.textNode = gui.get_node(self.name .. "/text")
	self.cursorNode = gui.get_node(self.name .. "/cursor")
	self.font = gui.get_font(self.textNode)
	self.endTag = "."
	self.endTagLength = gui.get_text_metrics(self.font, self.endTag).width
	self.placeholderText = placeholderText or ""
	self.cursorPos = gui.get_position(self.cursorNode)
	self.textOriginPos = gui.get_position(self.textNode)
	self.textPos = vmath.vector3(self.textOriginPos)
	self.halfInsideWidth = gui.get_size(gui.get_node(self.name .. "/inside")).x / 2 - gui.get_size(self.cursorNode).x / 2
	self.focus = focus_inputField
	self.unfocus = unfocus_inputField
	self.setText = inputField_setText
	self.backspace = inputField_backspace
	self.textInput = inputField_textInput
	self:setText(placeholderText)
	self.editfunc = editfunc
	self.release = release_inputField
	self.press = press_inputField
	self.confirmfunc = confirmfunc
	theme.init_inputField(self)
end

-- Group, Enable - Activates all buttons in the group and makes sure the root node is enabled (visible).
--		Activate_btn() will enable the buttons if they are disabled
--		Use theme.group_enable() for custom animations, etc.
function M.group_enable(key, name)
	key = key[M.keyName]
	local g = wgts[key].groups[name]
	gui.set_enabled(g.node, true)
	theme.group_enable(g)
	for i, v in ipairs(g.children) do
		M.activate_btn(key, v)
	end
	if M.mode == M.MODE_KEYBOARD then wgts[key].all[g.children[1]]:hover() end
end

-- It's up to the theme hide the node or not.
function M.group_disable(key, name)
	key = key[M.keyName]
	local g = wgts[key].groups[name]
	theme.group_disable(g)
	for i, v in ipairs(g.children) do
		M.deactivate_btn(key, v)
	end
end

-- Convenience function to disable one group and enable another
function M.group_swap(key, from, to)
	key = key[M.keyName]
	M.group_disable(key, from)
	M.group_enable(key, to)
end

function M.new_group(key, name, rootnode, children, autoset_wgts_vert, autoset_wgts_horiz, disable)
	key = key[M.keyName]
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
