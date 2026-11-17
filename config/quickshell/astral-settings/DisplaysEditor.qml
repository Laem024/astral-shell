pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Logic.js" as Logic

ColumnLayout {
  id:root
  required property var window
  required property var service
  required property var tokens
  function edit(index,key,value) { const next=Logic.clone(window.displayDraft); next[index][key]=value; window.displayDraft=next; window.displaysDirty=true; }
  Label { text:root.service.apiReason || 'Drag displays to arrange them, or enter coordinates below. Changes are tested before they are saved.'; wrapMode:Text.Wrap; Layout.fillWidth:true; color:root.tokens.muted }
  Rectangle {
    Layout.fillWidth:true; height:210; color:root.tokens.sunken; radius:12; clip:true
    Repeater {
      model:root.window.displayDraft
      Rectangle {
        id:monitor
        required property var modelData
        required property int index
        x:30+Number(modelData.position.split('x')[0])*0.08; y:40+Number(modelData.position.split('x')[1])*0.08
        width:Math.max(70,Number(modelData.mode.split('x')[0]) *0.07 || 134); height:78
        color:modelData.disabled ? root.tokens.surface : root.tokens.raised; border.color:root.tokens.cyan; radius:8
        Label { anchors.centerIn:parent; text:monitor.modelData.output; color:root.tokens.text }
        DragHandler { enabled:!root.service.apiReason && !root.service.busy && !root.service.testing; onActiveChanged:if(!active) root.edit(monitor.index,'position',Math.round((monitor.x-30)/0.08)+'x'+Math.round((monitor.y-40)/0.08)) }
      }
    }
  }
  Repeater {
    model:root.window.displayDraft
    Frame {
      id:display
      required property var modelData
      required property int index
      readonly property var live:root.service.inventory.find(m=>m.name===modelData.output) || ({})
      Layout.fillWidth:true
      enabled:!root.service.apiReason && !root.service.busy && !root.service.testing
      ColumnLayout {
        anchors.fill:parent
        RowLayout {
          Label { text:display.modelData.output; font.bold:true; color:root.tokens.text; Layout.fillWidth:true }
          Switch { text:'Enabled'; checked:!display.modelData.disabled; onToggled:root.edit(display.index,'disabled',!checked) }
        }
        GridLayout {
          columns:2; Layout.fillWidth:true; columnSpacing:16
          Label { text:'Resolution and refresh rate'; color:root.tokens.text }
          ComboBox { Layout.fillWidth:true; model:Array.from(new Set([display.modelData.mode,'preferred'].concat((display.live.availableModes || []).map(m=>m.replace(/Hz$/,''))))); currentIndex:model.indexOf(display.modelData.mode); onActivated:root.edit(display.index,'mode',model[currentIndex]) }
          Label { text:'Scale'; color:root.tokens.text }
          TextField { text:String(display.modelData.scale); onTextEdited:root.edit(display.index,'scale',Number(text)) }
          Label { text:'Position (X x Y)'; color:root.tokens.text }
          TextField { text:display.modelData.position; onTextEdited:root.edit(display.index,'position',text) }
          Label { text:'Rotation / flip'; color:root.tokens.text }
          ComboBox { model:['Normal','90°','180°','270°','Flipped','Flipped 90°','Flipped 180°','Flipped 270°']; currentIndex:display.modelData.transform; onActivated:root.edit(display.index,'transform',currentIndex) }
          Label { text:'Mirror'; color:root.tokens.text }
          ComboBox { model:[''].concat(root.window.displayDraft.filter(m=>m.output!==display.modelData.output).map(m=>m.output)); currentIndex:Math.max(0,model.indexOf(display.modelData.mirror)); onActivated:root.edit(display.index,'mirror',model[currentIndex]) }
          Label { text:display.live.vrrSupported===true ? 'VRR' : 'VRR · Unavailable: capability not advertised'; color:root.tokens.muted; wrapMode:Text.Wrap; Layout.maximumWidth:320 }
          ComboBox { enabled:display.live.vrrSupported===true; model:['Off','On','Fullscreen']; currentIndex:display.modelData.vrr; onActivated:root.edit(display.index,'vrr',currentIndex) }
          Label { text:display.live.supportsHDR===true ? 'HDR' : 'HDR · Unavailable: capability not advertised'; color:root.tokens.muted; wrapMode:Text.Wrap; Layout.maximumWidth:320 }
          Switch { enabled:display.live.supportsHDR===true; checked:display.modelData.cm==='hdr'; onToggled:root.edit(display.index,'cm',checked ? 'hdr':'srgb') }
          Label { text:display.live.supports10bit===true || display.live.bitDepth===10 ? 'Color depth' : '10-bit · Unavailable: capability not advertised'; color:root.tokens.muted; wrapMode:Text.Wrap; Layout.maximumWidth:320 }
          ComboBox { enabled:display.live.supports10bit===true || display.live.bitDepth===10; model:['8-bit','10-bit']; currentIndex:display.modelData.bitdepth===10 ? 1:0; onActivated:root.edit(display.index,'bitdepth',currentIndex===1 ? 10:8) }
        }
      }
    }
  }
  Label { visible:!root.window.displayDraft.length; text:'Unavailable: no display inventory'; color:root.tokens.muted }
}
