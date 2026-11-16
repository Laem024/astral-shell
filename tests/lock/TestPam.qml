import Quickshell
Scope {
  property string config
  property string configDirectory
  property int starts: 0
  property int responses: 0
  property int lastResponseLength: 0
  property bool failStart: false
  property bool messageIsError: false
  property bool active: false
  property bool responseRequired: false
  signal pamMessage()
  signal completed(int result)
  function start(): bool {
    starts++;
    if (failStart) return false;
    active = true; messageIsError = false; responseRequired = true; pamMessage();
    return true;
  }
  function respond(response: string): void {
    responses++;
    lastResponseLength = response.length;
    // Deliberately keep responseRequired true to simulate a delayed backend.
    // The UI must still immediately block duplicate submissions.
  }
  function finish(result: int): void { responseRequired = false; active = false; completed(result); }
}
