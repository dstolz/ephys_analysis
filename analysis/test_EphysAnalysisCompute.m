function test_EphysAnalysisCompute()
%test_EphysAnalysisCompute  Verification suite for the compute functions and the renderers the figures share.
%   No recording is needed: seeded Poisson spike trains and synthetic
%   signals check spikePSTH (rates, SEM, half-open bins aligned to the
%   event, baseline, smoothing, stop masking, rasters), a spike in the
%   event's own sample at 0 (spikePSTH, firingRate, unitCorrelation),
%   firingRate ("between" windows, baselines), tuningCurve (and
%   tuningCurve:NoValues), evokedPotential (the event's own row at the
%   recording rate, a bump on the event's sample peaking at 0 at derived
%   rates, NaN padding and drop counts, baseline), the trial-filter
%   compiler, probeMapValues, unitCorrelation (Pearson and Spearman
%   against corrcoef, peak rates, partial bins, baseline, groups,
%   degenerate units), that the renderers a figure's panels call
%   (renderHeatmap, renderProbeMap, renderCorrMap, renderWaveforms) draw
%   into a classic figure's axes, a uifigure's uiaxes, a figure (tiled
%   layout) and a panel, shortUnitLabels and the corrmap's outer labels,
%   binCounts / countBelow against brute force (a spike on a bin edge in
%   the bin that starts there, on a 30 kHz sample grid too), probeOrder,
%   siteLabels, the measures (rate, count, probability), a grid's labels
%   on its layout, renderWaveforms' grid and probe layouts (amplitude
%   scales, glyph sizes, sites, names, units without a position,
%   templates); the error bands and bars: errorBounds (SEM as semOf, SD,
%   the bootstrap 95% CI as bootci's percentile one, repeatable, the
%   global stream untouched, the median and the IQR) and the error each
%   compute function makes (R.err; a z-scored PSTH's scaled, an auROC's
%   none); and across sessions: sessionTable (labels, order),
%   combineSessions on hand-made results of every kind a figure layer
%   merges (pool / site / mapping tiles, series per session / subject /
%   all, the SEM and t 95% CI across sessions, members, epoch renumbering
%   on every epoch-indexed field, Group slicing against the compute over
%   that group, combine's labels and line styles, rate's rowsAre, every
%   error id); and the data export: the unit-mapping CSV
%   (writeUnitMapping, readUnitMapping) and writeAnalysisData (round trip,
%   Exists, -v7).
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

fprintf('\n== 6. the renderers the figures share ==\n');
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
check(Rq.on == "units" && isequal(Rq.value, Tu.rateHz) && isequal(Rq.unitX, Tu.x) && isequal(Rq.unitY, Tu.y), ...
    'probeMapValues keeps each unit''s own rate, at its own position');
Tn = Tu; Tn.x(3) = NaN; Tn.y(3) = NaN;
Rn = probeMapValues(Tn, probe, Value="nSpikes");
check(isequal(Rn.value, Tu.nSpikes) && Rn.unitX(3) == 0 && Rn.unitY(3) == 50, 'a unit without a position goes to its channel''s site');
Rq0 = probeMapValues(Tu, probe, Value="nUnits");
check(Rq0.on == "sites" && sum(Rq0.value) == 3 && Rq0.value(2) == 0, 'nUnits counts the units per site');
cases = {
    "heatmap psth",        @(tg) renderHeatmap(Rp, tg, Order="peak")
    "heatmap evoked",      @(tg) renderHeatmap(Rv, tg)
    "probe map",           @(tg) renderProbeMap(Rq, [], tg)
    "probe map (values)",  @(tg) renderProbeMap([5 NaN 3 1 0 2 7 4], probe, tg)
    "unit correlation",    @(tg) renderCorrMap(Rc, tg, Style=struct('SortDepth', false))
    };
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
parked = struct('chanMap', 0:9, 'xc', [0 8 0 8 200 208 200 208 4 204], 'yc', [0 25 50 75 0 25 50 75 400 500], ...
    'kcoords', [0 0 0 0 1 1 1 1 2 3]);
