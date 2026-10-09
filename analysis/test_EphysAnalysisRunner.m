function test_EphysAnalysisRunner()
%test_EphysAnalysisRunner  Verification suite for the runner, exports, reports and scripts.
%   Over a small synthetic project run through the pipeline: plan() and its
%   skip reasons; run() writing PNG + SVG figures named by the pattern (and
%   paged grids), an HTML report with embedded PNGs and a multi-page PDF
%   (title, summary and plot pages in order), both made from the exported
%   pages so each page is drawn once, leaving no figure open, with
%   percent-encoded links, and not rewriting existing pages with Overwrite
%   off; cancel(); driven synthetic units firing more in the stimulus
%   window; script equivalence -- the compact and the standalone script,
%   run into separate roots, pass checkcode and write the same figures
%   (pixel for pixel), the same HTML report (timestamps, image bytes and
%   the config aside) and the same PDF pages; real results rendered (a stack's row labels, Style.YLim on
%   PSTHs, rasters and evoked stacks, a tuning caption); a failing
%   export closing its page in the runner and the standalone script; and
%   unit waveforms (templates without the sorted .bin, spikes cut from a
%   planted one and cached, detections' saved waveforms, the script line);
%   behavior plots (RespLatency by Depth; the latency of the Trough onset
%   after RespWindow onset, which is RespLatency) and a raster sorted by a
%   stop event shifted by RespLatency (the response), descending across
%   groups, with the Trough onsets and offsets marked, all of them in the
%   scripts too.
%
%   Usage:  test_EphysAnalysisRunner

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);
addpath(genpath(fullfile(repo, 'vendor')));

root = fullfile(tempdir, sprintf('AnaRunner_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdirQuiet(root));

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
        end
    end

fprintf('\n== 0. fixture ==\n');
F = makeAnalysisFixture(string(root), Scenarios=["clean" "late-start"], NumTrials=12);
names = F.names;
check(numel(names) == 2, 'two datasets run through the pipeline');

cfg = EphysAnalysisConfig();
cfg.Name = "runner test";
cfg.Source.Root = F.proj;
cfg.Defaults.EventRef.line = "Stim";
cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
cfg.Defaults.Selection.groupBy = "Depth";
cfg = cfg.addPlot(struct('kind', "psth", 'bins', struct('BinSec', 0.02, 'SmoothSec', 0.02), ...
    'style', struct('MaxTiles', 2)), Id="psth_stim");
cfg = cfg.addPlot(struct('kind', "raster", 'rasterSort', "Depth", 'selection', struct('groupBy', string.empty(1, 0)), ...
    'waveform', struct('mode', "both")), Id="raster_stim");   % the sort's .bin is not there: templates
cfg = cfg.addPlot(struct('kind', "evoked", 'source', "LFP", 'window', struct('pre', -0.1, 'post', 0.4), ...
    'baseline', struct('Mode', "subtract", 'Window', [-0.1 0])), Id="lfp_stim");
cfg = cfg.addPlot(struct('kind', "rate", 'ref', struct('line', "RespWindow", 'scope', "trial"), ...
    'window', struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "RespWindow", 'edge', "offset", 'scope', "trial")), ...
    'selection', struct('filter', "Hit | Miss", 'groupBy', "Depth")), Id="rate_resp");
cfg = cfg.addPlot(struct('kind', "tuning", 'param', "Depth", 'window', struct('pre', 0, 'post', 0.5), ...
    'selection', struct('groupBy', string.empty(1, 0))), Id="tuning_depth");
cfg = cfg.addPlot(struct('kind', "heatmap", 'source', "detected"), Id="heat_det");
cfg = cfg.addPlot(struct('kind', "probemap", 'source', "detected", 'value', "rate"), Id="rate_map");
cfg = cfg.addPlot(struct('kind', "corrmap", 'metric', "peak", 'correlation', "spearman", 'ref', struct('line', "RespWindow", 'scope', "trial"), ...
    'window', struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "RespWindow", 'edge', "offset", 'scope', "trial"))), Id="corr_resp");
cfg = cfg.addPlot(struct('kind', "evoked", 'source', "SPIKE"), Id="spike_band");
cfg = cfg.addPlot(struct('kind', "psth", 'ref', struct('line', "Nope")), Id="no_line");
cfg = cfg.addPlot(struct('kind', "raster", 'ref', struct('line', "Stim", 'scope', "trial"), ...
    'window', struct('pre', -0.2, 'post', 2, 'stop', struct('line', "RespWindow", 'offsetParam', "RespLatency")), ...
    'rasterSort', "stop", 'rasterSortOrder', "descending", 'rasterByGroup', false, ...
    'rasterEvents', struct('lines', "Trough", 'edge', "both"), 'units', struct('maxUnits', 2)), Id="raster_resp");
