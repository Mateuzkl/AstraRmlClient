smartWalkDirs = {}
smartWalkDir = nil
wsadWalking = false
nextWalkDir = nil
lastWalkDir = nil
lastFinishedStep = 0
autoWalkEvent = nil
firstStep = true
walkLock = 0
walkEvent = nil
lastWalk = 0
lastTurn = 0
lastTurnDirection = 0
lastStop = 0
lastManualWalk = 0
autoFinishNextServerWalk = 0
turnKeys = {}

local FastTurnRepeatDelay = 50

function init()
  g_game.setMaxPreWalkingSteps(1)
  connect(g_game, { onTeleport = onTeleport, onGameEnd = stopSmartWalk })
  connect(LocalPlayer, {
    onPositionChange = onPositionChange,
    onWalk = onWalk,
    onWalkFinish = onWalkFinish,
    onCancelWalk = onCancelWalk
  })

  modules.game_interface.getRootPanel().onFocusChange = stopSmartWalk
  bindKeys()
end

function terminate()
  disconnect(g_game, { onTeleport = onTeleport, onGameEnd = stopSmartWalk })
  removeEvent(walkEvent)
  disconnect(LocalPlayer, {
    onPositionChange = onPositionChange,
    onWalk = onWalk,
    onWalkFinish = onWalkFinish,
    onCancelWalk = onCancelWalk
  })
  removeEvent(autoWalkEvent)
  stopSmartWalk()
  unbindKeys()
  disableWSAD()
end

function bindKeys()
  bindWalkKey('Up', North)
  bindWalkKey('Right', East)
  bindWalkKey('Down', South)
  bindWalkKey('Left', West)
  bindWalkKey('Numpad8', North)
  bindWalkKey('Numpad9', NorthEast)
  bindWalkKey('Numpad6', East)
  bindWalkKey('Numpad3', SouthEast)
  bindWalkKey('Numpad2', South)
  bindWalkKey('Numpad1', SouthWest)
  bindWalkKey('Numpad4', West)
  bindWalkKey('Numpad7', NorthWest)

  bindTurnKey('Ctrl+Up', North)
  bindTurnKey('Ctrl+Right', East)
  bindTurnKey('Ctrl+Down', South)
  bindTurnKey('Ctrl+Left', West)
  bindTurnKey('Ctrl+Numpad8', North)
  bindTurnKey('Ctrl+Numpad6', East)
  bindTurnKey('Ctrl+Numpad2', South)
  bindTurnKey('Ctrl+Numpad4', West)
end

function unbindKeys()
  unbindWalkKey('Up', North)
  unbindWalkKey('Right', East)
  unbindWalkKey('Down', South)
  unbindWalkKey('Left', West)
  unbindWalkKey('Numpad8', North)
  unbindWalkKey('Numpad9', NorthEast)
  unbindWalkKey('Numpad6', East)
  unbindWalkKey('Numpad3', SouthEast)
  unbindWalkKey('Numpad2', South)
  unbindWalkKey('Numpad1', SouthWest)
  unbindWalkKey('Numpad4', West)
  unbindWalkKey('Numpad7', NorthWest)

  unbindTurnKey('Ctrl+Up', North)
  unbindTurnKey('Ctrl+Right', East)
  unbindTurnKey('Ctrl+Down', South)
  unbindTurnKey('Ctrl+Left', West)
  unbindTurnKey('Ctrl+Numpad8', North)
  unbindTurnKey('Ctrl+Numpad6', East)
  unbindTurnKey('Ctrl+Numpad2', South)
  unbindTurnKey('Ctrl+Numpad4', West)
end

function enableWSAD()
  if wsadWalking then
    return
  end
  wsadWalking = true  
  local player = g_game.getLocalPlayer()
  if player then
    player:lockWalk(100) -- 100 ms walk lock for all directions    
  end

  bindWalkKey("W", North)
  bindWalkKey("D", East)
  bindWalkKey("S", South)
  bindWalkKey("A", West)

  bindTurnKey("Ctrl+W", North)
  bindTurnKey("Ctrl+D", East)
  bindTurnKey("Ctrl+S", South)
  bindTurnKey("Ctrl+A", West)

  bindWalkKey("E", NorthEast)
  bindWalkKey("Q", NorthWest)
  bindWalkKey("C", SouthEast)
  bindWalkKey("Z", SouthWest)
