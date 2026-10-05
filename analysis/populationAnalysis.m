function [P, S, files] = populationAnalysis(source, opts)
%populationAnalysis  Every unit of every dataset in one table: PSTH, response tests, auROC, tuning, metrics; summed up by group.
%   [P, S] = populationAnalysis(CFG) runs over the datasets of the analysis
%   config CFG (an EphysAnalysisConfig, or an EphysAnalysisRunner that has
%   found its datasets). Ref, Window and Selection default to the config's
%   Defaults. Per dataset it calls:
%     [st, meta] = selectUnits(src, Units, Ref=, Selection=)
%     E  = epochTable(src, Ref, Window=, Selection=, Baseline=)
%     R  = spikePSTH(st, E, Window=[pre post], BinSec=, SmoothSec=, Measure=,
%              Baseline=, BaselineMode=)               each unit's PSTH
%     Er = responseEpochs(src, Ref, Selection, Baseline=, Window=Response,
%              Param=)
%     T  = responseStats(st, Er, Baseline=, Window=Response, Param=,
%              Correction="none", Tests=)
%     A  = aurocCurves(st, Ea, Window=[pre post], Baseline=, BinSec=,
%              Measure=, <Auroc's settings>, Call=false, Groups=)
%              each unit's auROC per group (with Tests; Ea = E, or E's
%              epochs grouped by AurocGroupBy)
%   Then it adjusts the p values once (pAdjust with Correction) over the
%   family: every unit tested (Family "all", the default) or each
%   dataset's units on their own (Family "dataset"). The auROC calls are
%   made over the family too, in one aurocCall over every unit x group
%   curve of the family: the 95% CI cutoff (Auroc cutoff "ci") is taken
%   over all of them, as Macedo-Lima, Hamlette & Caras (2024) pooled every
%   unit's hit and false-alarm curves, rather than over one dataset's few
%   units; a "test" cutoff's p values (per curve) are adjusted with
%   Correction over the family and called at Alpha. It returns
%   S = populationSummary(P, GroupBy=, DepthBinUm=, TuningNormalize=).
%   With Folder, [P, S, FILES] = ... also writes the tables, figures and a
%   JSON record there (writePopulation).
%
%   The selection's groupBy is not used: each unit's PSTH pools every epoch
%   the selection keeps, Param gives the dependence on a trial parameter
%   and AurocGroupBy splits the auROC's epochs. Units.response is not used either, since every unit is
%   tested here with one correction over the family. Filter P.units by
%   responsive / tuned instead; passing an enabled Units.response is
%   populationAnalysis:ResponseSelection. A dataset that cannot be analysed
%   is left out and listed in P.datasets, with the warning
%   populationAnalysis:DatasetSkipped when it has nothing to analyse (no
%   units, events or epochs), else populationAnalysis:DatasetFailed.
%
%   P fields
%     units     table, one row per unit: dataset, datasetKey, subject (the
%               name pattern's SubjectID, else the behavior's), then
%               selectUnits' columns (label, unitId, class, channel,
%               channelName, shank, x, y, nSpikes and, with
%               Units.quality, the quality metrics), rateHz (nSpikes /
%               durationSec), responseStats' columns (nEpochs, baselineRate,
%               responseRate, pEvoked, qEvoked, direction, responsive and,
%               with Param, nLevels, pTuning, qTuning, tuned, bestLevel,
%               bestRate; q over the family), psthPeak (the highest PSTH
%               bin whose centre lies in the response window, in the PSTH's
%               unit), psthLatency (that bin's centre, s; NaN when every
%               such bin is equal), and the auROC's (P.auroc.calls per
%               group): aurocGroup, aurocMean, aurocPhasic, aurocPeak,
%               aurocPeakTime, aurocP and aurocQ of the unit's group whose
%               mean auROC is farthest from 0.5 (its only group without
%               AurocGroupBy), aurocDirection ("increase" | "decrease" when
%               called so in some group and never the other way, "mixed"
%               when both, "none"; "" without Tests or a call) and
%               aurocModulated (in any group)
%     psth      t [nBins x 1] (bin centres, s), rate [nBins x nUnits] (each
%               unit's PSTH, the rows of P.units), units (its measurement
%               unit), window, binSec, smoothSec, measure, baselineMode
%     auroc     ([] without Tests) t [nWindows x 1] (window centres, s),
%               calls (table, one row per unit and group, a unit's groups
%               together: dataset, datasetKey, subject, label, unitId,
%               unit (its row of P.units), group, nEpochs, mean and phasic
%               (the mean auROC and mean |auROC - 0.5| over the windows
%               inside Auroc.modulationWindow; NaN for a unit silent over
%               the group's epochs), peak (the auROC there farthest from
%               0.5) and peakTime (its window's centre, s; both NaN when
%               every such window is equal), p and q (cutoff "test"; q
%               over the family), direction ("increase" | "decrease" |
%               "none"; "" without a call), modulated), auroc [nWindows x
%               height(calls)] (each row's curve), inModulation, baseline,
%               modulationWindow, method, windows, groupBy (AurocGroupBy),
%               cutoff, settings (Auroc as used), families (table: family
%               ("all" or the datasetKey), nUnits, nCurves (the unit x
%               group curves with an auROC: the n of the 95% CI),
%               cutoffValue (c, the cutoff pooled over them; NaN for
%               "test" and "none"), nModulated, nIncrease, nDecrease (of
%               the curves))
%     tuning    param, levels [nLevels x 1] (every dataset's, sorted),
%               rate [nLevels x nUnits] (mean response rate per level,
%               spikes/s; NaN where a unit has no epoch of a level), n
%               (the epochs)
%     datasets  table: datasetKey, dataset, subject, status ("done" |
%               "skipped" | "error"), message, nUnits, nEpochs (the PSTH's),
%               nTestEpochs, nTestEpochsLeftOut
%     params    every option as used (ref, window and selection resolved)
%     provenance, created
%
%   Options
%     Units          UnitSelection (default: its defaults, sorted su + mua)
%     Ref, Window, Selection   eventRef / epochWindow (fixed) /
%                    trialSelection; [] = the config's Defaults
%     BinSec (0.01), SmoothSec (0), Measure ("rate")   the PSTH's
%     BaselineMode   the PSTH's: "none" (default) | "subtract" | "zscore" |
%                    "percent" (spikePSTH), over Baseline
%     Baseline       [b0 b1] s from the event (default [-0.2 0]): the
%                    test's baseline window, the PSTH's and the auROC's
%                    (the epochs leave out any whose baseline touches an
%                    artifact period)
%     Response       [w0 w1] s from the event (default [0 0.2])
%     Param          the trial parameter of the tuning test and curves
%     Auroc          the auROC's settings, as a plot's auroc
%                    (EphysAnalysisConfig.defaults("Auroc"): method,
%                    windows, windowSec, stepSec, modulationWindow, cutoff,
%                    threshold, test, nResamples; the fields left out take
%                    the defaults: the 95% CI cutoff over [0 0.5] s). Its
%                    correction and alpha are not used: Correction and
%                    Alpha below are, as for the response tests
%     AurocGroupBy   0-2 trial parameters: each unit's epochs split by them
%                    (the selection's groups, e.g. "TrialType" with
%                    Selection.response keeping hits and false alarms), a
%                    curve and a call per group, every unit x group curve
%                    pooled for the cutoff (default []: one curve per unit
%                    over every epoch)
%     Tests          true (default): the toolbox's tests and the auROC
%                    (Statistics and Machine Learning Toolbox); false:
%                    rates and tuning curves only, every p NaN
%     Correction     "bh" (default) | "holm" | "bonferroni" | "none"
%     Family         "all" (default) | "dataset"
%     Alpha          0.05: responsive / tuned (auROC test: modulated) when
%                    the adjusted p is at most Alpha
%     GroupBy, DepthBinUm, TuningNormalize   populationSummary's
%     Datasets       the datasets to use (keys, names or indices; [] = all)
%     Folder, Formats (["png"]), Dpi (150), FigureSizeCm ([18 12])
%                    writePopulation's ("" = write nothing)
%     LogFcn         LogFcn(message) per dataset (default: print; [] = quiet)
%
%   Errors: populationAnalysis:BadSource, populationAnalysis:BadOption,
%   populationAnalysis:BadWindow, populationAnalysis:ResponseSelection,
%   populationAnalysis:MixedLevels, populationAnalysis:NoUnits,
%   populationAnalysis:Bins (the datasets' PSTH bins differ),
%   responseStats:NoToolbox (Tests without the toolbox). Warnings:
%   aurocCall's, for the cutoff of a family.
%
%   See also populationSummary, renderPopulation, writePopulation,
%   responseStats, aurocCurves, aurocCall, spikePSTH, selectUnits,
%   EphysAnalysisRunner.

arguments
    source
    opts.Units = []
    opts.Ref = []
    opts.Window = []
    opts.Selection = []
    opts.BinSec (1,1) double {mustBePositive} = 0.01
    opts.SmoothSec (1,1) double {mustBeNonnegative} = 0
    opts.Measure (1,1) string = "rate"
    opts.BaselineMode (1,1) string = "none"
    opts.Baseline double = [-0.2 0]
    opts.Response double = [0 0.2]
    opts.Param (1,1) string = ""
    opts.Auroc = struct()
    opts.AurocGroupBy (1,:) string = string.empty(1, 0)
    opts.Tests (1,1) logical = true
    opts.Correction (1,1) string = "bh"
    opts.Family (1,1) string = "all"
    opts.Alpha (1,1) double = 0.05
    opts.GroupBy (1,:) string = ["subject" "class"]
    opts.DepthBinUm (1,1) double {mustBePositive} = 100
    opts.TuningNormalize (1,1) string = "peak"
    opts.Datasets = []
    opts.Folder (1,1) string = ""
    opts.Formats (1,:) string = "png"
    opts.Dpi (1,1) double {mustBePositive} = 150
    opts.FigureSizeCm (1,2) double {mustBePositive} = [18 12]
    opts.LogFcn = @(msg) fprintf('%s\n', msg)
end

% --- the datasets and the settings ------------------------------------------------------
if isa(source, 'EphysAnalysisRunner')
    runner = source;
elseif isa(source, 'EphysAnalysisConfig')
    runner = EphysAnalysisRunner(source, LogFcn=[]);
else
    error('populationAnalysis:BadSource', 'Pass an EphysAnalysisConfig or an EphysAnalysisRunner.');
end
cfg = runner.Config;
checkOption(opts.Correction, ["bh" "holm" "bonferroni" "none"], "Correction");
checkOption(opts.Family, ["all" "dataset"], "Family");
checkOption(opts.BaselineMode, ["none" "subtract" "zscore" "percent"], "BaselineMode");
checkOption(opts.Measure, ["rate" "count" "probability"], "Measure");
if ~(opts.Alpha > 0 && opts.Alpha <= 1)
    error('populationAnalysis:BadOption', 'Alpha must be in (0, 1] (got %g).', opts.Alpha);
end
ref = opts.Ref;
if isempty(ref); ref = cfg.Defaults.EventRef; end
ref = eventRef(ref);
win = opts.Window;
if isempty(win); win = cfg.Defaults.Window; end
win = epochWindow(win);
if win.mode ~= "fixed"
    error('populationAnalysis:BadWindow', 'The population PSTH needs a "fixed" window (got "%s").', win.mode);
end
sel = opts.Selection;
if isempty(sel); sel = cfg.Defaults.Selection; end
sel = trialSelection(sel);
sel.groupBy = string.empty(1, 0);    % one PSTH per unit, over every selected epoch
usel = opts.Units;
if isempty(usel); usel = struct(); end
[usel, unknown] = EphysAnalysisConfig.normalizeSection("UnitSelection", usel);
if ~isempty(unknown)
    error('populationAnalysis:BadOption', 'Unknown unit-selection field(s): %s.', strjoin(unknown, ", "));
end
if usel.response.enabled
    error('populationAnalysis:ResponseSelection', ...
        ['Units.response is not used here: populationAnalysis tests every unit itself (Response=, Baseline=, ' ...
         'Param=) with one correction over the family. Filter P.units by responsive / tuned instead.']);
end
if opts.Tests && ~(license('test', 'Statistics_Toolbox') && exist('signrank', 'file') > 0 && exist('tiedrank', 'file') > 0 ...
        && (opts.Param == "" || exist('kruskalwallis', 'file') > 0))
    error('responseStats:NoToolbox', ['The tests need the Statistics and Machine Learning Toolbox ' ...
        '(signrank, kruskalwallis; tiedrank for the auROC); Tests=false gives the rates and tuning curves without them.']);
end
[au, unknown] = EphysAnalysisConfig.normalizeSection("Auroc", opts.Auroc);
if ~isempty(unknown)
    error('populationAnalysis:BadOption', 'Unknown auROC setting(s): %s.', strjoin(unknown, ", "));
end
bPSTH = [];
if opts.BaselineMode ~= "none"; bPSTH = opts.Baseline; end
say = opts.LogFcn;
if isempty(say); say = @(msg) []; end

if isempty(opts.Datasets)
    idx = 1:numel(runner.Outputs);
else
    want = opts.Datasets;
    if ~isnumeric(want); want = string(want); end
    idx = zeros(1, numel(want));
    for j = 1:numel(want)
        idx(j) = runner.index(want(j));
        if idx(j) == 0
            error('populationAnalysis:BadOption', 'No dataset "%s".', string(want(j)));
        end
    end
end

% --- per dataset ---------------------------------------------------------------------------
nD = numel(idx);
D = table(strings(nD, 1), strings(nD, 1), strings(nD, 1), repmat("error", nD, 1), strings(nD, 1), ...
    zeros(nD, 1), zeros(nD, 1), zeros(nD, 1), zeros(nD, 1), ...
    'VariableNames', {'datasetKey', 'dataset', 'subject', 'status', 'message', 'nUnits', 'nEpochs', ...
    'nTestEpochs', 'nTestEpochsLeftOut'});
skipIds = ["selectUnits:NoUnits" "selectUnits:NoDetected" "selectUnits:NoneLeft" "epochTable:NoEpochs" ...
    "resolveEvents:NoEvents" "resolveEvents:NoLine" "responseStats:NoEpochs"];
parts = cell(nD, 1);
psth = cell(nD, 1);
aur = cell(nD, 1);
lev = cell(nD, 1);
t = [];
psthUnits = "";
psthWindow = [];
A1 = [];   % the first dataset's auROC result: its windows
for j = 1:nD
    k = idx(j);
    D.datasetKey(j) = runner.Keys(k);
    D.dataset(j) = runner.Names(k);
    say(sprintf('populationAnalysis: %s (%d of %d)', runner.Names(k), j, nD));
    try
        src = runner.source(k);
        subject = subjectOf(src, cfg.Source.NamePattern);
        D.subject(j) = subject;
        [st, meta] = selectUnits(src, usel, Ref=ref, Selection=sel);
        E = epochTable(src, ref, Window=win, Selection=sel, Baseline=opts.Baseline);
        R = spikePSTH(st, E, Window=[win.pre win.post], BinSec=opts.BinSec, SmoothSec=opts.SmoothSec, ...
            Measure=opts.Measure, Baseline=bPSTH, BaselineMode=opts.BaselineMode, Raster=false, Meta=meta);
        Er = responseEpochs(src, ref, sel, Baseline=opts.Baseline, Window=opts.Response, Param=opts.Param);
        [T, info] = responseStats(st, Er, Baseline=opts.Baseline, Window=opts.Response, Param=opts.Param, ...
            Correction="none", Alpha=opts.Alpha, Meta=meta, Tests=opts.Tests);
        A = [];
        if opts.Tests   % each unit's auROC per group; the call is made over the family below
            Ea = E;
            Ga = [];
            if ~isempty(opts.AurocGroupBy)
                selA = sel;
                selA.groupBy = opts.AurocGroupBy;
                [Ea, Ga] = epochTable(src, ref, Window=win, Selection=selA, Baseline=opts.Baseline);
            end
            A = aurocCurves(st, Ea, Window=[win.pre win.post], Baseline=opts.Baseline, BinSec=opts.BinSec, ...
                Measure=opts.Measure, Method=au.method, Windows=au.windows, WindowSec=au.windowSec, StepSec=au.stepSec, ...
                ModulationWindow=au.modulationWindow, Cutoff=au.cutoff, Threshold=au.threshold, Test=au.test, ...
                NResamples=au.nResamples, Call=false, Groups=Ga);
            A.nEpochs = accumarray(Ea.groupIndex, 1, [height(A.groups) 1]);
        end
    catch ME
        D.message(j) = string(ME.message);
        if ismember(string(ME.identifier), skipIds)
            D.status(j) = "skipped";
        end
        say(sprintf('  %s: %s', D.status(j), ME.message));
        continue
    end
    if isempty(t)
        t = R.t(:);
        psthUnits = string(R.units);
        psthWindow = R.window;
    elseif ~isequal(R.t(:), t)
        error('populationAnalysis:Bins', '%s: the PSTH bins differ from the first dataset''s.', D.dataset(j));
    end
    n = height(meta);
    U = meta;
    U = addvars(U, repmat(D.dataset(j), n, 1), repmat(D.datasetKey(j), n, 1), repmat(subject, n, 1), ...
        'Before', 1, 'NewVariableNames', {'dataset', 'datasetKey', 'subject'});
    U.rateHz = double(U.nSpikes) / src.durationSec;
    for c = setdiff(string(T.Properties.VariableNames), ["unit" "label"], 'stable')
        U.(c) = T.(c);
    end
    rate = R.rate(:, :, 1);
    [pk, lat] = peakIn(rate, t, opts.Response);
    U.psthPeak = pk;
    U.psthLatency = lat;
    U.aurocGroup = strings(n, 1);
    U.aurocMean = NaN(n, 1);
    U.aurocPhasic = NaN(n, 1);
    U.aurocPeak = NaN(n, 1);
    U.aurocPeakTime = NaN(n, 1);
    U.aurocP = NaN(n, 1);
    U.aurocQ = NaN(n, 1);
    U.aurocDirection = strings(n, 1);
    U.aurocModulated = false(n, 1);
    if ~isempty(A)
        if isempty(A1); A1 = A; end
        aur{j} = A;
    end
    parts{j} = U;
    psth{j} = rate;
    lev{j} = struct('levels', info.levels, 'rate', info.levelRate, 'n', info.levelN);
    D.status(j) = "done";
    D.nUnits(j) = n;
    D.nEpochs(j) = height(E);
    D.nTestEpochs(j) = info.nEpochs;
    D.nTestEpochsLeftOut(j) = info.nEpochsLeftOut;
end
reportDatasets(D);
done = find(D.status == "done").';
if isempty(done)
    error('populationAnalysis:NoUnits', 'No dataset gave units to analyse:%s', ...
        sprintf('\n  %s: %s', [D.dataset D.message].'));
end

% --- one table ---------------------------------------------------------------------------
if opts.Param ~= ""
    numericLevels = arrayfun(@(j) isnumeric(parts{j}.bestLevel), done);
    if ~(all(numericLevels) || ~any(numericLevels))
        error('populationAnalysis:MixedLevels', ...
            '"%s" is numeric in some datasets and text in others; its levels cannot be pooled.', opts.Param);
    end
end
U = vertcat(parts{done});
rateAll = [psth{done}];
if opts.Tests
    U.qEvoked = adjust(U.pEvoked, U.datasetKey, opts.Correction, opts.Family);
    U.responsive = U.qEvoked <= opts.Alpha;
    if opts.Param ~= ""
        U.qTuning = adjust(U.pTuning, U.datasetKey, opts.Correction, opts.Family);
        U.tuned = U.qTuning <= opts.Alpha;
    end
    [calls, curves] = aurocRows(U, aur(done));
    [calls, families] = aurocFamilies(calls, au, opts.Correction, opts.Alpha, opts.Family);
    U = aurocPerUnit(U, calls);
end

levels = [];
tuneRate = zeros(0, height(U));
tuneN = zeros(0, height(U));
if opts.Param ~= ""
    all0 = cellfun(@(L) L.levels(:), lev(done), 'UniformOutput', false);
    levels = unique(vertcat(all0{:}));
    tuneRate = NaN(numel(levels), height(U));
    tuneN = zeros(numel(levels), height(U));
    c0 = 0;
    for j = done
        L = lev{j};
        cols = c0 + (1:D.nUnits(j));
        [~, loc] = ismember(L.levels(:), levels);
        tuneRate(loc, cols) = L.rate;
        tuneN(loc, cols) = L.n;
        c0 = c0 + D.nUnits(j);
    end
end

P = struct();
P.units = U;
P.psth = struct('t', t, 'rate', rateAll, 'units', psthUnits, 'window', psthWindow, 'binSec', opts.BinSec, ...
    'smoothSec', opts.SmoothSec, 'measure', opts.Measure, 'baselineMode', opts.BaselineMode);
P.tuning = struct('param', opts.Param, 'levels', levels, 'rate', tuneRate, 'n', tuneN);
P.auroc = [];
if opts.Tests
    P.auroc = struct('t', A1.t, 'auroc', curves, 'calls', calls, 'inModulation', A1.inModulation, ...
        'baseline', A1.baseline, 'modulationWindow', A1.modulationWindow, 'method', A1.method, 'windows', A1.windows, ...
        'groupBy', opts.AurocGroupBy, 'cutoff', au.cutoff, 'settings', au, 'families', families);
end
P.datasets = D;
P.params = struct('units', usel, 'ref', ref, 'window', win, 'selection', sel, 'binSec', opts.BinSec, ...
    'smoothSec', opts.SmoothSec, 'measure', opts.Measure, 'baselineMode', opts.BaselineMode, ...
    'baseline', opts.Baseline, 'response', opts.Response, 'param', opts.Param, 'auroc', au, ...
    'aurocGroupBy', opts.AurocGroupBy, 'tests', opts.Tests, ...
    'correction', opts.Correction, 'family', opts.Family, 'alpha', opts.Alpha, 'config', cfg.Name);
P.provenance = ephysProvenance();
P.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

S = populationSummary(P, GroupBy=opts.GroupBy, DepthBinUm=opts.DepthBinUm, TuningNormalize=opts.TuningNormalize);
files = strings(1, 0);
if opts.Folder ~= ""
    files = writePopulation(P, S, opts.Folder, Formats=opts.Formats, Dpi=opts.Dpi, FigureSizeCm=opts.FigureSizeCm);
end
end


function checkOption(v, allowed, name)
if ~ismember(v, allowed)
    error('populationAnalysis:BadOption', '%s is %s (got "%s").', name, strjoin(allowed, ", "), v);
end
end


function s = subjectOf(src, pattern)
%subjectOf  The name pattern's SubjectID, else the behavior's subject, else "".
id = EphysDataset.nameIdentity(src.name, pattern);
s = id.subject;
if s == "" && isfield(src, 'subject'); s = string(src.subject); end
end


function [pk, lat] = peakIn(rate, t, w)
%peakIn  Per unit: the highest bin whose centre lies in [w0, w1), and that centre.
n = size(rate, 2);
pk = NaN(n, 1);
lat = NaN(n, 1);
in = t >= w(1) & t < w(2);
if ~any(in); return; end
tt = t(in);
Y = rate(in, :);
for u = 1:n
    y = Y(:, u);
    if all(isnan(y)) || max(y) == min(y); continue; end
    [pk(u), i] = max(y);
    lat(u) = tt(i);
end
end


function [C, curves] = aurocRows(U, aur)
%aurocRows  One row per unit and auROC group, from each dataset's aurocCurves result (AUR, in the order of U's rows).
%   C: the unit's identity (dataset, datasetKey, subject, label, unitId),
%   unit (its row of U), group, nEpochs, mean, phasic, peak, peakTime, p;
%   CURVES [nWindows x height(C)] its auROC curve. A unit's groups are
%   adjacent.
C = table();
curves = [];
row0 = 0;
for j = 1:numel(aur)
    A = aur{j};
    [n, nG] = size(A.mean);
    [pk, at] = aurocPeak(A);
    ui = repelem((1:n).', nG);
    gi = repmat((1:nG).', n, 1);
    rows = @(x) reshape(x.', [], 1);   % [nUnits x nGroups] as rows, a unit's groups together
    C = [C; table(row0 + ui, string(A.groups.label(gi)), A.nEpochs(gi), rows(A.mean), rows(A.phasic), rows(pk), ...
        rows(at), rows(A.p), 'VariableNames', {'unit', 'group', 'nEpochs', 'mean', 'phasic', 'peak', 'peakTime', 'p'})]; %#ok<AGROW>
    curves = [curves, reshape(permute(A.auroc, [1 3 2]), size(A.auroc, 1), [])]; %#ok<AGROW>
    row0 = row0 + n;
end
id = intersect(["dataset" "datasetKey" "subject" "label" "unitId"], string(U.Properties.VariableNames), 'stable');
C = [U(C.unit, id), C];
end


function [pk, at] = aurocPeak(A)
%aurocPeak  Per unit and group: the auROC of the window inside the modulation window farthest from 0.5, and that window's centre.
%   NaN where the windows there are all equally far from 0.5.
a = A.auroc(A.inModulation, :, :);
tt = A.t(A.inModulation);
[~, n, nG] = size(a);
pk = NaN(n, nG);
at = NaN(n, nG);
for g = 1:nG
    for u = 1:n
        d = abs(a(:, u, g) - 0.5);
        if all(isnan(d)) || max(d) == min(d); continue; end
        [~, i] = max(d);
        pk(u, g) = a(i, u, g);
        at(u, g) = tt(i);
    end
end
end


function [C, F] = aurocFamilies(C, a, correction, alpha, mode)
%aurocFamilies  The auROC calls (aurocCall) over every unit and group, or over each dataset's; each family's cutoff.
%   C: aurocRows' table, given q, direction and modulated. F: one row per
%   family: family, nUnits, nCurves (the unit x group curves with an auROC,
%   the n of the 95% CI), cutoffValue, nModulated / nIncrease / nDecrease
%   (curves).
if mode == "all"
    family = repmat("all", height(C), 1);
else
    family = C.datasetKey;
end
C.q = NaN(height(C), 1);
C.direction = strings(height(C), 1);
C.modulated = false(height(C), 1);
names = unique(family, 'stable');
nF = numel(names);
F = table(names, zeros(nF, 1), zeros(nF, 1), NaN(nF, 1), zeros(nF, 1), zeros(nF, 1), zeros(nF, 1), 'VariableNames', ...
    {'family', 'nUnits', 'nCurves', 'cutoffValue', 'nModulated', 'nIncrease', 'nDecrease'});
for i = 1:nF
    rows = family == names(i);
    K = struct('mean', C.mean(rows), 'phasic', C.phasic(rows), 'p', C.p(rows));
    K = aurocCall(K, Cutoff=a.cutoff, Threshold=a.threshold, Correction=correction, Alpha=alpha);
    C.q(rows) = K.q;
    C.direction(rows) = K.direction;
    C.modulated(rows) = K.modulated;
    F(i, 2:end) = {numel(unique(C.unit(rows))), nnz(isfinite(C.phasic(rows))), K.cutoffValue, K.nModulated, ...
        K.nIncrease, K.nDecrease};
end
end


function U = aurocPerUnit(U, C)
%aurocPerUnit  Each unit's auROC columns from its groups' rows of C (aurocFamilies').
%   The numbers and aurocGroup are those of the group whose mean auROC is
%   farthest from 0.5 (a unit's one group without AurocGroupBy); the
%   direction is "increase" or "decrease" when the unit is called so in a
%   group and never the other way, "mixed" when both, "none" when called
%   in no group, "" without a call; modulated in any group.
for r = 1:height(U)
    k = find(C.unit == r);
    if isempty(k); continue; end
    [~, b] = max(abs(C.mean(k) - 0.5));
    b = k(b);
    if isfinite(C.mean(b)); U.aurocGroup(r) = C.group(b); end
    U.aurocMean(r) = C.mean(b);
    U.aurocPhasic(r) = C.phasic(b);
    U.aurocPeak(r) = C.peak(b);
    U.aurocPeakTime(r) = C.peakTime(b);
    U.aurocP(r) = C.p(b);
    U.aurocQ(r) = C.q(b);
    d = C.direction(k);
    up = any(d == "increase");
    dn = any(d == "decrease");
    if up && dn
        U.aurocDirection(r) = "mixed";
    elseif up
        U.aurocDirection(r) = "increase";
    elseif dn
        U.aurocDirection(r) = "decrease";
    elseif any(d == "none")
        U.aurocDirection(r) = "none";
    end
    U.aurocModulated(r) = any(C.modulated(k));
end
end


function q = adjust(p, family, method, mode)
%adjust  pAdjust over every unit, or over each dataset's units.
if mode == "all"
    q = pAdjust(p, method);
    return
end
q = NaN(size(p));
for f = unique(family).'
    rows = family == f;
    q(rows) = pAdjust(p(rows), method);
end
end


function reportDatasets(D)
%reportDatasets  One warning for the datasets skipped, one for those that failed.
for kind = ["skipped" "error"]
    rows = D.status == kind;
    if ~any(rows); continue; end
    list = strjoin(compose("%s (%s)", D.dataset(rows), D.message(rows)), "; ");
    if kind == "skipped"
        warning('populationAnalysis:DatasetSkipped', '%d dataset(s) with nothing to analyse are left out: %s', nnz(rows), list);
    else
        warning('populationAnalysis:DatasetFailed', '%d dataset(s) failed and are left out: %s', nnz(rows), list);
    end
end
end