cfg = cfg.addPlot(struct('kind', "behavior", 'param', "Depth", 'yParam', "RespLatency"), Id="behavior_lat");
cfg = cfg.addPlot(struct('kind', "behavior", 'layout', "box", 'param', "Depth", 'yParam', "stop", ...
    'ref', struct('line', "RespWindow", 'scope', "trial"), ...
    'window', struct('pre', 0, 'post', 0, 'stop', struct('line', "Trough", 'scope', "trial"))), Id="behavior_stop");
outMain = fullfile(root, 'outMain');
cfg.Export.Formats = ["png" "svg"];
cfg.Export.Folder = fullfile(outMain, "{Name}");
cfg.Export.Dpi = 60;
cfg.Export.FigureSizeCm = [16 11];
cfg.Report.Format = "both";
cfg.Report.Folder = outMain;
cfg.Report.Dpi = 50;
I = cfg.validate();
check(~any(I.Severity == "error"), 'the test config validates');

fprintf('\n== 1. plan ==\n');
r = EphysAnalysisRunner(cfg, LogFcn=[]);
check(isequal(r.Names, names) && numel(r.Outputs) == 2 && all(r.Keys == F.keys), 'the runner finds both datasets by key');
T = r.plan();
check(height(T) == 2 * numel(cfg.Plots), 'plan: one row per dataset and plot');
rs = T.Reason(T.Plot == "spike_band");
rn = T.Reason(T.Plot == "no_line");
check(all(rs == "no SPIKE extract") && all(rn == "no line Nope") && all(T.Enabled(~ismember(T.Plot, ["spike_band" "no_line"]))), ...
    'plan: missing SPIKE extract and missing line are the only skips');
src = r.source(1);
check(isstruct(src) && src.name == names(1) && r.Sources.isKey(char(F.keys(1))), 'source() loads and caches a dataset');

fprintf('\n== 2. run: figures, HTML and PDF reports ==\n');
nFig = numel(findall(groot, 'Type', 'figure'));
made = 0;   % the figures the run creates
    function countFigure(~, ~)
        made = made + 1;
    end
oldCreate = get(groot, 'DefaultFigureCreateFcn');
set(groot, 'DefaultFigureCreateFcn', @countFigure);
R = r.run();
set(groot, 'DefaultFigureCreateFcn', oldCreate);
check(numel(findall(groot, 'Type', 'figure')) == nFig, 'the run leaves no figure open');
done = R(R.Status == "done", :);
check(height(R) == 2 * (numel(cfg.Plots)) && height(done) == 2 * (numel(cfg.Plots) - 2) ...
    && all(R.Status(ismember(R.Plot, ["spike_band" "no_line"])) == "skipped"), ...
    sprintf('run: %d done, the 4 unsupported plot runs skipped (%s)', height(done), strjoin(unique(R.Status(R.Status == "error") + ": " + R.Message(R.Status == "error")), "; ")));
for n = names
    d = fullfile(outMain, n);
    p1 = fullfile(d, n + "_psth_stim_p1.png"); p2 = fullfile(d, n + "_psth_stim_p2.png");
    check(isfile(p1) && isfile(p2) && isfile(replace(p1, ".png", ".svg")) && isfile(fullfile(d, n + "_lfp_stim.png")) ...
        && isfile(fullfile(d, n + "_rate_map.svg")) && ~isfile(fullfile(d, n + "_spike_band.png")), ...
        n + ": png + svg per plot, the paged PSTH as _p1 / _p2");
end
html = fullfile(outMain, "analysis_report.html");
pdf = fullfile(outMain, "analysis_report.pdf");
check(isfile(html) && isfile(pdf) && isequal(sort(r.ReportFiles), sort([string(html) string(pdf)])), 'both reports written');
rr = r.RunRecordFile;
rec = jsondecode(fileread(rr));
check(isfile(rr) && startsWith(rr, string(fullfile(outMain, "analysis_runs")) + filesep) && rec.schema == "ephys-analysis-run/1" ...
    && rec.outcome == "finished" && numel(rec.datasets) == numel(names) && numel(rec.results) == height(R) ...
    && numel(rec.reportFiles) == 2 && isfield(rec, 'config') && isfield(rec, 'provenance'), ...
    'the run record: analysis_runs/<runId>_<name>.json in the report folder, with the outcome, datasets, results, reports, config and provenance');
H = string(fileread(html));
check(contains(H, "data:image/png;base64,") && contains(H, "psth_stim") && contains(H, "rate_resp") ...
    && contains(H, "no SPIKE extract") && contains(H, "Digital lines") && contains(H, "<pre class=""config"">") ...
    && count(H, "<img ") >= 2 * (numel(cfg.Plots) - 2), 'the HTML embeds every figure, the skips, the summaries and the config');
