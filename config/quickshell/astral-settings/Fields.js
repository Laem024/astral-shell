.pragma library
.import "Logic.js" as Logic
const presets={
 light:{background:'#EEF2EF',surface:'#FBFCFA',text:'#141B1D',muted:'#5A6764',cyan:'#17675A',lavender:'#3B4A7A',gold:'#8A5B16',alert:'#A9361F'},
 dark:{background:'#0E1113',surface:'#171C1F',text:'#E7ECE9',muted:'#8D9994',cyan:'#7FD0BF',lavender:'#A9B5D9',gold:'#E5B873',alert:'#F08C7B'}
};
function field(page,scope,key,label,type,choices) { return {page:page,scope:scope,key:key,label:label,type:type,choices:choices || []}; }
function all() {
 const f=[]; const add=(p,s,k,l,t,c)=>f.push(field(p,s,k,l,t,c));
 add('Bar','bar','position','Position','choice',['top','bottom','left','right']); add('Bar','bar','margin','Margin','number');
 add('Bar','bar','frame','Frame','choice',['off','folds','full']); add('Bar','bar','workspaceDisplay','Workspaces','choice',['icons','numbers']);
 for(const k of ['logo','workspaces','window','clock','music','network','audio','battery','notifications','tray','capture']) add('Bar','bar','modules.'+k,'Show '+k,'boolean');
 add('Bar','bar','logo.glyph','Logo glyph','string'); add('Bar','bar','logo.image','Logo image path','string');
 add('Bar','bar','weather.temperatureUnit','Temperature unit','choice',['celsius','fahrenheit']); add('Bar','bar','weather.windUnit','Wind unit','choice',['kmh','mph','ms','kn']);
 add('Appearance','common','mode','Color mode','choice',['light','dark']); add('Appearance','common','scale','Quickshell scale','number'); add('Appearance','common','animations','Animations','boolean');
 for(const mode of ['light','dark']) for(const k of ['gtk','qt','icons','cursor']) add('Appearance','desktop','themes.'+mode+'.'+k,mode+' '+({gtk:'GTK theme',qt:'Qt style',icons:'icon theme',cursor:'cursor theme'})[k],'theme');
 for(const mode of ['light','dark']) for(const k of Object.keys(presets[mode])) add('Colors','common','colors.'+mode+'.'+k,mode+' '+k,'color');
 const labels={kb_layout:'Layouts (comma separated)',kb_variant:'Variants (comma separated)',kb_model:'Keyboard model',kb_options:'XKB options (grp:… switches layouts)',repeat_delay:'Repeat delay (ms)',repeat_rate:'Repeat rate (per second)',numlock_by_default:'Num Lock on startup',sensitivity:'Sensitivity',accel_profile:'Acceleration profile',natural_scroll:'Mouse natural scrolling',scroll_factor:'Mouse scroll speed','touchpad.natural_scroll':'Touchpad natural scrolling','touchpad.scroll_factor':'Touchpad scroll speed','touchpad.tap-to-click':'Tap to click','touchpad.clickfinger_behavior':'Click with fingers','touchpad.disable_while_typing':'Disable while typing'};
 for(const k of Object.keys(Logic.inputRules)) { const rule=Logic.inputRules[k]; add(k.startsWith('kb_') || k.startsWith('repeat_') || k==='numlock_by_default' ? 'Keyboard':'Mouse & Touchpad','desktop','input.'+k,labels[k],rule[0]==='enum'?'choice':rule[0],rule[0]==='enum'?rule.slice(1):[]); }
 add('Power & Lock','common','idle.enabled','Enable idle management','boolean');
 for(const k of ['lock','screenOff','suspend']) add('Power & Lock','common','idle.'+k+'Seconds',({lock:'Lock after',screenOff:'Turn off displays after',suspend:'Suspend after'})[k]+' (seconds)','number');
 add('Power & Lock','common','lockScreen.showProfile','Show profile on lock screen','boolean'); add('Power & Lock','common','lockScreen.showMusic','Show music on lock screen','boolean');
 add('General','common','clockFormat','Clock format','choice',['12h','24h']); add('General','common','workspaceCount','Workspace count','number');
 for(const k of ['terminal','fileManager','videoPlayer']) add('General','common','applications.'+k,({terminal:'Terminal',fileManager:'File manager',videoPlayer:'Video player'})[k]+' (JSON argument array)','argv');
 return f;
}
