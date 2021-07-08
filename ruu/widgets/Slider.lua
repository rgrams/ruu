
local Button = require "ruu.widgets.Button"

local Slider = Button:extend()

Slider.nudgeDist = 5

-- Hack to try to get global rotation, check two parents up.
local function getScreenRotation(node)
	local p1, p2
	local rotZ = gui.get_rotation(node).z -- gui.get_rotation returns a vector3 of euler angles.
	p1 = gui.get_parent(node)
	if p1 then
		p2 = gui.get_parent(p1)
		rotZ = rotZ + gui.get_rotation(p1).z
	end
	if p2 then
		rotZ = rotZ + gui.get_rotation(p2).z
	end
	return math.rad(rotZ)
end

local function toLocal(node, dx, dy)
	local screenRot = getScreenRotation(node)
	local screenRotQ = vmath.quat_rotation_z(-screenRot)
	local delta = vmath.rotate(screenRotQ, vmath.vector3(dx, dy, 0))
	return delta.x, delta.y
end

function Slider.set(self, ruu, owner, nodeName, releaseFn, fraction, length, wgtTheme)
	self.fraction = fraction or 0
	self.length = length or 100
	self.xPos = 0
	Slider.super.set(self, ruu, owner, nodeName, releaseFn, wgtTheme)
	self.barNode = gui.get_node(nodeName .. "/bar")
	self:updatePos(self, nil, nil) -- To update slider pos based on current fraction.
end

function Slider.onDrag(self, dragFn)
	self.dragFn = dragFn
	return self -- Allow chaining.
end

function Slider.updatePos(self, dx, dy, isLocal)
	local startPoint = -self.length/2 -- Assumes that the handle at x=0 is centered on the bar.
	local endPoint = self.length/2
	local pos = gui.get_position(self.node)

	if dx and dy then
		if not isLocal then -- Convert dx and dy to local deltas relative to the bar, so dx is always along the bar.
			dx, dy = toLocal(self.barNode, dx, dy)
		end
		-- Clamp to start and end points.
		pos.x = math.max(startPoint, math.min(endPoint, pos.x + dx))

	else -- .updatePos called with no dx or dy - Set pos based on current fraction.
		pos.x = startPoint + self.length * self.fraction
	end
	self.xPos = pos.x
	gui.set_position(self.node, pos)
end

function Slider.drag(self, dx, dy, dragType, isLocal)
	if dragType then  return  end -- Only respond to the default drag type.

	self:updatePos(dx, dy, isLocal)

	self.fraction = self.xPos / self.length + 0.5
	if self.dragFn then
		if self.releaseArgs then
			self.dragFn(self.owner, self, unpack(self.releaseArgs))
		else
			self.dragFn(self.owner, self)
		end
	end
	self.wgtTheme.drag(self, dx, dy)
end

local dirs = { up = {0, 1}, down = {0, -1}, left = {-1, 0}, right = {1, 0} }
local COS_45 = math.cos(math.rad(45))

function Slider.getFocusNeighbor(self, dir)
	local dirVec = dirs[dir]
	if dirVec then
		local dx, dy = dirVec[1], dirVec[2]
		dx, dy = toLocal(self.barNode, dx, dy)
		if math.abs(dx) > COS_45 then -- Input direction is roughly aligned with slider rotation.
			self:drag(dx * self.nudgeDist, 0, nil, true)
			return 1 -- Consume input.
		else
			return self.neighbor[dir]
		end
	else
		return self.neighbor[dir]
	end
end

return Slider
