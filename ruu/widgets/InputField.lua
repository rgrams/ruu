
local Button = require "ruu.widgets.Button"
local InputField = Button:extend()

local util = require "ruu.ruutilities"

local endChar = "|"

local function getTextWidth(font, text, endCharWidth)
	return gui.get_text_metrics(font, text .. endChar).width - endCharWidth
end

function InputField.set(self, ruu, owner, nodeName, confirmFn, text, wgtTheme)
	self.text = tostring(text) or ""
	self.oldText = self.text -- In case of cancel.
	self.textNode = gui.get_node(nodeName .. "/text")
	self.textMaskNode = gui.get_node(nodeName .. "/mask")
	self.font = gui.get_font(self.textNode)
	self.endCharWidth = gui.get_text_metrics(self.font, endChar).width
	self.textOrigin = gui.get_position(self.textNode)
	self.textPos = vmath.vector3(self.textOrigin)
	self.textScrollOX = 0
	self.confirmFn = confirmFn
	self.cursorX = self.textOrigin.x
	self.cursorIdx = #self.text
	self.hasSelection = false
	self.selectionTailX = nil
	self.selectionTailIdx = nil

	gui.set_text(self.textNode, self.text)

	local releaseFn = nil
	InputField.super.set(self, ruu, owner, nodeName, releaseFn, wgtTheme)

	self:updateTotalTextWidth()
	self:updateMaskSize()
	self:updateCursorPos()
end

function InputField.onEdit(self, editFn)
	self.editFn = editFn
	return self -- Allow chaining.
end

local function _sendCb(self, fn)
	if fn then
		if self.releaseArgs then
			return fn(self.owner, self, unpack(self.releaseArgs))
		else
			return fn(self.owner, self)
		end
	end
end

--------------------  Standard Widget Methods  --------------------
function InputField.release(self, dontFire, mx, my, isKeyboard)
	self.isPressed = false
	if self.releaseFn and not dontFire then
		_sendCb(self, self.releaseFn)
	end
	if isKeyboard and self.confirmFn and not dontFire then
		local rejectedText = self.text
		local isRejected = _sendCb(self, self.confirmFn)
		if isRejected then
			self:cancel()
			self.wgtTheme.textRejected(self, rejectedText)
		else
			self.oldText = self.text
		end
	end
	if not dontFire then  self:selectAll()  end
	self.wgtTheme.release(self, dontFire, mx, my, isKeyboard)
end

function InputField.focus(self, isKeyboard)
	if not self.isFocused then
		self.isFocused = true
		self.oldText = self.text -- Save in case of cancel.
		self:selectAll()
	end
	self.wgtTheme.focus(self)
end

function InputField.unfocus(self, isKeyboard)
	self.isFocused = false
	if self.isPressed then  self:release(true)  end -- Release without firing.
	if self.confirmFn then
		local rejectedText = self.text
		local isRejected = _sendCb(self, self.confirmFn)
		if isRejected then
			self:cancel()
			self.wgtTheme.textRejected(self, rejectedText)
		else
			self.oldText = self.text
		end
	end
	self.wgtTheme.unfocus(self, isKeyboard)
end

function InputField.cancel(self)
	self.text = self.oldText
	gui.set_text(self.textNode, self.text)
	self:selectAll()
	self.wgtTheme.updateText(self)
end

--------------------  Text Scrolling  --------------------

-- Save left and right edge positions of the text-mask, relative to the parent.
function InputField.updateMaskSize(self)
	local pivot = util.PIVOT_VEC[gui.get_pivot(self.textMaskNode)]
	local width = gui.get_size(self.textMaskNode).x
	local originX = gui.get_position(self.textMaskNode).x
	local centerX = originX - pivot.x * width

	self.maskLeftEdgeX, self.maskRightEdgeX = centerX - width/2, centerX + width/2
end

function InputField.updateTotalTextWidth(self)
	self.totalTextWidth = getTextWidth(self.font, self.text, self.endCharWidth)
end

function InputField.setScrollOffset(self, scrollOX)
	local oldScrollOX = self.textScrollOX
	local normalViewWidth = self.maskRightEdgeX - self.textOrigin.x
	if self.totalTextWidth <= normalViewWidth then
		scrollOX = 0
	else -- Don't let the right edge of the text be inside the right edge of the mask.
		local maxNegScroll = self.totalTextWidth - normalViewWidth
		scrollOX = math.max(-maxNegScroll, scrollOX)
	end

	if scrollOX ~= oldScrollOX then
		self.textScrollOX = scrollOX
		self.textPos.x = self.textOrigin.x + self.textScrollOX
		gui.set_position(self.textNode, self.textPos)

		self:updateSelectionXPos()
	end
end

-- Gets the un-scrolled X pos of the -right edge- of the character at `charIdx`.
function InputField.getCharXOffset(self, charIdx)
	local preText = self.text:sub(0, charIdx)
	local x = self.textOrigin.x + getTextWidth(self.font, preText, self.endCharWidth)
	return x
end

function InputField.scrollCharOffsetIntoView(self, x)
	local scrolledX = x + self.textScrollOX
	if scrolledX > self.maskRightEdgeX then -- Scroll text to the left.
		local distOutside = scrolledX - self.maskRightEdgeX
		self:setScrollOffset(self.textScrollOX - distOutside)
	elseif scrolledX < self.maskLeftEdgeX then -- Scroll text to the right.
		local distOutside = self.maskLeftEdgeX - scrolledX
		self:setScrollOffset(self.textScrollOX + distOutside)
	else
		self:setScrollOffset(self.textScrollOX)
	end
