function file = writeUnitQualityReport(units, file, opts)
%writeUnitQualityReport  One HTML page of a sort's unit quality: summary, histograms, table, waveforms.
%   FILE = writeUnitQualityReport(UNITS, FILE) writes a self-contained HTML
%   page (one file, no external files) for units that carry quality
%   metrics (EphysDataset.unitQuality, readSortedUnits(Quality=true)):
%     - the sort: results folder, recording length and where it came from,
%       units per class, units meeting the criteria
%     - the criteria applied (unitQualityPass) and the metric definitions
%     - one histogram per metric (inline SVG) with its threshold
%     - one row per unit: label, class, group, channel, spikes, the
%       metrics, pass / fail, the criteria it fails and those unknown;
%       failed metrics are marked, unknown ones grayed. The units labeled
%       good come first (those meeting the criteria first among them),
%       then the rest the same way, each in unit order. A header click
%       sorts the table by that column (again: reversed, a third time: back
%       to this order), by the page's one inline script; a good unit's
%       label links to its waveform
%     - each good unit's mean waveform on its peak channel (inline SVG):
%       the mean and SD of up to WaveformSpikes of its spikes, cut from the
%       data the sort read and prepared as Kilosort4 saw it
%       (EphysDataset.readPhyWaveforms); its template (templateWaveform)
%       when they cannot be read (the .bin is gone), and the page says why
%     - the code version that wrote the page (ephysProvenance)
%   FILE "" writes <resultsDir>/quality_report.html.
%
%   Options
%     Criteria        unitQualityPass criteria (default unitQualityCriteria())
%     Title           page title (default "Unit quality: <resultsDir's folder>")
%     WaveformSpikes  spikes per good unit to average, picked at random (the
%                     same ones each time) (default 100; 0 = the templates,
%                     no spikes read)
%
%   See also EphysDataset.unitQuality, unitQualityPass, unitQualityMetrics,
%   EphysDataset.readPhyWaveforms.

arguments
    units (1,1) struct
    file (1,1) string = ""
    opts.Criteria (1,1) struct = unitQualityCriteria()
    opts.Title (1,1) string = ""
    opts.WaveformSpikes (1,1) double {mustBeNonnegative, mustBeInteger} = 100
end
metrics = ["firingRate" "isiViolationsRatio" "presenceRatio" "amplitudeCutoff" "snr" "driftPtp"];
if ~all(isfield(units, metrics))
    error('writeUnitQualityReport:NoMetrics', ...
        'The units carry no quality metrics: read them with readSortedUnits(Quality=true) or EphysDataset.unitQuality.');
end
dir0 = "";
if isfield(units, 'resultsDir'); dir0 = string(units.resultsDir); end
if file == ""
    if dir0 == ""
        error('writeUnitQualityReport:NoFile', 'Give FILE: the units name no results folder.');
    end
    file = fullfile(dir0, "quality_report.html");
end
title = opts.Title;
if title == ""
    [~, leaf] = fileparts(dir0);
    title = "Unit quality: " + leaf;
end

n = numel(units.unitId);
[pass, why, unknown] = unitQualityPass(units, opts.Criteria);
c = unitQualityCriteria();
for f = string(fieldnames(opts.Criteria)).'; c.(f) = opts.Criteria.(f); end
cls = strings(n, 1);
if isfield(units, 'class'); cls = string(units.class(:)); end
grp = strings(n, 1);
if isfield(units, 'group'); grp = string(units.group(:)); end
good = grp == "good";
pass = pass(:);
order = [find(good & pass); find(good & ~pass); find(~good & pass); find(~good & ~pass)];
q = struct('settings', struct(), 'numSamples', NaN, 'numSamplesSource', "", 'snrNoise', "");
if isfield(units, 'quality') && isstruct(units.quality); q = units.quality; end

