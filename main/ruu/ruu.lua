
-- RUU - Version 0.1

local M = {}

local theme = require "main.ruu.ruu theme"
local winman = require "main.framework.window_manager"

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

M.INPUT_SCROLL_DIST = 25
M.INPUT_SLIDER_NUDGE_DIST = 5

-- ##########  CONTROL MODE  ##########
-- KEYBOARD: For keyboard only, or keyboard and mouse - Buttons stay hovered until another is hovered. Always hovers a default initial button.
M.MODE_KEYBOARD = 1

-- MOUSE: For mouse only, keys still work once the mouse hovers a button (if you give Ruu key input) - buttons hover when mouse enters and unhover when it exits.
M.MODE_MOUSE = 2

-- MOBILE: For touch - no hover state used, cursor position only checked while a tap is held.
-- Rather, everything is unhovered on touch release.
M.MODE_MOBILE = 3

M.mode = M.MODE_KEYBOARD
theme.mode = M.mode


local sysInfo = sys.get_sys_info()
if sysInfo.system_name == "Android" or sysInfo.system_name == "iPhone OS" then print("mobile build") M.mode = M.MODE_MOBILE end


M.layerPrecision = 1000 -- layer index multiplied by this in get_drawIndex() calculation
-- M.layerPrecision = number of different nodes allowed in each layer


-- ---------------------------------------------------------------------------------
--| 					PRIVATE FUNCTIONS 1: SETUP & KEYS							|
-- ---------------------------------------------------------------------------------

-- the main table that stores all widgets and other data.
local wgts = {} -- FORMAT: wgts[key] = new_context_table()

local function new_context_table()
	return {all = {}, active = {}, groups = {}, layers = { [hash("")] = 0 }, cur_focus = nil, dragging = {}, dragCount = 0, hovered = {}}
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
	i = (i + 1) <= #t and (i + 1) or 1
	return t[i]
end

local function prevval(t, i) -- looping, used for setting up button list neighbors
	if #t == 0 then return false end
	i = (i - 1) >= 1 and (i - 1) or #t
	return t[i]
end

local function nexti(t, i) -- Next index in array (looping)
	if #t == 0 then return 0 end
	return (i + 1) <= #t and (i + 1) or 1
end

local function previ(t, i) -- Previous index in array (looping)
	if #t == 0 then return 0 end
	return (i - 1) >= 1 and (i - 1) or #t
end

local function sign(x)
	return x >= 0 and 1 or -1
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

local function safe_get_node(id)
	if pcall(gui.get_node, id) then
		return gui.get_node(id)
	else
		return nil
	end
end

local function get_drawIndex(widget) -- combines layer and index to get an absolute draw index
	local layer = gui.get_layer(widget.node)
	local index = gui.get_index(widget.node)
	local li = wgts[widget.key].layers[layer]
	if not li then print("WARNING: ruu.get_drawIndex() - layer not found in list. May not accurately get top widget unless you call ruu.register_layers") end
	return (li and (li * M.layerPrecision) or 0) + index
end

local function get_topWidget(key, wgtList) -- find widget with highest drawIndex
	local maxI = -1
	local maxWgt = nil
	for i, v in ipairs(wgtList) do
		local drawI = get_drawIndex(v)
		if drawI > maxI then
			maxI = drawI
			maxWgt = v
		end
	end
	return maxWgt
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
		if self.scrollArea then self.scrollArea:scroll_to_child(self) end
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
	if self.pressed and (self.hovered or self.focused) then
		theme.release_btn(self)
		self.pressed = false
		if self.releasefunc and not dontfire then self.releasefunc() end
		wgts[self.key].dragging[self] = nil
		wgts[self.key].dragCount = wgts[self.key].dragCount - 1
	end
end

local neighbor_dirs = {
	neighbor_up = vmath.vector3(0, 1, 0),
	neighbor_down = vmath.vector3(0, -1, 0),
	neighbor_left = vmath.vector3(-1, 0, 0),
	neighbor_right = vmath.vector3(1, 0, 0)
}

