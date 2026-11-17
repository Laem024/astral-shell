import QtQuick
import QtTest
import "../../config/quickshell/common/Validation.js" as Validation
import "../../config/quickshell/common/Defaults.js" as Defaults
import "../../config/quickshell/astral-settings/Logic.js" as Logic
import "../../config/quickshell/astral-settings/Fields.js" as Fields

TestCase {
  name:'AstralSettingsPreferences'
  function rejects(fn) { let failed=false; try { fn(); } catch(e) { failed=true; } verify(failed); }
  function state() { return {version:1,input:{},themes:{light:{gtk:'',qt:'',icons:'',cursor:''},dark:{gtk:'',qt:'',icons:'',cursor:''}},monitors:[]}; }
  function monitor(name) { return {output:name,disabled:false,mode:'1920x1080@60.000',scale:1,position:'0x0',transform:0,mirror:'',bitdepth:8,vrr:0,cm:'srgb'}; }
  function test_field_merge() {
    const base=Logic.clone(Defaults.common), current=Logic.clone(base);
    current.extension={privateValue:'preserved'}; current.clockFormat='24h';
    const result=Validation.patch(current,base,{scale:1.5},'common');
    compare(result.extension.privateValue,'preserved'); compare(result.clockFormat,'24h'); compare(result.scale,1.5);
    rejects(()=>Validation.patch(current,base,{clockFormat:'12h'},'common'));
    rejects(()=>Validation.patch(current,base,{'colors.dark.other':'#112233'},'common'));
    rejects(()=>Validation.patch(current,base,{'constructor.prototype':'bad'},'common'));
    rejects(()=>Validation.patch(current,base,{scale:4},'common'));
    rejects(()=>Validation.patch(current,base,{'idle.lockSeconds':1000},'common'));
    const bar=Validation.patch(Defaults.bar,Defaults.bar,{'modules.capture':false},'bar'); compare(bar.modules.capture,false);
  }
  function test_desktop() {
    const base=state(), current=state(); current.extension='keep'; current.themes.dark.icons='Installed';
    const next=Logic.mergeDesktop(current,base,{'input.repeat_rate':40});
    compare(next.extension,'keep'); compare(next.themes.dark.icons,'Installed');
    rejects(()=>Logic.mergeDesktop(current,base,{'themes.dark.icons':'Other'}));
    rejects(()=>Logic.mergeDesktop(current,base,{'input.exec':'bad'}));
    rejects(()=>Logic.mergeDesktop(current,base,{'input.sensitivity':NaN}));
    rejects(()=>Logic.mergeDesktop(current,base,{'input.kb_layout':'us\nexec'}));
    rejects(()=>Logic.mergeDesktop(current,base,{'themes.dark.gtk':'../../theme'}));
  }
  function test_input_replies() {
    const key='touchpad.tap-to-click';
    compare(Logic.inputValue(key,{bool:true,set:false}),true);
    compare(Logic.inputValue(key,{bool:false,set:true}),false);
    compare(Logic.inputValue(key,{int:1}),true);
    compare(Logic.inputValue(key,{int:0}),false);
    compare(Logic.inputValue('kb_layout',{str:'us'}),'us');
    compare(Logic.inputValue('accel_profile',{str:'[[EMPTY]]',set:false}),'');
    compare(Logic.inputValue('kb_variant',{str:'[[EMPTY]]',set:false}),'');
    compare(Logic.inputValue('repeat_rate',{int:35}),35);
    compare(Logic.inputValue('sensitivity',{float:0.5}),0.5);
    rejects(()=>Logic.inputValue(key,{}));
    rejects(()=>Logic.inputValue(key,{bool:'false'}));
    rejects(()=>Logic.inputValue(key,{int:2}));
    rejects(()=>Logic.inputValue('sensitivity',{}));
  }
  function test_lua() {
    compare(Logic.lua('"\\\n'), '"\\"\\\\\\010"');
    const v=state(); v.input.kb_options='literal\"; os.execute(\"touch /bad\")';
    const result=Logic.overrideLua(v,Defaults.common);
    verify(result.startsWith('-- Managed')); verify(result.includes('return {')); verify(result.includes('\\"'));
    rejects(()=>Logic.lua(Infinity)); rejects(()=>Logic.overrideLua({version:2},Defaults.common));
  }
  function test_monitors() {
    const a=monitor('DP-1'), b=monitor('DP-2');
    Logic.validateMonitors([a,b]);
    a.disabled=true; b.disabled=true; rejects(()=>Logic.validateMonitors([a,b]));
    a.disabled=false; b.disabled=false; a.mirror='DP-2'; b.mirror='DP-1'; rejects(()=>Logic.validateMonitors([a,b]));
    a.mirror=''; b.mirror=''; a.cm='hdr'; rejects(()=>Logic.validateMonitors([a],[{name:'DP-1'}]));
    a.cm='srgb'; a.vrr=1; rejects(()=>Logic.validateMonitors([a],[{name:'DP-1'}]));
    a.vrr=0; a.bitdepth=10; rejects(()=>Logic.validateMonitors([a],[{name:'DP-1'}]));
    a.bitdepth=8; a.output='bad\nname'; rejects(()=>Logic.validateMonitors([a]));
  }
  function test_hardware_capabilities() {
    const internal={name:'eDP-1',hardwareDetails:{hdr:false,vrrCapable:true},currentFormat:'XRGB8888'};
    const external={name:'HDMI-A-1',hardwareDetails:{hdr:true,vrrCapable:false},currentFormat:'XRGB8888'};
    compare(Logic.displayCapability(internal,'vrr'),true);
    compare(Logic.displayCapability(internal,'hdr'),false);
    compare(Logic.displayCapability(external,'hdr'),true);
    compare(Logic.displayCapability(external,'vrr'),false);
    compare(Logic.displayCapability(external,'10bit'),null);
    compare(Logic.displayCapability({},'hdr'),null);
    compare(Logic.displayCapability({supports10bit:true},'10bit'),true);
    compare(Logic.displayCapability({currentFormat:'XRGB2101010'},'10bit'),true);
    compare(Logic.monitorFromLive({name:'DP-1',currentFormat:'ABGR2101010'}).bitdepth,10);
    const a=monitor('eDP-1'); a.vrr=1;
    Logic.validateMonitors([a],[internal]);
    a.vrr=0; a.cm='hdr'; rejects(()=>Logic.validateMonitors([a],[internal]));
    a.output='HDMI-A-1'; Logic.validateMonitors([a],[external]);
    a.bitdepth=10; rejects(()=>Logic.validateMonitors([a],[external]));
  }
  function test_display_conflicts() {
    const inventory=[{name:'DP-1',width:1920,height:1080,refreshRate:60,scale:1,x:0,y:0,transform:0}];
    const base=inventory.map(Logic.monitorFromLive), draft=Logic.clone(base);
    draft[0].scale=1.25; inventory[0].x=1920;
    const merged=Logic.mergeMonitors(draft,base,inventory);
    compare(merged[0].scale,1.25); compare(merged[0].position,'1920x0');
    inventory[0].scale=1.5; rejects(()=>Logic.mergeMonitors(draft,base,inventory));
  }
  function test_hotplug_recovery() {
    const a=monitor('DP-1'), b=monitor('DP-2'); a.disabled=true; b.mirror='DP-1';
    const restored=Logic.restoreMonitors([a,b],[{name:'DP-1',width:1920,height:1080}]);
    compare(restored.length,1); compare(restored[0].disabled,false); compare(restored[0].mode,'preferred');
    const replacement=Logic.restoreMonitors([a],[{name:'HDMI-A-1',width:1920,height:1080}]);
    compare(replacement[0].output,'HDMI-A-1'); compare(replacement[0].disabled,false);
  }
  function test_preserve_theme_files() {
    const text='[Other]\nfoo=bar\n[Settings]\ngtk-theme-name=Old\ncustom=yes\n';
    const next=Logic.ini(text,'Settings',{'gtk-theme-name':'New'});
    verify(next.includes('foo=bar')); verify(next.includes('custom=yes')); verify(next.includes('gtk-theme-name=New')); verify(!next.includes('Old'));
    const kitty=Logic.kitty('color0 #123456\nfont_size 12\nbackground #000000\n',Fields.presets.dark);
    verify(kitty.includes('color0 #123456')); verify(kitty.includes('font_size 12')); verify(kitty.includes('background #0E1113'));
  }
  function test_pages() { compare(Logic.pages.length,9); for(const page of Logic.pages.filter(p=>!['Displays','About'].includes(p))) verify(Fields.all().some(f=>f.page===page)); }
}
