local defaultOptions = {
  layout = DEFAULT_LAYOUT, -- set in init.lua
  vsync = true,
  showFps = true,
  showPing = true,
  fullscreen = false,
  classicView = not g_app.isMobile(),
  cacheMap = g_app.isMobile(),
  classicControl = not g_app.isMobile(),
  smartWalk = false,
  dash = false,
  autoChaseOverride = true,
  showStatusMessagesInConsole = true,
  showEventMessagesInConsole = true,
  showInfoMessagesInConsole = true,
  showTimestampsInConsole = true,
  showLevelsInConsole = true,
  showPrivateMessagesInConsole = true,
  showPrivateMessagesOnScreen = true,
  rightPanels = 1,
  leftPanels = g_app.isMobile() and 1 or 2,
  containerPanel = 8,
  backgroundFrameRate = 60,
  enableAudio = true,
  enableMusicSound = false,
  musicSoundVolume = 100,
  botSoundVolume = 100,
  enableLights = false,
  floorFading = 500,
  crosshair = 2,
  ambientLight = 100,
  optimizationLevel = 1,
  displayNames = true,
  displayHealth = true,
  displayMana = true,
  displayHealthOnTop = false,
  showHealthManaCircle = false,
  hidePlayerBars = false,
  highlightThingsUnderCursor = true,
  topHealtManaBar = true,
  displayText = true,
  dontStretchShrink = false,
  turnDelay = 30,
  hotkeyDelay = 50,
    
  wsadWalking = false,
  walkFirstStepDelay = 50,
  walkTurnDelay = 0,
  walkStairsDelay = 0,
  walkTeleportDelay = 0,
  walkCtrlTurnDelay = 0,

  topBar = true,

  actionbar1 = true,
  actionbar2 = false,
  actionbar3 = false,
  actionbar4 = false,
  actionbar5 = false,
  actionbar6 = false,
  actionbar7 = false,
  actionbar8 = false,
  actionbar9 = false,

  actionbarLock = false,

  profile = 1,
  
  antialiasing = false,

  effectOpacity = 100,
  missileOpacity = 100
}

local optionsButton
local options = {}
local extraOptions = {}
local audioButton
local setupEvent

function init()
  for k,v in pairs(defaultOptions) do
    g_settings.setDefault(k, v)
    options[k] = v
  end
  for _, v in ipairs(g_extras.getAll()) do
    extraOptions[v] = g_extras.get(v)
    g_settings.setDefault("extras_" .. v, extraOptions[v])
  end
  g_keyboard.bindKeyDown('Ctrl+Shift+F', function() toggleOption('fullscreen') end)
  g_keyboard.bindKeyDown('Ctrl+N', toggleDisplays)

  optionsButton = modules.client_topmenu.addLeftButton('optionsButton', tr('Options'), '/images/topbuttons/options', toggle)
  audioButton = modules.client_topmenu.addLeftButton('audioButton', tr('Audio'), '/images/topbuttons/audio', function() toggleOption('enableAudio') end)
  if g_app.isMobile() then
    audioButton:hide()
  end
  
  setupEvent = addEvent(function() setupEvent=nil setup() end)
  
  connect(g_game, { onGameStart = online,
                     onGameEnd = offline })                    
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                     onGameEnd = offline })  

  g_keyboard.unbindKeyDown('Ctrl+Shift+F')
  g_keyboard.unbindKeyDown('Ctrl+N')
  if setupEvent then removeEvent(setupEvent) setupEvent=nil end
  OptionsView.destroy()
  optionsButton:destroy()
  audioButton:destroy()
end

function setup()
  -- load options
  for k,v in pairs(defaultOptions) do
    if type(v) == 'boolean' then
      setOption(k, g_settings.getBoolean(k), true)
    elseif type(v) == 'number' then
      setOption(k, g_settings.getNumber(k), true)
    elseif type(v) == 'string' then
      setOption(k, g_settings.getString(k), true)
    end
  end
  
  for _, v in ipairs(g_extras.getAll()) do
    g_extras.set(v, g_settings.getBoolean("extras_" .. v))
  end  
  
  if g_game.isOnline() then
    online()
  end  
end

function toggle()
  if OptionsView.isVisible() then
    hide()
  else
    show()
  end
end

function show()
  if not OptionsView.show() then
    g_logger.warning('Options requires a client build with RmlUi support.')
  end
end

function hide()
  OptionsView.close()
end

function toggleDisplays()
  if options['displayNames'] and options['displayHealth'] and options['displayMana'] then
    setOption('displayNames', false)
  elseif options['displayHealth'] then
    setOption('displayHealth', false)
    setOption('displayMana', false)
  else
    if not options['displayNames'] and not options['displayHealth'] then
      setOption('displayNames', true)
    else
      setOption('displayHealth', true)
      setOption('displayMana', true)
    end
  end
end

function toggleOption(key) 
  setOption(key, not getOption(key))
end