[colP, CP, colQ] = probeColumns(parked.xc, parked.kcoords, [6 150 260 NaN]);
check(isequal(colP.', [1 1 1 1 2 2 2 2 1 2]) && isequal(CP.shank, [0 1]) && isequal(CP.center, [4 204]) && isequal(colQ.', [1 2 2 0]), ...
    'probeColumns: shanks by x, a site parked on a kcoords group of its own stays on its shank (named by its main group); a point goes to its nearest shank');
Rpk = probeMapValues(Tu, parked, Value="rate");
h = renderProbeMap(Rpk, [], fig);
lab = findall(h.axes, 'Tag', 'shankLabels');
ud = findall(h.axes, 'Tag', 'unitDots', 'Type', 'scatter');
check(isempty(findall(h.axes, 'Tag', 'sites')) && isequal(findall(h.axes, 'Tag', 'emptySites').XData(:), Rpk.x) ...
    && isscalar(ud) && isequal(ud.XData(:), Tu.x) && isequal(ud.CData(:), Tu.rateHz) ...
    && numel(findall(h.axes, 'Tag', 'probeShank')) == 2 && isequal(sort(string(get(lab, 'String'))), ["Shank 0"; "Shank 1"]) ...
    && isequal(h.axes.XTick, [4 204]), ...
    'probe map: the rates on the units (no site colored), every site at its own x (the parked ones too), a body and a name per shank, an x tick at each');
h = renderProbeMap(Rq0, [], fig);
check(numel(findall(h.axes, 'Tag', 'sites').XData) == 3 && numel(findall(h.axes, 'Tag', 'emptySites').XData) == 5 ...
    && isequal(h.colorbar.Ticks, 1) && string(h.colorbar.Label.String) == "Units", ...
    'units per site: a site with none is drawn as one without a value, a color step per count');
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
% a grid's labels: once, on its tiled layout
unlabeled = @(axs) all(arrayfun(@(a) string(a.XLabel.String) == "" && string(a.YAxis(1).Label.String) == "", axs));
gridKinds = {
    "heatmap",          @(tg) renderHeatmap(Rp, tg),                   "Time (s)", "Units"
    "unit correlation", @(tg) renderCorrMap(Rc, tg),                   "Units",    "Units"};
for k = 1:size(gridKinds, 1)
    hk = gridKinds{k, 2}(fig8);
    check(string(hk.layout.XLabel.String) == gridKinds{k, 3} && string(hk.layout.YLabel.String) == gridKinds{k, 4} && unlabeled(hk.axes), ...
        gridKinds{k, 1} + ": the x and y labels are the layout's, no tile's");
end
delete(fig8);

fprintf('\n== waveforms (renderWaveforms) ==\n');
nUw = size(Rp.rate, 2);
tms = linspace(-0.6, 1.4, 61).';
shape = -exp(-(tms / 0.15).^2) + 0.4 * exp(-((tms - 0.5) / 0.3).^2);
Ww = struct('timeMs', {repmat({tms}, nUw, 1)}, 'mean', {cell(nUw, 1)}, 'spikes', {cell(nUw, 1)}, ...
    'from', repmat("spikes", nUw, 1), 'units', repmat("uV", nUw, 1), 'note', "", 'maxSpikes', 12);
for u = 1:nUw
    Ww.spikes{u} = 50 * u * shape + 5 * randn(61, 12);
    Ww.mean{u} = mean(Ww.spikes{u}, 2);
end
probeW = struct('chanMap', (0:5).', 'xc', [0 0 0 200 200 200].', 'yc', [0 50 100 0 50 100].', 'kcoords', [0 0 0 1 1 1].');
Rw = struct('kind', "waveforms", 'meta', meta, 'labels', meta.label, 'n', 3, 'probe', probeW, 'waveforms', Ww, ...
    'groups', table(1, "all", [0.15 0.15 0.15], 3, 'VariableNames', {'index', 'label', 'color', 'n'}));
fig11 = figure('Visible', 'off');
part = @(ax, tag) findall(ax, 'Tag', tag);   % the parts are hidden handles (kept out of legends)
h = renderWaveforms(Rw, fig11, Waveform=struct('mode', "both"));
ok = numel(h.axes) == 3;
for ax = h.axes
    ok = ok && isscalar(part(ax, "waveMean")) && isscalar(part(ax, "waveSpikes")) && nnz(isnan(part(ax, "waveSpikes").YData)) == 12 ...
        && isscalar(part(ax, "waveZero")) && isequal(ax.XLim, [min(tms) max(tms)]);
