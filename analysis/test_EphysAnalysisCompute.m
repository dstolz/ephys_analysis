function test_EphysAnalysisCompute()
%test_EphysAnalysisCompute  Verification suite for the compute and render functions.
%   No recording is needed: seeded Poisson spike trains and synthetic
%   signals check spikePSTH (rates, SEM, half-open bins, baseline, smoothing,
%   stop masking, rasters), firingRate ("between" windows, baselines),
%   tuningCurve, evokedPotential (the event onset rule, NaN padding and drop
%   counts, baseline), the trial-filter compiler, and that every renderer
%   draws into a classic figure's axes, a uifigure's uiaxes and a figure
%   (tiled layout), including renderPlot's pages and titles.
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

fprintf('\n== 4. evokedPotential: the event rule, padding, baseline ==\n');
fs = 1000;
Y = single(0.01 * randn(20000, 3));
tEv = [0.05; 3.0005; 7.2; 12.001];            % digital-event times (row/Fs)
rows = round(tEv * fs);
Y(rows(2:end), 2) = 100;
Ev = epochs(tEv, [1; 1; 2; 2]);
Rv = evokedPotential(Y, fs, Ev, Window=[-0.1 0.2]);
k0 = find(Rv.t == 0);
check(Rv.droppedEdge == 1 && isequal(Rv.nEpochs, [1; 2]) && isequal(Rv.keptEpochs, [2; 3; 4]) ...
    && abs(Rv.mean(k0, 2, 1) - 100) < 0.1 && abs(Rv.mean(k0, 2, 2) - 100) < 0.1 ...
    && max(abs(Rv.mean([1:k0-1 k0+1:end], 2, 2))) < 0.1 && isequal(Rv.sampleOffsets, [-100 200]) && numel(Rv.t) == 301, ...
    'the deflection at row round(t*Fs) sits at t = 0; the epoch leaving the signal is dropped');
Rn = evokedPotential(Y, fs, Ev, Window=[-0.1 0.2], Incomplete="nan", KeepEpochs=true);
check(Rn.droppedEdge == 0 && isequal(Rn.nEpochs, [2; 2]) && all(isnan(Rn.data(1:51, 1, 1))) && ~any(isnan(Rn.data(52:end, 1, 1))) ...
    && size(Rn.data, 3) == 4 && isa(Rn.data, 'single'), 'Incomplete "nan" keeps it, NaN before the recording start');
Yo = Y + 50;
Yo(1950:2050, 3) = NaN;
Rb = evokedPotential(Yo, fs, epochs([2; 3.0005; 7.2], [1; 1; 1]), Window=[-0.1 0.2], Baseline=[-0.1 -0.01], Channels=[2 3]);
check(abs(Rb.mean(k0, 1) - 100) < 0.2 && max(abs(Rb.mean(1:90, 1))) < 0.1 && Rb.droppedNonFinite == 1 ...
    && isequal(Rb.channels, [2; 3]) && Rb.nEpochs == 2, 'baseline subtraction; epochs with NaN samples are dropped and counted');

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
Rq = probeMapValues(Tu, probe, Value="rate");
check(isequal(Rq.value([1 3 5]), [1; 3; 2]) && all(isnan(Rq.value([2 4 6 7 8]))), 'probeMapValues puts each unit''s rate on its site');
Rq0 = probeMapValues(Tu, probe, Value="nUnits");
check(sum(Rq0.value) == 3 && Rq0.value(2) == 0, 'nUnits counts the units per site');
cases = {
    "psth grid + raster",  @(tg) renderPSTH(Rp, tg, Layout="grid", WithRaster=true)
    "psth overlay",        @(tg) renderPSTH(Rp, tg, Layout="overlay")
    "psth line",           @(tg) renderPSTH(Rp, tg, Layout="grid", HistStyle="line")
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
h = renderPlot(Rp, spec, axes(figure('Visible', 'off')));
kids = h.axes(1).Children;
check(spec.histStyle == "bar" && any(arrayfun(@(c) isa(c, 'matlab.graphics.chart.primitive.Bar'), kids)), 'a PSTH draws bars by default');
close(h.axes(1).Parent);
spec.histStyle = "line";
h = renderPlot(Rp, spec, axes(figure('Visible', 'off')));
kids = h.axes(1).Children;
check(~any(arrayfun(@(c) isa(c, 'matlab.graphics.chart.primitive.Bar'), kids)) && any(arrayfun(@(c) isa(c, 'matlab.graphics.chart.primitive.Line'), kids)), 'histStyle "line" draws traces');
close(h.axes(1).Parent);
check(EphysAnalysisConfig.defaults("Plot").bins.SmoothSec == 0.01, 'PSTHs are smoothed with a 10 ms Gaussian by default');
cap = plotCaption(EphysAnalysisConfig.normalizePlot(struct('kind', "psth")), Rp);
check(startsWith(cap, "PSTH") && contains(cap, "bins 20 ms") && contains(cap, "3 sorted unit(s)"), "plotCaption: " + cap);

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


function E = epochs(t0, g)
%epochs  A minimal epochTable-shaped table for fixed windows.
t0 = t0(:); g = g(:);
n = numel(t0);
E = table((1:n).', NaN(n, 1), t0, NaN(n, 1), t0 - 0.2, t0 + 0.5, repmat(0.7, n, 1), true(n, 1), g, "group " + g, ...
    'VariableNames', {'epoch', 'trial', 't0', 't1', 'tStart', 'tStop', 'duration', 'complete', 'groupIndex', 'group'});
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
