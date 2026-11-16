.pragma library

function pidForAddress(text, address) {
  const target = String(address || "").replace(/^0x/, "");
  if (!target) return 0;
  try {
    const clients = JSON.parse(text);
    if (!Array.isArray(clients)) return 0;
    for (const client of clients) {
      if (!client || String(client.address || "").replace(/^0x/, "") !== target) continue;
      return typeof client.pid === "number" && Number.isInteger(client.pid) && client.pid > 1
        ? client.pid : 0;
    }
  } catch (_) {}
  return 0;
}
