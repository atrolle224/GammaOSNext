"use strict";
const NAMES = {GC:"GameCube",PS2:"PS2",N64:"N64",PSP:"PSP",XBOX:"Xbox",SNES:"SNES",GBA:"GBA"};
const ORDER = ["PS2","GC","XBOX","N64","PSP","GBA","SNES"];
const QUEUE_MAX = 10;
const DAY = 86400000;

const key = g => g[0] + "|" + g[1];
const byKey = new Map(GAMES.map(g => [key(g), g]));
// g[7]: HowLongToBeat's main story, hours
const len = g => g[7] == null ? "" : g[7] > 25 ? "L" : g[7] > 12 ? "M" : "S";

let st = {s:{}, q:[]};
try { st = Object.assign(st, JSON.parse(localStorage.getItem("pn.v1") || "{}")); } catch (e) {}
const save = () => { try { localStorage.setItem("pn.v1", JSON.stringify(st)); } catch (e) {} };
const status = k => (st.s[k] || {}).s || "";
const slot = s => Object.keys(st.s).find(k => st.s[k].s === s);

function setStatus(k, s) {
  st.q = st.q.filter(x => x !== k);
  if (s === "main" || s === "side") {
    const old = slot(s);
    if (old && old !== k) { st.s[old] = {s:"next", t:Date.now()}; st.q.unshift(old); }
  }
  if (!s) delete st.s[k];
  else st.s[k] = {s, t:Date.now()};
  if (s === "next") st.q.push(k);
  st.q = st.q.slice(0, 50);
  save();
}

const esc = s => String(s).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const cls = s => s == null ? "sn" : s >= 90 ? "s90" : s >= 80 ? "s80" : s >= 70 ? "s70" : "slow";
const sc = g => `<span class="sc ${cls(g[2])}">${g[2] == null ? "–" : g[2] + (g[3] === "I" ? "*" : "")}</span>`;
const lenTag = g => len(g) ? `<span class="len ${len(g)}">${Math.round(g[7]) || "<1"}h</span>` : "";
const row = g => `<button class="row" data-f data-k="${esc(key(g))}">${sc(g)}<span class="n">${esc(g[1])}</span>${lenTag(g)}<span class="sys">${NAMES[g[0]]}</span></button>`;
const ago = t => { const d = Math.floor((Date.now() - t) / DAY); return d <= 0 ? "today" : d === 1 ? "yesterday" : d + " days ago"; };

// Candidates: scored, untouched, best first; a bit of chance so the same three don't always come up.
function candidates(f) {
  return GAMES.filter(g => g[2] != null && !status(key(g))
    && (!f.sys || g[0] === f.sys) && (!f.len || (f.len === "L" ? len(g) === "L" || len(g) === "M" : len(g) === "S"))
    && g[2] >= f.min);
}
function pickSome(f, n) {
  const pool = candidates(f).map(g => [g, Math.pow(g[2] - 60, 3) * Math.random()]);
  return pool.sort((a, b) => b[1] - a[1]).slice(0, n).map(x => x[0]);
}

let tab = "now", pickF = {sys:"", len:"", min:85}, picks = null, lib = {sys:"", q:"", min:0, show:120};

function viewNow() {
  const m = slot("main"), s = slot("side");
  const sl = (k, label, help) => `<div class="card"><div class="lbl">${label}</div>${k ? row(byKey.get(k)) + `<div class="muted" style="font-size:13px">Started ${ago(st.s[k].t)}. ${help}</div>` : `<button data-f data-act="fill-${label === "Main game" ? "main" : "side"}">Choose a ${label.toLowerCase()}</button><div class="muted" style="font-size:13px;margin-top:6px">${label === "Main game" ? "A game over 12 hours: an RPG, an adventure." : "Under 12 hours: something to finish in a few sittings."}</div>`}</div>`;
  const q = st.q.map(k => byKey.get(k)).filter(Boolean);
  const done = Object.values(st.s).filter(x => x.s === "done").length;
  return `<h2>Playing now</h2><div class="slot">${sl(m, "Main game", "Not hooked after about 5 hours? Drop it, no guilt.")}${sl(s, "Side game", "Not hooked after an hour? Drop it.")}</div>
  <h2>Up next (${q.length}/${QUEUE_MAX})</h2>${q.slice(0, QUEUE_MAX).map(row).join("") || `<div class="empty">Your shortlist is empty.</div>`}
  ${q.length < QUEUE_MAX ? `<button data-f data-act="fill">Fill up next with ${QUEUE_MAX - q.length} top picks</button>` : ""}
  <h2>Progress</h2><div class="stat"><div class="card"><div class="big">${done}</div><div class="muted">finished</div></div><div class="card"><div class="big">${candidates({sys:"",len:"",min:90}).length}</div><div class="muted">90+ games left</div></div><div class="card"><div class="big">${candidates({sys:"",len:"",min:0}).length}</div><div class="muted">scored, untouched</div></div></div>`;
}

