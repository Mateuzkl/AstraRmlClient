-- Astra Prey dialog, normal protocol packets and controls; no live game actions.
return function(check, input, done)
  local prey = getfenv(modules.game_prey.show)
  local protocol = ProtocolGame.create()
  local original = {request = g_game.preyRequest, action = g_game.preyAction,
    online = g_game.isOnline, player = g_game.getLocalPlayer}
  local requests, actions = 0, {}
  g_game.preyRequest = function() requests = requests + 1 end
  g_game.preyAction = function(slot, action, index) actions[#actions + 1] = {slot, action, index} end
  g_game.isOnline = function() return true end
  g_game.getLocalPlayer = function()
    return {getPosition = function() return {x = 100, y = 100, z = 7} end,
      getResourceValue = function(_, resource)
      if resource == ResourceBank then return 20000 end
      if resource == ResourceInventary then return 5000 end
      if resource == ResourcePreyBonus then return 12 end
      return 0
    end}
  end
  local function receive(opcode, writer)
    local message = input(function(msg) writer(msg); msg:addU8(0x1E) end)
    check(protocol:onOpcode(opcode, message), 'Astra Prey owns opcode ' .. opcode)
    check(message:getU8() == 0x1E and message:eof(), 'Prey packet ends before the next opcode')
  end
  local function outfit(msg)
    msg:addU16(128)
    for _ = 1, 5 do msg:addU8(0) end
  end
  g_window.resize({width = 1100, height = 800})
  rootWidget:setSize({width = 1100, height = 800})
  modules.game_interface.getRootPanel():show()
  prey.check()
  check(rootWidget:recursiveGetChildById('preyButton') ~= nil, 'Prey Dialog button created')
  check(rootWidget:recursiveGetChildById('preyTrackerButton') ~= nil, 'Prey Tracker button created')
  prey.show()
  check(prey.preyWindow:isVisible() and requests == 1, 'Opening Prey requests current server state')
  check(prey.preyWindow.gold.text:getText():find('25', 1, true), 'Resource balances populated from player')
  receive(0xE9, function(msg) msg:addU32(15000) end)
  receive(0xE8, function(msg)
    msg:addU8(2); msg:addU8(0); msg:addU8(1); msg:addU16(0); msg:addU8(0); msg:addU32(900)
  end)
  check(prey.preyWindow.slot3.locked:isVisible() and prey.preyWindow.slot3.permanentPrice == 900,
    'Permanent slot state and price come from the server')
  receive(0xE8, function(msg) msg:addU8(1); msg:addU8(1); msg:addU16(0); msg:addU8(0) end)
  check(prey.preyWindow.slot2.inactive:isVisible(), 'Inactive slot rendered')
  receive(0xE8, function(msg)
    msg:addU8(0); msg:addU8(3); msg:addU8(9)
    for i = 1, 9 do msg:addString('Fixture Monster ' .. i); outfit(msg) end
    msg:addU16(0); msg:addU8(0)
  end)
  local selection = prey.preyWindow.slot1.select
  check(selection:isVisible() and selection.list:getChildCount() == 9, 'Nine server-provided choices displayed')
  selection.list:focusChild(selection.list:getFirstChild())
  selection.buttonsPanel.choose.button.choosePreyButton.onClick()
  local action = actions[#actions]
  check(action and action[1] == 0 and action[2] == 2 and action[3] == 0, 'Selection uses native zero-based slot and index')
  receive(0xE8, function(msg)
    msg:addU8(0); msg:addU8(2); msg:addString('Fixture Monster 1'); outfit(msg)
    msg:addU8(2); msg:addU16(20); msg:addU8(5); msg:addU16(7200); msg:addU16(0); msg:addU8(2)
  end)
  prey.toggleTracker()
  check(prey.preyTracker:isVisible() and prey.preyTracker:getParent(), 'Tracker docks in the RmlClient side panel')
  receive(0xE8, function(msg)
    msg:addU8(1); msg:addU8(6); msg:addU16(30)
    for i = 1, 30 do msg:addU16(500 + i); msg:addString(string.format('Monster %02d', i)); outfit(msg) end
    msg:addU16(0); msg:addU8(0)
  end)
  local wildcard = prey.preyWindow.slot2.wildcard
  check(wildcard:isVisible() and wildcard.monsterList:getChildCount() == 11, 'Wildcard list uses virtualized rows')
  wildcard.searchText:setText('Monster 20')
  local found = wildcard.monsterList:getFirstChild()
  check(found and found:getText():find('Monster 20', 1, true), 'Wildcard search uses server-provided names')
  wildcard.monsterList:focusChild(found)
  wildcard.choose.button.choosePreyButton.onClick()
  action = actions[#actions]
  check(action[1] == 1 and action[2] == 4 and action[3] == 520, 'Wildcard choice sends race ID rather than row index')
  prey.onResourceBalance(ResourcePreyBonus, 15)
  check(prey.preyWindow.wildCards.text:getText() == '15', 'Resource packet updates Wildcards')
  check(type(prey.preyWindow.gold.text:getTooltip()) == 'string', 'Gold tooltip works with current UI implementation')
  prey.onHover(selection.buttonsPanel.choose.button.choosePreyButton)

  -- Capture the actual renderer output for visual review, in the test profile.
  prey.preyWindow:breakAnchors()
  prey.preyWindow:setPosition({x = 24, y = 24})
  -- A hidden client may still hold its startup draw queue. First flush that
  -- frame, then capture the fresh Prey UI without opening a visible window.
  g_app.doScreenshot('prey-warmup.png')
  scheduleEvent(function() g_app.doScreenshot('prey-port.png') end, 300)
  scheduleEvent(function()
    check(prey.preyWindow.slot1.active:isVisible(), 'Active slot remains stable after deferred callbacks')
    check(prey.preyTracker.contentsPanel.slot1.creatureName:getText():find('Fixture', 1, true), 'Tracker shows the active creature')
    check(prey.preyWindow.slot1.active.creatureAndBonus.timeLeft:getPercent() == 100, 'Full active duration drawn')
    prey.onPreyTimeLeft(0, 3600)
    check(prey.preyWindow.slot1.active.creatureAndBonus.timeLeft:getPercent() == 50 and
      prey.preyTracker.contentsPanel.slot1.time:getPercent() == 50, 'Live duration updates dialog and tracker')
    print('PREY_RENDER_PATH: ' .. g_resources.getWriteDir() .. 'prey-port.png')
    prey.hide()
    check(not prey.preyWindow:isVisible() and not prey.preyTracker:isVisible(), 'Close/logout clears both windows')
    g_game.preyRequest, g_game.preyAction = original.request, original.action
    g_game.isOnline, g_game.getLocalPlayer = original.online, original.player
    done()
  end, 1200)
end
