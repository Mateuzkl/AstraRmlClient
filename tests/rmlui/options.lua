-- Exercise the production options module and renderer in a disposable profile.
-- No login, player settings, server, or user mods are loaded.
DEFAULT_LAYOUT = 'retro'
dofile('/test-run.lua')
g_resources.setLayout('retro')
dofile('/modules/gamelib/const.lua')
local settingsFile='/options-test-' .. TEST_RUN_ID .. '.otml'
g_configs.loadSettings(settingsFile)
local map = g_ui.createWidget('UIMap', rootWidget)
map:hide()
local function widget() return g_ui.createWidget('UIWidget', rootWidget) end
local refreshes, barRefreshes = 0, 0
modules.client_topmenu = {
  addLeftButton=function() return widget() end,
  setFpsVisible=function() end, setPingVisible=function() end,
}
modules.game_interface = {
  getMapPanel=function() return map end,
  refreshViewMode=function() refreshes=refreshes+1 end,
  updateStretchShrink=function() end,
}
modules.game_actionbar = {show=function() barRefreshes=barRefreshes+1 end}
modules.game_healthinfo = {}
for _, id in ipairs({'healthCircle','healthCircleFront','manaCircle','manaCircleFront','topHealthBar','topManaBar'}) do
  modules.game_healthinfo[id] = widget()
end
modules.client_locales = {
  getCurrentLocale=function() return {name='en'} end,
  getInstalledLocales=function() return {en={languageName='English'},pt={languageName='Portuguese'}} end,
}
g_modules.ensureModuleLoaded('client_options')
local options = modules.client_options
local win
local function el(id) return assert(Rml.element(win, id), id) end
local function click(id) el(id):DispatchEvent('click', {}) end
local function tab(id) click('tab-' .. id) end
local function change(key, value)
  local input = el('option-' .. key)
  input:SetAttribute('value', tostring(value))
  input:DispatchEvent('change', {value=tostring(value)})
end
local function screenshot(done)
  -- Render after a tab switch instead of capturing the previously queued frame.
  scheduleEvent(function()
  local file='astra-options-' .. TEST_RUN_ID .. '-' .. g_clock.millis() .. '.png'
  g_app.doScreenshot(file)
  local function wait(attempts)
    if g_resources.fileExists(file) then
      local data=g_resources.readFileContents(file)
      if #data > 1024 and data:sub(1,8) == '\137PNG\r\n\26\n' and data:sub(-12) == string.char(0,0,0,0,73,69,78,68,174,66,96,130) then
        print('[OPTIONS SCREENSHOT] ' .. g_resources.getWriteDir() .. '/' .. file)
        done()
        return
      end
    end
    assert(attempts > 0, 'screenshot did not finish')
    scheduleEvent(function() wait(attempts-1) end, 100)
  end
  wait(50)
  end,200)
end
local function bounds()
  local size, root = win:getSize(), rootWidget:getSize()
  assert(size.width <= root.width-20 and size.height <= root.height-20, 'window exceeds viewport')
  for _, id in ipairs({'accept-options','close-options','options-tabs','options-content'}) do
    local rect, clip = assert(Rml.elementRect(win,id),id), Rml.clipRect(win,id)
    assert(rect.x >= clip.x-1 and rect.y >= clip.y-1 and rect.x+rect.width <= clip.x+clip.width+1 and
      rect.y+rect.height <= clip.y+clip.height+1, 'clipped essential control: ' .. id)
  end
