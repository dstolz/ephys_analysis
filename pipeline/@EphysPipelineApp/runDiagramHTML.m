function html = runDiagramHTML(~)
%runDiagramHTML  The page behind the Run tab's diagram of the run.
%   One box per pipeline step, in execution order and in the Diagram tab's
%   step colours, joined by arrows. The page itself is static: the app sends
%   the run's state as the HTML component's Data (refreshRunDiagram), and the
%   page's setup() redraws the boxes from it on every DataChanged event. The
%   boxes are built once and then updated in place, so the step underway
%   keeps its pulse, beating dot and moving stripes between updates; it is
%   scrolled into view whenever the run moves on to it.
%
%   See also refreshRunDiagram, resetRunDiagram, updateRunDiagram,
%   finishRunDiagram, flowChartHTML.

html = "<!DOCTYPE html><html><head><meta charset=""utf-8""><title>Run diagram</title><style>" ...
    + css() + "</style></head><body class=""phase-idle"">" ...
    + "<header id=""head""><div id=""headline"" aria-live=""polite""></div><div id=""sub""></div></header>" ...
    + "<main id=""chain""></main><script>" + js() + "</script></body></html>";
end


function s = js()
%js  Build the boxes from the first Data, then update them in place.
s = join([ ...
    "var built = '', active = '';"
    "function setup(htmlComponent) {"
    "  var draw = function () { render(htmlComponent.Data); };"
    "  htmlComponent.addEventListener('DataChanged', draw);"
    "  draw();"
    "}"
    "function add(parent, tag, cls) {"
    "  var e = document.createElement(tag);"
    "  if (cls) { e.className = cls; }"
    "  parent.appendChild(e);"
    "  return e;"
    "}"
    "function build(steps) {"
    "  var chain = document.getElementById('chain');"
    "  chain.innerHTML = '';"
    "  for (var i = 0; i < steps.length; i++) {"
    "    if (i > 0) { add(chain, 'div', 'link'); }"
    "    var box = add(chain, 'section', 'step');"
    "    box.id = 'step-' + steps[i].key;"
    "    var top = add(box, 'div', 'top');"
    "    add(top, 'span', 'icon'); add(top, 'span', 'title'); add(top, 'span', 'pill'); add(top, 'span', 'pct');"
    "    add(box, 'div', 'what');"
    "    add(add(box, 'div', 'bar'), 'div', 'fill');"
    "    add(box, 'div', 'now'); add(box, 'div', 'msg'); add(box, 'div', 'sum');"
    "  }"
    "}"
    "function put(box, cls, text) {"
    "  box.querySelector('.' + cls).textContent = (text === undefined || text === null) ? '' : String(text);"
    "}"
    "function render(d) {"
    "  if (!d || !d.steps) { return; }"
    "  var steps = Array.isArray(d.steps) ? d.steps : [d.steps];"
    "  var sig = steps.map(function (s) { return s.key; }).join(',');"
    "  if (sig !== built) { build(steps); built = sig; active = ''; }"
    "  document.body.className = 'phase-' + d.phase;"
    "  document.getElementById('headline').textContent = d.headline;"
    "  document.getElementById('sub').textContent = d.sub;"
    "  var run = '';"
    "  for (var i = 0; i < steps.length; i++) {"
    "    var s = steps[i], box = document.getElementById('step-' + s.key);"
    "    box.className = 'step s-' + s.key + ' is-' + s.state + (s.errors > 0 ? ' has-errors' : '');"
    "    put(box, 'title', s.title);"
    "    put(box, 'pill', s.label);"
    "    put(box, 'pct', s.inRun ? Math.floor(s.pct) + '%' : '');"
    "    put(box, 'what', s.what);"
    "    box.querySelector('.fill').style.width = Math.max(0, Math.min(100, s.pct)) + '%';"
    "    put(box, 'now', s.now); put(box, 'msg', s.msg); put(box, 'sum', s.summary);"
    "    if (s.state === 'running') { run = s.key; }"
    "  }"
    "  if (run && run !== active) {"
    "    var b = document.getElementById('step-' + run);"
    "    if (b.scrollIntoView) { b.scrollIntoView({block: 'nearest', behavior: 'smooth'}); }"
    "  }"
    "  active = run;"
    "}"
    ], newline);
end