L = strings(0, 1);
L(end+1) = "<!doctype html><html lang=""en""><head><meta charset=""utf-8"">";
L(end+1) = "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">";
L(end+1) = "<title>" + esc(title) + "</title><style>";
L(end+1) = "body{font:14px/1.45 system-ui,sans-serif;margin:16px;color:#1d2433;background:#fff}";
L(end+1) = "h1{font-size:20px;margin:0 0 4px}h2{font-size:16px;margin:22px 0 8px}";
L(end+1) = ".meta{color:#5b6475}table{border-collapse:collapse;font-size:13px}";
L(end+1) = "th,td{border-bottom:1px solid #e3e6ec;padding:3px 8px;text-align:right;white-space:nowrap}";
L(end+1) = "th{background:#f3f5f8;position:sticky;top:0}td.t,th.t{text-align:left}";
L(end+1) = "td.fail{background:#fde2e1;color:#8a1c17}td.unk{color:#9aa1ad}tr.no td.t:first-child{color:#8a1c17}";
L(end+1) = ".wrap{overflow-x:auto}.hists{display:flex;flex-wrap:wrap;gap:12px}figure{margin:0}";
L(end+1) = "table.sortable th{cursor:pointer;user-select:none}td a{color:inherit}";
L(end+1) = "table.sortable th[data-dir=asc]::after{content:' \25B2'}table.sortable th[data-dir=desc]::after{content:' \25BC'}";
L(end+1) = "figure.wf{width:240px}";
L(end+1) = "figcaption{font-size:12px;color:#5b6475}</style></head><body>";
L(end+1) = "<h1>" + esc(title) + "</h1>";
L(end+1) = "<p class=""meta"">" + esc(dir0) + "</p>";

% --- summary ---------------------------------------------------------------
L(end+1) = "<h2>Summary</h2><table>";
L(end+1) = row2("Units", string(n));
for k = unique(cls).'
    L(end+1) = row2("&nbsp;&nbsp;class " + esc(k), sprintf("%d (%d meet the criteria)", nnz(cls == k), nnz(cls == k & pass))); %#ok<AGROW>
end
L(end+1) = row2("Meet the criteria", sprintf("%d of %d", nnz(pass), n));
if isfinite(q.numSamples) && isfield(units, 'fs')
    L(end+1) = row2("Recording", sprintf("%.1f s (%d samples, from %s)", q.numSamples / units.fs, q.numSamples, q.numSamplesSource));
end
if isfield(q, 'snrNoise') && q.snrNoise ~= ""
    L(end+1) = row2("SNR", esc(q.snrNoise));
end
L(end+1) = "</table>";

% --- criteria ----------------------------------------------------------------
L(end+1) = "<h2>Criteria</h2><table><tr><th class=""t"">Metric</th><th>Threshold</th></tr>";
thr = @(op, v) ternary(isnan(v), "not applied", op + " " + sprintf("%.4g", v));
crit = [ "isiViolationsRatio" thr("<", c.isiViolationsRatioMax); "presenceRatio" thr(">", c.presenceRatioMin); ...
         "amplitudeCutoff" thr("<", c.amplitudeCutoffMax); "snr" thr(">", c.snrMin); ...
         "driftPtp (um)" thr("<", c.driftPtpMax); "firingRate (Hz)" thr(">", c.firingRateMin)];
for r = 1:size(crit, 1)
    L(end+1) = "<tr><td class=""t"">" + crit(r, 1) + "</td><td>" + esc(crit(r, 2)) + "</td></tr>"; %#ok<AGROW>
end
L(end+1) = "<tr><td class=""t"">a metric that is NaN</td><td>" + ternary(string(c.unknown) == "fail", "fails", "passes") + ...
    "</td></tr></table>";
defs = "Definitions: SpikeInterface's quality metrics (unitQualityMetrics).";
if isfield(q, 'settings') && isfield(q.settings, 'definitions'); defs = "Definitions: " + q.settings.definitions + "."; end
L(end+1) = "<p class=""meta"">" + esc(defs) + "</p>";

% --- histograms ----------------------------------------------------------------
L(end+1) = "<h2>Distributions</h2><div class=""hists"">";
lims = struct('isiViolationsRatio', c.isiViolationsRatioMax, 'presenceRatio', c.presenceRatioMin, ...
    'amplitudeCutoff', c.amplitudeCutoffMax, 'snr', c.snrMin, 'driftPtp', c.driftPtpMax, 'firingRate', c.firingRateMin);
for m = metrics
    L(end+1) = histogramSvg(double(units.(m)(:)), m, lims.(m)); %#ok<AGROW>
end
L(end+1) = "</div>";

