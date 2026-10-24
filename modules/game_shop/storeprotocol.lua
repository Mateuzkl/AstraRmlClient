-- Existing RmlClient Shop widgets, original TFS 1.8 Astra Store protocol.
AstraStoreProtocol = {}
local categories, byName, offers = {}, {}, {}
local chunk, timeout, pending = nil, nil, false
local balance = 0

local function send(opcode, write)
  local protocol = g_game.getProtocolGame()
  if not protocol or not g_game.isOnline() then return false end
  local msg = OutputMessage.create()
  msg:addU8(opcode)
  if write then write(msg) end
  protocol:send(msg)
  return true
end

function AstraStoreProtocol.reset()
  removeEvent(timeout); timeout = nil
  categories, byName, offers = {}, {}, {}
  chunk, pending, balance = nil, false, 0
end

local function iconPath(icon)
  if icon and icon ~= '' then
    for _, path in ipairs({icon, '/images/store/'..icon, '/images/game/shop/'..icon,
        '/modules/game_store/images/icons/categories/'..icon,
        '/modules/game_store/images/icons/64/'..icon}) do
      if g_resources.fileExists(path) or g_resources.fileExists(path..'.png') then return path end
    end
  end
  return '/images/store/icon-boxed'
end

local function publish()
  removeEvent(timeout); timeout = nil
  chunk, pending = nil, false
  processCategories(categories)
  onCoinBalance(balance, balance)
end

local function beginCatalog(coins)
  removeEvent(timeout); timeout = nil
  categories, byName, offers = {}, {}, {}
  balance = coins
end

local function readCategory(msg)
  local name, icon = msg:getString(), msg:getString()
  local parent, description = msg:getString(), msg:getString()
  if g_game.getFeature(GameIngameStoreHighlights) then msg:getU8() end
  local category = byName[name]
  if not category then
    local image=iconPath(icon)
    category = {name=name, type='image', image=image, offers={}, indexes={}}
    byName[name] = category; categories[#categories+1] = category
  end
  local count = msg:getU16()
  for i=1,count do
    local id, title, image, price = msg:getU32(), msg:getString(), msg:getString(), msg:getU32()
    local basePrice = g_game.getFeature(GameAstraStoreBasePrice) and msg:getU32() or price
    local eid, amount, detail, subtype = msg:getU16(), msg:getU16(), msg:getString(), msg:getString()
    if g_game.getFeature(GameIngameStoreHighlights) then
      local state = msg:getU8()
      if state==2 or state==3 then msg:getU32() end
    end
    local offer = {id=id, title=title, cost=price, description=detail, count=amount,
      storeSubtype=subtype:lower(), basePrice=basePrice}
    if eid>0 and (offer.storeSubtype=='outfit' or offer.storeSubtype=='mount' or offer.storeSubtype=='hireling') then
      offer.type='outfit'; offer.outfit={type=eid,head=0,body=0,legs=0,feet=0,addons=0}
    elseif eid>0 then
      offer.type='item'; offer.item=eid
    else
      offer.type='image'; offer.image=iconPath(image)
    end
    local index=category.indexes[id]
    if not index then index=#category.offers+1; category.indexes[id]=index end
    category.offers[index]=offer; offers[id]=offer
  end
end

local function readBanners(msg)
  for i=1,msg:getU8() do msg:getString(); msg:getU8(); msg:getU32() end
  msg:getU8() -- banner rotation interval; layout remains the client's existing Shop.
end

local function fail(message)
  AstraStoreProtocol.reset()
  onStoreError(0,message)
end

function AstraStoreProtocol.receive(protocol, msg)
  local response=msg:getU8()
  if response==0 then
    removeEvent(timeout); timeout=nil
    pending=false
    onStoreError(0,msg:getString())
  elseif response==1 then
    local coins,count=msg:getU32(),msg:getU16()
    beginCatalog(coins)
    for i=1,count do readCategory(msg) end
    readBanners(msg); publish()
  elseif response==4 then
    local flags,coins,total,parts=msg:getU8(),msg:getU32(),msg:getU16(),msg:getU16()
    if flags>3 then msg:skipBytes(msg:getUnreadSize()); fail('Invalid Store catalog flags.'); return true end
    if flags==1 or flags==3 then
      if chunk then msg:skipBytes(msg:getUnreadSize()); fail('Invalid Store catalog sequence.'); return true end
      beginCatalog(coins); chunk={coins=coins,total=total}
    elseif not chunk or chunk.coins~=coins or chunk.total~=total then
      msg:skipBytes(msg:getUnreadSize()); fail('Invalid Store catalog sequence.'); return true
    end
    for i=1,parts do readCategory(msg) end
    removeEvent(timeout)
    if flags==2 or flags==3 then
      readBanners(msg)
      if #categories~=total then fail('Incomplete Store catalog. Reopen the Store.')
      else publish() end
    else
      timeout=scheduleEvent(function() fail('Store catalog timed out. Reopen the Store.') end,10000)
    end
  elseif response==2 then
    msg:getU32() -- confirmed offer ID
    local message=msg:getString()
    balance=msg:getU32()
    onCoinBalance(balance,balance)
    onStorePurchase(message)
    -- Refresh actual offers/prices only after the server confirms the purchase.
    pending=false
  elseif response==3 then
    local history={}
    for i=1,msg:getU16() do
      local date,price,positive=msg:getString(),msg:getU32(),msg:getU8()~=0
      msg:getU8() -- secondary currency
      local title,count=msg:getString(),msg:getU16()
      history[#history+1]={id=i,type='image',image='/images/store/icon-boxed',
        title=title,cost=positive and price or -price,description=date..' - '..title,count=count}
    end
    processHistory(history)
  else
    msg:skipBytes(msg:getUnreadSize()); fail('Unsupported Store response.')
  end
  return true
end

function AstraStoreProtocol.open()
  if pending then return false end
  pending=send(0xFB)
  if pending then
    timeout=scheduleEvent(function() fail('Store catalog timed out. Reopen the Store.') end,10000)
  end
  return pending
end

function AstraStoreProtocol.history() return send(0xFA) end

function AstraStoreProtocol.buy(id, name, sex)
  local offer=offers[id]
  if not offer then onStoreError(0,'This offer is no longer available. Reopen the Store.'); return false end
  return send(0xFC,function(msg)
    msg:addU32(id)
    if offer.storeSubtype=='changename' then msg:addString(name or '')
    elseif offer.storeSubtype=='hireling' then msg:addString(name or ''); msg:addU8(sex or 1) end
  end)
end

function AstraStoreProtocol.transfer(recipient, amount)
  if type(recipient)~='string' or recipient=='' or type(amount)~='number' or amount<1 or amount%1~=0 then return false end
  return send(0xF8,function(msg) msg:addString(recipient); msg:addU32(amount) end)
end

function AstraStoreProtocol.init()
  ProtocolGame.registerOpcode(0xFD,AstraStoreProtocol.receive)
  connect(g_game,{onGameEnd=AstraStoreProtocol.reset})
end

function AstraStoreProtocol.terminate()
  disconnect(g_game,{onGameEnd=AstraStoreProtocol.reset})
  ProtocolGame.unregisterOpcode(0xFD)
  AstraStoreProtocol.reset()
end
