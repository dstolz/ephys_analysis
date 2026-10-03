function file = writeUnitQualityReport(units, file, opts)
%writeUnitQualityReport  One HTML page of a sort's unit quality: summary, histograms, table.
%   FILE = writeUnitQualityReport(UNITS, FILE) writes a self-contained HTML
%   page (no scripts, no external files) for units that carry quality
%   metrics (EphysDataset.unitQuality, readSortedUnits(Quality=true)):
%     - the sort: results folder, recording length and where it came from,
%       units per class, units meeting the criteria
%     - the criteria applied (unitQualityPass) and the metric definitions
%     - one histogram per metric (inline SVG) with its threshold
%     - one row per unit: label, class, group, channel, spikes, the
%       metrics, pass / fail, the criteria it fails and those unknown;
%       failed metrics are marked, unknown ones greyed
%     - the code version that wrote the page (ephysProvenance)
%   FILE "" writes <resultsDir>/quality_report.html.
%
%   Options
%     Criteria   unitQualityPass criteria (default unitQualityCriteria())
%     Title      page title (default "Unit quality: <resultsDir's folder>")
%
%   See also EphysDataset.unitQuality, unitQualityPass, unitQualityMetrics.

arguments
    units (1,1) struct
    file (1,1) string = ""
    opts.Criteria (1,1) struct = unitQualityCriteria()
    opts.Title (1,1) string = ""
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
L(end+1) = "<h2>Units</h2><div class=""wrap""><table><tr><th class=""t"">Label</th><th class=""t"">Class</th>" + ...
    "<th class=""t"">Group</th><th>Channel</th><th>Spikes</th><th>Rate (Hz)</th><th>ISI ratio</th><th>ISI count</th>" + ...
    "<th>Presence</th><th>Amp. cutoff</th><th>SNR</th><th>Drift ptp (um)</th><th class=""t"">Meets</th>" + ...
    "<th class=""t"">Fails</th><th class=""t"">Unknown</th></tr>";
val = @(f, i) fieldOr(units, f, i);
for i = 1:n
    cells = strings(1, 0);
    cells(end+1) = "<td class=""t"">" + esc(string(val('label', i))) + "</td>"; %#ok<AGROW>
    cells(end+1) = "<td class=""t"">" + esc(cls(i)) + "</td>"; %#ok<AGROW>
    cells(end+1) = "<td class=""t"">" + esc(string(val('group', i))) + "</td>"; %#ok<AGROW>
    cells(end+1) = "<td>" + num(val('channel', i)) + "</td>"; %#ok<AGROW>
    cells(end+1) = "<td>" + num(val('nSpikes', i)) + "</td>"; %#ok<AGROW>
    for m = ["firingRate" "isiViolationsRatio" "isiViolationsCount" "presenceRatio" "amplitudeCutoff" "snr" "driftPtp"]
        v = double(val(char(m), i));
        cl = "";
        if isnan(v); cl = " class=""unk"""; elseif contains(why(i), m + " "); cl = " class=""fail"""; end
        cells(end+1) = "<td" + cl + ">" + num(v) + "</td>"; %#ok<AGROW>
    end
    cells(end+1) = "<td class=""t"">" + ternary(pass(i), "yes", "no") + "</td>"; %#ok<AGROW>
    cells(end+1) = "<td class=""t"">" + esc(why(i)) + "</td>"; %#ok<AGROW>
    cells(end+1) = "<td class=""t"">" + esc(unknown(i)) + "</td>"; %#ok<AGROW>
    L(end+1) = "<tr" + ternary(pass(i), "", " class=""no""") + ">" + strjoin(cells, "") + "</tr>"; %#ok<AGROW>
end
L(end+1) = "</table></div>";
v = ephysVersion();
L(end+1) = "<p class=""meta"">Written " + esc(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'))) + ...
    " by writeUnitQualityReport, " + esc(v.Text) + ".</p></body></html>";

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