end
local steps = {
  function(next)
    options.show()
    win=assert(rootWidget:getChildById('rmlOptions'))
    assert(not rootWidget:getChildById('optionsWindow'), 'OTUI options tree was created')
    scheduleEvent(function() screenshot(next) end,400)
  end,
  function(next)
    bounds()
    assert(options.getOption('hotkeyDelay') == 50 and options.getOption('walkFirstStepDelay') == 50,
      'opening range controls overwrote settings')
    assert(#el('options-tabs'):QuerySelectorAll('.category') == 6)
    click('option-smartWalk')
    assert(options.getOption('smartWalk') and g_settings.getBoolean('smartWalk'), 'checkbox did not persist')
    options.setOption('smartWalk', false)
    click('option-smartWalk')
    assert(options.getOption('smartWalk'), 'external checkbox sync suppressed the next user click')
    change('hotkeyDelay', 23)
    assert(options.getOption('hotkeyDelay') == 23 and g_settings.getNumber('hotkeyDelay') == 23)
    options.setOption('hotkeyDelay', 37)
    assert(tonumber(el('option-hotkeyDelay'):GetAttribute('value')) == 37 and el('value-hotkeyDelay').inner_rml == '37 ms',
      'external change did not sync')
    change('hotkeyDelay', 999)
    assert(options.getOption('hotkeyDelay') == 50, 'range accepted invalid bounds')
    click('change-language')
    assert(not el('language-dialog'):HasAttribute('hidden'))
    assert(#el('language-select'):QuerySelectorAll('option') == 2)
    click('language-cancel')
    assert(el('language-dialog'):HasAttribute('hidden'))
    click('change-language')
    win.onEscape()
    assert(el('language-dialog'):HasAttribute('hidden') and not win.rmlClosing, 'Escape did not dismiss the language dialog first')
    next()
  end,
  function(next)
    tab('interface')
    change('leftPanels', 4)
    assert(options.getOption('leftPanels') == 4 and refreshes > 0, 'panel index contract changed')
    click('option-actionbar2')
    assert(options.getOption('actionbar2') and barRefreshes > 0, 'action bar used the wrong option key')
    change('layout', 'Default')
    assert(options.getOption('layout') == 'Default')
    tab('console')
    click('option-showTimestampsInConsole')
    assert(options.getOption('showTimestampsInConsole') == false)
    next()
  end,
  function(next)
    tab('graphics')
    options.setOption('enableLights', true)
    assert(not el('option-ambientLight'):HasAttribute('disabled'))
    options.setLightOptionsVisibility(false)
    assert(el('option-enableLights'):HasAttribute('disabled') and el('option-ambientLight'):HasAttribute('disabled'))
    options.setLightOptionsVisibility(true)
    change('optimizationLevel', 5)
    assert(options.getOption('optimizationLevel') == 5, 'optimization selection did not apply: ' .. tostring(options.getOption('optimizationLevel')))
    change('backgroundFrameRate', 201)
    assert(g_app.getMaxFps() == 0 and el('value-backgroundFrameRate').inner_rml == 'max')
    assert(el('option-missileOpacity'):HasAttribute('disabled'))
    options.setOption('backgroundFrameRate', 0)
    tab('audio')
    click('option-enableMusicSound')
    change('musicSoundVolume', 41)
    assert(options.getOption('musicSoundVolume') == 41)
    options.setOption('enableAudio', false)
    assert(el('option-musicSoundVolume'):HasAttribute('disabled'))
    options.setOption('enableAudio', true)
    tab('extras')
    local extras=g_extras.getAll()
    if #extras > 0 then
      local key, previous=extras[1], g_extras.get(extras[1])
      click('option-' .. key)
      assert(g_extras.get(key) ~= previous and g_settings.getBoolean('extras_' .. key) == g_extras.get(key))
    end
    tab('game')
    screenshot(next)
  end,
  function(next)
    g_window.resize({width=800,height=600})
    next()
  end,
  function(next)
    bounds()
    tab('graphics')
    next()
  end,
  function(next)
    assert(options.getOption('backgroundFrameRate') == 0, 'opening normalized unlimited FPS into a saved finite limit')
    screenshot(next)
  end,
  function(next)
    tab('interface')
    next()
  end,
  function(next)
    assert(el('options-content').scroll_height > el('options-content').client_height, 'long tab does not scroll')
    screenshot(next)
  end,
  function(next)
    click('accept-options')
    next()
  end,
  function(next)
    assert(win:isDestroyed() and g_rml.getContextCount() == 0, 'closed options retained a context')
    assert(g_resources.fileExists(settingsFile), 'settings were not saved')
    local saved=g_resources.readFileContents(settingsFile)
    assert(saved:find('hotkeyDelay: 50',1,true) and saved:find('musicSoundVolume: 41',1,true), 'saved values differ from controls')
    options.show()
    win=assert(rootWidget:getChildById('rmlOptions'))
    next()
  end,
  function(next)
    assert(options.getOption('musicSoundVolume') == 41, 'reopen reset options')
    -- Rapid repeated close/toggle must not create a second context.
    options.hide() options.toggle() options.toggle()
    next()
  end,
  function(next)
    assert(win:isDestroyed() and g_rml.getContextCount() == 0)
    local cycle=0
    local function reopen()
      cycle=cycle+1
      if cycle > 25 then
        print('[RMLUI TEST] PASS: complete classic options; live events, settings, tabs, viewport and 25 lifecycle cycles')
        g_app.exit()
        return
      end
      options.show()
      win=assert(rootWidget:getChildById('rmlOptions'))
      scheduleEvent(function()
        tab(cycle%2 == 0 and 'interface' or 'graphics')
        if cycle%2 == 0 then win.onEscape() else click('close-options') end
        scheduleEvent(function()
          assert(win:isDestroyed() and g_rml.getContextCount() == 0, 'reopen leaked a context')
          reopen()
        end,50)
      end,80)
    end
    reopen()
  end,
}
local function run(index) steps[index](function() scheduleEvent(function() run(index+1) end, 180) end) end
scheduleEvent(function() g_window.resize({width=1100,height=780}) scheduleEvent(function() run(1) end,300) end,200)