check(count(H, "_psth_stim_p1.png") == 4 && contains(H, "href=""" + names(1) + "/"), 'the HTML links the exported files relatively');
check(relativePath("C:\out\rep", "C:\out\Rat#3\a b.png") == "../Rat%233/a%20b.png" ...
    && relativePath("C:\out\rep", "C:\out\rep\x 100%.png") == "x%20100%25.png" ...
    && relativePath("C:\out\rep", "D:\data\Rat#3\a.png") == "file:///D:/data/Rat%233/a.png" ...
    && relativePath("C:\out\rep", "\\srv\share\a b.png") == "file://srv/share/a%20b.png" ...
    && relativePath(pwd, "sub\x#1.png") == "sub/x%231.png", ...
    'report links: each segment percent-encoded ("#", "%", spaces), relative paths from pwd, file:// on another drive or share');
E1 = [r.Report.datasets.entries];
E1 = E1([E1.status] == "done");
nDrawn = sum(arrayfun(@(e) numel(e.pages), E1));
check(~isempty(E1) && all(arrayfun(@(e) numel(e.images) == numel(e.files) / numel(cfg.Export.Formats) ...
    && numel(e.pages) == numel(e.images) && e.images{1}.format == "png" && all(isfile(e.pages)), E1)) && ~isfield(E1, 'R'), ...
    'a "both" report holds the image and the PDF page of every exported page, and no result');
check(made == nDrawn + 1 + numel(names), sprintf(['each page is drawn once: %d figures for %d exported pages, ' ...
    'the PDF''s title page and its %d summary pages'], made, nDrawn, numel(names)));
texts = pdfPageTexts(pdf);
inOrder = numel(texts) == 1 + numel(names) + nDrawn && contains(texts(1), "Generated") ...
    && contains(texts(1), sprintf("1. %s (%d plot(s))", names(1), numel(cfg.Plots)));
at = 1;
for D = r.Report.datasets
    at = at + 1;
    inOrder = inOrder && at <= numel(texts) && contains(texts(at), D.name) && contains(texts(at), "spike_band: skipped");
    for e = D.entries([D.entries.status] == "done")
        for f = e.pages
            at = at + 1;
            inOrder = inOrder && at <= numel(texts) && texts(at) == pdfPageTexts(f);
        end
    end
end
check(inOrder, sprintf('the PDF: a title page, then per dataset its summary page and its plots'' pages in order (%d pages)', numel(texts)));
ro = cfg; ro.Export.Overwrite = false; ro.Report.Enabled = false;
pages = dir(fullfile(outMain, names(1), names(1) + "_psth_stim_p*.*"));
T3 = EphysAnalysisRunner(ro, LogFcn=[]).run(Datasets=1, Plots="psth_stim");
again = dir(fullfile(outMain, names(1), names(1) + "_psth_stim_p*.*"));
check(T3.Status == "done" && numel(split(T3.Files, "; ")) == numel(pages) && isequal([pages.datenum], [again.datenum]), ...
    'Overwrite off: a page whose files all exist is listed, not written again');

fprintf('\n== 3. cancel ==\n');
calls = 0;
r2 = EphysAnalysisRunner(cfg, LogFcn=[]);
    function onProgress(~, ~)
        calls = calls + 1;
        if calls == 3; r2.cancel(); end
    end
r2.ProgressFcn = @onProgress;
R2 = r2.run(Export=false, Report=false);
check(any(R2.Status == "canceled") && height(R2) == 2 * numel(cfg.enabledPlots()) && isempty(r2.ReportFiles), ...
    sprintf('cancel stops the run; the rest are "canceled" (%d of %d)', nnz(R2.Status == "canceled"), height(R2)));

fprintf('\n== 3. cancel inside a plot (the preview''s PollFcn) ==\n');
polls = 0;
cancelAt = 0;
    function onPoll()
        polls = polls + 1;
        if polls == cancelAt; r.cancel(); end
    end
srcC = r.source(1);
idsC = cfg.enabledPlots();
specC = cfg.plotFor(idsC(1));
r.PollFcn = @onPoll;
r.clearCancel();
R0 = r.computePlot(srcC, specC);
nPolls = polls;
check(nPolls >= 3 && isfield(R0, 'epochs'), sprintf('with PollFcn set, computePlot reaches %d checkpoints and still returns the result', nPolls));
polls = 0; cancelAt = 2;
r.clearCancel();
cid = "";
try
    r.computePlot(srcC, specC);
catch ME
    cid = string(ME.identifier);
end
check(cid == "EphysAnalysisRunner:Canceled" && polls == 2, 'cancel() at the second checkpoint stops computePlot there (Canceled)');
r.PollFcn = [];
polls = 0;
R1 = r.computePlot(srcC, specC);
check(polls == 0 && isequaln(R1.epochs, R0.epochs), 'with PollFcn empty (a run) there are no checkpoints: a cancel() already asked for does not stop computePlot');
r.clearCancel();

