function z = flowZoom(key, initial)
%flowZoom  The Diagram pages' zoom and pan: a viewport, its buttons and script.
%   Z = flowZoom(KEY, INITIAL) returns what a Diagram page (flowChartHTML,
%   flowOverviewHTML) wraps its drawing in:
%     open, close  HTML around the drawing: a viewport (filling the rest of
%                  the page) with the zoom buttons, and the stage it moves
%     css, js      the rules and the script (put the page's own after them)
%   The stage is scaled and moved inside the viewport: the mouse wheel zooms
%   about the pointer, a drag pans (the click that ends a drag opens no
%   box), and the buttons zoom out, back to 100%, in, and fit the whole
%   drawing in view (below the buttons). INITIAL is where a page starts:
%   "fit" (the whole drawing) or "actual" (100%, from the top, centred
%   across, as the detail view's tree is). Until it is zoomed or panned,
%   the page keeps that view as the viewport resizes.
%
%   The script defines flowZoom for the page's setup() (the app only):
%     flowZoom.restore(v)   the view the page was last left in (from
%                           htmlComponent.Data; ignored unless one)
%     flowZoom.onChange(f)  f({key, auto, scale, x, y}) after each zoom or pan
%                           (debounced); KEY names the page's view, AUTO is
%                           "fit" / "actual" while the page follows one
%   The app keeps them per view (FlowZoom, onFlowNavigate) and hands the
%   last one back when it redraws the page (refreshFlowChart).
%
%   A printed page is drawn whole, at 100%, without the buttons.

z.open = "<div class=""zoomview"" data-key=""" + key + """ data-initial=""" + initial + """>" ...
    + "<div class=""zoomctl"">" ...
    + "<button type=""button"" data-z=""out"" title=""Zoom out"">&minus;</button>" ...
    + "<button type=""button"" data-z=""actual"" class=""pct"" title=""Actual size"">100%</button>" ...
    + "<button type=""button"" data-z=""in"" title=""Zoom in"">+</button>" ...
    + "<button type=""button"" data-z=""fit"" class=""fit"" title=""Fit the whole diagram in view"">Fit</button>" ...
    + "</div><div class=""zoomstage"">";
z.close = "</div></div>";

z.css = join([ ...
    "html,body{height:100%}"
    "body{display:flex;flex-direction:column;box-sizing:border-box;overflow:hidden}"
    "body>*{flex:none}"
    ".zoomview{position:relative;flex:1 1 auto;min-height:120px;overflow:hidden;cursor:grab;user-select:none;touch-action:none}"
    ".zoomview.panning,.zoomview.panning *{cursor:grabbing!important}"
    ".zoomstage{position:absolute;left:0;top:0;width:100%;box-sizing:border-box;padding-bottom:12px;transform-origin:0 0}"
    ".zoomctl{position:absolute;top:8px;right:8px;z-index:2;display:flex;gap:4px;cursor:default}"
    ".zoomctl button{height:30px;min-width:32px;padding:0 9px;font:600 16px/1 'Segoe UI',system-ui,sans-serif;color:#fff;background:#1f7fbf;border:1px solid #17649a;border-radius:6px;box-shadow:0 1px 3px rgba(0,0,0,.2);cursor:pointer}"
    ".zoomctl button:hover{background:#17649a}"
    ".zoomctl button:focus-visible{outline:2px solid #0b3d5e;outline-offset:1px}"
    ".zoomctl .pct{min-width:56px;font-size:12.5px;color:#1f7fbf;background:#fff;border-color:#1f7fbf}"
    ".zoomctl .pct:hover{background:#e3f0fa}"
    ".zoomctl .fit{font-size:12.5px}"
    "@media print{html,body{height:auto;overflow:visible;display:block}"
    ".zoomview{overflow:visible}.zoomstage{position:static;transform:none!important}.zoomctl{display:none}}"
    ], "");

z.js = join([ ...
    "var flowZoom = (function () {"
    "  var view = document.querySelector('.zoomview'), stage = document.querySelector('.zoomstage');"
    "  var ctl = view.querySelector('.zoomctl'), pct = ctl.querySelector('.pct');"
    "  var MIN = 0.1, MAX = 4, PAD = 12, STEP = 1.25;"
    "  var s = 1, x = 0, y = 0, auto = view.getAttribute('data-initial'), listener = null, timer = null;"
    "  function clamp(v) { return Math.min(MAX, Math.max(MIN, v)); }"
    "  function draw(report) {"
    "    stage.style.transform = 'translate(' + x + 'px,' + y + 'px) scale(' + s + ')';"
    "    pct.textContent = Math.round(s * 100) + '%';"
    "    if (report && listener) {"
    "      window.clearTimeout(timer);"
    "      timer = window.setTimeout(function () {"
    "        listener({key: view.getAttribute('data-key'), auto: auto, scale: s, x: x, y: y});"
    "      }, 300);"
    "    }"
    "  }"
    % The view AUTO names, once the viewport has a size: all of the drawing
    % below the buttons, or 100% from the top, centred across either way.
    "  function follow(report) {"
    "    var vw = view.clientWidth, vh = view.clientHeight, cw = stage.scrollWidth, ch = stage.scrollHeight;"
    "    if (!vw || !vh || !cw || !ch) { return; }"
    "    if (auto === 'fit') {"
    "      var top = ctl.offsetTop + ctl.offsetHeight + 6;"
    "      s = clamp(Math.min((vw - 2 * PAD) / cw, (vh - top - PAD) / ch));"
    "      x = (vw - cw * s) / 2; y = top + Math.max(0, (vh - top - PAD - ch * s) / 2);"
    "    } else {"
    "      s = 1; x = (vw - cw) / 2; y = 0;"
    "    }"
    "    draw(report);"
    "  }"
    "  function zoomAt(f, cx, cy) {"
    "    var n = clamp(s * f);"
    "    x = cx - (cx - x) * n / s; y = cy - (cy - y) * n / s; s = n;"
    "    auto = null; draw(true);"
    "  }"
    "  ctl.addEventListener('click', function (e) {"
    "    var b = e.target.closest('button');"
    "    if (!b) { return; }"
    "    var z = b.getAttribute('data-z');"
    "    if (z === 'in' || z === 'out') {"
    "      zoomAt(z === 'in' ? STEP : 1 / STEP, view.clientWidth / 2, view.clientHeight / 2);"
    "    } else {"
    "      auto = z === 'fit' ? 'fit' : 'actual'; follow(true);"
    "    }"
    "  });"
    "  view.addEventListener('wheel', function (e) {"
    "    e.preventDefault();"
    "    var r = view.getBoundingClientRect();"
    "    var d = e.deltaY * (e.deltaMode === 1 ? 16 : e.deltaMode === 2 ? 400 : 1);"
    "    zoomAt(Math.exp(-d * 0.0015), e.clientX - r.left, e.clientY - r.top);"
    "  }, {passive: false});"
    % A press only pans once it has moved a few pixels, so a click still
    % opens a box; the click that ends a pan is swallowed before it can.
    "  var drag = null, moved = false;"
    "  view.addEventListener('pointerdown', function (e) {"
    "    moved = false;"
    "    if (e.button !== 0 || e.target.closest('.zoomctl')) { return; }"
    "    drag = {id: e.pointerId, px: e.clientX, py: e.clientY, x: x, y: y};"
    "  });"
    "  view.addEventListener('pointermove', function (e) {"
    "    if (!drag || e.pointerId !== drag.id) { return; }"
    "    var dx = e.clientX - drag.px, dy = e.clientY - drag.py;"
    "    if (!moved && Math.abs(dx) + Math.abs(dy) < 4) { return; }"
    "    if (!moved) { moved = true; view.classList.add('panning'); view.setPointerCapture(e.pointerId); }"
    "    x = drag.x + dx; y = drag.y + dy; auto = null; draw(true);"
    "  });"
    "  function release(e) {"
    "    if (drag && e.pointerId === drag.id) { drag = null; view.classList.remove('panning'); }"
    "  }"
    "  view.addEventListener('pointerup', release);"
    "  view.addEventListener('pointercancel', release);"
    "  view.addEventListener('click', function (e) {"
    "    if (moved) { e.preventDefault(); e.stopPropagation(); moved = false; }"
    "  }, true);"
    "  if (window.ResizeObserver) {"
    "    new ResizeObserver(function () { if (auto) { follow(false); } }).observe(view);"
    "  }"
    "  follow(false);"
    "  return {"
    "    restore: function (v) {"
    "      if (!v || typeof v !== 'object' || v.key !== view.getAttribute('data-key')) { return; }"
    "      if (v.auto === 'fit' || v.auto === 'actual') { auto = v.auto; follow(false); return; }"
    "      if (!(v.scale > 0) || !isFinite(v.x) || !isFinite(v.y)) { return; }"
    "      auto = null; s = clamp(v.scale); x = v.x; y = v.y; draw(false);"
    "    },"
    "    onChange: function (f) { listener = f; }"
    "  };"
    "})();"
    ], newline);
end
