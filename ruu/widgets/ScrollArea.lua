
local basePath = (...):gsub('[^%.]+$', '')
local Button = require(basePath .. "Button")
local ScrollArea = Button:extend()

local function getChildBounds(self, child)
	child:updateTransform()

	local x1, y1 = self:toLocal(child:toWorld(-child.w/2, -child.h/2))
	local x2, y2 = self:toLocal(child:toWorld(child.w/2, child.h/2))
	local x3, y3 = self:toLocal(child:toWorld(-child.w/2, child.h/2))
	local x4, y4 = self:toLocal(child:toWorld(child.w/2, -child.h/2))

	local lt, rt = math.min(x1, x2, x3, x4), math.max(x1, x2, x3, x4)
	local top, bot = math.min(y1, y2, y3, y4), math.max(y1, y2, y3, y4)

	return lt, rt, top, bot
end

function ScrollArea.updateChildrenBounds(self)
	local lt, rt, top, bot, w, h = 0, 0, 0, 0, 0, 0
	if self.children then
		lt, rt, top, bot = math.huge, -math.huge, math.huge, -math.huge
		for i=1,self.children.maxn or #self.children do
			local child = self.children[i]
			if child then
				local lt2, rt2, top2, bot2 = getChildBounds(self, child)
				lt, rt = math.min(lt, lt2), math.max(rt, rt2)
				top, bot = math.min(top, top2), math.max(bot, bot2)
			end
		end
		w, h = rt - lt, bot - top
	end
	local b = self.childBounds
	b.lt, b.rt, b.top, b.bot, b.w, b.h = lt, rt, top, bot, w, h
end

local function debugDraw(self)
	local b = self.childBounds
	if b.lt and b.rt then
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.line(
			b.lt, b.top, b.rt, b.top,
			b.rt, b.bot, b.lt, b.bot,
			b.lt, b.top
		)
	end
end

function ScrollArea.scroll(self, dx, dy)
	-- self:updateChildrenBounds() -- Should really only happen when children change.
	local b = self.childBounds
	local lt, rt, top, bot, w, h = b.lt, b.rt, b.top, b.bot, b.w, b.h

	dx = (dx or 0) * self.scrollDist
	dy = (dy or 0) * self.scrollDist

	lt, rt = lt + dx, rt + dx
	top, bot = top + dy, bot + dy

	local w2, h2 = self._contentAlloc.w/2, self._contentAlloc.h/2
	-- For each axis:
	if b.w <= self._contentAlloc.w then -- Bounds are smaller than mask area - don't allow children out.
		-- Don't allow scrolling - remove original delta.
		dx = -w2 - b.lt -- Align to left.
	else -- If bounds are larger than mask area - don't allow scrolling past.
		local insideLt = math.max(lt + w2, 0)
		local insideRt = math.min(rt - w2, 0)
		dx = dx - insideLt - insideRt
	end
	if b.h <= self._contentAlloc.h then
		dy = -h2 - b.top -- Align to top.
	else
		local insideTop = math.max(top + h2, 0)
		local insideBot = math.min(bot - h2, 0)
		dy = dy - insideTop - insideBot
	end

	self.scrollX, self.scrollY = self.scrollX + dx, self.scrollY + dy
	self:setOffset(self.scrollX, self.scrollY)

	b.lt, b.rt = b.lt + dx, b.rt + dx
	b.top, b.bot = b.top + dy, b.bot + dy
end

return ScrollArea