fprintf('\n== 4. driven units fire more in the stimulus window ==\n');
src = r.source(1);
E = epochTable(src, eventRef(line="Stim"), Window=epochWindow(pre=0, post=0.5), Selection=trialSelection());
[st, meta] = selectUnits(src, struct('classes', string.empty(1, 0)));
Fr = firingRate(st, E, Baseline=[-1 -0.5]);
mod = [F.truth(1).units.modulation].';
drv = mod == "driven";
stimRate = Fr.meanRate; baseRate = mean(Fr.baseline, 1).';
check(any(drv) && all(stimRate(drv) > 1.3 * baseRate(drv)) && numel(meta.label) == numel(mod), ...
    sprintf('driven units: stimulus %s Hz vs baseline %s Hz', mat2str(round(stimRate(drv).', 1)), mat2str(round(baseRate(drv).', 1))));

fprintf('\n== 5. scripts: compact vs standalone ==\n');
outA = fullfile(root, 'outA'); outB = fullfile(root, 'outB');
cfgA = cfg; cfgA.Export.Folder = fullfile(outA, "{Name}"); cfgA.Report.Folder = outA;
cfgA.Export.Formats = "png"; cfgA.Report.Format = "both";
cfgB = cfgA; cfgB.Export.Folder = fullfile(outB, "{Name}"); cfgB.Report.Folder = outB;
cfgFile = fullfile(root, 'analysis.json');
cfgA = cfgA.save(cfgFile);
compactFile = fullfile(root, 'scripts', 'run_compact.m');
standaloneFile = fullfile(root, 'scripts', 'run_standalone.m');
txtC = EphysAnalysisScript.compact(cfgA, File=compactFile);
txtS = EphysAnalysisScript.standalone(cfgB, File=standaloneFile);
check(isfile(compactFile) && isfile(standaloneFile) && contains(txtC, "EphysAnalysisConfig.load(") ...
    && contains(txtC, "EphysAnalysisRunner(cfg)"), 'both scripts written; the compact one loads the config and runs the runner');
check(~contains(txtS, "EphysAnalysisRunner") && ~contains(txtS, "EphysAnalysisConfig.load(") && contains(txtS, "spikePSTH(") ...
    && contains(txtS, "evokedPotential(") && contains(txtS, "tuningCurve(") && contains(txtS, "probeMapValues(") ...
    && contains(txtS, "spec1.ref.line = ""Stim"";") && contains(txtS, '"schema": "ephys-analysis-config"'), ...
    'the standalone script calls the analysis functions with every spec written out, never the runner');
isErr = @(m) arrayfun(@(x) startsWith(x.id, 'SYNER') || contains(x.message, 'Parse error'), m);
mC = checkcode(compactFile, '-id'); mS = checkcode(standaloneFile, '-id');
check((isempty(mC) || ~any(isErr(mC))) && (isempty(mS) || ~any(isErr(mS))), 'checkcode finds no syntax error in either script');
if ~isempty(mS) && any(isErr(mS)); disp(mS(isErr(mS))); end
outC = runScript(compactFile); %#ok<NASGU>
outS = runScript(standaloneFile);
check(~contains(outS, "FAILED"), 'the standalone script reported no failure');
if contains(outS, "FAILED"); disp(outS); end
pa = dir(fullfile(outA, '**', '*.png')); pb = dir(fullfile(outB, '**', '*.png'));
na = sort(string(erase(fullfile({pa.folder}, {pa.name}), string(outA)))); nb = sort(string(erase(fullfile({pb.folder}, {pb.name}), string(outB))));
check(~isempty(na) && isequal(na, nb), sprintf('the same %d figure files from both scripts', numel(na)));
samePix = true; sameBytes = true;
for k = 1:numel(na)
    a = fullfile(outA, na(k)); b = fullfile(outB, nb(k));
    samePix = samePix && isequal(imread(a), imread(b));
    sameBytes = sameBytes && isequal(fileBytes(a), fileBytes(b));
end
check(samePix, 'every figure is pixel-identical between the two scripts');
fprintf('    (PNG files byte-identical: %s)\n', string(sameBytes));
ha = normalizeHtml(fileread(fullfile(outA, 'analysis_report.html')));
hb = normalizeHtml(fileread(fullfile(outB, 'analysis_report.html')));
check(strlength(ha) > 1000 && ha == hb, 'the HTML reports are equal once timestamps, image bytes and the config are set aside');
ta = pdfPageTexts(fullfile(outA, 'analysis_report.pdf'));
tb = pdfPageTexts(fullfile(outB, 'analysis_report.pdf'));
check(numel(ta) == numel(texts) && isequal(erase(ta(2:end), " "), erase(tb(2:end), " ")) ...   % spaces: where the text extraction puts them varies
    && contains(txtS, "pages(p) = reportPdfPage(fig, report, Files=written);") ...
    && contains(txtS, "Files=files, Images=images, Pages=pages);"), ...
    sprintf('both scripts write the same %d PDF pages (the title page''s time aside), made from the exported figures', numel(ta)));

