local checks = 0
local function check(ok, why) checks=checks+1; assert(ok,why) end
local screens = {
  {'client_rmldemo','rmlDemoWindow'},
  {'client_rmloptions','rmlOptions'},
  {'game_rmlminimap','rmlMinimap'},
  {'game_rmloutfit','rmlOutfit'},
  {'game_rmlskilltree','rmlSkillTreeDemo'},
  {'client_rmlshowcase','rmlShowcase'}
}
local function run()
  check(g_resources.getWriteDir():find('astra_rml_compat_test',1,true), 'Isolated test profile')
  check(Rml and Rml.isAvailable(), 'RmlUi helper and native runtime ready')
  g_game.setProtocolVersion(860); g_game.setClientVersion(860)
  g_settings.set('client-version',860)
  local function nextScreen(index)
    local item = screens[index]
    if not item then
      print('ASTRA_RML_SCREENS_PASS: ' .. checks .. ' checks; all six RmlUi screens open and close')
      g_app.exit()
      return
    end
    local name, id = item[1], item[2]
    g_modules.ensureModuleLoaded(name)
    local baseline = g_rml.getWidgetCount()
    modules[name].toggle()
    local window = rootWidget:recursiveGetChildById(id)
    check(window and window:isVisible(), 'Screen opens: ' .. name)
    check(window:hasDocument(), 'RML document loaded: ' .. name)
    scheduleEvent(function()
      check(not window:isDestroyed() and window:hasDocument(), 'Screen survives native updates: ' .. name)
      modules[name].toggle()
      scheduleEvent(function()
        check(window:isDestroyed(), 'Window destroyed: ' .. name)
        check(g_rml.getWidgetCount() == baseline, 'RmlUi resources released: ' .. name)
        nextScreen(index+1)
      end,300)
    end,300)
  end
  nextScreen(1)
end
scheduleEvent(run,500)
