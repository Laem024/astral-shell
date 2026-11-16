import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

// The AuthFlow type is returned by PolkitAgent.flow but is not exposed to
// qmllint's type information, so its members are resolved at runtime.
// qmllint disable unresolved-type
Scope {
  id: root

  readonly property bool registered: agent.isRegistered
  readonly property bool active: agent.isActive
  readonly property var flow: agent.flow

  signal requestStarted()
  signal requestFinished()

  function submit(value: string): void {
    if (!agent.isActive || !agent.flow || !agent.flow.isResponseRequired) return;
    agent.flow.submit(value);
  }
  function cancel(): void {
    if (!agent.isActive || !agent.flow) return;
    agent.flow.cancelAuthenticationRequest();
  }
  function select(identity): void {
    if (!agent.isActive || !agent.flow || !identity) return;
    agent.flow.selectedIdentity = identity;
  }

  PolkitAgent {
    id: agent
    // A stable path keeps the agent registered across configuration reloads.
    path: "/org/astral/shell/PolkitAgent"
    onAuthenticationRequestStarted: root.requestStarted()
  }

  Connections {
    target: agent.flow
    function onIsCompletedChanged(): void {
      if (agent.flow && agent.flow.isCompleted) root.requestFinished();
    }
  }

  IpcHandler {
    target: "polkit"
    function state(): string { return root.registered ? "ready" : "loading"; }
    function registered(): bool { return root.registered; }
    function active(): bool { return root.active; }
    function action(): string { return root.active && root.flow ? root.flow.actionId : ""; }
    function cancel(): string {
      if (!root.active) return "inactive";
      root.cancel();
      return "cancelled";
    }
  }
}