fprintf('\n== 6. rendering real results ==\n');
src = r.source(1);
fig = newExportFigure(cfg.Export);
figCloser = onCleanup(@() close(fig));
spec = cfg.plotFor("psth_stim");
spec.stack = true; spec.style.MaxTiles = 16;
[Rs, ~, Gs] = r.computePlot(src, spec);
h = renderPlot(Rs, spec, fig);
ax = h.axes(1);
yyaxis(ax, 'left');
check(ismember("nTrials", string(Gs.Properties.VariableNames)) && ~isempty(regexp(char(h.layout.YLabel.String), '^Depth($|  ·  )', 'once')) ...
    && isequal(string(ax.YTickLabel(:)), compose("%.6g", Gs.Depth)), ...
    'a stack of real epochTable groups (which carry nTrials) labels its rows by the groupBy parameter alone');
spec = cfg.plotFor("psth_stim"); spec.style.YLim = [0 2];
Rp = r.computePlot(src, spec);
h = renderPlot(Rp, spec, fig);
nE = numel(Rp.epochGroup);
check(isequal(h.rasterAxes(1).YLim, [0.5 nE + 0.5]) && isequal(h.axes(1).YLim, [0 2]), ...
    sprintf('Style.YLim sets a PSTH''s rates, never its raster (all %d epochs stay in view)', nE));
spec = cfg.plotFor("raster_stim"); spec.style.YLim = [0 2];
Rr = r.computePlot(src, spec);
h = renderPlot(Rr, spec, fig);
check(all(arrayfun(@(a) isequal(a.YLim, [0.5 numel(Rr.epochGroup) + 0.5]), h.axes)), 'a raster plot shows every epoch whatever Style.YLim');
spec.style.MaxTiles = 1;
nU = numel(Rr.raster);
hAll = renderPlot(Rr, spec, fig, Page=2);
tAll = string(hAll.axes(1).Title.String);
R2 = r.computePlot(src, spec, Page=2);
h = renderPlot(R2, spec, fig);
check(nU >= 2 && numel(R2.raster) == 1 && isequal(R2.page, [2 nU]) && plotPageCount(R2, spec) == nU ...
    && h.page == 2 && isequal(string(h.axes(1).Title.String), tAll), ...
    'computePlot Page=2 computes only that page''s unit, and renderPlot draws it as page 2 of them all');
check(ismember("Depth", string(Rr.epochs.Properties.VariableNames)) && string(h.layout.YLabel.String) == "Epoch (by Depth)", ...
    'rasterSort "Depth": computePlot copies Depth onto the epochs and the raster sorts by it');
spec = cfg.plotFor("lfp_stim"); spec.style.YLim = [-50 50];
Rv = r.computePlot(src, spec);
h = renderPlot(Rv, spec, fig);
ax = h.axes(1);
check(spec.layout == "stack" && numel(ax.YTick) == size(Rv.mean, 2) && ax.YLim(1) < min(ax.YTick) && ax.YLim(2) > max(ax.YTick), ...
    'an evoked stack ignores Style.YLim: every channel stays in view');
spec = cfg.plotFor("tuning_depth"); spec.selection.groupBy = "Depth";
Rt = r.computePlot(src, spec);
cap = plotCaption(spec, Rt);
check(~contains(cap, "groups by") && contains(cap, sprintf("n = %d epochs", sum(Rt.n, 'all'))), ...
    "a tuning caption counts its curve's epochs, not the trial groups it ignores: " + cap);
lat = src.trials.RespLatency;            % ms; NaN where the animal did not respond
dep = src.trials.Depth;
okT = src.trials.PairingFlag == "ok";
spec = cfg.plotFor("behavior_lat");
Rb = r.computePlot(src, spec);
want = arrayfun(@(d) mean(lat(okT & dep == d & isfinite(lat))), Rb.x);
check(isequal(sort(Rb.values.y), sort(lat(okT & isfinite(lat)))) && Rb.nMissing == nnz(okT & ~isfinite(lat)) ...
    && max(abs(Rb.mean - want)) < 1e-9 && isequal(Rb.x, unique(dep(okT & isfinite(lat)))), ...
    'behavior: every paired trial''s RespLatency by its Depth, the means per Depth, the misses left out and counted');
h = renderPlot(Rb, spec, fig);
cap = plotCaption(spec, Rb);
check(startsWith(h.title, "Behavior: RespLatency by Depth") && contains(cap, "RespLatency by Depth") ...
    && contains(cap, "from the paired trials") && ~contains(cap, "groups by"), "a behavior plot's title and caption: " + cap);
