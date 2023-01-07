local ffi = require "ffi"
local bit = require "bit"
local utf8 = require "utf8"
local ultralove = require "ul"
local ul = ultralove.ultralight
local wc = ultralove.webcore
local ulc = ultralove.core
local ac = ultralove.appcore
local kc = ultralove.keycodes
local renderer, view

js_func = function(ctx, func, this, args_n, args, except)
  local str = wc.JSStringCreateWithUTF8CString "Hello from Love2D!"

  print "Called from JS!"

  local bal = wc.JSValueMakeString(ctx, str)
  wc.JSStringRelease(str)

  return bal
end
js_func_c = ffi.new("JSObjectCallAsFunctionCallback", js_func)

ready = function(data, caller, frame_id, is_main, url)
  print "DOM ready"

  local ctx = ul.ulViewLockJSContext(view)

  local name = wc.JSStringCreateWithUTF8CString "js_func"

  local func = wc.JSObjectMakeFunctionWithCallback(ctx, name, js_func_c)

  wc.JSObjectSetProperty(ctx, wc.JSContextGetGlobalObject(ctx), name, func, 0, ffi.new "void*")

  wc.JSStringRelease(name)

  ul.ulViewUnlockJSContext(view)
end
ready_c = ffi.new("ULDOMReadyCallback", ready)

love.load = function()
  love.keyboard.setKeyRepeat(true)

  local conf = ul.ulCreateConfig()

  local resource_path = ul.ulCreateString("./resources/")
  ul.ulConfigSetResourcePath(conf, resource_path)
  ul.ulDestroyString(resource_path)
  ul.ulConfigSetUseGPURenderer(conf, false)

  ac.ulEnablePlatformFontLoader()
  local log_path = ul.ulCreateString("./log/ul.log")
  ac.ulEnableDefaultLogger(log_path)
  ul.ulDestroyString(log_path)
  local fs_path = ul.ulCreateString(love.filesystem.getSaveDirectory())
  ac.ulEnablePlatformFileSystem(fs_path)
  ul.ulDestroyString(fs_path)

  renderer = ul.ulCreateRenderer(conf)

  ul.ulDestroyConfig(conf)

  view = ul.ulCreateView(renderer, 500, 500, false, nil, false)

  ul.ulViewSetDOMReadyCallback(view, ready_c, ffi.new "void*")

  local html = ul.ulCreateString[[
<html>
<head>
<script>
var setted = false;

function test() {
  var title = document.getElementById("title");
  if (setted) {
    title.innerHTML = js_func();
    setted = false;
  } else {
    title.innerHTML = "Hello, Ultralight!";
    setted = true;
  }
}

function input_test() {
  var desc = document.getElementById("desc");
  var inp = document.getElementById("inp");
  desc.innerHTML = inp.value;
}
</script>
</head>
<body>
<h1 id="title">Hello, Love2D!</h1>
<p id="desc"> Some text under </p>
<marquee>Left</marquee>
<marquee direction="right">Right</marquee>
<button id="btn" onclick="test();">Click me!</button>
<input id="inp" type="text" value="Hello, Ultralight!" oninput="input_test();" />
</body>
</html>    
  ]]
  ul.ulViewLoadHTML(view, html)
  ul.ulViewFocus(view)
  ul.ulDestroyString(html)

  display = love.image.newImageData(500, 500)
end

local ul_to_canvas = function()
  local surface = ul.ulViewGetSurface(view)
  local dirty = ul.ulSurfaceGetDirtyBounds(surface)

  local bitmap_surface = ffi.new("ULBitmapSurface", surface)
  local bitmap = ul.ulBitmapSurfaceGetBitmap(bitmap_surface)

  local pixels = ul.ulBitmapLockPixels(bitmap)

  local width = ul.ulBitmapGetWidth(bitmap)
  local height = ul.ulBitmapGetHeight(bitmap)

  local pixel_data = ffi.cast("uint8_t*", pixels)

  local pixel_data_size = width * height * 4

  ffi.copy(display:getPointer(), pixel_data, pixel_data_size)

  local img = love.graphics.newImage(display)
  love.graphics.draw(img, love.graphics.getWidth() / 2 - 250, love.graphics.getHeight() / 2 - 250)


  ul.ulBitmapUnlockPixels(bitmap)
end

love.update = function(dt)
  ul.ulUpdate(renderer)
end

love.draw = function()
  ul.ulRender(renderer)

  ul_to_canvas()
end

local localize_coords = function(x, y)
  return x - love.graphics.getWidth() / 2 + 250, y - love.graphics.getHeight() / 2 + 250
end

love.mousemoved = function(x, y, dx, dy)
  local lx, ly = localize_coords(x, y)
  local mouse_event = ul.ulCreateMouseEvent(ul.kMouseEventType_MouseMoved, lx, ly, ul.kMouseButton_None)
  ul.ulViewFireMouseEvent(view, mouse_event)
end

love.mousepressed = function(x, y, button, isTouch)
  local mouse_button = ul.kMouseButton_None
  if button == 1 then
    mouse_button = ul.kMouseButton_Left
  elseif button == 2 then
    mouse_button = ul.kMouseButton_Right
  elseif button == 3 then
    mouse_button = ul.kMouseButton_Middle
  end

  local lx, ly = localize_coords(x, y)
  local mouse_event = ul.ulCreateMouseEvent(ul.kMouseEventType_MouseDown, lx, ly, mouse_button)
  ul.ulViewFireMouseEvent(view, mouse_event)
end

love.mousereleased = function(x, y, button, isTouch)
  local mouse_button = ul.kMouseButton_None
  if button == 1 then
    mouse_button = ul.kMouseButton_Left
  elseif button == 2 then
    mouse_button = ul.kMouseButton_Right
  elseif button == 3 then
    mouse_button = ul.kMouseButton_Middle
  end

  local lx, ly = localize_coords(x, y)
  local mouse_event = ul.ulCreateMouseEvent(ul.kMouseEventType_MouseUp, lx, ly, mouse_button)
  ul.ulViewFireMouseEvent(view, mouse_event)
end

love.keypressed = function(key, scancode, isrepeat)
  --local key_event = ul.ulCreateKeyEvent(ul.kKeyEventType_KeyDown, 0, key, 0, 0)
  local key_text = ul.ulCreateString(key)
  local is_keypad = key:sub(1, 2) == "kp"
  local key_event = ul.ulCreateKeyEvent(
    ul.kKeyEventType_RawKeyDown,
    0, kc[key], 0, key_text, key_text, is_keypad, isrepeat, false
  )
  print(key, kc[key])
  ul.ulViewFireKeyEvent(view, key_event)
  ul.ulDestroyString(key_text)
end

love.textinput = function(text)
  print(utf8.len(text))
  local utf8_text = ul.ulCreateStringUTF8(text, #text)
  local key_text = ul.ulCreateString(text)
  local key_event = ul.ulCreateKeyEvent(
    ul.kKeyEventType_Char,
    0, 0, 0, utf8_text, key_text, false, false, false
  )
  ul.ulViewFireKeyEvent(view, key_event)
  ul.ulDestroyString(key_text)
  ul.ulDestroyString(utf8_text)
end
