function [html, summary, model] = manifest(src, opts)
%manifest  A dataset manifest as a flow chart: what was done to the recording, at four levels of detail.
%   [HTML, SUMMARY, MODEL] = PipelineDiagram.manifest(SRC) draws how the
%   outputs of one dataset were made, as a standalone HTML page. SRC is a
%   decoded manifest struct, an EphysDataset, a <Name>_manifest.json file or
%   the recording folder that holds one. It is the manifest viewer's Flow chart
%   tab (ManifestViewerApp), and works without it:
%
%     writelines(PipelineDiagram.manifest(ds), "flowchart.html");
%
%   Where PipelineDiagram.overview and .detail draw what a config would do, this
%   draws what the manifest says was done. The inputs (the behavior session,
%   the recording, the probe map) are on top, then a box per step with the
%   files it wrote hung under it. An arrow runs from each input or output to
%   every step that reads it, in the color of what it leaves. An arrow is
%   dashed when the reader's record says it did not read it, and a step that
%   has not run is faded, with the arrows into it.
%
%   The page's buttons switch between the levels of detail. All four are in
%   the page, so a saved file has them too:
%     steps       the major steps and whether each ran
%     outputs     and the files written, with what came of each step
%     settings    and the settings that decide the result, in words
%     parameters  and every value the manifest holds about each step
%   Others switch its direction, top to bottom or left to right, also both
%   in the page.
%
%   Each level is laid out on its own for the size its boxes come to, on the
%   same grid (gridPlace, as PipelineDiagram.overview): no box overlaps another
%   and no arrow runs through one, the rows follow the flow of the data, and
%   the arrows are ordered to cross as little as they can. A box's badge
%   checks its file on disk now.
%
%   Options:
%     Level             the level the page opens on, "outputs" by default
%     Direction         the direction it opens in, "vertical" (top to bottom,
%                       the default) or "horizontal" (left to right)
%     HideNotRun        leave out the steps not run and the arrows not read
%     DefaultProbeFile  the probe a dataset without its own is used with
%
%   SUMMARY is a one-line description. MODEL holds the geometry of each level
%   in each direction, for tests: levels(k).name, .direction, .width, .height,
%   .nodes (id, title, rect [x y w h], the box and the files hung under it) and
%   .edges (from, to, on, dim, points, a [n x 2] polyline ending on the side of
%   the target box its arrows enter).
%
%   Errors: PipelineDiagram:manifest:Unreadable (a file that is not a readable
%   manifest), ManifestViewerApp:NotFound (no such file or folder).
%
%   See also ManifestViewerApp, ManifestText, EphysDataset.writeManifest,
%   PipelineDiagram.overview, PipelineDiagram.zoomFrame.

arguments
    src
    opts.Level (1,1) string {mustBeMember(opts.Level, ["steps" "outputs" "settings" "parameters"])} = "outputs"
    opts.Direction (1,1) string {mustBeMember(opts.Direction, ["vertical" "horizontal"])} = "vertical"
    opts.HideNotRun (1,1) logical = false
    opts.DefaultProbeFile (1,1) string = ""
end
m = readSource(src);
[C, E] = manifestCards(m, opts.DefaultProbeFile);

L = levels();
ran = C(ismember([C.id], ["behavior" "artifacts" "signals" "bin" "spikes" "sorting" "export"]));
for k = 1:numel(E)   % an arrow into, or out of, a step not run fades with it
    E(k).dim = C([C.id] == E(k).to).dim || C([C.id] == E(k).from).dim;
end
hide = opts.HideNotRun && any(~[ran.dim]);   % with nothing run, the inputs are all there is to draw

