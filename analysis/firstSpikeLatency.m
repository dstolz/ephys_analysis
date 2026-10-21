function L = firstSpikeLatency(R, opts)
%firstSpikeLatency  Each epoch's first-spike latency from a spikePSTH result's raster rows.
%   L = firstSpikeLatency(R, Name=Value) finds, for every epoch (row of
%   R.epochs; R.epochGroup gives each one's trial group) and every unit
%   asked for, the first spike at or after MinSec and at or before MaxSec,
%   in s from the epoch's aligned event. It reads R.raster (spikePSTH with
%   Raster=true, or a result merged across sessions by combineSessions):
%   the very spike times the raster draws, already taken relative to each
%   epoch's event on the spikes' clock (spikePSTH: spike k at (k-1)/Fs, the
%   event at its t0Continuous, so a spike in the event's own sample is at
%   0), with the stop mask applied when the panel masks after the stop
%   event. Nothing is aligned again here, so a latency and the tick it
%   marks agree. Epochs an artifact period dropped are not in R (epochTable
%   left them out); an epoch with no spike in the window has NaN. Pure: no
%   I/O, no graphics.
%
%   The search window is [MinSec, MaxSec] with both ends included (within
%   1e-9 s, the rounding of a spike and an event on one sample grid, as
%   binCounts), clipped to the span the raster holds, R.edges([1 end]):
%   the raster keeps spikes in [edges(1), edges(end)), so a MaxSec at or
%   past the window's end means "up to the window's end" (Inf, the
%   default, says so).
%
%   Options
%     Units    the raster's units (indices into R.raster), default every one
%     MinSec   the earliest latency, s from the event (default 0)
%     MaxSec   the latest, s (default Inf: the window's end)
%
%   L fields
%     lat         [nEpochs x nUnits] the first spike's latency, s (NaN: none)
%     spikeTime   [nEpochs x nUnits] that spike's time on the continuous
%                 clock, lat + R.epochs.t0Continuous (NaN where lat is, or
%                 everywhere when R.epochs has no t0Continuous, as a result
%                 merged across sessions)
%     window      [lo hi] the window searched, after clipping
%     units       the units, as asked (a row)
%     labels      their labels (R.labels; "" without them)
%     epochGroup  [nEpochs x 1] each epoch's group (R.epochGroup)
%     groups      R.groups
%     n           [nGroups x nUnits] the epochs of each group with a first
%                 spike
%     nEpochs     [nGroups x 1] the epochs of each group
%
%   Errors: firstSpikeLatency:NoRaster (R holds no raster rows: spikePSTH
%   with Raster=false, or a merged result whose sessions had none),
%   firstSpikeLatency:BadWindow (MinSec > MaxSec, or
%   either not a number), firstSpikeLatency:BadUnit.
%
%   See also spikePSTH, rasterInto, drawPsthPanel, combineSessions.

arguments
    R (1,1) struct
    opts.Units double = []
    opts.MinSec (1,1) double = 0
    opts.MaxSec (1,1) double = Inf
end

kept = isfield(R, 'raster') && isfield(R, 'epochGroup') && isfield(R, 'edges');
if kept && isfield(R, 'params') && isstruct(R.params) && isfield(R.params, 'Raster') && ~R.params.Raster
    kept = false;   % spikePSTH(..., Raster=false): the rows are there, empty
end
if kept && isempty(R.raster) && isfield(R, 'rate') && size(R.rate, 2) > 0
    kept = false;   % merged across sessions without the members' rows
end
if ~kept
    error('firstSpikeLatency:NoRaster', ['The result holds no raster rows (R.raster): compute it with ' ...
        'spikePSTH(..., Raster=true).']);
end
lo = opts.MinSec;
hi = opts.MaxSec;
if isnan(lo) || isnan(hi) || lo > hi
    error('firstSpikeLatency:BadWindow', 'The latency window [%g %g] s needs MinSec <= MaxSec.', lo, hi);
end
nU0 = numel(R.raster);
units = reshape(opts.Units, 1, []);
if isempty(opts.Units); units = 1:nU0; end
if any(units < 1 | units > nU0 | units ~= round(units))
    error('firstSpikeLatency:BadUnit', 'Units must be indices of the raster''s %d units.', nU0);
end
W = R.edges([1 end]);
lo = max(lo, W(1));
hi = min(hi, W(2));
tol = 1e-9;   % s: a spike and an event on one sample grid, equal up to rounding (binCounts)

grp = double(R.epochGroup(:));
nE = numel(grp);
nU = numel(units);
lat = NaN(nE, nU);
for k = 1:nU
    t = double(R.raster(units(k)).times(:));
    ep = double(R.raster(units(k)).epoch(:));
    in = t >= lo - tol & t <= hi + tol & ep >= 1 & ep <= nE;
    if any(in)
        lat(:, k) = accumarray(ep(in), t(in), [nE 1], @min, NaN);
    end
end

spikeTime = NaN(nE, nU);
if isfield(R, 'epochs') && istable(R.epochs) && height(R.epochs) == nE ...
        && ismember('t0Continuous', R.epochs.Properties.VariableNames)
    spikeTime = lat + double(R.epochs.t0Continuous(:));
end

G = [];
if isfield(R, 'groups'); G = R.groups; end
nG = max([0; grp(isfinite(grp))]);
if istable(G); nG = max(nG, height(G)); end
okG = isfinite(grp) & grp >= 1 & grp <= nG & grp == round(grp);
nEpochs = accumarray(grp(okG), 1, [nG 1]);
n = zeros(nG, nU);
for k = 1:nU
    have = okG & isfinite(lat(:, k));
    n(:, k) = accumarray(grp(have), 1, [nG 1]);
end
labels = strings(1, nU);
if isfield(R, 'labels') && numel(R.labels) >= max([units 0]); labels = reshape(string(R.labels(units)), 1, []); end

L = struct('lat', lat, 'spikeTime', spikeTime, 'window', [lo hi], 'units', units, 'labels', labels, ...
    'epochGroup', grp, 'groups', G, 'n', n, 'nEpochs', nEpochs);
end