end

function disableWSAD()
  if not wsadWalking then
    return
  end
  wsadWalking = false

  unbindWalkKey("W")
  unbindWalkKey("D")
  unbindWalkKey("S")
  unbindWalkKey("A")

  unbindTurnKey("Ctrl+W")
  unbindTurnKey("Ctrl+D")
  unbindTurnKey("Ctrl+S")
  unbindTurnKey("Ctrl+A")

  unbindWalkKey("E")
  unbindWalkKey("Q")
  unbindWalkKey("C")
  unbindWalkKey("Z")
end

function bindWalkKey(key, dir)
  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyDown(key, function() changeWalkDir(dir) end, gameRootPanel, true)
  g_keyboard.bindKeyUp(key, function() changeWalkDir(dir, true) end, gameRootPanel, true)
  g_keyboard.bindKeyPress(key, function(c, k, ticks) smartWalk(dir, ticks) end, gameRootPanel)
end

function unbindWalkKey(key)
  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyDown(key, gameRootPanel)
  g_keyboard.unbindKeyUp(key, gameRootPanel)
  g_keyboard.unbindKeyPress(key, gameRootPanel)
end

function bindTurnKey(key, dir)
  turnKeys[key] = dir
  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.bindKeyDown(key, function() turn(dir, false) end, gameRootPanel)
  g_keyboard.bindKeyPress(key, function() turn(dir, true) end, gameRootPanel)
  g_keyboard.bindKeyUp(key, function() local player = g_game.getLocalPlayer() if player then player:lockWalk(g_settings.getNumber('walkCtrlTurnDelay')) end stopSmartWalk() end, gameRootPanel)
end

function unbindTurnKey(key)
  turnKeys[key] = nil
  local gameRootPanel = modules.game_interface.getRootPanel()
  g_keyboard.unbindKeyDown(key, gameRootPanel)
  g_keyboard.unbindKeyPress(key, gameRootPanel)
  g_keyboard.unbindKeyUp(key, gameRootPanel)
end

function stopSmartWalk()
  smartWalkDirs = {}
  smartWalkDir = nil
  nextWalkDir = nil
  g_game.cancelWalkQueue()
  removeEvent(walkEvent)
  walkEvent = nil
  removeEvent(autoWalkEvent)
  autoWalkEvent = nil
end

function changeWalkDir(dir, pop)
  while table.removevalue(smartWalkDirs, dir) do end
  if pop then
    if #smartWalkDirs == 0 then
      stopSmartWalk()
      return
    end
  else
    table.insert(smartWalkDirs, 1, dir)
  end

  smartWalkDir = smartWalkDirs[1]
  if modules.client_options.getOption('smartWalk') and #smartWalkDirs > 1 then
    for _,d in pairs(smartWalkDirs) do
      if (smartWalkDir == North and d == West) or (smartWalkDir == West and d == North) then
        smartWalkDir = NorthWest
        break
      elseif (smartWalkDir == North and d == East) or (smartWalkDir == East and d == North) then
        smartWalkDir = NorthEast
        break
      elseif (smartWalkDir == South and d == West) or (smartWalkDir == West and d == South) then
        smartWalkDir = SouthWest
        break
      elseif (smartWalkDir == South and d == East) or (smartWalkDir == East and d == South) then
        smartWalkDir = SouthEast
        break
      end
    end
  end

  nextWalkDir = smartWalkDir
  g_game.cancelWalkQueue()
end

function smartWalk(dir, ticks)
  removeEvent(walkEvent)
  walkEvent = nil

  if g_keyboard.getModifiers() == KeyboardNoModifier then
    return walk(smartWalkDir or dir, ticks)
  end

  return true