local dot45 = math.sqrt(2)/2

local function slider_focus_neighbor(self, action_id)
	local dirKey = M.INPUT_DIRKEY[action_id]
	local dirDot = vmath.dot(neighbor_dirs[dirKey], self.angleVec)
	if math.abs(dirDot) >= dot45 then
		local dotSign = sign(dirDot)
		self:drag(self.angleVec.x * self.nudgeDist * dotSign, self.angleVec.y * self.nudgeDist * dotSign)
	else
		local neighbor = self[dirKey]
		if neighbor then
			self:unfocus()
			neighbor:focus()
			wgts[self.key].cur_focus = neighbor
		end
	end
end

local function drag_slider(self, dx, dy)
	local axis = self.axis or "x"
	self.dragVec.x = dx;  self.dragVec.y = dy
	local dragDist = vmath.dot(self.dragVec, self.angleVec)
	self.pos[axis] = clamp(self.pos[axis] + dragDist, self.endx, self.startx)
	self.fraction = self.slideLength == 0 and 0 or (self.pos[axis] - self.startx)/self.slideLength -- have to avoid dividing by zero
	gui.set_position(self.slideNode, self.pos)

	if self.dragfunc then self.dragfunc(self.fraction) end
end

local function slider_setHandleLength(self, newLength)
	local axis = self.axis or "x"
	self.handleLength = clamp(newLength, self.baseLength, 0)
	self.slideLength = self.baseLength - self.handleLength
	self.startx = self.handleLength/2
	self.endx = self.startx + self.slideLength

	self.pos[axis] = vmath.lerp(self.fraction, self.startx, self.endx)
	gui.set_position(self.slideNode, self.pos)

	if self.autoResize then -- for scroll bar style sliders
		local size = gui.get_size(self.slideNode)
		size[axis] = self.handleLength
		gui.set_size(self.slideNode, size)
	end
	theme.slider_setHandleLength(self)
end

-- Scroll Area
local function drag_scrollArea(self, dx, dy)
	self.dragVec.x = dx;  self.dragVec.y = dy
	local dragDist = vmath.dot(self.dragVec, self.angleVec)
	self.pos.y = clamp(self.pos.y + dragDist, self.endx, self.startx)
	self.fraction = self.slideLength == 0 and 0 or (self.pos.y - self.startx)/self.slideLength -- have to avoid dividing by zero
	gui.set_position(self.slideNode, self.pos)

	if self.dragfunc then self.dragfunc(self.fraction) end
end

