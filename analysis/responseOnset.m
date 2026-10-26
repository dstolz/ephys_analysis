function O = responseOnset(R, opts)
%responseOnset  A unit's response onset from its PSTH by CUSUM: when its rate rises above the baseline and stays up.
%   O = responseOnset(R, Name=Value) finds, for every unit asked for, the
%   time its peri-event histogram departs upward from its baseline: once
%   over every epoch of R (the unit's onset) and once over each trial
%   group's epochs. It reads R.raster (spikePSTH with Raster=true, or a
%   result merged across sessions by combineSessions), the spike times the
%   raster draws, relative to each epoch's event, so the onset and the
%   raster agree. Pure: no I/O, no graphics. A figure computes it once per
%   unit and alignment for every panel that draws it (figureLatencies,
%   from the figure's latency block, defaults("Latency")).
%
%   The histogram: the spikes counted in bins of BinSec on a grid through
%   the event (a bin edge at 0; a spike on an edge in the bin that starts
%   there, as binCounts), inside the raster's span R.edges([1 end]), as a
%   rate x_i over the epochs counted (spikes/s). Its baseline: the bins
%   inside the Baseline window (default: the part before the event), their
%   mean m and standard deviation s (a baseline without a spike has s = 0:
%   s is then the rate one spike in one bin makes, 1 / (nEpochs x BinSec)).
%   The cumulative sum (CUSUM) of the bins in the search window
%   [MinSec, MaxSec] is Page's one-sided form (Page 1954, Biometrika
%   41:100-115), as Ellaway (1978, Electroencephalogr Clin Neurophysiol
%   45:302-304) applied the cumulative sum to a PSTH: each bin adds its
%   departure from the baseline in baseline SDs less an allowance,
%   C_i = max(0, C_(i-1) + (x_i - m) / s - Drift), C_0 = 0, so it stays near
%   zero while the rate is the baseline's (Drift 0: the plain cumulative
%   excess over the baseline mean, floored at zero). The onset is found
%   where C first reaches Threshold (in baseline SDs) and stays up and
%   rising: over the next SustainSec C never falls under Threshold and ends
%   higher than it was. A crossing that does not last is passed over, and
%   the scan goes on. The onset is then the start of the rise: the left
%   edge of the bin after the last bin before the crossing where C was 0
%   (Page's estimate of the change point; the search window's start when C
%   never was). No crossing that lasts: NaN.
%
%   Options
%     Units       the raster's units (indices into R.raster), default every
%                 one
%     MinSec      the search window's start, s from the event (default 0)
%     MaxSec      its end, s (default Inf: the window's end); both clipped
%                 to the raster's span
%     Baseline    [] (default: before the event) or [lo hi] s, clipped to
%                 the raster's span; the bins wholly inside it are counted
%     BinSec      the histogram's bins, s (default 0.002)
%     Threshold   the CUSUM's threshold, baseline SDs (default 5)
%     Drift       the allowance taken from each bin, baseline SDs
%                 (default 1: on a synthetic Poisson baseline it keeps C at
%                 zero, where 0.5 lets it wander up and the onset comes
%                 early)
%     SustainSec  how long the CUSUM must stay over the threshold and
%                 rising, s (default 0.005; rounded to whole bins, 0 = the
%                 crossing alone)
%
%   O fields
%     onset          [1 x nUnits] the onset over every epoch, s from the
%                    event (NaN: none)
%     groupOnset     [nGroups x nUnits] the onset over each group's epochs
%                    (NaN: none, or a group without epochs)
%     t              [nBins x 1] the left edge of each bin searched, s
%     cusum          [nBins x nUnits] C over every epoch, in those bins
%     baselineMean   [1 x nUnits] m over every epoch, spikes/s
%     baselineSD     [1 x nUnits] s over every epoch, spikes/s
%     window         [lo hi] the search window, after clipping
%     baseline       [lo hi] the baseline window, after clipping
%     settings       a struct of MinSec, MaxSec, Baseline, BinSec,
%                    Threshold, Drift and SustainSec, as asked
%     units, labels, groups   as firstSpikeLatency's
%
%   Errors: responseOnset:NoRaster (R holds no raster rows),
%   responseOnset:BadWindow (MinSec > MaxSec, either not a number, or a
%   window that holds no whole bin), responseOnset:NoBaseline (no whole
%   bin inside the baseline window), responseOnset:BadUnit.
%
%   See also firstSpikeLatency, figureLatencies, spikePSTH, binCounts.

arguments
    R (1,1) struct
    opts.Units double = []
    opts.MinSec (1,1) double = 0
    opts.MaxSec (1,1) double = Inf
    opts.Baseline double = []
    opts.BinSec (1,1) double {mustBePositive, mustBeFinite} = 0.002
    opts.Threshold (1,1) double {mustBePositive} = 5
    opts.Drift (1,1) double {mustBeNonnegative} = 1
    opts.SustainSec (1,1) double {mustBeNonnegative} = 0.005
end

kept = isfield(R, 'raster') && isfield(R, 'epochGroup') && isfield(R, 'edges');
if kept && isfield(R, 'params') && isstruct(R.params) && isfield(R.params, 'Raster') && ~R.params.Raster
    kept = false;
end
if kept && isempty(R.raster) && isfield(R, 'rate') && size(R.rate, 2) > 0
    kept = false;
end
if ~kept
    error('responseOnset:NoRaster', 'The result holds no raster rows (R.raster): compute it with spikePSTH(..., Raster=true).');
end
nU0 = numel(R.raster);
units = reshape(opts.Units, 1, []);
if isempty(opts.Units); units = 1:nU0; end
if any(units < 1 | units > nU0 | units ~= round(units))
    error('responseOnset:BadUnit', 'Units must be indices of the raster''s %d units.', nU0);
end
tol = 1e-9;
W = R.edges([1 end]);
b = opts.BinSec;
edges = (ceil((W(1) - tol) / b):floor((W(2) + tol) / b)) * b;   % a grid through the event, inside the span
if numel(edges) < 2
    error('responseOnset:BadWindow', 'The raster''s span [%g %g] s holds no whole bin of %g s.', W(1), W(2), b);
end
left = edges(1:end-1).';
right = edges(2:end).';
lo = max(opts.MinSec, W(1));
hi = min(opts.MaxSec, W(2));
if isnan(opts.MinSec) || isnan(opts.MaxSec) || opts.MinSec > opts.MaxSec
    error('responseOnset:BadWindow', 'The onset window [%g %g] s needs MinSec <= MaxSec.', opts.MinSec, opts.MaxSec);
end
det = left >= lo - tol & right <= hi + tol;
if ~any(det)
    error('responseOnset:BadWindow', 'The onset window [%g %g] s holds no whole bin of %g s.', lo, hi, b);
end
B = opts.Baseline;
if isempty(B); B = [W(1) 0]; end
B = [max(B(1), W(1)) min(B(end), W(2))];
base = left >= B(1) - tol & right <= B(2) + tol;
if ~any(base)
    error('responseOnset:NoBaseline', 'The baseline window [%g %g] s holds no whole bin of %g s of the raster''s span.', ...
        B(1), B(2), b);
end
sustain = round(opts.SustainSec / b);

grp = double(R.epochGroup(:));
nE = numel(grp);
G = [];
if isfield(R, 'groups'); G = R.groups; end
nG = max([0; grp(isfinite(grp))]);
if istable(G); nG = max(nG, height(G)); end
nB = numel(left);
nU = numel(units);
onset = NaN(1, nU);
groupOnset = NaN(nG, nU);
cusum = NaN(nnz(det), nU);
mu = NaN(1, nU);
sd = NaN(1, nU);
for k = 1:nU
    t = double(R.raster(units(k)).times(:));
    ep = double(R.raster(units(k)).epoch(:));
    bin = discretize(t + tol, edges);   % [a, b): a spike on an edge in the bin starting there
    ok = ~isnan(bin) & ep >= 1 & ep <= nE & ep == round(ep);
    C = accumarray([bin(ok) ep(ok)], 1, [nB max(nE, 1)]);
    [onset(k), cusum(:, k), mu(k), sd(k)] = onsetOf(sum(C, 2), nE, b, base, det, left, opts, sustain);
    for g = 1:nG
        in = grp == g;
        if ~any(in); continue; end
        groupOnset(g, k) = onsetOf(sum(C(:, in), 2), nnz(in), b, base, det, left, opts, sustain);
    end
end
labels = strings(1, nU);
if isfield(R, 'labels') && numel(R.labels) >= max([units 0]); labels = reshape(string(R.labels(units)), 1, []); end
settings = struct('MinSec', opts.MinSec, 'MaxSec', opts.MaxSec, 'Baseline', opts.Baseline, 'BinSec', b, ...
    'Threshold', opts.Threshold, 'Drift', opts.Drift, 'SustainSec', opts.SustainSec);
O = struct('onset', onset, 'groupOnset', groupOnset, 't', left(det), 'cusum', cusum, 'baselineMean', mu, ...
    'baselineSD', sd, 'window', [lo hi], 'baseline', B, 'settings', settings, 'units', units, 'labels', labels, 'groups', G);
end


function [onset, S, m, s] = onsetOf(counts, nEp, b, base, det, left, opts, sustain)
%onsetOf  The CUSUM onset of one histogram (COUNTS per bin over NEP epochs); S the CUSUM over the searched bins.
onset = NaN;
x = counts / (max(nEp, 1) * b);   % spikes/s
m = mean(x(base));
s = 0;
if nnz(base) > 1; s = std(x(base)); end
if ~(s > 0); s = 1 / (max(nEp, 1) * b); end   % no spread in the baseline: the rate of one spike in one bin
z = (x(det) - m) / s - opts.Drift;
n = numel(z);
S = zeros(n, 1);
c = 0;
for i = 1:n
    c = max(0, c + z(i));
    S(i) = c;
end
if nEp == 0; return; end
t = left(det);
h = opts.Threshold;
for i = find(S >= h).'
    j = i + sustain;
    if j > n; break; end   % no room left to see it last
    if sustain > 0 && ~(all(S(i:j) >= h) && S(j) > S(i)); continue; end
    z0 = find(S(1:i-1) == 0, 1, 'last');   % the last bin at zero before the crossing: the rise starts after it
    if isempty(z0); z0 = 0; end
    onset = t(z0 + 1);
    return
end
end