nameOf = @(id) C([C.id] == id).title;
start = find([L.name] == opts.Level);
stage = "";
model = struct('levels', struct('name', {}, 'direction', {}, 'width', {}, 'height', {}, 'nodes', {}, 'edges', {}));
for dir = ["vertical" "horizontal"]
    for k = 1:numel(L)
        N = nodeAt(C(1), L(k));
        for j = 2:numel(C)
            N(j) = nodeAt(C(j), L(k));
        end
        e = E;
        if hide; [N, e] = gridHide(N, e); end
        [N, e, W, H] = gridPlace(N, e, ColW=L(k).colW, Direction=dir);
        svg = sprintf("<svg class=""flow"" xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 %g %g"" width=""%g"" height=""%g"" role=""img"" aria-label=""%s"">", ...
            W, H, W, H, gridEsc(L(k).title)) ...
            + gridJoin([arrayfun(@(x) gridEdgeSVG(x, nameOf), e, "UniformOutput", false), arrayfun(@gridNodeSVG, N, "UniformOutput", false)]) ...
            + "</svg>";
        stage = stage + "<div class=""lvl" + ternary(k == start && dir == opts.Direction, " on", "") ...
            + """ data-level=""" + L(k).name + """ data-dir=""" + dir + """ data-initial=""" + L(k).initial + """>" + svg + "</div>";
        model.levels(end + 1) = struct('name', L(k).name, 'direction', dir, 'width', W, 'height', H, ...
            'nodes', struct('id', {N.id}, 'title', {N.title}, 'rect', arrayfun(@(n) [n.x n.y n.w n.h], N, "UniformOutput", false)), ...
            'edges', struct('from', {e.from}, 'to', {e.to}, 'on', {e.on}, 'dim', {e.dim}, 'points', {e.points}));
    end
end

nRun = nnz(~[ran.dim]);
summary = sprintf("%d of %d steps run", nRun, numel(ran));
nBad = nnz([C.badgeClass] == "bad");
if nBad > 0; summary = summary + sprintf(" | %d with files gone", nBad); end
if hide; summary = summary + " | steps not run hidden"; end

name = ManifestText.text(ManifestText.field(m, 'name', ""));
pageTitle = "Processing flow: " + name;
zoom = PipelineDiagram.zoomFrame("manifest", L(start).initial);
updated = ManifestText.text(ManifestText.field(m, 'updated', ""));
body = "<h1>" + gridEsc(pageTitle) + "</h1><div class=""bars"">" + levelBar(L, start) + directionBar(opts.Direction) + "</div>" + legendHTML() ...
    + "<div class=""note"">From the manifest" + ternary(updated ~= "", " updated " + gridEsc(updated), "") ...
    + ". Arrows carry data in the color of what wrote it. Hover a box to trace what it reads and writes. Scroll to zoom, drag to pan.</div>" ...
    + zoom.open + stage + zoom.close ...
    + "<script>" + zoom.js + newline + js() + "</script>";
html = "<!DOCTYPE html><html><head><meta charset=""utf-8""><title>" + gridEsc(pageTitle) + "</title><style>" ...
    + zoom.css + gridCSS() + css() + "</style></head><body>" + body + "</body></html>";
end


function m = readSource(src)
%readSource  The decoded manifest of a struct, an EphysDataset, a file or a folder.
if isstruct(src)
    m = src;
    return
end
if isa(src, 'EphysDataset')
    file = string(src(1).manifestFile());
    if ~isfile(file)
        error('ManifestViewerApp:NotFound', 'Dataset %s has no manifest yet (%s). ds.writeManifest() writes one.', src(1).Name, file);
    end
else
    file = ManifestViewerApp.resolveFile(string(src));
end
[m, why] = EphysDataset.readManifest(file);
if why ~= ""
    error('PipelineDiagram:manifest:Unreadable', 'Cannot draw %s: %s.', file, why);
end
end


function L = levels()
%levels  The levels of detail, each with the width its boxes need. The first
%   three open fitted to the view; the last is read at full size, panning.
L = struct('name', {"steps", "outputs", "settings", "parameters"}, ...
    'label', {"Steps", "Outputs", "Key settings", "Every parameter"}, ...
    'title', {"The major processing steps", "The steps and the files they wrote", ...
        "The steps, their files and the settings that decide the result", ...
        "The steps, their files and every value the manifest holds"}, ...
    'colW', {190, 216, 276, 330}, 'initial', {"fit", "fit", "fit", "actual"});
end


function n = nodeAt(c, lev)
%nodeAt  A card as a node (gridPlace, gridNodeSVG) at a level of detail.
lines = strings(1, 0);
warn = strings(1, 0);
outs = c.pills([]);
rows = strings(0, 2);
if lev.name ~= "steps"
    lines = c.lines(c.lines ~= "");
    warn = c.warn;
    outs = c.pills;
end
if lev.name == "settings"; rows = c.key; end
if lev.name == "parameters"; rows = c.all; end
[bodySvg, bodyH] = bodySVG(warn, rows, lev.colW - 28);
n = struct('id', c.id, 'key', c.id, 'kind', c.kind, 'row', c.row, 'col', c.col, 'title', c.title, ...
    'lines', {lines}, 'target', "", 'badge', c.badge, 'badgeClass', c.badgeClass, 'dim', c.dim, ...
    'outs', {outs}, 'x', 0, 'y', 0, 'w', 0, 'h', 0, 'boxH', 0, 'body', bodySvg, 'bodyH', bodyH);
end


function [s, h] = bodySVG(warn, rows, w)
%bodySVG  A box's warnings and its [name value] rows, drawn from (0, 0) in width W.
%   Both columns wrap, so no value is ever cut short; a row ["#" label] starts a group.
LINE = 14;
PX = 10.5;
keyW = round(0.46 * w);
parts = strings(1, 0);
y = 0;
for t = reshape(warn, 1, [])
    for line = gridWrap(t, w, PX)
        y = y + LINE;
        parts(end+1) = sprintf("<text class=""kw"" y=""%.1f"">%s</text>", y - 3, gridEsc(line)); %#ok<AGROW>
    end
end
odd = false;
for r = 1:height(rows)
    if rows(r, 1) == "#"
        y = y + LINE + 4;
        parts(end+1) = sprintf("<text class=""kh"" y=""%.1f"">%s</text>", y - 3, gridEsc(rows(r, 2))); %#ok<AGROW>
        odd = false;
        continue
    end
    a = gridWrap(rows(r, 1), keyW - 6, PX);
    b = gridWrap(rows(r, 2), w - keyW, PX);
    if isempty(a); a = ""; end
    if isempty(b); b = "(empty)"; end
    n = max(numel(a), numel(b));
    if odd
        parts(end+1) = sprintf("<rect class=""kr"" x=""-4"" y=""%.1f"" width=""%.1f"" height=""%.1f"" rx=""2""/>", y, w + 8, n * LINE); %#ok<AGROW>
    end
    odd = ~odd;
    for j = 1:numel(a)
        parts(end+1) = sprintf("<text class=""kk"" y=""%.1f"">%s</text>", y + j * LINE - 3, gridEsc(a(j))); %#ok<AGROW>
    end
    for j = 1:numel(b)
        parts(end+1) = sprintf("<text class=""kv"" x=""%.1f"" y=""%.1f"">%s</text>", keyW, y + j * LINE - 3, gridEsc(b(j))); %#ok<AGROW>
    end
    y = y + n * LINE;
end
h = y;
if y > 0; h = y + 4; end
s = strjoin(parts, "");
end


function h = levelBar(L, start)
h = "<div class=""levels"" role=""group"" aria-label=""Level of detail""><span>Detail:</span>";
for k = 1:numel(L)
    h = h + "<button type=""button"" data-level=""" + L(k).name + """ title=""" + gridEsc(L(k).title) + """" ...
        + ternary(k == start, " class=""on""", "") + ">" + L(k).label + "</button>";