local function scrollArea_scroll_to_child(self, child)
	local center = get_center_position(child.node) -- will be relative to scrollArea inside . . . always the same

	local rot = math.rad(gui.get_rotation(child.node).z) -- relative to parent (scrollArea inside)
	local qRot = vmath.quat_rotation_z(rot)
	local scale = gui.get_scale(child.node)
	local size = gui.get_size(child.node) * 0.5
	size.x = size.x * scale.x;  size.y = size.y * scale.y
	local invSize = vmath.vector3(size);  invSize.x = -invSize.x
	size = vmath.rotate(qRot, size)
	invSize = vmath.rotate(qRot, invSize)
	local top = math.max(size.y, invSize.y, -size.y, -invSize.y)
	local bottom = math.min(size.y, invSize.y, -size.y, -invSize.y)

	-- outTop: positive if out top
	local outTop = (center.y + top + self.pos.y) - self.handleLength/2
	-- outBottom: negative if out bottom
	local outBottom = (center.y + bottom + self.pos.y) + self.handleLength/2

	-- multiply by angleVec because drag coordinates are global
	if outTop > 0 then self:drag(self.angleVec.x * -outTop, self.angleVec.y * -outTop)
	elseif outBottom < 0 then self:drag(self.angleVec.x * -outBottom, self.angleVec.y * -outBottom)
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
		M.update_mouse(key, action.x, action.y, action.screen_dx, action.screen_dy)
		-- if you wish to tell if the mouse is over a button in your gui script you can call M.update_mouse directly and get the return value.
	elseif action_id == M.INPUT_CLICK then -- Mouse click
		if M.mode == M.MODE_MOBILE then M.update_mouse(key, action.x, action.y, action.dx, action.dy) end
		if action.pressed then
			for i, v in ipairs(wgts[key].hovered) do v:press() end -- press all hovered nodes

			-- give keyboard focus to top hovered widget
			local topWgt = get_topWidget(key, wgts[key].hovered)
			if topWgt and topWgt ~= wgts[key].cur_focus then
				if wgts[key].cur_focus then wgts[key].cur_focus:unfocus() end
				wgts[key].cur_focus = topWgt
				topWgt:focus()
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
			for i, v in ipairs(wgts[key].hovered) do if v.scroll then v:scroll(M.INPUT_SCROLL_DIST, M.INPUT_SCROLL_DIST) end end
			M.update_mouse(key, action.x, action.y, action.dx, action.dy)
		end
	elseif action_id == M.INPUT_SCROLLDOWN then
		if action.pressed then
			for i, v in ipairs(wgts[key].hovered) do if v.scroll then v:scroll(-M.INPUT_SCROLL_DIST, -M.INPUT_SCROLL_DIST) end end
			M.update_mouse(key, action.x, action.y, action.dx, action.dy)
		end
	elseif M.INPUT_DIRKEY[action_id] and (action.pressed or action.repeated) then -- Keyboard/Gamepad navigation
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

function M.register_layers(key, layers)
	key = key[M.keyName]
	local layersList = wgts[key].layers
	local layerCount = 1
	for i, v in ipairs(layers) do
		if type(v) == "string" then v = hash(v)
		elseif type(v) ~= "userdata" then v = nil print("ERROR: ruu.register_layers() - invalid layer, must be a string or a hash")
		end
		if v and v ~= hash("") then
			layerCount = layerCount + 1
			layersList[v] = layerCount - 1
		end
	end
end

function M.activate_widgets(key, ...)
	key = key[M.keyName]
	for i, name in ipairs({...}) do
		local w = wgts[key].all[name]
		wgts[key].active[name] = w
		if w.activate then w:activate() end
	end
end

function M.deactivate_widgets(key, ...)
	key = key[M.keyName]
	for i, name in ipairs({...}) do
		wgts[key].active[name] = nil
		local w = wgts[key].all[name]
		if w.deactivate then w:deactivate() end
	end
end

function M.widget_setPressfunc(key, widget, func)
	key = key[M.keyName]
	wgts[key].all[widget].pressfunc = func
end

function M.widget_setReleasefunc(key, widget, func)
	key = key[M.keyName]
	wgts[key].all[widget].releasefunc = func
end

function M.widget_setText(key, widget, text)
	key = key[M.keyName]
	local w = wgts[key].all[widget]
	if w.textNode then
		w.text = text
		gui.set_text(w.textNode, text)
	end
end

function M.widget_setNeighbors(key, widget, up, down, left, right)
	key = key[M.keyName]
	local w = wgts[key].all[widget]
	if up then w.neighbor_up = wgts[key].all[up] end
	if down then w.neighbor_down = wgts[key].all[down] end
	if left then w.neighbor_left = wgts[key].all[left] end
	if right then w.neighbor_right = wgts[key].all[right] end
end