% --- units -------------------------------------------------------------------------
% Good units first; numeric cells carry their value (data-v, "" for NaN) for the sort script.
L(end+1) = "<h2>Units</h2><p class=""meta"">The units labeled good first (those meeting the criteria " + ...
    "first among them), then the rest. Click a column header to sort by it, again to reverse, a third " + ...
    "time for this order. A good unit's label links to its mean waveform.</p>";
L(end+1) = "<div class=""wrap""><table class=""sortable""><thead><tr><th class=""t"">Label</th><th class=""t"">Class</th>" + ...
    "<th class=""t"">Group</th><th>Channel</th><th>Spikes</th><th>Rate (Hz)</th><th>ISI ratio</th><th>ISI count</th>" + ...
    "<th>Presence</th><th>Amp. cutoff</th><th>SNR</th><th>Drift ptp (um)</th><th class=""t"">Meets</th>" + ...
    "<th class=""t"">Fails</th><th class=""t"">Unknown</th></tr></thead><tbody>";
val = @(f, i) fieldOr(units, f, i);
for r = 1:n
    i = order(r);
    cells = strings(1, 0);
    lbl = esc(string(val('label', i)));
    if good(i); lbl = "<a href=""#" + waveId(units, i) + """>" + lbl + "</a>"; end
    cells(end+1) = "<td class=""t"">" + lbl + "</td>"; %#ok<AGROW>
    cells(end+1) = "<td class=""t"">" + esc(cls(i)) + "</td>"; %#ok<AGROW>
    cells(end+1) = "<td class=""t"">" + esc(grp(i)) + "</td>"; %#ok<AGROW>
    cells(end+1) = numCell(val('channel', i), ""); %#ok<AGROW>
    cells(end+1) = numCell(val('nSpikes', i), ""); %#ok<AGROW>
    for m = ["firingRate" "isiViolationsRatio" "isiViolationsCount" "presenceRatio" "amplitudeCutoff" "snr" "driftPtp"]
        v = double(val(char(m), i));
        cl = "";
        if isnan(v); cl = "unk"; elseif contains(why(i), m + " "); cl = "fail"; end
        cells(end+1) = numCell(v, cl); %#ok<AGROW>
    end
    cells(end+1) = "<td class=""t"">" + ternary(pass(i), "yes", "no") + "</td>"; %#ok<AGROW>
    cells(end+1) = "<td class=""t"">" + esc(why(i)) + "</td>"; %#ok<AGROW>
    cells(end+1) = "<td class=""t"">" + esc(unknown(i)) + "</td>"; %#ok<AGROW>
    L(end+1) = "<tr data-i=""" + r + """" + ternary(pass(i), "", " class=""no""") + ">" + strjoin(cells, "") + "</tr>"; %#ok<AGROW>
end
L(end+1) = "</tbody></table></div>";

% --- good units' mean waveforms ------------------------------------------------------
L(end+1) = "<h2>Mean waveforms of the good units</h2>";
rows = order(good(order));
if isempty(rows)
    L(end+1) = "<p class=""meta"">No unit is labeled good.</p>";
else
    [WF, note] = meanWaveforms(units, rows, opts.WaveformSpikes);
    if opts.WaveformSpikes == 0
        about = "Each good unit's Kilosort4 template on its peak channel (WaveformSpikes 0: no spikes read).";
    elseif note == ""
        about = sprintf("On each good unit's peak channel, the mean (line) and SD (band) of up to %d of its " + ...
            "spikes, cut from the data the sort read and prepared as Kilosort4 saw it.", opts.WaveformSpikes);
    else
        about = "The sorted spikes cannot be read, so the units' Kilosort4 templates are drawn: " + note;
    end
    L(end+1) = "<p class=""meta"">" + esc(about) + "</p><div class=""hists"">";
    for k = 1:numel(rows)
        i = rows(k);
        cap = "<b>" + esc(string(val('label', i))) + "</b> &middot; " + esc(channelText(units, i));
        w = WF(k);
        switch w.from
            case "spikes";   cap = cap + sprintf(" &middot; %d spikes", w.n);
            case "template"; cap = cap + " &middot; template";
        end
        if ~isempty(w.mean)
            cap = cap + " &middot; " + num(max(w.mean) - min(w.mean)) + " " + unitText(w.units) + " p-p";
        end
        cap = cap + "<br>" + ternary(pass(i), "meets the criteria", "fails: " + esc(why(i)));
        L(end+1) = waveformSvg(w, waveId(units, i), cap); %#ok<AGROW>
    end
    L(end+1) = "</div>";
