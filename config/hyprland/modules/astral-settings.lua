-- Apply only confirmed Astral overrides, after the repository's base modules.
-- A restricted environment makes the managed file a data source, not a config API.
local config = os.getenv("XDG_CONFIG_HOME")
if not config or config:sub(1, 1) ~= "/" then config = (os.getenv("HOME") or "") .. "/.config" end
local chunk = loadfile(config .. "/astral-shell/astral-settings/overrides.lua", "t", {})
if not chunk then return end
local ok, data = pcall(chunk)
if not ok or type(data) ~= "table" or data.version ~= 1 then return end
local function only(value, allowed)
  if type(value) ~= "table" then return false end
  for key in pairs(value) do if not allowed[key] then return false end end
  return true
end
local input_rules = {
  kb_layout="string", kb_variant="string", kb_model="string", kb_options="string",
  repeat_delay={100,2000}, repeat_rate={1,100}, numlock_by_default="boolean",
  sensitivity={-1,1}, accel_profile={flat=true,adaptive=true,[""]=true},
  natural_scroll="boolean", scroll_factor={0.1,10},
}
local touch_rules = {
  natural_scroll="boolean", scroll_factor={0.1,10}, ["tap-to-click"]="boolean",
  clickfinger_behavior="boolean", disable_while_typing="boolean",
}
local function fields(value, rules)
  if not only(value, rules) then return false end
  for key, v in pairs(value) do
    if (key=="repeat_rate" or key=="repeat_delay") and (type(v)~="number" or v%1~=0) then return false end
    local rule=rules[key]
    if type(rule)=="string" then
      if type(v)~=rule or (rule=="string" and (#v>512 or v:find("[%c]"))) then return false end
    elseif rule[1] then
      if type(v)~="number" or v~=v or v<rule[1] or v>rule[2] then return false end
    elseif not rule[v] then return false end
  end
  return true
end
if not only(data,{version=true,input=true,monitors=true,colors=true,cursor=true}) or type(data.input)~="table" then return end
local input={}
for k,v in pairs(data.input) do if k~="touchpad" then input[k]=v end end
if not fields(input,input_rules) or (data.input.touchpad and not fields(data.input.touchpad,touch_rules)) then return end
local monitor_keys={output=true,disabled=true,mode=true,scale=true,position=true,transform=true,mirror=true,bitdepth=true,vrr=true,cm=true}
if type(data.monitors)~="table" then return end
for k in pairs(data.monitors) do
  if type(k)~="number" or k%1~=0 or k<1 or k>#data.monitors then return end
end
if data.cursor~=nil and (type(data.cursor)~="string" or #data.cursor>512 or data.cursor:find("[%c/]")) then return end
local outputs, enabled={},0
for _,m in ipairs(data.monitors) do
  if not only(m,monitor_keys) or type(m.output)~="string" or not m.output:match("^[%w_.:%-]+$") or outputs[m.output]
    or type(m.disabled)~="boolean" or type(m.mode)~="string" or (m.mode~="preferred" and not m.mode:match("^%d+x%d+@%d+%.?%d*$"))
    or type(m.scale)~="number" or m.scale~=m.scale or m.scale<0.5 or m.scale>4
    or type(m.position)~="string" or not m.position:match("^%-?%d+x%-?%d+$")
    or type(m.transform)~="number" or m.transform%1~=0 or m.transform<0 or m.transform>7
    or (m.bitdepth~=8 and m.bitdepth~=10) or (m.vrr~=0 and m.vrr~=1 and m.vrr~=2)
    or (m.cm~="srgb" and m.cm~="hdr") or type(m.mirror)~="string" then return end
  outputs[m.output]=m
  if not m.disabled then enabled=enabled+1 end
end
if #data.monitors>0 and enabled==0 then return end
for _,m in ipairs(data.monitors) do
  local seen, target={[m.output]=true},m.mirror
  while target~="" do
    if seen[target] or not outputs[target] or outputs[target].disabled then return end
    seen[target]=true; target=outputs[target].mirror
  end
end
if not only(data.colors,{cyan=true,lavender=true,muted=true,shadow=true}) then return end
for _,k in ipairs({"cyan","lavender","muted","shadow"}) do
  if type(data.colors[k])~="string" or #data.colors[k]~=6 or not data.colors[k]:match("^%x+$") then return end
end
local p=data.colors
-- The complete data has been validated before making any compositor call.
if data.input.accel_profile=="" then data.input.accel_profile="adaptive" end
hl.config({input=data.input,general={col={active_border={colors={"rgba("..p.cyan.."ee)","rgba("..p.lavender.."ee)"},angle=45},inactive_border="rgba("..p.muted.."66)"}},decoration={shadow={color="rgba("..p.shadow.."ee)"}}})
-- Enable outputs before disabling others. Never force supports_hdr/supports_wide_color.
for _,m in ipairs(data.monitors) do if not m.disabled then hl.monitor(m) end end
for _,m in ipairs(data.monitors) do if m.disabled then hl.monitor(m) end end

if data.cursor and data.cursor~="" then hl.env("XCURSOR_THEME",data.cursor) end
