.pragma library
function downloadUrl(url) { return typeof url === "string" && /^https:\/\/w\.wallhaven\.cc\/full\/[a-z0-9]{2}\/wallhaven-[a-z0-9]+\.(jpg|png|webp)$/.test(url); }
function thumbnailUrl(url) { return typeof url === "string" && /^https:\/\/th\.wallhaven\.cc\/[a-z0-9/_.-]+$/.test(url); }
function searchUrl(request, key) {
  if (!request || !Number.isInteger(request.page) || request.page < 1 || request.page > 1000 || typeof request.query !== "string" || request.query.length > 2048 || !/^[a-zA-Z0-9]*$/.test(key)) throw new Error("Invalid Wallhaven search.");
  const f = request.filters || {};
  const values = {categories: f.categories || "111", purity: f.purity || "100",
    sorting: f.sorting || (request.query.trim() ? "relevance" : "date_added"), order: f.order || "desc"};
  if (!/^[01]{3}$/.test(values.categories) || values.categories === "000" || !/^[01]{3}$/.test(values.purity) || values.purity === "000") throw new Error("Select at least one category and content rating.");
  if (values.purity[2] === "1" && !key) throw new Error("NSFW search requires an API key.");
  if (!["date_added", "relevance", "random", "views", "favorites", "toplist"].includes(values.sorting) || !["desc", "asc"].includes(values.order)) throw new Error("Invalid Wallhaven sorting.");
  if (values.sorting === "toplist") {
    values.topRange = f.topRange || "1M";
    if (!["1d", "3d", "1w", "1M", "3M", "6M", "1y"].includes(values.topRange)) throw new Error("Invalid toplist range.");
  }
  for (const name of ["atleast", "resolutions", "ratios", "colors", "seed"]) {
    const value = f[name] || "";
    if (!value) continue;
    const pattern = name === "seed" ? /^[a-zA-Z0-9]{6}$/ : name === "colors" ? /^(660000|990000|cc0000|cc3333|ea4c88|993399|663399|333399|0066cc|0099cc|66cccc|77cc33|669900|336600|666600|999900|cccc33|ffff00|ffcc33|ff9900|ff6600|cc6633|996633|663300|000000|999999|cccccc|ffffff|424153)$/ : name === "ratios" ? /^(landscape|portrait|[1-9][0-9]{0,4}x[1-9][0-9]{0,4})$/ : /^[1-9][0-9]{0,4}x[1-9][0-9]{0,4}$/;
    if (typeof value !== "string" || !pattern.test(value)) throw new Error("Invalid Wallhaven " + name + " filter.");
    if (name !== "seed" || values.sorting === "random") values[name] = value;
  }
  if (values.atleast && values.resolutions) throw new Error("Choose minimum or exact resolution, not both.");
  values.q = request.query.trim(); values.page = request.page;
  return "https://wallhaven.cc/api/v1/search?" + Object.keys(values).map(name => name + "=" + encodeURIComponent(values[name])).join("&");
}
function parse(text, purity) {
  purity = purity || "100";
  const result = JSON.parse(text), meta = result.meta;
  if (!Array.isArray(result.data) || result.data.length > 100 || !meta || !Number.isSafeInteger(meta.current_page) || !Number.isSafeInteger(meta.last_page) || meta.current_page < 1 || meta.last_page < 1 || meta.current_page > meta.last_page) throw new Error("Invalid response");
  return {data: result.data.filter(e => e && ["sfw", "sketchy", "nsfw"].some((rating, index) => e.purity === rating && purity[index] === "1") && /^[a-z0-9]+$/.test(e.id) && downloadUrl(e.path)).map(e => ({id: e.id, path: e.path, resolution: typeof e.resolution === "string" ? e.resolution : "", thumbs: {large: e.thumbs && thumbnailUrl(e.thumbs.large) ? e.thumbs.large : "", small: e.thumbs && thumbnailUrl(e.thumbs.small) ? e.thumbs.small : ""}})), meta: meta};
}
function httpError(code) {
  if (code === "401" || code === "403") return "Wallhaven authentication failed. Check the API key.";
  if (code === "429") return "Wallhaven rate limit reached. Try again later.";
  return "Wallhaven request failed (HTTP " + code + ").";
}
