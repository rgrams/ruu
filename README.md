# Ruu

A GUI library for Defold. Very Unfinished! Desktop rather than mobile-oriented. The following documentation is written for myself.
### Setup:
#### Ruu(owner, getInput, [theme])
* __owner__ <kbd>script instance</kbd> - The 'self' of the calling script.
* __getInput__ <kbd>function</kbd> - Unused for now (but required for some reason). A function to get whether an action-name is pressed or not. To be used for InputFields to do selection and word skipping with modifiers pressed.

```lua
self.ruu = Ruu(self, function() end, require("interface.ruu-theme"))
self.ruu:registerLayers(GUI_LAYER_NAMES)
```

#### Ruu:registerLayers(layerList)
Takes a list of string or hash layer names.

#### Ruu:input(action_id, action)
```lua
function on_input(self, action_id, action)
	self.ruu:input(action_id, action)
end
```
#### Ruu:mouseMoved(x, y, dx, dy)
Used internally by `Ruu:input()`. Call it yourself you add/remove/reposition widgets and want to re-check mouse hover.
> `self.ruu:mouseMoved(self.ruu.mx, self.ruu.my, 0, 0)`

### Creating Widgets:
#### Ruu:Button(nodeName, [releaseFn], [wgtTheme])
* __nodeName__ <kbd>string</kbd> - Widget `nodeName`s are just a prefix. The widget constructor will need to find a node at (for example): `nodeName .. "/body"`. It will use that node for collision checking wih `gui.pick_node`. The nodeName is also used as an ID for the widget, so you can get the widget object again using `Ruu:get(nodeName)`.

* __releaseFn__ <kbd>function</kbd> - Called like so:
> `releaseFn(self, widget, ...)` -- 'self' being the Ruu 'owner' - your script-instance 'self'.

All widgets have an `args(...)` method to store any number of custom arguments that will be passed to any of their callbacks, such as their `releaseFn`. `args()` returns the widget, so it can be chained. If you don't use `args()` the callback will just be called with `(self, widget)`.

* __wgtTheme__ <kbd>table</kbd> - If you want to set a custom theme for this specific widget. Otherwise it gets a theme table from inside the theme for the Ruu instance, using the widget's class name. Like so:
> ruu.theme.Button

#### Ruu:ToggleButton(nodeName, releaseFn, isChecked, wgtTheme)

#### Ruu:RadioButton(nodeName, releaseFn, isChecked, wgtTheme)

#### Ruu:groupRadioButtons(widgets)
Link together a list of radio buttons. Siblings will be removed from the list when they are destroyed (Ruu.destroy calls final() on destroyed widgets, if they have it).
* __widgets__ <kbd>table</kbd> A list of widget objects or widget names.

#### Ruu:Slider(nodeName, releaseFn, [fraction], [length], wgtTheme)
Must be the centered child of a "/bar" node. Slider axis is always the local X axis, so rotate the parent bar node if you want a vertical slider or any other angle. Will probably break if you scale the nodes.

When the slider is focused, the keyboard navigation that most closely aligns with the slider's axis will nudge the slider. Set `.nudgeDist` on the slider or its parent class to specify the distance (in pixels, default: 5px).

* __fraction__ <kbd>number</kbd> - The fractional starting position of the slider. Defaults to 0 (all the way left).
* __length__ <kbd>number</kbd> - The total distance the slider can move. Defaults to 100. Simply subtract the length of the handle from the bar length if you want a scrollBar-type slider that "hits" the inside edges of the bar.

`sliderHandle:onDrag(dragFn)` - Add a callback to be fired whenever the slider is moved (chainable method).

To move the slider via code, simply set its `.fraction` and call `slider:updatePos()`. This won't call its drag callback.

#### Ruu:InputField(nodeName, confirmFn, text, wgtTheme)
Basic dumb text fields with input and backspace so far. Need to add selection, etc.

Requires "/mask" and "/text" nodes, and the default theme requires a "/cursor" node.

The current text can be accessed at `inputField.text`.

* __confirmFn__ <kbd>function</kbd> Called when enter is pressed or unfocused from the keyboard. If `confirmFn` returns true, then the entered text is rejected and it reverts to the last value.

`inputField:onEdit(editFn)` - Add a callback to be fired whenever the text is edited (chainable method). The editFn is called after inputField.text is modified, but before things are actually updated with it, so you can safely modify it however you want.

### Other:
#### Ruu:setEnabled(widget, enabled)
Sets whether a widget is considered to be active or not by Ruu. Not show/hide, not "greyed-out", just ignored.

#### Ruu:destroy(widget)
Calls `final()` on the destroyed widget, if it is defined.

#### Ruu:setFocus(widget, isKeyboard)
Use nil 'widget' to unfocus anything that's focused.

#### Ruu:mapNeighbors(map)
* __map__ <kbd>table</kbd> - 2D [y][x] array of widgets to map for keyboard navigation. Empty spaces in the array must be `false`, not `nil`!

```lua
{ -- For vertical list navigation:
	{ wgt1 },
	{ wgt2 },
	{ wgt3 },
}
{ -- For horizontal list navigation:
	( wgt1, wgt2, wgt3 )
}
```

#### Ruu:mapNextPrev(map)
Like mapNeighbors, but for next/prev navigation (tab, shift-tab) rather than directional.

#### Ruu:startDrag(widget, dragType)
For custom drags. `nil` is the default dragType, so don't use that.

#### Ruu:stopDrag(dragType)
To stop a custom drag.

#### Ruu:stopDragsOnWidget(widget)
Probably just for internal use?

#### Ruu:get(name)
Get a widget instance from it's name.

#### Ruu:rename(oldName, newName)
Register a new name for a widget.

### Themes:
Themeing is separate as much as possible from the mechanics of Ruu and its widgets, though it gets a bit blurry with InputFields.

#### Widget Theme Methods:
_(All widgets inherit from Button.)_

* Button.init(self, nodeName)
* Button.hover(self)
* Button.unhover(self)
* Button.focus(self, isKeyboard)
* Button.unfocus(self, isKeyboard)
* Button.press(self, mx, my, isKeyboard)
* Button.release(self, dontFire, mx, my, isKeyboard)


* ToggleButton.setChecked(self, isChecked)


* RadioButton.setChecked(self, isChecked)


* InputField.updateCursor(self)
* InputField.updateText(self)
* InputField.textRejected(self, rejectedText)


* SliderHandle.drag(self)