end

v = ephysVersion();
L(end+1) = "<p class=""meta"">Written " + esc(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'))) + ...
    " by writeUnitQualityReport, " + esc(v.Text) + ".</p>";
L(end+1) = strjoin(sortScript(), newline);
L(end+1) = "</body></html>";

d = fileparts(file);
if strlength(d) > 0 && ~isfolder(d); mkdir(d); end
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    error('writeUnitQualityReport:CannotWrite', 'Cannot open %s for writing.', file);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, char(strjoin(L, newline) + newline), 'char');
end


function s = histogramSvg(x, name, lim)
%histogramSvg  An inline SVG histogram of X (20 bins over its finite range) with the threshold LIM.
W = 260; H = 130; pad = 22;
v = x(isfinite(x));
s = "<figure><svg width=""" + W + """ height=""" + H + """ viewBox=""0 0 " + W + " " + H + """ role=""img"" aria-label=""" + ...
    name + " histogram"">";
if isempty(v)
    s = s + "<text x=""10"" y=""60"" font-size=""12"" fill=""#9aa1ad"">no values</text></svg>";
else
    lo = min([v; lim(isfinite(lim))]); hi = max([v; lim(isfinite(lim))]);
    if hi == lo; lo = lo - 0.5; hi = hi + 0.5; end
    e = linspace(lo, hi, 21);
    h = histcounts(v, e);
    bw = (W - 2 * pad) / 20;
    sx = @(t) pad + (t - lo) / (hi - lo) * (W - 2 * pad);
    for b = 1:20
        bh = (H - 2 * pad) * h(b) / max(h);
        s = s + sprintf("<rect x=""%.1f"" y=""%.1f"" width=""%.1f"" height=""%.1f"" fill=""#5b8def""/>", ...
            pad + (b - 1) * bw, H - pad - bh, max(bw - 1, 0.5), bh);
    end
    s = s + sprintf("<line x1=""%d"" y1=""%d"" x2=""%d"" y2=""%d"" stroke=""#9aa1ad""/>", pad, H - pad, W - pad, H - pad);
    s = s + sprintf("<text x=""%d"" y=""%d"" font-size=""10"" fill=""#5b6475"">%s</text>", pad, H - 6, num(lo));
    s = s + sprintf("<text x=""%d"" y=""%d"" font-size=""10"" fill=""#5b6475"" text-anchor=""end"">%s</text>", W - pad, H - 6, num(hi));
    if isfinite(lim)
        s = s + sprintf("<line x1=""%.1f"" y1=""%d"" x2=""%.1f"" y2=""%d"" stroke=""#c0392b"" stroke-dasharray=""4 3""/>", ...
            sx(lim), pad - 6, sx(lim), H - pad);
    end
    s = s + "</svg>";
end
s = s + "<figcaption>" + esc(name) + sprintf(" (%d of %d units with a value)", numel(v), numel(x)) + "</figcaption></figure>";
end


function [WF, note] = meanWaveforms(units, rows, nMax)
%meanWaveforms  Each unit of ROWS on its peak channel: mean and SD of its spikes, else its template.
%   Up to NMAX of the unit's spikes are cut from the data the sort read
%   (EphysDataset.readPhyWaveforms). Once that data cannot be read (the .bin
%   is gone) every unit from then on gets its template, and NOTE says why;
%   a unit whose peak channel was not sorted gets its template alone.
WF = repmat(struct('timeMs', [], 'mean', [], 'sd', [], 'n', 0, 'units', "", 'from', "none"), numel(rows), 1);
note = "";
dir0 = "";
if isfield(units, 'resultsDir'); dir0 = string(units.resultsDir); end
canRead = nMax > 0 && dir0 ~= "" && isfield(units, 'samples') && isfield(units, 'ksChannel');
if nMax > 0 && ~canRead
    note = "the units name no results folder, spikes or peak channels.";
end
for k = 1:numel(rows)
    i = rows(k);
    if canRead
        try
            [w, info] = EphysDataset.readPhyWaveforms(dir0, units.samples{i}, ...
                Channels=double(units.ksChannel(i)), MaxSpikes=nMax);
            if size(w, 3) > 0
                w = reshape(w, size(w, 1), []);          % samples x spikes
                WF(k).timeMs = double(info.timeMs(:));
                WF(k).mean = mean(w, 2);
                WF(k).sd = std(w, 0, 2);
                WF(k).n = size(w, 2);
                WF(k).units = string(info.units);
                WF(k).from = "spikes";
                continue
            end
        catch ME
            if ~startsWith(ME.identifier, "EphysDataset:readPhyWaveforms:")
                rethrow(ME);
            end
            if ME.identifier ~= "EphysDataset:readPhyWaveforms:BadChannels"
                canRead = false;
                note = string(ME.message);
            end
        end
    end
    if isfield(units, 'templateWaveform') && numel(units.templateWaveform) >= i && ~isempty(units.templateWaveform{i})
        WF(k).timeMs = double(units.templateTimeMs(:));
        WF(k).mean = double(units.templateWaveform{i}(:));
        WF(k).units = string(units.templateUnits);
        WF(k).from = "template";
    end
end
end


function s = waveformSvg(w, id, caption)
%waveformSvg  An inline SVG of one unit's waveform W (meanWaveforms): its mean, its SD as a band.
Wd = 240; H = 150; l = 44; r = 8; t = 8; b = 22;
s = "<figure class=""wf"" id=""" + id + """><svg width=""" + Wd + """ height=""" + H + """ viewBox=""0 0 " + ...
    Wd + " " + H + """ role=""img"" aria-label=""mean waveform"">";
