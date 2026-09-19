function test_EphysAnalysisRunner()
%test_EphysAnalysisRunner  Verification suite for the runner, exports, reports and scripts.
%   Over a small synthetic project run through the pipeline: plan() and its
%   skip reasons; run() writing PNG + SVG figures named by the pattern (and
%   paged grids), an HTML report with embedded PNGs and a multi-page PDF;
%   cancel(); driven synthetic units firing more in the stimulus window; and
%   script equivalence -- the compact and the standalone script, run into
%   separate roots, pass checkcode and write the same figures (pixel for
%   pixel) and the same HTML report (timestamps, image bytes and the config
%   aside).
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
cfg = cfg.addPlot(struct('kind', "raster", 'selection', struct('groupBy', string.empty(1, 0))), Id="raster_stim");
cfg = cfg.addPlot(struct('kind', "evoked", 'source', "LFP", 'window', struct('pre', -0.1, 'post', 0.4), ...
    'baseline', struct('Mode', "subtract", 'Window', [-0.1 0])), Id="lfp_stim");
cfg = cfg.addPlot(struct('kind', "rate", 'ref', struct('line', "Platform", 'scope', "trial"), ...
    'window', struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Platform", 'edge', "offset", 'scope', "trial")), ...
    'selection', struct('filter', "Hit | Miss", 'groupBy', "Depth")), Id="rate_platform");
cfg = cfg.addPlot(struct('kind', "tuning", 'param', "Depth", 'window', struct('pre', 0, 'post', 0.5), ...
    'selection', struct('groupBy', string.empty(1, 0))), Id="tuning_depth");
cfg = cfg.addPlot(struct('kind', "heatmap", 'source', "detected"), Id="heat_det");
cfg = cfg.addPlot(struct('kind', "probemap", 'source', "detected", 'value', "rate"), Id="rate_map");
cfg = cfg.addPlot(struct('kind', "corrmap", 'metric', "peak", 'correlation', "spearman", 'ref', struct('line', "Platform", 'scope', "trial"), ...
    'window', struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Platform", 'edge', "offset", 'scope', "trial"))), Id="corr_platform");
cfg = cfg.addPlot(struct('kind', "evoked", 'source', "SPIKE"), Id="spike_band");
cfg = cfg.addPlot(struct('kind', "psth", 'ref', struct('line', "Nope")), Id="no_line");
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
R = r.run();
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
H = string(fileread(html));
check(contains(H, "data:image/png;base64,") && contains(H, "psth_stim") && contains(H, "rate_platform") ...
    && contains(H, "no SPIKE extract") && contains(H, "Digital lines") && contains(H, "<pre class=""config"">") ...
    && count(H, "<img ") >= 2 * (numel(cfg.Plots) - 2), 'the HTML embeds every figure, the skips, the summaries and the config');
check(count(H, "_psth_stim_p1.png") == 4 && contains(H, "href=""" + names(1) + "/"), 'the HTML links the exported files relatively');
pdfText = fileread(pdf);
nPages = numel(regexp(pdfText, '/Type\s*/Page[^s]', 'match'));
check(nPages >= 1 + 2 + 2 * (numel(cfg.Plots) - 2), sprintf('the PDF has a title page, a page per dataset and every figure (%d pages)', nPages));

fprintf('\n== 3. cancel ==\n');
calls = 0;
r2 = EphysAnalysisRunner(cfg, LogFcn=[]);
    function onProgress(~, ~)
        calls = calls + 1;
        if calls == 3; r2.cancel(); end
    end
r2.ProgressFcn = @onProgress;
R2 = r2.run(Export=false, Report=false);
check(any(R2.Status == "cancelled") && height(R2) == 2 * numel(cfg.enabledPlots()) && isempty(r2.ReportFiles), ...
    sprintf('cancel stops the run; the rest are "cancelled" (%d of %d)', nnz(R2.Status == "cancelled"), height(R2)));

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
cfgA.Export.Formats = "png"; cfgA.Report.Format = "html";
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

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisRunner:Failures', '%d checks failed.', nFail);
end
end


function out = runScript(file) %#ok<INUSD> used inside evalc
%runScript  Run a script in its own workspace and capture what it prints.
out = evalc('run(file)');
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
