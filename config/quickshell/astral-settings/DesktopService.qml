import QtQuick
import Quickshell
import Quickshell.Io
import "../common" as Common
import "Logic.js" as Logic

// Lives in the daemon, independently of the window and its confirmation dialog.
QtObject {
  id: root
  property bool preview: false
  property bool windowOpen: true
  onWindowOpenChanged: if(!windowOpen && testing) revert()
  readonly property string directory: Common.Paths.state + "/astral-settings"
  readonly property string configHome: Common.Paths.base("XDG_CONFIG_HOME", Common.Paths.home + "/.config")
  readonly property string statePath: directory + "/state.json"
  readonly property string luaPath: configHome + "/astral-shell/astral-settings/overrides.lua"
  property var value: ({version:1,input:{},themes:{light:{gtk:"",qt:"",icons:"",cursor:""},dark:{gtk:"",qt:"",icons:"",cursor:""}},monitors:[]})
  property var inventory: []
  property var liveInput: ({})
  property var installed: ({gtk:[],qt:[],icons:[],cursor:[]})
  property string about: ""
  property string error: ""
  property bool ready: false
  property bool inspected: false
  property bool busy: false
  property bool recovering: false
  property bool testing: false
  property int seconds: 0
  property var transaction: null
  property bool rollbackRequested: false
  property string apiReason: "Detecting Hyprland Lua API…"
  property var themeBackups: []
  property bool quietOperation: false
  property string appliedAppearance: ""
  property string appliedCursor: Quickshell.env("XCURSOR_THEME") || "default"
  property string operationAppearance: ""
  function appearanceKey(common) { return JSON.stringify({mode:common.mode,colors:common.colors}); }
  signal completed(bool success, string message)
  property Common.Command command: Common.Command { timeout: 5000 }
  property Common.Command query: Common.Command { timeout: 3000 }
  property FileView io: FileView {
    atomicWrites: true; blockWrites: true; blockLoading: true
    onLoadFailed: error => root.loadError = error
    onSaveFailed: root.saveFailed = true
  }
  property int loadError: FileViewError.Success
  property bool saveFailed: false
  function read(path, optional) {
    if(preview) return optional ? null : "";
    loadError=FileViewError.Success; io.path=path; io.text(); io.reload(); io.waitForJob();
    if(loadError!==FileViewError.Success) {
      if(optional && loadError===FileViewError.FileNotFound) return null;
      throw new Error("Cannot read " + path + ": " + FileViewError.toString(loadError));
    }
    return io.text();
  }
  function write(path, text) {
    if(preview) return;
    io.path=path; io.text(); io.waitForJob(); saveFailed=false; io.setText(text); io.waitForJob();
    if(saveFailed || read(path,false)!==text) throw new Error("Cannot verify write: "+path);
  }
  function disk() {
    const text=read(statePath,true);
    return text===null ? Logic.clone(value) : Logic.validateDesktop(JSON.parse(text));
  }
  function finish(ok, message) {
    busy=false; error=ok ? "" : message;
    if(ok && operationAppearance) appliedAppearance=operationAppearance;
    operationAppearance="";
    const quiet=quietOperation; quietOperation=false;
    if(!quiet) completed(ok,message);
    if(ready && !inspected) startInspection();
    if(ok && appliedAppearance!==appearanceKey(Common.SettingsData.value)) appearanceSync.restart();
  }
  function persist(next, common) {
    // The JSON is authoritative; callers restore both artifacts if application fails.
    write(luaPath,Logic.overrideLua(next,common));
    write(statePath,JSON.stringify(next,null,2)+'\n'); value=next;
  }
  function evalLua(code, done) {
    if(preview) { Qt.callLater(() => done(true,"")); return; }
    command.run(['hyprctl','eval',code], (c,out,err) => done(c===0 && !/\berror\b|\bfailed\b/i.test(out),err || out));
  }
  function refresh(done) {
    if(preview) { if(done) done(true); return; }
    if(query.running) { if(done) done(false); return; }
    query.run(['hyprctl','-j','monitors','all'], (c,out) => {
      let valid=false;
      try { if(c) throw new Error('Monitor query failed'); const v=JSON.parse(out); if(!Array.isArray(v)) throw new Error('Invalid monitors'); inventory=v; valid=true; }
      catch(e) { error=e.message; }
      if(done) done(valid);
    });
  }
  function initialize() {
    if(preview) {
      inventory=[{name:'DP-1',width:1920,height:1080,refreshRate:60,x:0,y:0,scale:1,transform:0,bitDepth:8,availableModes:['1920x1080@60.000','1280x720@60.000'],supportsHDR:false,vrrSupported:true}];
      liveInput={kb_layout:'us',kb_variant:'',kb_model:'',kb_options:'',repeat_delay:250,repeat_rate:35,numlock_by_default:true,sensitivity:0,accel_profile:'adaptive',natural_scroll:false,scroll_factor:1,touchpad:{natural_scroll:false,scroll_factor:1,'tap-to-click':true,clickfinger_behavior:true,disable_while_typing:true}};
      installed={gtk:['Adwaita'],qt:['Breeze'],icons:['Adwaita'],cursor:['Adwaita']};
      apiReason=''; ready=true; about='Astral preview\nLinux sample\nCPU: 8 cores\nMemory: 16 GiB\nGPU: Sample graphics\nSession: Wayland'; return;
    }
    command.run(['mkdir','-p','-m','700','--',directory,configHome+'/astral-shell/astral-settings'], c => {
      if(c) { error='Cannot create Settings directories'; return; }
      try { value=disk(); } catch(e) { error=e.message; }
      appliedAppearance=appearanceKey(Common.SettingsData.value);
      if(Object.values(value.themes[Common.SettingsData.value.mode]).some(v=>!!v)) { appliedAppearance=""; appearanceSync.restart(); }
      // eval reports execution status ("ok"); repl returns the expression's value.
      command.run(['hyprctl','repl','type(hl.monitor) == "function" and type(hl.config) == "function"'], (c,out) => {
        apiReason=c===0 && out.trim()==='true' ? '' : 'Installed Hyprland does not expose the Lua monitor/config API';
        refresh(ok => {
          try {
            const journal=read(directory+'/display-transaction.json',true);
            if(journal!==null) {
              const v=JSON.parse(journal);
              if(v.version!==1 || typeof v.pending!=='boolean' || !Array.isArray(v.previous)) throw new Error('Invalid display recovery journal');
              if(v.pending) { Logic.validateMonitors(v.previous); if(v.confirmed && v.confirmed.length) Logic.validateMonitors(v.confirmed); transaction=v; testing=true; recovering=true; revert(); }
            }
          } catch(e) { error=e.message; }
          ready=true;
          if(!busy) startInspection();
        });
      });
    });
    discoverThemes();
  }
  function startInspection() { if(inspected) return; inspected=true; discoverInput(Object.keys(Logic.inputRules),0); }
  function discoverInput(keys,index) {
    if(index>=keys.length) { inspectAbout(); return; }
    const k=keys[index];
    query.run(['hyprctl','-j','getoption','input:'+k.replace('.',':')], (c,out) => {
      try {
        if(!c) { const result=Logic.inputValue(k,JSON.parse(out));
          const next=Logic.clone(liveInput); Logic.put(next,k,result); liveInput=next;
        }
      } catch(e) {}
      discoverInput(keys,index+1);
    });
  }
  property Common.Command discovery: Common.Command { timeout: 5000 }
  function discoverThemes() {
    const dataRoots=[Common.Paths.base('XDG_DATA_HOME',Common.Paths.home+'/.local/share')].concat((Quickshell.env('XDG_DATA_DIRS') || '/usr/local/share:/usr/share').split(':').filter(p=>p.startsWith('/')));
    const directories=[Common.Paths.home+'/.themes',Common.Paths.home+'/.icons'];
    for(const path of dataRoots) directories.push(path+'/themes',path+'/icons');
    discovery.run(['find'].concat(directories,['-maxdepth','3','-type','d']), (c,out) => {
      const themes={gtk:[],qt:[],icons:[],cursor:[]};
      for(const path of out.split('\n')) {
        const parts=path.split('/'), leaf=parts.pop(), name=parts.pop();
        if(/^gtk-[234]/.test(leaf)) themes.gtk.push(name);
        if(leaf==='cursors') themes.cursor.push(name);
        if(parts[parts.length-1]==='icons' || name==='icons') themes.icons.push(name==='icons' ? leaf : name);
      }
      for(const k of Object.keys(themes)) themes[k]=Array.from(new Set(themes[k])).sort();
      // Qt styles are plugins, not GTK theme directories. Only installed plugins are offered.
      discovery.run(['find','/usr/lib/qt6/plugins/styles','/usr/lib/qt/plugins/styles','-maxdepth','1','-name','*.so'], (code,output) => {
        themes.qt=output.split('\n').filter(s=>s.endsWith('.so')).map(s=>s.split('/').pop().replace(/^lib/,'').replace(/\.so$/,'')); installed=themes;
      });
    });
  }
  function inspectAbout() {
    const files=[['OS','/etc/os-release'],['Kernel','/proc/sys/kernel/osrelease'],['CPU','/proc/cpuinfo'],['Memory','/proc/meminfo']]; const lines=[];
    for(const item of files) { try { let t=read(item[1],false); if(item[0]==='OS') t=(t.match(/^PRETTY_NAME=(.*)$/m)||[])[1] || t; if(item[0]==='CPU') t=(t.match(/model name\s*:\s*(.*)/)||[])[1] || 'Unavailable'; if(item[0]==='Memory') t=(t.match(/MemTotal:\s*(.*)/)||[])[1] || 'Unavailable'; lines.push(item[0]+': '+t.trim()); } catch(e) { lines.push(item[0]+': Unavailable'); } }
    lines.push('Session: '+(Quickshell.env('XDG_SESSION_TYPE') || 'Unavailable'));
    const jobs=[['Hyprland',['hyprctl','version']],['Quickshell',['qs','--version']],['GPU',['lspci']],['Storage',['df','-h',Common.Paths.home]]];
    function next(i) { if(i>=jobs.length) { root.about=lines.join('\n\n'); return; } query.run(jobs[i][1],(c,out) => { let t=out.trim(); if(jobs[i][0]==='GPU') t=t.split('\n').filter(s=>/VGA|3D|Display/.test(s)).join('\n'); lines.push(jobs[i][0]+': '+(c===0 && t ? t : 'Unavailable')); next(i+1); }); } next(0);
  }
  function apply(base, changes, common, quiet) {
    if(busy || testing) return;
    quietOperation=!!quiet;
    operationAppearance=appearanceKey(common);
    let next, previous;
    try {
      previous=disk(); next=Logic.mergeDesktop(previous,base,changes);
      for(const key of Object.keys(changes)) if(key.startsWith('themes.') && changes[key] && !installed[key.split('.')[2]].includes(changes[key])) throw new Error('Theme is no longer installed');
    } catch(e) { finish(false,e.message); return; }
    const hasInput=Object.keys(changes).some(k=>k.startsWith('input.'));
    if(hasInput && apiReason) { finish(false,apiReason); return; }
    busy=true;
    const oldInput=Logic.clone(liveInput);
    const oldCursor=appliedCursor;
    function rollback(message) {
      root.restoreThemeFiles();
      try { root.write(root.luaPath,Logic.overrideLua(root.disk(),common)); } catch(ignored) {}
      root.evalLua(Logic.inputLua(oldInput),()=> {
        if(!root.preview && root.appliedCursor!==oldCursor) {
          root.command.run(['hyprctl','setcursor',oldCursor,String(root.cursorSize())],()=> { root.appliedCursor=oldCursor; root.finish(false,message); });
        } else root.finish(false,message);
      });
    }
    function commit() {
      try {
        next=Logic.mergeDesktop(root.disk(),base,changes); root.persist(next,common);
        root.liveInput=Object.assign({},root.liveInput,next.input); root.themeBackups=[];
        root.finish(true,'Applied. Some applications require restarting to use the selected theme.');
      } catch(e) { rollback(e.message); }
    }
    function save(ok,message) {
      if(!ok) { root.finish(false,message); return; }
      root.applyThemeFiles(next,common,themeOk => {
        if(!themeOk) { rollback(root.error); return; }
        const cursor=next.themes[common.mode].cursor;
        if(cursor && !root.preview) {
          root.command.run(['hyprctl','setcursor',cursor,String(root.cursorSize())],(code,out,err)=> {
            if(code || /error|failed/i.test(out)) { rollback('Cursor could not be applied: '+(err || out)); return; }
            root.appliedCursor=cursor; commit();
          });
        } else commit();
      });
    }
    if(!apiReason) evalLua((hasInput ? Logic.inputLua(next.input)+'\n' : '')+Logic.paletteLua(common),(ok,message) => {
      if(!ok) { root.evalLua(Logic.inputLua(oldInput),()=>save(false,message)); return; }
      root.verifyInput(next.input,Object.keys(changes).filter(k=>k.startsWith('input.')).map(k=>k.slice(6)),0,verified=> {
        if(verified) save(true,''); else root.evalLua(Logic.inputLua(oldInput),()=>save(false,'Input application could not be verified'));
      });
    });
    else if(hasInput) finish(false,apiReason);
    else save(true,'');
  }
  function cursorSize() { const n=Number(Quickshell.env('XCURSOR_SIZE')); return Number.isInteger(n) && n>=8 && n<=128 ? n : 24; }
  function verifyInput(input,keys,index,done) {
    if(preview || index>=keys.length) { done(true); return; }
    if(query.running) { Qt.callLater(()=>verifyInput(input,keys,index,done)); return; }
    const key=keys[index], expected=Logic.at(input,key);
    query.run(['hyprctl','-j','getoption','input:'+key.replace('.',':')], (code,out)=> {
      try {
        if(code) throw new Error('Cannot query input');
        const actual=Logic.inputValue(key,JSON.parse(out));
        if(typeof expected==='number' ? Math.abs(actual-expected)>0.001 : actual!==expected) throw new Error('Input mismatch');
        verifyInput(input,keys,index+1,done);
      } catch(e) { done(false); }
    });
  }
  function applyThemeFiles(next,common,done) {
    if(preview) { done(true); return; }
    const selected=next.themes[common.mode];
    const tasks=[];
    for(const version of ['gtk-3.0','gtk-4.0']) {
      const keys={'gtk-application-prefer-dark-theme':common.mode==='dark' ? '1':'0'}; if(selected.gtk) keys['gtk-theme-name']=selected.gtk; if(selected.icons) keys['gtk-icon-theme-name']=selected.icons; if(selected.cursor) keys['gtk-cursor-theme-name']=selected.cursor;
      if(Object.keys(keys).length) tasks.push({path:configHome+'/'+version+'/settings.ini',section:'Settings',keys:keys});
    }
    if(selected.qt || selected.icons) for(const version of ['qt5ct','qt6ct']) {
      const keys={}; if(selected.qt) keys.style=selected.qt; if(selected.icons) keys.icon_theme=selected.icons;
      tasks.push({path:configHome+'/'+version+'/'+version+'.conf',section:'Appearance',keys:keys});
    }
    tasks.push({path:configHome+'/kitty/kitty.conf',palette:common.colors[common.mode]});
    const backups=[]; themeBackups=backups;
    function restore() { root.restoreThemeFiles(); done(false); }
    function step(i) {
      if(i>=tasks.length) { done(true); return; }
      const task=tasks[i];
      root.command.run(['mkdir','-p','--',task.path.slice(0,task.path.lastIndexOf('/'))],code => {
        if(code) { root.error='Cannot create theme configuration directory'; restore(); return; }
        try {
          const original=root.read(task.path,true), old=original===null ? '' : original;
          function update() {
            try {
              const updated=task.palette ? Logic.kitty(old,task.palette) : Logic.ini(old,task.section,task.keys);
              backups.push({path:task.path,text:old,updated:updated});
              root.write(task.path,updated); step(i+1);
            } catch(e) { root.error=e.message; restore(); }
          }
          if(original===null) update();
          else if(old.length) { root.write(task.path+'.astral-backup',old); update(); }
          else root.command.run(['install','-m','600','/dev/null',task.path+'.astral-backup'],code=> {
            if(code) { root.error='Cannot back up '+task.path; restore(); } else update();
          });
        } catch(e) { root.error=e.message; restore(); }
      });
    } step(0);
  }
  function restoreThemeFiles() {
    for(const item of themeBackups) {
      try { if(read(item.path,false)===item.updated) write(item.path,item.text); }
      catch(e) { error+='; '+e.message; }
    }
    themeBackups=[];
  }
  function beginDisplay(list, baseline) {
    if(busy || testing || apiReason || (!preview && Common.Privacy.blocked)) return;
    busy=true;
    refresh(ok => {
      if(!ok || !windowOpen || (!preview && Common.Privacy.blocked)) { finish(false,'Cannot test displays while the window is hidden or the session is blocked'); return; }
      try {
        list=baseline ? Logic.mergeMonitors(list,baseline,inventory) : Logic.validateMonitors(list,inventory);
        transaction={version:1,pending:true,previous:inventory.map(Logic.monitorFromLive),confirmed:disk().monitors,trial:Logic.clone(list)};
        write(directory+'/display-transaction.json',JSON.stringify(transaction));
      } catch(e) { finish(false,e.message); return; }
      testing=true; seconds=20; rollbackRequested=false; deadline.restart();
      applyMonitorList(list,(applied,message) => {
        busy=false;
        if(!applied || !windowOpen || rollbackRequested || (!preview && Common.Privacy.blocked)) { revert(); return; }
        refresh(verified => {
          if(!verified || !matches(list)) { error='Display application could not be verified'; revert(); }
        });
      });
    });
  }
  function applyMonitorList(list,done) {
    if(preview) {
      inventory=list.map(m => {
        const old=inventory.find(i=>i.name===m.output) || {}, mode=m.mode.match(/^(\d+)x(\d+)@([\d.]+)$/), xy=m.position.split('x');
        return Object.assign({},old,{name:m.output,disabled:m.disabled,width:mode ? Number(mode[1]) : old.width,height:mode ? Number(mode[2]) : old.height,refreshRate:mode ? Number(mode[3]) : old.refreshRate,scale:m.scale,x:Number(xy[0]),y:Number(xy[1]),transform:m.transform,mirrorOf:m.mirror,bitDepth:m.bitdepth,vrr:!!m.vrr,cm:m.cm});
      });
      Qt.callLater(()=>done(true,''));
    } else evalLua(Logic.monitorLua(list),done);
  }
  function matches(list) {
    return list.every(m => {
      const live=inventory.find(i=>i.name===m.output); if(!live) return false;
      if(m.disabled) return !!live.disabled;
      const mode=m.mode.match(/^(\d+)x(\d+)@([\d.]+)$/);
      const xy=m.position.split('x');
      const mirrored=typeof live.mirrorOf==='string' && live.mirrorOf!=='none' ? live.mirrorOf : '';
      return !live.disabled && live.x===Number(xy[0]) && live.y===Number(xy[1]) && mirrored===m.mirror && (!live.bitDepth || live.bitDepth===m.bitdepth) && (m.cm!=='hdr' || Logic.monitorFromLive(live).cm==='hdr') && Math.abs(live.scale-m.scale)<0.01 && live.transform===m.transform && (!mode || (live.width===Number(mode[1]) && live.height===Number(mode[2]) && Math.abs(live.refreshRate-Number(mode[3]))<1));
    });
  }
  function keep() {
    if(!testing || busy || recovering || rollbackRequested || seconds<=0 || !windowOpen) return;
    busy=true;
    refresh(ok => {
      if(!ok || (!preview && Common.Privacy.blocked) || !matches(transaction.trial)) { busy=false; revert(); return; }
      try {
        const next=disk();
        if(JSON.stringify(next.monitors)!==JSON.stringify(transaction.confirmed)) throw new Error('Display preferences changed externally; reload before applying');
        next.monitors=transaction.trial; persist(next,Common.SettingsData.value);
        write(directory+'/display-transaction.json',JSON.stringify({version:1,pending:false,previous:next.monitors}));
        deadline.stop(); testing=false; transaction=null; finish(true,'Display changes kept');
      } catch(e) { error=e.message; busy=false; revert(); }
    });
  }
  function revert() {
    if(!testing) return;
    if(command.running || query.running || busy) { rollbackRequested=true; return; }
    busy=true; deadline.stop();
    refresh(ok => {
      if(!ok || !inventory.length) { busy=false; rollbackRequested=true; error='Waiting for an available display to restore'; return; }
      const restored=Logic.restoreMonitors(transaction.previous,inventory);
      applyMonitorList(restored,(success,message) => {
        if(!success) { busy=false; rollbackRequested=true; error='Display restore failed: '+message; return; }
        refresh(verified => {
          if(!verified || !matches(restored)) { busy=false; rollbackRequested=true; error='Display restoration is not yet verified'; return; }
          try {
            // A crash during Keep may have written one artifact. Restore both before clearing the journal.
            const next=disk();
            if(!transaction.confirmed || JSON.stringify(next.monitors)===JSON.stringify(transaction.confirmed) || JSON.stringify(next.monitors)===JSON.stringify(transaction.trial)) next.monitors=transaction.confirmed ? (transaction.confirmed.length ? Logic.restoreMonitors(transaction.confirmed,inventory) : []) : restored;
            persist(next,Common.SettingsData.value);
            write(directory+'/display-transaction.json',JSON.stringify({version:1,pending:false,previous:restored}));
            testing=false; recovering=false; transaction=null; rollbackRequested=false; finish(true,'Previous display configuration restored');
          } catch(e) { busy=false; rollbackRequested=true; error=e.message; }
        });
      });
    });
  }
  property Connections appearanceChanges: Connections {
    target:Common.SettingsData
    function onValueChanged() { appearanceSync.restart(); }
  }
  property Timer appearanceSync: Timer {
    interval:500
    onTriggered: {
      if(root.preview || root.appliedAppearance===root.appearanceKey(Common.SettingsData.value)) return;
      if(!root.ready || root.busy || root.testing || Common.Privacy.blocked) { restart(); return; }
      root.apply(root.value,{},Common.SettingsData.value,true);
    }
  }
  property Timer deadline: Timer { interval:1000; repeat:true; onTriggered: { root.seconds--; if(root.seconds<=0) { stop(); root.revert(); } } }
  property Timer poll: Timer {
    interval:2000; repeat:true; running:root.ready
    onTriggered: {
      if(root.rollbackRequested && !root.busy && !root.command.running && !root.query.running) root.revert();
      else if(!root.busy && !root.query.running) root.refresh(ok => {
        if(root.testing && root.transaction && root.transaction.trial && root.transaction.trial.some(m=>!root.inventory.some(i=>i.name===m.output))) root.revert();
      });
    }
  }
  Component.onCompleted: Qt.callLater(initialize)
}
