buttonsWindow = nil
contentsPanel = nil
local layoutEvent = nil
local BUTTON_SIZE = 24
local BUTTON_SPACING = 2
local PANEL_MARGIN = 6

local function requestLayout()
  if layoutEvent or not buttonsWindow or buttonsWindow:isDestroyed() then return end
  layoutEvent = addEvent(function()
    layoutEvent = nil
    updateOrder()
  end)
end

function init()
  buttonsWindow = g_ui.loadUI('buttons', modules.game_interface.getRightPanel())
  buttonsWindow:disableResize()
  buttonsWindow:setup()
  contentsPanel = buttonsWindow.contentsPanel
  if contentsPanel.buttons then
    connect(contentsPanel.buttons, {onGeometryChange = requestLayout})
  end
  if not buttonsWindow.forceOpen or not contentsPanel.buttons then
    buttonsWindow:close()
  end
end

function terminate()
  removeEvent(layoutEvent)
  layoutEvent = nil
  local window = buttonsWindow
  buttonsWindow, contentsPanel = nil, nil
  if window then window:destroy() end
end

function takeButtons(buttons)
  if not buttonsWindow.forceOpen or not contentsPanel.buttons then return end
  for i, button in ipairs(buttons) do
    takeButton(button, true)
  end
  updateOrder()
end

function takeButton(button, dontUpdateOrder)
  if not buttonsWindow.forceOpen or not contentsPanel.buttons then return end
  local layout = contentsPanel.buttons:getLayout()
  layout:disableUpdates()
  button:setParent(contentsPanel.buttons)
  if not button.astraToolbarManaged then
    button:setStyle(button.astraToolbarStyle or 'GameToolbarSpriteButton')
    if button.astraToolbarIconRect then button:setIconRect(button.astraToolbarIconRect) end
    if button.astraToolbarIconClip then button:setIconClip(button.astraToolbarIconClip) end
    button.astraToolbarManaged = true
    connect(button, {onVisibilityChange = requestLayout, onDestroy = requestLayout})
  end
  layout:enableUpdates()
  if not dontUpdateOrder then
    updateOrder()
  end
end

function updateOrder()
   if not buttonsWindow or buttonsWindow:isDestroyed() or not contentsPanel or not contentsPanel.buttons then return end
   local panel = contentsPanel.buttons
   local children = panel:getChildren()
   table.sort(children, function(a, b)
    local left, right = a.index or 1000, b.index or 1000
    if left == right then return a:getId() < b:getId() end
    return left < right
   end)
   local visibleCount = 0
   for _, child in ipairs(children) do
    if child:isExplicitlyVisible() then
      visibleCount = visibleCount + 1
    end
   end
   local columns = math.max(1, math.floor((panel:getWidth() + BUTTON_SPACING) / (BUTTON_SIZE + BUTTON_SPACING)))
   local rows = math.max(1, math.ceil(visibleCount / columns))
   local layout = panel:getLayout()
   layout:disableUpdates()
   local height = PANEL_MARGIN + rows * BUTTON_SIZE + (rows - 1) * BUTTON_SPACING
   -- Automatic toolbar sizing is not a user resize: avoid saving a fixed height
   -- or recursively fitting/minimizing sibling miniwindows in a crowded panel.
   if buttonsWindow:getHeight() ~= height then UIWidget.setHeight(buttonsWindow, height) end
   buttonsWindow:getLayout():update()
   contentsPanel:getLayout():update()
   panel:reorderChildren(children)
   layout:enableUpdates()
   layout:update()
end