local function map_get_next(wgt, map, iy, ix, dirx, diry) -- local function for M.map_neighbors
	-- 'map' is the whole map or just the x-list, depending on usage
	local found = nil
	while not found do
		if diry == 1 then
			found = prevval(map, iy)[ix]
			iy = previ(map, iy)
		elseif diry == -1 then
			found = nextval(map, iy)[ix]
			iy = nexti(map, iy)
		elseif dirx == -1 then
			found = prevval(map, ix)
			ix = previ(map, ix)
		elseif dirx == 1 then
			found = nextval(map, ix)
			ix = nexti(map, ix)
		else found = wgt
		end
	end
	return found ~= wgt and found or nil
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
				if wgt then
					wgt.neighbor_up = map_get_next(wgt, map, iy, ix, 0, 1)
					wgt.neighbor_down = map_get_next(wgt, map, iy, ix, 0, -1)
				end
			end
			if #list > 1 then -- don't loop to self if there are no others in this dimension
				if wgt then
					wgt.neighbor_left = map_get_next(wgt, list, iy, ix, -1, 0)
					wgt.neighbor_right = map_get_next(wgt, list, iy, ix, 1, 0)
				end
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

function M.add_to_scrollArea(key, scrollArea, ...)
	key = key[M.keyName]
	scrollArea = wgts[key].all[scrollArea]
	for i, v in ipairs({...}) do
		v = wgts[key].all[v]
		v.scrollArea = scrollArea
	end
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
	button.textNode = gui.get_node(name .. "/text")
	button.text = gui.get_text(button.textNode)
	theme.init_btn(button)
	return button
end

function M.new_toggleButton(key, name, active, pressfunc, releasefunc, checked, theme_type)
	if type(key) == "table" then key = key[M.keyName] end
	local button = M.new_baseWidget(key, name, active, pressfunc, releasefunc, theme_type)
	button.checked = checked
	button.textNode = gui.get_node(name .. "/text")
	button.text = gui.get_text(button.textNode)
	button.release = release_toggleButton
	theme.init_toggleButton(button)
	return button
end

function M.new_radioButtonGroup(key, namesList, active, pressfunc, releasefunc, checkedName, theme_type)
	if type(key) == "table" then key = key[M.keyName] end
	local buttons = {}
	for i, name in ipairs(namesList) do
		local button = M.new_baseWidget(key, name, active, pressfunc, releasefunc, theme_type)
		button.textNode = gui.get_node(name .. "/text")
		button.text = gui.get_text(button.textNode)
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

function M.new_slider(key, name, active, pressfunc, releasefunc, dragfunc, length, handleLength, startFraction, autoResizeHandle, nudgeDist, theme_type)
	if type(key) == "table" then key = key[M.keyName] end
	local button = M.new_baseWidget(key, name, active, pressfunc, releasefunc, theme_type)
	button.rootNode = gui.get_node(name .. "/root") -- only used to get slider rotation
	button.endpointNode = safe_get_node(name .. "/endpoint") -- optional, only used to get default baseLength
	button.slideNode = button.node
	local rot = math.rad(gui.get_rotation(button.rootNode).z)
	button.angleVec = vmath.vector3(math.cos(rot), math.sin(rot), 0)
	button.baseLength = length or (button.endpointNode and gui.get_position(button.endpointNode).x or 200) -- base length of slider range
	button.handleLength = handleLength or gui.get_size(button.node).x -- "physical" length of slider handle - default to x of node, input 0 if desired.
	-- meant for scroll bar style sliders where the handle fits inside the bar.

	--			The following are set in button:setHandleLength()
	--button.slideLength = baseLength - handleLength  --actual distance slider can move
	--button.startx = origin X (0.0) + handle length/2
	--button.endx = startx + slideLength

	button.nudgeDist = nudgeDist or M.INPUT_SLIDER_NUDGE_DIST -- distance the slider moves on directional key presses
	button.fraction = startFraction or 0 -- 0.0-1.0 position of slider in its range. 0.0 --> left/top
	button.dragVec = vmath.vector3() -- used for (dx, dy) in drag function to avoid creating a new vector every frame of dragging
	button.autoResize = autoResizeHandle -- should resize the actual handle node to match `handleLength`. Defaults to nil/false
	button.press = press_slider
	button.release = release_slider
	button.focus_neighbor = slider_focus_neighbor
	button.dragfunc = dragfunc -- called continuously whenever the slider is moved.
	button.drag = drag_slider
	button.setHandleLength = slider_setHandleLength

	-- set starting pos, etc.
	theme.init_btn(button)
	button.pos = gui.get_position(button.node) -- will use the current Y and Z and only change X
	button:setHandleLength(button.handleLength)
	return button
