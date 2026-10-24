local checks = 0
local function check(ok, why) checks = checks + 1; assert(ok, why) end
local function pngSize(path)
  local data = g_resources.readFileContents(path:match('%.png$') and path or path .. '.png')
  local function u32(offset)
    local a,b,c,d = data:byte(offset, offset + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end
local function run()
  check(g_resources.getWriteDir():find('astra_rml_compat_test', 1, true), 'Isolated test profile')
  g_game.setProtocolVersion(860); g_game.setClientVersion(860)
  g_window.resize({width=1100,height=800}); rootWidget:setSize({width=1100,height=800})
  local bar, menu = modules.game_buttons, modules.client_topmenu
  modules.game_interface.getRootPanel():show()
  modules.game_prey.check()
  menu.showGameButtons()
  local window, panel = bar.buttonsWindow, bar.contentsPanel.buttons
  check(window.forceOpen and panel, 'Retro toolbar available')
  for _, button in ipairs(panel:getChildren()) do button:show() end
  local clicked = 0
  local probe = menu.addRightGameToggleButton('toolbarProbe', 'Offline click test', '/modules/game_buttons/images/bot',
    function() clicked = clicked + 1 end, false, 100001)
  probe:show()
  window:setParent(rootWidget); window:breakAnchors(); window:setPosition({x=16,y=16}); window:setWidth(190)
  bar.updateOrder()
  local function validate()
    local visible = {}
    for _, child in ipairs(panel:getChildren()) do
      if child:isExplicitlyVisible() then visible[#visible + 1] = child end
    end
    local columns = math.max(1, math.floor((panel:getWidth() + 2) / 26))
    local rows = math.max(1, math.ceil(#visible / columns))
    check(window:getHeight() == 6 + rows * 24 + (rows - 1) * 2, 'Window fits all visible rows')
    local p = panel:getRect()
    for i, button in ipairs(visible) do
      local r = button:getRect()
      check(r.width == 24 and r.height == 24, 'Uniform hitbox: ' .. button:getId())
      check(r.x == p.x + ((i - 1) % columns) * 26 and r.y == p.y + math.floor((i - 1) / columns) * 26,
        'Aligned grid: ' .. button:getId())
      check(r.x >= p.x and r.y >= p.y and r.x + r.width <= p.x + p.width and r.y + r.height <= p.y + p.height,
        'Unclipped button: ' .. button:getId())
      local icon = button:getIconRect()
      check(icon.x >= 0 and icon.y >= 0 and icon.x + icon.width <= 24 and icon.y + icon.height <= 24,
        'Icon fits hitbox: ' .. button:getId())
      local w,h = pngSize(button:getIconPath())
      local old = button:isOn()
      for _, on in ipairs({false,true}) do
        button:setOn(on)
        local clip = button:getIconClip()
        check(clip.x >= 0 and clip.y >= 0 and clip.x + clip.width <= w and clip.y + clip.height <= h,
          'Off/On sprite bounds: ' .. button:getId())
      end
      button:setOn(old)
    end
    return #visible
  end
  scheduleEvent(function()
    local count = validate()
    local point = probe:getPosition(); point.x=point.x+3; point.y=point.y+3
    probe.onMouseRelease(probe,point,MouseLeftButton)
    check(clicked == 1, 'Click callback retained')
    probe.onMouseRelease(probe,point,MouseMidButton)
    check(clicked == 1, 'Middle click ignored')
    window:setWidth(160)
    scheduleEvent(function()
      validate(); window:setWidth(250)
      scheduleEvent(function()
        validate(); probe:hide()
        scheduleEvent(function()
          check(validate() == count - 1, 'Hidden buttons trigger relayout')
          probe:destroy(); window:setWidth(190)
          scheduleEvent(function()
            validate()
            for _, button in ipairs(panel:getChildren()) do button:setOn(false) end
            g_app.doScreenshot('toolbar-warmup.png')
            scheduleEvent(function() g_app.doScreenshot('toolbar-aligned.png') end,300)
            scheduleEvent(function()
              print('TOOLBAR_RENDER_PATH: ' .. g_resources.getWriteDir() .. 'toolbar-aligned.png')
              print('ASTRA_TOOLBAR_PASS: ' .. checks .. ' layout, frame, state and callback checks')
              g_app.exit()
            end,1000)
          end,80)
        end,80)
      end,80)
    end,80)
  end,100)
end
scheduleEvent(run,500)
