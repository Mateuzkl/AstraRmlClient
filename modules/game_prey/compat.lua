-- Keep Astra's Prey artwork and controls independent of the global client theme.
PreyCompat = {}

function PreyCompat.initialize()
  g_fonts.importFont('/modules/game_prey/fonts/pVerdana Bold-11px.otfont')
  g_fonts.importFont('/modules/game_prey/fonts/Verdana Bold-11px-wheel.otfont')
  g_ui.importStyle('/modules/game_prey/styles.otui')
end

function PreyCompat.setupProgressBar(widget)
  widget.preyPercent = 0
  widget:setFocusable(false)
  widget.setPercent = function(self, value)
    self.preyPercent = math.max(0, math.min(100, tonumber(value) or 0))
    self:setImageRect({x = 0, y = 0, width = math.max(1, math.floor(self:getWidth() * self.preyPercent / 100)), height = self:getHeight()})
    self:setImageColor(self.preyPercent == 0 and '#ffffff00' or '#ffffffff')
  end
  widget.getPercent = function(self) return self.preyPercent end
  connect(widget, {onGeometryChange = function(self) self:setPercent(self.preyPercent) end})
end

function PreyCompat.setInputLockWidget(widget)
  if widget then
    if modules.game_walking then modules.game_walking.stopSmartWalk() end
    widget:focus()
  elseif g_game.isOnline() and modules.game_interface then
    modules.game_interface.getRootPanel():focus()
  end
end

function PreyCompat.attachTracker(widget)
  local panel = modules.game_interface.getRightPanel()
  if not panel then return false end
  widget:setParent(panel)
  return true
end

function PreyCompat.setStringColor(values, text, color)
  values[#values + 1] = text
  values[#values + 1] = color
end

function PreyCompat.shortText(text, limit)
  text = tostring(text)
  return #text > limit and text:sub(1, limit - 3) .. '...' or text
end

function PreyCompat.capitalize(text)
  return text:gsub('(%w)([%w]*)', function(first, rest) return first:upper() .. rest:lower() end)
end
