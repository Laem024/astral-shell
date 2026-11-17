local loader = "config/hyprland/modules/astral-settings.lua"
local actual_loadfile = loadfile
local calls = 0
hl = {config=function() calls=calls+1 end, monitor=function() calls=calls+1 end}
local function base()
  return {version=1,input={kb_layout="us",touchpad={["tap-to-click"]=true}},monitors={},colors={cyan="7FD0BF",lavender="A9B5D9",muted="8D9994",shadow="0E1113"}}
end
local function run(data, expected)
  calls=0
  loadfile=function(path, mode, environment)
    assert(path:match("/astral%-shell/astral%-settings/overrides.lua$"))
    assert(mode=="t" and next(environment)==nil)
    return function() return data end
  end
  assert(actual_loadfile(loader))()
  assert(calls==expected, "Unexpected compositor calls: "..calls)
end
run(base(),1)
local value=base(); value.input.exec="untrusted"; run(value,0)
value=base(); value.colors.cyan="not hex"; run(value,0)
value=base(); value.version=2; run(value,0)
value=base(); value.input.sensitivity=2; run(value,0)
value=base(); value.monitors={{output="DP-1",disabled=true,mode="preferred",scale=1,position="0x0",transform=0,mirror="",bitdepth=8,vrr=0,cm="srgb"}}; run(value,0)
value.monitors[1].disabled=false; run(value,2)
value.monitors[1].supports_hdr=1; run(value,0)
value=base(); value.input.kb_layout="us\nexec"; run(value,0)
loadfile=function() return nil,"missing/corrupt file" end
calls=0; assert(actual_loadfile(loader))(); assert(calls==0)
loadfile=actual_loadfile
print("ASTRAL_SETTINGS_LOADER_PASS")