function setOption(key, value, force)
  if extraOptions[key] ~= nil then
    g_extras.set(key, value)
    g_settings.set("extras_" .. key, value)
    OptionsView.sync(key)
    if key == "debugProxy" and modules.game_proxy then
      if value then
        modules.game_proxy.show()
      else
        modules.game_proxy.hide()      
      end
    end
    return
  end
  
  if modules.game_interface == nil then
    return
  end
   
  if not force and options[key] == value then return end
  local gameMapPanel = modules.game_interface.getMapPanel()

  if key == 'vsync' then
    g_window.setVerticalSync(value)
  elseif key == 'showFps' then
    modules.client_topmenu.setFpsVisible(value)
    if modules.game_stats and modules.game_stats.ui.fps then
      modules.game_stats.ui.fps:setVisible(value)
    end
  elseif key == 'showPing' then
    modules.client_topmenu.setPingVisible(value)
    if modules.game_stats and modules.game_stats.ui.ping then
      modules.game_stats.ui.ping:setVisible(value)
    end
  elseif key == 'fullscreen' then
    g_window.setFullscreen(value)
  elseif key == 'enableAudio' then
    if g_sounds ~= nil then
      g_sounds.setAudioEnabled(value)
    end
    if value then
      audioButton:setIcon('/images/topbuttons/audio')
    else
      audioButton:setIcon('/images/topbuttons/audio_mute')
    end
  elseif key == 'enableMusicSound' then
    if g_sounds ~= nil then
      g_sounds.getChannel(SoundChannels.Music):setEnabled(value)
    end
  elseif key == 'musicSoundVolume' then
    if g_sounds ~= nil then
      g_sounds.getChannel(SoundChannels.Music):setGain(value/100)
    end
  elseif key == 'botSoundVolume' then
    if g_sounds ~= nil then
      g_sounds.getChannel(SoundChannels.Bot):setGain(value/100)
    end
  elseif key == 'showHealthManaCircle' then
    modules.game_healthinfo.healthCircle:setVisible(value)
    modules.game_healthinfo.healthCircleFront:setVisible(value)
    modules.game_healthinfo.manaCircle:setVisible(value)
    modules.game_healthinfo.manaCircleFront:setVisible(value)
  elseif key == 'backgroundFrameRate' then
    local v = value
    if value <= 0 or value >= 201 then v = 0 end
    g_app.setMaxFps(v)
  elseif key == 'enableLights' then
    gameMapPanel:setDrawLights(value and options['ambientLight'] < 100)
  elseif key == 'floorFading' then
    gameMapPanel:setFloorFading(value)
  elseif key == 'crosshair' then
    if value == 1 then
      gameMapPanel:setCrosshair("")    
    elseif value == 2 then
      gameMapPanel:setCrosshair("/images/crosshair/default.png")        
    elseif value == 3 then
      gameMapPanel:setCrosshair("/images/crosshair/full.png")    
    end
  elseif key == 'ambientLight' then
    gameMapPanel:setMinimumAmbientLight(value/100)
    gameMapPanel:setDrawLights(options['enableLights'] and value < 100)
  elseif key == 'optimizationLevel' then
    g_adaptiveRenderer.setLevel(value - 2)
  elseif key == 'displayNames' then
    gameMapPanel:setDrawNames(value)
  elseif key == 'displayHealth' then
    gameMapPanel:setDrawHealthBars(value)
  elseif key == 'displayMana' then
    gameMapPanel:setDrawManaBar(value)
  elseif key == 'displayHealthOnTop' then
    gameMapPanel:setDrawHealthBarsOnTop(value)
  elseif key == 'hidePlayerBars' then
    gameMapPanel:setDrawPlayerBars(value)
  elseif key == 'topHealtManaBar' then
    modules.game_healthinfo.topHealthBar:setVisible(value)
    modules.game_healthinfo.topManaBar:setVisible(value)
  elseif key == 'displayText' then
    gameMapPanel:setDrawTexts(value)
  elseif key == 'dontStretchShrink' then
    addEvent(function()
      modules.game_interface.updateStretchShrink()
    end)
  elseif key == 'dash' then
    if value then
      g_game.setMaxPreWalkingSteps(2)
    else 
      g_game.setMaxPreWalkingSteps(1)    
    end
  elseif key == 'wsadWalking' then
    if modules.game_console and modules.game_console.consoleToggleChat:isChecked() ~= value then
      modules.game_console.consoleToggleChat:setChecked(value)
    end
  elseif key == "antialiasing" then
    g_app.setSmooth(value)
  elseif key == 'effectOpacity' then
    if not g_app.isMobile() then
      g_client.setEffectAlpha(value / 100)
    end
  end
  
  g_settings.set(key, value)
  options[key] = value
  OptionsView.sync(key)

  if key == "profile" then
    if modules.client_profiles then
      modules.client_profiles.onProfileChange()
    end
  end
  
  if key == 'classicView' or key == 'rightPanels' or key == 'leftPanels' or key == 'cacheMap' then
    modules.game_interface.refreshViewMode()    
  elseif key:find("actionbar") then
    modules.game_actionbar.show()
  end

  if key == 'topBar' then
    if modules.game_topbar then
      modules.game_topbar.show()
    end
  end
end

function getOption(key)
  if extraOptions[key] ~= nil then return g_extras.get(key) end
  return options[key]
end

-- hide/show

function online()
  setLightOptionsVisibility(not g_game.getFeature(GameForceLight))
  if not g_app.isMobile() and g_app.setSmooth then
    g_app.setSmooth(g_settings.getBoolean("antialiasing"))
  end
end

function offline()
  setLightOptionsVisibility(true)
end

function setLightOptionsVisibility(value)
  OptionsView.setLightOptionsVisibility(value)
end