end
h = h + "</div>";
end


function h = directionBar(dir)
h = "<div class=""levels"" role=""group"" aria-label=""Direction""><span>Direction:</span>" ...
    + "<button type=""button"" data-dir=""vertical"" title=""The flow from top to bottom""" ...
    + ternary(dir == "vertical", " class=""on""", "") + ">Top to bottom</button>" ...
    + "<button type=""button"" data-dir=""horizontal"" title=""The flow from left to right""" ...
    + ternary(dir == "horizontal", " class=""on""", "") + ">Left to right</button></div>";
end


function h = legendHTML()
items = [ ...
    "<span class=""lg lg-src"">recording</span>", ...
    "<span class=""lg lg-in"">input</span>", ...
    "<span class=""lg lg-step"">step</span>", ...
    "<span class=""lg lg-out"">file written</span>", ...
    "<span class=""lg lg-link"">artifact periods</span>", ...
    "<span class=""lg lg-step lg-dim"">not run</span>", ...
    "<span class=""la""><i></i>read</span>", ...
    "<span class=""la off""><i></i>not read</span>"];
h = "<div class=""legend"">" + join(items, "") + "</div>";
end


function s = js()
%js  Page script: the level and direction buttons, in the app and in a saved
%   page, then the tracing. setup() is called only by the app's HTML component,
%   which then hears of each one picked, to open on it when the page is drawn again.
s = join([ ...
    "var manifestPicked = null;"
    "function setup(htmlComponent) {"
    "  manifestPicked = function (what, name) { htmlComponent.sendEventToMATLAB(what, name); };"
    "}"
    "(function () {"
    "  var buttons = document.querySelectorAll('.levels button'), panes = document.querySelectorAll('.lvl');"
    "  var shown = document.querySelector('.lvl.on');"
    "  var level = shown.getAttribute('data-level'), dir = shown.getAttribute('data-dir');"
    "  function show() {"
    "    var view = 'fit';"
    "    for (var i = 0; i < panes.length; i++) {"
    "      var on = panes[i].getAttribute('data-level') === level && panes[i].getAttribute('data-dir') === dir;"
    "      panes[i].classList.toggle('on', on);"
    "      if (on) { view = panes[i].getAttribute('data-initial'); }"
    "    }"
    "    for (var j = 0; j < buttons.length; j++) {"
    "      var b = buttons[j];"
    "      b.classList.toggle('on', b.getAttribute('data-level') === level || b.getAttribute('data-dir') === dir);"
    "    }"
    "    flowZoom.setView(view);"
    "  }"
    "  for (var k = 0; k < buttons.length; k++) {"
    "    buttons[k].addEventListener('click', function (e) {"
    "      var l = e.currentTarget.getAttribute('data-level'), d = e.currentTarget.getAttribute('data-dir');"
    "      if (l) { level = l; } else { dir = d; }"
    "      show();"
    "      if (manifestPicked) { manifestPicked(l ? 'level' : 'direction', l || d); }"
    "    });"
    "  }"
    "})();"
    gridTraceJS()], newline);
