-- Offline fixtures against the user's existing RmlUi executable. No live login.
local checks = 0
local function check(ok, why)
  checks = checks + 1
  assert(ok, why)
end

local function input(writer)
  local output = OutputMessage.create()
  writer(output)
  local message = InputMessage.create()
  message:setBuffer(output:getBuffer())
  return message
end

local function run()
  g_modules.ensureModuleLoaded('game_features')
  g_modules.ensureModuleLoaded('game_things')
  g_game.setProtocolVersion(860)
  g_game.setClientVersion(860)
  check(modules.game_things.isLoaded(), 'Native 8.60 DAT/SPR load')
  check(GameColorizedLootValue == 121 and GameNewCreatureStacking == 136, 'Lua feature IDs match Astra SRC')
  for _, feature in ipairs({GameNegativeOffset, GameMagicEffectU16, GameDistanceEffectU16,
      GameDoubleHealth, GameExtendedOpcode, GamePlayerFamiliars, GameSpritesU32}) do
    check(g_game.getFeature(feature), 'Astra 8.60 feature enabled: ' .. feature)
  end
  for _, feature in ipairs({GameNewWalking, GameNewSpeedLaw, GameItemTierByte, GameShopCountU16}) do
    check(not g_game.getFeature(feature), 'Negotiated or incompatible feature not forced: ' .. feature)
  end
  check(g_rml and g_rml.isReady(), 'Existing RmlUi runtime remains ready')
  check(not g_modules.getModule('game_maptracker'), 'MapTracker is outside module discovery')
  check(not g_modules.getModule('cavebot_mod'), 'Legacy Waypoints bot removed')
  check(not g_modules.getModule('scriptsManager-mod'), 'Scripts Manager removed')
  g_modules.ensureModuleLoaded('game_bot')
  check(g_modules.getModule('game_bot'):isLoaded(), 'Requested game_bot remains loaded')
  check(USE_OTCV8_JSON_SHOP == false, 'Original TFS uses native Store')

  -- Enter the actual native HTTP binding: its fourth argument must be a map.
  local operation = HTTP.postJSON('http://127.0.0.1:1/compat', {offline = true}, function() end)
  check(type(operation) == 'number', 'Native HTTP.postJSON accepts header map')
  HTTP.cancel(operation)
  local called = false
  HTTP.operations[90001] = {json = true, callback = function(data, err)
    check(not err and data.answer == 42, 'HttpResult JSON response decoded')
    called = true
  end}
  HTTP.onPost(90001, '', '', {status = 200, headers = {}, body = '{"answer":42}'})
  check(called and not HTTP.operations[90001], 'Terminal HTTP callback released')
  HTTP.operations[90002] = {callback = function(data, err)
    check(not err and data == 'plain body', 'Non-JSON HttpResult body decoded')
  end}
  HTTP.onGet(90002, '', '', {body = 'plain body'})
  HTTP.operations[90003] = {json = true, callback = function(data, err)
    check(not err and data.legacy == true, 'Legacy string response remains supported')
  end}
  HTTP.onGet(90003, '', '', '{"legacy":true}')

  local originalPost, statsUrl = HTTP.postJSON, Services.stats
  local statsSent = 0
  HTTP.postJSON = function(url, data)
    check(url == 'http://127.0.0.1:1/stats' and type(data) == 'table', 'Stats use the compatible HTTP JSON wrapper')
    statsSent = statsSent + 1
  end
  Services.stats = ''
  modules.client_stats.sendStats()
  check(statsSent == 0, 'Disabled statistics send nothing to the old OTCv8 endpoint')
  Services.stats = 'http://127.0.0.1:1/stats'
  modules.client_stats.sendStats()
  check(statsSent == 1, 'Statistics only use the explicitly configured endpoint')
  HTTP.postJSON, Services.stats = originalPost, statsUrl

  -- Use real native message readers for Astra capabilities and character data.
  local login = ProtocolLogin.create()
  login:parseAstraCapabilities(input(function(msg) msg:addU8(1); msg:addU8(1) end))
  local charactersReceived = false
  login.onCharacterList = function(_, characters, account)
    check(#characters == 1 and characters[1].name == 'Compat Fixture', 'Astra character name')
    check(characters[1].outfit.type == 128 and characters[1].level == 450, 'Outfit and level stay aligned')
    check(characters[1].vocation == 'Knight' and characters[1].dailyRewardState == true, 'Vocation and negotiated daily state')
    check(account.premDays == 7, 'Premium trailer stays aligned')
    charactersReceived = true
  end
  local list = input(function(msg)
    msg:addU8(1); msg:addString('Compat Fixture'); msg:addString('Offline World')
    msg:addU32(0x0100007F); msg:addU16(7172); msg:addU16(128)
    for color = 1, 5 do msg:addU8(color) end
    msg:addU32(450); msg:addString('Knight'); msg:addU8(0); msg:addU16(7)
    msg:addU8(0xA1); msg:addU8(0); msg:addU8(0)
  end)
  login:parseExtendedCharacterList(list)
  check(charactersReceived and list:eof(), 'Character packet completely consumed')

  -- modules.* is a read proxy; mutate the sandbox used by these callbacks.
  local walk = getfenv(modules.game_walking.walk)
  local original = {walk = g_game.walk, player = g_game.getLocalPlayer, dead = g_game.isDead,
    cancel = g_game.cancelWalkQueue, turn = g_game.turn, modifiers = g_keyboard.getModifiers,
    online = g_game.isOnline, protocol = g_game.getProtocolGame}
  local sent, cancelled, turned, locked = 0, 0, 0, 0
  local walking = false
  local player = {isDead = function() return false end, isWalkLocked = function() return false end,
    isWalking = function() return walking end, isPreWalking = function() return false end,
    isServerWalking = function() return false end, getWalkDirection = function() return North end,
    lockWalk = function(_, delay) locked = delay end,
    preWalk = function() error('Lua must not duplicate native prewalking') end}
  g_game.getLocalPlayer = function() return player end
  g_game.isDead = function() return false end
  g_game.walk = function(dir, keyDown)
    check(keyDown == true, 'Native engine owns keyboard prewalking')
    sent = sent + 1
    return true
  end
  g_game.cancelWalkQueue = function() cancelled = cancelled + 1 end
  g_game.turn = function() turned = turned + 1 end
  g_keyboard.getModifiers = function() return KeyboardNoModifier end
  for _, dir in ipairs({North, South, East, West, NorthEast, SouthEast, SouthWest, NorthWest}) do
    walk.firstStep = false; walk.walkLock = 0
    local before = sent
    check(walk.walk(dir, 0) and sent == before + 1, 'One dispatch per input direction: ' .. dir)
  end
  walk.changeWalkDir(North)
  walk.smartWalk(North, 0)
  walk.changeWalkDir(North, true)
  check(walk.smartWalkDir == nil and walk.nextWalkDir == nil and cancelled > 0, 'Key release clears queues')
  walk.turn(East, false)
  check(turned == 1, 'Ctrl turn sends a turn without an extra step')
  walk.onCancelWalk(player)
  check(locked == 50 and walk.nextWalkDir == nil, 'Server cancel recovers and clears pending steps')
  walk.nextWalkDir = West
  walk.onTeleport(player, {x = 100, y = 100, z = 7}, {x = 1, y = 1, z = 7})
  check(walk.nextWalkDir == nil, 'Teleport clears pending direction')
  g_game.isOnline = function() return true end
  g_game.getProtocolGame = function() error('Native TFS must not query JSON opcode 201') end
  modules.game_shop.check()
  check(true, 'Store login handler sends no unsupported opcode 201')
  g_game.walk, g_game.getLocalPlayer, g_game.isDead = original.walk, original.player, original.dead
  g_game.cancelWalkQueue, g_game.turn, g_keyboard.getModifiers = original.cancel, original.turn, original.modifiers
  g_game.isOnline, g_game.getProtocolGame = original.online, original.protocol

  local storeTest = assert(loadstring(g_resources.readFileContents('/tests/compat/store_test.lua'), '@store_test.lua'))()
  storeTest(check, input)
  print('ASTRA_RML_COMPAT_PASS: ' .. checks .. ' checks; startup, HTTP, login, features, DAT/SPR, RmlUi, walk and Store guard')
  g_app.exit()
end

-- Let deferred option setup and UI callbacks run before asserting success.
scheduleEvent(run, 1500)