end

function M.new_scrollArea(key, name, active, pressfunc, releasefunc, dragfunc, startFraction, nudgeDist, theme_type)
	if type(key) == "table" then key = key[M.keyName] end
	local button = M.new_baseWidget(key, name, active, pressfunc, releasefunc, theme_type)
	button.insideNode = gui.get_node(name .. "/inside")
	button.slideNode = button.insideNode
	button.axis = "y" -- movement axis at rotation 0
	button.rot = math.rad(gui.get_rotation(button.node).z + (button.axis == "y" and 90 or 0))
	button.angleVec = vmath.vector3(math.cos(button.rot), math.sin(button.rot), 0)
	button.baseLength = gui.get_size(button.insideNode)[button.axis] -- length of slider range
	button.handleLength = gui.get_size(button.node)[button.axis]

	--			The following are set in button:setHandleLength()
	--button.slideLength = baseLength - handleLength : actual distance slider can move
	--button.startx = origin X (0.0) + handle length/2
	--button.endx = startx + slideLength

	button.nudgeDist = -(nudgeDist or M.INPUT_SCROLL_DIST) -- dist the slider moves on directional key presses (negative to scroll instead of drag)
	button.fraction = startFraction or 0 -- 0.0-1.0 position of slider in its range. 0.0 --> left/top
	button.dragVec = vmath.vector3() -- used for (dx, dy) in drag function to avoid creating a new vector every frame of dragging
	button.autoResize = false -- should resize the actual handle node to match `handleLength`. Defaults to nil/false
	button.press = press_slider
	button.release = release_slider
	button.focus_neighbor = slider_focus_neighbor
	button.dragfunc = dragfunc -- called continuously whenever the slider is moved.
	button.drag = drag_scrollArea
	button.scroll = function(self, dx, dy) drag_slider(self, -dx, -dy) end
	button.setHandleLength = slider_setHandleLength
	button.scroll_to_child = scrollArea_scroll_to_child

	-- set starting pos, etc.
	theme.init_btn(button)
	button.pos = gui.get_position(button.insideNode) -- will use the current Y and Z and only change X
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
	box.scroll_to_fraction = scrollBox_scroll
	box.hover = scrollBox_hover
	box.unhover = scrollBox_unhover
	box.press = scrollBox_press
	box.release = scrollBox_release
	box.focus = function() end

	local handleLength = box.viewLength/(box.scrollLength) * box.viewLength -- assuming the scrollbar is the same length as the mask
	local scrollbar = M.new_slider(key, scrollbarname, active, nil, nil, function(fraction) box:scroll_to_fraction(fraction) end, box.viewLength, handleLength, 1, true)
	scrollbar.scrollBox = box
	box.scrollbar = scrollbar
	box.drag = function(self, dx, dy) local a = -self.viewLength/(self.scrollLength + self.viewLength) box.scrollbar:drag(dx*a, dy*a) end
	box.scroll = function(self, dx, dy) local a = self.viewLength/(self.scrollLength + self.viewLength) self.scrollbar:drag(dx*a, dy*a) end
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
	local childMap = {}
	if autoset_wgts_vert then
		for i, v in ipairs(children) do table.insert(childMap, { v }) end
		M.map_neighbors(key, childMap)
	elseif autoset_wgts_horiz then
		local xlist = {}
		table.insert(childMap, xlist)
		for i, v in ipairs(children) do table.insert(xlist, v) end
		M.map_neighbors(key, childMap)
	end
end


return M
