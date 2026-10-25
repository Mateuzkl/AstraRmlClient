-- Keep the showcase and Ctrl+Shift+O entry points on the real options window.
function toggle()
  modules.client_options.toggle()
end

function init()
  g_keyboard.bindKeyDown('Ctrl+Shift+O', toggle)
end

function terminate()
  g_keyboard.unbindKeyDown('Ctrl+Shift+O', toggle)
end
