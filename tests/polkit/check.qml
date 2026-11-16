import QtQuick
import Quickshell
import Quickshell.Io
import "astral-polkit" as Polkit
import "common" as Common
ShellRoot {
  id: root
  function check(ok, message) { if (!ok) { console.error("POLKIT_FAIL: " + message); Qt.exit(1); } }
  QtObject {
    id: flow
    property bool isResponseRequired: true
    property bool isCompleted: false
    property bool responseVisible: false
    property bool failed: false
    property string supplementaryMessage: ""
    property bool supplementaryIsError: false
    property string message: "Simulated authentication"
    property string inputPrompt: "Password:"
    property string actionId: "org.astral.test"
    property var identities: [{id:1000, string:"first", displayName:"First", isGroup:false}, {id:1001, string:"second", displayName:"Second", isGroup:false}]
    property var selectedIdentity: identities[0]
    property string answer: ""
    property bool cancelled: false
    function submit(value) { answer = value; isResponseRequired = false; }
    function cancelAuthenticationRequest() { cancelled = true; }
  }
  QtObject {
    id: backend
    property bool isRegistered: true
    property bool isActive: true
    property var flow: flow
    signal authenticationRequestStarted()
  }
  Polkit.PolkitService { id: service; useNative: false; backend: backend; blocked: false }
  Common.Theme { id: theme; settings: Common.SettingsData }
  Polkit.PolkitContent {
    id: content
    width: 800; height: 650
    service: service; tokens: theme
    onSubmitRequested: value => service.submit(value)
    onCancelRequested: service.cancel()
  }
  Polkit.PolkitDialog { id: dialog; service: service; tokens: theme }
  IpcHandler {
    target: "test"
    function deactivate(): void { backend.isActive = false; }
    function unregister(): void { backend.isRegistered = false; }
  }
  Component.onCompleted: {
    if (Quickshell.env("ASTRAL_POLKIT_IPC") !== "1") Qt.callLater(runChecks);
  }
  function runChecks() {
    check(service.registered && service.active, "backend state");
    content.password = "secret";
    content.submit();
    check(flow.answer === "secret" && content.password === "", "submit clears input");
    flow.isResponseRequired = true;
    content.password = "old identity";
    service.select(flow.identities[1]);
    check(flow.selectedIdentity.id === 1001 && content.password === "", "identity clears input");
    content.password = "failed response";
    flow.supplementaryIsError = true;
    flow.supplementaryMessage = "Try again";
    check(content.password === "", "failure clears input");
    content.password = "private";
    service.blocked = true;
    check(content.password === "", "privacy clears input");
    service.submit("blocked");
    check(flow.answer === "secret", "privacy prevents submit");
    service.blocked = false;
    content.password = "cancelled";
    content.cancel();
    check(flow.cancelled && content.password === "", "cancel clears input");
    content.password = "IPC cancellation";
    service.cancel();
    check(content.password === "", "service cancel clears all content immediately");
    content.password = "finished";
    flow.isCompleted = true;
    check(content.password === "", "completion clears input");
    check(dialog.opened && dialog.testSurface, "unlocked dialog exists");
    dialog.testSurface.password = "private surface input";
    service.blocked = true;
    check(!dialog.opened && !dialog.testSurface, "blocked dialog destroyed immediately");
    service.blocked = false;
    check(dialog.testSurface && dialog.testSurface.password === "", "unlock recreates empty dialog");
    // An unknown logind state has the same fail-closed surface policy.
    Common.Privacy.blocked = true;
    service.blocked = Qt.binding(() => Common.Privacy.blocked);
    check(!dialog.opened && !dialog.testSurface, "unknown privacy destroys dialog");
    Common.Privacy.blocked = false;
    check(dialog.testSurface && dialog.testSurface.password === "", "confirmed unlock restores request");
    backend.isActive = false;
    check(!dialog.testSurface, "completion destroys dialog");
    console.log("POLKIT_FLOW_PASS"); Qt.exit(0);
  }
}
