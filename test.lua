-- working test with Ultralight, AppCore and JavaScript (Sample 6)
local ffi = require "ffiex.init"
local bit = require "bit"
ffi.path "./ul/include"

ffi.cdef [[
#include <Ultralight/CAPI.h>
#include <AppCore/CAPI.h>
#include <JavaScriptCore/JavaScript.h>
]]

local ulc = ffi.load "./ul/bin/libUltralightCore.so"
local ac = ffi.load "./ul/bin/libAppCore.so"
local wc = ffi.load "./ul/bin/libWebCore.so"
local ul = ffi.load "./ul/bin/libUltralight.so"
local nothin = ffi.new"void*"
local app, overlay, window, view

update = function(data)
end
update_c = ffi.new("ULUpdateCallback", update)

resize = function(data, w, h)
  ul.ulOverlayResize(overlay, w, h)
end
resize_c = ffi.new("ULResizeCallback", resize)

js_func = function(ctx, func, this, args_n, args, except)
  local str = wc.JSStringCreateWithUTF8CString "Hello from Lua!"

  print "Called from JS!"

  local bal = wc.JSValueMakeString(ctx, str)
  wc.JSStringRelease(str)

  return bal
end
js_func_c = ffi.new("JSObjectCallAsFunctionCallback", js_func)

ready = function(data, caller, frame_id, is_main, url)
  local ctx = ul.ulViewLockJSContext(view)

  local name = wc.JSStringCreateWithUTF8CString "js_func"

  local func = wc.JSObjectMakeFunctionWithCallback(ctx, name, js_func_c)

  wc.JSObjectSetProperty(ctx, wc.JSContextGetGlobalObject(ctx), name, func, 0, nothin)

  wc.JSStringRelease(name)

  ul.ulViewUnlockJSContext(view)
end
ready_c = ffi.new("ULDOMReadyCallback", ready)

init = function()
  local settings = ac.ulCreateSettings()
  ac.ulSettingsSetForceCPURenderer(settings, true)

  local config = ul.ulCreateConfig()

  app = ac.ulCreateApp(settings, config)

  ac.ulAppSetUpdateCallback(app, update_c, nothin)

  ac.ulDestroySettings(settings)
  ul.ulDestroyConfig(config)

  window = ac.ulCreateWindow(
    ac.ulAppGetMainMonitor(app),
      500, 500, false,
      bit.bor(ac.kWindowFlags_Titled, ac.kWindowFlags_Resizable)
    )

  ac.ulWindowSetTitle(window, "LuaJIT test")

  ac.ulWindowSetResizeCallback(window, resize_c, nothin)

  ac.ulAppSetWindow(app, window)

  overlay = ac.ulCreateOverlay(window, ac.ulWindowGetWidth(window), ac.ulWindowGetHeight(window), 0, 0)

  view = ac.ulOverlayGetView(overlay)

  ul.ulViewSetDOMReadyCallback(view, ready_c, nothin)

  local html = ul.ulCreateString[[
<html>
  <script type="text/javascript">
    function click() {
      document.getElementById("msg").innerHTML = js_func();
    }
  </script>
  </head>
  <body>
    <div id="msg"></div>
    <button id="btn" onclick="click();">Click Me!</button>
  </body>
</html>
]]
  ul.ulViewLoadHTML(view, html)
  ul.ulDestroyString(html)
end

shutdown = function()
  ac.ulDestroyOverlay(overlay)
  ac.ulDestroyWindow(window)
  ac.ulDestroyApp(app)
end

init()

ac.ulAppRun(app)

shutdown()
