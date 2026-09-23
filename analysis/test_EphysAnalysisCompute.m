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
%   figure (tiled layout), including renderPlot's pages and titles, and
%   binCounts / countBelow against brute force.
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
sd = 0.002;                                   % a 2 ms Gaussian bump centred on each event's sample, (row-1)/Fs
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
    "unit correlation",    @(tg) renderCorrMap(Rc, tg, Order="channel")
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
h = renderPSTH(Rd, f6, Stack=true, Style=struct('ShowSEM', false));
ax = h.axes(1);
pk = reshape(max(Rd.rate(:, 1, :), [], 1), [], 1);
stp = 1.1 * max(pk);
yyaxis(ax, 'right'); rt = ax.YTick; rl = string(ax.YTickLabel); ylR = ax.YLim;
yyaxis(ax, 'left');  lt = ax.YTick; ll = string(ax.YTickLabel); llab = string(ax.YLabel.String); ylL = ax.YLim;
[srt, o] = sort((0:2).' * stp + pk);
check(numel(h.axes) == 3 && all(abs(h.step - 1.1 * reshape(max(Rd.rate, [], [1 3]), 1, [])) < 1e-9) && abs(h.step(1) - stp) < 1e-9, ...
    'each unit''s row step is Spacing (1.1) x its tallest PSTH');
check(numel(ax.YAxis) == 2 && max(abs(lt - (0:2) * stp)) < 1e-9 && isequal(ll(:), ["0"; "0.5"; "1"]) && llab == "Depth", ...
    'left axis: a tick at each row''s baseline, first group at the bottom, labelled with its Depth value');
check(max(abs(rt(:) - srt)) < 1e-9 && isequal(rl(:), compose("%.3g", pk(o))) && isequal(ylL, ylR), ...
    'right axis: a tick where each row peaks, labelled with its peak rate, on the same limits as the left');
check(isempty(ax.Legend) && contains(string(h.axes(2).YAxis(2).Label.String), "Peak (spikes/s)") ...
    && string(h.axes(1).YAxis(2).Label.String) == "", 'no legend; "Peak (spikes/s)" names the right axis of the last column');
check(all(strcmp(get(findall(ax, 'Type', 'line'), 'Marker'), 'none')), 'no markers from the yyaxis line-style cycle');
check(all(strcmp({h.rasterAxes.YDir}, 'normal')), 'the raster above a stack is flipped: first group at the bottom, as the rows');
pa = findobj(ax, 'Type', 'patch');
check(numel(pa) == 3 && all([pa.FaceAlpha] == 1), 'stacked rows are opaque by default');
yl0 = ylL;
h = renderPSTH(Rd, f6, Stack=true, Spacing=0.5, Style=struct('ShowSEM', false, 'YLim', [0 1]));
ax = h.axes(1);
check(abs(h.step(1) - 0.5 * max(pk)) < 1e-9 && max(abs(ax.YTick - (0:2) * 0.5 * max(pk))) < 1e-9 && ax.YLim(2) < yl0(2) ...
    && ax.YLim(2) > 1, 'Spacing 0.5 overlaps the rows; a stack ignores YLim');
h = renderPSTH(Rd, f6, Stack=true, Normalize="groupPeak", Style=struct('ShowSEM', false));
ax = h.axes(1);
yyaxis(ax, 'right'); rt = ax.YTick; rl = string(ax.YTickLabel); yyaxis(ax, 'left');
check(abs(h.step(1) - 1.1) < 1e-9 && max(abs(sort(rt(:)) - ((0:2).' * 1.1 + 1))) < 1e-9 && isequal(sort(rl(:)), sort(compose("%.3g", pk))), ...
    'groupPeak: every row peaks at 1 x its step unit; the right axis still gives each row''s peak rate');
h = renderPSTH(Rd, f6, Normalize="unitPeak", Stack=false, Style=struct('ShowSEM', false));
ax = h.axes(1);
yd = get(findobj(ax, 'Type', 'patch'), 'YData');
check(abs(max(cellfun(@max, yd)) - 1) < 1e-9 && string(ax.YLabel.String) == "Normalized (unit peak = 1)", ...
    'unitPeak unstacked: the tallest group reaches 1, and the y label says so');
h = renderPSTH(Rd, f6, Layout="overlay", Normalize="unitPeak", Stack=true, Style=struct('ShowSEM', false));
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
check(okC, 'binCounts (one vectorized pass) = histcounts per event: counts, raster times and events, spikes on bin edges included');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisCompute:Failures', '%d checks failed.', nFail);
end
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
E = table((1:n).', NaN(n, 1), t0, tc, NaN(n, 1), t0 - 0.2, t0 + 0.5, repmat(0.7, n, 1), true(n, 1), g, "group " + g, ...
    'VariableNames', {'epoch', 'trial', 't0', 't0Continuous', 't1', 'tStart', 'tStop', 'duration', 'complete', 'groupIndex', 'group'});
end


function [c, rel, ep] = binCountsRef(s, t0, edges)
%binCountsRef  binCounts the slow way: each event's spikes by comparison, histcounts per event.
s = sort(s(:));
c = zeros(numel(edges) - 1, numel(t0));
rel = zeros(0, 1); ep = zeros(0, 1);
for e = 1:numel(t0)
    r = s(s >= t0(e) + edges(1) & s < t0(e) + edges(end)) - t0(e);
    c(:, e) = histcounts(r, edges).';
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