end
check(ok && isscalar(part(h.axes(1), "waveLabel")), ...
    'grid: a tile per unit, its 12 spikes and mean on the spike-time axis (ms), the spike''s time marked, a label');
check(isequal(arrayfun(@(a) string(a.Title.String), h.axes), ["u2" "u3" "u1"]), 'the tiles go top of the probe first, titled by unit');
yl = vertcat(h.axes.YLim);
check(size(unique(yl, 'rows'), 1) == 3, 'amplitude "unit": every tile has the limits of its own waveform');
h = renderWaveforms(Rw, fig11, Waveform=struct('mode', "mean", 'ampScale', "common"));
yl = vertcat(h.axes.YLim);
check(size(unique(yl, 'rows'), 1) == 1 && all(arrayfun(@(a) isempty(part(a, "waveSpikes")), h.axes)), ...
    'amplitude "common", mode "mean": one amplitude axis for every tile, no spikes');
h = renderWaveforms(Rw, fig11, Style=struct('MaxTiles', 2), Page=2);
check(isscalar(h.axes), 'MaxTiles pages the grid: page 2 of three units at two a page holds one');
h = renderWaveforms(Rw, fig11, Waveform=struct('mode', "off"));
check(numel(part(h.axes(1), "waveSpikes")) == 1 && numel(part(h.axes(1), "waveMean")) == 1, 'mode "off" is drawn as "both"');

