-- RmlUi presentation only. The existing options service owns values and persistence.
OptionsView = {}
local window, activeTab = nil, 'game'
local syncing = false
local lightOptionsEnabled = true
local controls = {}
local displayedValues = {}
local resize

local function check(key, label, desktop, hint)
  return {key=key, label=label, kind='check', desktop=desktop, hint=hint}
end
local function range(key, label, min, max, suffix, desktop)
  return {key=key, label=label, kind='range', min=min, max=max, suffix=suffix or '', desktop=desktop}
end
local function selectOption(key, label, choices, desktop)
  return {key=key, label=label, kind='select', choices=choices, desktop=desktop}
end
local sections = {
  {id='game', label='Game', icon='game', options={
    check('classicControl', 'Classic control', true),
    check('autoChaseOverride', 'Allow auto chase override'),
    check('displayText', 'Display text messages'),
    check('wsadWalking', 'Enable WSAD walking', true, 'Disable chat and allow walk using WSAD keys'),
    check('dash', 'Enable fast walking (DASH)', false, 'Allows to execute next move without server confirmation of previous one'),
    check('smartWalk', 'Enable smart walking', false, 'Will detect when to use diagonal step based on the keys you are pressing'),
    range('hotkeyDelay', 'Hotkey delay', 5, 50, ' ms'),
    range('walkFirstStepDelay', 'Walk delay after first step', 50, 300, ' ms', true),
    range('walkTurnDelay', 'Walk delay after turn', 0, 300, ' ms', true),
    range('walkCtrlTurnDelay', 'Walk delay after ctrl turn', 0, 300, ' ms', true),
    range('walkStairsDelay', 'Walk delay after floor change', 0, 300, ' ms', true),
    range('walkTeleportDelay', 'Walk delay after teleport', 0, 300, ' ms', true),
  }},
  {id='interface', label='Interface', icon='game', options={
    selectOption('layout', 'Layout (change requires client restart)', {}, true),
    check('classicView', 'Classic view', true),
    check('cacheMap', 'Cache map (for non-classic view)', true),
    check('actionbar1', 'Show first action bar'),
    check('actionbar2', 'Show second action bar'),
    check('showPing', 'Show connection ping'),
    check('displayNames', 'Display creature names'),
    check('displayHealth', 'Display creature health bars'),
    check('displayHealthOnTop', 'Display creature health bars above texts', true),
    check('hidePlayerBars', 'Show player health bar'),
    check('displayMana', 'Show player mana bar', true),
    check('topHealtManaBar', 'Show player top health and mana bar'),
    check('showHealthManaCircle', 'Show health and mana circle', true),
    check('highlightThingsUnderCursor', 'Highlight things under cursor'),
    selectOption('leftPanels', 'Left panels', {'0','1','2','3','4'}),
    selectOption('rightPanels', 'Right panels', {'1','2','3','4'}),
    selectOption('containerPanel', "Container's panel", {'1st left panel','2nd left panel','3rd left panel','4th left panel',
      '1st right panel','2nd right panel','3rd right panel','4th right panel'}),
    selectOption('crosshair', 'Crosshair', {'None','Default','Full'}),
    range('floorFading', 'Floor fading', 0, 2000, ' ms'),
  }},
  {id='console', label='Console', icon='console', options={
    check('showInfoMessagesInConsole', 'Show info messages in console'),
    check('showEventMessagesInConsole', 'Show event messages in console'),
    check('showStatusMessagesInConsole', 'Show status messages in console'),
    check('showTimestampsInConsole', 'Show timestamps in console'),
    check('showLevelsInConsole', 'Show levels in console'),
    check('showPrivateMessagesInConsole', 'Show private messages in console'),
    check('showPrivateMessagesOnScreen', 'Show private messages on screen'),
  }},
  {id='graphics', label='Graphics', icon='graphics', options={
    check('vsync', 'Enable vertical synchronization'),
    check('showFps', 'Show frame rate'),
    check('enableLights', 'Enable lights'),
    check('fullscreen', 'Fullscreen', false, 'Ctrl+Shift+F'),
    check('antialiasing', 'Antialiasing', true),
    selectOption('optimizationLevel', 'Optimization level', {'Automatic','None','Low','Medium','High','Maximum'}),
    range('backgroundFrameRate', 'Game framerate limit', 10, 201, ' FPS'),
    range('ambientLight', 'Ambient light', 0, 100, '%'),
    range('effectOpacity', 'Effect opacity', 10, 100, '%', true),
    range('missileOpacity', 'Missile opacity', 10, 100, '%', true),
  }},
  {id='audio', label='Audio', icon='audio', options={
    check('enableAudio', 'Enable audio'),
    check('enableMusicSound', 'Enable music sound'),
    range('musicSoundVolume', 'Music volume', 0, 100, '%'),
    range('botSoundVolume', 'Bot sound volume', 0, 100, '%'),
  }},
  {id='extras', label='Extras', icon='extras', options={}},
}
for _, section in ipairs(sections) do
  for _, option in ipairs(section.options) do controls[option.key] = option end
