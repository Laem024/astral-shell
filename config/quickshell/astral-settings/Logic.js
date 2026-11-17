.pragma library

function clone(v) { return JSON.parse(JSON.stringify(v)); }
function at(v, path) { return path.split('.').reduce((o,k) => o === undefined ? undefined : o[k], v); }
function put(v, path, value) {
  const keys = path.split('.'); let o = v;
  for (const k of keys.slice(0,-1)) { if (!o[k]) o[k] = {}; o = o[k]; }
  o[keys[keys.length-1]] = value;
}
const pages = ['Displays','Bar','Appearance','Colors','Keyboard','Mouse & Touchpad','Power & Lock','General','About'];
// Every desktop field is allowlisted here; arbitrary Lua identifiers never enter the serializer.
const inputRules = {
  kb_layout: ['string'], kb_variant: ['string'], kb_model: ['string'], kb_options: ['string'],
  repeat_delay: ['number',100,2000], repeat_rate: ['number',1,100], numlock_by_default: ['boolean'],
  sensitivity: ['number',-1,1], accel_profile: ['enum','flat','adaptive',''], natural_scroll: ['boolean'], scroll_factor: ['number',0.1,10],
  'touchpad.natural_scroll': ['boolean'], 'touchpad.scroll_factor': ['number',0.1,10],
  'touchpad.tap-to-click': ['boolean'], 'touchpad.clickfinger_behavior': ['boolean'], 'touchpad.disable_while_typing': ['boolean']
};
function checkRule(value, rule) {
  if (rule[0] === 'enum') return rule.slice(1).includes(value);
  if (typeof value !== rule[0]) return false;
  if (rule[0] === 'number') return Number.isFinite(value) && value >= rule[1] && value <= rule[2];
  return rule[0] !== 'string' || (value.length <= 512 && !/[\x00-\x1f\x7f]/.test(value));
}
function inputValue(key, reply) {
  const rule=inputRules[key];
  if(!rule || !reply || typeof reply!=='object') throw new Error('Invalid input reply: '+key);
  let value;
  if(rule[0]==='boolean') {
    if(typeof reply.bool==='boolean') value=reply.bool;
    else if(reply.bool===undefined && [0,1].includes(reply.int)) value=reply.int===1;
  } else if(rule[0]==='number') value=reply.float===undefined ? reply.int : reply.float;
  else value=reply.str;
  if(!checkRule(value,rule)) throw new Error('Invalid input value: '+key);
  return value;
}
function validateDesktop(v) {
  if (!v || v.version !== 1 || !v.input || !v.themes || !Array.isArray(v.monitors)) throw new Error('Invalid desktop preferences version');
  for (const key of Object.keys(v.input)) {
    if (key === 'touchpad') {
      for (const k of Object.keys(v.input.touchpad)) if (!inputRules['touchpad.'+k] || !checkRule(v.input.touchpad[k], inputRules['touchpad.'+k])) throw new Error('Invalid touchpad field: '+k);
    } else if (!inputRules[key] || !checkRule(v.input[key],inputRules[key]) || (key.startsWith('repeat_') && !Number.isInteger(v.input[key]))) throw new Error('Invalid input field: '+key);
  }
  for (const mode of ['light','dark']) {
    if (!v.themes[mode]) throw new Error('Missing theme mode');
    for (const k of Object.keys(v.themes[mode])) if (!['gtk','qt','icons','cursor'].includes(k) || typeof v.themes[mode][k] !== 'string' || /[\x00-\x1f\x7f/]/.test(v.themes[mode][k])) throw new Error('Invalid theme');
  }
  if (v.monitors.length) validateMonitors(v.monitors);
  return v;
}
function mergeDesktop(current, base, changes) {
  const next = clone(current);
  for (const key of Object.keys(changes)) {
    if (!(key.startsWith('input.') && inputRules[key.slice(6)]) && !/^themes\.(light|dark)\.(gtk|qt|icons|cursor)$/.test(key)) throw new Error('Unsupported field');
    if (JSON.stringify(at(current,key)) !== JSON.stringify(at(base,key))) throw new Error('Changed externally: '+key+'. Reload before applying.');
    put(next,key,changes[key]);
  }
  return validateDesktop(next);
}
function lua(value) {
  if (typeof value === 'string') return '"'+value.replace(/\\/g,'\\\\').replace(/"/g,'\\"').replace(/[\x00-\x1f\x7f]/g,c => '\\'+('000'+c.charCodeAt(0)).slice(-3))+'"';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  if (Array.isArray(value)) return '{'+value.map(lua).join(',')+'}';
  if (value && typeof value === 'object') return '{'+Object.keys(value).sort().map(k => '['+lua(k)+']='+lua(value[k])).join(',')+'}';
  throw new Error('Cannot serialize Lua value');
}
function overrideData(desktop, common) {
  validateDesktop(desktop);
  const p = common.colors[common.mode];
  const hex = hexColor;
  return {version:1, input:desktop.input, monitors:desktop.monitors, cursor:desktop.themes[common.mode].cursor || '', colors:{cyan:hex(p.cyan),lavender:hex(p.lavender),muted:hex(p.muted),shadow:hex(p.background)}};
}
function overrideLua(desktop, common) { return '-- Managed by Astral Settings. Confirmed overrides only.\nreturn '+lua(overrideData(desktop,common))+'\n'; }
function inputLua(input) { validateDesktop({version:1,input:input,themes:{light:{},dark:{}},monitors:[]}); return 'hl.config('+lua({input:input})+')'; }
function monitorFromLive(m) {
  return {output:m.name,disabled:!!m.disabled,mode:m.width+'x'+m.height+'@'+Number(m.refreshRate || 60).toFixed(3),scale:m.scale || 1,position:(m.x || 0)+'x'+(m.y || 0),transform:m.transform || 0,mirror:typeof m.mirrorOf === 'string' && m.mirrorOf !== 'none' ? m.mirrorOf : '',bitdepth:m.bitDepth || 8,vrr:m.vrr ? 1 : 0,cm:m.cm === 'hdr' || m.colorManagementPreset === 'hdr' || m.hdr === true ? 'hdr' : 'srgb'};
}
function validateMonitors(list, inventory) {
  if (!Array.isArray(list) || !list.length || !list.some(m => !m.disabled)) throw new Error('At least one display must remain enabled');
  const names = list.map(m => m.output);
  if (new Set(names).size !== names.length) throw new Error('Duplicate output');
  for (const m of list) {
    if (!/^[A-Za-z0-9_.:-]+$/.test(m.output) || typeof m.disabled !== 'boolean' || !/^(preferred|\d+x\d+@\d+(\.\d+)?)$/.test(m.mode)
        || !Number.isFinite(m.scale) || m.scale < 0.5 || m.scale > 4 || !/^-?\d+x-?\d+$/.test(m.position)
        || !Number.isInteger(m.transform) || m.transform < 0 || m.transform > 7 || ![8,10].includes(m.bitdepth) || ![0,1,2].includes(m.vrr) || !['srgb','hdr'].includes(m.cm)) throw new Error('Invalid display configuration');
    if (Object.keys(m).some(k => !['output','disabled','mode','scale','position','transform','mirror','bitdepth','vrr','cm'].includes(k))) throw new Error('Unknown monitor field');
    let target = m.mirror; const seen = [m.output];
    while (target) {
      if (seen.includes(target)) throw new Error('Mirror cycle');
      const peer = list.find(p => p.output === target);
      if (!peer || peer.disabled) throw new Error('Mirror target unavailable');
      seen.push(target); target = peer.mirror;
    }
    if (inventory) {
      const live = inventory.find(i => i.name === m.output);
      if (!live) throw new Error('Display disconnected: '+m.output);
      if (m.cm === 'hdr' && live.supportsHDR !== true && monitorFromLive(live).cm !== 'hdr') throw new Error('HDR capability is unavailable');
      if (m.vrr && live.vrrSupported !== true && m.vrr !== monitorFromLive(live).vrr) throw new Error('VRR capability is unavailable');
      if (m.bitdepth === 10 && live.supports10bit !== true && live.bitDepth !== 10) throw new Error('10-bit capability is unavailable');
      if (m.mode !== 'preferred' && live.availableModes && !live.availableModes.some(mode => sameMode(mode,m.mode)) && m.mode !== monitorFromLive(live).mode) throw new Error('Mode is not advertised by the display');
    }
  }
  return list;
}
function restoreMonitors(previous, inventory) {
  const present = previous.filter(m => inventory.some(i => i.name === m.output)).map(clone);
  for (const m of present) if (m.mirror && !present.some(p => p.output === m.mirror && !p.disabled)) m.mirror = '';
  if (!present.some(m => !m.disabled) && inventory.length) {
    const safe = monitorFromLive(inventory[0]); safe.disabled=false; safe.mode='preferred'; safe.scale=1; safe.position='0x0'; safe.cm='srgb'; safe.vrr=0; safe.bitdepth=8; safe.mirror='';
    const i = present.findIndex(m => m.output === safe.output); if(i >= 0) present[i]=safe; else present.push(safe);
  }
  return present;
}
function monitorLua(list) { validateMonitors(list); return list.slice().sort((a,b) => Number(a.disabled)-Number(b.disabled)).map(m => 'hl.monitor('+lua(m)+')').join('\n'); }
function ini(text, section, values) {
  const lines = text.split('\n'); let active=false; const seen={}; const result=[];
  function remaining() { for (const k of Object.keys(values)) if (!seen[k]) { result.push(k+'='+values[k]); seen[k]=true; } }
  let found=false;
  for (const line of lines) {
    if (/^\s*\[.*\]\s*$/.test(line)) { if(active) remaining(); active=line.trim()==='['+section+']'; if(active) found=true; }
    const match=line.match(/^\s*([^#;=]+?)\s*=/);
    if(active && match && Object.prototype.hasOwnProperty.call(values,match[1])) { if(!seen[match[1]]) result.push(match[1]+'='+values[match[1]]); seen[match[1]]=true; } else result.push(line);
  }
  if(active) remaining();
  if(!found) { result.push('['+section+']'); remaining(); }
  return result.join('\n').replace(/\n*$/,'\n');
}
function kitty(text, palette) {
  const rgb=c=>'#'+hexColor(c);
  const values={background:rgb(palette.background),foreground:rgb(palette.text),selection_background:rgb(palette.cyan),selection_foreground:rgb(palette.background),cursor:rgb(palette.text)};
  const seen={}; const lines=text.split('\n').map(line => {
    const k=line.trim().split(/\s+/)[0]; if(!Object.prototype.hasOwnProperty.call(values,k)) return line;
    seen[k]=true; return k+' '+values[k];
  });
  for(const k of Object.keys(values)) if(!seen[k]) lines.push(k+' '+values[k]);
  return lines.join('\n').replace(/\n*$/,'\n');
}

function hexColor(c) { const h=c.replace('#',''); return h.length===3 ? h.split('').map(x=>x+x).join('') : h.slice(-6); }
function paletteLua(common) {
 const p=common.colors[common.mode];
 return 'hl.config('+lua({general:{col:{active_border:{colors:['rgba('+hexColor(p.cyan)+'ee)','rgba('+hexColor(p.lavender)+'ee)'],angle:45},inactive_border:'rgba('+hexColor(p.muted)+'66)'}},decoration:{shadow:{color:'rgba('+hexColor(p.background)+'ee)'}}})+')';
}

function sameMode(a,b) {
 const parse=s=>s.replace(/Hz$/,'').match(/^(\d+)x(\d+)@([\d.]+)$/);
 const x=parse(a), y=parse(b);
 return !!x && !!y && x[1]===y[1] && x[2]===y[2] && Math.abs(Number(x[3])-Number(y[3]))<0.02;
}

function mergeMonitors(draft, baseline, inventory) {
  const fresh=inventory.map(monitorFromLive);
  for(const edited of draft) {
    const original=baseline.find(m=>m.output===edited.output), current=fresh.find(m=>m.output===edited.output);
    if(!current || !original) throw new Error('Display connections changed; reset and review the layout');
    for(const key of Object.keys(edited)) {
      if(JSON.stringify(edited[key])===JSON.stringify(original[key])) continue;
      if(JSON.stringify(current[key])!==JSON.stringify(original[key])) throw new Error('Display field changed externally: '+edited.output+' '+key+'. Reset before applying.');
      current[key]=edited[key];
    }
  }
  return validateMonitors(fresh,inventory);
}
