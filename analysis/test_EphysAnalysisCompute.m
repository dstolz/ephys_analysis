function test_EphysAnalysisCompute()
%test_EphysAnalysisCompute  Verification suite for the compute and render functions.
%   No recording is needed: seeded Poisson spike trains and synthetic
%   signals check spikePSTH (rates, SEM, half-open bins aligned to the
%   event, baseline, smoothing, stop masking, rasters), a spike in the
%   event's own sample at 0 (spikePSTH, firingRate, unitCorrelation),
%   firingRate ("between" windows, baselines), tuningCurve (and
%   tuningCurve:NoValues), evokedPotential (the event's own row at the
%   recording rate, a bump on the event's sample peaking at 0 at derived
%   rates, NaN padding and drop counts, baseline), the trial-filter
%   compiler, unitCorrelation (Pearson and Spearman against corrcoef, peak
%   rates, partial bins, baseline, groups, degenerate units), that every
%   renderer draws into a classic figure's axes, a uifigure's uiaxes and a
%   figure (tiled layout), including renderPlot's pages and titles,
%   binCounts / countBelow against brute force (a spike on a bin edge in
%   the bin that starts there, on a 30 kHz sample grid too), and the unit waveform
%   boxes (where each location puts them, on a reversed raster too; the
%   modes, box and scale; the limits kept; none on an overlay; templates),
%   the raster's sort direction, its sort by another event's latency
%   (R.rasterSortEvent: the order, the y label, the caption's count of
%   epochs without the event), its rows sorted across groups and its
%   event marks (epochEvents' result: where they sit, their look, the
%   aesthetics rules reaching them), behaviorValues / renderBehavior
%   (means, series, missing values, every layout, the jitter, a linear x
%   axis), and the mean aux signal: auxMean (each channel, the vector
%   magnitude taken per epoch before the mean, the baseline before the
%   magnitude, every epoch as one group, epochs leaving the signal) and its
%   panels below and above, on the right axis of a PSTH or raster (below a
%   stack), their colors, line styles, legend, y labels, caption, overlays,
%   the aesthetics editor's list and the export page's height; the error
%   bands and bars: errorBounds (SEM as semOf, SD, the bootstrap 95% CI as
%   bootci's percentile one, repeatable, the global stream untouched), the
%   error each compute function makes (R.err; a z-scored PSTH's scaled, an
%   auROC's none), the bands' look from the style (and the default as
%   before), the bands and bars drawn from R.err, an overlay's across the
%   units, captions, and plotErrorType; and across sessions: sessionTable
%   (labels, order), combineSessions on hand-made results of every kind
%   (pool / site / mapping tiles, series per session / subject / all, the
%   SEM and t 95% CI across sessions, members, epoch renumbering on every
%   epoch-indexed field, Group slicing against the compute over that group,
%   combine's labels and line styles, rate's rowsAre, every error id), every
%   renderer drawing the merged results on every page, a session spec's own
%   aesthetics, and sessionResults' facets and groups; and the data export:
%   the unit-mapping CSV (writeUnitMapping, readUnitMapping), sessionData,
%   writeAnalysisData (round trip, Exists) and epochLongTable (counts,
%   spikes, signals and every kind's values) on hand-made epochData and
%   results (epochData itself is checked on the fixture in
%   test_EphysAnalysisRunner).
%
%   Usage:  test_EphysAnalysisCompute

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);

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
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end

rng(7, 'twister');

fprintf('\n== 1. spikePSTH on Poisson trains ==\n');
lambda = 20;
T = 820;
st = poissonTrain(lambda, T);
t0 = (5:2:805).';
E = epochs(t0, ones(numel(t0), 1));
R = spikePSTH({st}, E, Window=[-0.2 0.5], BinSec=0.05);
m = mean(R.rate(:, 1, 1));
check(abs(m - lambda) / lambda < 0.05 && numel(R.t) == 14 && abs(R.t(1) + 0.175) < 1e-12 && R.nEpochs == numel(t0), ...
    sprintf('the mean rate of a %g Hz train is %.2f Hz (within 5%%), 14 bins of 50 ms', lambda, m));
check(sum(R.count(:)) == sum(arrayfun(@(a) nnz(st >= a - 0.2 & st < a + 0.5), t0)), 'count is every spike in [t0-0.2, t0+0.5)');
Rs = spikePSTH({st}, E(1:100, :), Window=[-0.2 0.5], BinSec=0.05);
check(mean(Rs.sem) / mean(R.sem) > 1.6, sprintf('SEM shrinks with more epochs (%.2f vs %.2f)', mean(Rs.sem), mean(R.sem)));
one = epochs(10, 1);
Rb = spikePSTH({[10 - 0.2; 10.5; 10.1]}, one, Window=[-0.2 0.5], BinSec=0.01);
check(sum(Rb.count) == 2 && Rb.count(1) == 1 && max(abs(sort(Rb.raster.times).' - [-0.2 0.1])) < 1e-12, ...
    'half-open bins: a spike at t0+pre counts, one at t0+post does not');
Ra = spikePSTH({st}, E, Window=[-0.25 0.5], BinSec=0.1);
check(max(abs(Ra.edges - (-2:5) * 0.1)) < 1e-12 && isequal(Ra.window, Ra.edges([1 end])) && isequal(Ra.params.Window, [-0.25 0.5]) ...
    && sum(Ra.count(:)) == sum(arrayfun(@(a) nnz(st >= a - 0.2 & st < a + 0.5), t0)), ...
    'bins are whole multiples of BinSec from the event: [-0.25 0.5] in 0.1 s bins covers [-0.2 0.5] (R.window)');
Rq = spikePSTH({st}, E, Window=[-0.2 0.5], BinSec=0.015);
check(any(Rq.edges == 0) && abs(Rq.window(1) + 0.195) < 1e-12 && abs(Rq.window(2) - 0.495) < 1e-12 && numel(Rq.t) == 46, ...
    'no bin straddles the event: [-0.2 0.5] in 15 ms bins covers [-0.195 0.495], an edge at 0');
check(strcmp(errorId(@() spikePSTH({st}, E, Window=[-0.005 0.004], BinSec=0.01)), 'spikePSTH:BadWindow'), ...
    'a window that holds no whole bin: spikePSTH:BadWindow');
fsRec = 30000;
r = 90000;                                          % an event at recording row r: t0 = r/Fs
Ek = epochs(r / fsRec, 1, fsRec);
Ek.tStart = Ek.t0; Ek.tStop = Ek.t0 + 0.01;
sp = {(r - 1) / fsRec};                             % a spike in the event's own sample: (row-1)/Fs
Rk = spikePSTH(sp, Ek, Window=[-0.01 0.01], BinSec=0.01);
Fk = firingRate(sp, Ek);
Ck = unitCorrelation(sp, Ek);
check(isequal(Rk.count(:).', [0 1]) && Rk.raster.times == 0 && Fk.count == 1 && Ck.response == 100, ...
    'a spike in the event''s own sample is at 0: in the bin after the event, and in a window that starts at it');
R0 = spikePSTH({st}, E, Window=[-0.2 0.5], BinSec=0.05, Baseline=[-0.2 0], BaselineMode="subtract");
check(abs(mean(R0.rate)) < 0.05 * lambda && abs(R0.baselineRate - lambda) / lambda < 0.05 && R0.units == "spikes/s - baseline", ...
    sprintf('baseline subtraction of a flat train is %.2f (about 0)', mean(R0.rate)));
Rz = spikePSTH({st}, E, Window=[-0.2 0.5], BinSec=0.05, Baseline=[-0.2 0], BaselineMode="zscore");
check(abs(mean(Rz.rate)) < 0.3 && Rz.units == "z (baseline)", 'z-scored flat train is about 0');
Rg = spikePSTH({st}, E, Window=[-0.2 0.5], BinSec=0.01, SmoothSec=0.02);
Rr = spikePSTH({st}, E, Window=[-0.2 0.5], BinSec=0.01);
check(abs(mean(Rg.rate) - mean(Rr.rate)) / mean(Rr.rate) < 0.01 && std(Rg.rate) < std(Rr.rate), ...
    'smoothing keeps the mean and lowers the bin-to-bin spread');
drv = [st; driven(t0, 0.05, 0.25, 60)];
Rd = spikePSTH({st, drv}, E, Window=[-0.2 0.5], BinSec=0.05, Labels=["flat" "driven"]);
inWin = Rd.t > 0.05 & Rd.t < 0.25;
check(mean(Rd.rate(inWin, 2)) > mean(Rd.rate(~inWin, 2)) + 40 && abs(mean(Rd.rate(inWin, 1)) - lambda) < 3 ...
    && isequal(Rd.labels, ["flat"; "driven"]), 'a driven window shows up in the driven unit only');
E2 = epochs(t0, 1 + (mod((1:numel(t0)).', 2) == 0));
E2.t1 = E2.t0 + 0.21;
Rm = spikePSTH({st}, E2, Window=[-0.2 0.5], BinSec=0.05, MaskAfterStop=true);
after = Rm.t - 0.025 >= 0.21;
check(all(isnan(Rm.rate(after, 1, :)), 'all') && all(isfinite(Rm.rate(~after, 1, :)), 'all') && size(Rm.rate, 3) == 2 ...
    && all(abs(Rm.stopMean - 0.21) < 1e-12) && all(Rm.raster(1).times < 0.21), 'MaskAfterStop drops the bins after the stop event');

fprintf('\n== 2. firingRate: between windows and baselines ==\n');
nE = 200;
t0 = (10:4:10 + 4 * (nE - 1)).';
dur = 0.5 + 1.5 * rand(nE, 1);
Eb = epochs(t0, ones(nE, 1));
Eb.t1 = t0 + dur; Eb.tStart = t0; Eb.tStop = Eb.t1; Eb.duration = dur;
s2 = sort([poissonTrain(5, t0(end) + 5); insideTrain(t0, dur, 25)]);   % 5 Hz everywhere + 25 Hz inside
F = firingRate({s2}, Eb, Baseline=[-1 0]);
check(abs(F.meanRate - 30) / 30 < 0.05 && abs(F.baselineRate - 5) / 5 < 0.15 && max(abs(F.duration - dur)) < 1e-9, ...
    sprintf('the rate inside variable-length windows is %.1f Hz (30 expected), baseline %.1f Hz (5)', F.meanRate, F.baselineRate));
Fs = firingRate({s2}, Eb, Baseline=[-1 0], Normalize="subtract");
check(abs(mean(Fs.rate) - 25) < 1.5 && Fs.units == "spikes/s - baseline", 'Normalize subtract removes the baseline');
Fr = firingRate({s2}, Eb, Baseline=[-1 0], Normalize="ratio");
check(abs(Fr.meanRate - F.meanRate / mean(F.baseline)) < 1e-9 && Fr.units == "x baseline", 'Normalize ratio divides by the mean baseline');
check(strcmp(errorId(@() firingRate({s2}, Eb, Normalize="zscore")), 'firingRate:BadBaseline'), 'Normalize without Baseline is an error');

fprintf('\n== 3. tuningCurve ==\n');
x = repmat([0; 1; 2; 3], 50, 1);
series = repelem(["a"; "b"], 100);
rates = 10 + 5 * x + (series == "b") * 7 + 0.5 * randn(numel(x), 2);
Tc = tuningCurve(rates, x, Series=series, Param="Depth", SeriesParam="Kind");
check(isequal(Tc.x, [0; 1; 2; 3]) && max(abs(Tc.mean(:, 1, 1) - (10 + 5 * (0:3).')), [], 'all') < 0.3 ...
    && max(abs(Tc.mean(:, 1, 2) - (17 + 5 * (0:3).')), [], 'all') < 0.3 && isequal(Tc.n, 25 * ones(4, 2)) ...
    && isequal(Tc.series, ["Kind = a"; "Kind = b"]), 'the curves recover 10 + 5 x and the series offset');
Tt = tuningCurve(rates(:, 1), string(x));
check(~Tt.xIsNumeric && isequal(Tt.x, ["0"; "1"; "2"; "3"]) && Tt.series == "all", 'a text parameter works too');
check(strcmp(errorId(@() tuningCurve(rates, NaN(size(x)), Param="Depth")), 'tuningCurve:NoValues') ...
    && strcmp(errorId(@() tuningCurve(rates, x, Series=repmat(string(missing), size(x)), Param="Depth", SeriesParam="Kind")), 'tuningCurve:NoValues'), ...
    'no epoch with a parameter value (events outside the trials): tuningCurve:NoValues');

fprintf('\n== 4. evokedPotential: the event''s sample, padding, baseline ==\n');
fs = 1000;
Y = single(0.01 * randn(20000, 3));
rows = [50; 3001; 7200; 12001];               % recording rows of the events (the signal is at the recording rate)
tEv = rows / fs;                              % their digital-event times, row/Fs
Y(rows(2:end), 2) = 100;
Ev = epochs(tEv, [1; 1; 2; 2], fs);
Rv = evokedPotential(Y, fs, Ev, Window=[-0.1 0.2]);
k0 = find(Rv.t == 0);
check(Rv.droppedEdge == 1 && isequal(Rv.nEpochs, [1; 2]) && isequal(Rv.keptEpochs, [2; 3; 4]) ...
    && abs(Rv.mean(k0, 2, 1) - 100) < 0.1 && abs(Rv.mean(k0, 2, 2) - 100) < 0.1 ...
    && max(abs(Rv.mean([1:k0-1 k0+1:end], 2, 2))) < 0.1 && isequal(Rv.sampleOffsets, [-100 200]) && numel(Rv.t) == 301, ...
    'at the recording rate the event''s own row sits at t = 0; the epoch leaving the signal is dropped');
Rn = evokedPotential(Y, fs, Ev, Window=[-0.1 0.2], Incomplete="nan", KeepEpochs=true);
check(Rn.droppedEdge == 0 && isequal(Rn.nEpochs, [2; 2]) && all(isnan(Rn.data(1:51, 1, 1))) && ~any(isnan(Rn.data(52:end, 1, 1))) ...
    && size(Rn.data, 3) == 4 && isa(Rn.data, 'single'), 'Incomplete "nan" keeps it, NaN before the recording start');
Yo = Y + 50;
Yo(1950:2050, 3) = NaN;
Rb = evokedPotential(Yo, fs, epochs([2; 3.001; 7.2], [1; 1; 1], fs), Window=[-0.1 0.2], Baseline=[-0.1 -0.01], Channels=[2 3]);
check(abs(Rb.mean(k0, 1) - 100) < 0.2 && max(abs(Rb.mean(1:90, 1))) < 0.1 && Rb.droppedNonFinite == 1 ...
    && isequal(Rb.channels, [2; 3]) && Rb.nEpochs == 2, 'baseline subtraction; epochs with NaN samples are dropped and counted');
fsRec = 30000;
rEv = [30001; 60008; 90014; 120023];          % recording rows: 0, 7, 13 and 22 thirtieths past a 1 kHz sample
tEv = rEv / fsRec;
Ev = epochs(tEv, ones(4, 1), fsRec);
sd = 0.002;                                   % a 2 ms Gaussian bump centerd on each event's sample, (row-1)/Fs
bump = @(fsSig) single(sum(exp(-((0:round(4.2 * fsSig) - 1).' / fsSig - (rEv.' - 1) / fsRec) .^ 2 / (2 * sd ^ 2)), 2));
okPeak = true; pk = strings(0, 1);
for fsSig = [1000 2000 5000 fsRec]            % derived rows k at (k-1)/fsSig, as resample makes them
    Rd = evokedPotential(bump(fsSig), fsSig, Ev, Window=[-0.01 0.01], KeepEpochs=true);
    [~, i] = max(squeeze(Rd.data(:, 1, :)), [], 1);
    okPeak = okPeak && all(Rd.t(i) == 0);
    pk(end+1) = sprintf("%g Hz: %s ms", fsSig, mat2str(1000 * Rd.t(i).')); %#ok<AGROW>
end
check(okPeak && all(abs(Rd.data(Rd.t == 0, 1, :) - 1) < 1e-6, 'all'), ...
    "a bump on the event's sample peaks at t = 0 at every rate, the sample nearest it (" + strjoin(pk, "; ") + ")");

fprintf('\n== 5. the trial-filter compiler ==\n');
Tt = table([1313; 1154; 2376; 2180], [0.5; 1; 0; 0], ["a"; "b"; "a"; "c"], ...
    'VariableNames', {'RespCode', 'Depth', 'Name'});
f = tableFilterFcn("Hit | Miss", string(Tt.Properties.VariableNames));
check(isequal(f(Tt), [true; true; false; false]), '"Hit | Miss"');
f = tableFilterFcn("Depth > 0 && Name == ""a""", string(Tt.Properties.VariableNames));
check(isequal(f(Tt), [true; false; false; false]), 'a parameter and a text column');
f = tableFilterFcn("ismember(Depth, [0 1]) & !CR", string(Tt.Properties.VariableNames));
check(isequal(f(Tt), [false; true; true; false]), 'ismember and "!"');
check(strcmp(errorId(@() tableFilterFcn("system('dir')", string(Tt.Properties.VariableNames))), 'trialSelection:BadFilter') ...
    && strcmp(errorId(@() tableFilterFcn("eval(""1"")", string(Tt.Properties.VariableNames))), 'trialSelection:BadFilter') ...
    && strcmp(errorId(@() tableFilterFcn("Depth.x > 1", string(Tt.Properties.VariableNames))), 'trialSelection:BadFilter') ...
    && strcmp(errorId(@() tableFilterFcn("Depth > 1; delete('x')", string(Tt.Properties.VariableNames))), 'trialSelection:BadFilter'), ...
    'system(), eval(), field access and ";" are rejected');

fprintf('\n== 6. renderers ==\n');
E3 = epochs(t0, 1 + mod((1:nE).', 3));
E3.t1 = E3.t0 + 0.3;
E3.Properties.UserData = struct('ref', eventRef(line="Stim"), 'window', epochWindow(pre=-0.2, post=0.5), ...
    'selection', trialSelection(), 'scope', "trial", 'nTrials', nE);
G3 = table((1:3).', ["Depth = 0"; "Depth = 0.5"; "Depth = 1"], [0 0 0.5; 0 0.5 0; 0.5 0 0], [0; 0; 0], ...
    'VariableNames', {'index', 'label', 'color', 'n'});
meta = table(["u1"; "u2"; "u3"], [1; 2; 3], ["su"; "mua"; "su"], [1; 5; 3], ["A-000"; "A-004"; "A-002"], [0; 0; 1], ...
    [0; 8; 200], [0; 100; 50], [1; 1; 1], 'VariableNames', {'label', 'unitId', 'class', 'channel', 'channelName', 'shank', 'x', 'y', 'nSpikes'});
Rp = spikePSTH({s2, st, drv}, E3, Window=[-0.2 0.5], BinSec=0.02, Groups=G3, Meta=meta);
Rp.epochs = E3; Rp.dataset = "synthetic";
Rr = firingRate({s2, st, drv}, E3, Groups=G3, Meta=meta);
Rt = tuningCurve(Rr.rate, mod((1:nE).', 4), Param="Depth", Meta=meta);
Rv.meta = table(["c1"; "c2"; "c3"], [1; 2; 3], [0; 0; 0], [0; 0; 0], [0; 25; 50], 'VariableNames', {'label', 'channel', 'shank', 'x', 'y'});
probe = struct('chanMap', 0:7, 'xc', [0 8 0 8 200 208 200 208], 'yc', [0 25 50 75 0 25 50 75], 'kcoords', [0 0 0 0 1 1 1 1]);
Tu = table(["u1"; "u2"; "u3"], ["su"; "mua"; "su"], [1; 5; 3], [0; 1; 0], [0; 200; 0], [0; 0; 50], [10; 20; 30], [1; 2; 3], ...
    'VariableNames', {'label', 'class', 'channel', 'shank', 'x', 'y', 'nSpikes', 'rateHz'});
Rc = unitCorrelation({s2, st, drv}, E3, Groups=G3, Meta=meta);
Rc.epochs = E3; Rc.dataset = "synthetic";
Rq = probeMapValues(Tu, probe, Value="rate");
check(isequal(Rq.value([1 3 5]), [1; 3; 2]) && all(isnan(Rq.value([2 4 6 7 8]))), 'probeMapValues puts each unit''s rate on its site');
Rq0 = probeMapValues(Tu, probe, Value="nUnits");
check(sum(Rq0.value) == 3 && Rq0.value(2) == 0, 'nUnits counts the units per site');
yb = 200 + 50 * randn(nE, 1);
yb(1:7:end) = NaN;   % no response on these
Rb = behaviorValues(yb, 0.25 * mod((1:nE).', 4), Series=mod((1:nE).', 2), Param="Depth", SeriesParam="TrialType", ...
    YName="RespLatency", YUnits="ms");
cases = {
    "psth grid + raster",  @(tg) renderPSTH(Rp, tg, Layout="grid", WithRaster=true)
    "psth overlay",        @(tg) renderPSTH(Rp, tg, Layout="overlay")
    "psth line",           @(tg) renderPSTH(Rp, tg, Layout="grid", HistStyle="line")
    "psth stack",          @(tg) renderPSTH(Rp, tg, Layout="grid", Stack=true, Fill=false)
    "psth stack overlay",  @(tg) renderPSTH(Rp, tg, Layout="overlay", Stack=true, Normalize="unitPeak", HistStyle="line")
    "raster",              @(tg) renderRaster(Rp, tg)
    "evoked stack",        @(tg) renderEvoked(Rv, tg, Layout="stack")
    "evoked butterfly",    @(tg) renderEvoked(Rv, tg, Layout="butterfly")
    "evoked grid",         @(tg) renderEvoked(Rv, tg, Layout="grid")
    "rates bar",           @(tg) renderRates(Rr, tg, Layout="bar")
    "rates box",           @(tg) renderRates(Rr, tg, Layout="box")
    "rates points",        @(tg) renderRates(Rr, tg, Layout="points")
    "tuning grid",         @(tg) renderTuning(Rt, tg, Layout="grid")
    "tuning overlay",      @(tg) renderTuning(Rt, tg, Layout="overlay")
    "heatmap psth",        @(tg) renderHeatmap(Rp, tg, Order="peak")
    "heatmap evoked",      @(tg) renderHeatmap(Rv, tg)
    "probe map",           @(tg) renderProbeMap(Rq, [], tg)
    "probe map (values)",  @(tg) renderProbeMap([5 NaN 3 1 0 2 7 4], probe, tg)
    "unit correlation",    @(tg) renderCorrMap(Rc, tg, Style=struct('SortDepth', false))
    "behavior points",     @(tg) renderBehavior(Rb, tg)
    "behavior line",       @(tg) renderBehavior(Rb, tg, Layout="line", XScale="linear")
    "behavior box",        @(tg) renderBehavior(Rb, tg, Layout="box")
    "behavior swarm",      @(tg) renderBehavior(Rb, tg, Layout="swarm")
    };
if exist('violinplot', 'file')   % MATLAB R2024b or later
    cases(end+1, :) = {"behavior violin", @(tg) renderBehavior(Rb, tg, Layout="violin")};
end
fig = figure('Visible', 'off');
ufig = uifigure('Visible', 'off');
closer = onCleanup(@() delete([fig ufig]));
for k = 1:size(cases, 1)
    okAll = true;
    msgs = "";
    for mode = ["axes" "uiaxes" "figure" "panel"]
        try
            switch mode
                case "axes",   clf(fig); tg = axes(fig); %#ok<LAXES>
                case "uiaxes", delete(ufig.Children); tg = uiaxes(ufig);
                case "figure", tg = fig;
                case "panel",  delete(ufig.Children); tg = uipanel(ufig);
            end
            h = cases{k, 2}(tg);
            axs = h.axes;
            ok = ~isempty(axs) && all(isgraphics(axs)) && ~isempty(axs(1).Children);
            if mode == "figure" || mode == "panel"; ok = ok && ~isempty(h.layout); end
            drawnow;
        catch ME
            ok = false;
            msgs = msgs + mode + ": " + ME.message + "  ";
        end
        okAll = okAll && ok;
    end
    check(okAll, cases{k, 1} + " draws into an axes, a uiaxes, a figure and a uipanel" + ternary(msgs == "", "", " (" + msgs + ")"));
end
spec = EphysAnalysisConfig.normalizePlot(struct('kind', "psth", 'layout', "grid", 'style', struct('MaxTiles', 2)));
check(plotPageCount(Rp, spec) == 2, 'three units at MaxTiles 2 make two pages');
h = renderPlot(Rp, spec, fig, Page=2);
check(isscalar(h.axes) && h.page == 2 && startsWith(h.title, "PSTH: ") && contains(h.title, "(200 epochs)") ...
    && contains(string(h.layout.Subtitle.String), "page 2 of 2") && contains(string(h.layout.Subtitle.String), "synthetic"), ...
    'renderPlot draws page 2 with the automatic title and a subtitle');
spec.title = "Custom";
h = renderPlot(Rp, spec, axes(figure('Visible', 'off')));
check(h.title == "Custom" && string(h.axes(1).Title.String) == "Custom", 'a plot title replaces the automatic one');
close(h.axes(1).Parent);
spec.title = "";
spec.style.ShowSEM = false;
h = renderPlot(Rp, spec, axes(figure('Visible', 'off')));
pa = findobj(h.axes(1), 'Type', 'patch');
check(spec.histStyle == "bar" && spec.fill && numel(pa) == 3 && all([pa.FaceAlpha] == 0.5) && numel(pa(1).XData) == 2 * numel(Rp.t) + 2, ...
    'a PSTH draws filled bars by default: a staircase patch per group, half-transparent where the 3 groups overlap');
close(h.axes(1).Parent);
spec.fill = false;
h = renderPlot(Rp, spec, axes(figure('Visible', 'off')));
ln = findobj(h.axes(1), 'Type', 'line');
check(isempty(findobj(h.axes(1), 'Type', 'patch')) && numel(ln) == 3 && all(arrayfun(@(l) numel(l.XData) == 2 * numel(Rp.t) + 3, ln)), ...
    'fill false: the bars'' outline, one staircase line per group (no patches)');
close(h.axes(1).Parent);
spec.histStyle = "line";
h = renderPlot(Rp, spec, axes(figure('Visible', 'off')));
ln = findobj(h.axes(1), 'Type', 'line');
check(isempty(findobj(h.axes(1), 'Type', 'patch')) && numel(ln) == 3 && all(arrayfun(@(l) numel(l.XData) == numel(Rp.t), ln)), ...
    'histStyle "line" unfilled draws one trace per group');
close(h.axes(1).Parent);
spec.fill = true; spec.fillAlpha = 0.3;
h = renderPlot(Rp, spec, axes(figure('Visible', 'off')));
pa = findall(h.axes(1), 'Type', 'patch');   % hidden from findobj, as the SEM bands
lg = h.axes(1).Legend;
check(numel(pa) == 3 && all([pa.FaceAlpha] == 0.3) && numel(findobj(h.axes(1), 'Type', 'line')) == 3 ...
    && ~isempty(lg) && all(arrayfun(@(p) isa(p, 'matlab.graphics.chart.primitive.Line'), lg.PlotChildren)), ...
    'a filled line: the area under it at fillAlpha 0.3, the line on top (and in the legend)');
close(h.axes(1).Parent);

fprintf('\n== 6b. stacked, normalized PSTHs ==\n');
G3d = G3; G3d.Depth = [0; 0.5; 1];
Rd = Rp; Rd.groups = G3d;
f6 = figure('Visible', 'off');
h = renderPSTH(Rd, f6, Stack=true, Style=struct('SortDepth', false, 'ShowSEM', false));
ax = h.axes(1);
pk = reshape(max(Rd.rate(:, 1, :), [], 1), [], 1);
stp = 1.1 * max(pk);
yyaxis(ax, 'right'); rt = ax.YTick; rl = string(ax.YTickLabel); ylR = ax.YLim;
yyaxis(ax, 'left');  lt = ax.YTick; ll = string(ax.YTickLabel); llab = string(h.layout.YLabel.String); ylL = ax.YLim;
[srt, o] = sort((0:2).' * stp + pk);
check(numel(h.axes) == 3 && all(abs(h.step - 1.1 * reshape(max(Rd.rate, [], [1 3]), 1, [])) < 1e-9) && abs(h.step(1) - stp) < 1e-9, ...
    'each unit''s row step is Spacing (1.1) x its tallest PSTH');
check(numel(ax.YAxis) == 2 && max(abs(lt - (0:2) * stp)) < 1e-9 && isequal(ll(:), ["0"; "0.5"; "1"]) && llab == "Depth  ·  Epoch", ...
    'left axis: a tick at each row''s baseline, first group at the bottom, labeled with its Depth value; the grid''s y label names Depth (then the rasters'' rows)');
check(max(abs(rt(:) - srt)) < 1e-9 && isequal(rl(:), compose("%.3g", pk(o))) && isequal(ylL, ylR), ...
    'right axis: a tick where each row peaks, labeled with its peak rate, on the same limits as the left');
check(isempty(ax.Legend) && contains(string(h.axes(2).YAxis(2).Label.String), "Peak (spikes/s)") ...
    && string(h.axes(1).YAxis(2).Label.String) == "", 'no legend; "Peak (spikes/s)" names the right axis of the last column');
check(all(strcmp(get(findall(ax, 'Type', 'line'), 'Marker'), 'none')), 'no markers from the yyaxis line-style cycle');
check(all(strcmp({h.rasterAxes.YDir}, 'normal')), 'the raster above a stack is flipped: first group at the bottom, as the rows');
pa = findobj(ax, 'Type', 'patch');
check(numel(pa) == 3 && all([pa.FaceAlpha] == 1), 'stacked rows are opaque by default');
yl0 = ylL;
h = renderPSTH(Rd, f6, Stack=true, Spacing=0.5, Style=struct('SortDepth', false, 'ShowSEM', false, 'YLim', [0 1]));
ax = h.axes(1);
check(abs(h.step(1) - 0.5 * max(pk)) < 1e-9 && max(abs(ax.YTick - (0:2) * 0.5 * max(pk))) < 1e-9 && ax.YLim(2) < yl0(2) ...
    && ax.YLim(2) > 1, 'Spacing 0.5 overlaps the rows; a stack ignores YLim');
h = renderPSTH(Rd, f6, Stack=true, Normalize="groupPeak", Style=struct('SortDepth', false, 'ShowSEM', false));
ax = h.axes(1);
yyaxis(ax, 'right'); rt = ax.YTick; rl = string(ax.YTickLabel); yyaxis(ax, 'left');
check(abs(h.step(1) - 1.1) < 1e-9 && max(abs(sort(rt(:)) - ((0:2).' * 1.1 + 1))) < 1e-9 && isequal(sort(rl(:)), sort(compose("%.3g", pk))), ...
    'groupPeak: every row peaks at 1 x its step unit; the right axis still gives each row''s peak rate');
h = renderPSTH(Rd, f6, Normalize="unitPeak", Stack=false, Style=struct('SortDepth', false, 'ShowSEM', false));
ax = h.axes(1);
yd = get(findobj(ax, 'Type', 'patch'), 'YData');
check(abs(max(cellfun(@max, yd)) - 1) < 1e-9 && startsWith(string(h.layout.YLabel.String), "Normalized (unit peak = 1)"), ...
    'unitPeak unstacked: the tallest group reaches 1, and the y label says so');
h = renderPSTH(Rd, f6, Normalize="allPeak", Stack=false, Style=struct('SortDepth', false, 'ShowSEM', false));
yd = arrayfun(@(a) max(cellfun(@max, get(findobj(a, 'Type', 'patch'), 'YData'))), h.axes);
check(abs(max(yd) - 1) < 1e-9 && all(yd <= 1 + 1e-9) && startsWith(string(h.layout.YLabel.String), "Normalized (overall peak = 1)"), ...
    'allPeak: the tallest PSTH of all units reaches 1, none above, and the y label says so');
h = renderPSTH(Rd, f6, Layout="overlay", Normalize="unitPeak", Stack=true, Style=struct('SortDepth', false, 'ShowSEM', false));
ax = h.axes(1);
m = reshape(mean(Rd.rate ./ max(Rd.rate, [], [1 3]), 2, 'omitnan'), [], 3);
yyaxis(ax, 'right'); rl = string(ax.YTickLabel); rlab = string(ax.YLabel.String); yyaxis(ax, 'left');
check(abs(h.step - 1.1 * max(m, [], 'all')) < 1e-9 && isequal(sort(rl(:)), sort(compose("%.3g", max(m, [], 1).'))) && rlab == "Peak (normalized)", ...
    'overlay + unitPeak: each unit is normalized before the mean; the right axis gives the normalized peaks');
R1 = spikePSTH({st}, epochs(t0(1:20), ones(20, 1)), Window=[-0.2 0.5], BinSec=0.02);
h = renderPSTH(R1, f6, Stack=true);
check(isscalar(h.axes(1).YAxis) && isnan(h.step), 'a single group is not stacked');
h = renderPSTH(Rd, f6, Style=struct('Colormap', "black"));
pa = findobj(h.axes(1), 'Type', 'patch', '-not', 'FaceAlpha', 1);
check(numel(pa) == 3 && all(arrayfun(@(p) isequal(p.FaceColor, [0 0 0]), pa)), 'Colormap "black" gives every group black');
delete(f6);
sp = EphysAnalysisConfig.normalizePlot(struct('kind', "psth", 'stack', true, 'normalize', "groupPeak"));
cap = plotCaption(sp, Rd);
check(contains(cap, "each PSTH normalized to its own peak") && contains(cap, "groups stacked"), "plotCaption: " + cap);
check(EphysAnalysisConfig.defaults("Plot").bins.SmoothSec == 0.01, 'PSTHs are smoothed with a 10 ms Gaussian by default');
cap = plotCaption(EphysAnalysisConfig.normalizePlot(struct('kind', "psth")), Rp);
check(startsWith(cap, "PSTH") && contains(cap, "bins 20 ms") && contains(cap, "3 sorted unit(s)"), "plotCaption: " + cap);
spec = EphysAnalysisConfig.normalizePlot(struct('kind', "corrmap"));
h = renderPlot(Rc, spec, fig);
check(numel(h.axes) == 3 && startsWith(h.title, "Unit correlation (Pearson, mean rate): Stim onset") ...
    && isequal(h.axes(1).CLim, [-1 1]) && isequal(h.axes(1).Colormap, blueWhiteRed(256)), ...
    'renderPlot draws a corrmap: a tile per group on [-1 1] in blueWhiteRed');
specZ = EphysAnalysisConfig.normalizePlot(struct('kind', "corrmap", 'fisherZ', true));
RcZ = unitCorrelation({s2, st, drv}, E3, Groups=G3, Meta=meta, FisherZ=true);
h = renderPlot(RcZ, specZ, fig);
check(isequal(h.axes(1).CLim, [-1 1] * max([1; abs(RcZ.z(isfinite(RcZ.z)))])) && contains(h.colorbar.Label.String, "Fisher z"), ...
    'a Fisher-z corrmap draws z on a scale symmetric about 0');
check(contains(plotCaption(specZ, RcZ), "Fisher z"), 'plotCaption names the Fisher z transform');
cap = plotCaption(spec, Rc);
check(contains(cap, "Pearson correlation of each epoch's mean rate") && ~contains(cap, "bins"), "plotCaption: " + cap);
check(isequal(shortUnitLabels(["su001_S-01_260918T1405"; "mua012_S-01_260918T1405"]), ["su001"; "mua012"]) ...
    && isequal(shortUnitLabels(["su001_S-01_A"; "su001_S-01_B"]), ["su001_S-01_A"; "su001_S-01_B"]) ...
    && isequal(shortUnitLabels(["A-000"; "A-001"]), ["A-000"; "A-001"]), ...
    'shortUnitLabels drops a shared recording suffix, and only a shared one');
long = ["su000"; "mua001"; "su002"] + "_SYNTH-01_260918T1405";
Rc2 = Rc; Rc2.labels = long;
h = renderCorrMap(Rc2, fig);
tick = @(v) string(v(:));
short = sort(["su000"; "mua001"; "su002"]);
check(isempty(h.axes(1).XTickLabel) && isequal(sort(tick(h.axes(1).YTickLabel)), short) ...
    && isempty(h.axes(2).YTickLabel) && isequal(sort(tick(h.axes(2).XTickLabel)), short) ...
    && ~isempty(h.axes(3).XTickLabel) && ~isempty(h.axes(3).YTickLabel), ...
    'a corrmap names the units, without the shared suffix, on the outer tiles only');
Rp2 = Rp; Rp2.labels = long;
h = renderPSTH(Rp2, fig, Layout="grid");
titles = arrayfun(@(ax) string(ax.Title.String), [h.axes h.rasterAxes]);
check(any(titles == "su000") && ~any(contains(titles, "SYNTH-01")), 'PSTH tiles are titled by the short unit label');

fprintf('\n== 7. unitCorrelation ==\n');
tc = (5:2:203).';
nC = numel(tc);
k = randi([0 10], nC, 1);
[uA, uB, uD, uF, uG, uC] = deal(zeros(0, 1));
for e = 1:nC
    a = tc(e) + linspace(0.01, 0.4, k(e)).';
    uA = [uA; a]; uB = [uB; a + 0.001]; %#ok<AGROW>
    uD = [uD; tc(e) + linspace(0.01, 0.4, 10 - k(e)).']; %#ok<AGROW>
    uF = [uF; tc(e) + linspace(0.01, 0.4, k(e) ^ 2).']; %#ok<AGROW>
    uG = [uG; tc(e) + 0.1025 + 0.002 * rand(k(e), 1)]; %#ok<AGROW>
    uC = [uC; tc(e) - 0.2 + 0.7 * rand(randi([0 10]), 1)]; %#ok<AGROW>
end
Ec = epochs(tc, ones(nC, 1));
C = unitCorrelation({uA, uB, uC, uD, uF}, Ec);
[r0, p0] = corrcoef(C.response);
check(C.kind == "corrmap" && isequal(size(C.r), [5 5]) && C.nEpochs == nC ...
    && max(abs(C.response(:, 1) - k / 0.7)) < 1e-9, 'mean metric: spikes in [tStart, tStop) over the window length');
check(max(abs(C.r(:) - r0(:))) < 1e-12 && abs(C.r(1, 2) - 1) < 1e-12 && abs(C.r(1, 4) + 1) < 1e-12 ...
    && abs(C.r(1, 3)) < 0.35 && C.r(1, 5) < 0.99, ...
    sprintf('Pearson matches corrcoef: same train 1, mirror -1, independent %.2f, squared %.3f', C.r(1, 3), C.r(1, 5)));
off = ~eye(5);
check(max(abs(C.p(off) - p0(off))) < 1e-9 && all(isnan(diag(C.p))), 'p values match corrcoef''s');
check(abs(C.meanR - mean(r0(off))) < 1e-12, 'meanR is the mean over the pairs');
Z = unitCorrelation({uA, uB, uC, uD, uF}, Ec, FisherZ=true);
rc = max(min(C.r, 1 - eps), -1 + eps);
check(Z.fisherZ && isequal(Z.r, C.r) && all(isnan(diag(Z.z))) && max(abs(Z.z(off) - atanh(rc(off)))) < 1e-12 ...
    && abs(Z.meanR - tanh(mean(atanh(rc(off))))) < 1e-12 && all(isfinite(Z.z(off))) && ~isfield(C, 'z') && ~C.fisherZ, ...
    'FisherZ: z = atanh r (r = +-1 kept finite), the mean taken in z and transformed back; r unchanged');
S = unitCorrelation({uA, uB, uC, uD, uF}, Ec, Type="spearman");
check(abs(S.r(1, 5) - 1) < 1e-12 && abs(S.r(1, 4) + 1) < 1e-12 && max(abs(S.r - corrcoef(ranks(S.response))), [], 'all') < 1e-12, ...
    'Spearman: a monotone transform correlates 1, and it is Pearson of the (tie-averaged) ranks');
P = unitCorrelation({uA, uG}, Ec, Metric="peak", BinSec=0.01);
check(max(abs(P.response(:, 2) - 100 * k)) < 1e-9 && max(abs(P.response(:, 1) - 100 * (k > 0))) < 1e-9 ...
    && abs(P.r(1, 2) - corr1(P.response)) < 1e-12, 'peak metric: the largest 10 ms bin (a burst of k spikes = 100 k/s)');
Ps = unitCorrelation({uG}, Ec, Metric="peak", BinSec=0.01, SmoothSec=0.01);
check(all(Ps.response(k > 0) < 100 * k(k > 0)) && all(Ps.response(k > 0) > 30 * k(k > 0)), 'smoothing spreads the burst: a lower peak');
Eb = Ec(1:4, :);
Eb.tStop = Eb.tStart + [0.035; 0.035; 0.7; 0.7];
Eb.duration = Eb.tStop - Eb.tStart;
sb = Eb.tStart + [0.032; 0.005; 0.5; 0.6];
Pb = unitCorrelation({sb}, Eb, Metric="peak", BinSec=0.01);
Mb = unitCorrelation({sb}, Eb);
check(max(abs(Pb.response.' - [0 100 100 100])) < 1e-9 && max(abs(Mb.response.' - 1 ./ Eb.duration.')) < 1e-9, ...
    'between windows: the peak skips a bin that runs past tStop; the mean divides by each window''s length');
B = unitCorrelation({uA, uC}, Ec, Baseline=[-0.2 0], BaselineMode="subtract");
bC = arrayfun(@(t) nnz(uC >= t - 0.2 & uC < t), tc) / 0.2;
check(max(abs(B.response(:, 2) - (C.response(:, 3) - bC))) < 1e-9 && B.units == "spikes/s - baseline", ...
    'baseline subtract: each epoch minus its own baseline rate');
g2 = 1 + (tc > 100);
Eg = epochs(tc, g2);
Rg = unitCorrelation({uA, uC, uD}, Eg);
r1 = corrcoef(C.response(g2 == 1, [1 3 4]));
r2 = corrcoef(C.response(g2 == 2, [1 3 4]));
check(isequal(size(Rg.r), [3 3 2]) && isequal(Rg.n, [nnz(g2 == 1); nnz(g2 == 2)]) ...
    && max(abs(Rg.r(:, :, 1) - r1), [], 'all') < 1e-12 && max(abs(Rg.r(:, :, 2) - r2), [], 'all') < 1e-12, ...
    'one matrix per group, over that group''s epochs');
Z = unitCorrelation({uA, tc + 0.1, uD}, Ec);
check(all(isnan(Z.r(2, :))) && all(isnan(Z.r(:, 2))) && Z.r(1, 1) == 1 && abs(Z.r(1, 3) + 1) < 1e-12, ...
    'a unit with the same count every epoch has NaN correlations');
Z = unitCorrelation({uA, uD}, epochs(tc(1:2), [1; 1]));
check(all(isnan(Z.r(:))) && isnan(Z.meanR) && Z.n == 2, 'fewer than 3 epochs: NaN');
check(strcmp(errorId(@() unitCorrelation({uA}, Eb, Metric="peak", BinSec=1)), 'unitCorrelation:BadWindow') ...
    && strcmp(errorId(@() unitCorrelation({uA}, Ec, BaselineMode="subtract")), 'unitCorrelation:BadBaseline'), ...
    'a window shorter than a bin, and subtract without a baseline window, are errors');

fprintf('\n== 8. binCounts and countBelow against brute force ==\n');
okC = true; okB = true;
for trial = 1:200
    s = sort(round(1000 * 20 * rand(randi([0 300]), 1)) / 1000);       % ms grid: ties with events
    t0 = sort(round(100 * 20 * rand(randi([0 30]), 1)) / 100);
    switch mod(trial, 3)
        case 0, edges = (-20:50) * 0.01;
        case 1, edges = (-4:10) / 8;
        case 2, edges = [-0.2 0];
    end
    if ~isempty(t0) && ~isempty(s)                                       % spikes exactly on edges and at the window ends
        e = randi(numel(t0), 20, 1);
        s = sort([s; t0(e) + edges(randi(numel(edges), 20, 1)).'; t0(e) + edges(end); t0(e) + edges(1)]);
    end
    x = [t0; s(1:min(5, end)); NaN; Inf];
    okB = okB && isequaln(countBelow(s, x), [arrayfun(@(v) nnz(s < v), x(1:end-2)); NaN; NaN]);
    if mod(trial, 4) == 0; s = s(randperm(numel(s))); end                % an unsorted train
    [c1, r1, e1] = binCounts(s, t0, edges);
    [c2, r2, e2] = binCountsRef(s, t0, edges);
    okC = okC && isequal(c1, c2) && isequal(r1, r2) && isequal(e1, e2);
end
check(okB, 'countBelow (binary search) = the count of spikes strictly below, with ties, NaN and Inf');
check(okC, 'binCounts (one vectorized pass) = counting per event and bin: counts, raster times and events, a spike on an edge in the bin that starts there');
fs = 30000;
r0 = 1 + 7919 * (1:40).';                 % event samples, 0.26 s apart
j = mod((1:40).', 9) - 4;                 % each event's spike: j x 10 ms (300 samples) from it
cE = binCounts((r0 + 300 * j - 1) / fs, (r0 - 1) / fs, (-5:10) * 0.01);
check(sum(cE, 'all') == 40 && all(arrayfun(@(e) cE(j(e) + 6, e) == 1, (1:40).')), ...
    'spikes and events on a 30 kHz sample grid: a spike a whole number of 10 ms bins from its event is in the bin starting there');

fprintf('\n== 8. Probe order, labels, measures, corner labels, spacing ==\n');
ord = @(d, s) probeOrder(meta, 3, EphysAnalysisConfig.normalizeSection("Style", struct('SortDepth', d, 'SortShank', s))).';
check(isequal(ord(true, false), [2 3 1]) && isequal(ord(false, true), [1 2 3]) && isequal(ord(true, true), [2 1 3]) ...
    && isequal(ord(false, false), [1 2 3]), 'probeOrder: depth (top first), shank, shank then depth, neither = as listed');
st0 = EphysAnalysisConfig.normalizeSection("Style", struct());
stL = EphysAnalysisConfig.normalizeSection("Style", struct('LabelDepth', true, 'LabelShank', true));
check(isequal(siteLabels(["u1"; "u2"; "u3"], meta, st0), ["u1"; "u2"; "u3"]) ...
    && isequal(siteLabels(["u1"; "u2"; "u3"], meta, stL), ["u1 (sh0, 0 µm)"; "u2 (sh0, 100 µm)"; "u3 (sh1, 50 µm)"]) ...
    && isequal(siteLabels(["u1"; "u2"], [], stL), ["u1"; "u2"]), 'siteLabels appends the shank and the depth, only when asked');
fig8 = figure('Visible', 'off');
h = renderRates(Rr, fig8, Style=struct('SortDepth', false, 'SortShank', true, 'LabelShank', true));
check(isequal(string(h.axes.XTickLabel(:)), ["u1 (sh0)"; "u2 (sh0)"; "u3 (sh1)"]), 'rates: units by shank, labeled with it');
h = renderRates(Rr, fig8);
check(isequal(string(h.axes.XTickLabel(:)), ["u2"; "u3"; "u1"]), 'rates: top of the probe first by default');
h = renderPSTH(Rp, fig8, Layout="grid", WithRaster=false, Style=struct('SortDepth', true, 'LabelDepth', true));
check(isequal(arrayfun(@(a) string(a.Title.String), h.axes), ["u2 (100 µm)" "u3 (50 µm)" "u1 (0 µm)"]), 'PSTH tiles follow the depth order, titled with the depth');
h = renderHeatmap(Rp, fig8, Style=struct('SortShank', true, 'SortDepth', true));
check(isequal(string(h.axes(1).YTickLabel(:)), ["u2"; "u1"; "u3"]), 'heatmap rows: shank, then depth');
h = renderCorrMap(Rc, fig8, Style=struct('SortDepth', false));
check(isequal(string(h.axes(3).XTickLabel(:)), ["u1"; "u2"; "u3"]), 'unit correlation without sorting: as listed');
% measures: bin 1 of epochs at 1..4 s holds 2, 1, 0, 0 spikes; bin 5 holds one (epoch 4)
Em = epochs([1; 2; 3; 4], ones(4, 1));
trainP = [1.05; 1.06; 2.05; 4.42];
P2 = spikePSTH({trainP}, Em, Window=[0 0.5], BinSec=0.1, Measure="probability");
C2 = spikePSTH({trainP}, Em, Window=[0 0.5], BinSec=0.1, Measure="count");
R2 = spikePSTH({trainP}, Em, Window=[0 0.5], BinSec=0.1);
check(abs(P2.rate(1) - 0.5) < 1e-12 && abs(C2.rate(1) - 0.75) < 1e-12 && abs(R2.rate(1) - 7.5) < 1e-9 && abs(P2.rate(5) - 0.25) < 1e-12, ...
    'a bin holds P(spike) = 2/4 epochs, 0.75 spikes per epoch, or 7.5 spikes/s for the same spikes');
check(P2.units == "P(spike)/bin" && C2.units == "spikes/bin" && R2.units == "spikes/s" && P2.measure == "probability", 'spikePSTH measures carry their units');
Pb = spikePSTH({trainP}, Em, Window=[0 0.5], BinSec=0.1, Measure="probability", Baseline=[-0.2 0], BaselineMode="subtract");
check(Pb.units == "P(spike)/bin - baseline" && Pb.baselineRate(1) == 0 && abs(Pb.rate(1) - 0.5) < 1e-12, 'a probability baseline is measured in the same bins');
Fp = firingRate({trainP}, Em, Measure="probability");
Fc = firingRate({trainP}, Em, Measure="count");
Fr = firingRate({trainP}, Em);
check(isequal(Fp.rate(:, 1).', [1 1 0 1]) && isequal(Fc.rate(:, 1).', [2 1 0 1]) && Fp.meanRate == 0.75 ...
    && Fp.units == "P(spike)/window" && Fc.units == "spikes/window" && Fr.units == "spikes/s" && Fr.measure == "rate", ...
    'firingRate: probability = share of epochs with a spike, count = spikes per window');
% a grid's labels: once, on its tiled layout; and spacing
unlabeled = @(axs) all(arrayfun(@(a) string(a.XLabel.String) == "" && string(a.YAxis(1).Label.String) == "", axs));
h = renderPSTH(Rp, fig8, Layout="grid", WithRaster=false, Style=struct('MaxTiles', 6));
check(string(h.layout.XLabel.String) == "Time (s)" && string(h.layout.YLabel.String) == Rp.units && unlabeled(h.axes) ...
    && all(arrayfun(@(a) string(a.Title.String) ~= "", h.axes)), 'a PSTH grid: one x and one y label, the layout''s; the tiles keep only their titles');
h = renderPSTH(Rp, fig8, Layout="grid");
check(string(h.layout.YLabel.String) == Rp.units + "  ·  Epoch" && unlabeled([h.axes h.rasterAxes]), ...
    'with rasters: the layout''s y label names the rates, then the rasters'' rows; no tile is labeled');
amp = "Amplitude (" + replace(string(Rv.units), "uV", "µV") + ")";
gridKinds = {
    "raster",           @(tg) renderRaster(Rp, tg),                    "Time (s)", "Epoch"
    "heatmap",          @(tg) renderHeatmap(Rp, tg),                   "Time (s)", "Units"
    "unit correlation", @(tg) renderCorrMap(Rc, tg),                   "Units",    "Units"
    "tuning grid",      @(tg) renderTuning(Rt, tg),                    Rt.param,   Rt.units
    "evoked butterfly", @(tg) renderEvoked(Rv, tg, Layout="butterfly"), "Time (s)", amp
    "evoked grid",      @(tg) renderEvoked(Rv, tg, Layout="grid"),      "Time (s)", amp};
for k = 1:size(gridKinds, 1)
    hk = gridKinds{k, 2}(fig8);
    check(string(hk.layout.XLabel.String) == gridKinds{k, 3} && string(hk.layout.YLabel.String) == gridKinds{k, 4} && unlabeled(hk.axes), ...
        gridKinds{k, 1} + ": the x and y labels are the layout's, no tile's");
end
ax9 = axes(figure('Visible', 'off'));
h = renderPSTH(Rp, ax9, Layout="grid");
check(isempty(h.layout) && string(ax9.XLabel.String) == "Time (s)" && string(ax9.YLabel.String) == Rp.units, ...
    'drawn into one axes: the axes takes the labels');
delete(ancestor(ax9, 'figure'));
h = renderPSTH(Rp, fig8, Layout="grid", Style=struct('TileSpacing', "loose"));
check(string(h.layout.TileSpacing) == "loose" && string(h.layout.Padding) == "loose", 'TileSpacing loose reaches the tiled layout');
h = renderPSTH(Rp, fig8, Layout="grid", Style=struct('TileSpacing', "none"));
check(string(h.layout.TileSpacing) == "none" && string(h.layout.Padding) == "tight", 'TileSpacing none: tight padding');
% legend place: outside the grid, orientation, box
h = renderPSTH(Rp, fig8, Layout="grid", Style=struct('LegendLocation', "east"));
lg = findall(fig8, 'Type', 'legend');
host = findall(fig8, 'Type', 'axes', 'Tag', 'legendHost');
T = PlotAesthetics.components(h.layout);
check(isscalar(lg) && isscalar(host) && lg.Parent == h.layout && string(lg.Layout.Tile) == "east" ...
    && string(lg.Orientation) == "vertical" && string(lg.Box) == "off" && numel(lg.String) == height(Rp.groups) && isempty(h.axes(1).Legend), ...
    'a PSTH grid with rasters: the legend east of the whole grid (a hidden host axes), vertical, no box');
check(nnz(T.Role == "legend") == 1 && T.Tile(T.Role == "legend") == 0 && nnz(ismember(T.Role, ["axes" "rasterAxes"])) == numel(h.axes) + numel(h.rasterAxes), ...
    'the aesthetics editor lists that legend as the plot''s, and the host axes is no tile');
renderPSTH(Rp, fig8, Layout="grid", Style=struct('LegendLocation', "north", 'LegendBox', true));
lg = findall(fig8, 'Type', 'legend');
check(string(lg.Layout.Tile) == "north" && string(lg.Orientation) == "horizontal" && string(lg.Box) == "on", ...
    'north of the grid: horizontal by default; LegendBox draws its box');
renderPSTH(Rp, fig8, Layout="grid", Style=struct('LegendLocation', "west", 'LegendOrientation', "horizontal"));
lg = findall(fig8, 'Type', 'legend');
check(string(lg.Layout.Tile) == "west" && string(lg.Orientation) == "horizontal", 'LegendOrientation horizontal on the west side');
h = renderPSTH(Rp, fig8, Layout="grid", WithRaster=false, Style=struct('LegendLocation', "south", 'LegendOrientation', "vertical"));
lg = findall(fig8, 'Type', 'legend');
check(isscalar(lg) && isempty(findall(fig8, 'Type', 'axes', 'Tag', 'legendHost')) && lg.Parent == h.layout ...
    && string(lg.Layout.Tile) == "south" && string(lg.Orientation) == "vertical" && ~isempty(h.axes(1).Legend), ...
    'tiles straight in the layout: the legend belongs to the first tile, south of the grid, vertical when asked');
renderPSTH(Rp, fig8, Layout="grid", Style=struct('LegendLocation', "inside"));
lg = findall(fig8, 'Type', 'legend');
check(isscalar(lg) && string(lg.Location) == "best" && isempty(findall(fig8, 'Type', 'axes', 'Tag', 'legendHost')), 'inside: in the first tile');
h = renderPSTH(Rp, fig8, Layout="grid");
lg = findall(fig8, 'Type', 'legend');
check(isscalar(lg) && lg.Parent == h.layout && string(lg.Layout.Tile) == "east" && string(lg.Orientation) == "vertical", ...
    'auto in a grid: east of the whole grid, as its labels');
Rts = tuningCurve(Rr.rate, mod((1:nE).', 4), Series=mod((1:nE).', 2), Param="Depth", SeriesParam="Kind", Meta=meta);
for f = {@(tg) renderRaster(Rp, tg), @(tg) renderTuning(Rts, tg), @(tg) renderEvoked(Rv, tg, Layout="grid")}
    h = f{1}(fig8);
    lg = findall(fig8, 'Type', 'legend');
    check(isscalar(lg) && lg.Parent == h.layout && string(lg.Layout.Tile) == "east", ...
        "auto, " + func2str(f{1}) + ": the grid's legend east of it");
end
renderPSTH(Rp, fig8, Layout="overlay");
lg = findall(fig8, 'Type', 'legend');
check(isscalar(lg) && string(lg.Location) == "best", 'auto in a single plot: its own place (an overlay''s best)');
fig9 = figure('Visible', 'off');
ax9 = axes(fig9);
renderPSTH(Rp, ax9, Style=struct('LegendLocation', "east"));
check(string(ax9.Legend.Location) == "eastoutside", 'one axes: the legend goes outside it, on that side');
delete(fig9);
delete(fig8);

fprintf('\n== raster sort ==\n');
% one spike per epoch at t0 + 0.01 k names its epoch k; within each group
% "level" and the stop latency put the epochs in the order [2 3 1] and [6 5 4]
% (a missing level sorts last)
t0 = (10:10:60).';
Es = epochs(t0, [1 1 1 2 2 2]);
Es.t1 = t0 + [0.3 0.1 0.2 0.4 0.2 0.1].';
Es.level = [3 1 2 NaN 5 4].';
Rs = spikePSTH({t0 + 0.01 * (1:6).'}, Es, Window=[-0.2 0.5], BinSec=0.05);
Rs.epochs = Es;
fig9 = figure('Visible', 'off');
rowsOf = @(h) rasterRows(h.axes(1));
check(isequal(rowsOf(renderRaster(Rs, fig9)), 1:6), 'raster: by default the epochs are rows in time order');
check(isequal(rowsOf(renderRaster(Rs, fig9, SortBy="level")), [3 1 2 6 5 4]), ...
    'raster SortBy a column of the epochs: sorted within each group, a missing value last');
check(isequal(rowsOf(renderRaster(Rs, fig9, SortBy="stop")), [3 1 2 6 5 4]), 'raster SortBy "stop": by the stop event''s latency');
h = renderPSTH(Rs, fig9, SortBy="level");
check(isequal(rasterRows(h.rasterAxes(1)), [3 1 2 6 5 4]) && endsWith(string(h.layout.YLabel.String), "Epoch (by level)"), ...
    'the raster above a PSTH takes SortBy, and the grid''s y label names it');
h = renderPlot(Rs, struct('kind', "raster", 'rasterSort', "level"), fig9);
check(isequal(rasterRows(h.axes(1)), [3 1 2 6 5 4]) && contains(plotCaption(struct('kind', "raster", 'rasterSort', "level"), Rs), ...
    "sorted by level"), 'renderPlot sorts by the spec''s rasterSort; the caption says so');
check(strcmp(errorId(@() renderRaster(Rs, fig9, SortBy="nope")), 'renderRaster:NoSortColumn'), ...
    'SortBy a column the epochs lack: renderRaster:NoSortColumn');
% each epoch's latency to another event (eventLatency); epoch 2 has none
Re = Rs;
Re.rasterSortEvent = struct('label', "Platform offset", 't', [0.25 NaN 0.05 0.3 0.1 0.2].');
h = renderRaster(Re, fig9, SortBy="event");
check(isequal(rasterRows(h.axes(1)), [2 3 1 6 4 5]) && string(h.layout.YLabel.String) == "Epoch (by Platform offset latency)", ...
    'raster SortBy "event": by each epoch''s latency to R.rasterSortEvent within each group, an epoch without one last; the y label names the event');
check(isequal(rowsOf(renderRaster(Re, fig9, SortBy="event", SortOrder="descending")), [1 3 2 4 6 5]), ...
    'SortBy "event" descending: the longest latency first, an epoch without the event still last');
h = renderPlot(Re, struct('kind', "raster", 'rasterSort', "event"), fig9);
cap = plotCaption(struct('kind', "raster", 'rasterSort', "event"), Re);
check(isequal(rasterRows(h.axes(1)), [2 3 1 6 4 5]) && contains(cap, "sorted by Platform offset latency within each group") ...
    && contains(cap, "1 epoch(s) with no Platform offset after their event sorted last"), ...
    "renderPlot sorts by the event's latency; the caption names it and counts the epoch without one: " + cap);
check(strcmp(errorId(@() renderRaster(Rs, fig9, SortBy="event")), 'renderRaster:NoSortEvent'), ...
    'SortBy "event" without R.rasterSortEvent: renderRaster:NoSortEvent');
check(isequal(rowsOf(renderRaster(Rs, fig9, SortBy="level", SortOrder="descending")), [1 3 2 6 4 5]), ...
    'SortOrder "descending": the largest first within each group, a missing value still last');
check(isequal(rowsOf(renderRaster(Rs, fig9, SortOrder="descending")), [3 2 1 6 5 4]), ...
    'no sort key, descending: each group in reverse time order');
h = renderRaster(Rs, fig9, SortBy="stop", ByGroup=false);
bands = findall(h.axes(1), 'Tag', 'rasterBand');
bands = bands(arrayfun(@(b) numel(b.XData) > 1, bands));   % not the legend's stand-ins
nFaces = arrayfun(@(b) size(b.XData, 2), bands);
check(isequal(rasterRows(h.axes(1)), [5 1 3 6 4 2]) && numel(bands) == 2 && isequal(sort(nFaces(:)).', [3 3]) ...
    && contains(string(h.layout.YLabel.String), "groups mixed"), ...
    'ByGroup false: every epoch sorted by stop latency as one block (ties in time order), each row on its group''s band');
check(contains(plotCaption(struct('kind', "raster", 'rasterSort', "stop", 'rasterSortOrder', "descending", 'rasterByGroup', false), Rs), ...
    "sorted by stop latency, descending across groups"), 'the caption says how the raster is sorted');
Rm = Rs;
Rm.rasterEvents = struct('line', "Beam", 'edge', "onset", 'label', "Beam onset", 'epoch', [1; 1; 4], 't', [0.1; 0.3; -0.1]);
h = renderRaster(Rm, fig9, SortBy="level", EventMarks=struct('marker', "^", 'size', 7, 'color', "#ff00ff"));
mk = findall(h.axes(1), 'Tag', 'rasterEvent', 'HandleVisibility', 'off');
lg = h.axes(1).Legend;
check(isscalar(mk) && isequal(mk.XData(:).', [0.1 0.3 -0.1]) && isequal(mk.YData(:).', [3 3 6]) && string(mk.Marker) == "^" ...
    && mk.MarkerSize == 7 && isequal(mk.Color, [1 0 1]) && getappdata(mk, 'PlotGroup') == "Beam onset" ...
    && ~isempty(lg) && any(string(lg.String) == "Beam onset"), ...
    'event marks: one per event on its epoch''s row (two in epoch 1), in the look asked for, named and in the legend');
h = renderPlot(Rm, struct('kind', "raster", 'aesthetics', struct('role', "rasterEvent", 'group', "Beam onset", ...
    'property', "MarkerSize", 'value', 11)), fig9);
mk = findall(h.axes(1), 'Tag', 'rasterEvent', 'HandleVisibility', 'off');
check(isscalar(mk) && mk.MarkerSize == 11 && string(mk.Marker) == "diamond" && contains(plotCaption(struct('kind', "raster"), Rm), ...
    "raster marks: Beam onset"), 'a plot''s aesthetics rule restyles the marks; the default marker is a diamond; the caption lists them');
delete(fig9);

fprintf('\n== behavior values ==\n');
yv = [300 NaN 250 410 520 NaN 180 200].';    % ms; NaN: no response
xv = [0.25 0.25 0.5 0.5 1 1 0.25 1].';
sv = ["A" "A" "B" "B" "A" "B" "B" "A"].';
B = behaviorValues(yv, xv, Param="Depth", YName="RespLatency", YUnits="ms");
check(isequal(B.x, [0.25; 0.5; 1]) && isequal(B.n, [2; 2; 2]) && max(abs(B.mean - [240; 330; 360])) < 1e-12 ...
    && abs(B.sem(1) - std([300 180]) / sqrt(2)) < 1e-12 && isequal(B.median, B.mean) ...
    && B.nMissing == 2 && isequal(B.values.epoch, [1 3 4 5 7 8].') && isequal(B.values.y, yv([1 3 4 5 7 8])) ...
    && B.groups.label == "all" && B.units == "ms", ...
    'behaviorValues: each x value''s mean, SEM, median and count; every value kept; the NaN values left out and counted');
Bs = behaviorValues(yv, xv, Series=sv, Param="Depth", SeriesParam="Group", YName="RespLatency");
check(isequal(Bs.n, [1 1; 0 2; 2 0]) && isequaln(Bs.mean, [300 180; NaN 330; 360 NaN]) ...
    && isequal(Bs.series, ["Group = A"; "Group = B"]) && isequal(Bs.groups.n, [3; 3]), ...
    'a series parameter: one series per value, NaN where a series has no value at an x value');
check(strcmp(errorId(@() behaviorValues(NaN(3, 1), [1; 2; 3])), 'behaviorValues:NoValues') ...
    && strcmp(errorId(@() behaviorValues(["a"; "b"], [1; 2])), 'behaviorValues:NotNumeric') ...
    && strcmp(errorId(@() behaviorValues([1; 2], [1; 2; 3])), 'behaviorValues:Size'), ...
    'no value left, text values, sizes that differ: behaviorValues:NoValues / NotNumeric / Size');
figB = figure('Visible', 'off');
h = renderBehavior(Bs, figB, Jitter=false);
pts = findall(h.axes, 'Tag', 'points');
ptsA = pts(arrayfun(@(p) getappdata(p, 'PlotGroup') == "Group = A", pts));
check(numel(pts) == 2 && isequal(sort(ptsA.XData(:)).', [0.8 2.8 2.8]) && isequal(sort(ptsA.YData(:)).', [200 300 520]) ...
    && isequal(string(h.axes.XTickLabel(:)).', ["0.25" "0.5" "1"]) && string(h.axes.XLabel.String) == "Depth" ...
    && string(h.axes.YLabel.String) == "RespLatency" && isequal(string(h.axes.Legend.String), ["Group = A" "Group = B"]), ...
    'points, no jitter: each value on its x value, the series side by side; the x values labeled, a legend of the series');
h = renderBehavior(Bs, figB);
pts = findall(h.axes, 'Tag', 'points');
ptsA = pts(arrayfun(@(p) getappdata(p, 'PlotGroup') == "Group = A", pts));
check(~isequal(sort(ptsA.XData(:)).', [0.8 2.8 2.8]) && all(abs(sort(ptsA.XData(:)).' - [0.8 2.8 2.8]) <= 0.12 + 1e-12) ...
    && numel(findall(h.axes, 'Tag', 'behaviorMean')) == 2, 'points: jittered by default, at most 0.3 of the series'' slot (0.4) either way; each series'' mean marked');
h = renderBehavior(B, figB, Layout="line", XScale="linear");
mn = findall(h.axes, 'Tag', 'behaviorMean');
check(isscalar(mn) && isequal(mn.XData(:).', [0.25 0.5 1]) && isequal(mn.YData(:).', [240 330 360]) ...
    && string(h.axes.YLabel.String) == "RespLatency (ms)", 'line, linear x: the means joined at their x values');
h = renderBehavior(Bs, figB, Layout="box");
bx = findall(h.axes, 'Tag', 'box');
check(numel(bx) == 2 && all(arrayfun(@(b) isa(b, 'matlab.graphics.chart.primitive.BoxChart'), bx)), 'box: a boxchart per series');
h = renderBehavior(Bs, figB, Layout="swarm");
sw = findall(h.axes, 'Tag', 'swarm');
check(numel(sw) == 2 && all(arrayfun(@(b) isa(b, 'matlab.graphics.chart.primitive.Scatter'), sw)) ...
    && sum(arrayfun(@(b) numel(b.YData), sw)) == 6, 'swarm: a swarmchart per series, every value');
h = renderPlot(Bs, struct('kind', "behavior", 'param', "Depth", 'yParam', "RespLatency"), figB);
check(h.title == "Behavior: RespLatency by Depth (6 epochs)" ...
    && contains(plotCaption(struct('kind', "behavior", 'param', "Depth", 'yParam', "RespLatency"), Bs), ...
    "one series per Group (n = 3, 3 epochs); 2 epoch(s) without a value of RespLatency or Depth left out"), ...
    'renderPlot draws a behavior result (points by default) with its title; the caption counts what was left out');
delete(figB);

fprintf('\n== unit waveform boxes ==\n');
nUw = size(Rp.rate, 2);
tms = linspace(-0.6, 1.4, 61).';
shape = -exp(-(tms / 0.15).^2) + 0.4 * exp(-((tms - 0.5) / 0.3).^2);
Ww = struct('timeMs', {repmat({tms}, nUw, 1)}, 'mean', {cell(nUw, 1)}, 'spikes', {cell(nUw, 1)}, ...
    'from', repmat("spikes", nUw, 1), 'units', repmat("uV", nUw, 1), 'note', "", 'maxSpikes', 12);
for u = 1:nUw
    Ww.spikes{u} = 50 * u * shape + 5 * randn(61, 12);
    Ww.mean{u} = mean(Ww.spikes{u}, 2);
end
Rpw = Rp; Rpw.waveforms = Ww;
fig10 = figure('Visible', 'off');
part = @(ax, tag) findall(ax, 'Tag', tag);   % the parts are hidden handles (kept out of legends)
mid = @(lim) mean(lim);
h0 = renderPSTH(Rpw, fig10, WithRaster=false);
lims0 = [vertcat(h0.axes.XLim) vertcat(h0.axes.YLim)];
check(isempty(findall(fig10, '-regexp', 'Tag', '^wave')), 'Waveform off (the default): no box');
h = renderPSTH(Rpw, fig10, WithRaster=false, Waveform=struct('mode', "both"));
ok = isequal([vertcat(h.axes.XLim) vertcat(h.axes.YLim)], lims0);
for ax = h.axes
    b = part(ax, "waveBox"); s = part(ax, "waveSpikes"); m = part(ax, "waveMean");
    ok = ok && isscalar(b) && isscalar(s) && isscalar(m) && isscalar(part(ax, "waveLabel")) ...
        && min(b.XData) > mid(ax.XLim) && min(b.YData) > mid(ax.YLim) && nnz(isnan(s.YData)) == 12 ...
        && min(m.YData) >= min(b.YData) && max(m.YData) <= max(b.YData) && string(b.HandleVisibility) == "off";
end
check(ok, 'mode "both": in each tile a box at the top right (northeast) holding 12 spikes and their mean; the limits stay');
h = renderPSTH(Rpw, fig10, WithRaster=false, Waveform=struct('mode', "mean", 'location', "southwest", 'scale', 2));
b = part(h.axes(1), "waveBox");
xl = h.axes(1).XLim; yl = h.axes(1).YLim;
check(abs(min(b.XData) - (xl(1) + 0.03 * diff(xl))) < 1e-9 && abs(min(b.YData) - (yl(1) + 0.03 * diff(yl))) < 1e-9 ...
    && abs(max(b.XData) - min(b.XData) - 2 / 3 * diff(xl)) < 1e-9 && isempty(part(h.axes(1), "waveSpikes")), ...
    'southwest at scale 2: the box sits at the bottom left, two thirds of the tile wide; mode "mean" draws no spikes');
h = renderPSTH(Rpw, fig10, WithRaster=false, Waveform=struct('mode', "subsample", 'box', false));
check(isempty(findall(fig10, 'Tag', 'waveBox')) && isempty(findall(fig10, 'Tag', 'waveMean')) ...
    && numel(findall(fig10, 'Tag', 'waveSpikes')) == numel(h.axes), 'box off: the spikes alone, no box');
h = renderRaster(Rpw, fig10, Waveform=struct('mode', "mean", 'location', "southeast"));
ax = h.axes(1); b = part(ax, "waveBox");
check(string(ax.YDir) == "reverse" && min(b.YData) > mid(ax.YLim) && min(b.XData) > mid(ax.XLim), ...
    'a raster (y reversed): southeast is still the bottom right as seen');
renderPSTH(Rpw, fig10, Layout="overlay", Waveform=struct('mode', "both"));
check(isempty(findall(fig10, '-regexp', 'Tag', '^wave')), 'an overlay of units draws no unit''s waveform');
Rpw.waveforms.from(:) = "template";
Rpw.waveforms.spikes(:) = {[]};
h = renderPSTH(Rpw, fig10, WithRaster=false, Waveform=struct('mode', "subsample"));
lb = part(h.axes(1), "waveLabel");
check(isscalar(part(h.axes(1), "waveMean")) && isempty(part(h.axes(1), "waveSpikes")) && endsWith(lb.String, "(template)"), ...
    'a template is drawn as the mean whatever the mode, and its label says so');
delete(fig10);

fprintf('\n== waveforms plot ==\n');
probeW = struct('chanMap', (0:5).', 'xc', [0 0 0 200 200 200].', 'yc', [0 50 100 0 50 100].', 'kcoords', [0 0 0 1 1 1].');
Rw = struct('kind', "waveforms", 'meta', meta, 'labels', meta.label, 'n', 3, 'probe', probeW, 'waveforms', Ww, ...
    'groups', table(1, "all", [0.15 0.15 0.15], 3, 'VariableNames', {'index', 'label', 'color', 'n'}));
fig11 = figure('Visible', 'off');
part = @(ax, tag) findall(ax, 'Tag', tag);
wspec = @(varargin) struct('kind', "waveforms", varargin{:});
h = renderPlot(Rw, wspec('waveform', struct('mode', "both")), fig11);
ok = numel(h.axes) == 3;
for ax = h.axes
    ok = ok && isscalar(part(ax, "waveMean")) && isscalar(part(ax, "waveSpikes")) && nnz(isnan(part(ax, "waveSpikes").YData)) == 12 ...
        && isscalar(part(ax, "waveZero")) && isequal(ax.XLim, [min(tms) max(tms)]);
end
check(ok && h.title == "Unit waveforms (3 units)" && isscalar(part(h.axes(1), "waveLabel")), ...
    'grid: a tile per unit, its 12 spikes and mean on the spike-time axis (ms), the spike''s time marked, a label');
check(isequal(arrayfun(@(a) string(a.Title.String), h.axes), ["u2" "u3" "u1"]), 'the tiles go top of the probe first, titled by unit');
yl = vertcat(h.axes.YLim);
check(size(unique(yl, 'rows'), 1) == 3, 'amplitude "unit": every tile has the limits of its own waveform');
h = renderPlot(Rw, wspec('waveform', struct('mode', "mean", 'ampScale', "common")), fig11);
yl = vertcat(h.axes.YLim);
check(size(unique(yl, 'rows'), 1) == 1 && all(arrayfun(@(a) isempty(part(a, "waveSpikes")), h.axes)), ...
    'amplitude "common", mode "mean": one amplitude axis for every tile, no spikes');
h = renderPlot(Rw, wspec('style', struct('MaxTiles', 2)), fig11);
check(plotPageCount(Rw, wspec('style', struct('MaxTiles', 2))) == 2 && plotPageCount(Rw, wspec('layout', "probe")) == 1, ...
    'MaxTiles pages the grid; the probe layout is one page');
cap = plotCaption(wspec('waveform', struct('mode', "both")), Rw);
check(contains(cap, "each unit's mean waveform and up to 12 of its spikes on its peak channel, one tile per unit, each on its own amplitude scale") ...
    && contains(cap, "3 sorted unit(s)"), 'the caption says what the tiles show and how they are scaled');

h = renderPlot(Rw, wspec('layout', "probe", 'waveform', struct('mode', "both")), fig11);
ax = h.axes;
mu = part(ax, "waveMean"); sp = part(ax, "waveSpikes"); sites = part(ax, "waveSites");
gh = 30;   % the probe is 100 um tall: a twelfth is below the 30 um floor
mx = reshape(mu.XData, [], 3); my = reshape(mu.YData, [], 3);   % a unit per column, a NaN row each
ok = isscalar(mu) && isscalar(sp) && isscalar(sites) && nnz(isnan(mu.XData)) == 3 && nnz(isnan(sp.YData)) == 36 && numel(sites.XData) == 6;
ok = ok && all(abs((min(mx) + max(mx)) / 2 - [0 8 200]) < 1e-9);          % centerd on x (the shanks are far enough apart)
ok = ok && all(all(abs(my(1:end-1, :) - meta.y.') <= gh / 2 + 1e-9));
check(ok && string(ax.XLabel.String) == "x (µm)" && isempty(part(ax, "waveName")) && isempty(part(ax, "waveScale")), ...
    'probe: one panel; every unit''s spikes and mean as a glyph at its position (within 30 um of its y), the probe''s sites behind');
h = renderPlot(Rw, wspec('layout', "probe", 'waveform', struct('mode', "mean", 'scale', 2)), fig11);
my = reshape(part(h.axes, "waveMean").YData, [], 3);
check(all(abs((max(my) - min(my)) - 2 * gh) < 1e-9), 'scale 2 doubles the glyphs; "unit" scale fills each glyph''s height');
h = renderPlot(Rw, wspec('layout', "probe", 'waveform', struct('mode', "mean", 'ampScale', "common")), fig11);
my = reshape(part(h.axes, "waveMean").YData, [], 3);
hgt = max(my) - min(my);
check(abs(hgt(3) - gh) < 1e-9 && abs(hgt(1) / hgt(3) - 1 / 3) < 0.1 && numel(part(h.axes, "waveScale")) == 2, ...
    '"common": the largest unit fills the height, the others in proportion (a third), and a scale bar says how much');
h = renderPlot(Rw, wspec('layout', "probe", 'waveform', struct('mode', "both", 'showSites', false, 'showNames', true, 'showPP', false)), fig11);
check(isempty(part(h.axes, "waveSites")) && numel(part(h.axes, "waveName")) == 3, 'sites off, unit names on');
Rw2 = Rw; Rw2.meta.x(2) = NaN;
h = renderPlot(Rw2, wspec('layout', "probe"), fig11);
lb = part(h.axes, "waveLabel");
check(nnz(isnan(part(h.axes, "waveMean").XData)) == 2 && isscalar(lb) && contains(string(lb.String), "1 unit(s) without a probe position"), ...
    'a unit without a position is left out, and the panel says so');
Rw3 = Rw; Rw3.waveforms.from(:) = "template"; Rw3.waveforms.spikes(:) = {[]};
h = renderPlot(Rw3, wspec('waveform', struct('mode', "subsample")), fig11);
check(all(arrayfun(@(a) isscalar(part(a, "waveMean")) && isempty(part(a, "waveSpikes")) && endsWith(part(a, "waveLabel").String, "(template)"), h.axes)), ...
    'templates are drawn as the mean whatever the mode, and say so');
delete(fig11);
cfgw = EphysAnalysisConfig().addPlot("waveforms");
iss = cfgw.validate(CheckPaths=false);
cfgw.Plots(1).waveform.mode = "off";
iss2 = cfgw.validate(CheckPaths=false);
bad = iss2(iss2.Section == "Plots" & iss2.Severity == "error", :);
check(cfgw.Plots(1).source == "units" && cfgw.Plots(1).layout == "" && ~any(iss.Section == "Plots") ...
    && height(bad) == 1 && endsWith(bad.Field, ".waveform.mode"), ...
    'a new waveforms plot is valid and shows both; mode "off" is an error for it');

fprintf('\n== mean aux signal ==\n');
% three aux channels at offsets (1, 2, 2) -- magnitude 3 -- on the raster-sort epochs (t0 10:10:60 s, groups 1 1 1 2 2 2);
% in the epochs of group 2 channel 1 steps to 4 for 100 ms from the event's own sample
fsA = 1000;
Ya = repmat(single([1 2 2]), 70000, 1);
rowA = round(Es.t0Continuous * fsA) + 1;
for e = 4:6
    Ya(rowA(e) + (0:99), 1) = 4;
end
metaA = table(["AUX1"; "AUX2"; "AUX3"], (1:3).', NaN(3, 1), zeros(3, 1), NaN(3, 1), NaN(3, 1), repmat("V", 3, 1), ...
    'VariableNames', {'label', 'channel', 'recordingChannel', 'shank', 'x', 'y', 'units'});
Ac = auxMean(Ya, fsA, Es, Window=[-0.2 0.5], Groups=Rs.groups, Meta=metaA);
kA = find(abs(Ac.t) < 1e-12);
check(Ac.kind == "aux" && Ac.mode == "channels" && Ac.byGroup && isequal(size(Ac.mean), [701 3 2]) ...
    && isequal(Ac.labels, ["AUX1"; "AUX2"; "AUX3"]) && Ac.units == "V" && isequal(Ac.nEpochs, [3; 3]) ...
    && all(abs(Ac.mean(:, 1, 1) - 1) < 1e-6) && abs(Ac.mean(kA, 1, 2) - 4) < 1e-6 && abs(Ac.mean(kA - 1, 1, 2) - 1) < 1e-6 ...
    && all(abs(Ac.mean(:, 2, 2) - 2) < 1e-6), ...
    'auxMean "channels": each channel''s mean per group, the step from the event''s own sample on');
Am = auxMean(Ya, fsA, Es, Window=[-0.2 0.5], Mode="magnitude", Groups=Rs.groups, Meta=metaA);
check(isequal(size(Am.mean), [701 1 2]) && Am.labels == "|AUX1, AUX2, AUX3|" && isequal(Am.channelLabels, metaA.label) ...
    && isempty(Am.meta) && Am.magnitude && all(abs(Am.mean(:, 1, 1) - 3) < 1e-6) && abs(Am.mean(kA, 1, 2) - sqrt(24)) < 1e-6, ...
    'auxMean "magnitude": sqrt(x^2 + y^2 + z^2) at every sample, one trace');
Yd = zeros(70000, 1, 'single');
Yd(rowA(1) + (0:99)) = 2;
Yd(rowA(2) + (0:99)) = -2;
Ad = auxMean(Yd, fsA, Es(1:2, :), Window=[-0.2 0.5], Mode="magnitude");
Ad0 = auxMean(Yd, fsA, Es(1:2, :), Window=[-0.2 0.5]);
check(abs(Ad.mean(kA) - 2) < 1e-6 && abs(Ad0.mean(kA)) < 1e-6, ...
    'the magnitude is taken in each epoch before the mean: +2 and -2 average to 2, not to the magnitude of their mean, 0');
Ab = auxMean(Ya, fsA, Es, Window=[-0.2 0.5], Mode="magnitude", Baseline=[-0.2 -0.01], Groups=Rs.groups);
check(all(abs(Ab.mean(:, 1, 1)) < 1e-6) && abs(Ab.mean(kA, 1, 2) - 3) < 1e-6 && isequal(Ab.params.Baseline, [-0.2 -0.01]), ...
    'a baseline is subtracted from each channel before the magnitude: the size of the change (offsets gone)');
Ap = auxMean(Ya, fsA, Es, Window=[-0.2 0.5], ByGroup=false, Groups=Rs.groups, Meta=metaA);
check(size(Ap.mean, 3) == 1 && height(Ap.groups) == 1 && Ap.groups.label == "all epochs" && Ap.nEpochs == 6 && ~Ap.byGroup ...
    && abs(Ap.mean(kA, 1) - 2.5) < 1e-6, 'ByGroup false: one mean over every epoch');
Ae = auxMean(Ya(1:60300, :), fsA, Es, Window=[-0.2 0.5], Groups=Rs.groups, Meta=metaA);
check(Ae.droppedEdge == 1 && isequal(Ae.nEpochs, [3; 2]), 'an epoch leaving the aux signal is dropped and counted');
% one outlying epoch (2, 2, 20 for 100 ms): the median ignores it, the mean does not; the interquartile band; rectifying
Yo = zeros(70000, 1, 'single');
Yo(rowA(1) + (0:99)) = 2;
Yo(rowA(2) + (0:99)) = 2;
Yo(rowA(3) + (0:99)) = 20;
Amn = auxMean(Yo, fsA, Es(1:3, :), Window=[-0.2 0.5]);
Amd = auxMean(Yo, fsA, Es(1:3, :), Window=[-0.2 0.5], Statistic="median", ErrorType="iqr");
qo = prctile([2 2 20], [25 75]);
check(Amn.statistic == "mean" && Amd.statistic == "median" && abs(Amn.mean(kA) - 8) < 1e-6 && abs(Amd.mean(kA) - 2) < 1e-6 ...
    && Amd.err.type == "iqr" && abs(Amd.err.lo(kA) - qo(1)) < 1e-6 && abs(Amd.err.hi(kA) - qo(2)) < 1e-6 ...
    && abs(Amd.sem(kA) - std([2 2 20]) / sqrt(3)) < 1e-6, ...
    'auxMean Statistic "median": the epochs'' median, which an outlier does not move; ErrorType "iqr": their 25th to 75th percentile');
Ar = auxMean(Yd, fsA, Es(1:2, :), Window=[-0.2 0.5], Rectify=true);
check(Ar.rectified && ~Ad0.rectified && abs(Ar.mean(kA) - 2) < 1e-6 && abs(Ad0.mean(kA)) < 1e-6 && all(Ar.mean(:) >= 0), ...
    'Rectify: each epoch''s absolute value before the mean (+2 and -2 give 2, not 0)');

figA = figure('Visible', 'off');
closerA = onCleanup(@() delete(figA));
auxSpec = @(varargin) struct('mode', "magnitude", varargin{:});
RsA = Rs; RsA.aux = Am;
h = renderPSTH(RsA, figA);
check(isempty(h.auxAxes) && isempty(findall(figA, 'Tag', 'auxTrace')), 'Aux mode "off" (the default): R.aux is not drawn');
h = renderPSTH(RsA, figA, Aux=auxSpec('placement', "below"));
xa = h.auxAxes;
tr = findall(xa, 'Tag', 'auxTrace');
grp = arrayfun(@(l) string(getappdata(l, 'PlotGroup')), tr);
tr2 = tr(grp == Rs.groups.label(2));
check(isscalar(xa) && string(xa.Tag) == "auxAxes" && numel(tr) == 2 && isscalar(tr2) && isequal(tr2.Color, Rs.groups.color(2, :)) ...
    && xa.Layout.Tile > h.axes(1).Layout.Tile && h.rasterAxes(1).Layout.Tile < h.axes(1).Layout.Tile ...
    && isequal(xa.XLim, h.axes(1).XLim) && isempty(h.axes(1).XTickLabel) ...
    && numel(findall(xa, 'Tag', 'auxSem')) >= 2 && startsWith(string(h.layout.YLabel.String), "|AUX| (V)  ·  "), ...
    'below: a panel under the PSTH on its time axis, a trace and SEM band per group in its color; the grid''s y label names it first');
h = renderPSTH(RsA, figA, Aux=auxSpec('placement', "above"));
xa = h.auxAxes;
check(isscalar(xa) && xa.Layout.Tile == 1 && h.rasterAxes(1).Layout.Tile == 2 && isempty(xa.XTickLabel) ...
    && string(xa.Title.String) ~= "" && isempty(h.rasterAxes(1).Title.String) && endsWith(string(h.layout.YLabel.String), "  ·  |AUX| (V)"), ...
    'above: a panel over the raster, carrying the unit''s title; the grid''s y label names it last');
h = renderPSTH(RsA, figA, Aux=auxSpec('placement', "over"));
ax = h.axes(1);
check(isempty(h.auxAxes) && numel(ax.YAxis) == 2 && string(ax.YAxisLocation) == "left" && numel(bothSides(ax, 'auxTrace')) == 2 ...
    && string(ax.YAxis(2).Label.String) == "|AUX| (V)", 'over: on the rate panel''s right y axis, named there; the left side is active again');
T = PlotAesthetics.components(figA);
check(nnz(T.Role == "auxTrace") == 2 && any(T.Role == "auxSem"), 'the aesthetics editor lists the traces on the right side of a yyaxis');
h = renderPSTH(RsA, figA, Aux=auxSpec('placement', "over", 'overPosition', [0 0.3], 'yLim', [2.5 5.5]));
ax = h.axes(1);
yyaxis(ax, 'right'); yr = ax.YLim; tk = ax.YTick; yyaxis(ax, 'left');
check(abs((2.5 - yr(1)) / diff(yr)) < 1e-9 && abs((5.5 - yr(1)) / diff(yr) - 0.3) < 1e-9 ...
    && numel(tk) >= 2 && numel(tk) <= 3 && all(tk >= 2.5 & tk <= 5.5), ...
    'over, span 0 to 0.3, y limits [2.5 5.5]: the limits sit at the panel''s bottom and three tenths up; the right ticks stay along that span');
h = renderPSTH(RsA, figA, Aux=auxSpec('placement', "over", 'overPosition', [0.7 1]));
ax = h.axes(1);
yyaxis(ax, 'right'); yr = ax.YLim; yyaxis(ax, 'left');
trs = bothSides(ax, 'auxTrace');
yd = [trs.YData];
check(min(yd - yr(1)) / diff(yr) >= 0.7 - 1e-9 && max(yd - yr(1)) / diff(yr) <= 1 + 1e-9, ...
    'span 0.7 to 1 with automatic limits: the traces stay in the top three tenths');
h = renderPSTH(RsA, figA, Aux=auxSpec('placement', "below", 'yLim', [0 10]));
cap = plotCaption(struct('kind', "psth", 'aux', auxSpec('placement', "over", 'overPosition', [0 0.3], 'yLim', [2.5 5.5])), RsA);
check(isequal(h.auxAxes.YLim, [0 10]) && contains(cap, "right axis (from 0 to 0.3 of its height)") && contains(cap, "y limits [2.5 5.5] V"), ...
    "a panel takes the y limits given; the caption names the span and the limits: " + cap);
h = renderPSTH(RsA, figA, Stack=true, Aux=auxSpec('placement', "over"));
check(isscalar(h.auxAxes) && h.auxAxes.Layout.Tile > h.axes(1).Layout.Tile, 'over on a stack (its right axis is the peaks): drawn below');
RsC = Rs; RsC.aux = Ac;
h = renderPSTH(RsC, figA, Aux=struct('mode', "channels", 'placement', "below"));
tr = findall(h.auxAxes, 'Tag', 'auxTrace');
lsty = arrayfun(@(l) string(l.LineStyle), tr);
lg = findall(figA, 'Type', 'legend');
check(numel(tr) == 6 && numel(unique(lsty)) == 3 && isscalar(lg) && all(ismember(["AUX1" "AUX2" "AUX3"], string(lg.String))) ...
    && all(ismember(string(Rs.groups.label).', string(lg.String))), ...
    'channels of several groups: the groups'' colors, a line style per channel, each channel in the legend beside the groups');
RsP = Rs; RsP.aux = auxMean(Ya, fsA, Es, Window=[-0.2 0.5], ByGroup=false, Groups=Rs.groups, Meta=metaA);
h = renderRaster(RsP, figA, Aux=struct('mode', "channels", 'placement', "above"));
tr = findall(h.auxAxes, 'Tag', 'auxTrace');
cols = unique(vertcat(tr.Color), 'rows');
check(isscalar(h.auxAxes) && h.auxAxes.Layout.Tile == 1 && h.axes(1).Layout.Tile == 2 && numel(tr) == 3 && size(cols, 1) == 3 ...
    && all(arrayfun(@(l) string(l.LineStyle) == "-", tr)) && endsWith(string(h.layout.YLabel.String), "Epoch  ·  AUX (V)"), ...
    'a raster with the channels of every epoch above it: a color per channel, solid');
h = renderRaster(RsA, figA, Aux=auxSpec('placement', "over"));
ax = h.axes(1);
yyaxis(ax, 'right'); dirR = string(ax.YDir);
yyaxis(ax, 'left'); dirL = string(ax.YDir);
check(numel(ax.YAxis) == 2 && dirL == "reverse" && dirR == "normal" ...
    && numel(bothSides(ax, 'auxTrace')) == 2 && isequal(rasterRows(ax), 1:6), ...
    'over a raster: the rows still run down on the left, the aux signal up on the right');
ax1 = axes(figA);
renderPSTH(RsA, ax1, Aux=auxSpec('placement', "below"));
check(isempty(findall(figA, 'Tag', 'auxAxes')) && numel(ax1.YAxis) == 1, 'one axes: no room for a panel below, no aux signal');
spA = struct('kind', "psth", 'aux', auxSpec('placement', "below", 'baseline', "subtract"));
RsAb = Rs; RsAb.aux = Ab;
h = renderPlot(RsAb, spA, figA);
cap = plotCaption(spA, RsAb);
check(isscalar(h.auxAxes) && startsWith(string(h.layout.YLabel.String), "|AUX - baseline| (V)") ...
    && contains(cap, "aux: mean vector magnitude") && contains(cap, "subtracted from each channel first") ...
    && contains(cap, "in a panel below the PSTH") && contains(cap, "one trace per group (n = 3, 3 epochs)"), ...
    "renderPlot draws spec.aux; the caption says what the aux trace is, where, over how many epochs: " + cap);
RsE = Rs; RsE.aux = Ae;
cap = plotCaption(struct('kind', "raster", 'aux', struct('mode', "channels", 'placement', "over")), RsE);
check(contains(cap, "aux: mean of AUX1, AUX2, AUX3 (V), on the raster's right axis") ...
    && contains(cap, "1 epoch(s) leaving the AUX signal or holding missing samples left out of the aux mean"), ...
    "the caption counts the epochs left out of the aux mean: " + cap);
% display: stacked rows and a heat map; the statistic and the band the aux signal chooses for itself; what colors the traces
Ao = struct('mode', "channels", 'placement', "below", 'display', "stacked");
h = renderPSTH(RsC, figA, Aux=Ao);
xa = h.auxAxes;
tr = findall(xa, 'Tag', 'auxTrace');
ym = arrayfun(@(l) median(l.YData, 'omitnan'), tr);
tkl = string(xa.YAxis(1).TickLabels);
check(isscalar(xa) && numel(tr) == 6 && numel(unique(round(ym, 9))) == 6 && max(diff(sort(ym))) - min(diff(sort(ym))) < 1e-9 ...
    && numel(tkl) == 6 && all(contains(tkl, " · ")) && numel(findall(xa, 'Tag', 'auxScale')) == 2 ...
    && numel(findall(xa, 'Tag', 'auxSem')) >= 6, ...
    'stacked: a row per channel and group on one amplitude scale, labeled at its tick, with a scale bar and its bands');
Ao.placement = "over"; Ao.display = "heatmap";
h = renderPSTH(RsC, figA, Aux=Ao);
xa = h.auxAxes;
im = findall(xa, 'Tag', 'auxImage');
check(isscalar(xa) && isscalar(im) && isequal(size(im.CData), [6 701]) && numel(findall(xa, 'Tag', 'auxGroup')) == 6 ...
    && isempty(findall(xa, 'Tag', 'auxSem')) && isempty(findall(xa, 'Tag', 'auxTrace')) && isequal(xa.CLim, [1 4]) ...
    && string(xa.YDir) == "reverse" && numel(xa.YTick) == 6 && numel(h.axes(1).YAxis) == 1, ...
    'heat map: an image in a panel of its own ("over" goes below), a row per channel and group on one color scale, group marks, no bands');
Ao.display = "lines"; Ao.placement = "below"; Ao.colorBy = "channel";
h = renderPSTH(RsC, figA, Aux=Ao);
tr = findall(h.auxAxes, 'Tag', 'auxTrace');
check(size(unique(vertcat(tr.Color), 'rows'), 1) == 3 && numel(unique(arrayfun(@(l) string(l.LineStyle), tr))) == 2, ...
    'colorBy "channel": a color per channel, the groups told apart by line style');
Ao.colorBy = "group";
h = renderPSTH(RsC, figA, Aux=Ao);
tr = findall(h.auxAxes, 'Tag', 'auxTrace');
check(size(unique(vertcat(tr.Color), 'rows'), 1) == 2 && numel(unique(arrayfun(@(l) string(l.LineStyle), tr))) == 3, ...
    'colorBy "group": the trial selection group''s color, the channels told apart by line style');
h = renderPSTH(RsA, figA, Aux=auxSpec('placement', "below", 'errorType', "off"));
nOff = numel(findall(h.auxAxes, 'Tag', 'auxSem'));
h = renderPSTH(RsA, figA, Aux=auxSpec('placement', "below"), Style=struct('ShowSEM', false));
check(nOff == 0 && numel(findall(h.auxAxes, 'Tag', 'auxSem')) >= 2 && isempty(findall(h.axes(1), 'Tag', 'sem')), ...
    'the aux band has its own choice: off draws none, and the plot''s Error box does not take it away');
RsM = Rs; RsM.aux = auxMean(Yo, fsA, Es(1:3, :), Window=[-0.2 0.5], ByGroup=false, Statistic="median", Rectify=true, ErrorType="iqr");
spM = struct('kind', "psth", 'aux', auxSpec('placement', "below", 'errorType', "iqr"));
h = renderPlot(RsM, spM, figA);
cap = plotCaption(spM, RsM);
check(isscalar(h.auxAxes) && startsWith(string(h.layout.YLabel.String), "median |AUX| (V)") ...
    && contains(cap, "aux: median of the rectified") && contains(cap, "bands: the interquartile range"), ...
    "a median of a rectified signal: named in the label and the caption: " + cap);
ov = struct('shape', "line", 'axis', "x", 'value', 0.1, 'panel', "all");
h = renderPlot(RsA, struct('kind', "psth", 'aux', auxSpec('placement', "below"), 'overlays', ov), figA);
nAll = numel(findall(h.auxAxes, 'Tag', 'overlayLine'));
h = renderPlot(RsA, struct('kind', "psth", 'aux', auxSpec('placement', "below"), 'overlays', setfield(ov, 'panel', "data")), figA); %#ok<SFLD>
check(nAll == 1 && isempty(findall(h.auxAxes, 'Tag', 'overlayLine')) && isscalar(findall(h.axes, 'Tag', 'overlayLine')), ...
    'an overlay on all panels reaches the aux panel; one on the data panels does not');
spX = struct('kind', "psth", 'aux', auxSpec('placement', "below"));
fx = newExportFigure(struct('FigureSizeCm', [18 1]), Rp, spX, Page=1);
fx0 = newExportFigure(struct('FigureSizeCm', [18 1]), setfield(Rp, 'aux', Am), spX, Page=1); %#ok<SFLD>
check(fx0.Position(4) - fx.Position(4) > 1.4, 'an exported grid page grows by 1.5 cm a row of tiles for the aux panels');
delete([fx fx0]);
clear closerA

fprintf('\n== error bands: SEM, SD, bootstrap 95%% CI ==\n');
haveBoot = license('test', 'Statistics_Toolbox') && exist('bootci', 'file') == 2;
Xe = [1 2 2 5; 2 2 2 NaN; 3 2 NaN NaN; 4 2 NaN NaN];   % columns of 4, 4, 2 and 1 values
[lo, hi] = errorBounds(Xe, 1, "sem");
m = mean(Xe, 1, 'omitnan');
check(isequaln(lo, m - semOf(Xe, 1)) && isequaln(hi, m + semOf(Xe, 1)) && lo(2) == 2 && hi(2) == 2 && isnan(lo(4)) && isnan(hi(4)), ...
    'errorBounds "sem": the mean +/- semOf''s SEM; none from a single value');
[lo, hi] = errorBounds(Xe, 1, "std");
[lo2, hi2] = errorBounds(Xe.', 2, "std");
check(abs(hi(1) - lo(1) - 2 * std([1 2 3 4])) < 1e-12 && abs(hi(3) - 2) < 1e-12 && isnan(hi(4)) ...
    && isequaln(lo2, lo.') && isequaln(hi2, hi.'), '"std": the mean +/- the SD of the values, along either dimension');
X3 = cat(3, [1 2; 3 4], [2 3; 4 6], [0 1; 1 1]);
[lo3, hi3] = errorBounds(X3, 3, "sem");
check(isequal(size(lo3), [2 2]) && abs(lo3(2, 2) - (mean([4 6 1]) - std([4 6 1]) / sqrt(3))) < 1e-12 ...
    && abs(hi3(1, 1) - (1 + std([1 2 0]) / sqrt(3))) < 1e-12, 'a 3-D array, the observations along its third dimension');
if haveBoot
    g0 = RandStream.getGlobalStream;
    state0 = g0.State;
    [cl, ch] = errorBounds(Xe, 1, "ci95", 2000);
    [cl2, ch2] = errorBounds(Xe, 1, "ci95", 2000);
    g1 = RandStream.getGlobalStream;
    prev = RandStream.setGlobalStream(RandStream('mt19937ar', 'Seed', 0));
    ci = bootci(2000, {@(y) mean(y, 1, 'omitnan'), Xe(:, 1)}, 'Type', 'per');
    RandStream.setGlobalStream(prev);
    check(isequaln(cl, cl2) && isequaln(ch, ch2) && g1 == g0 && isequal(g0.State, state0) ...
        && abs(cl(1) - ci(1)) < 1e-12 && abs(ch(1) - ci(2)) < 1e-12 && cl(1) < m(1) && ch(1) > m(1) ...
        && cl(2) == 2 && ch(2) == 2 && isnan(cl(4)) && isnan(ch(4)), ...
        ['"ci95": bootci''s percentile 95% CI of the mean, from a seed-0 stream of its own (the same every time, the ' ...
        'global stream untouched); a constant column has a zero-width CI; none from a single value']);
else
    fprintf('  (no Statistics and Machine Learning Toolbox: the bootstrap checks are skipped)\n');
end
rng(21, 'twister');
tE = (10:2:70).';
gE = 1 + mod((1:numel(tE)).', 2);
Ee = epochs(tE, gE);
trains = {poissonTrain(15, 80), sort([poissonTrain(10, 80); driven(tE, 0, 0.2, 40)])};
Rs0 = spikePSTH(trains, Ee, Window=[-0.2 0.5], BinSec=0.05);
Rsd = spikePSTH(trains, Ee, Window=[-0.2 0.5], BinSec=0.05, ErrorType="std");
Rs0.epochs = Ee; Rsd.epochs = Ee;
nPer = reshape(Rs0.nEpochs, 1, 1, []);
check(Rs0.err.type == "sem" && Rs0.err.over == "epochs" && isequaln(Rs0.err.lo, Rs0.rate - Rs0.sem) && isequaln(Rs0.err.hi, Rs0.rate + Rs0.sem) ...
    && Rsd.err.type == "std" && isequaln(Rsd.rate, Rs0.rate) && max(abs(Rsd.err.hi - Rsd.rate - Rs0.sem .* sqrt(nPer)), [], 'all') < 1e-9, ...
    'spikePSTH: R.err is the mean +/- SEM by default; "std" is the mean +/- SD over the group''s epochs (SEM x sqrt(n))');
Rz = spikePSTH(trains, Ee, Window=[-0.2 0.5], BinSec=0.05, Baseline=[-0.2 0], BaselineMode="zscore", ErrorType="std");
sdB = reshape(Rz.baselineSD, 1, size(Rz.baselineSD, 1), []);
check(max(abs((Rz.err.hi - Rz.rate) .* sdB - (Rsd.err.hi - Rsd.rate)), [], 'all') < 1e-9, ...
    'a z-scored PSTH''s band is scaled by the baseline''s SD, as its mean is');
if haveBoot   % the auROC needs the toolbox too
    Ra0 = spikePSTH(trains, Ee, Window=[-0.2 0.5], BinSec=0.05, Baseline=[-0.2 0], BaselineMode="auroc", ...
        Auroc=struct('cutoff', "none"), ErrorType="std");
    check(all(isnan(Ra0.err.lo), 'all') && all(isnan(Ra0.err.hi), 'all'), 'an auROC curve has no band');
end
Ye = single(randn(80000, 2));
Ee2 = epochs(tE, gE, 1000);
V0 = evokedPotential(Ye, 1000, Ee2, Window=[-0.1 0.2]);
Vs = evokedPotential(Ye, 1000, Ee2, Window=[-0.1 0.2], ErrorType="std");
nV = reshape(V0.nEpochs, 1, 1, []);
check(isequaln(V0.err.lo, V0.mean - V0.sem) && max(abs(Vs.err.hi - Vs.mean - V0.sem .* sqrt(nV)), [], 'all') < 1e-9 ...
    && isempty(Vs.data), 'evokedPotential: mean +/- SEM by default; "std" the mean +/- SD over the epochs; no epochs kept unless asked');
if haveBoot
    Vc = evokedPotential(Ye, 1000, Ee2, Window=[-0.1 0.2], ErrorType="ci95", ErrorResamples=500);
    Vk = evokedPotential(Ye, 1000, Ee2, Window=[-0.1 0.2], KeepEpochs=true);
    [l1, h1] = errorBounds(Vk.data(:, :, Ee2.groupIndex(Vk.keptEpochs) == 1), 3, "ci95", 500);
    check(Vc.err.type == "ci95" && isequaln(Vc.err.lo(:, :, 1), l1) && isequaln(Vc.err.hi(:, :, 1), h1) && isempty(Vc.data) ...
        && all(Vc.err.lo <= Vc.mean & Vc.err.hi >= Vc.mean, 'all'), ...
        'evokedPotential "ci95": the bootstrap CI of each group''s epochs, the epochs not returned unless asked');
end
Fr = firingRate(trains, Ee, ErrorType="std");
Tu = tuningCurve(Fr.rate, mod((1:numel(tE)).', 3), Param="P", ErrorType="std");
Bv = behaviorValues(Fr.rate(:, 1), mod((1:numel(tE)).', 3), Param="P", ErrorType="std");
sdOf = @(v) std(v, 0, 1, 'omitnan');
check(abs(Fr.err.hi(1, 1) - Fr.meanRate(1, 1) - sdOf(Fr.rate(gE == 1, 1))) < 1e-9 ...
    && abs(Tu.err.hi(1, 2, 1) - Tu.mean(1, 2, 1) - sdOf(Fr.rate(mod((1:numel(tE)).', 3) == 0, 2))) < 1e-9 ...
    && abs(Bv.err.lo(2) - (Bv.mean(2) - sdOf(Fr.rate(mod((1:numel(tE)).', 3) == 1, 1)))) < 1e-9, ...
    'firingRate, tuningCurve and behaviorValues make the error over each mean''s epochs');

figE = figure('Visible', 'off');
closerE = onCleanup(@() delete(figE));
c1 = Rs0.groups.color(1, :);
bandsOf = @(ax, g) ofGroup(findall(ax, 'Tag', 'sem'), g);
h = renderPSTH(Rs0, figE, WithRaster=false);
sb = bandsOf(h.axes(1), Rs0.groups.label(1));
check(~isempty(sb) && all(arrayfun(@(p) max(abs(p.FaceColor - (c1 + ([1 1 1] - c1) * 0.75))) < 1e-12 && p.FaceAlpha == 1 ...
    && isequal(p.EdgeColor, 'none'), sb)), 'by default a band is opaque, the group''s color paled, with no edge (as before)');
h = renderPSTH(Rs0, figE, WithRaster=false, Style=struct('ErrorFaceAlpha', 0.3, 'ErrorEdgeColor', "auto", ...
    'ErrorEdgeStyle', "--", 'ErrorEdgeWidth', 1.5));
sb = bandsOf(h.axes(1), Rs0.groups.label(1));
check(~isempty(sb) && all(arrayfun(@(p) isequal(p.FaceColor, c1) && p.FaceAlpha == 0.3 && isequal(p.EdgeColor, c1) ...
    && strcmp(p.LineStyle, '--') && p.LineWidth == 1.5, sb)), ...
    'the bands take the style''s look: an opacity (the color unpaled), the edge in the fill''s color, its style and width');
h = renderPSTH(Rs0, figE, WithRaster=false, Style=struct('ErrorFaceColor', "black", 'ErrorEdgeColor', "#ff0000"));
sb = bandsOf(h.axes(1), Rs0.groups.label(2));
check(~isempty(sb) && all(arrayfun(@(p) isequal(p.FaceColor, [0 0 0]) && p.FaceAlpha == 1 && isequal(p.EdgeColor, [1 0 0]), sb)), ...
    'a face color given is drawn as given, opaque; an edge color given is used');
h = renderPSTH(Rsd, figE, WithRaster=false);
sb = bandsOf(h.axes(1), Rsd.groups.label(1));
yb = vertcat(sb.YData);
check(abs(max(yb) - max(Rsd.err.hi(:, 1, 1))) < 1e-9 && abs(min(yb) - min(Rsd.err.lo(:, 1, 1))) < 1e-9, ...
    'a PSTH''s band runs between R.err''s edges');
h = renderPSTH(Rsd, figE, Layout="overlay", Style=struct('ErrorType', "std"));
[olo, ohi] = errorBounds(Rsd.rate, 2, "std");
sb = bandsOf(h.axes(1), Rsd.groups.label(1));
yb = vertcat(sb.YData);
check(abs(max(yb) - max(ohi(:, 1, 1))) < 1e-9 && abs(min(yb) - min(olo(:, 1, 1))) < 1e-9, ...
    'an overlay of units draws the style''s error across the units');
h = renderPSTH(Rsd, figE, WithRaster=false, Stack=true);
check(isfinite(h.step(1)), 'a stack draws its rows'' bands from R.err');
h = renderEvoked(Vs, figE, Layout="grid");
sb = findall(h.layout, 'Tag', 'sem');
check(~isempty(sb) && abs(max(vertcat(sb.YData)) - max(Vs.err.hi, [], 'all')) < 1e-9, 'an evoked grid draws R.err''s band');
h = renderRates(Fr, figE);
eb = findall(h.axes, 'Tag', 'errorBar');
deltas = @(objs, f) sort(cell2mat(arrayfun(@(e) reshape(e.(f), [], 1), objs, 'UniformOutput', false)));
dP = deltas(eb, 'YPositiveDelta'); dN = deltas(eb, 'YNegativeDelta');
check(numel(eb) == 2 && max(abs(dP - sort(reshape(Fr.err.hi - Fr.meanRate, [], 1)))) < 1e-9 && max(abs(dP - dN)) < 1e-12, ...
    'rate bars: error bars from R.err (the SD here, symmetric)');
h = renderTuning(Tu, figE);
cv = findall(h.layout, 'Tag', 'curve');
dT = deltas(cv, 'YPositiveDelta');
check(numel(cv) == size(Tu.mean, 2) && max(abs(dT - sort(reshape(Tu.err.hi - Tu.mean, [], 1)))) < 1e-9, ...
    'a tuning curve''s error bars come from R.err');
h = renderBehavior(Bv, figE, Layout="line");
mb = findall(h.axes, 'Tag', 'behaviorMean');
check(isscalar(mb) && max(abs(mb.YNegativeDelta(:) - (Bv.mean(:) - Bv.err.lo(:)))) < 1e-9, 'a behavior plot''s error bars come from R.err');
cap = @(sp, R) plotCaption(EphysAnalysisConfig.normalizePlot(sp), R);
check(contains(cap(struct('kind', "psth"), Rs0), "bands: mean +/- SEM across epochs") ...
    && contains(cap(struct('kind', "psth", 'style', struct('ErrorType', "std")), Rsd), "bands: mean +/- SD across epochs") ...
    && contains(cap(struct('kind', "psth", 'layout', "overlay", 'style', struct('ErrorType', "std")), Rsd), "bands: mean +/- SD across units") ...
    && ~contains(cap(struct('kind', "psth", 'style', struct('ShowSEM', false)), Rs0), "bands:") ...
    && contains(cap(struct('kind', "rate"), Fr), "error bars: mean +/- SD across epochs"), ...
    'the caption names the error and what it is across');
if haveBoot
    Rci = spikePSTH(trains, Ee, Window=[-0.2 0.5], BinSec=0.05, ErrorType="ci95", ErrorResamples=300);
    Rci.epochs = Ee;
    check(contains(cap(struct('kind', "psth", 'style', struct('ErrorType', "ci95", 'ErrorResamples', 300)), Rci), ...
        "bands: the bootstrap 95% CI of the mean (300 resamples, percentile) across epochs"), 'the caption names the bootstrap and its resamples');
end
pe = @(varargin) plotErrorType(EphysAnalysisConfig.normalizePlot(struct(varargin{:})));
ciS = struct('ErrorType', "ci95");
check(pe('kind', "psth", 'style', ciS) == "ci95" && pe('kind', "raster", 'style', ciS) == "sem" ...
    && pe('kind', "evoked", 'source', "LFP", 'layout', "butterfly", 'style', ciS) == "sem" && pe('kind', "evoked", 'source', "LFP", 'style', ciS) == "ci95" ...
    && pe('kind', "rate", 'layout', "box", 'style', ciS) == "sem" && pe('kind', "behavior", 'style', ciS) == "ci95" ...
    && pe('kind', "psth", 'style', struct('ErrorType', "ci95", 'ShowSEM', false)) == "sem" ...
    && plotErrorType(EphysAnalysisConfig.normalizePlot(struct('kind', "raster", 'aux', struct('mode', "channels"), 'style', ciS)), "aux") == "sem" ...
    && plotErrorType(EphysAnalysisConfig.normalizePlot(struct('kind', "raster", 'aux', struct('mode', "channels", 'errorType', "ci95"), ...
        'style', struct('ShowSEM', false))), "aux") == "ci95" ...
    && plotErrorType(EphysAnalysisConfig.normalizePlot(struct('kind', "raster", 'aux', struct('mode', "channels", 'errorType', "iqr"))), "aux") == "iqr" ...
    && plotErrorType(EphysAnalysisConfig.normalizePlot(struct('kind', "raster", 'aux', struct('mode', "channels", 'errorType', "ci95", ...
        'display', "heatmap"))), "aux") == "sem" ...
    && plotErrorType(EphysAnalysisConfig.normalizePlot(struct('kind', "raster", 'aux', struct('mode', "channels", 'errorType', "off"))), "aux") == "sem" ...
    && plotErrorType(EphysAnalysisConfig.normalizePlot(struct('kind', "raster", 'aux', struct('errorType', "ci95"))), "aux") == "sem", ...
    'plotErrorType: the style''s error where the plot draws it, "sem" where it draws none (no bootstrap for nothing); the aux signal''s own');
if haveBoot
    Xm = [1; 2; 3; 4; 100];
    [mlo, mhi] = errorBounds(Xm, 1, "ci95", 300, "median");
    [slo, shi] = errorBounds(Xm, 1, "sem", [], "median");
    [ilo, ihi] = errorBounds(Xm, 1, "iqr");
    check(mlo >= 1 && mlo <= 3 && mhi >= 3 && mhi <= 100 && abs((slo + shi) / 2 - 3) < 1e-12 ...
        && abs(ilo - prctile(Xm, 25)) < 1e-12 && abs(ihi - prctile(Xm, 75)) < 1e-12, ...
        'errorBounds with the median: its bootstrap CI, SEM centered on it; "iqr": the 25th and 75th percentiles');
end
clear closerE

fprintf('\n== across sessions: sessionTable, combineSessions, sessionResults ==\n');
sessionChecks(@check, @errorId);

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisCompute:Failures', '%d checks failed.', nFail);
end
end


function sessionChecks(check, errorId)
%sessionChecks  sessionTable, combineSessions (every kind, every error) and sessionResults on hand-made results,
%   and every renderer drawing the merged results.
rng(11, 'twister');
names = ["SYNTH-01_260908_103000"; "SYNTH-01_260909_101500"; "SYNTH-02_260910_090000"];
keys = ["SYNTH-01/260908_103000"; "SYNTH-01/260909_101500"; "SYNTH-02/260910_090000"];
S = sessionTable(names, keys);
check(isequal(S.subject, ["SYNTH-01"; "SYNTH-01"; "SYNTH-02"]) && isequal(S.dateText, ["2026-09-08"; "2026-09-09"; "2026-09-10"]) ...
    && isequal(S.label, ["SYNTH-01 2026-09-08"; "SYNTH-01 2026-09-09"; "SYNTH-02 2026-09-10"]) && isequal(S.index, (1:3).') ...
    && all(S.folder == "") && S.date(1) == datetime(2026, 9, 8, 10, 30, 0), ...
    'sessionTable: subject, date and "<subject> <date>" labels from the name pattern, in the order given');
Sd = sessionTable(["x"; "x"; "y"], ["k1"; "k2"; "k3"]);
Ss = sessionTable(names([3 1 2]), keys([3 1 2]), Sort=true, Index=[7; 8; 9], AcqDates=NaT);
check(isequal(Sd.label, ["x"; "x (2)"; "y"]) && all(isnat(Sd.date)) && all(Sd.subject == "") ...
    && isequal(Ss.name, names) && isequal(Ss.index, [8; 9; 7]), ...
    'sessionTable: names without a subject and date keep their name, made unique ("x (2)"); Sort orders by date, keeping Index');

% --- per-session results ------------------------------------------------------------------
t0 = (5:2:85).';
nE = numel(t0);
g2 = 1 + mod((1:nE).', 2);
Ep = epochs(t0, ones(nE, 1));          % one group
Eg = epochs(t0, g2);                   % two groups, "group 1" and "group 2"
Eg3 = epochs(t0, ones(nE, 1));         % the third session: group 1 only
mk = @(ids, ch, sfx) table("su" + ids(:) + "_" + sfx, ids(:), repmat("su", numel(ids), 1), ch(:), "A-" + compose("%03d", ch(:)), ...
    zeros(numel(ids), 1), zeros(numel(ids), 1), 10 * ch(:), ones(numel(ids), 1), ...
    'VariableNames', {'label', 'unitId', 'class', 'channel', 'channelName', 'shank', 'x', 'y', 'nSpikes'});
meta = {mk([1 2 3], [5 5 9], "SYNTH-01_260908T1030"), mk([11 12], [5 7], "SYNTH-01_260909T1015"), mk(21, 9, "SYNTH-02_260910T0900")};
trains = {{poissonTrain(10, 90), poissonTrain(20, 90), poissonTrain(30, 90)}, {poissonTrain(15, 90), poissonTrain(25, 90)}, ...
    {poissonTrain(12, 90)}};
specP = EphysAnalysisConfig.normalizePlot(struct('kind', "psth", 'selection', struct('maxGroups', 12)));
P = cell(1, 3); G = cell(1, 3); F = cell(1, 3);
for k = 1:3
    E = Ep; Eh = Eg; if k == 3; Eh = Eg3; end
    P{k} = spikePSTH(trains{k}, E, Window=[-0.2 0.5], BinSec=0.05, Meta=meta{k});
    P{k}.epochs = E; P{k}.spec = specP; P{k}.dataset = names(k);
    G{k} = spikePSTH(trains{k}, Eh, Window=[-0.2 0.5], BinSec=0.05, Meta=meta{k});
    G{k}.epochs = Eh; G{k}.spec = specP;
    F{k} = firingRate(trains{k}, E, Meta=meta{k}, Baseline=[-1 0]);
    F{k}.epochs = E;
end
h1 = nE; h2 = nE;
P{1}.rasterEvents = struct('line', "Lick", 'edge', "onset", 'label', "Lick onset", 'epoch', [1; 3], 't', [0.1; 0.2]);
P{2}.rasterEvents = struct('line', "Lick", 'edge', "onset", 'label', "Lick onset", 'epoch', 2, 't', 0.3);
P{1}.rasterSortEvent = struct('label', "Lick onset", 't', (1:h1).' / 100);

% --- pool, a series per session -----------------------------------------------------------
R = combineSessions(P(1:2), S(1:2, :));
nB = numel(P{1}.t);
check(isequal(size(R.rate), [nB 5 2]) && isequaln(R.rate(:, 1:3, 1), P{1}.rate) && isequaln(R.rate(:, 4:5, 2), P{2}.rate) ...
    && all(isnan(R.rate(:, 1:3, 2)), 'all') && all(isnan(R.rate(:, 4:5, 1)), 'all') && isequaln(R.sem(:, 4:5, 2), P{2}.sem) ...
    && isequaln(R.err.lo(:, 1:3, 1), P{1}.err.lo) && isequaln(R.err.hi(:, 4:5, 2), P{2}.err.hi) && R.err.type == "sem" ...
    && R.err.over == "epochs" && isequal(R.count(:, 1:3, 1), P{1}.count) && all(R.count(:, 1:3, 2) == 0, 'all') ...
    && isequaln(R.baselineRate(1:3, 1), P{1}.baselineRate) && R.kind == "psth" && isequal(R.edges, P{1}.edges), ...
    'pool: every session-unit its own tile, its own session''s values copied, NaN in the other series, counts summed');
nT = height(R.epochs);
check(nT == h1 + h2 && isequal(R.epochs.epoch, (1:nT).') && isequal(R.epochs.session, [ones(h1, 1); 2 * ones(h2, 1)]) ...
    && all(R.epochs.sessionKey(h1+1:end) == keys(2)) && isequal(R.epochGroup, R.epochs.session) && isequal(R.nEpochs, [h1; h2]) ...
    && isequaln(R.epochStop, [P{1}.epochStop; P{2}.epochStop]) && isequal(R.epochs.t0, [Ep.t0; Ep.t0]) ...
    && R.epochs.Properties.UserData.sessions == 2 && R.epochs.Properties.UserData.dataset == R.dataset, ...
    'pool: the epochs stacked and renumbered 1..N, with session and sessionKey; epochGroup is each epoch''s series');
ok = true;
for t = 1:5
    k = 1 + (t > 3); u = t - 3 * (t > 3);
    ok = ok && isequal(R.raster(t).times, P{k}.raster(u).times) && isequal(R.raster(t).epoch, P{k}.raster(u).epoch + (k - 1) * h1) ...
        && isequal(R.raster(t).group, R.epochGroup(R.raster(t).epoch));
end
check(ok, 'pool: each tile''s raster is its unit''s spikes, epochs offset to rows of R.epochs, group the epoch''s series');
check(isequal(R.rasterEvents.epoch, [1; 3; 2 + h1]) && isequal(R.rasterEvents.t, [0.1; 0.2; 0.3]) && R.rasterEvents.label == "Lick onset" ...
    && isequaln(R.rasterSortEvent.t, [(1:h1).' / 100; NaN(h2, 1)]), ...
    'raster marks are concatenated by label with offset epochs; the sort key is NaN for a session without it');
check(R.labels(1) == "su1 · SYNTH-01 2026-09-08" && R.meta.label(1) == meta{1}.label(1) && isequal(R.meta.session, [1; 1; 1; 2; 2]) ...
    && isequal(R.groups.label, S.label(1:2)) && isequal(R.groups.color, lines(2)) && isequal(R.groups.nSessions, [1; 1]) ...
    && R.dataset == "2 sessions (SYNTH-01)" && isequal(R.tiles.units{4, 2}, 1) && isempty(R.tiles.units{4, 1}) ...
    && R.tiles.key(4) == keys(2) + "|11" && R.tiles.match == "pool" && R.sessionSeries.mode == "session", ...
    'pool: tile labels "<unit> · <session>", meta.session, a palette color per session, the subtitle, the tiles'' units');
check(isequal(R.sessions.status, ["done"; "done"]) && isequal(R.sessions.nItems, [3; 2]) && isequal(R.sessions.nEpochs, [h1; h2]) ...
    && isequal(R.sessions.series, [1; 2]) && isfield(R, 'spec') && isequaln(R.spec, specP), ...
    'R.sessions: each session''s series, status, units and epochs');
Rq = combineSessions(P, S, ColorOrder="sequential");
check(isequal(Rq.groups.color, groupColors((1:3).', true)) && isOrdinalGroups(Rq.groups), ...
    'ColorOrder "sequential": the groups'' ordered colors, so a design''s sequential map follows');

% --- site, every session averaged; the 95% CI --------------------------------------------------
v1 = mean(P{1}.rate(:, 1:2), 2, 'omitnan');
v2 = P{2}.rate(:, 1);
X = [v1 v2];
q = 1.96;
if license('test', 'Statistics_Toolbox') && exist('tinv', 'file'); q = tinv(0.975, 1); end
R = combineSessions(P, S, Match="site", Series="all", MinSessions=2, Error="ci95");
check(isequal(R.tiles.key, ["ch5"; "ch9"]) && max(abs(R.rate(:, 1) - mean(X, 2)), [], 'all') < 1e-12 ...
    && max(abs(R.sem(:, 1) - q * std(X, 0, 2) / sqrt(2))) < 1e-9 && isequaln(R.err.hi, R.rate + R.sem) && R.err.type == "ci95" ...
    && R.err.over == "sessions" && R.sessionSeries.errorNote ~= "" && R.groups.label == "All sessions" && isequal(R.groups.color, [0.15 0.15 0.15]) ...
    && isequal(R.meta.label, ["A-005"; "A-009"]) && isequal(R.meta.nSessions, [2; 2]) && isequal(R.meta.nUnits, [3; 2]) ...
    && ~isfield(R, 'waveforms') && R.dataset == "3 sessions, 2 subjects", ...
    'site + all: one tile per channel held by >= MinSessions sessions, the mean over sessions and the t 95% CI across them');
check(numel(R.raster(1).times) == numel(P{1}.raster(1).times) + numel(P{1}.raster(2).times) + numel(P{2}.raster(1).times) ...
    && all(R.epochs.session(R.raster(1).epoch(numel(P{1}.raster(1).times) + numel(P{1}.raster(2).times) + 1:end)) == 2), ...
    'site: a tile''s raster pools its units'' spikes, each on its own session''s rows');
Rs1 = combineSessions(P, S, Match="site", MinSessions=2);
check(max(abs(Rs1.rate(:, 1, 1) - v1)) < 1e-12 && max(abs(Rs1.sem(:, 1, 1) - sqrt(P{1}.sem(:, 1) .^ 2 + P{1}.sem(:, 2) .^ 2) / 2)) < 1e-12 ...
    && isequaln(Rs1.rate(:, 1, 2), P{2}.rate(:, 1)) && all(isnan(Rs1.rate(:, 1, 3))) && isequaln(Rs1.rate(:, 2, 3), P{3}.rate(:, 1)), ...
    'site, a series per session: a session''s units on the site averaged, their SEM combined as sqrt(sum(sem^2)) / k');

% --- per subject, members ------------------------------------------------------------------
R = combineSessions(P, S, Match="site", Series="subject", ShowMembers=true);
check(isequal(R.tiles.key, ["ch5"; "ch7"; "ch9"]) && isequal(R.groups.label, ["SYNTH-01"; "SYNTH-02"]) && isequal(R.groups.nSessions, [2; 1]) ...
    && max(abs(R.rate(:, 1, 1) - mean(X, 2))) < 1e-12 && max(abs(R.sem(:, 1, 1) - std(X, 0, 2) / sqrt(2))) < 1e-12 ...
    && isequaln(R.rate(:, 3, 2), P{3}.rate(:, 1)) && all(isnan(R.sem(:, 3, 2))) && isequal(size(R.members.rate), [nB 3 3]) ...
    && isequal(R.members.series, [1; 1; 2]) && isequal(R.members.session, [1; 2; 3]) && isequaln(R.members.rate(:, 1, 1), v1), ...
    'series subject: each subject''s sessions averaged (a single session has no band); members keep each session''s values');

% --- mapping --------------------------------------------------------------------------------
M = table(["cellA"; "cellB"; "cellC"], ["1"; "3"; ""], [11; NaN; 12], 'VariableNames', ["cell" keys(1) keys(2)]);
R = combineSessions(P(1:2), S(1:2, :), Match="mapping", Mapping=M);
check(isequal(R.tiles.key, ["cellA"; "cellB"; "cellC"]) && isequaln(R.rate(:, 1, 1), P{1}.rate(:, 1)) && isequaln(R.rate(:, 1, 2), P{2}.rate(:, 1)) ...
    && all(isnan(R.rate(:, 2, 2))) && isequaln(R.rate(:, 3, 2), P{2}.rate(:, 2)) && all(isnan(R.rate(:, 3, 1))) ...
    && isequal(R.tiles.nUnits, [1 1; 1 0; 0 1]) && isequal(R.meta.cell, ["cellA"; "cellB"; "cellC"]) && isequal(R.labels, R.meta.cell), ...
    'mapping: one tile per cell, each session''s unit id in its key''s column; a missing id is NaN');
M2 = table("cellX", "1 2", 11, 'VariableNames', ["cell" keys(1) keys(2)]);
R = combineSessions(P(1:2), S(1:2, :), Match="mapping", Mapping=M2);
Rm = combineSessions(P(1:2), S(1:2, :), Match="mapping", Mapping=M, MinSessions=2);
check(max(abs(R.rate(:, 1, 1) - mean(P{1}.rate(:, 1:2), 2))) < 1e-12 && isequal(R.tiles.nUnits, [2 1]) && Rm.tiles.key == "cellA", ...
    'mapping: "1 2" averages two units; MinSessions keeps the cells found in enough sessions');
check(strcmp(errorId(@() combineSessions(P(1:2), S(1:2, :), Match="mapping", Mapping=M(:, 2:3))), 'combineSessions:Mapping') ...
    && strcmp(errorId(@() combineSessions(P(1:2), S(1:2, :), Match="mapping", Mapping=M(:, 1:2))), 'combineSessions:Mapping') ...
    && strcmp(errorId(@() combineSessions(P(1:2), S(1:2, :), Match="mapping")), 'combineSessions:Mapping'), ...
    'combineSessions:Mapping: no cell column, no column for a session key, no mapping');

% --- errors ------------------------------------------------------------------------------------
Pb = spikePSTH(trains{2}, Ep, Window=[-0.2 0.5], BinSec=0.1, Meta=meta{2}); Pb.epochs = Ep;
check(strcmp(errorId(@() combineSessions({P{1}, F{2}}, S(1:2, :))), 'combineSessions:Kind') ...
    && strcmp(errorId(@() combineSessions({P{1}, Pb}, S(1:2, :))), 'combineSessions:Bins') ...
    && strcmp(errorId(@() combineSessions(G(1:2), S(1:2, :))), 'combineSessions:Groups') ...
    && strcmp(errorId(@() combineSessions(P(1:2), S(1:2, :), Match="site", MinSessions=3)), 'combineSessions:TooFew') ...
    && strcmp(errorId(@() combineSessions(P(1:2), S(1:2, :), MinSessions=3)), 'combineSessions:TooFew') ...
    && strcmp(errorId(@() combineSessions({[], []}, S(1:2, :))), 'combineSessions:TooFew') ...
    && strcmp(errorId(@() combineSessions(P(1:2), S)), 'combineSessions:Size'), ...
    'errors: Kind, Bins, Groups (several groups, no Group), TooFew (no tile / session reaches MinSessions, none at all), Size');
Pa = P{1}; Pa.auroc = struct('cutoff', "ci");
check(strcmp(errorId(@() combineSessions({Pa, P{2}}, S(1:2, :))), 'combineSessions:Auroc'), 'an auROC result: combineSessions:Auroc');

% --- one trial group sliced, every epoch-indexed field renumbered -----------------------------
G{1}.rasterEvents = struct('line', "Lick", 'edge', "onset", 'label', "Lick onset", 'epoch', (1:nE).', 't', 0.01 * (1:nE).');
G{1}.rasterSortEvent = struct('label', "Lick onset", 't', Eg.t0);
R = combineSessions(G, S, Group="group 2");
E2 = Eg(Eg.groupIndex == 2, :); E2.epoch = (1:height(E2)).'; E2.groupIndex(:) = 1; E2.group(:) = "group 2";
ref1 = spikePSTH(trains{1}, E2, Window=[-0.2 0.5], BinSec=0.05, Meta=meta{1});
n2 = height(E2);
check(isequaln(R.rate(:, 1:3, 1), ref1.rate) && isequaln(R.sem(:, 1:3, 1), ref1.sem) && isequaln(R.err.lo(:, 1:3, 1), ref1.err.lo) ...
    && isequal(R.raster(1).epoch, ref1.raster(1).epoch) && isequal(R.raster(1).times, ref1.raster(1).times) ...
    && R.sessions.status(3) == "missing" && R.dataset == "2 sessions (SYNTH-01), group 2" && height(R.epochs) == 2 * n2 ...
    && all(R.epochs.groupIndex == 1) && R.sessionSeries.group == "group 2" && isequal(R.nEpochs, [n2; n2]), ...
    'Group slicing: a session''s group 2 merged is spikePSTH over its group-2 epochs; the session without it is missing');
check(isequal(R.epochs.t0(R.rasterEvents.epoch), E2.t0) && isequal(R.rasterEvents.t, 0.01 * find(Eg.groupIndex == 2)) ...
    && isequal(R.rasterSortEvent.t(1:n2), R.epochs.t0(1:n2)) && all(isnan(R.rasterSortEvent.t(n2+1:end))) ...
    && isequal(R.epochs.t0(R.raster(4).epoch), Eg.t0(G{2}.raster(1).epoch(Eg.groupIndex(G{2}.raster(1).epoch) == 2))), ...
    'Group slicing: raster marks, the sort key and the rasters index the merged epochs (each lands on its own event)');
Fg = firingRate(trains{1}, Eg, Meta=meta{1}); Fg.epochs = Eg;
Rf = combineSessions({Fg}, S(1, :), Group="group 2");
check(isequaln(Rf.rate, Fg.rate(Eg.groupIndex == 2, :)) && isequal(Rf.epochs.t0(Rf.epochIndex), E2.t0) && isequal(Rf.groupIndex, ones(n2, 1)), ...
    'Group slicing a rate result: its epochs'' rates, epochIndex into the merged epochs');
check(strcmp(errorId(@() combineSessions(G, S, Group="group 9")), 'combineSessions:TooFew'), 'a group no session has: TooFew');

% --- combine: session x trial group, line styles ------------------------------------------------
R = combineSessions(G(1:2), S(1:2, :), TrialGroups="combine");
c2 = lines(2);
check(isequal(R.groups.label, [S.label(1) + " · group 1"; S.label(1) + " · group 2"; S.label(2) + " · group 1"; S.label(2) + " · group 2"]) ...
    && isequal(R.groups.lineStyle, ["-"; "--"; "-"; "--"]) && isequal(R.groups.color, c2([1 1 2 2], :)) && isequal(R.groups.base, [1; 1; 2; 2]) ...
    && isequal(R.groups.group, ["group 1"; "group 2"; "group 1"; "group 2"]) && isequaln(R.rate(:, 1:3, 2), G{1}.rate(:, :, 2)) ...
    && isequaln(R.rate(:, 4:5, 3), G{2}.rate(:, :, 1)) && isequal(R.epochGroup, [Eg.groupIndex; Eg.groupIndex + 2]) ...
    && isequal(R.nEpochs, [G{1}.nEpochs; G{2}.nEpochs]), ...
    'combine: a series per session and trial group, "<session> · <group>", the session''s color, a line style per group');

% --- heatmap: pooled rows, the trial groups as its tiles ----------------------------------------
R = combineSessions(G(1:2), S(1:2, :), Kind="heatmap", TrialGroups="each", Match="site", Series="session");
check(R.sessionSeries.match == "pool" && R.sessionSeries.mode == "all" && isequal(R.groups.label, ["group 1"; "group 2"]) && isequal(size(R.rate), [nB 5 2]) ...
    && isequaln(R.rate(:, 1:3, 2), G{1}.rate(:, :, 2)) && isequaln(R.rate(:, 4:5, 1), G{2}.rate(:, :, 1)) && isequal(R.meta.session, [1; 1; 1; 2; 2]), ...
    'heatmap: rows are the session-units (pool, whatever the match), the trial groups its tiles');

% --- rate --------------------------------------------------------------------------------------
R = combineSessions(F(1:2), S(1:2, :));
check(R.rowsAre == "epochs" && isequal(size(R.rate), [h1 + h2 5]) && isequaln(R.rate(1:h1, 1:3), F{1}.rate) && all(isnan(R.rate(1:h1, 4:5)), 'all') ...
    && isequaln(R.rate(h1+1:end, 4:5), F{2}.rate) && isequal(R.epochIndex, (1:h1 + h2).') && isequal(R.groupIndex, [ones(h1, 1); 2 * ones(h2, 1)]) ...
    && isequaln(R.meanRate(1:3, 1), F{1}.meanRate) && all(isnan(R.meanRate(1:3, 2))) && isequaln(R.median(4:5, 2), F{2}.median) ...
    && isequaln(R.duration, [F{1}.duration; F{2}.duration]), ...
    'rate, a series per session: rows are every epoch (NaN off its session), the means per session copied');
Ra = combineSessions(F, S, Match="site", Series="all");
m5 = [mean(F{1}.meanRate(1:2)); F{2}.meanRate(1); NaN];
check(Ra.rowsAre == "sessions" && size(Ra.rate, 1) == 3 && isequal(Ra.epochIndex, (1:3).') && all(Ra.groupIndex == 1) ...
    && max(abs(Ra.rate(1:2, 1) - m5(1:2))) < 1e-12 && isnan(Ra.rate(3, 1)) && abs(Ra.meanRate(1) - mean(m5(1:2))) < 1e-12 ...
    && abs(Ra.sem(1) - std(m5(1:2)) / sqrt(2)) < 1e-12 && all(isnan(Ra.duration)), ...
    'rate, every session averaged: one row per session (its mean rate), so bars, boxes and points agree');

% --- tuning --------------------------------------------------------------------------------------
x1 = 1 + mod((1:nE).', 2); x2 = 2 + mod((1:nE).', 2);
T1 = tuningCurve(F{1}.rate, x1, Param="Depth", Meta=meta{1}); T1.epochs = Ep;
T2 = tuningCurve(F{2}.rate, x2, Param="Depth", Meta=meta{2}); T2.epochs = Ep;
R = combineSessions({T1, T2}, S(1:2, :));
check(isequal(R.x, [1; 2; 3]) && isequaln(R.mean(1:2, 1:3, 1), T1.mean) && all(isnan(R.mean(3, 1:3, 1))) && isequaln(R.mean(2:3, 4:5, 2), T2.mean) ...
    && isequal(R.n, [T1.n(1) 0; T1.n(2) T2.n(1); 0 T2.n(2)]) && R.seriesParam == "session" ...
    && isequal(R.series, S.label(1:2)) && R.param == "Depth", ...
    'tuning: the curves on the union of the levels, NaN where a session has none');
T2t = tuningCurve(F{2}.rate, string(x2), Param="Depth", Meta=meta{2}); T2t.epochs = Ep;
check(strcmp(errorId(@() combineSessions({T1, T2t}, S(1:2, :))), 'combineSessions:MixedLevels'), ...
    'a level numeric in one session and text in another: combineSessions:MixedLevels');
Rt = combineSessions({T1, T2}, S(1:2, :), Match="site", Series="all", ShowMembers=true);
check(isequal(size(Rt.members.mean), [3 3 2]) && Rt.seriesParam == "" && max(abs(Rt.mean(2, 1) - mean([mean(T1.mean(2, 1:2)) T2.mean(1, 1)]))) < 1e-12, ...
    'tuning over every session: the site''s mean at a shared level, the members kept');

% --- behavior ----------------------------------------------------------------------------------
y1 = 200 + 10 * randn(nE, 1); y1(1:5:end) = NaN;
y2 = 250 + 10 * randn(nE, 1);
B1 = behaviorValues(y1, x1, Param="Depth", YName="RespLatency", YUnits="ms"); B1.epochs = Ep;
B2 = behaviorValues(y2, x2, Param="Depth", YName="RespLatency", YUnits="ms"); B2.epochs = Ep;
R = combineSessions({B1, B2}, S(1:2, :));
nb1 = height(B1.values);
check(isequal(R.x, [1; 2; 3]) && height(R.values) == nb1 + height(B2.values) && isequal(R.values.epoch, [B1.values.epoch; B2.values.epoch + h1]) ...
    && isequal(R.epochs.session(R.values.epoch), R.values.session) && isequal(R.values.xIndex, [B1.values.xIndex; B2.values.xIndex + 1]) ...
    && isequal(R.values.seriesIndex, R.values.session) && isequaln(R.mean(1:2, 1), B1.mean) && isequaln(R.mean(2:3, 2), B2.mean) ...
    && R.nMissing == B1.nMissing + B2.nMissing && R.nEpochs == 2 * nE && R.yName == "RespLatency" && R.units == "ms", ...
    'behavior: every value kept, its epoch a row of the merged epochs, its x into the union, its session''s series');
Rb = combineSessions({B1, B2}, S(1:2, :), Series="all");
check(abs(Rb.mean(2) - mean([B1.mean(2) B2.mean(1)])) < 1e-12 && Rb.mean(1) == B1.mean(1) && isnan(Rb.sem(1)) && all(Rb.values.seriesIndex == 1), ...
    'behavior over every session: the sessions'' means averaged at each level');

% --- evoked ------------------------------------------------------------------------------------
fs = 1000;
Y1 = single(randn(90 * fs, 3)); Y2 = single(randn(90 * fs, 3));
mc = @(ch) table("c" + ch(:), ch(:), zeros(numel(ch), 1), zeros(numel(ch), 1), 25 * ch(:), 'VariableNames', {'label', 'channel', 'shank', 'x', 'y'});
V1 = evokedPotential(Y1, fs, Ep, Window=[-0.1 0.2], Meta=mc(1:3)); V1.epochs = Ep;
V2 = evokedPotential(Y2, fs, Ep, Window=[-0.1 0.2], Meta=mc(2:4)); V2.epochs = Ep;
R = combineSessions({V1, V2}, S(1:2, :), MinSessions=2);
check(isequal(R.channels, [2; 3]) && isequal(R.labels, ["c2"; "c3"]) && isequaln(R.mean(:, 1, 1), V1.mean(:, 2)) && isequaln(R.mean(:, 1, 2), V2.mean(:, 1)) ...
    && isequal(R.keptEpochs, [V1.keptEpochs; V2.keptEpochs + h1]) && R.droppedEdge == V1.droppedEdge + V2.droppedEdge && isempty(R.data) ...
    && R.sessionSeries.match == "channel" && isequal(R.t, V1.t) && R.fs == fs, ...
    'evoked: channels matched by recording channel (MinSessions 2: the shared two), kept epochs offset');
V3 = evokedPotential(Y2, 2 * fs, Ep, Window=[-0.1 0.2], Meta=mc(2:4)); V3.epochs = Ep;
check(strcmp(errorId(@() combineSessions({V1, V3}, S(1:2, :))), 'combineSessions:TimeBase'), 'evoked at another rate: combineSessions:TimeBase');
Rhv = combineSessions({V1, V2}, S(1:2, :), Kind="heatmap");
check(size(Rhv.mean, 3) == 1 && max(abs(Rhv.mean(:, 2) - mean([V1.mean(:, 2) V2.mean(:, 1)], 2))) < 1e-6, ...
    'heatmap of a signal: the channels averaged over the sessions, one tile');

% --- waveforms -----------------------------------------------------------------------------------
wv = @(n, tot) struct('timeMs', {repmat({(-1:0.5:1).'}, n, 1)}, 'mean', {num2cell(rand(5, n), 1).'}, 'spikes', {cell(n, 1)}, ...
    'from', repmat("template", n, 1), 'units', repmat("uV", n, 1), 'total', tot(:), 'note', "", 'maxSpikes', 100);
Gw = table(1, "all", [0.15 0.15 0.15], 3, 'VariableNames', {'index', 'label', 'color', 'n'});
W1 = struct('kind', "waveforms", 'meta', meta{1}, 'labels', meta{1}.label, 'n', 3, 'groups', Gw, 'probe', [], ...
    'waveforms', wv(3, [10 20 30]), 'epochs', []);
Gw.n = 2;
W2 = struct('kind', "waveforms", 'meta', meta{2}, 'labels', meta{2}.label, 'n', 2, 'groups', Gw, 'probe', [], ...
    'waveforms', wv(2, [40 50]), 'epochs', []);
Rw = combineSessions({W1, W2}, S(1:2, :), Series="all", Match="site");
check(Rw.sessionSeries.mode == "session" && Rw.sessionSeries.match == "pool" && height(Rw.groups) == 2 && isequal(Rw.groups.n, [3; 2]) ...
    && numel(Rw.waveforms.mean) == 5 && isequal(Rw.waveforms.total, [10; 20; 30; 40; 50]) && isequal(Rw.waveforms.mean{4}, W2.waveforms.mean{1}) ...
    && isequal(Rw.meta.session, [1; 1; 1; 2; 2]) && Rw.n == 5 && isempty(Rw.epochs), ...
    'waveforms: every session''s units side by side, a series (color) per session, the waveforms concatenated');

% --- every renderer draws the merged results -----------------------------------------------------
Rpool = combineSessions(P(1:2), S(1:2, :));
Rall = combineSessions(P, S, Match="site", Series="all", ShowMembers=true);
Rcomb = combineSessions(G(1:2), S(1:2, :), TrialGroups="combine");
Rheat = combineSessions(G(1:2), S(1:2, :), Kind="heatmap", TrialGroups="each");
Rrate = combineSessions(F(1:2), S(1:2, :));
Rrate2 = combineSessions(F, S, Match="site", Series="all");
Rtun = combineSessions({T1, T2}, S(1:2, :));
Rtun2 = Rt;
Rbeh = combineSessions({B1, B2}, S(1:2, :));
Rev = combineSessions({V1, V2}, S(1:2, :));
sp = @(kind, layout, varargin) EphysAnalysisConfig.normalizePlot(struct('kind', kind, 'layout', layout, varargin{:}));
cases = {
    "psth grid + raster", Rpool, sp("psth", "grid", 'style', struct('MaxTiles', 2))
    "psth overlay",       Rpool, sp("psth", "overlay")
    "psth all + members", Rall,  sp("psth", "grid", 'histStyle', "line")
    "psth combine",       Rcomb, sp("psth", "grid", 'histStyle', "line")
    "psth stack",         Rcomb, sp("psth", "grid", 'stack', true)
    "raster",             Rpool, sp("raster", "grid")
    "raster combine",     Rcomb, sp("raster", "grid", 'rasterByGroup', false)
    "heatmap",            Rheat, sp("heatmap", "groups")
    "heatmap evoked",     Rhv,   sp("heatmap", "groups", 'source', "LFP")
    "evoked stack",       Rev,   sp("evoked", "stack", 'source', "LFP")
    "evoked butterfly",   Rev,   sp("evoked", "butterfly", 'source', "LFP")
    "evoked grid",        Rev,   sp("evoked", "grid", 'source', "LFP")
    "rate bar",           Rrate, sp("rate", "bar")
    "rate box",           Rrate, sp("rate", "box")
    "rate points",        Rrate, sp("rate", "points")
    "rate bar (sessions)",    Rrate2, sp("rate", "bar")
    "rate box (sessions)",    Rrate2, sp("rate", "box")
    "rate points (sessions)", Rrate2, sp("rate", "points")
    "tuning grid",        Rtun,  sp("tuning", "grid", 'param', "Depth")
    "tuning overlay",     Rtun2, sp("tuning", "overlay", 'param', "Depth")
    "behavior points",    Rbeh,  sp("behavior", "points", 'source', "trials")
    "behavior line",      Rbeh,  sp("behavior", "line", 'source', "trials")
    "behavior box",       Rbeh,  sp("behavior", "box", 'source', "trials")
    "behavior swarm",     Rbeh,  sp("behavior", "swarm", 'source', "trials")
    "waveforms grid",     Rw,    sp("waveforms", "grid", 'waveform', struct('mode', "both"))
    };
if exist('violinplot', 'file')
    cases(end+1, :) = {"behavior violin", Rbeh, sp("behavior", "violin", 'source', "trials")};
end
for c = 1:size(cases, 1)
    Rc = cases{c, 2}; spec = cases{c, 3};
    msg = "";
    ok = true;
    try
        n = plotPageCount(Rc, spec);
        for p = 1:n
            fig = newExportFigure(struct(), Rc, spec, Page=p);
            closer = onCleanup(@() close(fig));
            h = renderPlot(Rc, spec, fig, Page=p);
            ok = ok && ~isempty(h.axes) && all(isgraphics(h.axes)) && contains(h.title, "session");
            plotCaption(spec, Rc);
            clear closer
        end
        if cases{c, 1} == "psth grid + raster"; ok = ok && n == 3; end
    catch ME
        ok = false;
        msg = " (" + string(ME.message) + ")";
    end
    check(ok, "a merged " + cases{c, 1} + " draws on every page, titled with its sessions" + msg);
end
specS = sp("psth", "grid");
specS.aesthetics = PlotAesthetics.normalizeRules(struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2));
specS.sessionAesthetics = PlotAesthetics.normalizeRules(struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 3));
specS.histStyle = "line";
fig = newExportFigure(struct(), Rpool, specS);
closer = onCleanup(@() close(fig));
h = renderPlot(Rpool, specS, fig);
lw = arrayfun(@(o) o.LineWidth, findall(fig, 'Tag', 'rate'));
check(~isempty(lw) && all(lw == 3) && startsWith(h.title, "PSTH") && contains(h.title, "(2 sessions, " + (h1 + h2) + " epochs)") ...
    && contains(string(h.layout.Subtitle.String), "2 sessions (SYNTH-01)"), ...
    'renderPlot: a session spec''s sessionAesthetics apply after the base plot''s aesthetics; the title counts sessions and epochs');
clear closer

% --- sessionResults ------------------------------------------------------------------------------
spx = EphysAnalysisConfig.normalizeSection("SessionPlot", struct('plot', "p", 'facet', "subject", 'trialGroups', "each"));
res = sessionResults(G, S, spx, specP);
check(numel(res) == 3 && isequal([res.label], ["SYNTH-01 / group 1" "SYNTH-01 / group 2" "SYNTH-02 / group 1"]) ...
    && all([res.status] == "done") && isequaln(res(1).R.spec, specP) && res(3).R.dataset == "1 session (SYNTH-02), group 1" ...
    && isequal([res.facet], ["SYNTH-01" "SYNTH-01" "SYNTH-02"]) && isequal([res.group], ["group 1" "group 2" "group 1"]), ...
    'sessionResults: facet subject x trialGroups each: a figure per subject and group, labeled "<subject> / <group>"');
spx.facet = "none"; spx.trialGroups = "pool";
r1 = sessionResults(P, S, spx, specP);
r2 = sessionResults(G, S, spx, specP);
spx.minSessions = 5;
r3 = sessionResults(P, S, spx, specP);
spx.minSessions = 1; spx.trialGroups = "each";
specP1 = specP; specP1.selection.maxGroups = 1;
r4 = sessionResults(G, S, spx, specP1);
spx.trialGroups = "combine";
r5 = sessionResults(G, S, spx, specP);
check(isscalar(r1) && r1.label == "all" && r1.status == "done" && r2.status == "error" && contains(r2.message, "trial groups") ...
    && r3.status == "skipped" && isscalar(r4) && r4.group == "group 1" && isscalar(r5) && height(r5.R.groups) == 5, ...
    'sessionResults: pool gives one figure ("all"); several groups unpooled is an error, too few sessions skipped; maxGroups caps "each"; combine is one figure');

% --- data export: the mapping CSV, sessionData, writeAnalysisData, epochLongTable -----------------
fprintf('\n== data export: mapping CSV, sessionData, writeAnalysisData, epochLongTable ==\n');
dxDir = tempname;
mkdir(dxDir);
dxClean = onCleanup(@() rmdir(dxDir, 's'));

% the mapping CSV
mf = fullfile(dxDir, 'sub', 'map.csv');
M3 = table(["cellA"; "cellB"; "c,d"], ["1"; "2 3"; ""], [11; NaN; 12], 'VariableNames', ["cell" keys(1) keys(2)]);
mfOut = writeUnitMapping(mf, M3);
txt = splitlines(string(fileread(mf)));
Mr = readUnitMapping(mf);
check(mfOut == mf && txt(1) == "cell," + keys(1) + "," + keys(2) && txt(2) == "cellA,1,11" && txt(3) == "cellB,2 3," ...
    && txt(4) == """c,d"",,12" && isempty(dir(fullfile(dxDir, 'sub', '~*'))), ...
    'writeUnitMapping: the contract''s CSV (header of keys, empty field for a NaN, a field with a comma quoted), the folder made, no temp file left');
check(isequal(string(Mr.Properties.VariableNames), ["cell" keys(1) keys(2)]) && isequal(Mr.cell, M3.cell) && Mr.(keys(1))(2) == "2 3" ...
    && ismissing(Mr.(keys(1))(3)) && Mr.(keys(2))(1) == 11 && isnan(Mr.(keys(2))(2)), ...
    'readUnitMapping: the cell column as text, the key columns as written (text for "2 3", NaN / missing for an empty field)');
Rm1 = combineSessions(P(1:2), S(1:2, :), Match="mapping", Mapping=M3);
Rm2 = combineSessions(P(1:2), S(1:2, :), Match="mapping", Mapping=Mr);
spm = EphysAnalysisConfig.normalizeSection("SessionPlot", struct('plot', "p", 'match', "mapping", 'mappingFile', mf));
rm = sessionResults(P(1:2), S(1:2, :), spm, specP);
check(isequaln(Rm1.rate, Rm2.rate) && isequal(Rm1.tiles.key, Rm2.tiles.key) && isequal(Rm2.tiles.key, ["cellA"; "cellB"; "c,d"]) ...
    && isequal(Rm2.tiles.nUnits, [1 1; 2 0; 0 1]) && isscalar(rm) && rm.status == "done" && isequal(rm.R.tiles.key, Rm2.tiles.key), ...
    'a written and read mapping gives the tiles the table does, and sessionResults reads the file itself');
bad = fullfile(dxDir, 'bad.csv');
writelines(["a,b"; "1,2"], bad);
Mcase = readUnitMapping(writeUnitMapping(fullfile(dxDir, 'case.csv'), table("x", 1, 'VariableNames', ["cell" "k"])));
check(strcmp(errorId(@() readUnitMapping(bad)), 'readUnitMapping:NoCell') ...
    && strcmp(errorId(@() readUnitMapping(fullfile(dxDir, 'none.csv'))), 'readUnitMapping:NoFile') ...
    && strcmp(errorId(@() writeUnitMapping(fullfile(dxDir, 'x.csv'), table(1, 'VariableNames', "a"))), 'writeUnitMapping:NoCell') ...
    && strcmp(errorId(@() writeUnitMapping(mf, M3, Overwrite=false)), 'writeUnitMapping:Exists') && Mcase.cell == "x", ...
    'mapping errors: readUnitMapping:NoCell / :NoFile, writeUnitMapping:NoCell / :Exists');

% epochLongTable on one dataset's epochData
Ed = epochs((5:8).', [1; 2; 1; 2]);
Ed.trial = (1:4).';
Ed.Depth = [0.1; 0.2; 0.1; 0.2];
cnt = reshape(1:24, [4 3 2]);
tms = {[0.01; 0.02], 0.05; zeros(0, 1), [0.2; 0.3]; 0.3, zeros(0, 1); [0.1; 0.2; 0.4], zeros(0, 1)};
Dd = struct('identity', struct('key', keys(1), 'name', names(1), 'label', S.label(1), 'folder', "", 'subject', "SYNTH-01", ...
    'date', S.date(1), 'fs', 30000, 'durationSec', 100), 'spec', specP, 'E', Ed, 'G', table(), 'meta', meta{1}(1:2, :), ...
    'spikes', struct('times', {tms}, 'counts', cnt, 'edges', (-1:2) * 0.1, 't', [-0.05; 0.05; 0.15], 'binSec', 0.1, ...
    'window', [-0.1 0.2], 'binWindow', [-0.1 0.2]), ...
    'signals', struct('data', single(reshape(1:30, [5 2 3])), 'dims', "time x channel x epoch", 't', (-2:2).' / 100, 'fs', 100, ...
    'epochs', Ed([1 3 4], :), 'channels', [4; 7], 'labels', ["c4"; "c7"], 'units', "uV", 'sampleOffsets', [-2 2], ...
    'droppedEdge', 1, 'droppedNonFinite', 0));
Tc = epochLongTable(Dd);
r = Tc.epoch == 3 & Tc.unit == 2 & Tc.bin == 2;
check(height(Tc) == 24 && isequal(string(Tc.Properties.VariableNames), ["session" "subject" "date" "trial" "epoch" "group" "unit" "bin" "t" "count" "Depth"]) ...
    && isequal(Tc.count, reshape(permute(cnt, [2 1 3]), [], 1)) && nnz(r) == 1 && Tc.count(r) == cnt(3, 2, 2) && Tc.t(r) == 0.05 ...
    && Tc.Depth(r) == 0.1 && Tc.group(r) == "group 1" && Tc.session(r) == S.label(1) && Tc.subject(r) == "SYNTH-01" && Tc.trial(r) == 3 ...
    && sum(Tc.count) == sum(cnt(:)), ...
    'epochLongTable counts: a row per epoch x unit x bin (bin fastest), the unit id, the bin center, the trial parameter columns');
Ts = epochLongTable(Dd, What="spikes");
r = Ts.epoch == 2 & Ts.unit == 2;
check(height(Ts) == 9 && isequal(Ts.t(r), [0.2; 0.3]) && sum(Ts.unit == 1) == 6 && all(Ts.Depth(Ts.epoch == 4) == 0.2) ...
    && isequal(string(Ts.Properties.VariableNames), ["session" "subject" "date" "trial" "epoch" "group" "unit" "t" "Depth"]), ...
    'epochLongTable spikes: a row per spike, relative to the event');
Tg = epochLongTable(Dd, What="signals");
r = Tg.epoch == 3 & Tg.channel == 7 & Tg.sample == 1;
check(height(Tg) == 30 && nnz(r) == 1 && Tg.value(r) == Dd.signals.data(4, 2, 2) && Tg.t(r) == 0.01 && Tg.label(r) == "c7" ...
    && isequal(unique(Tg.epoch).', [1 3 4]) && Tg.Depth(r) == 0.1, ...
    'epochLongTable signals: a row per kept epoch x channel x sample, the sample offset from the event, the value');
Dn = Dd; Dn.signals = [];
Dm = Dd; Dm.spikes = [];
Dz = Dd; Dz.spikes.counts = zeros(4, 0, 2);
check(strcmp(errorId(@() epochLongTable(Dd, MaxRows=10)), 'epochLongTable:TooLarge') ...
    && strcmp(errorId(@() epochLongTable(Dn, What="signals")), 'epochLongTable:NoSignals') ...
    && strcmp(errorId(@() epochLongTable(Dm, What="spikes")), 'epochLongTable:NoSpikes') ...
    && strcmp(errorId(@() epochLongTable(Dm)), 'epochLongTable:NoCounts') && strcmp(errorId(@() epochLongTable(Dz)), 'epochLongTable:NoCounts') ...
    && strcmp(errorId(@() epochLongTable(Dd, What="values")), 'epochLongTable:Input') && strcmp(errorId(@() epochLongTable(struct('a', 1))), 'epochLongTable:Input'), ...
    'epochLongTable errors: TooLarge (MaxRows), NoSignals, NoSpikes, NoCounts, Input');

% sessionData and the values table
Ss = S(1:2, :);
Ss.status = ["done"; "done"];
Ss.message = ["" ""].';
spd = EphysAnalysisConfig.normalizeSection("SessionPlot", struct('id', "sd", 'plot', "p", 'data', ["results" "epochs"]));
resD = sessionResults(P(1:2), Ss, spd, specP);
Sx = sessionData(spd, specP, Ss, P(1:2), resD, Epochs={Dd, Dd}, Config=struct('Name', "t"), Files={["a.png" "a.svg"]});
check(Sx.schema == "ephys-analysis-sessions/1" && isequal(fieldnames(Sx).', {'schema', 'sessionPlot', 'spec', 'sessions', 'results', 'perSession', ...
    'epochs', 'config', 'created', 'provenance'}) && isequal(Sx.sessions.nItems, [3; 2]) && isequal(Sx.sessions.nEpochs, [nE; nE]) ...
    && isequal(Sx.sessions.status, ["done"; "done"]) && isscalar(Sx.results) && Sx.results(1).label == "all" && Sx.results(1).R.kind == "psth" ...
    && isequal(Sx.results(1).files, ["a.png" "a.svg"]) && Sx.results(1).status == "done" && numel(Sx.perSession) == 2 && isequaln(Sx.perSession{2}.rate, P{2}.rate) ...
    && numel(Sx.epochs) == 2 && Sx.config.Name == "t" && isfield(Sx.provenance, 'code') && Sx.sessionPlot.id == "sd" && isequaln(Sx.spec, specP), ...
    'sessionData: schema, sessions with nItems / nEpochs, a result per figure, the per-session results and epochs as the data list asks');
spd2 = spd; spd2.data = "epochs";
spd3 = spd; spd3.data = "results";
Sx2 = sessionData(spd2, specP, Ss, P(1:2), resD, Epochs={Dd, Dd});
Sx3 = sessionData(spd3, specP, Ss, P(1:2), resD, Epochs={Dd, Dd});
check(isempty(Sx2.perSession) && numel(Sx2.epochs) == 2 && numel(Sx3.perSession) == 2 && isempty(Sx3.epochs) ...
    && strcmp(errorId(@() sessionData(spd, specP, Ss, P(1:3), resD)), 'sessionData:Size'), ...
    'sessionData: per-session results only with "results", epochs only with "epochs"; sessionData:Size');
nB = numel(P{1}.t);
Tv1 = epochLongTable(Sx);
r = Tv1.session == 2 & Tv1.tile == P{2}.labels(2) & Tv1.t == P{2}.t(5);
check(isequal(string(Tv1.Properties.VariableNames), ["plot" "facet" "group" "series" "session" "subject" "date" "tile" "unit" "channel" "t" "value" "err" "n"]) ...
    && height(Tv1) == nB * 5 && nnz(r) == 1 && Tv1.value(r) == P{2}.rate(5, 2, 1) && Tv1.err(r) == P{2}.sem(5, 2, 1) && Tv1.n(r) == P{2}.nEpochs(1) ...
    && Tv1.series(r) == Ss.label(2) && Tv1.unit(r) == 12 && Tv1.channel(r) == 7 && Tv1.subject(r) == "SYNTH-01" && Tv1.facet(r) == "all" && Tv1.plot(r) == "p" ...
    && Tv1.date(r) == Ss.date(2) && Tv1.group(r) == P{2}.groups.label(1), ...
    'epochLongTable values from the per-session results: a row per session x unit x bin, with its session, unit, channel, value, error and epochs');
Tv2 = epochLongTable(Sx2);
r = Tv2.series == Ss.label(2) & Tv2.unit == 11 & Tv2.t == P{1}.t(3);
check(height(Tv2) == nB * 5 * 2 && nnz(r) == 1 && Tv2.value(r) == resD.R.rate(3, 4, 2) && Tv2.session(r) == 2 && Tv2.tile(r) == resD.R.labels(4) ...
    && sum(isnan(Tv2.value)) == nB * 5, ...
    'epochLongTable values without the per-session results: from the merged result, a row per series x tile x bin (NaN where a series has no unit)');
spa = spd2; spa.series = "all"; spa.match = "site";
resA = sessionResults(P(1:2), Ss, spa, specP);
Va = epochLongTable(sessionData(spa, specP, Ss, P(1:2), resA));
spb = spd2; spb.series = "subject";
resB = sessionResults(P, S, spb, specP);
Vb = epochLongTable(sessionData(spb, specP, S, P, resB));
check(all(isnan(Va.session)) && all(Va.series == "All sessions") && height(Va) == nB * height(resA.R.meta) && all(isnat(Va.date)) ...
    && isequal(unique(Vb.series, 'stable'), ["SYNTH-01"; "SYNTH-02"]) && isequal(Vb.subject, Vb.series) && all(isnan(Vb.session)), ...
    'epochLongTable values of a summary series: no session (NaN), a subject series carries its subject');
specF = EphysAnalysisConfig.normalizePlot(struct('kind', "rate"));
resF = sessionResults(F(1:2), Ss, spd2, specF);
Vf = epochLongTable(sessionData(spd2, specF, Ss, F(1:2), resF));
r = Vf.series == Ss.label(2) & Vf.tile == resF.R.labels(4);
check(~ismember("t", string(Vf.Properties.VariableNames)) && ~ismember("x", string(Vf.Properties.VariableNames)) && height(Vf) == 5 * 2 ...
    && nnz(r) == 1 && Vf.value(r) == resF.R.meanRate(4, 2) && Vf.err(r) == resF.R.sem(4, 2), ...
    'epochLongTable values of a rate result: a row per series x tile, no position column');
specV = EphysAnalysisConfig.normalizePlot(struct('kind', "evoked", 'source', "LFP"));
resV = sessionResults({V1, V2}, Ss, spd2, specV);
Vv = epochLongTable(sessionData(spd2, specV, Ss, {V1, V2}, resV));
ic = find(resV.R.labels == "c2");
r = Vv.series == Ss.label(1) & Vv.tile == "c2" & Vv.t == resV.R.t(5);
check(height(Vv) == numel(resV.R.t) * numel(resV.R.labels) * 2 && nnz(r) == 1 && Vv.value(r) == resV.R.mean(5, ic, 1) && Vv.channel(r) == 2, ...
    'epochLongTable values of an evoked result: the channel, the time, the mean');
specT = EphysAnalysisConfig.normalizePlot(struct('kind', "tuning", 'param', "Depth"));
resT = sessionResults({T1, T2}, Ss, spd2, specT);
Vt = epochLongTable(sessionData(spd2, specT, Ss, {T1, T2}, resT));
r = Vt.series == Ss.label(2) & Vt.x == 2 & Vt.tile == resT.R.labels(4);
check(height(Vt) == 3 * 5 * 2 && nnz(r) == 1 && Vt.value(r) == resT.R.mean(2, 4, 2) && Vt.n(r) == resT.R.n(2, 2), ...
    'epochLongTable values of a tuning result: the level as x');
specB = EphysAnalysisConfig.normalizePlot(struct('kind', "behavior", 'param', "Depth", 'source', "trials"));
resBh = sessionResults({B1, B2}, Ss, spd2, specB);
Vh = epochLongTable(sessionData(spd2, specB, Ss, {B1, B2}, resBh));
r = Vh.series == Ss.label(2) & Vh.x == 2;
check(height(Vh) == 3 * 2 && nnz(r) == 1 && Vh.value(r) == resBh.R.mean(2, 2) && Vh.tile(r) == "", ...
    'epochLongTable values of a behavior result: no tiles');
specW = EphysAnalysisConfig.normalizePlot(struct('kind', "waveforms", 'layout', "grid"));
resW = sessionResults({W1, W2}, Ss, spd2, specW);
check(strcmp(errorId(@() epochLongTable(sessionData(spd2, specW, Ss, {W1, W2}, resW))), 'epochLongTable:Kind') ...
    && strcmp(errorId(@() epochLongTable(Sx3, What="counts")), 'epochLongTable:NoEpochs') ...
    && strcmp(errorId(@() epochLongTable(Sx, MaxRows=20)), 'epochLongTable:TooLarge'), ...
    'epochLongTable: a waveforms result has no values (:Kind), no epochs (:NoEpochs), :TooLarge past MaxRows');
Tx = epochLongTable(Sx, What="counts");
check(height(Tx) == 48 && all(Tx.session == S.label(1)), 'epochLongTable counts of a sessions struct: every session''s epochs stacked');

% writeAnalysisData
df = fullfile(dxDir, 'data', 'sd');
out = writeAnalysisData(df, Sx);
L = load(out);
check(out == df + ".mat" && isfile(out) && isequal(sort(fieldnames(L)), sort(fieldnames(Sx))) && L.schema == Sx.schema ...
    && isequal(L.sessions.label, Sx.sessions.label) && isequal(L.sessions.nItems, Sx.sessions.nItems) && L.results(1).R.kind == "psth" ...
    && isequaln(L.results(1).R.rate, Sx.results(1).R.rate) && isequaln(L.perSession{1}.rate, P{1}.rate) && numel(L.epochs) == 2 ...
    && isequaln(L.epochs{1}.spikes.counts, Dd.spikes.counts) && isequaln(L.epochs{2}.signals.data, Dd.signals.data) ...
    && isempty(dir(fullfile(dxDir, 'data', '~*'))), ...
    'writeAnalysisData: ".mat" added, the struct''s fields are the file''s variables (load gives them back), no temp file left');
out7 = writeAnalysisData(fullfile(dxDir, 'v7.mat'), Sx, MatVersion="-v7");
L7 = load(out7);
check(strcmp(errorId(@() writeAnalysisData(out, Sx)), 'writeAnalysisData:Exists') && writeAnalysisData(out, Sx, Overwrite=true) == out ...
    && numel(L7.results) == 1 && isequaln(L7.results(1).R.rate, Sx.results(1).R.rate), ...
    'writeAnalysisData: :Exists unless Overwrite; MatVersion "-v7" writes too');
clear dxClean
end


function h = bothSides(ax, tag)
%bothSides  The objects tagged TAG on both sides of a yyaxis AX (a side's Children may be its own only).
side = ax.YAxisLocation;
yyaxis(ax, 'left');
h = findall(ax, 'Tag', tag);
yyaxis(ax, 'right');
r = findall(ax, 'Tag', tag);
yyaxis(ax, side);
for k = 1:numel(r)
    if ~any(r(k) == h); h(end+1, 1) = r(k); end %#ok<AGROW>
end
end


function h = ofGroup(h, g)
%ofGroup  The objects of H whose PlotGroup is G.
keep = arrayfun(@(p) isappdata(p, 'PlotGroup') && string(getappdata(p, 'PlotGroup')) == g, h);
h = h(keep);
end


function rows = rasterRows(ax)
%rasterRows  The row of each epoch k in a raster of one spike per epoch at t0 + 0.01 k.
L = findobj(ax, 'Type', 'line', 'Color', [0 0 0]);
x = L.XData(1:3:end);
y = L.YData(1:3:end) + 0.4;
rows = zeros(1, numel(x));
rows(round(x / 0.01)) = round(y);
end


function s = poissonTrain(rate, T)
%poissonTrain  Homogeneous Poisson spike times on [0, T).
n = poissrnd0(rate * T);
s = sort(T * rand(n, 1));
end


function n = poissrnd0(mu)
%poissrnd0  Poisson count (normal approximation for large mu; no toolbox).
n = max(0, round(mu + sqrt(mu) * randn));
end


function s = driven(t0, a, b, rate)
%driven  Extra spikes at RATE Hz in [t0+a, t0+b) of every event.
s = zeros(0, 1);
for k = 1:numel(t0)
    n = poissrnd0(rate * (b - a));
    s = [s; t0(k) + a + (b - a) * rand(n, 1)]; %#ok<AGROW>
end
end


function s = insideTrain(t0, dur, rate)
s = zeros(0, 1);
for k = 1:numel(t0)
    n = poissrnd0(rate * dur(k));
    s = [s; t0(k) + dur(k) * rand(n, 1)]; %#ok<AGROW>
end
end


function E = epochs(t0, g, fsRec)
%epochs  A minimal epochTable-shaped table for fixed windows.
%   T0 are digital-event times row/FSREC of a FSREC-Hz recording
%   (t0Continuous = (row-1)/FSREC, as epochTable makes it); FSREC Inf
%   (default): T0 is on the continuous clock already.
if nargin < 3; fsRec = Inf; end
t0 = t0(:); g = g(:);
n = numel(t0);
tc = t0;
if isfinite(fsRec); tc = (round(t0 * fsRec) - 1) / fsRec; end
E = table((1:n).', NaN(n, 1), t0, tc, NaN(n, 1), t0 - 0.2, t0 + 0.5, repmat(0.7, n, 1), true(n, 1), false(n, 1), g, "group " + g, ...
    'VariableNames', {'epoch', 'trial', 't0', 't0Continuous', 't1', 'tStart', 'tStop', 'duration', 'complete', 'artifact', 'groupIndex', 'group'});
end


function [c, rel, ep] = binCountsRef(s, t0, edges)
%binCountsRef  binCounts the slow way: each event's spikes by comparison, bin by bin.
%   A spike within 1e-9 s of an edge belongs to the bin that starts there.
tol = 1e-9;
s = sort(s(:));
c = zeros(numel(edges) - 1, numel(t0));
rel = zeros(0, 1); ep = zeros(0, 1);
for e = 1:numel(t0)
    r = s - t0(e);
    r = r(r >= edges(1) - tol & r < edges(end) - tol);
    for k = 1:numel(edges) - 1
        c(k, e) = nnz(r >= edges(k) - tol & r < edges(k + 1) - tol);
    end
    rel = [rel; r]; %#ok<AGROW>
    ep = [ep; repmat(e, numel(r), 1)]; %#ok<AGROW>
end
end


function Q = ranks(X)
%ranks  Tie-averaged ranks down each column, by counting (independent of unitCorrelation's).
Q = zeros(size(X));
for j = 1:size(X, 2)
    x = X(:, j);
    Q(:, j) = arrayfun(@(v) nnz(x < v) + (nnz(x == v) + 1) / 2, x);
end
end


function r = corr1(X)
c = corrcoef(X);
r = c(1, 2);
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