if isempty(w.mean)
    s = s + "<text x=""10"" y=""70"" font-size=""12"" fill=""#9aa1ad"">no waveform</text></svg>";
else
    x = w.timeMs(:);
    m = w.mean(:);
    sd = zeros(size(m));
    if ~isempty(w.sd); sd = w.sd(:); end
    lo = min([m - sd; 0]); hi = max([m + sd; 0]);
    if hi == lo; lo = lo - 1; hi = hi + 1; end
    x0 = x(1); x1 = x(end);
    if x1 == x0; x1 = x0 + 1; end
    sx = @(v) l + (v - x0) / (x1 - x0) * (Wd - l - r);
    sy = @(v) t + (hi - v) / (hi - lo) * (H - t - b);
    s = s + sprintf("<line x1=""%d"" y1=""%d"" x2=""%d"" y2=""%d"" stroke=""#9aa1ad""/>", l, t, l, H - b);
    s = s + sprintf("<line x1=""%d"" y1=""%.1f"" x2=""%d"" y2=""%.1f"" stroke=""#c8ccd4"" stroke-dasharray=""3 3""/>", ...
        l, sy(0), Wd - r, sy(0));
    if x0 <= 0 && 0 <= x1
        s = s + sprintf("<line x1=""%.1f"" y1=""%d"" x2=""%.1f"" y2=""%d"" stroke=""#e3e6ec""/>", sx(0), t, sx(0), H - b);
    end
    if any(sd > 0)
        s = s + "<polygon points=""" + pts(sx([x; flipud(x)]), sy([m + sd; flipud(m - sd)])) + ...
            """ fill=""#5b8def"" fill-opacity=""0.3"" stroke=""none""/>";
    end
    s = s + "<polyline points=""" + pts(sx(x), sy(m)) + """ fill=""none"" stroke=""#1d4ed8"" stroke-width=""1.5""/>";
    s = s + sprintf("<text x=""%d"" y=""%d"" font-size=""10"" fill=""#5b6475"" text-anchor=""end"">%s</text>", l - 4, t + 8, sprintf("%.3g", hi));
    s = s + sprintf("<text x=""%d"" y=""%d"" font-size=""10"" fill=""#5b6475"" text-anchor=""end"">%s</text>", l - 4, H - b, sprintf("%.3g", lo));
    s = s + sprintf("<text x=""%d"" y=""%d"" font-size=""10"" fill=""#5b6475"">%s</text>", l, H - 6, sprintf("%.3g", x0));
    s = s + sprintf("<text x=""%d"" y=""%d"" font-size=""10"" fill=""#5b6475"" text-anchor=""end"">%s ms</text>", ...
        Wd - r, H - 6, sprintf("%.3g", x1));
    s = s + "</svg>";
end
s = s + "<figcaption>" + caption + "</figcaption></figure>";
end


function p = pts(x, y)
%pts  SVG points "x,y x,y ..." of the columns X and Y.
p = strtrim(string(sprintf("%.1f,%.1f ", [x(:) y(:)].')));
end


function id = waveId(units, i)
%waveId  The HTML id of unit I's waveform figure.
id = "wf-" + string(units.unitId(i));
end


function t = channelText(units, i)
%channelText  Unit I's peak channel: its native name, else "ch <recording channel>".
t = "";
if isfield(units, 'channelName') && numel(units.channelName) >= i; t = string(units.channelName(i)); end
if ismissing(t) || t == ""; t = "ch " + num(fieldOr(units, 'channel', i)); end
end


function s = unitText(units)
%unitText  The amplitude unit for a caption (EphysDataset.readPhyWaveforms units).
switch units
    case "uV";       s = "&micro;V";
    case "bin";      s = ".bin units";
    case "whitened"; s = "whitened units";
    otherwise;       s = "a.u.";
end
end


function c = numCell(v, cl)
%numCell  A numeric table cell, its value in data-v ("" for NaN) for the sort script; CL its class.
v = double(v);
dv = "";
if ~isempty(v) && isfinite(v); dv = string(sprintf("%.10g", v)); end
if cl ~= ""; cl = " class=""" + cl + """"; end
c = "<td" + cl + " data-v=""" + dv + """>" + num(v) + "</td>";
end


function L = sortScript()
%sortScript  The page's script: a header click sorts its table up, down, then back to the page's order.
%   Numeric columns (no class "t") sort by each cell's data-v, text ones by
%   the cell's text; empty values go last either way.
L = [
"<script>"
"document.querySelectorAll('table.sortable').forEach(function (t) {"
"  var body = t.tBodies[0], heads = t.tHead.rows[0].cells;"
"  Array.prototype.forEach.call(heads, function (th, c) {"
"    var num = !th.classList.contains('t');"
"    th.title = 'Sort by this column (again: reversed, a third time: the order of the report)';"
"    th.addEventListener('click', function () {"
"      var dir = {'': 'asc', asc: 'desc', desc: ''}[th.getAttribute('data-dir') || ''];"
"      Array.prototype.forEach.call(heads, function (h) { h.removeAttribute('data-dir'); });"
"      if (dir) { th.setAttribute('data-dir', dir); }"
"      var key = function (row) {"
"        var d = row.cells[c], v = d.hasAttribute('data-v') ? d.getAttribute('data-v') : d.textContent.trim();"
"        return v === '' ? null : (num ? parseFloat(v) : v);"
"      };"
"      var rows = Array.prototype.slice.call(body.rows);"
"      rows.sort(function (a, b) {"
"        var i = a.getAttribute('data-i') - b.getAttribute('data-i');"
"        if (!dir) { return i; }"
"        var x = key(a), y = key(b);"
"        if (x === null || y === null) { return ((x === null) - (y === null)) || i; }"
"        var d = num ? x - y : x.localeCompare(y, undefined, {numeric: true});"
"        return (dir === 'asc' ? d : -d) || i;"
"      });"
"      rows.forEach(function (row) { body.appendChild(row); });"
"    });"
"  });"
"});"
"</script>"];
end


function v = fieldOr(u, f, i)
%fieldOr  Element I of field F of the units, or "" / NaN when the field is missing.
if isfield(u, f) && numel(u.(f)) >= i
    v = u.(f)(i);
    if iscell(v); v = v{1}; end
elseif ismember(f, {'label', 'group'})
    v = "";
else
    v = NaN;
end
end


function t = num(v)
%num  A number as the table shows it: up to 4 significant digits, NaN as an em dash.
if isempty(v) || ~isfinite(double(v))
    t = "&mdash;";
elseif v == round(v) && abs(v) < 1e6
    t = sprintf("%d", round(v));
else
    t = sprintf("%.4g", v);
end
t = string(t);
end


function t = row2(a, b)
t = "<tr><td class=""t"">" + a + "</td><td class=""t"">" + b + "</td></tr>";
end


function s = esc(s)
%esc  HTML text: & < > and quotes escaped.
s = replace(string(s), ["&" "<" ">" """"], ["&amp;" "&lt;" "&gt;" "&quot;"]);
end


function out = ternary(c, a, b)
if c; out = string(a); else; out = string(b); end
end
