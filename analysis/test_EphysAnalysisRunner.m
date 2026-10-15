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
%   scripts too; and a PSTH with the mean aux magnitude (computePlot against
%   auxMean on the AUX extract, its panels, caption and skip reason, and
%   the standalone script); and session plots over the two datasets (the
%   sessions table, plan rows and skip reasons, a run writing
%   <SessionsFolder>/all_<id>.png and per group / subject files, the
%   report's "Across sessions" section in HTML and PDF, "sessions: ..."
%   Results rows, the run record, the result cache reused, Overwrite off,
%   a cancel during the session plots, a per-dataset report's own
%   <FileName>_sessions); a session plot of every kind, and the compact and
%   the standalone script writing the same session figures (pixel for
%   pixel), report pages and data .mat files; and the data export: epochData on the fixture
%   (counts equal binCounts at t0Continuous and sum to the PSTH's, the
%   epoched LFP equal to evokedPotential's, TooLarge), r.sessionData
%   without Results (spike epochs, epoched signals), and a run with
%   Export.Data.Enabled writing <Data.Folder>\all_<id>.mat; and figures
%   (the Figures section: a raster + PSTH card per unit, a probe map of the
%   dataset, a disabled one): plan rows, run rows (Kind "figure", a file
%   per observation named <Name>_<id>_<unit>), the report's entries (an
%   image and a PDF page per observation, the caption), the run record,
%   Figures= / Plots=string.empty(1, 0), Overwrite off, a cancel between
%   observations, a Canceled from inside a plot's compute rethrown, and
%   the standalone script (figureCompute, no runner) writing the same
%   pixels and HTML report.
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
    'rasterEvents', {struct('line', "Trough", 'edge', {"onset" "offset"})}, 'units', struct('maxUnits', 2)), Id="raster_resp");
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
spec = cfg.plotFor("psth_stim");
spec.aux = EphysAnalysisConfig.normalizeSection("Aux", struct('mode', "magnitude", 'channels', [], 'placement', "below", ...
    'baseline', "subtract", 'baselineWindow', [-0.2 0], 'byGroup', true));