function chips(name, opts, cur) {
  return `<div class="chips">${opts.map(([v, l]) => `<button data-f data-row data-chip="${name}" data-v="${v}" class="${String(cur) === String(v) ? "on" : ""}">${l}</button>`).join("")}</div>`;
}

function viewPick() {
  if (!picks) picks = pickSome(pickF, 3);
  return `<h2>Pick for me</h2>
  ${chips("len", [["", "Any length"], ["L", "Over 12h"], ["S", "Under 12h"]], pickF.len)}
  ${chips("min", [[90, "90+"], [85, "85+"], [80, "80+"], [0, "Any score"]], pickF.min)}
  ${chips("psys", [["", "All"]].concat(ORDER.map(s => [s, NAMES[s]])), pickF.sys)}
  ${picks.map(row).join("") || `<div class="empty">Nothing left for these filters.</div>`}
  <button data-f data-act="reroll">Three more (Y)</button>
  <p class="muted" style="font-size:13px">Higher scores come up more often, but not always: a little chance keeps the list from showing the same games every time.</p>`;
}

function viewLib() {
  const q = lib.q.toLowerCase();
  const list = GAMES.filter(g => (!lib.sys || g[0] === lib.sys) && (!q || g[1].toLowerCase().includes(q)) && (lib.min ? g[2] != null && g[2] >= lib.min : true))
    .sort((a, b) => (b[2] ?? -1) - (a[2] ?? -1) || a[1].localeCompare(b[1]));
  return `<input type="search" id="q" placeholder="Search (touch)" value="${esc(lib.q)}">
  ${chips("lsys", [["", "All"]].concat(ORDER.map(s => [s, NAMES[s]])), lib.sys)}
  ${chips("lmin", [[0, "Any score"], [90, "90+"], [80, "80+"]], lib.min)}
  <div class="muted" style="margin:4px 0 8px;font-size:13px">${list.length} games · * IGN score where Metacritic has none · X adds to Up next</div>
  ${list.slice(0, lib.show).map(g => row(g).replace('<span class="sys">', `<span class="sys">${status(key(g)) ? "● " : ""}`)).join("")}
  ${list.length > lib.show ? `<button data-f data-act="more">Show more (${list.length - lib.show} left)</button>` : ""}`;
}

function viewDone() {
  const of = s => Object.entries(st.s).filter(([, v]) => v.s === s).sort((a, b) => b[1].t - a[1].t).map(([k, v]) => [byKey.get(k), v]).filter(x => x[0]);
  const list = xs => xs.map(([g, v]) => row(g).replace('<span class="sys">', `<span class="sys">${new Date(v.t).toLocaleDateString()} · `)).join("");
  const d = of("done"), x = of("drop");
  return `<h2>Finished (${d.length})</h2>${list(d) || `<div class="empty">Nothing yet. Credits rolling counts.</div>`}
  <h2>Dropped (${x.length})</h2>${list(x) || `<div class="empty">Nothing dropped. Dropping a game that isn't clicking is part of the plan.</div>`}`;
}