function s = css()
s = join([ ...
    "*{box-sizing:border-box}"
    "body{font:12px/1.35 'Segoe UI',system-ui,sans-serif;color:#1f2328;background:#f4f5f7;margin:0;padding:8px 12px 14px}"
    "#head{background:#fff;border:1px solid #d0d7de;border-left:5px solid #8c959f;border-radius:8px;padding:6px 10px;margin:0 0 10px}"
    ".phase-running #head{border-left-color:#1f7fbf}"
    ".phase-done #head{border-left-color:#2e9e5b}"
    ".phase-cancelled #head{border-left-color:#d9822b}"
    ".phase-error #head{border-left-color:#cf222e}"
    "#headline{font-size:14px;font-weight:600}"
    "#sub{font-size:11px;color:#57606a;margin-top:1px;overflow-wrap:anywhere}"
    "#chain{display:flex;flex-direction:column}"
    % Arrow from one step to the next.
    ".link{align-self:center;position:relative;flex:none;width:2px;height:14px;background:#afb8c1}"
    ".link::after{content:'';position:absolute;left:-4px;bottom:-3px;border:5px solid transparent;border-top-color:#afb8c1;border-bottom-width:0}"
    % A step: accent colour per step, as on the Diagram tab (flowChartHTML).
    ".step{--acc:#8c959f;--tint:#f0f1f3;--glow:rgba(140,149,159,.45);background:#fff;border:1px solid #d0d7de;border-left:5px solid var(--acc);border-radius:8px;padding:6px 10px 7px;transition:background-color .3s,border-color .3s}"
    ".s-probe{--acc:#1b7c83;--tint:#e1f3f4;--glow:rgba(27,124,131,.45)}"
    ".s-behavior{--acc:#bf3989;--tint:#fbe9f3;--glow:rgba(191,57,137,.45)}"
    ".s-artifacts{--acc:#d9822b;--tint:#fdf0e2;--glow:rgba(217,130,43,.45)}"
    ".s-sorting{--acc:#8250df;--tint:#f1eafd;--glow:rgba(130,80,223,.45)}"
    ".s-signals{--acc:#1f7fbf;--tint:#e3f0fa;--glow:rgba(31,127,191,.45)}"
    ".s-spikes{--acc:#2e9e5b;--tint:#e3f5ea;--glow:rgba(46,158,91,.45)}"
    ".s-export{--acc:#6e7781;--tint:#eef0f2;--glow:rgba(110,119,129,.45)}"
    ".top{display:flex;align-items:center;gap:7px;min-height:18px}"
    ".icon{flex:none;width:10px;height:10px;border-radius:50%;border:2px solid var(--acc);background:#fff}"
    ".title{font-weight:600;font-size:13px}"
    ".pill{font-size:11px;line-height:16px;padding:0 7px;border-radius:8px;background:#eaeef2;color:#57606a;white-space:nowrap}"
    ".pct{margin-left:auto;font-weight:600;font-variant-numeric:tabular-nums;color:#57606a}"
    ".what{font-size:11px;color:#57606a;margin-top:1px}"
    ".bar{height:6px;border-radius:3px;background:#eaeef2;margin-top:6px;overflow:hidden}"
    ".fill{height:100%;width:0;border-radius:3px;background:var(--acc);transition:width .4s ease}"
    ".now,.msg,.sum{font-size:11px;margin-top:3px;overflow-wrap:anywhere}"
    ".now:empty,.msg:empty,.sum:empty{display:none}"
    ".msg,.sum{color:#57606a}"
    % Before a run: a preview of the steps that will run, no percentages.
    ".phase-idle .bar,.phase-idle .pct{display:none}"
    % Off in the config / not in this run.
    ".is-off{background:#f6f8fa;border-style:dashed;border-left-style:dashed;color:#8c959f;padding:4px 10px}"
    ".is-off .icon{border-color:#afb8c1}"
    ".is-off .what,.is-off .bar,.is-off .pct{display:none}"
    ".is-off .title{font-weight:400;font-size:12px}"
    % The step underway: tinted, thick accent border, pulsing ring, beating dot, moving stripes.
    ".is-running{background:var(--tint);border:2px solid var(--acc);border-left-width:7px;padding:8px 11px 9px;animation:pulse 1.6s ease-out infinite}"
    ".is-running .title{font-size:15px}"
    ".is-running .pill{background:var(--acc);color:#fff;font-weight:600;text-transform:uppercase;letter-spacing:.04em}"
    ".is-running .pct{font-size:18px;color:var(--acc)}"
    ".is-running .icon{background:var(--acc);animation:beat 1s ease-in-out infinite}"
    ".is-running .bar{height:12px;border-radius:6px;background:#fff}"
    ".is-running .fill{border-radius:6px;background-image:linear-gradient(45deg,rgba(255,255,255,.35) 25%,transparent 25%,transparent 50%,rgba(255,255,255,.35) 50%,rgba(255,255,255,.35) 75%,transparent 75%,transparent);background-size:16px 16px;animation:stripes .8s linear infinite}"
    ".is-running .now{font-weight:600}"
    ".is-done .icon{background:var(--acc)}"
    ".is-done .pill{background:#dafbe1;color:#116329}"
    ".is-done.has-errors .pill,.is-failed .pill{background:#ffebe9;color:#a40e26}"
    ".is-failed{border-color:#cf222e}"
    ".is-cancelled .pill,.is-notrun .pill{background:#fff1e5;color:#953800}"
    ".is-notrun{opacity:.7}"
    ".has-errors .sum{color:#a40e26;font-weight:600}"
    "@keyframes pulse{0%{box-shadow:0 0 0 0 var(--glow)}70%{box-shadow:0 0 0 9px rgba(0,0,0,0)}100%{box-shadow:0 0 0 0 rgba(0,0,0,0)}}"
    "@keyframes beat{0%,100%{transform:scale(1)}50%{transform:scale(1.3)}}"
    "@keyframes stripes{from{background-position:16px 0}to{background-position:0 0}}"
    "@media (prefers-reduced-motion:reduce){.is-running,.is-running .icon,.is-running .fill{animation:none}}"
    ], "");
end