spec = cfg.plotFor("behavior_stop");
Rb2 = r.computePlot(src, spec);
tr = Rb2.epochs.trial(Rb2.values.epoch);
check(Rb2.units == "ms" && Rb2.yName == "Trough onset latency" && isequal(sort(tr), find(okT & isfinite(lat))) ...
    && max(abs(Rb2.values.y - lat(tr))) < 1500 / src.fs, ...
    'behavior "stop": the Trough onset''s latency after RespWindow onset, ms, is each trial''s RespLatency (within a sample)');
spec = cfg.plotFor("raster_resp");
Rr2 = r.computePlot(src, spec);
M = Rr2.rasterEvents;
hit = true;
for e = find(isfinite(Rr2.epochStop)).'
    hit = hit && any(abs(M(1).t(M(1).epoch == e) - Rr2.epochStop(e)) < 1.5 / src.fs);
end
check(numel(M) == 2 && isequal([M.label], ["Trough onset" "Trough offset"]) && any(isfinite(Rr2.epochStop)) && hit ...
    && isequal(isfinite(Rr2.epochStop), isfinite(lat(Rr2.epochs.trial))), ...
    'a stop at RespWindow onset + RespLatency is each response; a Trough onset is marked there on every row with one');
h = renderPlot(Rr2, spec, fig);
ax = h.axes(1);
dots = findall(ax, 'Tag', 'rasterStop');
[~, top] = min(dots.YData);
check(contains(string(h.layout.YLabel.String), "descending") && contains(string(h.layout.YLabel.String), "groups mixed") ...
    && dots.XData(top) == max(dots.XData) && numel(findall(ax, 'Tag', 'rasterEvent')) >= 2, ...
    'sorted by the response latency, descending, across groups: the latest response on the top row; both edges marked');
cap = plotCaption(spec, Rr2);
check(contains(cap, "stop at RespWindow onset + RespLatency (ms)") && contains(cap, "raster marks: Trough onset, Trough offset") ...
    && contains(cap, "sorted by stop latency, descending across groups"), "the raster's caption: " + cap);
yStop = get(findall(h.axes(1), 'Tag', 'rasterTicks'), 'YData');   % the rows sorted by the stop
spec.rasterSort = "event";   % the same event as the window's stop, as a sort event of its own
spec.rasterSortEvent = eventRef(line="RespWindow", offsetParam="RespLatency");
Rr3 = r.computePlot(src, spec);
h = renderPlot(Rr3, spec, fig);
cap = plotCaption(spec, Rr3);
nNo = nnz(~isfinite(Rr3.rasterSortEvent.t));
check(Rr3.rasterSortEvent.label == "RespWindow onset + RespLatency (ms)" && isequaln(Rr3.rasterSortEvent.t, Rr3.epochStop) ...
    && isequaln(get(findall(h.axes(1), 'Tag', 'rasterTicks'), 'YData'), yStop) ...
    && contains(string(h.layout.YLabel.String), "Epoch (by RespWindow onset + RespLatency (ms) latency)") ...
    && contains(cap, "sorted by RespWindow onset + RespLatency (ms) latency, descending across groups") ...
    && (nNo == 0 || contains(cap, sprintf("%d epoch(s) with no RespWindow onset + RespLatency (ms) after their event sorted last", nNo))), ...
    "rasterSort ""event"" at the stop's own event: its latencies and rows are the stop's; the y label and caption name it: " + cap);
specE = spec; specE.rasterSortEvent = eventRef(line="Nope");
specP = cfg.plotFor("psth_stim"); specP.withRaster = false; specP.rasterSort = "event"; specP.rasterSortEvent = specE.rasterSortEvent;
check(plotSkipReason(src, specE) == "no line Nope" && plotSkipReason(src, specP) == "", ...
    'a sort event on a line the recording lacks skips a raster ("no line Nope"), not a PSTH that draws none');
ev = cfg;
ev.Plots = ev.Plots(ev.plotIndex("raster_resp"));
ev.Plots(1).rasterSort = "event";
ev.Plots(1).rasterSortEvent = struct('line', "RespWindow", 'offsetParam', "RespLatency");
ev.Source.Selection = "list"; ev.Source.Datasets = F.keys(1);
ev.Export.Folder = fullfile(root, "outEvent", "{Name}"); ev.Export.Formats = "png";
ev.Report.Enabled = false;
evFile = fullfile(root, 'scripts', 'run_event_sort.m');
txtE = EphysAnalysisScript.standalone(ev, File=evFile);
outE = runScript(evFile);
check(contains(txtE, "[sortLat, sortLabel] = eventLatency(src, E, spec.rasterSortEvent);") && ~contains(outE, "FAILED") ...
    && ~isempty(dir(fullfile(root, 'outEvent', '**', '*.png'))), ...
    'the standalone script computes the sort event''s latencies and draws the raster sorted by them');
