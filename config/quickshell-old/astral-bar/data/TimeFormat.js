.pragma library

function pad2(value) {
  const number = Number(value);
  return number < 10 ? "0" + number : String(number);
}

// Converts an absolute timestamp to the wall-clock fields of a fixed UTC offset.
// The returned fields can be formatted without relying on the system timezone.
function zoned(timestamp, offsetSeconds) {
  const instant = Number.isFinite(timestamp) ? timestamp : Date.now();
  const offset = Number.isFinite(offsetSeconds) ? offsetSeconds : 0;
  const date = new Date(instant + offset * 1000);
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth(),
    day: date.getUTCDate(),
    weekday: date.getUTCDay(),
    hour: date.getUTCHours(),
    minute: date.getUTCMinutes()
  };
}

function clockText(parts, twelveHour) {
  if (!parts) return "--:--";
  if (!twelveHour) return pad2(parts.hour) + ":" + pad2(parts.minute);
  const hour = parts.hour % 12 || 12;
  return pad2(hour) + ":" + pad2(parts.minute);
}

function periodText(parts) {
  return parts && parts.hour >= 12 ? "PM" : "AM";
}

function offsetLabel(offsetSeconds) {
  const total = Math.round(Math.abs(Number(offsetSeconds) || 0) / 60);
  const sign = Number(offsetSeconds) < 0 ? "-" : "+";
  return "UTC" + sign + pad2(Math.floor(total / 60)) + ":" + pad2(total % 60);
}