end

function InputField.updateCursorPos(self)
	local baseCursorX = self:getCharXOffset(self.cursorIdx)
	self:scrollCharOffsetIntoView(baseCursorX)
	self.cursorX = baseCursorX + self.textScrollOX
	self.wgtTheme.updateCursor(self, self.cursorX, self.selectionTailX)
end

--------------------  Internal Text Setting  --------------------
function InputField.updateText(self, text)
	self.text = text
	_sendCb(self, self.editFn) -- Can modify self.text.
	gui.set_text(self.textNode, self.text)
	self:updateTotalTextWidth()
	self:updateCursorPos()
	self.wgtTheme.updateText(self)
end

function InputField.insertText(self, text)
	text = text or ""
	local preCursorText, postCursorText

	if self.hasSelection then
		local selectionLeftIdx, selectionRightIdx = self:getSelectionLeftIdx(), self:getSelectionRightIdx()
		preCursorText = string.sub(self.text, 0, selectionLeftIdx)
		postCursorText = string.sub(self.text, selectionRightIdx + 1)
		self.cursorIdx = selectionLeftIdx
		self:clearSelection()
	else
		preCursorText = string.sub(self.text, 0, self.cursorIdx)
		postCursorText = string.sub(self.text, self.cursorIdx + 1)
	end

	self.cursorIdx = self.cursorIdx + #text
	self:updateText(preCursorText .. text .. postCursorText)
end

--------------------  Selection  --------------------
function InputField.clearSelection(self)
	self.hasSelection = false
	self.selectionTailIdx = nil
	self.selectionTailX = nil
end

-- Set the "tail" character index of the selection. The "head" position of the selection is the cursor index.
function InputField.startSelection(self, charIdx)
	self.hasSelection = true
	self.selectionTailIdx = charIdx
	self:updateSelectionXPos() -- Only nood to update X pos now, and when scroll actually changes.
end

function InputField.selectAll(self)
	self:startSelection(0)
	self.cursorIdx = #self.text
	self:updateCursorPos()
end

function InputField.getSelectionLeftIdx(self)
	return math.min(self.cursorIdx, self.selectionTailIdx)
end

function InputField.getSelectionRightIdx(self)
	return math.max(self.cursorIdx, self.selectionTailIdx)
end

function InputField.updateSelectionXPos(self)
	if self.hasSelection then
		self.selectionTailX = self:getCharXOffset(self.selectionTailIdx) + self.textScrollOX
	end
end

--------------------  Cursor Movement  --------------------
function InputField.setCursorIdx(self, index)
	if self.hasSelection and self.ruu.selectionModifierPresses == 0 then
		self:clearSelection()
	elseif not self.hasSelection and self.ruu.selectionModifierPresses > 0 then
		self:startSelection(self.cursorIdx)
	end
	self.cursorIdx = math.max(0, math.min(#self.text, index))
	self:updateCursorPos()
end

function InputField.moveCursor(self, dx)
	if dx == 0 then  return  end

	if self.hasSelection and self.ruu.selectionModifierPresses == 0 then
		if dx > 0 then
			local selectionRightIdx = math.max(self.cursorIdx, self.selectionTailIdx)
			self.cursorIdx = selectionRightIdx
		elseif dx < 0 then
			local selectionLeftIdx = math.min(self.cursorIdx, self.selectionTailIdx)
			self.cursorIdx = selectionLeftIdx
		end
		self:clearSelection()
		self:updateCursorPos()
		return -- Skip normal cursor movement.
	elseif not self.hasSelection and self.ruu.selectionModifierPresses > 0 then
		self:startSelection(self.cursorIdx)
	end

	if dx > 0 then
		self.cursorIdx = math.min(#self.text, self.cursorIdx + dx)
	elseif dx < 0 then
		self.cursorIdx = math.max(0, self.cursorIdx + dx)
	end
	self:updateCursorPos()
end

--------------------  External Input Methods  --------------------
function InputField.getFocusNeighbor(self, dir)
	if dir == "left" then
		self:moveCursor(-1)
	elseif dir == "right" then
		self:moveCursor(1)
	else
		return self.neighbor[dir]
	end
end

function InputField.setText(self, text)
	text = text ~= nil and tostring(text) or ""
	self.cursorIdx = #text
	self:updateText(text)
end

function InputField.textInput(self, text)
	self:insertText(text)
end

function InputField.backspace(self)
	if self.hasSelection then
		self:insertText("")
	else
		local preCursorText = string.sub(self.text, 0, self.cursorIdx - 1) -- Skip back 1 character.
		local postCursorText = string.sub(self.text, self.cursorIdx + 1)
		self.cursorIdx = math.max(0, self.cursorIdx - 1)
		self:updateText(preCursorText .. postCursorText)
	end
end

function InputField.delete(self)
	if self.hasSelection then
		self:insertText("")
	else
		local preCursorText = string.sub(self.text, 0, self.cursorIdx)
		local postCursorText = string.sub(self.text, self.cursorIdx + 2) -- Skip forward 1 character.
		-- Deleting in front of the cursor, so cursor index stays the same.
		self:updateText(preCursorText .. postCursorText)
	end
end

function InputField.home(self)
	self:setCursorIdx(0)
end

local function _end(self)
	self:setCursorIdx(#self.text)
end
InputField["end"] = _end

return InputField