if contains(outE, "FAILED"); disp(outE); end
clear figCloser

fprintf('\n== 7. a failing export closes its page ==\n');
bad = cfg;
bad.Plots = bad.Plots(bad.plotIndex("psth_stim"));
bad.Source.Selection = "list"; bad.Source.Datasets = F.keys(1);
bad.Export.Folder = fullfile(root, "bad|folder", "{Name}");   % cannot be created
bad.Report.Enabled = false;
nFig = numel(findall(groot, 'Type', 'figure'));
Tb = EphysAnalysisRunner(bad, LogFcn=[]).run();
check(height(Tb) == 1 && Tb.Status == "error" && numel(findall(groot, 'Type', 'figure')) == nFig, ...
    'runner: the page whose export fails is closed; the plot is an error row');
badFile = fullfile(root, 'scripts', 'run_bad.m');
EphysAnalysisScript.standalone(bad, File=badFile);
outBad = runScript(badFile);
check(contains(outBad, "FAILED") && numel(findall(groot, 'Type', 'figure')) == nFig, ...
    'standalone script: the page whose export fails is closed too');

fprintf('\n== 8. unit waveforms ==\n');
src = r.source(1);
fig = newExportFigure(cfg.Export);
figCloser = onCleanup(@() close(fig));
spec = cfg.plotFor("raster_stim");
spec.waveform.maxSpikes = 5;
lastwarn('');
Rw = r.computePlot(src, spec);
[~, wid] = lastwarn();
W = Rw.waveforms;
U = src.outputs.load("sorting");
row = find(double(U.unitId) == Rw.meta.unitId(1), 1);
check(numel(W.mean) == height(Rw.meta) && all(W.from == "template") && isequal(W.mean{1}, double(U.templateWaveform{row}(:))) ...
    && all(cellfun(@isempty, W.spikes)) && W.note ~= "" && string(wid) == "unitWaveforms:Templates", ...
    'without the sorted .bin each unit''s template is its mean, with no spikes, and a warning says why');
h = renderPlot(Rw, spec, fig);
C = PlotAesthetics.components(h.layout);
check(nnz(C.Role == "waveMean") == numel(h.axes) && ~any(C.Role == "waveSpikes") ...
    && numel(findall(fig, 'Tag', 'waveLabel')) == numel(h.axes) ...
    && all(arrayfun(@(t) contains(t.String, "(template)"), findall(fig, 'Tag', 'waveLabel'))), ...
    'mode "both" draws a template as the mean alone, labeled as a template');
cap = plotCaption(spec, Rw);
check(contains(cap, "each unit's mean waveform and up to 5 of its spikes on its peak channel") ...
    && contains(cap, sprintf("%d by their template", height(Rw.meta))), "the caption says what the boxes show: " + cap);