end

local function escape(value) return Rml.escape(Rml.text(value)) end
local function text(value) return escape(tr(value)) end
local function element(id) return window and Rml.element(window, id) end
local function extrasVisible() return not g_game.getFeature(GameNoDebug) and not g_app.isMobile() end
local function visible(option) return not option.desktop or not g_app.isMobile() end
local function enabled(key)
  if key == 'missileOpacity' then return false end -- The engine shares effect/projectile alpha.
  if key == 'enableLights' or key == 'floorFading' then return lightOptionsEnabled end
  if key == 'ambientLight' then return lightOptionsEnabled and getOption('enableLights') end
  if key == 'enableMusicSound' or key == 'botSoundVolume' then return getOption('enableAudio') end
  if key == 'musicSoundVolume' then return getOption('enableAudio') and getOption('enableMusicSound') end
  return true
end
local function valueText(option, value)
  if option.key == 'backgroundFrameRate' and (value <= 0 or value >= 201) then return tr('max') end
  if option.key == 'missileOpacity' then return tr('shared with effects') end
  return tostring(value) .. (option.suffix or '')
end
local function choices(option)
  local list = {}
  if option.key == 'layout' then
    list[1] = {value='Default', label='Default'}
    for _, file in ipairs(g_resources.listDirectoryFiles('/layouts', false, true)) do
      if g_resources.directoryExists('/layouts/' .. file) then
        local name = file:gsub('^%l', string.upper)
        list[#list+1] = {value=name, label=name}
      end
    end
    -- Keep a saved layout name even if its directory was removed locally.
    local saved, found = getOption('layout'), false
    for _, item in ipairs(list) do
      if item.value:lower() == saved:lower() then found=true item.value=saved end
    end
    if not found then list[#list+1] = {value=saved, label=saved} end
  else
    -- Preserve the one-based indices expected by the game interface.
    for i, label in ipairs(option.choices) do list[i] = {value=tostring(i), label=label} end
  end
  return list
end
local function row(option)
  local value = getOption(option.key)
  if value == nil or not visible(option) then return '' end
  if option.kind == 'range' then
    if option.key == 'backgroundFrameRate' and value <= 0 then value=201 end
    value=math.max(option.min, math.min(option.max, value))
  end
  displayedValues[option.key] = value
  local key, disabled = option.key, enabled(option.key) and '' or ' disabled'
  local title = option.hint and (' title="' .. text(option.hint) .. '"') or ''
  if option.kind == 'check' then
    return '<label class="check-row"' .. title .. '><input type="checkbox" id="option-' .. key .. '"' ..
      (value and ' checked' or '') .. disabled .. '/><span>' .. text(option.label) .. '</span></label>'
  elseif option.kind == 'range' then
    return '<div class="range-row"' .. title .. '><label for="option-' .. key .. '">' .. text(option.label) ..
      ': <span id="value-' .. key .. '">' .. escape(valueText(option, value)) .. '</span></label>' ..
      '<input type="range" id="option-' .. key .. '" min="' .. option.min .. '" max="' .. option.max ..
      '" step="1" value="' .. value .. '"' .. disabled .. '/></div>'
  end
  local markup = {'<div class="select-row"><label for="option-' .. key .. '">' .. text(option.label) ..
    '</label><select id="option-' .. key .. '" value="' .. escape(value) .. '"' .. disabled .. '>'}
  for _, item in ipairs(choices(option)) do
    local selected = tostring(value):lower() == item.value:lower()
    markup[#markup+1] = '<option value="' .. escape(item.value) .. '"' .. (selected and ' selected' or '') ..
      '>' .. text(item.label) .. '</option>'
  end
  markup[#markup+1] = '</select></div>'
  return table.concat(markup)
end

function OptionsView.selectTab(id)
  if not window or window.rmlClosing then return end
  local selected
  for _, section in ipairs(sections) do if section.id == id then selected=section end end
  if not selected or (id == 'extras' and not extrasVisible()) then return end
  activeTab, syncing = id, true
  local markup = {}
  if id == 'graphics' then
    markup[#markup+1] = '<div class="device-info"><b>GPU</b><p>' .. escape(g_graphics.getRenderer()) ..
      '</p><p>' .. escape(g_graphics.getVersion()) .. '</p></div>'
  end
  for _, option in ipairs(selected.options) do markup[#markup+1] = row(option) end
  if id == 'game' then
    markup[#markup+1] = '<button id="change-language" class="classic-button language-button">' .. text('Change language') .. '</button>'
  elseif id == 'graphics' then
    markup[#markup+1] = '<p class="hint">' .. text('High/Maximum optimization level may cause visual defects.') .. '</p>'
  elseif id == 'interface' then
    markup[#markup+1] = '<p class="hint">' .. text("Floor fading doesn't work with enabled light") .. '</p>'
  elseif id == 'extras' and #selected.options == 0 then
    markup[#markup+1] = '<p class="hint">' .. text('No extra options are available in this build.') .. '</p>'
  end
  element('options-content').inner_rml = table.concat(markup)
  element('options-content').scroll_top = 0
  element('section-title').inner_rml = text(selected.label)
  for _, section in ipairs(sections) do
    local tab = element('tab-' .. section.id)
    if tab then tab:SetClass('selected', section.id == id) end
  end
  syncing = false
end

function OptionsView.sync(key)
  if not window or window.rmlClosing then return end
  syncing = true
  local input, option = element('option-' .. key), controls[key]
  if input and option then
    local value = getOption(key)
    if option.kind == 'check' then
      displayedValues[key]=value
      if value then input:SetAttribute('checked', '') else input:RemoveAttribute('checked') end
    else
      local displayValue=value
      if option.kind == 'range' then
        if key == 'backgroundFrameRate' and value <= 0 then displayValue=201 end
        displayValue=math.max(option.min, math.min(option.max, displayValue))
      end
      displayedValues[key]=displayValue
      input:SetAttribute('value', tostring(displayValue))
      local label = element('value-' .. key)
      if label then label.inner_rml = escape(valueText(option, value)) end
    end
  end
  for _, dependency in ipairs({'enableLights','ambientLight','floorFading','enableMusicSound','musicSoundVolume','botSoundVolume','missileOpacity'}) do
    local control = element('option-' .. dependency)
    if control then
      if enabled(dependency) then control:RemoveAttribute('disabled') else control:SetAttribute('disabled', '') end
    end
  end
  syncing = false
end

local function change(event)
  if syncing or not window or window.rmlClosing then return end
  local input = event.target_element
  local key = input.id:match('^option%-(.+)$')
  local option = key and controls[key]
  if not option or not enabled(key) or not visible(option) then return end
  local value
  if option.kind == 'check' then value=input:HasAttribute('checked')
  elseif option.kind == 'range' then
    value=tonumber(event.parameters.value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return end
    value=math.floor(math.max(option.min, math.min(option.max, value)) + 0.5)
  else
    for _, item in ipairs(choices(option)) do
      if item.value == event.parameters.value then value=key == 'layout' and item.value or tonumber(item.value) end
    end
    if value == nil then return end
  end
  -- Native controls can emit change while their first layout is initialized.
  -- Ignore the value we just rendered; only a changed input reaches the service.
  if displayedValues[key] == value then return end
  displayedValues[key]=value
  if getOption(key) ~= value then setOption(key, value) end
end

local function languageDialog()
  local locales = modules.client_locales
  local current = locales.getCurrentLocale().name
  local names, markup = {}, {}
  for name in pairs(locales.getInstalledLocales()) do names[#names+1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local locale = locales.getInstalledLocales()[name]
    markup[#markup+1] = '<option value="' .. escape(name) .. '"' .. (current == name and ' selected' or '') ..
      '>' .. escape(locale.languageName) .. '</option>'
  end
  element('language-select').inner_rml = table.concat(markup)
  element('language-dialog'):RemoveAttribute('hidden')
end

resize = function()
  if not window or window:isDestroyed() then return end
  local size = rootWidget:getSize()
  window:setSize({width=math.min(490, size.width-20), height=math.min(500, size.height-20)})
  window:setMarginLeft(0)
  window:setMarginTop(0)
end

function OptionsView.show()
  if window and not window:isDestroyed() then
    if not window.rmlClosing then window:raise() window:focus() end
    return true
  end
  if not Rml.isAvailable() then return false end
  local extras = sections[#sections].options
  for _, option in ipairs(extras) do controls[option.key] = nil end
  sections[#sections].options = {}
  for _, key in ipairs(g_extras.getAll()) do
    local option = check(key, g_extras.getDescription(key))
    controls[key] = option
    table.insert(sections[#sections].options, option)
  end
  window = Rml.createWindow{
    id='rmlOptions', document='/modules/client_options/options.rml', model='clientOptions',
    width=490, height=500,
    data={title=Rml.text(tr('Options')), ok=Rml.text(tr('Ok')), language=Rml.text(tr('Change language')),
      cancel=Rml.text(tr('Cancel')), apply=Rml.text(tr('Apply')),
      Close=function() hide() end},
    onClose=function()
      disconnect(rootWidget, {onGeometryChange=resize})
      g_settings.save()
      window=nil
    end,
  }
  if not window then return false end
  window.onEscape = function()
    local dialog=element('language-dialog')
    if not dialog:HasAttribute('hidden') then dialog:SetAttribute('hidden', '') else hide() end
  end
  window.onKeyPress = function(self, key, modifiers)
    if modifiers ~= KeyboardNoModifier then return false end
    if key == KeyEscape then self.onEscape() return true end
    if key == KeyEnter then hide() return true end
    return false
  end
  resize()
  connect(rootWidget, {onGeometryChange=resize})
  local tabs = {}
  for _, section in ipairs(sections) do
    if section.id ~= 'extras' or extrasVisible() then
      tabs[#tabs+1] = '<button id="tab-' .. section.id .. '" data-tab="' .. section.id .. '" class="category">' ..
        '<img src="/images/optionstab/' .. section.icon .. '.png"/><span>' .. text(section.label) .. '</span></button>'
    end
  end
  element('options-tabs').inner_rml = table.concat(tabs)
  Rml.on(window, 'options-tabs', 'click', function(event)
    local target = event.target_element
    while target do
      if target:HasAttribute('data-tab') then OptionsView.selectTab(target:GetAttribute('data-tab')) return end
      target=target.parent_node
    end
  end)
  Rml.on(window, 'options-content', 'change', change)
  Rml.on(window, 'options-content', 'click', function(event)
    if event.target_element.id == 'change-language' then languageDialog() end
  end)
  Rml.on(window, 'language-cancel', 'click', function() element('language-dialog'):SetAttribute('hidden', '') end)
  Rml.on(window, 'language-apply', 'click', function()
    local name = element('language-select'):GetAttribute('value')
    if not modules.client_locales.getInstalledLocales()[name] then return end
    -- Module reload must happen outside the RmlUi callback stack.
    Rml.defer(window, function() modules.client_locales.selectFirstLocale(name) end)
  end)
  OptionsView.selectTab(activeTab == 'extras' and not extrasVisible() and 'game' or activeTab)
  return true
end

function OptionsView.isVisible() return window ~= nil and not window:isDestroyed() end
function OptionsView.close()
  if window then Rml.close(window) end
end
function OptionsView.setLightOptionsVisibility(value)
  lightOptionsEnabled = value
  OptionsView.sync('enableLights')
end
function OptionsView.destroy()
  disconnect(rootWidget, {onGeometryChange=resize})
  if window then window:destroy() window=nil end
end