end


function s = css()
s = join([ ...
    ".bars{display:flex;flex-wrap:wrap;gap:6px 20px;margin:0 0 8px}"
    ".levels{display:flex;flex-wrap:wrap;align-items:center;gap:4px;font-size:12px;color:#57606a}"
    ".levels span{margin-right:4px;font-weight:600}"
    ".levels button{height:30px;padding:0 12px;font:600 12.5px 'Segoe UI',system-ui,sans-serif;color:#1f7fbf;background:#fff;border:1px solid #1f7fbf;border-radius:6px;cursor:pointer}"
    ".levels button:hover{background:#e3f0fa}"
    ".levels button.on{color:#fff;background:#1f7fbf}"
    ".levels button:focus-visible{outline:2px solid #0b3d5e;outline-offset:1px}"
    ".lvl{display:none}"
    ".lvl.on{display:block}"
    ".lvl[data-initial=actual]{padding-top:46px}"   % at 100% the zoom buttons cover no box
    ".c-bin{--acc:#6f42c1;--tint:#ece4fb}"
    ".c-rec .kk,.c-rec .kh{fill:#d0d7de}"
    ".c-rec .kv{fill:#fff}"
    ".c-rec .kr{fill:rgba(255,255,255,.09)}"
    ".kk{font-size:10.5px;fill:#57606a}"
    ".kv{font-size:10.5px;fill:#1f2328}"
    ".kh{font-size:10.5px;font-weight:600;fill:#1f2328;text-transform:uppercase;letter-spacing:.04em}"
    ".kw{font-size:10.5px;font-weight:600;fill:#b42318}"
    ".kr{fill:rgba(31,35,40,.05)}"
    ".badge.bad{fill:#ffebe9}"
    ".bt.bad{fill:#b42318;font-weight:600}"
    ".badge.warn{fill:#fff4d6}"
    ".bt.warn{fill:#7a5a00}"
    "@media print{.bars{display:none}}"
    ], "");
end


function v = ternary(tf, a, b)
if tf; v = string(a); else; v = string(b); end
end