end

function canChangeFloorDown(pos)
  pos.z = pos.z + 1
  toTile = g_map.getTile(pos)
  return toTile and toTile:hasElevation(3)
end

function canChangeFloorUp(pos)
  pos.z = math.max(0, pos.z - 1)
  toTile = g_map.getTile(pos)
  return toTile and toTile:isWalkable()
end

function onPositionChange(player, newPos, oldPos)
end

function onWalk(player, newPos, oldPos)
  if autoFinishNextServerWalk + 200 > g_clock.millis() then
    player:finishServerWalking()
  end
end

function onTeleport(player, newPos, oldPos)
  if not newPos or not oldPos then
    return
  end
  local delay = 0
  if math.abs(newPos.x - oldPos.x) >= 3 or math.abs(newPos.y - oldPos.y) >= 3 or math.abs(newPos.z - oldPos.z) >= 2 then
    delay = g_settings.getNumber("walkTeleportDelay")
  else
    delay = g_settings.getNumber("walkStairsDelay")
  end

  walkLock = delay > 0 and g_clock.millis() + delay or 0

  nextWalkDir = nil
  g_game.cancelWalkQueue()
end

function onWalkFinish(player)
  lastFinishedStep = g_clock.millis()
  if nextWalkDir ~= nil then
    removeEvent(autoWalkEvent)
    autoWalkEvent = addEvent(function() if nextWalkDir ~= nil then walk(nextWalkDir, 0) end end, false)
  end
end

function onCancelWalk(player)
  nextWalkDir = nil
  g_game.cancelWalkQueue()
  player:lockWalk(50)
end

function walk(dir, ticks)
  ticks = ticks or 0
  local player = g_game.getLocalPlayer()
  local now = g_clock.millis()
  lastManualWalk = now

  if not player or g_game.isDead() or player:isDead() then
    return false
  end

  if player:isWalkLocked() then
    nextWalkDir = nil
    return false
  end

  if now <= walkLock then
    nextWalkDir = nil
    return false
  end

  if firstStep and lastWalkDir == dir and now < lastWalk + g_settings.getNumber("walkFirstStepDelay") then
    firstStep = false
    walkLock = lastWalk + g_settings.getNumber("walkFirstStepDelay")
    return false
  end

  local firstStepDelay = g_settings.getNumber("walkFirstStepDelay")
  firstStep = not player:isWalking() and lastFinishedStep + firstStepDelay < now and walkLock + firstStepDelay < now

  removeEvent(autoWalkEvent)
  autoWalkEvent = nil

  if not g_game.walk(dir, true) then
    if player:isWalking() or player:isPreWalking() or player:isServerWalking() then
      nextWalkDir = dir
    else
      nextWalkDir = nil
    end
    return false
  end

  nextWalkDir = nil

  local turnDelay = g_settings.getNumber("walkTurnDelay")
  if turnDelay > 0 and not firstStep and lastWalkDir ~= dir then
    walkLock = now + turnDelay
  end

  lastWalkDir = dir
  lastWalk = now

  return true
end

function turn(dir, repeated)
  local player = g_game.getLocalPlayer()
  if not player then
    return
  end

  removeEvent(walkEvent)
  walkEvent = nil

  nextWalkDir = nil
  stopSmartWalk()

  if player:isWalking() and player:getWalkDirection() == dir and not player:isServerWalking() then
    return
  end

  if not repeated or lastTurn + FastTurnRepeatDelay < g_clock.millis() then
    g_game.turn(dir)

    lastTurn = g_clock.millis()
    lastTurnDirection = dir

    local ctrlTurnDelay = g_settings.getNumber("walkCtrlTurnDelay")
    if ctrlTurnDelay > 0 then
      player:lockWalk(ctrlTurnDelay)
    end
  end
end

function checkTurn()
  for keys, direction in pairs(turnKeys) do
    if g_keyboard.areKeysPressed(keys) then
      turn(direction, false)
    end
  end
end