sortDir = string(src.outputs.SortingDir);
P = fileread(fullfile(sortDir, 'params.py'));
nCh = str2double(regexp(P, 'n_channels_dat = (\d+)', 'tokens', 'once'));
fsS = str2double(regexp(P, 'sample_rate = ([\d.eE+]+)', 'tokens', 'once'));
nS = round(5 * fsS);                                      % 5 s: later spikes leave the file
datFile = fullfile(sortDir, 'temp_wh.dat');
fid = fopen(datFile, 'w');
fwrite(fid, repmat(int16(10 * (1:nCh).'), 1, nS), 'int16');   % row r holds 10 r: read back (/200) as r / 20
fclose(fid);
Rw2 = r.computePlot(src, spec);
W2 = Rw2.waveforms;
isS = W2.from == "spikes";
vals = true;
for u = find(isS).'
    row = find(double(U.unitId) == Rw2.meta.unitId(u), 1);
    vals = vals && size(W2.spikes{u}, 2) <= 5 && all(abs(W2.spikes{u} - U.ksChannel(row) / 20) < 1e-9, 'all') ...
        && max(abs(W2.mean{u} - U.ksChannel(row) / 20)) < 1e-9 && isequal(W2.timeMs{u}, W.timeMs{u});
end
check(any(isS) && vals && any(cellfun(@(w) size(w, 2), W2.spikes(isS)) == 5) && W2.units(find(isS, 1)) == "whitened" && W2.note == "", ...
    'with the sorted .bin the spikes are cut on each unit''s peak channel, at most maxSpikes of them, and averaged');
h = renderPlot(Rw2, spec, fig);
C = PlotAesthetics.components(h.layout);
check(nnz(C.Role == "waveSpikes") == nnz(isS(1:numel(h.axes))) && nnz(C.Role == "waveBox") == numel(h.axes), ...
    'mode "both" draws the spikes read, in a box in every tile');
delete(datFile);
W3 = unitWaveforms(src, Rw2.meta, Source="units", MaxSpikes=5);
check(all(W3.total(W3.from == "spikes") >= cellfun(@(s) size(s, 2), W3.spikes(W3.from == "spikes"))) ...
    && all(W3.total(W3.from == "spikes") > 0), 'W.total is the unit''s spike count in the recording, not the number drawn');
check(isequal(W3.from, W2.from) && isequal(W3.spikes, W2.spikes), 'the spikes read are kept (CacheData): a redraw does not read the .bin again');
spec.source = "detected";
spec.units.source = "detected";
Rd = r.computePlot(src, spec);
Wd = Rd.waveforms;
D = src.outputs.load("spikes", "detected").detected;          % the synthetic project keeps detection waveforms
u1 = find(Wd.from == "spikes", 1);
wf1 = double(D.wf{double(D.channels) == Rd.meta.unitId(u1)}).';
check(~isempty(u1) && max(abs(Wd.mean{u1} - mean(wf1, 2))) < 1e-9 && size(Wd.spikes{u1}, 2) == min(5, size(wf1, 2)) ...
    && Wd.units(u1) == "uV" && isequal(Wd.timeMs{u1}, double(D.info.waveformTimeMs(:))) && Wd.note == "", ...
    'detections: the spikes file''s waveforms, maxSpikes of them drawn, the mean over all of them');
spec = cfg.plotFor("psth_stim");
R0 = r.computePlot(src, spec);
spec.layout = "overlay";
spec.waveform.mode = "mean";
R1 = r.computePlot(src, spec);
check(~isfield(R0, 'waveforms') && ~isfield(R1, 'waveforms'), 'no waveforms are read with the mode off, or for an overlay of units');
off = cfg;
off.Plots = off.Plots(off.plotIndex("psth_stim"));
check(contains(txtS, "R.waveforms = unitWaveforms(src, R.meta, Source=""units"", MaxSpikes=100);") ...
    && ~contains(EphysAnalysisScript.standalone(off), "unitWaveforms("), ...
    'the standalone script reads the waveforms only for a plot that draws them');
cfgWf = EphysAnalysisConfig().addPlot("waveforms", Id="wf");
cfgWf.Source = cfg.Source;
specWf = cfgWf.plotFor("wf");
Rwf = r.computePlot(src, specWf);
nWf = height(Rwf.meta);
check(plotSkipReason(src, specWf) == "" && Rwf.kind == "waveforms" && numel(Rwf.waveforms.mean) == nWf && nWf > 0 ...
    && any(Rwf.waveforms.from ~= "none") && isempty(Rwf.epochs) && Rwf.n == nWf, ...
    'a waveforms plot computes without events: the units and each one''s waveform');
hWf = renderPlot(Rwf, specWf, fig);
check(numel(hWf.axes) == min(nWf, 16) && ~isempty(findall(fig, 'Tag', 'waveMean')), 'it draws a tile per unit');
specWf.layout = "probe";
hWf = renderPlot(Rwf, specWf, fig);
check(isscalar(hWf.axes) && ~isempty(findall(fig, 'Tag', 'waveMean')) && ~isempty(findall(fig, 'Tag', 'waveSites')), ...
    'on the probe it draws one panel: each unit''s waveform where it sits, the sites behind');
txtWf = EphysAnalysisScript.standalone(cfgWf);
check(contains(txtWf, "R = struct('kind', ""waveforms""") && contains(txtWf, "unitWaveforms(src, R.meta"), ...
    'the standalone script computes it the same way');
clear figCloser

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisRunner:Failures', '%d checks failed.', nFail);
end
end


function out = runScript(file) %#ok<INUSD> used inside evalc
%runScript  Run a script in its own workspace and capture what it prints.
out = evalc('run(file)');
end


function T = pdfPageTexts(file)
%pdfPageTexts  Each page's text, whitespace collapsed (PDFBox, as writePdfReport joins the pages).
doc = org.apache.pdfbox.pdmodel.PDDocument.load(java.io.File(char(file)));
closer = onCleanup(@() doc.close());
strip = org.apache.pdfbox.text.PDFTextStripper();
n = doc.getNumberOfPages();
T = strings(n, 1);
for p = 1:n
    strip.setStartPage(p);
    strip.setEndPage(p);
    T(p) = strtrim(regexprep(string(strip.getText(doc)), '\s+', ' '));
end
end


function h = normalizeHtml(h)
h = string(h);
h = regexprep(h, '<span class="created">[^<]*</span>', '<span class="created"></span>');
h = regexprep(h, 'data:image/png;base64,[^"]+', 'data:image/png;base64,');
h = regexprep(h, '<pre class="config">.*?</pre>', '<pre class="config"></pre>');
end


function b = fileBytes(f)
fid = fopen(f, 'r');
b = fread(fid, Inf, '*uint8');
fclose(fid);
end


function rmdirQuiet(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