function viewPlan() {
  return `<div class="plan"><h2>The plan</h2>
  <p>Built from how people with huge backlogs and full ROM sets actually get through them. The common thread: <b>a full library is a museum, not a to-do list</b>. Choose from a short list, not from 1,400 games.</p>
  <ol>
  <li><b>Two games at a time.</b> One long Main game (over 12 hours) and one short Side game (under 12). Play the Side game when you have 20 minutes or need a break from the Main.</li>
  <li><b>A shortlist of 10.</b> Up next holds at most ten. When a slot frees up, take the top of Up next instead of browsing the whole library.</li>
  <li><b>Best first.</b> Start with the 90+ games: they are the ones the most people loved, and they teach you what you like.</li>
  <li><b>Quit freely.</b> Not hooked after about an hour (short) or five hours (long)? Mark it Dropped. That's a decision, not a failure.</li>
  <li><b>Done means credits.</b> Main story finished counts as finished. No 100% unless you want it.</li>
  <li><b>Stuck choosing?</b> Press Y for three picks and take one within a minute.</li>
  <li><b>Mix it up.</b> After a long RPG, take something short, or another system, before the next long one.</li>
  </ol>
  <h2>Controls</h2>
  <p>D-pad moves · A opens · B goes back · L1/R1 switch tabs · X adds to Up next · Y picks for you.</p>
  <h2>Scores</h2>
  <p>Metacritic's score where it has one; IGN's review ×10 (marked *) for older games Metacritic never rated. Hours are HowLongToBeat's main-story times, where known. Many SNES, N64 and GBA games have no score at all: that says nothing about their quality.</p></div>`;
}

const VIEWS = {now:viewNow, pick:viewPick, lib:viewLib, done:viewDone, plan:viewPlan};
const TABS = ["now", "pick", "lib", "done", "plan"];
let focus = 0;

function render(keepFocus) {
  document.querySelectorAll("nav [data-tab]").forEach(b => b.classList.toggle("on", b.dataset.tab === tab));
  const main = document.querySelector("main");
  main.innerHTML = VIEWS[tab]();
  const qi = document.getElementById("q");
  if (qi) qi.oninput = () => { lib.q = qi.value; lib.show = 120; const p = qi.selectionStart; render(true); const n = document.getElementById("q"); n.focus(); n.setSelectionRange(p, p); };
  if (!keepFocus) { focus = 0; main.scrollTop = 0; }
  showFocus();
}

const items = () => sheetOpen() ? [...document.querySelectorAll("#sheet [data-f]")] : [...document.querySelectorAll("main [data-f]")];
function showFocus(scroll) {
  document.querySelectorAll(".focus").forEach(e => e.classList.remove("focus"));
  const it = items();
  if (!it.length) return;
  focus = Math.max(0, Math.min(focus, it.length - 1));
  it[focus].classList.add("focus");
  if (scroll) it[focus].scrollIntoView({block:"nearest"});
}

const sheetOpen = () => document.getElementById("sheet").classList.contains("open");
let sheetReturn = 0;
function openSheet(k) {
  const g = byKey.get(k), s = status(k);
  const act = (a, l) => `<button data-f data-sa="${a}">${l}</button>`;
  document.querySelector("#sheet .box").innerHTML = `<div class="row">${sc(g)}<span class="n big">${esc(g[1])}</span></div>
  <div class="muted">${NAMES[g[0]]} · ${esc(g[5] || "genre unknown")} · ${esc(g[6] || "")}${g[7] != null ? " · about " + g[7] + " h to finish" : ""}${g[4] ? " · user score " + g[4] : ""}${s ? " · now: " + {next:"Up next", main:"Main game", side:"Side game", done:"Finished", drop:"Dropped"}[s] : ""}</div>
  ${s !== "main" ? act("main", "Play as Main game") : ""}${s !== "side" ? act("side", "Play as Side game") : ""}
  ${s !== "next" ? act("next", "Add to Up next") : act("top", "Move to top of Up next")}
  ${s === "main" || s === "side" ? act("done", "Finished it") + act("drop", "Drop it") : ""}
  ${s ? act("", s === "done" || s === "drop" ? "Back in the library" : "Take off my lists") : ""}
  ${act("close", "Close")}`;
  const sh = document.getElementById("sheet");
  sh.dataset.k = k;
  sheetReturn = focus;
  sh.classList.add("open");
  focus = 0; showFocus();
}
function closeSheet() { document.getElementById("sheet").classList.remove("open"); focus = sheetReturn; render(true); showFocus(true); }

