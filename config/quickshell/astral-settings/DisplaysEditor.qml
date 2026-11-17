pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../astral-bar/panel" as Panel
import "Logic.js" as Logic

ColumnLayout {
  id:root
  required property var window
  required property var service
  required property var tokens
  spacing:14
  function edit(index,key,value) { const next=Logic.clone(window.displayDraft); next[index][key]=value; window.displayDraft=next; window.displaysDirty=true; }
  function geometry(m) {
    const mode=m.mode.match(/^(\d+)x(\d+)/), xy=m.position.split('x').map(Number);
    const w=mode ? Number(mode[1]) : 1920, h=mode ? Number(mode[2]) : 1080;
    return {x:xy[0],y:xy[1],w:(m.transform%2 ? h:w)/m.scale,h:(m.transform%2 ? w:h)/m.scale};
  }
  readonly property var bounds: {
    const list=window.displayDraft.map(geometry);
    return {x:Math.min(0,...list.map(m=>m.x)),y:Math.min(0,...list.map(m=>m.y)),
      right:Math.max(1,...list.map(m=>m.x+m.w)),bottom:Math.max(1,...list.map(m=>m.y+m.h))};
  }
  Panel.PanelCard {
    tokens:root.tokens; title:'WORKSPACE LAYOUT'
    Label { text:root.service.apiReason || 'Drag to arrange your screens. Every change gets a 20-second trial.'; wrapMode:Text.Wrap; Layout.fillWidth:true; color:root.tokens.muted; font.pixelSize:12 }
    Rectangle {
      id:map
      Layout.fillWidth:true; implicitHeight:210; color:root.tokens.sunken; radius:root.tokens.cardRadius; clip:true
      readonly property real factor:Math.min((width-56)/Math.max(1,root.bounds.right-root.bounds.x),140/Math.max(1,root.bounds.bottom-root.bounds.y))
      readonly property real originX:(width-(root.bounds.right-root.bounds.x)*factor)/2
      readonly property real originY:(height-(root.bounds.bottom-root.bounds.y)*factor)/2
      Repeater {
        model:root.window.displayDraft
        Rectangle {
          id:monitor
          required property var modelData
          required property int index
          readonly property var dimensions:root.geometry(modelData)
          x:map.originX+(dimensions.x-root.bounds.x)*map.factor
          y:map.originY+(dimensions.y-root.bounds.y)*map.factor
          width:Math.max(44,dimensions.w*map.factor); height:Math.max(36,dimensions.h*map.factor)
          color:Qt.tint(root.tokens.surface,Qt.alpha(root.tokens.accentAt(index),drag.active ? 0.24 : 0.09))
          opacity:modelData.disabled ? 0.45 : 1
          border.color:root.tokens.accentAt(index); border.width:drag.active ? 2:1; radius:root.tokens.rowRadius
          Column {
            anchors.centerIn:parent; spacing:5
            Label { anchors.horizontalCenter:parent.horizontalCenter; text:String(monitor.index+1).padStart(2,'0'); font.family:root.tokens.mono; font.pixelSize:18; color:root.tokens.accentAt(monitor.index) }
            Label { anchors.horizontalCenter:parent.horizontalCenter; text:monitor.modelData.output; font.pixelSize:11; color:root.tokens.text }
          }
          DragHandler {
            id:drag
            enabled:!root.service.apiReason && !root.service.busy && !root.service.testing
            property real startX:0
            property real startY:0
            property real factor:1
            onActiveChanged: {
              if(active) { startX=monitor.dimensions.x; startY=monitor.dimensions.y; factor=map.factor; }
              else root.edit(monitor.index,'position',Math.round(startX+translation.x/factor)+'x'+Math.round(startY+translation.y/factor));
            }
          }
        }
      }
      Label { anchors.centerIn:parent; visible:!root.window.displayDraft.length; text:'No connected displays'; color:root.tokens.muted }
    }
  }
  Repeater {
    model:root.window.displayDraft
    Panel.PanelCard {
      id:display
      required property var modelData
      required property int index
      readonly property var live:root.service.inventory.find(m=>m.name===modelData.output) || ({})
      tokens:root.tokens; accent:root.tokens.accentAt(index)
      enabled:!root.service.apiReason && !root.service.busy && !root.service.testing
      RowLayout {
        Layout.fillWidth:true; spacing:12
        Rectangle {
          width:40; height:40; radius:12; color:Qt.alpha(display.accent,0.12)
          Label { anchors.centerIn:parent; text:String(display.index+1).padStart(2,'0'); font.family:root.tokens.mono; color:display.accent }
        }
        ColumnLayout {
          Layout.fillWidth:true; spacing:3
          Label { text:display.modelData.output; font.pixelSize:16; font.weight:Font.DemiBold; color:root.tokens.text }
          Label { text:display.live.description || 'Connected display'; color:root.tokens.muted; font.pixelSize:11; Layout.fillWidth:true; elide:Text.ElideRight }
        }
        Label { text:display.modelData.disabled ? 'Disabled' : 'Enabled'; color:root.tokens.muted; font.pixelSize:11 }
        Panel.PanelSwitch { tokens:root.tokens; checked:!display.modelData.disabled; onToggled:root.edit(display.index,'disabled',!checked); Accessible.name:'Enable '+display.modelData.output }
      }
      Rectangle { Layout.fillWidth:true; height:1; color:root.tokens.hairline }
      GridLayout {
        columns:2; Layout.fillWidth:true; columnSpacing:24; rowSpacing:12
        Label { text:'Resolution & refresh rate'; color:root.tokens.text; font.pixelSize:12 }
        SettingsChoice { tokens:root.tokens; Layout.fillWidth:true; Layout.minimumWidth:180; model:Array.from(new Set([display.modelData.mode,'preferred'].concat((display.live.availableModes || []).map(m=>m.replace(/Hz$/,''))))); currentIndex:model.indexOf(display.modelData.mode); onActivated:root.edit(display.index,'mode',model[currentIndex]); Accessible.name:'Resolution and refresh rate' }
        Label { text:'Scale'; color:root.tokens.text; font.pixelSize:12 }
        SettingsTextField { tokens:root.tokens; Layout.fillWidth:true; text:String(display.modelData.scale); onTextEdited:root.edit(display.index,'scale',Number(text)); Accessible.name:'Display scale' }
        Label { text:'Position · X × Y'; color:root.tokens.text; font.pixelSize:12 }
        SettingsTextField { tokens:root.tokens; Layout.fillWidth:true; text:display.modelData.position; onTextEdited:root.edit(display.index,'position',text); Accessible.name:'Display position' }
        Label { text:'Rotation'; color:root.tokens.text; font.pixelSize:12 }
        SettingsChoice { tokens:root.tokens; Layout.fillWidth:true; model:['Normal','90°','180°','270°','Flipped','Flipped 90°','Flipped 180°','Flipped 270°']; currentIndex:display.modelData.transform; onActivated:root.edit(display.index,'transform',currentIndex); Accessible.name:'Display rotation' }
        Label { text:'Mirror another display'; color:root.tokens.text; font.pixelSize:12 }
        SettingsChoice { tokens:root.tokens; Layout.fillWidth:true; model:[''].concat(root.window.displayDraft.filter(m=>m.output!==display.modelData.output).map(m=>m.output)); currentIndex:Math.max(0,model.indexOf(display.modelData.mirror)); displayText:currentText || 'Independent'; onActivated:root.edit(display.index,'mirror',model[currentIndex]); Accessible.name:'Mirror display' }
      }
      Rectangle { Layout.fillWidth:true; height:1; color:root.tokens.hairline }
      Repeater {
        model:[{key:'vrr',title:'Variable refresh rate',subtitle:'Smoother motion with adaptive refresh'},{key:'hdr',title:'High dynamic range',subtitle:'More detail in highlights and shadows'},{key:'10bit',title:'10-bit color',subtitle:'Finer gradients and color transitions'}]
        RowLayout {
          id:capability
          required property var modelData
          readonly property var supported:Logic.displayCapability(display.live,modelData.key)
          readonly property bool canTest:supported===true || (modelData.key==='10bit' && supported===null)
          Layout.fillWidth:true; spacing:16
          ColumnLayout {
            Layout.fillWidth:true; spacing:4
            Label { text:capability.modelData.title; color:root.tokens.text; font.pixelSize:12 }
            Label { text:capability.supported===null && capability.modelData.key==='10bit' ? 'Try 10-bit for 20 seconds; keep only if the display works correctly' : capability.supported===true ? capability.modelData.subtitle : Logic.capabilityText(display.live,capability.modelData.key); color:root.tokens.muted; font.pixelSize:11; wrapMode:Text.Wrap; Layout.fillWidth:true }
          }
          SettingsChoice {
            tokens:root.tokens; Layout.preferredWidth:180
            visible:capability.modelData.key!=='hdr'; enabled:capability.canTest
            model:capability.modelData.key==='vrr' ? ['Off','On','Fullscreen'] : ['8-bit','10-bit']
            currentIndex:capability.modelData.key==='vrr' ? display.modelData.vrr : display.modelData.bitdepth===10 ? 1:0
            onActivated:root.edit(display.index,capability.modelData.key==='vrr' ? 'vrr':'bitdepth',capability.modelData.key==='vrr' ? currentIndex : currentIndex===1 ? 10:8)
            Accessible.name:capability.modelData.title
          }
          Panel.PanelSwitch {
            tokens:root.tokens; visible:capability.modelData.key==='hdr'; enabled:capability.supported===true
            checked:display.modelData.cm==='hdr'; onToggled:root.edit(display.index,'cm',checked ? 'hdr':'srgb'); Accessible.name:'High dynamic range'
          }
        }
      }
    }
  }
}
