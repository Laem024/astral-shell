// nmcli terse mode escapes both ':' and '\\'. Never trim SSIDs.
function rows(text) {
  return text.split("\n").filter(line => line !== "").map(line => {
    let fields = [], value = "", escaped = false;
    for (let i = 0; i < line.length; ++i) {
      const c = line[i];
      if (escaped) { value += c; escaped = false; }
      else if (c === "\\") escaped = true;
      else if (c === ":") { fields.push(value); value = ""; }
      else value += c;
    }
    if (escaped) value += "\\";
    fields.push(value);
    return fields;
  });
}
function networks(text) {
  const grouped = {};
  rows(text).forEach(f => {
    if (!f[2]) return;
    const key = JSON.stringify([f[0], f[2], f[4]]);
    const old = grouped[key];
    const item = {device:f[0], active:f[1] === "*", ssid:f[2], signal:Number(f[3]) || 0, security:f[4] || "--"};
    if (!old) grouped[key] = item;
    else if (item.active) { old.signal = item.signal; old.active = true; }
    else if (!old.active) old.signal = Math.max(old.signal, item.signal);
  });
  return Object.keys(grouped).map(k => grouped[k]).sort((a,b) => Number(b.active)-Number(a.active) || b.signal-a.signal);
}
function compatible(security, key) {
  if (!security || security === "--") return !key || key === "--" || key === "owe";
  if (/802.1X|EAP/.test(security)) return key === "wpa-eap" || key === "wpa-eap-suite-b-192";
  if (/WPA3/.test(security) && key === "sae") return true;
  return /WPA[12]/.test(security) && key === "wpa-psk";
}

// Property queries include empty values: keep their positions (not table rows).
function values(text) {
  const lines = text.split("\n");
  if (lines[lines.length - 1] === "") lines.pop();
  return lines.map(line => (rows(line)[0] || [""])[0]);
}