[Ra, Ea, Ga] = r.computePlot(src, spec);
[Ya, fsa, metaA] = selectChannels(src, "AUX");
A0 = auxMean(Ya, fsa, Ea, Window=[spec.window.pre spec.window.post], Mode="magnitude", Baseline=[-0.2 0], Groups=Ga, Meta=metaA);
h = renderPlot(Ra, spec, fig);
cap = plotCaption(spec, Ra);
check(isfield(Ra, 'aux') && isequaln(Ra.aux.mean, A0.mean) && isequaln(Ra.aux.sem, A0.sem) && Ra.aux.fs == fsa ...
    && sum(Ra.aux.nEpochs) + Ra.aux.droppedEdge + Ra.aux.droppedNonFinite == height(Ea) && size(Ra.aux.mean, 2) == 1 ...
    && Ra.aux.labels == "|" + strjoin(metaA.label.', ", ") + "|" && numel(h.auxAxes) == numel(h.axes) ...
    && contains(cap, "aux: mean vector magnitude"), ...
    'computePlot adds the mean aux magnitude over the plot''s own epochs (auxMean on the AUX extract); every tile gets its panel');
specM = spec;
specM.aux = EphysAnalysisConfig.normalizeSection("Aux", struct('mode', "channels", 'statistic', "median", 'transform', "rectify", ...
    'errorType', "iqr"));
RaM = r.computePlot(src, specM);
A1 = auxMean(Ya, fsa, Ea, Window=[spec.window.pre spec.window.post], Mode="channels", Rectify=true, Statistic="median", ...
    ErrorType="iqr", Groups=Ga, Meta=metaA);
check(isequaln(RaM.aux.mean, A1.mean) && RaM.aux.statistic == "median" && RaM.aux.rectified && RaM.aux.err.type == "iqr" ...
    && isequaln(RaM.aux.err.lo, A1.err.lo) && isequaln(RaM.aux.err.hi, A1.err.hi), ...
    'computePlot passes the aux statistic, transform and band choice to auxMean (the median of the rectified channels, an IQR band)');
srcN = src; srcN.signals.AUX = false;
check(plotSkipReason(srcN, spec) == "no AUX extract" && plotSkipReason(srcN, cfg.plotFor("psth_stim")) == "", ...
    'a dataset without an AUX extract skips a plot that draws the aux signal ("no AUX extract"), not one that does not');
cfgX = cfg;
cfgX.Plots = cfgX.Plots(cfgX.plotIndex("psth_stim"));
cfgX.Plots(1).aux = spec.aux;
cfgX.Source.Selection = "list"; cfgX.Source.Datasets = F.keys(1);
cfgX.Export.Folder = fullfile(root, "outAux", "{Name}"); cfgX.Export.Formats = "png";
cfgX.Report.Enabled = false;
axFile = fullfile(root, 'scripts', 'run_aux.m');
txtA = EphysAnalysisScript.standalone(cfgX, File=axFile);
outA2 = runScript(axFile);
check(contains(txtA, "[Ya, fsa, metaA] = selectChannels(src, ""AUX"", Channels=[]);") ...
    && contains(txtA, "R.aux = auxMean(Ya, fsa, E, Window=[-0.2 0.8], Mode=""magnitude"", Baseline=[-0.2 0], ByGroup=true, Groups=G, Meta=metaA);") ...
    && ~contains(outA2, "FAILED") && ~isempty(dir(fullfile(root, 'outAux', '**', '*.png'))), ...
    'the standalone script computes the mean aux signal and draws the PSTH with it');
if contains(outA2, "FAILED"); disp(outA2); end
specS = cfg.plotFor("psth_stim"); specS.style.ErrorType = "std";
Rsd = r.computePlot(src, specS);
specN = specS; specN.style.ShowSEM = false;
Rn = r.computePlot(src, specN);
nG3 = reshape(Rsd.nEpochs, 1, 1, []);
cfgS = cfg; cfgS.Plots(cfgS.plotIndex("psth_stim")).style.ErrorType = "std";
txtS2 = EphysAnalysisScript.standalone(cfgS);
check(Rsd.err.type == "std" && Rn.err.type == "sem" && max(abs(Rsd.err.hi - Rsd.rate - Rsd.sem .* sqrt(nG3)), [], 'all') < 1e-6 ...
    && contains(txtS2, "ErrorType=""std"", ErrorResamples=1000);") && ~contains(txtS, "ErrorType="), ...
    ['computePlot makes the error the style asks for (mean +/- SD; SEM when no error is drawn), and the standalone ' ...
    'script passes it on (only when it is not the default SEM)']);
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

fprintf('\n== 9. session plots ==\n');
cfgS = cfg;
cfgS.Plots = cfg.Plots(ismember(cfg.plotIds(), ["psth_stim" "raster_stim" "lfp_stim" "rate_resp" "behavior_lat"]));
for id = ["psth_stim" "rate_resp" "behavior_lat"]   % drawn only across sessions here
    cfgS.Plots(cfgS.plotIndex(id)).enabled = false;
end
cfgS.Plots(cfgS.plotIndex("raster_stim")).style.MaxTiles = 64;
outS = fullfile(root, 'outSessions');
cfgS.Export.Folder = fullfile(outS, "{Name}");
cfgS.Export.SessionsFolder = fullfile(outS, "sessions");
cfgS.Export.Formats = "png";
cfgS.Report.Folder = outS;
cfgS = cfgS.addSessionPlot("raster_stim", Id="raster_days");
cfgS = cfgS.addSessionPlot(struct('plot', "lfp_stim", 'series', "all", 'showMembers', true), Id="lfp_days");
cfgS = cfgS.addSessionPlot(struct('plot', "psth_stim", 'trialGroups', "combine", 'layout', "overlay"), Id="psth_combine");
cfgS = cfgS.addSessionPlot(struct('plot', "rate_resp", 'trialGroups', "each", 'match', "site"), Id="rate_each");
cfgS = cfgS.addSessionPlot(struct('plot', "behavior_lat", 'facet', "subject"), Id="behavior_days");
sids = cfgS.sessionPlotIds();
I = cfgS.validate();
check(~any(I.Severity == "error"), 'the session plot config validates');
rS = EphysAnalysisRunner(cfgS, LogFcn=[]);
sessS = rS.sessionTable();
subj = unique(sessS.subject);
check(height(sessS) == 2 && issorted(sessS.date) && isequal(sort(sessS.index), [1; 2]) && all(sessS.label ~= "") ...
    && isscalar(subj) && subj ~= "", 'r.sessionTable(): both datasets, by date, one subject');
Tp = rS.plan();
sRows = Tp(startsWith(Tp.Dataset, "sessions: "), :);
check(height(sRows) == numel(sids) && isequal(sRows.Plot, sids.') && all(sRows.Enabled) ...
    && sRows.Dataset(sRows.Plot == "behavior_days") == "sessions: " + subj && all(sRows.Dataset(sRows.Plot ~= "behavior_days") == "sessions: all") ...
    && height(Tp) == 2 * numel(cfgS.Plots) + numel(sids), ...
    'plan: a row per session plot (per subject with facet "subject") after the dataset x plot rows');
cfgB = cfgS;
cfgB = cfgB.addSessionPlot(struct('plot', "nope"), Id="no_base");
cfgB = cfgB.addSessionPlot(struct('plot', "lfp_stim", 'minSessions', 3), Id="three");
cfgB = cfgB.addSessionPlot(struct('plot', "lfp_stim", 'enabled', false), Id="off");
cfgB = cfgB.addSessionPlot(struct('plot', "psth_stim", 'datasets', "list", 'datasetKeys', F.keys(1), 'minSessions', 2), Id="one_listed");
Tb = EphysAnalysisRunner(cfgB, LogFcn=[]).plan(Plots=string.empty(1, 0), SessionPlots=["no_base" "three" "off" "one_listed"]);
rb = @(id) Tb.Reason(Tb.Plot == id);
check(rb("no_base") == "no base plot nope" && startsWith(rb("three"), "fewer than 3 session(s) can draw it") ...
    && rb("off") == "disabled" && startsWith(rb("one_listed"), "fewer than 2 session(s)") && ~any(Tb.Enabled(startsWith(Tb.Dataset, "sessions: "))), ...
    'plan: session plot skip reasons (no base plot, fewer than minSessions sessions, disabled, a list of one dataset)');

made = 0;
oldCreate = get(groot, 'DefaultFigureCreateFcn');
set(groot, 'DefaultFigureCreateFcn', @countFigure);
nFig = numel(findall(groot, 'Type', 'figure'));
RS = rS.run();
set(groot, 'DefaultFigureCreateFcn', oldCreate);
rowsS = RS(startsWith(RS.Dataset, "sessions: "), :);
resEach = rS.computeSessionPlot("rate_each");
check(numel(findall(groot, 'Type', 'figure')) == nFig && all(rowsS.Status == "done") && isequal(unique(rowsS.Plot, 'stable'), sids.') ...
    && nnz(rowsS.Plot == "rate_each") == numel(resEach) && numel(resEach) > 1 && ~any(ismember(rowsS.Dataset, names)) ...
    && all(rowsS.Files ~= ""), ...
    sprintf('run: every session plot done, a "sessions: <label>" row per figure (%d for rate_each, one per Depth group) (%s)', ...
    numel(resEach), strjoin(rowsS.Message(rowsS.Status ~= "done"), "; ")));
sf = fullfile(outS, "sessions");
grpFiles = arrayfun(@(e) fullfile(sf, "all_rate_each_" + regexprep(e.group, '[^\w\-\.]', '_') + ".png"), resEach);
check(isfile(fullfile(sf, "all_raster_days.png")) && isfile(fullfile(sf, "all_lfp_days.png")) && isfile(fullfile(sf, "all_psth_combine.png")) ...
    && all(isfile(grpFiles)) && isfile(fullfile(sf, regexprep(subj, '[^\w\-\.]', '_') + "_behavior_days.png")), ...
    'run: <SessionsFolder>/all_<id>.png, all_<id>_<group>.png for each trial group, <subject>_<id>.png per subject');
htmlS = fullfile(outS, "analysis_report.html");
HS = string(fileread(htmlS));
check(contains(HS, "<h2>Across sessions</h2>") && contains(HS, "<h4>Sessions</h4>") && contains(HS, "raster_days") ...
    && contains(HS, "rate_each (all / ") && contains(HS, "1 section(s)") && contains(HS, sessS.label(1)) ...
    && max([0 strfind(HS, "<h2>Across sessions</h2>")]) > max([0 strfind(HS, "<h2>" + names(2) + "</h2>")]), ...
    'the HTML report: an "Across sessions" section after the datasets, its sessions table and figures');
textsS = pdfPageTexts(fullfile(outS, "analysis_report.pdf"));
nPages = 1;
for D = rS.Report.datasets
    nPages = nPages + 1 + sum(arrayfun(@(e) numel(e.pages), D.entries([D.entries.status] == "done")));
end
secPage = 1 + numel(names) + sum(arrayfun(@(D) sum(arrayfun(@(e) numel(e.pages), D.entries([D.entries.status] == "done"))), ...
    rS.Report.datasets(1:numel(names)))) + 1;
check(numel(textsS) == nPages && contains(textsS(secPage), "Across sessions") && contains(textsS(secPage), "Sessions") ...
    && rS.Report.datasets(end).kind == "section" && numel(rS.Report.datasets(end).entries) == height(rowsS), ...
    sprintf('the PDF report: a summary page for the section, then its figures'' pages (%d pages)', numel(textsS)));
recS = jsondecode(fileread(rS.RunRecordFile));
check(isequal(string(recS.sessionPlots(:)).', sids) && numel(recS.results) == height(RS), 'the run record lists the session plots');
kRaster = EphysAnalysisRunner.cacheKey(rS.Keys(1), cfgS.sessionPlotFor("raster_days"));
check(rS.CacheBytes > 0 && isKey(rS.ResultCache, char(kRaster)) && ismember(kRaster, rS.CacheWanted) ...
    && kRaster == EphysAnalysisRunner.cacheKey(rS.Keys(1), cfgS.plotFor("raster_stim")), ...
    'cache: the per-dataset raster''s result is kept for its session plot (the same key: only looks differ)');
polls = 0; cancelAt = 0;
rS.PollFcn = @onPoll;
[resR, sessR] = rS.computeSessionPlot("raster_days");
rS.PollFcn = [];
check(polls == height(sessR) && resR.status == "done" && numel(resR.R.raster) == sum(resR.R.sessions.nItems) ...
    && all(resR.R.sessions.status == "done"), ...
    'a second computeSessionPlot reads no data: only its own checkpoint per session, every result from the cache');
f0 = dir(fullfile(sf, "all_raster_days.*"));
ro = cfgS; ro.Export.Overwrite = false; ro.Report.Enabled = false;
[ro.Plots.enabled] = deal(false);
Tro = EphysAnalysisRunner(ro, LogFcn=[]).run(SessionPlots="raster_days");
f1 = dir(fullfile(sf, "all_raster_days.*"));
check(height(Tro) == 1 && Tro.Status == "done" && contains(Tro.Files, "all_raster_days.png") && isequal([f0.datenum], [f1.datenum]), ...
    'Overwrite off: a session figure whose files exist is listed, not written again');
r3 = EphysAnalysisRunner(cfgS, LogFcn=[]);
    function onSessionProgress(~, msg)
        if startsWith(msg, "Session plot"); r3.cancel(); end
    end
r3.ProgressFcn = @onSessionProgress;
R3 = r3.run(Export=false, Report=false);
rec3 = jsondecode(fileread(r3.RunRecordFile));
c3 = R3(startsWith(R3.Dataset, "sessions: "), :);
check(height(c3) == numel(sids) && all(c3.Status == "canceled") && isequal(c3.Plot, sids.') && all(R3.Status(~startsWith(R3.Dataset, "sessions: ")) ~= "canceled") ...
    && rec3.outcome == "canceled", 'cancel during the session plots: each one is "canceled", the run record says so');
cfgP = cfgS;
cfgP.SessionPlots = cfgP.SessionPlots(cfgP.sessionPlotIndex("lfp_days"));
[cfgP.Plots.enabled] = deal(false);
cfgP.Report.PerDataset = true; cfgP.Report.Format = "html";
rP = EphysAnalysisRunner(cfgP, LogFcn=[]);
rP.run(Export=false);
check(numel(rP.ReportFiles) == numel(names) + 1 && any(endsWith(rP.ReportFiles, "analysis_report_sessions.html")) ...
    && contains(string(fileread(rP.ReportFiles(endsWith(rP.ReportFiles, "_sessions.html")))), "lfp_days"), ...
    'Report.PerDataset: the session plots get a report of their own, <FileName>_sessions');

% --- every supported kind, and compact vs standalone parity for the session plots --------
cfgQ = cfgS;
for id = ["tuning_depth" "heat_det"]
    cfgQ = cfgQ.addPlot(cfg.Plots(cfg.plotIndex(id)), Id=id);
end
cfgQ = cfgQ.addPlot("waveforms", Id="wf_units");
[cfgQ.Plots.enabled] = deal(false);   % only the session plots draw
cfgQ = cfgQ.addSessionPlot(struct('plot', "tuning_depth"), Id="tuning_days");
cfgQ = cfgQ.addSessionPlot(struct('plot', "heat_det", 'series', "all", 'datasets', "list", 'datasetKeys', flip(F.keys)), Id="heat_days");   % the listed keys, in reverse
cfgQ = cfgQ.addSessionPlot(struct('plot', "wf_units"), Id="wave_days");
cfgQ = cfgQ.addSessionPlot(struct('plot', "psth_stim", 'trialGroups', "each", 'series', "all", 'showMembers', true, ...
    'data', ["results" "epochs"]), Id="psth_each");
cfgQ.SessionPlots(cfgQ.sessionPlotIndex("lfp_days")).data = ["results" "epochs" "signals"];
cfgQ.Export.Formats = "png";
cfgQ.Export.Data.Enabled = true;
cfgQ.Report.Format = "both";
IQ = cfgQ.validate();
check(~any(IQ.Severity == "error"), 'the config with a session plot of every kind validates');
kindsQ = arrayfun(@(sp) string(cfgQ.sessionPlotFor(sp.id).kind), cfgQ.SessionPlots);
check(all(ismember(["psth" "raster" "evoked" "rate" "tuning" "behavior" "heatmap" "waveforms"], kindsQ)), ...
    'session plots over psth, raster, evoked, rate, tuning, behavior, heatmap and waveforms');
outQA = fullfile(root, 'outQA'); outQB = fullfile(root, 'outQB');
cfgQA = cfgQ; cfgQB = cfgQ;
for c = ["A" "B"]
    o = fullfile(root, "outQ" + c);
    q = cfgQ;
    q.Export.Folder = fullfile(o, "{Name}"); q.Export.SessionsFolder = fullfile(o, "sessions");
    q.Export.Data.Folder = fullfile(o, "data"); q.Report.Folder = o;
    if c == "A"; cfgQA = q; else; cfgQB = q; end
end
cfgQA = cfgQA.save(fullfile(root, 'analysisQ.json'));
compactQ = fullfile(root, 'scripts', 'run_sessions_compact.m');
standaloneQ = fullfile(root, 'scripts', 'run_sessions_standalone.m');
EphysAnalysisScript.compact(cfgQA, File=compactQ);
txtQ = EphysAnalysisScript.standalone(cfgQB, File=standaloneQ);
check(contains(txtQ, "%% Session plots") && contains(txtQ, "sessionTable(names(sel).'") && contains(txtQ, "sessionResults(Rs, sessions, sp, spec)") ...
    && contains(txtQ, "addReportSection(report, ""Across sessions""") && contains(txtQ, "writeAnalysisData(dfile, S") ...
    && contains(txtQ, "epochData(src, spec, Signals=true") && ~contains(txtQ, "EphysAnalysisRunner") && ~contains(txtQ, "computeSessionPlot"), ...
    'the standalone script has the Session plots block: sessionTable, sessionResults, addReportSection, epochData and writeAnalysisData, never the runner');
mQ = checkcode(standaloneQ, '-id');
check(isempty(mQ) || ~any(isErr(mQ)), 'checkcode finds no syntax error in the session script');
if ~isempty(mQ) && any(isErr(mQ)); disp(mQ(isErr(mQ))); end
runScript(compactQ);
outSQ = runScript(standaloneQ);
check(~contains(outSQ, "FAILED"), 'the standalone script reported no failure over the session plots');
if contains(outSQ, "FAILED"); disp(outSQ); end
paQ = dir(fullfile(outQA, 'sessions', '*.png')); pbQ = dir(fullfile(outQB, 'sessions', '*.png'));
naQ = sort(string({paQ.name})); nbQ = sort(string({pbQ.name}));
check(numel(naQ) >= numel(cfgQ.SessionPlots) + 1 && isequal(naQ, nbQ) ...
    && all(ismember(["all_raster_days.png" "all_tuning_days.png" "all_heat_days.png" "all_wave_days.png"], naQ)), ...
    sprintf('both scripts write the same %d session figure files (%d session plots; trial groups and a subject facet add files)', numel(naQ), numel(cfgQ.SessionPlots)));
samePixQ = true;
for k = 1:numel(naQ)
    same = isequal(imread(fullfile(outQA, 'sessions', naQ(k))), imread(fullfile(outQB, 'sessions', nbQ(k))));
    if ~same; fprintf(2, '    %s differs\n', naQ(k)); end
    samePixQ = samePixQ && same;
end
check(samePixQ, 'every session figure is pixel-identical between the compact and the standalone script');
haQ = normalizeHtml(fileread(fullfile(outQA, 'analysis_report.html')));
hbQ = normalizeHtml(fileread(fullfile(outQB, 'analysis_report.html')));
check(contains(haQ, "<h2>Across sessions</h2>") && haQ == hbQ, 'the HTML reports, with their Across sessions section, are equal between the scripts');
if haQ ~= hbQ; showHtmlDiff(haQ, hbQ); end
taQ = pdfPageTexts(fullfile(outQA, 'analysis_report.pdf'));
tbQ = pdfPageTexts(fullfile(outQB, 'analysis_report.pdf'));
check(numel(taQ) == numel(tbQ) && numel(taQ) > 3 && isequal(erase(taQ(2:end), " "), erase(tbQ(2:end), " ")), ...
    sprintf('both scripts write the same %d PDF pages for the session plots', numel(taQ)));
daQ = dir(fullfile(outQA, 'data', '*.mat')); dbQ = dir(fullfile(outQB, 'data', '*.mat'));
check(isequal(sort(string({daQ.name})), sort(string({dbQ.name}))) && numel(daQ) == numel(cfgQ.SessionPlots), ...
    sprintf('both scripts write the same %d data files, one per session plot', numel(daQ)));
sameData = true;
for k = 1:numel(daQ)
    LA = load(fullfile(outQA, 'data', daQ(k).name));
    LB = load(fullfile(outQB, 'data', daQ(k).name));
    same = isequaln(dataForCompare(LA), dataForCompare(LB)) && LA.config.name == LB.config.name ...
        && isequal(cellfun(@(f) strrep(string(f), string(outQA), ""), {LA.results.files}, 'UniformOutput', false), ...
                   cellfun(@(f) strrep(string(f), string(outQB), ""), {LB.results.files}, 'UniformOutput', false));
    if ~same
        dA = dataForCompare(LA); dB = dataForCompare(LB);
        bad = string(fieldnames(dA)); bad = bad(arrayfun(@(f) ~isequaln(dA.(f), dB.(f)), bad));
        fprintf(2, '    data file %s differs (%s)\n', daQ(k).name, strjoin(bad, ", "));
        for q = 1:min(numel(dA.perSession), numel(dB.perSession))
            if ~isequaln(dA.perSession{q}, dB.perSession{q})
                fa = string(fieldnames(dA.perSession{q}));
                fprintf(2, '      perSession{%d}: %s\n', q, strjoin(fa(arrayfun(@(f) ~isequaln(dA.perSession{q}.(f), dB.perSession{q}.(f)), fa)), ", "));
            end
        end
    end
    sameData = sameData && same;
end
check(sameData, 'every session data .mat is equal between the scripts (created, provenance, the config and file paths aside)');

% the per-dataset report mode: the session plots' own report
cfgQP = cfgQ;
cfgQP.SessionPlots = cfgQP.SessionPlots(cfgQP.sessionPlotIndex("lfp_days"));
cfgQP.Export.Data.Enabled = false; cfgQP.Report.PerDataset = true; cfgQP.Report.Format = "html";
cfgQPA = cfgQP; cfgQPB = cfgQP;
for c = ["A" "B"]
    o = fullfile(root, "outQP" + c);
    q = cfgQP;
    q.Export.Folder = fullfile(o, "{Name}"); q.Export.SessionsFolder = fullfile(o, "sessions"); q.Report.Folder = o;
    if c == "A"; cfgQPA = q; else; cfgQPB = q; end
end
cfgQPA = cfgQPA.save(fullfile(root, 'analysisQP.json'));
compactQP = fullfile(root, 'scripts', 'run_sessions_pd_compact.m');
standaloneQP = fullfile(root, 'scripts', 'run_sessions_pd_standalone.m');
EphysAnalysisScript.compact(cfgQPA, File=compactQP);
EphysAnalysisScript.standalone(cfgQPB, File=standaloneQP);
runScript(compactQP);
outSQP = runScript(standaloneQP);
fqA = fullfile(root, 'outQPA', 'analysis_report_sessions.html'); fqB = fullfile(root, 'outQPB', 'analysis_report_sessions.html');
check(~contains(outSQP, "FAILED") && isfile(fqA) && isfile(fqB) && normalizeHtml(fileread(fqA)) == normalizeHtml(fileread(fqB)) ...
    && contains(fileread(fqA), "lfp_days") && isequal(imread(fullfile(root, 'outQPA', 'sessions', 'all_lfp_days.png')), imread(fullfile(root, 'outQPB', 'sessions', 'all_lfp_days.png'))), ...
    'Report.PerDataset: both scripts write the same <FileName>_sessions report and session figure');

fprintf('\n== 10. data export: epochData, r.sessionData, Export.Data ==\n');
src1 = rS.source(1);
specD = cfgS.plotFor("psth_stim");
wD = specD.window;
D = epochData(src1, specD);
[Ed, Gd] = epochTable(src1, specD.ref, Window=wD, Selection=specD.selection);
[trainsD, metad] = selectUnits(src1, specD.units, Ref=specD.ref, Selection=specD.selection);
nEd = height(Ed); nUd = numel(trainsD); nBd = numel(D.spikes.t);
okCounts = isequal(size(D.spikes.counts), [nEd nBd nUd]) && isequal(size(D.spikes.times), [nEd nUd]);
okTimes = true;
for u = 1:nUd
    ref = binCounts(trainsD{u}, Ed.t0Continuous, D.spikes.edges).';
    okCounts = okCounts && isequal(D.spikes.counts(:, :, u), ref);
    inside = cellfun(@(x) all(x >= wD.pre - 1e-9 & x < wD.post) && issorted(x), D.spikes.times(:, u));
    okTimes = okTimes && all(inside) && sum(cellfun(@numel, D.spikes.times(:, u))) == sum(ref, 'all');
end
Rp = spikePSTH(trainsD, Ed, Window=[wD.pre wD.post], BinSec=specD.bins.BinSec, Groups=Gd, Meta=metad, Raster=false);
okPsth = true;
for g = 1:height(Gd)
    okPsth = okPsth && isequal(reshape(sum(D.spikes.counts(Ed.groupIndex == g, :, :), 1), nBd, nUd), Rp.count(:, :, g));
end
check(nEd > 0 && nUd > 0 && isequal(D.E.t0Continuous, Ed.t0Continuous) && ismember("Depth", string(D.E.Properties.VariableNames)) ...
    && isequal(D.meta.unitId, metad.unitId) && okCounts && okPsth && isequal(D.spikes.edges, Rp.edges) && isequal(D.spikes.t, Rp.t), ...
    sprintf('epochData: %d epochs x %d bins x %d units of counts equal binCounts at t0Continuous, and sum to the PSTH''s counts', nEd, nBd, nUd));
check(okTimes && D.identity.name == src1.name && D.identity.fs == src1.fs && D.identity.key == src1.key && isequaln(D.spec, specD) ...
    && isempty(D.signals) && isstruct(D.provenance) && strlength(D.created) > 0, ...
    'epochData: spike times sorted and inside [pre post), as many as the counts; the identity, the spec and the provenance');
check(strcmp(errorIdOf(@() epochData(src1, specD, MaxMB=1e-6)), 'epochData:TooLarge') ...
    && isempty(epochData(src1, specD, Spikes=false).spikes) && size(epochData(src1, specD, Counts=false).spikes.counts, 2) == 0, ...
    'epochData: TooLarge before the counts are made; Spikes=false and Counts=false leave them out');

specL = cfgS.plotFor("lfp_stim");
wL = specL.window;
DL = epochData(src1, specL, Signals=true);
[YL, fsL, mL] = selectChannels(src1, "LFP", Channels=specL.channels);
[EL, GL] = epochTable(src1, specL.ref, Window=wL, Selection=specL.selection, Baseline=specL.baseline.Window);
Rv = evokedPotential(YL, fsL, EL, Window=[wL.pre wL.post], Groups=GL, Meta=mL, KeepEpochs=true);
e1 = DL.signals.epochs.epoch(1);
rows = round(EL.t0Continuous(EL.epoch == e1) * fsL) + 1 + (round(wL.pre * fsL):round(wL.post * fsL));
check(isequal(DL.signals.data, Rv.data) && DL.signals.dims == "time x channel x epoch" && isequal(DL.signals.t, Rv.t) && DL.signals.fs == fsL ...
    && isequal(DL.signals.epochs.epoch, Rv.keptEpochs) && size(DL.signals.data, 3) == height(DL.signals.epochs) && isa(DL.signals.data, 'single') ...
    && isequal(DL.signals.data(:, :, 1), YL(rows(:), :)) && height(DL.meta) == size(DL.signals.data, 2) && isempty(DL.spikes), ...
    'epochData signals: the kept epochs'' samples as evokedPotential cuts them, the first one the rows round(t0Continuous*fs)+1 + (s0:s1) of the signal');
check(strcmp(errorIdOf(@() epochData(src1, specL, Signals=true, MaxMB=1e-6)), 'epochData:TooLarge') && isempty(epochData(src1, specL).signals), ...
    'epochData: epoched signals over MaxMB are refused before they are cut, and read only with Signals=true');
src1.outputs.clearCache();

cfgD = cfgS;
cfgD = cfgD.addSessionPlot(struct('plot', "psth_stim", 'data', ["results" "epochs"]), Id="psth_data");
cfgD = cfgD.addSessionPlot(struct('plot', "lfp_stim", 'data', ["epochs" "signals"]), Id="lfp_data");
rD = EphysAnalysisRunner(cfgD, LogFcn=[]);
S1 = rD.sessionData("psth_data");
spD = cfgD.sessionPlotFor("psth_data");
Dk = epochData(rD.source(S1.sessions.index(1)), spD);
check(S1.schema == "ephys-analysis-sessions/1" && height(S1.sessions) == 2 && all(S1.sessions.status == "done") && isscalar(S1.results) ...
    && S1.results(1).R.kind == "psth" && numel(S1.perSession) == 2 && S1.perSession{1}.kind == "psth" && numel(S1.epochs) == 2 ...
    && ~any(cellfun(@isempty, S1.epochs)) && S1.epochs{1}.identity.label == S1.sessions.label(1) && S1.epochs{2}.identity.label == S1.sessions.label(2) ...
    && S1.epochs{1}.identity.subject == S1.sessions.subject(1) && isequal(S1.epochs{1}.spikes.counts, Dk.spikes.counts) ...
    && height(S1.epochs{2}.meta) == numel(S1.perSession{2}.labels) && isequal(S1.sessions.nItems, [numel(S1.perSession{1}.labels); numel(S1.perSession{2}.labels)]) ...
    && S1.config.name == cfgD.Name && rD.CacheBytes > 0, ...
    'r.sessionData without Results: computes the sessions'' results and each one''s epochs, labeled and ordered like the sessions table');
Tl = epochLongTable(S1);
Tn = epochLongTable(S1, What="counts");
check(height(Tl) == sum(S1.sessions.nItems) * numel(S1.perSession{1}.t) && isequal(unique(Tl.session).', [1 2]) ...
    && height(Tn) == sum(cellfun(@(d) numel(d.spikes.counts), S1.epochs)) && all(ismember(unique(Tn.session), S1.sessions.label)), ...
    'epochLongTable over the real data: values per session-unit and bin, counts per epoch, unit and bin');
S2 = rD.sessionData("lfp_data");
nKept = size(S2.epochs{1}.signals.data, 3);
check(isempty(S2.perSession) && numel(S2.epochs) == 2 && S2.epochs{1}.signals.dims == "time x channel x epoch" ...
    && nKept == height(S2.epochs{1}.signals.epochs) && size(S2.epochs{2}.signals.data, 2) == height(S2.epochs{2}.meta) ...
    && strcmp(errorIdOf(@() rD.sessionData("lfp_data", [], MaxMB=1e-6)), 'epochData:TooLarge'), ...
    'r.sessionData with "signals": the epoched samples of every session; MaxMB refuses them (TooLarge)');
Tsg = epochLongTable(S2, What="signals");
check(height(Tsg) == sum(cellfun(@(d) numel(d.signals.data), S2.epochs)), 'epochLongTable signals over the real data: a row per epoch, channel and sample');

outE = fullfile(root, 'outData');
dataDir = fullfile(outE, 'data');
cfgE = cfgD;
[cfgE.Plots.enabled] = deal(false);
cfgE.Export.Folder = fullfile(outE, "{Name}");
cfgE.Export.SessionsFolder = fullfile(outE, "sessions");
cfgE.Export.Formats = "png";
cfgE.Report.Enabled = false;
cfgE.Export.Data.Folder = dataDir;
rOff = EphysAnalysisRunner(cfgE, LogFcn=[]);
rOff.run(SessionPlots="psth_data");
check(~isfolder(dataDir) || isempty(dir(fullfile(dataDir, '*.mat'))), 'Export.Data off (the default): no data file is written');
cfgE.Export.Data.Enabled = true;
rE = EphysAnalysisRunner(cfgE, LogFcn=[]);
RE = rE.run(SessionPlots=["psth_data" "lfp_days"]);
dfile = fullfile(dataDir, "all_psth_data.mat");
dfile2 = fullfile(dataDir, "all_lfp_days.mat");
rowsE = RE(startsWith(RE.Dataset, "sessions: "), :);
L = load(dfile);
L2 = load(dfile2);
check(all(rowsE.Status == "done") && isfile(dfile) && isfile(dfile2) && contains(rowsE.Files(rowsE.Plot == "psth_data"), dfile) ...
    && height(L.sessions) == 2 && L.results(1).R.kind == "psth" && numel(L.perSession) == 2 && numel(L.epochs) == 2 ...
    && L.epochs{1}.spikes.counts(1) >= 0 && L.sessionPlot.id == "psth_data" && L2.results(1).R.kind == "evoked" && height(L2.sessions) == 2 ...
    && numel(L2.perSession) == 2 && isempty(L2.epochs) && any(contains(L.results(1).files, "all_psth_data_p1.png")), ...
    'run with Export.Data.Enabled: <Data.Folder>\all_<id>.mat holds sessions (2 rows), results(1).R, the per-session results and epochs, the figure files');
cfgE.Export.Overwrite = false;
RE2 = EphysAnalysisRunner(cfgE, LogFcn=[]).run(SessionPlots="psth_data");
check(any(contains(RE2.Message, "data file:")) && any(contains(RE2.Message, "exists")), ...
    'Export.Overwrite off: an existing data file is kept and the run says so in the row''s message');

fprintf('\n== 11. figures (the Figures section) in plan, run, report and the standalone script ==\n');
outF = fullfile(root, 'outFig');
cfgF = EphysAnalysisConfig();
cfgF.Name = "figures test";
cfgF.Source.Root = F.proj;
cfgF.Defaults = cfg.Defaults;
cfgF = cfgF.addPlot(struct('kind', "evoked", 'source', "LFP", 'window', struct('pre', -0.1, 'post', 0.4)), Id="lfp_stim");
cfgF = cfgF.addFigure("rasterPsth", Id="card");
cfgF.Figures(1).observe.units.maxUnits = 3;
cfgF = cfgF.addFigure("probemap", Id="map");
cfgF = cfgF.addFigure("waveforms", Id="off");
cfgF.Figures(3).enabled = false;
cfgF.Export.Formats = "png";
cfgF.Export.FilenamePattern = "{Name}_{Plot}";
cfgF.Export.Folder = fullfile(outF, "{Name}");
cfgF.Export.Dpi = 50;
cfgF.Export.FigureSizeCm = [12 8];
cfgF.Report.Format = "both";
cfgF.Report.Folder = outF;
cfgF.Report.Dpi = 40;
IF = cfgF.validate();
check(~any(IF.Severity == "error"), 'the figures config validates');
rF = EphysAnalysisRunner(cfgF, LogFcn=[]);
nObs = zeros(1, 2);
obsOf = cell(1, 2);
for k = 1:2
    obsOf{k} = figureObservations(rF.source(k), cfgF.figureFor("card"));
    nObs(k) = height(obsOf{k});
end
TF = rF.plan();
fr = TF(TF.Kind == "figure", :);
check(height(TF) == 2 * 4 && height(fr) == 2 * 3 && all(fr.Source(fr.Plot == "card") == "unit") ...
    && all(fr.Source(fr.Plot == "map") == "dataset") && all(fr.Enabled(fr.Plot ~= "off")) && all(fr.Reason(fr.Plot == "off") == "disabled") ...
    && all(nObs >= 2 & nObs <= 3), ...
    sprintf('plan: a row per dataset and figure (Kind "figure", Source the observe kind; a disabled one "disabled"); %s units observed', mat2str(nObs)));
TFp = rF.plan(Figures=string.empty(1, 0));
TFf = rF.plan(Plots=string.empty(1, 0), Figures="map");
check(~any(TFp.Kind == "figure") && height(TFp) == 2 && height(TFf) == 2 && all(TFf.Plot == "map"), ...
    'plan: Figures=string.empty(1, 0) lists none; Plots=string.empty(1, 0), Figures="map" only that figure');
% plan loads no bulk data for figures: with the LFP file moved away after the source is read, a channel figure still plans
cfgL = cfgF.addFigure("continuous", Id="lfp_fig");
rL = EphysAnalysisRunner(cfgL, LogFcn=[]);
srcL = rL.source(1);
rL.Outputs(1).clearCache();
lfpFile = srcL.outputs.signalFile("LFP");
movefile(lfpFile, lfpFile + ".away");
restoreLfp = onCleanup(@() movefile(lfpFile + ".away", lfpFile));
TL = rL.plan(Datasets=1, Plots=string.empty(1, 0), Figures=["lfp_fig" "card" "map"]);
clear restoreLfp
check(isfile(lfpFile) && height(TL) == 3 && all(TL.Reason == "") && all(TL.Enabled) && TL.Source(TL.Plot == "lfp_fig") == "channel", ...
    sprintf('plan decides a figure from cheap facts: no extract or spikes are loaded (the LFP file was away; reasons: %s)', strjoin("""" + TL.Reason + """", ", ")));
nFig = numel(findall(groot, 'Type', 'figure'));
RF = rF.run();
check(numel(findall(groot, 'Type', 'figure')) == nFig, 'the run with figures leaves no figure open');
fRows = RF(RF.Kind == "figure", :);
check(height(RF) == 2 * 3 && height(fRows) == 4 && all(fRows.Status == "done") && ~any(RF.Plot == "off") ...
    && all(fRows.Message(fRows.Plot == "card") == compose("%d observation(s)", nObs.')), ...
    sprintf('run: one row per dataset and enabled figure, Kind "figure", done (%s)', strjoin(RF.Status + ": " + RF.Message, "; ")));
namesOk = true;
for k = 1:2
    d = fullfile(outF, names(k));
    T1 = obsOf{k};
    want = arrayfun(@(i) string(fullfile(d, names(k) + "_card_" + shortUnitLabels(T1.meta{i}.label) + ".png")), 1:height(T1));
    got = split(fRows.Files(fRows.Dataset == names(k) & fRows.Plot == "card"), "; ").';
    namesOk = namesOk && all(isfile(want)) && isequal(sort(got), sort(want)) ...
        && fRows.Files(fRows.Dataset == names(k) & fRows.Plot == "map") == string(fullfile(d, names(k) + "_map.png"));
end
check(namesOk, 'a file per observation, <Name>_<figure>_<unit>.png ("_<Unit>" since the pattern has no {Unit}); one dataset figure as <Name>_map.png');
EF = [rF.Report.datasets.entries];
eC = EF([EF.plot] == "card");
eM = EF([EF.plot] == "map");
check(numel(eC) == 2 && all([eC.kind] == "figure") && isequal(arrayfun(@(e) numel(e.images), eC), nObs) ...
    && isequal(arrayfun(@(e) numel(e.pages), eC), nObs) && all(startsWith([eC.caption], "card: " + nObs + " observations")) ...
    && numel(eM) == 2 && all(arrayfun(@(e) numel(e.pages), eM) == 1) && contains(eM(1).caption, "1 observation (the dataset)"), ...
    'the report: one entry per dataset and figure (kind "figure"), an image and a PDF page per observation, figureCaption''s caption');
HF = string(fileread(fullfile(outF, "analysis_report.html")));
check(contains(HF, "<span class=""kind"">figure</span>") && contains(HF, htmlEscape(eC(1).caption)) ...
    && contains(HF, "_card_" + shortUnitLabels(obsOf{1}.meta{1}.label) + ".png"), ...
    'the HTML shows each figure''s kind, caption and links to its observations'' files');
tF = pdfPageTexts(fullfile(outF, "analysis_report.pdf"));
nPagesF = sum(arrayfun(@(e) numel(e.pages), EF([EF.status] == "done")));
check(numel(tF) == 1 + 2 + nPagesF && sum(arrayfun(@(e) numel(e.pages), [eC eM])) == sum(nObs) + 2, ...
    sprintf('the PDF: title, a summary per dataset and every page (%d pages: the plot''s, an observation each, the maps)', numel(tF)));
recF = jsondecode(fileread(rF.RunRecordFile));
check(isequal(string(recF.figures(:)).', ["card" "map"]) && isequal(string(recF.plots), "lfp_stim"), 'the run record lists the figures run');
roF = cfgF; roF.Export.Overwrite = false; roF.Report.Enabled = false;
before = dir(fullfile(outF, names(1), names(1) + "_card_*.png"));
RO = EphysAnalysisRunner(roF, LogFcn=[]).run(Datasets=1, Figures="card", Plots=string.empty(1, 0));
after = dir(fullfile(outF, names(1), names(1) + "_card_*.png"));
check(height(RO) == 1 && RO.Plot == "card" && RO.Status == "done" && numel(split(RO.Files, "; ")) == nObs(1) ...
    && isequal([before.datenum], [after.datenum]), ...
    'run(Figures="card", Plots=string.empty(1, 0)) runs that figure alone; Overwrite off keeps (and lists) every observation''s files');

% one figure per trial group: a file per unit and group, the group in its name
outPg = fullfile(root, 'outFigGroup');
cfgPg = cfgF;
cfgPg.Figures(1).observe.perGroup = true;
cfgPg.Export.Folder = fullfile(outPg, "{Name}");
cfgPg.Report.Enabled = false;
Tpg = figureObservations(EphysAnalysisRunner(cfgPg, LogFcn=[]).source(1), cfgPg.figureFor("card"));
nGpg = numel(unique(Tpg.group));
RPg = EphysAnalysisRunner(cfgPg, LogFcn=[]).run(Datasets=1, Figures="card", Plots=string.empty(1, 0));
filesPg = split(RPg.Files, "; ");
wantPg = strings(height(Tpg), 1);
for i = 1:height(Tpg)
    wantPg(i) = string(fullfile(outPg, names(1), names(1) + "_card_" + shortUnitLabels(Tpg.meta{i}.label) + "_" ...
        + regexprep(Tpg.groupLabel(i), '[^\w\-\.]', '_') + ".png"));
end
check(height(RPg) == 1 && RPg.Status == "done" && nGpg >= 2 && height(Tpg) == nObs(1) * nGpg && numel(filesPg) == height(Tpg) ...
    && isequal(sort(filesPg), sort(wantPg)) && all(isfile(wantPg)) && RPg.Message == compose("%d observation(s)", height(Tpg)), ...
    sprintf('perGroup: one file per unit and trial group (%d x %d), <Name>_card_<unit>_<group>.png', nObs(1), nGpg));

% cancel between observations, and a Canceled from inside a plot's compute
outCx = fullfile(root, 'outFigCancel');
cfgC = cfgF; cfgC.Export.Folder = fullfile(outCx, "{Name}"); cfgC.Report.Enabled = false;
rC = EphysAnalysisRunner(cfgC, LogFcn=[]);
    function onFigProgress(~, msg)
        if contains(msg, ": card (2/"); rC.cancel(); end
    end
rC.ProgressFcn = @onFigProgress;
nFig = numel(findall(groot, 'Type', 'figure'));
RC = rC.run();
st = @(ds, id) RC.Status(RC.Dataset == ds & RC.Plot == id);
check(height(RC) == 6 && st(names(1), "lfp_stim") == "done" && st(names(1), "card") == "canceled" && st(names(1), "map") == "canceled" ...
    && all(RC.Status(RC.Dataset == names(2)) == "canceled") && all(RC.Kind(RC.Plot ~= "lfp_stim") == "figure") ...
    && isscalar(dir(fullfile(outCx, names(1), names(1) + "_card_*.png"))) && numel(findall(groot, 'Type', 'figure')) == nFig, ...
    'cancel() between a figure''s observations: the first page is written, the figure and the rest are "canceled"');
rP = EphysAnalysisRunner(cfgC, LogFcn=[]);
rP.PollFcn = @() rP.cancel();   % the first checkpoint inside computePlot cancels
RP = rP.run(Export=false, Report=false);
check(height(RP) == 6 && all(RP.Status == "canceled"), ...
    sprintf('a Canceled thrown inside a plot''s compute is rethrown: every row "canceled", none "error" (%s)', strjoin(unique(RP.Status), ", ")));

% the standalone script: figureCompute, runner-free, the same pages
outSA = fullfile(root, 'outFigScript');
cfgSA = cfgF; cfgSA.Export.Folder = fullfile(outSA, "{Name}"); cfgSA.Report.Folder = outSA;
saFile = fullfile(root, 'scripts', 'run_figures.m');
txtF = EphysAnalysisScript.standalone(cfgSA, File=saFile);
check(~contains(txtF, "EphysAnalysisRunner") && contains(txtF, "fspec1 = struct();") && ~contains(txtF, "fspec3") ...
    && contains(txtF, "fres = figureCompute(src, fspec, Observation=obsT(i, :));") && contains(txtF, "renderFigure(fres, fspec, fig)") ...
    && contains(txtF, "Caption=figureCaption(fspec, obsT, Dataset=name)"), ...
    'the standalone script writes each enabled figure''s spec and computes it with figureCompute, never the runner');
mF = checkcode(saFile, '-id');
check(isempty(mF) || ~any(isErr(mF)), 'checkcode finds no syntax error in the figures script');
outFS = runScript(saFile);
check(~contains(outFS, "FAILED") && contains(outFS, "card done"), 'the figures script ran without a failure');
if contains(outFS, "FAILED"); disp(outFS); end
pa = dir(fullfile(outF, '**', '*.png')); pb = dir(fullfile(outSA, '**', '*.png'));
na = sort(string(erase(fullfile({pa.folder}, {pa.name}), string(outF))));
nb = sort(string(erase(fullfile({pb.folder}, {pb.name}), string(outSA))));
samePixF = ~isempty(na) && isequal(na, nb);
if ~isequal(na, nb); fprintf(2, '    runner: %s\n    script: %s\n', strjoin(na, ", "), strjoin(nb, ", ")); end
for k = 1:min(numel(na), numel(nb))
    ia = imread(fullfile(outF, na(k))); ib = imread(fullfile(outSA, nb(k)));
    same = isequal(ia, ib);
    if ~same
        if isequal(size(ia), size(ib))
            nDiff = nnz(any(ia ~= ib, 3));
            [rr, cc] = find(any(ia ~= ib, 3));
            fprintf(2, '    %s differs: %d pixels, rows %d-%d, cols %d-%d of %s\n', na(k), nDiff, ...
                min(rr), max(rr), min(cc), max(cc), mat2str(size(ia)));
            % seen intermittently: a handful of antialiased pixels of one text label (the x label's
            % box) in the first figure page of a run; tolerated, any wider difference is a failure
            same = nDiff <= 16 && max(rr) - min(rr) < 20 && max(cc) - min(cc) < 60;
        else
            fprintf(2, '    %s differs in size: %s vs %s\n', na(k), mat2str(size(ia)), mat2str(size(ib)));
        end
    end
    samePixF = samePixF && same;
end
check(samePixF && any(contains(na, "_card_")), sprintf('the script''s %d PNGs (each observation''s too) are pixel-identical to the runner''s (a few antialiased label pixels tolerated)', numel(na)));
hR = normalizeHtml(fileread(fullfile(outF, 'analysis_report.html')));
hS = normalizeHtml(fileread(fullfile(outSA, 'analysis_report.html')));
check(hR == hS && numel(pdfPageTexts(fullfile(outSA, 'analysis_report.pdf'))) == numel(tF), ...
    'the script''s HTML report equals the runner''s (timestamps, image bytes and the config aside), and its PDF has as many pages');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisRunner:Failures', '%d checks failed.', nFail);
end
end


function S = dataForCompare(S)
%dataForCompare  A session data file's contents without what differs run to run (created, provenance), the config and file paths.
for f = ["created" "provenance" "config"]
    if isfield(S, f); S = rmfield(S, f); end
end
if isfield(S, 'results') && isfield(S.results, 'files'); S.results = rmfield(S.results, 'files'); end
for c = ["epochs" "perSession"]   % per-session structs: each result and epochData carries a timestamp (and provenance)
    if isfield(S, c)
        for k = 1:numel(S.(c))
            drop = ["created" "provenance"];
            if c == "perSession"; drop(end+1) = "spec"; end   % the runner's cached result keeps the spec of the plot that computed it first
            for f = drop
                if isstruct(S.(c){k}) && isfield(S.(c){k}, f); S.(c){k} = rmfield(S.(c){k}, f); end
            end
        end
    end
end
for i = 1:numel(S.results)   % the merged results
    if isfield(S.results(i).R, 'created'); S.results(i).R = rmfield(S.results(i).R, 'created'); end
end
end


function id = errorIdOf(fcn)
%errorIdOf  The identifier of the error FCN throws ('' when it does not).
id = '';
try
    fcn();
catch ME
    id = ME.identifier;
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


function showHtmlDiff(a, b)
%showHtmlDiff  Print the first lines where two HTML reports differ.
la = splitlines(a); lb = splitlines(b);
n = 0;
for k = 1:max(numel(la), numel(lb))
    x = ""; y = "";
    if k <= numel(la); x = la(k); end
    if k <= numel(lb); y = lb(k); end
    if x ~= y
        fprintf(2, '    line %d\n      A: %s\n      B: %s\n', k, extractBefore(x + blanks(300), 301), extractBefore(y + blanks(300), 301));
        n = n + 1;
        if n >= 4; return; end
    end
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
