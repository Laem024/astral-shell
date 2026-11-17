pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../common" as Common
import "Logic.js" as Logic
import "Fields.js" as Fields

Window {
  id: root
  required property var service
  required property var tokens
  required property var barStore
  property bool preview: false
  property string page: 'Displays'
  property string search: ''
  property var baseline: ({})
  property var changes: ({common:{},bar:{},desktop:{}})
  property var displayDraft: []
  property var displayBaseline: []
  property bool displaysDirty: false
  property string status: ''
  property string destination: ''
  property bool closePending: false
  property bool applyThenNavigate: false
  property var applying: null
  readonly property bool dirty: displaysDirty || Object.keys(changes.common).length+Object.keys(changes.bar).length+Object.keys(changes.desktop).length>0
  readonly property var fields: Fields.all().filter(f=>(!search ? f.page===page : (f.label+' '+f.page).toLowerCase().includes(search.toLowerCase())))
  title: preview ? 'Astral Settings Preview' : 'Astral Settings'
  width: 1100; height: 780; minimumWidth: 780; minimumHeight: 560
  color: tokens.background
  palette { window: tokens.background; windowText: tokens.text; base: tokens.surface; text: tokens.text; button: tokens.raised; buttonText: tokens.text; highlight: tokens.cyan; highlightedText: tokens.background; placeholderText: tokens.muted }
  function reload() {
    let reloadError='';
    try {
      Common.SettingsData.file.reload(); Common.SettingsData.file.waitForJob();
      barStore.file.reload(); barStore.file.waitForJob();
      service.value=service.disk();
    } catch(e) { reloadError=e.message; }
    baseline={common:Logic.clone(Common.SettingsData.value),bar:Logic.clone(barStore.value),desktop:Logic.clone(service.value)};
    changes={common:{},bar:{},desktop:{}}; displaysDirty=false;
    displayDraft=service.inventory.map(Logic.monitorFromLive); displayBaseline=Logic.clone(displayDraft); status=reloadError;
  }
  function value(f) {
    if(Object.prototype.hasOwnProperty.call(changes[f.scope],f.key)) return changes[f.scope][f.key];
    let v=Logic.at(baseline[f.scope] || {},f.key);
    if(v===undefined && f.key.startsWith('input.')) v=Logic.at(service.liveInput,f.key.slice(6));
    return v;
  }
  function edit(f,v) {
    const next=Logic.clone(changes); next[f.scope][f.key]=v;
    if(JSON.stringify(v)===JSON.stringify(Logic.at(baseline[f.scope],f.key))) delete next[f.scope][f.key];
    changes=next; status='';
  }
  function unavailable(f) {
    if(f.scope==='bar' && barStore.error) return barStore.error;
    if(f.key.startsWith('input.')) return service.apiReason || (value(f)===undefined ? 'The installed compositor did not report this option' : '');
    if(f.type==='theme' && !service.installed[f.key.split('.')[2]].length) return 'No installed '+f.key.split('.')[2]+' themes detected';
    return '';
  }
  function navigate(target,closing) {
    if(service.testing) { service.revert(); if(closing) hide(); return; }
    if(dirty) { destination=target; closePending=closing; pending.open(); return; }
    if(closing) hide(); else { page=target; search=''; reload(); }
  }
  function continueNavigation() {
    if(closePending) hide(); else if(destination) { page=destination; search=''; }
    closePending=false; destination=''; applyThenNavigate=false; reload();
  }
  function apply() {
    if(service.busy || service.testing) return;
    if(displaysDirty) { service.beginDisplay(displayDraft,displayBaseline); return; }
    const desktopChanges=Object.keys(changes.desktop).length>0;
    const appearanceChanged=Object.keys(changes.common).some(k=>['mode'].includes(k) || k.startsWith('colors.'));
    // Preflight both stores before committing either one.
    try {
      Common.SettingsData.file.reload(); Common.SettingsData.file.waitForJob();
      barStore.file.reload(); barStore.file.waitForJob();
      // updateFields repeats this check immediately before its atomic write.
      Common.SettingsData.previewPatch(baseline.common,changes.common);
      barStore.previewPatch(baseline.bar,changes.bar);
      if(desktopChanges) Logic.mergeDesktop(service.disk(),baseline.desktop,changes.desktop);
    } catch(e) { status=e.message; return; }
    if(Object.keys(changes.common).length && !Common.SettingsData.updateFields(baseline.common,changes.common)) { status=Common.SettingsData.error; return; }
    if(Object.keys(changes.bar).length && !barStore.updateFields(baseline.bar,changes.bar)) {
      const restore={}; for(const key of Object.keys(changes.common)) restore[key]=Logic.at(baseline.common,key);
      if(Object.keys(restore).length) Common.SettingsData.updateFields(Common.SettingsData.value,restore);
      status=barStore.error; return;
    }
    applying={baseline:Logic.clone(baseline),changes:Logic.clone(changes)};
    // Shared values are already persisted and reactively consumed by running modules.
    changes={common:{},bar:{},desktop:changes.desktop};
    baseline={common:Logic.clone(Common.SettingsData.value),bar:Logic.clone(barStore.value),desktop:baseline.desktop};
    if(desktopChanges || appearanceChanged) service.apply(baseline.desktop,changes.desktop,Common.SettingsData.value);
    else { applying=null; reload(); status='Applied and verified'; if(applyThenNavigate) { applyThenNavigate=false; continueNavigation(); } }
  }
  onClosing: event => { event.accepted=false; navigate('',true); }
  onVisibleChanged: if(visible && !dirty) reload()
  Connections {
    target: root.service
    function onCompleted(success,message) {
      if(success) { root.applying=null; root.reload(); root.status=message; if(root.applyThenNavigate) { root.applyThenNavigate=false; root.continueNavigation(); } }
      else {
        if(root.applying) {
          const saved=root.applying;
          for(const scope of ['common','bar']) {
            const store=scope==='common' ? Common.SettingsData : root.barStore;
            const restore={}; for(const k of Object.keys(saved.changes[scope])) restore[k]=Logic.at(saved.baseline[scope],k);
            if(Object.keys(restore).length && !store.updateFields(store.value,restore)) message+='; '+store.error;
          }
          root.baseline=saved.baseline; root.changes=saved.changes; root.applying=null;
        }
        root.status=message; root.applyThenNavigate=false;
      }
    }
    function onInventoryChanged() {
      if(root.service.testing) return;
      const live=root.service.inventory.map(Logic.monitorFromLive);
      if(!root.displaysDirty) { root.displayDraft=live; root.displayBaseline=Logic.clone(live); return; }
      const next=root.displayDraft.filter(m=>live.some(n=>n.output===m.output));
      const base=root.displayBaseline.filter(m=>live.some(n=>n.output===m.output));
      for(const m of live) if(!next.some(n=>n.output===m.output)) { next.push(m); base.push(Logic.clone(m)); }
      if(next.map(m=>m.output).join()!==root.displayDraft.map(m=>m.output).join()) root.status='Display connections changed. Review the updated layout.';
      root.displayDraft=next; root.displayBaseline=base;
    }
  }
  ColumnLayout {
    x:20; y:20; width:(root.width-40)/root.tokens.scale; height:(root.height-40)/root.tokens.scale
    scale:root.tokens.scale; transformOrigin:Item.TopLeft; spacing:16
    RowLayout {
      Layout.fillWidth: true
      Label { text:'Astral Settings'; font.pixelSize:26; font.bold:true; color:root.tokens.text }
      Item { Layout.fillWidth:true }
      TextField { Layout.preferredWidth:280; placeholderText:'Search settings'; text:root.search; onTextEdited:root.search=text }
    }
    RowLayout {
      Layout.fillWidth:true; Layout.fillHeight:true; spacing:24
      ColumnLayout {
        Layout.preferredWidth:185; Layout.alignment:Qt.AlignTop
        Repeater {
          model:Logic.pages
          Button {
            required property string modelData
            Layout.fillWidth:true; text:modelData; highlighted:root.page===modelData && !root.search
            onClicked:root.navigate(modelData,false)
          }
        }
        Item { Layout.fillHeight:true }
        Label { text:root.preview ? 'Simulated preview' : 'Astral desktop'; color:root.tokens.muted }
      }
      ColumnLayout {
        Layout.fillHeight:true; Layout.fillWidth:true
        Label { text:root.search ? 'Search results' : root.page; font.pixelSize:22; color:root.tokens.text }
        ScrollView {
          id: scroll
          Layout.fillWidth:true; Layout.fillHeight:true; clip:true; contentWidth:availableWidth
          ColumnLayout {
            width:scroll.availableWidth; spacing:12
            Label {
              visible:root.page==='Keyboard' || root.page==='Mouse & Touchpad'
              text:'Input settings apply globally to all devices.'; color:root.tokens.muted
            }
            Label {
              visible:root.page==='Appearance'
              text:'GTK and Qt use installed themes. Some applications require restarting. Applications with their own theme may ignore these choices.'
              Layout.fillWidth:true; wrapMode:Text.Wrap; color:root.tokens.muted
            }
            Button {
              visible:!!root.search && 'displays resolution refresh rate scale position rotation mirror vrr hdr color depth'.includes(root.search.toLowerCase())
              text:'Displays · Resolution, refresh rate, scale and layout'
              onClicked:root.navigate('Displays',false)
            }
            Button {
              visible:!!root.search && 'about operating system kernel cpu memory gpu storage session versions'.includes(root.search.toLowerCase())
              text:'About · System information'
              onClicked:root.navigate('About',false)
            }
            DisplaysEditor { visible:root.page==='Displays' && !root.search; Layout.fillWidth:true; window:root; service:root.service; tokens:root.tokens }
            RowLayout {
              visible:root.page==='Colors' && !root.search
              Repeater { model:['light','dark']; Button { required property string modelData; text:'Restore Astral '+modelData; onClicked: { for(const k of Object.keys(Fields.presets[modelData])) root.edit({scope:'common',key:'colors.'+modelData+'.'+k},Fields.presets[modelData][k]); } } }
            }
            Repeater {
              model:root.fields
              Rectangle {
                id: row
                required property var modelData
                readonly property var f:modelData
                readonly property var current:root.value(f)
                readonly property string reason:root.unavailable(f)
                Layout.fillWidth:true; implicitHeight:Math.max(70,editor.implicitHeight+24); radius:10; color:root.tokens.surface
                RowLayout {
                  anchors.fill:parent; anchors.margins:12; spacing:12
                  ColumnLayout {
                    Layout.fillWidth:true
                    Label { text:(root.search ? row.f.page+' · ' : '')+row.f.label; color:root.tokens.text; wrapMode:Text.Wrap; Layout.fillWidth:true }
                    Label { visible:!!row.reason; text:'Unavailable: '+row.reason; color:root.tokens.muted; wrapMode:Text.Wrap; Layout.fillWidth:true }
                  }
                  Loader {
                    id:editor
                    Layout.preferredWidth:300; enabled:!row.reason && !root.service.busy
                    sourceComponent:row.f.type==='boolean' ? booleanField : ['choice','theme'].includes(row.f.type) ? choiceField : textField
                    property var field:row.f
                    property var current:row.current
                  }
                  Component {
                    id:booleanField
                    Switch { checked:!!row.current; onToggled:root.edit(row.f,checked) }
                  }
                  Component {
                    id:choiceField
                    ComboBox {
                      model:row.f.type==='theme' ? [''].concat(root.service.installed[row.f.key.split('.')[2]]) : row.f.choices
                      currentIndex:Math.max(0,model.indexOf(row.current))
                      displayText:currentText || (row.f.type==='theme' ? 'Keep existing theme' : 'Default')
                      onActivated:root.edit(row.f,model[currentIndex])
                    }
                  }
                  Component {
                    id:textField
                    RowLayout {
                      TextField {
                        Layout.fillWidth:true
                        text:row.f.type==='argv' ? JSON.stringify(row.current) : row.current===undefined ? '' : String(row.current)
                        selectByMouse:true
                        onTextEdited: {
                          try { root.edit(row.f,row.f.type==='argv' ? JSON.parse(text) : row.f.type==='number' ? Number(text) : text); }
                          catch(e) { root.status='Enter a JSON array of separate command arguments'; }
                        }
                      }
                      Button {
                        visible:row.f.type==='color'; text:'Pick'; width:44
                        background:Rectangle { color:row.f.type==='color' && /^#[0-9a-fA-F]{6}$/.test(row.current) ? row.current : root.tokens.surface; radius:8; border.color:root.tokens.muted }
                        onClicked: { picker.field=row.f; picker.selectedColor=row.current; picker.open(); }
                      }
                    }
                  }
                }
              }
            }
            RowLayout {
              visible:root.page==='Colors'
              Repeater {
                model:['background','surface','text','muted','cyan','lavender','gold','alert']
                Rectangle {
                  required property string modelData
                  Layout.fillWidth:true; height:48; radius:8
                  color:root.value({scope:'common',key:'colors.'+root.value({scope:'common',key:'mode'})+'.'+modelData}) || root.tokens.surface
                  ToolTip.visible: swatchHover.hovered; ToolTip.text:modelData
                  HoverHandler { id:swatchHover }
                }
              }
            }
            RowLayout {
              visible:root.page==='General'
              Repeater {
                model:[{label:'Connections',target:'control'},{label:'Audio',target:'audio'},{label:'Wallpaper',target:'wallpaper'}]
                Button { required property var modelData; text:modelData.label; onClicked:root.openExisting(modelData.target) }
              }
            }
            Label { visible:root.page==='About'; text:root.service.about || 'Reading system information…'; Layout.fillWidth:true; wrapMode:Text.Wrap; color:root.tokens.text; textFormat:Text.PlainText }
            Button { visible:root.page==='About'; text:'Open resource monitor'; onClicked:if(!root.preview) action.run(['astral-monitor'],()=>{}) }
          }
        }
        Label { Layout.fillWidth:true; text:root.status || root.service.error; visible:!!text; wrapMode:Text.Wrap; color:root.tokens.gold; textFormat:Text.PlainText }
        RowLayout {
          Layout.fillWidth:true
          Label { text:root.dirty ? 'Unsaved changes' : ''; color:root.tokens.muted; Layout.fillWidth:true }
          Button { text:'Reset changes'; enabled:root.dirty && !root.service.testing; onClicked: { root.applyThenNavigate=false; root.destination=''; root.closePending=false; root.reload(); } }
          Button { text:root.displaysDirty ? 'Test for 20 seconds' : 'Apply'; highlighted:true; enabled:root.dirty && root.service.ready && !root.service.busy && !root.service.testing && (!root.displaysDirty || !root.service.apiReason); onClicked:root.apply() }
        }
      }
    }
  }
  Common.Command { id:action }
  function openExisting(target) {
    if(preview) { status='Preview: '+target; return; }
    if(target==='wallpaper') action.run(['astral-wallpaper'],()=>{});
    else { const entry=Common.Overlays.entry('astral-bar'); if(entry) action.run(['qs','ipc','-p',entry,'call','bar','openSettingsPage',target],(c,out)=>{ if(c) root.status='Control center unavailable'; }); }
  }
  ColorDialog { id:picker; property var field; title:'Choose palette color'; onAccepted:root.edit(field,selectedColor.toString()) }
  Dialog {
    id:pending; width:390; title:'Unsaved changes'; modal:true; anchors.centerIn:parent
    contentItem:ColumnLayout {
      Label { text:'Apply changes before continuing?'; color:root.tokens.text }
      RowLayout {
        Button { text:'Apply'; onClicked: { pending.close(); root.applyThenNavigate=true; root.apply(); } }
        Button { text:'Discard'; onClicked: { pending.close(); root.continueNavigation(); } }
        Button { text:'Cancel'; onClicked: { pending.close(); root.applyThenNavigate=false; root.closePending=false; root.destination=''; } }
      }
    }
  }
  Dialog {
    id:confirm; width:390; title:'Keep display changes?'; modal:true; anchors.centerIn:parent; closePolicy:Popup.NoAutoClose
    visible:root.service.testing && root.visible
    contentItem:ColumnLayout {
      Label { text:'Reverting in '+root.service.seconds+' seconds'; color:root.tokens.text }
      RowLayout {
        Button { text:'Keep changes'; enabled:!root.service.busy && !root.service.recovering; onClicked:root.service.keep() }
        Button { text:'Revert'; onClicked:root.service.revert() }
      }
    }
  }
}