function act(el) {
  if (el.dataset.tab) { tab = el.dataset.tab; render(); return; }
  if (el.dataset.sa !== undefined) {
    const k = document.getElementById("sheet").dataset.k, a = el.dataset.sa;
    if (a === "top") { st.q = [k].concat(st.q.filter(x => x !== k)); save(); }
    else if (a !== "close") setStatus(k, a);
    if (tab === "pick" && a !== "close") picks = picks.filter(g => key(g) !== k);
    closeSheet(); return;
  }
  if (el.dataset.k) { openSheet(el.dataset.k); return; }
  if (el.dataset.chip) {
    const v = el.dataset.v, c = el.dataset.chip;
    if (c === "len") pickF.len = v; if (c === "min") pickF.min = +v; if (c === "psys") pickF.sys = v;
    if (c === "lsys") lib.sys = v; if (c === "lmin") lib.min = +v;
    if (c[0] === "l" && c !== "len") lib.show = 120; else picks = null;
    render(true); return;
  }
  const a = el.dataset.act;
  if (a === "reroll") { picks = null; render(true); }
  else if (a === "more") { lib.show += 120; render(true); }
  else if (a === "fill") { fill(); render(true); }
  else if (a === "fill-main" || a === "fill-side") { pickF.len = a === "fill-main" ? "L" : "S"; picks = null; tab = "pick"; render(); }
}

// Top picks spread over the systems, longs and shorts alternating.
function fill() {
  const want = QUEUE_MAX - st.q.length;
  const used = new Set(), out = [];
  for (let i = 0; out.length < want && i < 200; i++) {
    const sys = ORDER[i % ORDER.length], l = (out.length % 2) ? "S" : "L";
    const g = candidates({sys, len:l, min:85}).filter(g => !used.has(key(g))).sort((a, b) => b[2] - a[2])[0]
      || candidates({sys, len:"", min:85}).filter(g => !used.has(key(g))).sort((a, b) => b[2] - a[2])[0];
    if (g) { used.add(key(g)); out.push(g); }
  }
  out.forEach(g => setStatus(key(g), "next"));
}

function moveFocus(d) { focus += d; showFocus(true); }
function rowMove(d) {
  const it = items(), el = it[focus];
  if (el && el.hasAttribute("data-row")) { const n = it[focus + d]; if (n && n.parentElement === el.parentElement) moveFocus(d); return; }
  if (tab === "lib" && !sheetOpen()) moveFocus(d * 10);
}

window.pad = function (k) {
  if (k === "up") moveFocus(-1);
  else if (k === "down") moveFocus(1);
  else if (k === "left") rowMove(-1);
  else if (k === "right") rowMove(1);
  else if (k === "a") { const el = items()[focus]; if (el) act(el); }
  else if (k === "b") {
    if (sheetOpen()) { closeSheet(); return true; }
    if (tab !== "now") { tab = "now"; render(); return true; }
    return false;
  }
  else if ((k === "l1" || k === "r1") && !sheetOpen()) { tab = TABS[(TABS.indexOf(tab) + (k === "r1" ? 1 : TABS.length - 1)) % TABS.length]; render(); }
  else if (k === "y" && !sheetOpen()) { tab = "pick"; picks = null; render(); }
  else if (k === "x" && !sheetOpen()) { const el = items()[focus]; if (el && el.dataset.k && !status(el.dataset.k)) { setStatus(el.dataset.k, "next"); if (tab === "pick") picks = picks.filter(g => key(g) !== el.dataset.k); render(true); showFocus(true); } }
  else if (k === "l2") moveFocus(-10);
  else if (k === "r2") moveFocus(10);
  return true;
};

document.addEventListener("click", e => {
  const el = e.target.closest("[data-f], nav [data-tab]");
  if (!el) { if (e.target.id === "sheet") closeSheet(); return; }
  const it = items(), i = it.indexOf(el);
  if (i >= 0) focus = i;
  act(el);
});
document.addEventListener("keydown", e => {
  if (e.target.id === "q") return;
  const m = {ArrowUp:"up", ArrowDown:"down", ArrowLeft:"left", ArrowRight:"right", Enter:"a", Escape:"b", x:"x", y:"y", q:"l1", e:"r1"}[e.key];
  if (m) { e.preventDefault(); pad(m); }
});
render();
