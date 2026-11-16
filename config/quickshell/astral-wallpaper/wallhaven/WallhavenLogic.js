.pragma library
function downloadUrl(url) { return typeof url === "string" && /^https:\/\/w\.wallhaven\.cc\/full\/[a-z0-9]{2}\/wallhaven-[a-z0-9]+\.(jpg|png|webp)$/.test(url); }
function thumbnailUrl(url) { return typeof url === "string" && /^https:\/\/th\.wallhaven\.cc\/[a-z0-9/_.-]+$/.test(url); }
function parse(text) {
  const result = JSON.parse(text), meta = result.meta;
  if (!Array.isArray(result.data) || result.data.length > 100 || !meta || !Number.isInteger(meta.current_page) || !Number.isInteger(meta.last_page) || meta.current_page < 1 || meta.last_page < 1 || meta.last_page > 10000 || meta.current_page > meta.last_page) throw new Error("Invalid response");
  return {data: result.data.filter(e => e && e.purity === "sfw" && /^[a-z0-9]+$/.test(e.id) && downloadUrl(e.path)).map(e => ({id: e.id, path: e.path, resolution: typeof e.resolution === "string" ? e.resolution : "", thumbs: {large: e.thumbs && thumbnailUrl(e.thumbs.large) ? e.thumbs.large : "", small: e.thumbs && thumbnailUrl(e.thumbs.small) ? e.thumbs.small : ""}})), meta: meta};
}
function httpError(code) {
  if (code === "401" || code === "403") return "Wallhaven authentication failed. Check the API key.";
  if (code === "429") return "Wallhaven rate limit reached. Try again later.";
  return "Wallhaven request failed (HTTP " + code + ").";
}
