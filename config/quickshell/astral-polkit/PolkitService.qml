import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import "../common" as Common

// The AuthFlow type is returned by PolkitAgent.flow but is not exposed to
// qmllint's type information, so its members are resolved at runtime.
// qmllint disable unresolved-type
Scope {
  id: root

  property bool useNative: true
  property var backend: nativeAgent.item
  property bool blocked: Common.Privacy.blocked
  readonly property bool registered: !!(backend && backend.isRegistered)
  readonly property bool active: !!(backend && backend.isActive)
  readonly property var flow: backend ? backend.flow : null

  signal responseCleared()
  onBlockedChanged: if (blocked) responseCleared()
  onFlowChanged: responseCleared()

  signal requestStarted()
  signal requestFinished()

  function submit(value: string): void {
    if (blocked || !root.active || !root.flow || !root.flow.isResponseRequired) return;
    responseCleared();
    root.flow.submit(value);
  }
  function cancel(): void {
    if (!root.active || !root.flow) return;
    responseCleared();
    root.flow.cancelAuthenticationRequest();
  }
  function select(identity): void {
    if (blocked || !root.active || !root.flow || !identity) return;
    responseCleared();
    root.flow.selectedIdentity = identity;
  }

  LazyLoader {
    id: nativeAgent
    active: root.useNative
    component: Component {
      PolkitAgent { path: "/org/astral/shell/PolkitAgent" }
    }
  }
  Connections {
    target: root.backend
    function onAuthenticationRequestStarted() { root.requestStarted(); }
  }

  Timer {
    interval: 5000; running: !root.registered
    onTriggered: console.error("Astral Polkit agent did not register; check for another authentication agent.")
  }

  Connections {
    target: root.flow
    function onIsCompletedChanged(): void {
      if (root.flow && root.flow.isCompleted) root.requestFinished();
    }
  }

  IpcHandler {
    target: "polkit"
    function state(): string { return root.registered ? "ready" : "loading"; }
    function registered(): bool { return root.registered; }
    function active(): bool { return root.active; }
    function action(): string { return root.active && root.flow ? root.flow.actionId : ""; }
    function closeActive(): string {
      if (!root.active) return "inactive";
      root.cancel();
      return "closed";
    }
    function cancel(): string {
      if (!root.active) return "inactive";
      root.cancel();
      return "cancelled";
    }
  }
}
