function test_EphysAnalysisRunner()
%test_EphysAnalysisRunner  Verification suite for the runner, exports, reports and scripts.
%   Over a small synthetic project run through the pipeline, a config of
%   figures (a raster + PSTH card per unit, an LFP trace per channel, a
%   probe map and a heat map of the dataset, two that every dataset skips
%   -- an SPIKE extract none has, a line none has -- and a disabled one):
%   plan() and its skip reasons, from cheap facts only; run() writing PNG
%   + SVG files, one per observation, named by the pattern, an HTML report
%   with embedded PNGs and a multi-page PDF (title, summary and figure
%   pages in order), both made from the pages as they were drawn so each
%   page is drawn once, leaving no figure open, with percent-encoded
%   links; the run record (schema ephys-analysis-run/2: figures and
%   sessionFigures); Overwrite off; run(Figures=) alone; cancel() between
%   observations, from the progress and from inside a compute (PollFcn:
%   computeFigure's checkpoints); driven synthetic units firing more in
%   the stimulus window; script equivalence -- the compact and the
%   standalone script, run into separate roots, pass checkcode and write
%   the same figures (pixel for pixel), the same HTML report (timestamps,
%   image bytes and the config aside) and the same PDF pages; a failing
%   export closing its page in the runner and the standalone script; unit
%   waveforms (templates without the sorted .bin, spikes cut from a
%   planted one and cached, detections' saved waveforms); one figure per
%   trial group (perGroup); a report per dataset (PerDataset); one
%   observation (run(Observation=): the unit on its own figure, its
%   channel on the LFP one, the dataset's figures drawn for the dataset, a
%   figure across sessions skipped and said so; figureObservations' match
%   of a channel, of every trial group and of the dataset); Report.Order
%   (validated; by unit: the entries' observation keys, reportGroups, the
%   HTML's headings and contents and the PDF's page order and listing,
%   against the order by figure); and a
%   session figure (the card across both datasets): one plan row, a page
%   per matched site in the sessions folder, the "Across sessions" report
%   entry with its caption (and its own <FileName>_sessions report with
%   PerDataset), the run record, the data file with Export.Data.Enabled,
%   Overwrite off, a cancel between observations, and the standalone
%   script (figureSessionCompute) writing the same pixels.
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
isErr = @(m) arrayfun(@(x) startsWith(x.id, 'SYNER') || contains(x.message, 'Parse error'), m);

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
cfg = cfg.addFigure("rasterPsth", Id="card");
cfg.Figures(1).observe.units.maxUnits = 2;
cfg.Figures(1).panels(2).options.bins = struct('BinSec', 0.02, 'SmoothSec', 0.02);
cfg = cfg.addFigure("continuous", Id="lfp");
cfg.Figures(2).observe.channels = [1 2];
cfg.Figures(2).window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.4, 'stop', []);
cfg = cfg.addFigure("probemap", Id="map");
cfg.Figures(3).panels(1).layers(1).source = "detected";
cfg = cfg.addFigure("heatmap", Id="heat");
cfg.Figures(4).panels(1).layers(1).source = "detected";
cfg = cfg.addFigure("continuous", Id="spike_band");
cfg.Figures(5).observe.data = "SPIKE";
cfg.Figures(5).panels(1).layers(1).source = "SPIKE";
cfg = cfg.addFigure("rasterPsth", Id="no_line");
cfg.Figures(6).ref = EphysAnalysisConfig.normalizeSection("EventRef", struct('line', "Nope"));
cfg = cfg.addFigure("waveforms", Id="off");
cfg.Figures(7).enabled = false;
nOn = numel(cfg.enabledFigures());
outMain = fullfile(root, 'outMain');
cfg.Export.Formats = ["png" "svg"];
cfg.Export.Folder = fullfile(outMain, "{Name}");
cfg.Export.Dpi = 50;
cfg.Export.FigureSizeCm = [12 8];
cfg.Report.Format = "both";
cfg.Report.Folder = outMain;
cfg.Report.Dpi = 40;
I = cfg.validate();
check(~any(I.Severity == "error") && nOn == 6, 'the test config (six enabled figures, one disabled) validates');

fprintf('\n== 1. plan ==\n');
r = EphysAnalysisRunner(cfg, LogFcn=[]);
check(isequal(r.Names, names) && numel(r.Outputs) == 2 && all(r.Keys == F.keys), 'the runner finds both datasets by key');
T = r.plan();
check(height(T) == 2 * numel(cfg.Figures) && all(T.Kind == "figure") ...
    && all(T.Source(T.Plot == "card") == "unit") && all(T.Source(T.Plot == "lfp") == "channel") ...
    && all(T.Source(T.Plot == "map") == "dataset"), ...
    'plan: one row per dataset and figure, Kind "figure", Source the observe kind');
check(all(T.Reason(T.Plot == "spike_band") == "no SPIKE extract") && all(T.Reason(T.Plot == "no_line") == "no line Nope") ...
    && all(T.Reason(T.Plot == "off") == "disabled") && all(T.Enabled(~ismember(T.Plot, ["spike_band" "no_line" "off"]))), ...
    'plan: a missing SPIKE extract, a missing line and a disabled figure are the only skips');
TFp = r.plan(Figures=string.empty(1, 0));
TFf = r.plan(Figures="map");
check(height(TFp) == 0 && height(TFf) == 2 && all(TFf.Plot == "map"), 'plan: Figures=string.empty(1, 0) lists none; Figures="map" only that figure');
src = r.source(1);
check(isstruct(src) && src.name == names(1) && r.Sources.isKey(char(F.keys(1))), 'source() loads and caches a dataset');
% plan loads no bulk data: with the LFP file moved away after the source is read, a channel figure still plans
rL = EphysAnalysisRunner(cfg, LogFcn=[]);
srcL = rL.source(1);
rL.Outputs(1).clearCache();
lfpFile = srcL.outputs.signalFile("LFP");
movefile(lfpFile, lfpFile + ".away");
restoreLfp = onCleanup(@() movefile(lfpFile + ".away", lfpFile));
TL = rL.plan(Datasets=1, Figures=["lfp" "card" "map"]);
clear restoreLfp
check(isfile(lfpFile) && height(TL) == 3 && all(TL.Reason == "") && all(TL.Enabled), ...
    sprintf('plan decides a figure from cheap facts: no extract or spikes are loaded (the LFP file was away; reasons: %s)', strjoin("""" + TL.Reason + """", ", ")));
obsCard = cell(1, 2);
nObs = zeros(1, 2);
for k = 1:2
    obsCard{k} = figureObservations(r.source(k), cfg.figureFor("card"));
    nObs(k) = height(obsCard{k});
end
check(all(nObs == 2), sprintf('the card observes maxUnits = 2 units per dataset (%s)', mat2str(nObs)));

fprintf('\n== 2. run: figure files, HTML and PDF reports, the run record ==\n');
nFig = numel(findall(groot, 'Type', 'figure'));
made = 0;   % the figures the run creates
    function countFigure(~, ~)
        made = made + 1;
    end
oldCreate = get(groot, 'DefaultFigureCreateFcn');
set(groot, 'DefaultFigureCreateFcn', @countFigure);
heardF = zeros(0, 1); heardM = strings(0, 1);   % what ProgressFcn hears
    function onRunProgress(f, m)
        heardF(end+1, 1) = f; heardM(end+1, 1) = m;
    end
r.ProgressFcn = @onRunProgress;
R = r.run();
r.ProgressFcn = [];
set(groot, 'DefaultFigureCreateFcn', oldCreate);
check(numel(findall(groot, 'Type', 'figure')) == nFig, 'the run leaves no figure open');
isRep = startsWith(heardM, "Writing the report: ");
check(any(heardM == "Writing the report: section 2/2") && any(heardM == "Writing the report: page 3/3") ...
    && any(startsWith(heardM, "Writing the report: joining")) && all(heardF(isRep) >= 2/3 - 1e-12) ...
    && all(diff(heardF) >= -1e-12) && heardF(end) == 1 && heardM(end) == "Done", ...
    sprintf(['ProgressFcn hears the report''s sections and pages in its own last third of the run (two datasets, ' ...
    'one report), the fraction never going back (%d calls, %d while writing the report)'], numel(heardF), nnz(isRep)));
done = R(R.Status == "done", :);
check(height(R) == 2 * nOn && height(done) == 2 * (nOn - 2) && all(R.Kind == "figure") ...
    && all(R.Status(ismember(R.Plot, ["spike_band" "no_line"])) == "skipped") && ~any(R.Plot == "off") ...
    && all(R.Message(R.Plot == "card") == "2 observation(s)") && all(R.Message(R.Plot == "lfp") == "2 observation(s)"), ...
    sprintf('run: %d done, the 4 unsupported figure runs skipped (%s)', height(done), ...
    strjoin(unique(R.Status(R.Status == "error") + ": " + R.Message(R.Status == "error")), "; ")));
namesOk = true;
for k = 1:2
    d = fullfile(outMain, names(k));
    T1 = obsCard{k};
    want = arrayfun(@(i) string(fullfile(d, names(k) + "_card_" + shortUnitLabels(T1.meta{i}.label) + ".png")), 1:height(T1));
    got = split(R.Files(R.Dataset == names(k) & R.Plot == "card"), "; ").';
    namesOk = namesOk && all(isfile(want)) && all(isfile(replace(want, ".png", ".svg"))) && numel(got) == 2 * numel(want) ...
        && all(ismember(want, got)) && isfile(fullfile(d, names(k) + "_map.png")) && isfile(fullfile(d, names(k) + "_heat.svg")) ...
        && numel(dir(fullfile(d, names(k) + "_lfp_*.png"))) == 2 && isempty(dir(fullfile(d, names(k) + "_spike_band*")));
end
check(namesOk, 'png + svg per observation: <Name>_card_<unit>, <Name>_lfp_<channel>, <Name>_map; none for a skipped figure');
html = fullfile(outMain, "analysis_report.html");
pdf = fullfile(outMain, "analysis_report.pdf");
check(isfile(html) && isfile(pdf) && isequal(sort(r.ReportFiles), sort([string(html) string(pdf)])), 'both reports written');
rr = r.RunRecordFile;
rec = jsondecode(fileread(rr));
check(isfile(rr) && startsWith(rr, string(fullfile(outMain, "analysis_runs")) + filesep) && rec.schema == "ephys-analysis-run/2" ...
    && rec.outcome == "finished" && numel(rec.datasets) == numel(names) && numel(rec.results) == height(R) ...
    && isequal(string(rec.figures(:)).', cfg.enabledFigures()) && isempty(rec.sessionFigures) ...
    && ~isfield(rec, 'plots') && ~isfield(rec, 'sessionPlots') ...
    && numel(rec.reportFiles) == 2 && isfield(rec, 'config') && isfield(rec, 'provenance') && rec.config.version == 2, ...
    'the run record: analysis_runs/<runId>_<name>.json, schema ephys-analysis-run/2 with figures and sessionFigures (no plots), the results, reports, config (version 2) and provenance');
H = string(fileread(html));
E1 = [r.Report.datasets.entries];
E1 = E1([E1.status] == "done");
nDrawn = sum(arrayfun(@(e) numel(e.pages), E1));
check(contains(H, "data:image/png;base64,") && contains(H, "card") && contains(H, "no SPIKE extract") ...
    && contains(H, "Digital lines") && contains(H, "<pre class=""config"">") && count(H, "<img ") >= nDrawn ...
    && contains(H, "<span class=""kind"">figure</span>") && contains(H, "2 dataset(s), " + 2 * nOn + " figure(s)"), ...
    'the HTML embeds every page, the skips, the summaries and the config, and counts figures');
check(contains(H, "_card_" + shortUnitLabels(obsCard{1}.meta{1}.label) + ".png") && contains(H, "href=""" + names(1) + "/"), ...
    'the HTML links the exported files relatively');
check(relativePath("C:\out\rep", "C:\out\Rat#3\a b.png") == "../Rat%233/a%20b.png" ...
    && relativePath("C:\out\rep", "C:\out\rep\x 100%.png") == "x%20100%25.png" ...
    && relativePath("C:\out\rep", "D:\data\Rat#3\a.png") == "file:///D:/data/Rat%233/a.png" ...
    && relativePath("C:\out\rep", "\\srv\share\a b.png") == "file://srv/share/a%20b.png" ...
    && relativePath(pwd, "sub\x#1.png") == "sub/x%231.png", ...
    'report links: each segment percent-encoded ("#", "%", spaces), relative paths from pwd, file:// on another drive or share');
check(~isempty(E1) && all(arrayfun(@(e) numel(e.images) == numel(e.files) / numel(cfg.Export.Formats) ...
    && numel(e.pages) == numel(e.images) && e.images{1}.format == "png" && all(isfile(e.pages)), E1)) && ~isfield(E1, 'R') ...
    && all([E1.kind] == "figure"), ...
    'a "both" report holds the image and the PDF page of every exported page (a page per observation), and no result');
eC = E1([E1.plot] == "card");
png1 = eC(1).files(endsWith(eC(1).files, ".png"));
fid = fopen(png1(1), 'r'); pngBytes = fread(fid, Inf, '*uint8'); fclose(fid);
check(eC(1).images{1}.data == string(matlab.net.base64encode(pngBytes)), ...
    'the HTML embeds the exported PNG of a page (Export png ticked) rather than write the page again at the report''s dpi');
check(numel(eC) == 2 && all(startsWith([eC.caption], "card: 2 observations")), 'each figure''s report entry carries figureCaption''s caption');
check(made == nDrawn + 1 + numel(names), sprintf(['each page is drawn once: %d figures for %d exported pages, ' ...
    'the PDF''s title page and its %d summary pages'], made, nDrawn, numel(names)));
texts = pdfPageTexts(pdf);
inOrder = numel(texts) == 1 + numel(names) + nDrawn && contains(texts(1), "Generated") ...
    && contains(texts(1), sprintf("1. %s (%d figure(s))", names(1), nOn));
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
check(inOrder, sprintf('the PDF: a title page, then per dataset its summary page and its figures'' pages in order (%d pages)', numel(texts)));
ro = cfg; ro.Export.Overwrite = false; ro.Report.Enabled = false;
before = dir(fullfile(outMain, names(1), names(1) + "_card_*.*"));
RO = EphysAnalysisRunner(ro, LogFcn=[]).run(Datasets=1, Figures="card");
after = dir(fullfile(outMain, names(1), names(1) + "_card_*.*"));
check(height(RO) == 1 && RO.Plot == "card" && RO.Status == "done" && numel(split(RO.Files, "; ")) == numel(before) ...
    && isequal([before.datenum], [after.datenum]), ...
    'run(Figures="card") runs that figure alone; Overwrite off keeps (and lists) every observation''s files');
hadPool = license('test', 'Distrib_Computing_Toolbox') && ~isempty(ver('parallel')) && ~isempty(gcp('nocreate'));
rw = EphysAnalysisRunner(ro, LogFcn=[]);
rw.Workers = 2;
RW = rw.run(Datasets=1, Figures="card");
check(RW.Status == "done" && (hadPool || ~license('test', 'Distrib_Computing_Toolbox') || isempty(ver('parallel')) || isempty(gcp('nocreate'))), ...
    'Workers = 2 on a run of fewer than MinPoolPages pages starts no pool: the pages are drawn here');
% a vector PDF page is the figure's size, also for a figure whose paper is not set up (exportFigure prints on its size)
fpdf = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [1 1 10 6]);
plot(axes(fpdf), 1:3);
paper = get(fpdf, {'PaperUnits', 'PaperSize', 'PaperPosition', 'PaperPositionMode'});
pdfFile = exportFigure(fpdf, fullfile(root, "paper_check"), Format="pdf");
paperAfter = get(fpdf, {'PaperUnits', 'PaperSize', 'PaperPosition', 'PaperPositionMode'});
close(fpdf);
sz = pdfPageSizeCm(pdfFile);
check(all(abs(sz - [10 6]) < 0.05) && isequal(paper, paperAfter), ...
    sprintf('exportFigure PDF: one page the figure''s size (%.2f x %.2f cm, 10 x 6 wanted), the figure''s paper put back', sz));

fprintf('\n== 3. cancel ==\n');
calls = 0;
r2 = EphysAnalysisRunner(cfg, LogFcn=[]);
    function onProgress(~, ~)
        calls = calls + 1;
        if calls == 3; r2.cancel(); end
    end
r2.ProgressFcn = @onProgress;
R2 = r2.run(Export=false, Report=false);
check(any(R2.Status == "canceled") && height(R2) == 2 * nOn && isempty(r2.ReportFiles) && all(R2.Kind == "figure"), ...
    sprintf('cancel stops the run; the rest are "canceled" (%d of %d)', nnz(R2.Status == "canceled"), height(R2)));
outCx = fullfile(root, 'outCancel');
cfgC = cfg; cfgC.Export.Folder = fullfile(outCx, "{Name}"); cfgC.Report.Enabled = false; cfgC.Export.Formats = "png";
rC = EphysAnalysisRunner(cfgC, LogFcn=[]);
    function onFigProgress(~, msg)
        if contains(msg, ": card (2/"); rC.cancel(); end
    end
rC.ProgressFcn = @onFigProgress;
nFig = numel(findall(groot, 'Type', 'figure'));
RC = rC.run();
check(height(RC) == 2 * nOn && RC.Status(RC.Dataset == names(1) & RC.Plot == "card") == "canceled" ...
    && all(RC.Status(RC.Dataset == names(2)) == "canceled") && all(RC.Status(RC.Dataset == names(1) & RC.Plot ~= "card") == "canceled") ...
    && isscalar(dir(fullfile(outCx, names(1), names(1) + "_card_*.png"))) && numel(findall(groot, 'Type', 'figure')) == nFig, ...
    'cancel() between a figure''s observations: the first page is written, the figure and the rest are "canceled"');
polls = 0;
cancelAt = 0;
    function onPoll()
        polls = polls + 1;
        if polls == cancelAt; r.cancel(); end
    end
specC = cfg.figureFor("card");
r.PollFcn = @onPoll;
r.clearCancel();
F0 = r.computeFigure(src, specC, Observation=obsCard{1}(1, :));
nPolls = polls;
check(nPolls >= 2 && F0.kind == "figure", sprintf('with PollFcn set, computeFigure reaches %d checkpoints and still returns the figure', nPolls));
polls = 0; cancelAt = 2;
r.clearCancel();
cid = "";
try
    r.computeFigure(src, specC, Observation=obsCard{1}(1, :));
catch ME
    cid = string(ME.identifier);
end
check(cid == "EphysAnalysisRunner:Canceled" && polls == 2, 'cancel() at the second checkpoint stops computeFigure there (Canceled)');
r.PollFcn = [];
polls = 0;
F1 = r.computeFigure(src, specC, Observation=obsCard{1}(1, :));
check(polls == 0 && isequaln(F1.panels(2).layers(1).R.rate, F0.panels(2).layers(1).R.rate), ...
    'with PollFcn empty (a run) there are no checkpoints: a cancel() already asked for does not stop computeFigure');
r.clearCancel();
rP = EphysAnalysisRunner(cfgC, LogFcn=[]);
rP.PollFcn = @() rP.cancel();   % the first checkpoint inside computeFigure cancels
RP = rP.run(Export=false, Report=false);
check(height(RP) == 2 * nOn && all(RP.Status == "canceled"), ...
    sprintf('a Canceled thrown inside a figure''s compute is rethrown: every row "canceled", none "error" (%s)', strjoin(unique(RP.Status), ", ")));

fprintf('\n== 4. driven units fire more in the stimulus window ==\n');
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
check(~contains(txtS, "EphysAnalysisRunner") && ~contains(txtS, "EphysAnalysisConfig.load(") && contains(txtS, "fspec1 = struct();") ...
    && ~contains(txtS, "fspec7") && contains(txtS, "fres = figureCompute(src, fspec, Observation=obsT(i, :));") ...
    && contains(txtS, "renderFigure(fres, fspec, fig)") && contains(txtS, "Caption=figureCaption(fspec, obsT, Dataset=name, Auroc=acalls)") ...
    && contains(txtS, "ac = figureAurocCalls(fres);") ...
    && contains(txtS, "fspec1.ref.line = ""Stim"";") && contains(txtS, '"schema": "ephys-analysis-config"') ...
    && ~contains(txtS, ["plotFor" "renderPlot" "computePlot"]) && ~any(startsWith(splitlines(txtS), "spec1 = struct();")), ...
    'the standalone script writes each enabled figure''s spec and computes it with figureCompute, never the runner');
mC = checkcode(compactFile, '-id'); mS = checkcode(standaloneFile, '-id');
check((isempty(mC) || ~any(isErr(mC))) && (isempty(mS) || ~any(isErr(mS))), 'checkcode finds no syntax error in either script');
if ~isempty(mS) && any(isErr(mS)); disp(mS(isErr(mS))); end
outC = runScript(compactFile); %#ok<NASGU>
outS = runScript(standaloneFile);
check(~contains(outS, "FAILED") && contains(outS, "card done"), 'the standalone script reported no failure');
if contains(outS, "FAILED"); disp(outS); end
[samePix, na] = samePngs(outA, outB);
check(samePix && numel(na) == sum(contains(na, "_card_")) + sum(contains(na, "_lfp_")) + 4 && any(contains(na, "_card_")), ...
    sprintf('the same %d figure files from both scripts, pixel-identical (a few antialiased label pixels tolerated)', numel(na)));
ha = normalizeHtml(fileread(fullfile(outA, 'analysis_report.html')));
hb = normalizeHtml(fileread(fullfile(outB, 'analysis_report.html')));
check(strlength(ha) > 1000 && ha == hb, 'the HTML reports are equal once timestamps, image bytes and the config are set aside');
if ha ~= hb; showHtmlDiff(ha, hb); end
ta = pdfPageTexts(fullfile(outA, 'analysis_report.pdf'));
tb = pdfPageTexts(fullfile(outB, 'analysis_report.pdf'));
check(numel(ta) == numel(texts) && isequal(erase(ta(2:end), " "), erase(tb(2:end), " ")) ...   % spaces: where the text extraction puts them varies
    && contains(txtS, "pages(end+1) = reportPdfPage(fig, report, Files=written);") ...
    && contains(txtS, "Files=files, Images=images, Pages=pages, Observations=obsT, ..."), ...
    sprintf('both scripts write the same %d PDF pages (the title page''s time aside), made from the drawn pages', numel(ta)));

fprintf('\n== 6. a failing export closes its page ==\n');
bad = cfg;
bad.Figures = bad.Figures(bad.figureIndex("map"));
bad.Source.Selection = "list"; bad.Source.Datasets = F.keys(1);
bad.Export.Folder = fullfile(root, "bad|folder", "{Name}");   % cannot be created
bad.Report.Enabled = false;
nFig = numel(findall(groot, 'Type', 'figure'));
Tb = EphysAnalysisRunner(bad, LogFcn=[]).run();
check(height(Tb) == 1 && Tb.Status == "error" && numel(findall(groot, 'Type', 'figure')) == nFig, ...
    'runner: the page whose export fails is closed; the figure is an error row');
badFile = fullfile(root, 'scripts', 'run_bad.m');
EphysAnalysisScript.standalone(bad, File=badFile);
outBad = runScript(badFile);
check(contains(outBad, "FAILED") && numel(findall(groot, 'Type', 'figure')) == nFig, ...
    'standalone script: the page whose export fails is closed too');

fprintf('\n== 7. unit waveforms ==\n');
[~, metaW] = selectUnits(src, struct('classes', ["su" "mua"]));
lastwarn('');
W = unitWaveforms(src, metaW, Source="units", MaxSpikes=5);
[~, wid] = lastwarn();
U = src.outputs.load("sorting");
row = find(double(U.unitId) == metaW.unitId(1), 1);
check(numel(W.mean) == height(metaW) && all(W.from == "template") && isequal(W.mean{1}, double(U.templateWaveform{row}(:))) ...
    && all(cellfun(@isempty, W.spikes)) && W.note ~= "" && string(wid) == "unitWaveforms:Templates", ...
    'without the sorted .bin each unit''s template is its mean, with no spikes, and a warning says why');
sortDir = string(src.outputs.SortingDir);
P = fileread(fullfile(sortDir, 'params.py'));
nCh = str2double(regexp(P, 'n_channels_dat = (\d+)', 'tokens', 'once'));
fsS = str2double(regexp(P, 'sample_rate = ([\d.eE+]+)', 'tokens', 'once'));
nS = round(5 * fsS);                                      % 5 s: later spikes leave the file
datFile = fullfile(sortDir, 'temp_wh.dat');
fid = fopen(datFile, 'w');
fwrite(fid, repmat(int16(10 * (1:nCh).'), 1, nS), 'int16');   % row r holds 10 r: read back (/200) as r / 20
fclose(fid);
src.outputs.clearCache();
W2 = unitWaveforms(src, metaW, Source="units", MaxSpikes=5);
isS = W2.from == "spikes";
vals = true;
for u = find(isS).'
    row = find(double(U.unitId) == metaW.unitId(u), 1);
    vals = vals && size(W2.spikes{u}, 2) <= 5 && all(abs(W2.spikes{u} - U.ksChannel(row) / 20) < 1e-9, 'all') ...
        && max(abs(W2.mean{u} - U.ksChannel(row) / 20)) < 1e-9 && isequal(W2.timeMs{u}, W.timeMs{u});
end
check(any(isS) && vals && any(cellfun(@(w) size(w, 2), W2.spikes(isS)) == 5) && W2.units(find(isS, 1)) == "whitened" && W2.note == "", ...
    'with the sorted .bin the spikes are cut on each unit''s peak channel, at most maxSpikes of them, and averaged');
k1 = find(isS, 1);
check(max(abs(W2.sd{k1} - std(W2.spikes{k1}, 0, 2))) < 1e-12 && W2.nMean(k1) == size(W2.spikes{k1}, 2), ...
    'W.sd and W.nMean: the SD of the spikes the mean is over, and how many');
lastwarn('');
Wt = unitWaveforms(src, metaW, Source="units", MaxSpikes=5, Template=true);
[~, widT] = lastwarn();
check(all(Wt.from == "template") && isequal(Wt.mean{1}, W.mean{1}) && all(cellfun(@isempty, Wt.spikes)) ...
    && all(Wt.nMean == 0) && Wt.note == "" && string(widT) == "", ...
    'Template=true: the templates even with the sorted .bin there, no spikes read, no warning');
delete(datFile);
W3 = unitWaveforms(src, metaW, Source="units", MaxSpikes=5);
check(all(W3.total(W3.from == "spikes") >= cellfun(@(s) size(s, 2), W3.spikes(W3.from == "spikes"))) ...
    && all(W3.total(W3.from == "spikes") > 0), 'W.total is the unit''s spike count in the recording, not the number drawn');
check(isequal(W3.from, W2.from) && isequal(W3.spikes, W2.spikes), 'the spikes read are kept (CacheData): a redraw does not read the .bin again');
[~, metaD] = selectUnits(src, struct('source', "detected", 'classes', string.empty(1, 0)));
Wd = unitWaveforms(src, metaD, Source="detected", MaxSpikes=5);
Dd = src.outputs.load("spikes", "detected").detected;          % the synthetic project keeps detection waveforms
u1 = find(Wd.from == "spikes", 1);
wf1 = double(Dd.wf{double(Dd.channels) == metaD.unitId(u1)}).';
check(~isempty(u1) && max(abs(Wd.mean{u1} - mean(wf1, 2))) < 1e-9 && size(Wd.spikes{u1}, 2) == min(5, size(wf1, 2)) ...
    && Wd.units(u1) == "uV" && isequal(Wd.timeMs{u1}, double(Dd.info.waveformTimeMs(:))) && Wd.note == "", ...
    'detections: the spikes file''s waveforms, maxSpikes of them drawn, the mean over all of them');
check(max(abs(Wd.sd{u1} - std(wf1, 0, 2))) < 1e-9 && Wd.nMean(u1) == size(wf1, 2), 'detections: W.sd over all of them, as the mean is');
WdT = unitWaveforms(src, metaD, Source="detected", Template=true);
check(all(WdT.from == "none") && contains(WdT.note, "no template"), 'detections have no template: none, and W.note says so');
src.outputs.clearCache();

fprintf('\n== 8. one figure per trial group, a report per dataset ==\n');
outPg = fullfile(root, 'outFigGroup');
cfgPg = cfg;
cfgPg.Figures(1).observe.perGroup = true;
cfgPg.Export.Folder = fullfile(outPg, "{Name}");
cfgPg.Export.Formats = "png";
cfgPg.Report.Enabled = false;
Tpg = figureObservations(EphysAnalysisRunner(cfgPg, LogFcn=[]).source(1), cfgPg.figureFor("card"));
nGpg = numel(unique(Tpg.group));
RPg = EphysAnalysisRunner(cfgPg, LogFcn=[]).run(Datasets=1, Figures="card");
filesPg = split(RPg.Files, "; ");
wantPg = strings(height(Tpg), 1);
for i = 1:height(Tpg)
    wantPg(i) = string(fullfile(outPg, names(1), names(1) + "_card_" + shortUnitLabels(Tpg.meta{i}.label) + "_" ...
        + regexprep(Tpg.groupLabel(i), '[^\w\-\.]', '_') + ".png"));
end
check(height(RPg) == 1 && RPg.Status == "done" && nGpg >= 2 && height(Tpg) == nObs(1) * nGpg && numel(filesPg) == height(Tpg) ...
    && isequal(sort(filesPg), sort(wantPg)) && all(isfile(wantPg)) && RPg.Message == compose("%d observation(s)", height(Tpg)), ...
    sprintf('perGroup: one file per unit and trial group (%d x %d), <Name>_card_<unit>_<group>.png', nObs(1), nGpg));
outPd = fullfile(root, 'outPerDataset');
cfgPd = cfg;
cfgPd.Figures = cfgPd.Figures(cfgPd.figureIndex("map"));
cfgPd.Export.Folder = fullfile(outPd, "{Name}");
cfgPd.Export.Formats = "png";
cfgPd.Report.PerDataset = true;
cfgPd.Report.Format = "html";
cfgPd.Report.Folder = fullfile(outPd, "{Name}");
rPd = EphysAnalysisRunner(cfgPd, LogFcn=[]);
RPd = rPd.run();
wantPd = arrayfun(@(n) string(fullfile(outPd, n, "analysis_report_" + regexprep(n, '[^\w\-\.]', '_') + ".html")), names);
check(height(RPd) == 2 && all(RPd.Status == "done") && isequal(sort(rPd.ReportFiles), sort(wantPd)) && all(isfile(wantPd)), ...
    'Report.PerDataset: one report per dataset, <Folder>/<FileName>_<Name>.html');

fprintf('\n== 8b. one observation: run(Observation=), figureObservations(Observation=) ==\n');
u = obsCard{1}(1, :);   % the first unit of dataset 1
obU = struct('kind', "unit", 'data', "units", 'unitId', u.unitId, 'channel', u.channel, 'label', u.label);
cfgOb = cfg;
cfgOb.Report.Format = "html";
cfgOb.Report.Folder = fullfile(root, 'outObs');
sesOb = cfgOb.Figures(cfgOb.figureIndex("card"));
sesOb.id = "card_sessions";
sesOb.sessions.enabled = true;   % a figure across sessions: left out of a one-observation run
cfgOb.Figures(end+1) = sesOb;
rOb = EphysAnalysisRunner(cfgOb, LogFcn=[]);
ROb = rOb.run(Datasets=1, Export=false, Report=true, Observation=obU);
rowOf = @(id) ROb(ROb.Plot == id, :);
lfpR = rowOf("lfp");
if ismember(u.channel, cfg.Figures(2).observe.channels)
    lfpOk = lfpR.Status == "done" && lfpR.Message == "1 observation(s)";
else
    lfpOk = lfpR.Status == "skipped" && startsWith(lfpR.Message, "no LFP channel on channel " + u.channel);
end
html = fileread(rOb.ReportFiles(1));
sesR = rowOf("card_sessions");
dsR = ROb(ROb.Dataset == names(1), :);
check(height(ROb) == nOn + 1 && height(dsR) == nOn && rowOf("card").Status == "done" && rowOf("card").Message == "1 observation(s)" ...
    && lfpOk && rowOf("map").Status == "done" && rowOf("map").Message == "1 observation(s)" ...
    && rowOf("heat").Status == "done" && rowOf("heat").Message == "1 observation(s)" ...
    && isscalar(sesR.Status) && sesR.Status == "skipped" && sesR.Dataset == "sessions: all" ...
    && sesR.Message == "it is drawn across the sessions, not for one dataset's observation" ...
    && isscalar(rOb.ReportFiles) && endsWith(rOb.ReportFiles, ".html") && startsWith(rOb.ReportFiles, cfgOb.Report.Folder) ...
    && contains(html, "Across sessions") && contains(html, "it is drawn across the sessions, not for one dataset&#39;s observation") ...
    && startsWith(rOb.RunRecordFile, cfgOb.Report.Folder), ...
    sprintf(['run(Observation=<a unit>): the unit alone on its figure, its channel on the LFP figure (%s), the figures of ' ...
    'the dataset drawn for the dataset, the figure across sessions skipped and said so under "Across sessions"'], lfpR.Message));
[Tm, whyM] = figureObservations(r.source(1), cfg.figureFor("map"), Observation=obU);
obD = struct('kind', "dataset", 'data', "units", 'unitId', NaN, 'channel', NaN, 'label', names(1));
[Td, whyD] = figureObservations(r.source(1), cfg.figureFor("card"), Observation=obD);
[Tdm, whyDm] = figureObservations(r.source(1), cfg.figureFor("map"), Observation=obD);
check(height(Tm) == 1 && Tm.kind == "dataset" && whyM == "" && height(Td) == 0 && whyD ~= "" ...
    && height(Tdm) == 1 && whyDm == "", ...
    'a figure of the dataset keeps the dataset for any observation picked; the dataset picked keeps no unit (and says why)');
Tg = figureObservations(r.source(1), cfgPg.figureFor("card"), Observation=obU);
check(height(Tg) == nGpg && all(Tg.unitId == u.unitId), 'a figure per trial group keeps every group of the unit matched');
Tl = figureObservations(r.source(1), cfg.figureFor("lfp"));
obC = struct('kind', "channel", 'data', "LFP", 'unitId', NaN, 'channel', Tl.channel(1), 'label', Tl.label(1));
[Tu, why] = figureObservations(r.source(1), cfg.figureFor("card"), Observation=obC);
[Tc, whyC] = figureObservations(r.source(1), cfg.figureFor("lfp"), Observation=obC);
check(all(Tu.channel == obC.channel) && (height(Tu) > 0 || startsWith(why, "no unit on channel " + obC.channel)) ...
    && height(Tc) == 1 && Tc.channel == obC.channel && whyC == "", ...
    'a channel picked: the units on that channel (or why none), the channel itself on a channel figure');
specSt = cfg.figureFor("card");
specSt.observe.starred = true;   % Starred only, and no star in the fixture
Tst = figureObservations(r.source(1), specSt);
[Tso, whySo] = figureObservations(r.source(1), specSt, Observation=obU);
check(height(Tst) == 0 && height(Tso) == 1 && Tso.unitId == u.unitId && ~Tso.starred && whySo == "", ...
    'Starred only keeps no unstarred unit, but the one observation picked (Observation=) is drawn, starred or not');

fprintf('\n== 8c. report order: by figure, by unit ==\n');
cfgOr = cfg;
cfgOr.Report.Format = "both";
cfgOr.Report.IncludeParameters = true;
bad = cfgOr; bad.Report.Order = "shank";
IOr = bad.validate();
check(cfgOr.Report.Order == "figure" && any(IOr.Section == "Report" & IOr.Field == "Order" & IOr.Severity == "error"), ...
    'Report.Order is "figure" by default; another value is a validation error');
orderRun = @(order, folder) runOrder(cfgOr, order, fullfile(root, folder));
[rF, HF] = orderRun("figure", 'outOrderFigure');
[rU, HU] = orderRun("unit", 'outOrderUnit');
DU = rU.Report.datasets(1);
[G, rest] = reportGroups(DU);
eCard = DU.entries([DU.entries.plot] == "card");
eLfp = DU.entries([DU.entries.plot] == "lfp");
check(numel(eCard.obsKeys) == numel(eCard.images) && all(startsWith(eCard.obsKeys, "unit|units|")) ...
    && all(startsWith(eLfp.obsKeys, "channel|LFP|")) && isequal(DU.entries([DU.entries.plot] == "map").obsKeys, "dataset") ...
    && isequal(eCard.obsLabels, obsCard{1}.label.'), ...
    'each report entry keeps its pages'' observations: unit|<data>|<id>, channel|<data>|<channel>, dataset; the picker''s labels');
nGroups = numel(unique([DU.entries.obsKeys]));
check(numel(G) == nGroups && isequal([G(1:2).label], obsCard{1}.label.') && all(arrayfun(@(g) g.entry(1), G(1:2)) == find([DU.entries.plot] == "card")) ...
    && any([G.key] == "dataset") && isequal(sort([DU.entries(rest).plot]), sort(["no_line" "spike_band"])), ...
    sprintf('by unit: a group per observation (%d), the card''s units first in its order, the dataset one group; the skipped figures after them', nGroups));
iFirst = @(H, s) strfind(H, s);
headPos = arrayfun(@(g) min([iFirst(HU, "<h3 class=""obs"">" + htmlEscape(g.label) + "</h3>") Inf]), G);
cardPos = cell2mat(arrayfun(@(k) iFirst(HU, "<article id=""ds1-o" + k + "-" + G(k).entry(1) + """>"), 1:numel(G), 'UniformOutput', false));
check(~contains(HF, "class=""obs""") && count(HU, "<h3 class=""obs"">") == numel(G) ...
    && all(isfinite(headPos)) && issorted(headPos) && numel(cardPos) == numel(G) && all(cardPos > headPos) ...
    && count(HU, "<img ") == count(HF, "<img ") && count(HU, "<summary>Parameters</summary>") == count(HF, "<summary>Parameters</summary>") ...
    && contains(HU, "href=""#ds1-o1"">" + htmlEscape(G(1).label) + "</a>"), ...
    'the HTML by figure has no observation headings; by unit a heading per observation in order, each figure under it, the same pages, the parameters once per figure, the contents listing the observations');
want = strings(0, 1);
for g = 1:numel(G)
    for q = 1:numel(G(g).entry)
        e = DU.entries(G(g).entry(q));
        want = [want; reshape(e.pages(G(g).pages{q}), [], 1)]; %#ok<AGROW>
    end
end
TU = pdfPageTexts(rU.ReportFiles(endsWith(rU.ReportFiles, ".pdf")));
TF = pdfPageTexts(rF.ReportFiles(endsWith(rF.ReportFiles, ".pdf")));
sameOrder = numel(TU) == 2 + numel(want) && numel(TF) == numel(TU);
for p = 1:numel(want)
    sameOrder = sameOrder && TU(2 + p) == pdfPageTexts(want(p));
end
check(sameOrder && contains(TU(2), "Pages by observation:") && contains(TU(2), "page 3") && ~contains(TF(2), "Pages by observation"), ...
    sprintf('the PDF by unit: every observation''s pages together in group order, the summary page listing them (%d pages)', numel(TU)));

fprintf('\n== 9. session figures: plan, run, export, report, data file, run record, cancel, standalone script ==\n');
outG = fullfile(root, 'outSesFig');
cfgG = cfg;
cfgG.Name = "session figures test";
cfgG.Figures = cfgG.Figures(cfgG.figureIndex("card"));
cfgG.Figures(1).sessions.enabled = true;   % "card" across the two datasets
cfgG.Export.Folder = fullfile(outG, "{Name}");
cfgG.Export.SessionsFolder = fullfile(outG, "sessions");
cfgG.Export.Formats = "png";
cfgG.Export.Data.Enabled = true;
cfgG.Export.Data.Folder = fullfile(outG, "data");
cfgG.Report.Folder = outG;
cfgG.Report.Format = "html";
IG = cfgG.validate();
check(~any(IG.Severity == "error") && isempty(cfgG.enabledFigures()) && isequal(cfgG.enabledSessionFigures(), "card"), ...
    'a config of one session figure validates; it is not a per-dataset figure');
rG = EphysAnalysisRunner(cfgG, LogFcn=[]);
TGo = rG.sessionFigureObservations("card");
nG = height(TGo);
PG = rG.plan();
check(height(PG) == 1 && PG.Dataset == "sessions: all" && PG.Kind == "figure" && PG.Source == "unit" && PG.Enabled, ...
    'plan: the session figure is one row "sessions: all" (Kind "figure"), not a row per dataset');
nFig = numel(findall(groot, 'Type', 'figure'));
RG = rG.run();
check(numel(findall(groot, 'Type', 'figure')) == nFig, 'the run with a session figure leaves no figure open');
wantG = arrayfun(@(i) string(fullfile(outG, "sessions", "all_card_site_ch" + TGo.channel(i) + ".png")), 1:nG);
dfile = string(fullfile(outG, "data", "all_card.mat"));
gFiles = split(RG.Files, "; ").';
check(nG >= 1 && height(RG) == 1 && RG.Dataset == "sessions: all" && RG.Kind == "figure" && RG.Status == "done" ...
    && startsWith(RG.Message, compose("%d observation(s)", nG)) && isequal(sort(gFiles(gFiles ~= dfile)), sort(wantG)) && all(isfile(wantG)), ...
    sprintf('run: the session figure is drawn once per matched site into the sessions folder, <facet>_card_site_ch<N>.png (%d pages)', nG));
Ld = load(dfile);
check(isfile(dfile) && any(gFiles == dfile) && Ld.schema == "ephys-analysis-session-figure/1" && Ld.figure == "card" ...
    && height(Ld.sessions) == 2 && height(Ld.observations) == nG && size(Ld.perSession, 1) == nG && size(Ld.perSession, 2) == 2 ...
    && ~isempty(Ld.results), ...
    'Export.Data.Enabled: <Data.Folder>/all_card.mat holds the sessions, the observations, each one''s merged figure and every dataset''s own');
DG = rG.Report.datasets(end);
eG = DG.entries([DG.entries.plot] == "card");
check(DG.kind == "section" && DG.name == "Across sessions" && isscalar(eG) && eG.kind == "figure" && numel(eG.images) == nG ...
    && startsWith(eG.caption, "card: ") && contains(eG.caption, "across 2 sessions"), ...
    sprintf('the report: an entry in the "Across sessions" section, a page per observation, captioned "%s"', eG.caption));
recG = jsondecode(fileread(rG.RunRecordFile));
check(recG.schema == "ephys-analysis-run/2" && isequal(string(recG.sessionFigures), "card") && isempty(recG.figures), ...
    'the run record lists the session figure apart from the figures');
roG = cfgG; roG.Export.Overwrite = false; roG.Report.Enabled = false; roG.Export.Data.Enabled = false;
beforeG = dir(fullfile(outG, "sessions", "all_card_*.png"));
ROG = EphysAnalysisRunner(roG, LogFcn=[]).run(SessionFigures="card", Figures=string.empty(1, 0));
afterG = dir(fullfile(outG, "sessions", "all_card_*.png"));
check(height(ROG) == 1 && ROG.Status == "done" && numel(split(ROG.Files, "; ")) == nG && isequal([beforeG.datenum], [afterG.datenum]), ...
    'run(SessionFigures="card") alone; Overwrite off keeps (and lists) every observation''s files');
outGP = fullfile(root, 'outSesFigPerDataset');
cfgGP = cfgG; cfgGP.Export.Data.Enabled = false; cfgGP.Export.SessionsFolder = fullfile(outGP, "sessions");
cfgGP.Report.PerDataset = true; cfgGP.Report.Folder = outGP;
rGP = EphysAnalysisRunner(cfgGP, LogFcn=[]);
rGP.run();
sesRep = string(fullfile(outGP, "analysis_report_sessions.html"));
check(any(rGP.ReportFiles == sesRep) && isfile(sesRep) && contains(fileread(sesRep), "Across sessions"), ...
    'with Report.PerDataset the session figures get a report of their own, <FileName>_sessions');
outGC = fullfile(root, 'outSesFigCancel');
cfgGC = roG; cfgGC.Export.Overwrite = true; cfgGC.Export.SessionsFolder = fullfile(outGC, "sessions");
rGC = EphysAnalysisRunner(cfgGC, LogFcn=[]);
    function onSesProgress(~, msg)
        if contains(msg, "sessions: card (2/"); rGC.cancel(); end
    end
check(nG >= 2, sprintf('the session figure has several observations to cancel between (%d sites)', nG));
if nG >= 2
    rGC.ProgressFcn = @onSesProgress;
    RGC = rGC.run();
    check(height(RGC) == 1 && RGC.Status == "canceled" && RGC.Dataset == "sessions: all" ...
        && isscalar(dir(fullfile(outGC, "sessions", "all_card_*.png"))), ...
        'cancel() between a session figure''s observations: the first page is written, the figure "canceled"');
end
% the standalone script: figureSessionCompute, runner-free, the same pages
outSG = fullfile(root, 'outSesFigScript');
cfgSG = cfgG; cfgSG.Export.Folder = fullfile(outSG, "{Name}"); cfgSG.Export.SessionsFolder = fullfile(outSG, "sessions");
cfgSG.Export.Data.Folder = fullfile(outSG, "data");
cfgSG.Report.Folder = outSG;
sgFile = fullfile(root, 'scripts', 'run_session_figures.m');
txtSG = EphysAnalysisScript.standalone(cfgSG, File=sgFile);
check(~contains(txtSG, "EphysAnalysisRunner") && contains(txtSG, "sfspec1 = struct();") && contains(txtSG, "figureSessionObservations(sources, fspec)") ...
    && contains(txtSG, "figureSessionCompute(sources, sessions, fspec, Observation=obsT(i, :))") ...
    && contains(txtSG, "Caption=figureCaption(fspec, obsT(E(q).rows, :), Sessions=E(q).F.sessions)") ...
    && contains(txtSG, "%% Session figures") && contains(txtSG, "writeAnalysisData(dfile, S,"), ...
    'the standalone script writes the session figure''s spec, merges it with figureSessionCompute and writes its data file, never the runner');
mSG = checkcode(sgFile, '-id');
check(isempty(mSG) || ~any(isErr(mSG)), 'checkcode finds no syntax error in the session figures script');
outSGt = runScript(sgFile);
check(~contains(outSGt, "FAILED") && contains(outSGt, "card done") && isfile(fullfile(outSG, "data", "all_card.mat")), ...
    'the session figures script ran without a failure and wrote the data file');
if contains(outSGt, "FAILED"); disp(outSGt); end
[samePixG, nga] = samePngs(fullfile(outG, 'sessions'), fullfile(outSG, 'sessions'));
check(samePixG, sprintf('the script''s %d session figure PNGs are pixel-identical to the runner''s (the same tolerance)', numel(nga)));

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisRunner:Failures', '%d checks failed.', nFail);
end
end


function [r, H] = runOrder(cfg, order, folder)
%runOrder  Dataset 1's report (no figure files) in Report.Order ORDER, into FOLDER: the runner and the HTML text.
cfg.Report.Order = order;
cfg.Report.Folder = folder;
r = EphysAnalysisRunner(cfg, LogFcn=[]);
r.run(Datasets=1, Export=false, Report=true);
H = string(fileread(r.ReportFiles(endsWith(r.ReportFiles, ".html"))));
end


function [same, na] = samePngs(dirA, dirB)
%samePngs  Whether two folders hold the same PNGs (by relative path), pixel for pixel.
%   Seen intermittently: a handful of antialiased pixels of one text label
%   (the x label's box) in the first figure page of a run; tolerated, any
%   wider difference is a failure. NA: the relative names in DIRA.
pa = dir(fullfile(dirA, '**', '*.png')); pb = dir(fullfile(dirB, '**', '*.png'));
na = sort(string(erase(fullfile({pa.folder}, {pa.name}), string(dirA))));
nb = sort(string(erase(fullfile({pb.folder}, {pb.name}), string(dirB))));
same = ~isempty(na) && isequal(na, nb);
if ~isequal(na, nb); fprintf(2, '    A: %s\n    B: %s\n', strjoin(na, ", "), strjoin(nb, ", ")); end
for k = 1:min(numel(na), numel(nb))
    ia = imread(fullfile(dirA, na(k))); ib = imread(fullfile(dirB, nb(k)));
    ok = isequal(ia, ib);
    if ~ok
        if isequal(size(ia), size(ib))
            nDiff = nnz(any(ia ~= ib, 3));
            [rr, cc] = find(any(ia ~= ib, 3));
            fprintf(2, '    %s differs: %d pixels, rows %d-%d, cols %d-%d of %s\n', na(k), nDiff, ...
                min(rr), max(rr), min(cc), max(cc), mat2str(size(ia)));
            ok = nDiff <= 16 && max(rr) - min(rr) < 20 && max(cc) - min(cc) < 60;
        else
            fprintf(2, '    %s differs in size: %s vs %s\n', na(k), mat2str(size(ia)), mat2str(size(ib)));
        end
    end
    same = same && ok;
end
end


function out = runScript(file) %#ok<INUSD> used inside evalc
%runScript  Run a script in its own workspace and capture what it prints.
out = evalc('run(file)');
end


function sz = pdfPageSizeCm(file)
%pdfPageSizeCm  The first page's width and height, cm (PDFBox).
doc = org.apache.pdfbox.pdmodel.PDDocument.load(java.io.File(char(file)));
closer = onCleanup(@() doc.close());
box = doc.getPage(0).getMediaBox();
sz = [box.getWidth() box.getHeight()] / 72 * 2.54;
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


function rmdirQuiet(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end