h = renderWaveforms(Rw, fig11, Layout="probe", Waveform=struct('mode', "both"));
ax = h.axes;
mu = part(ax, "waveMean"); sp = part(ax, "waveSpikes"); sites = part(ax, "waveSites");
gh = 30;   % the probe is 100 um tall: a twelfth is below the 30 um floor
mx = reshape(mu.XData, [], 3); my = reshape(mu.YData, [], 3);   % a unit per column, a NaN row each
ok = isscalar(mu) && isscalar(sp) && isscalar(sites) && nnz(isnan(mu.XData)) == 3 && nnz(isnan(sp.YData)) == 36 && numel(sites.XData) == 6;
ok = ok && all(abs((min(mx) + max(mx)) / 2 - [0 8 200]) < 1e-9);          % centered on x (the shanks are far enough apart)
ok = ok && all(all(abs(my(1:end-1, :) - meta.y.') <= gh / 2 + 1e-9));
check(ok && string(ax.XLabel.String) == "x (µm)" && isempty(part(ax, "waveName")) && isempty(part(ax, "waveScale")), ...
    'probe: one panel; every unit''s spikes and mean as a glyph at its position (within 30 um of its y), the probe''s sites behind');
h = renderWaveforms(Rw, fig11, Layout="probe", Waveform=struct('mode', "mean", 'height', 2, 'width', 0.5));
my = reshape(part(h.axes, "waveMean").YData, [], 3); mx = reshape(part(h.axes, "waveMean").XData, [], 3);
check(all(abs((max(my) - min(my)) - 2 * gh) < 1e-9) && all(abs((max(mx) - min(mx)) - 0.5 * 1.6 * gh) < 1e-9), ...
    'height 2 doubles the glyphs'' height, width 0.5 halves their width; "unit" scale fills each glyph''s height');
h = renderWaveforms(Rw, fig11, Layout="probe", Waveform=struct('mode', "mean", 'ampScale', "fixed", 'ampLim', [-100 50]));
my = reshape(part(h.axes, "waveMean").YData, [], 3);
check(all(max(my) - min(my) <= gh + 1e-9) && abs(max(my(:, 3)) - min(my(:, 3)) - gh) < 1e-9 && numel(part(h.axes, "waveScale")) == 2, ...
    'probe, "fixed" amplitude: every glyph on the range [-100 50] uV (the largest clipped at the glyph''s height), with a scale bar');
h = renderWaveforms(Rw, fig11, Waveform=struct('mode', "both", 'timeMs', [-0.2 0.6], 'ampScale', "fixed", 'ampLim', [-300 100]));
in = tms(tms >= -0.2 & tms <= 0.6);
check(all(arrayfun(@(a) isequal(a.XLim, [min(in) max(in)]) && numel(part(a, "waveMean").XData) == numel(in) ...
    && abs(a.YLim(1) + 300 + 0.08 * 400) < 1e-9 && abs(a.YLim(2) - 100 - 0.08 * 400) < 1e-9, h.axes)), ...
    'grid: the time span [-0.2 0.6] ms is the x axis (only its samples drawn); "fixed" amplitude: every tile''s y limits are the range (padded)');
h = renderWaveforms(Rw, fig11, Waveform=struct('mode', "mean", 'timeMs', [5 9]));
check(isequal(h.axes(1).XLim, [min(tms) max(tms)]), 'a time span that misses the waveform draws all of it');
h = renderWaveforms(Rw, fig11, Waveform=struct('mode', "mean", 'timeMs', [-Inf 0]));
check(isequal(h.axes(1).XLim, [min(tms) max(tms(tms <= 0))]), 'a span''s -Inf is the cut''s start');
h = renderWaveforms(Rw, fig11, Layout="probe", Waveform=struct('mode', "mean", 'ampScale', "common"));
my = reshape(part(h.axes, "waveMean").YData, [], 3);
hgt = max(my) - min(my);
check(abs(hgt(3) - gh) < 1e-9 && abs(hgt(1) / hgt(3) - 1 / 3) < 0.1 && numel(part(h.axes, "waveScale")) == 2, ...
    '"common": the largest unit fills the height, the others in proportion (a third), and a scale bar says how much');
h = renderWaveforms(Rw, fig11, Layout="probe", Waveform=struct('mode', "both", 'showSites', false, 'showNames', true, 'showPP', false));
check(isempty(part(h.axes, "waveSites")) && numel(part(h.axes, "waveName")) == 3, 'sites off, unit names on');
Rw4 = Rw;
Rw4.probe = struct('chanMap', (0:6).', 'xc', [0 0 0 200 200 200 0].', 'yc', [0 50 100 0 50 100 400].', 'kcoords', [0 0 0 1 1 1 2].');
h = renderWaveforms(Rw4, fig11, Layout="probe");
check(isequal(part(h.axes, "waveSites").XData(:), Rw4.probe.xc) && numel(part(h.axes, "shankLabels")) == 2, ...
    'probe: a site parked on a kcoords group of its own stays at its own x, on its shank; one name per shank');
Rw2 = Rw; Rw2.meta.x(2) = NaN;
h = renderWaveforms(Rw2, fig11, Layout="probe");
lb = part(h.axes, "waveLabel");
check(nnz(isnan(part(h.axes, "waveMean").XData)) == 2 && isscalar(lb) && contains(string(lb.String), "1 unit(s) without a probe position"), ...
    'a unit without a position is left out, and the panel says so');
Rw3 = Rw; Rw3.waveforms.from(:) = "template"; Rw3.waveforms.spikes(:) = {[]};
h = renderWaveforms(Rw3, fig11, Waveform=struct('mode', "subsample"));
check(all(arrayfun(@(a) isscalar(part(a, "waveMean")) && isempty(part(a, "waveSpikes")) && endsWith(part(a, "waveLabel").String, "(template)"), h.axes)), ...
    'templates are drawn as the mean whatever the mode, and say so');
check(strcmp(errorId(@() renderWaveforms(rmfield(Rw, 'waveforms'), fig11)), 'renderWaveforms:NoWaveforms'), ...
    'a result without waveforms: renderWaveforms:NoWaveforms');
delete(fig11);

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
sdOf = @(v) std(v, 0, 1, 'omitnan');
check(abs(Fr.err.hi(1, 1) - Fr.meanRate(1, 1) - sdOf(Fr.rate(gE == 1, 1))) < 1e-9 ...
    && abs(Tu.err.hi(1, 2, 1) - Tu.mean(1, 2, 1) - sdOf(Fr.rate(mod((1:numel(tE)).', 3) == 0, 2))) < 1e-9, ...
    'firingRate and tuningCurve make the error over each mean''s epochs');

if haveBoot
    Xm = [1; 2; 3; 4; 100];
    [mlo, mhi] = errorBounds(Xm, 1, "ci95", 300, "median");
    [slo, shi] = errorBounds(Xm, 1, "sem", [], "median");
    [ilo, ihi] = errorBounds(Xm, 1, "iqr");
    check(mlo >= 1 && mlo <= 3 && mhi >= 3 && mhi <= 100 && abs((slo + shi) / 2 - 3) < 1e-12 ...
        && abs(ilo - prctile(Xm, 25)) < 1e-12 && abs(ihi - prctile(Xm, 75)) < 1e-12, ...
        'errorBounds with the median: its bootstrap CI, SEM centered on it; "iqr": the 25th and 75th percentiles');
end

fprintf('\n== across sessions: sessionTable, combineSessions; the data export ==\n');
sessionChecks(@check, @errorId);

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisCompute:Failures', '%d checks failed.', nFail);
end
end


function sessionChecks(check, errorId)
%sessionChecks  sessionTable and combineSessions (every kind a figure layer merges, every error) on hand-made
%   results, the unit-mapping CSV and writeAnalysisData.
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
specP = struct('kind', "psth", 'id', "p");   % what a result carries as its spec (combineSessions keeps the first's)
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

% --- data export: the mapping CSV, writeAnalysisData ---------------------------------------------
fprintf('\n== data export: mapping CSV, writeAnalysisData ==\n');
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
check(isequaln(Rm1.rate, Rm2.rate) && isequal(Rm1.tiles.key, Rm2.tiles.key) && isequal(Rm2.tiles.key, ["cellA"; "cellB"; "c,d"]) ...
    && isequal(Rm2.tiles.nUnits, [1 1; 2 0; 0 1]), ...
    'a written and read mapping gives the tiles the table does');
bad = fullfile(dxDir, 'bad.csv');
writelines(["a,b"; "1,2"], bad);
Mcase = readUnitMapping(writeUnitMapping(fullfile(dxDir, 'case.csv'), table("x", 1, 'VariableNames', ["cell" "k"])));
check(strcmp(errorId(@() readUnitMapping(bad)), 'readUnitMapping:NoCell') ...
    && strcmp(errorId(@() readUnitMapping(fullfile(dxDir, 'none.csv'))), 'readUnitMapping:NoFile') ...
    && strcmp(errorId(@() writeUnitMapping(fullfile(dxDir, 'x.csv'), table(1, 'VariableNames', "a"))), 'writeUnitMapping:NoCell') ...
    && strcmp(errorId(@() writeUnitMapping(mf, M3, Overwrite=false)), 'writeUnitMapping:Exists') && Mcase.cell == "x", ...
    'mapping errors: readUnitMapping:NoCell / :NoFile, writeUnitMapping:NoCell / :Exists');

% writeAnalysisData
Sx = struct('schema', "ephys-analysis-session-figure/1", 'figure', "card", 'sessions', S(1:2, :), ...
    'results', struct('index', 1, 'label', "all", 'status', "done", 'F', combineSessions(P(1:2), S(1:2, :))), ...
    'perSession', {P(1:2)}, 'config', struct('Name', "t"), 'created', "2026-10-15 12:00:00");
df = fullfile(dxDir, 'data', 'sd');
out = writeAnalysisData(df, Sx);
L = load(out);
check(out == df + ".mat" && isfile(out) && isequal(sort(fieldnames(L)), sort(fieldnames(Sx))) && L.schema == Sx.schema ...
    && isequal(L.sessions.label, Sx.sessions.label) && L.results(1).F.kind == "psth" ...
    && isequaln(L.results(1).F.rate, Sx.results(1).F.rate) && isequaln(L.perSession{1}.rate, P{1}.rate) ...
    && isempty(dir(fullfile(dxDir, 'data', '~*'))), ...
    'writeAnalysisData: ".mat" added, the struct''s fields are the file''s variables (load gives them back), no temp file left');
out7 = writeAnalysisData(fullfile(dxDir, 'v7.mat'), Sx, MatVersion="-v7");
L7 = load(out7);
check(strcmp(errorId(@() writeAnalysisData(out, Sx)), 'writeAnalysisData:Exists') && writeAnalysisData(out, Sx, Overwrite=true) == out ...
    && numel(L7.results) == 1 && isequaln(L7.results(1).F.rate, Sx.results(1).F.rate), ...
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
