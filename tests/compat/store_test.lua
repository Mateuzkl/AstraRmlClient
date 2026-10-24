-- Native message readers and existing Shop UI, with mocked outbound transport.
-- No purchase, transfer or login reaches a server.
return function(check, input)
  local shop = getfenv(modules.game_shop.init)
  local adapter = shop.AstraStoreProtocol
  local protocol = ProtocolGame.create()
  local originalOnline, originalProtocol = g_game.isOnline, g_game.getProtocolGame
  local basePrices = g_game.getFeature(GameAstraStoreBasePrice)
  local sent = {}
  g_game.isOnline = function() return true end
  g_game.getProtocolGame = function()
    return {send = function(_, message) sent[#sent + 1] = message:getBuffer() end,
      sendExtendedOpcode = function() error('Store must use normal opcodes') end,
      sendExtendedJSONOpcode = function() error('Store must not send JSON opcode 201') end}
  end
  local function lastRequest()
    local message = InputMessage.create()
    message:setBuffer(sent[#sent])
    return message
  end
  local function receive(writer)
    local message = input(writer)
    check(protocol:onOpcode(0xFD, message), 'Astra handler owns opcode 0xFD before the legacy C++ parser')
    check(message:getU8() == 0xA5 and message:eof(), 'Store response leaves the following opcode untouched')
  end
  local function offer(msg, id, subtype)
    msg:addU32(id); msg:addString('Fixture ' .. id); msg:addString(''); msg:addU32(100)
    if g_game.getFeature(GameAstraStoreBasePrice) then msg:addU32(150) end
    msg:addU16(subtype == 'item' and 3031 or 0); msg:addU16(1)
    msg:addString('Offline fixture'); msg:addString(subtype)
    msg:addU8(0) -- highlight state
  end
  local function category(msg, id, count)
    msg:addString('Items'); msg:addString(''); msg:addString(''); msg:addString('Offline category')
    msg:addU8(0); msg:addU16(count)
    for i = 1, count do offer(msg, id + i - 1, i == 2 and 'changename' or 'item') end
  end
  adapter.reset()
  shop.show()
  local request = lastRequest()
  check(request:getU8() == 0xFB and request:eof(), 'Catalog request matches original TFS: opcode only')

  for _, extended in ipairs({false, true}) do
    if extended then g_game.enableFeature(GameAstraStoreBasePrice)
    else g_game.disableFeature(GameAstraStoreBasePrice) end
    receive(function(msg)
      msg:addU8(1); msg:addU32(1234); msg:addU16(1)
      category(msg, 101, 2)
      msg:addU8(0); msg:addU8(10); msg:addU8(0xA5)
    end)
    local selected = shop.shop.categories:getChildByIndex(1)
    shop.changeCategory(nil, selected)
    check(shop.shop.categories:getChildCount() == 1 and shop.shop.offers:getChildCount() == 2,
      'Full catalog populates the existing UI; base-price extension = ' .. tostring(extended))
    check(shop.shop.infoPanel.points:getText():find('1234', 1, true), 'Balance displayed from server catalog')
  end

  local before = #sent
  shop.showHistory()
  request = lastRequest()
  check(#sent == before + 1 and request:getU8() == 0xFA and request:eof(), 'History request matches original TFS')
  receive(function(msg)
    msg:addU8(3); msg:addU16(1); msg:addString('2026-10-24 12:00:00')
    msg:addU32(125); msg:addU8(1); msg:addU8(0); msg:addString('History Fixture'); msg:addU16(2)
    msg:addU8(0xA5)
  end)
  check(shop.shop.offers:getChildCount() == 1, 'TFS history is displayed in the current Shop layout')
  check(#sent == before + 1, 'Rendering history does not request it again')

  -- Replay the actual failing body locally when packet.log is available.
  -- Production packet logs are never added to the repository.
  if g_resources.fileExists('/captured-packet.log') then
    local captured = g_resources.readFileContents('/captured-packet.log')
    local bytes = captured:match('\n(fd [^\r\n]+)')
    if bytes then
      bytes = bytes:gsub('(%x%x)%s*', function(hex) return string.char(tonumber(hex, 16)) end)
      local message = InputMessage.create()
      message:setBuffer(bytes)
      check(message:getU8() == 0xFD, 'Captured failing Store response selected')
      check(protocol:onOpcode(0xFD, message) and message:eof(), 'Captured history fully decoded without EOF')
      check(shop.shop.offers:getChildCount() > 0, 'Captured history reaches the existing UI')
    end
  end

  adapter.reset()
  receive(function(msg)
    msg:addU8(4); msg:addU8(1); msg:addU32(77); msg:addU16(1); msg:addU16(1)
    category(msg, 201, 1); msg:addU8(0xA5)
  end)
  receive(function(msg)
    msg:addU8(4); msg:addU8(2); msg:addU32(77); msg:addU16(1); msg:addU16(1)
    category(msg, 202, 1); msg:addU8(0); msg:addU8(10); msg:addU8(0xA5)
  end)
  shop.changeCategory(nil, shop.shop.categories:getChildByIndex(1))
  check(shop.shop.offers:getChildCount() == 2, 'Chunked catalog merges category parts')
  check(adapter.buy(201), 'Known offer can construct an offline purchase request')
  request = lastRequest()
  check(request:getU8() == 0xFC and request:getU32() == 201 and request:eof(), 'Purchase request has exact TFS fields')
  check(adapter.transfer('Offline Fixture', 25), 'Transfer request constructed offline')
  request = lastRequest()
  check(request:getU8() == 0xF8 and request:getString() == 'Offline Fixture' and request:getU32() == 25 and request:eof(),
    'Transfer request has exact TFS fields')
  receive(function(msg)
    msg:addU8(2); msg:addU32(201); msg:addString('Offline success'); msg:addU32(66); msg:addU8(0xA5)
  end)
  check(shop.shop.infoPanel.points:getText():find('66', 1, true), 'Confirmed purchase updates balance')
  receive(function(msg) msg:addU8(0); msg:addString('Offline error'); msg:addU8(0xA5) end)

  adapter.reset()
  shop.hide()
  if shop.msgWindow then shop.msgWindow:destroy() end
  if basePrices then g_game.enableFeature(GameAstraStoreBasePrice)
  else g_game.disableFeature(GameAstraStoreBasePrice) end
  g_game.isOnline, g_game.getProtocolGame = originalOnline, originalProtocol
end
