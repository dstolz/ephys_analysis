function R = evokedPotential(Y, fs, E, opts)
%evokedPotential  Event-locked average of continuous channels, per group.
%   R = evokedPotential(Y, FS, E, Name=Value) cuts every epoch of E
%   (epochTable) out of the signal Y ([nSamples x nChan], row k at
%   t = (k-1)/FS) and averages them per group. Pure: no I/O, no graphics.
%
%   Epoch e covers rows round(t0(e) * FS) + (s0:s1) with s0 = round(pre*FS)
%   and s1 = round(post*FS): the "event" onset rule of
%   ChronuxDataset.trials and the pairing's TrialOnsetSample_<SIG>, under
%   which a digital-event time t = row/Fs maps back to the sample that
%   produced it. R.t = (s0:s1)'/FS.
%
%   Options
%     Window      [pre post] s (default [-0.1 0.5])
%     Channels    columns of Y to use (default all)
%     Labels      one label per used channel
%     Baseline    [b0 b1] s: subtract each epoch's mean over this span
%                 (per channel); [] = none
%     Detrend     remove each epoch's linear trend (per channel) first
%     Incomplete  "drop" (default): drop epochs that leave the signal or
%                 hold non-finite samples; "nan": keep them, NaN outside
%                 (the average then ignores the missing samples)
%     KeepEpochs  keep the epochs in R.data [nTime x nChan x nKept] (single)
%     Groups      groups table (epochTable); default from E
%     Meta        channel table (selectChannels)
%     Units       unit of Y (default "uV")
%
%   R fields: kind "evoked", t, mean / sem [nTime x nChan x nGroups],
%   nEpochs [nGroups x 1] (kept), data, channels, labels, fs, units,
%   sampleOffsets [s0 s1], onsetRule "event", keptEpochs (rows of E),
%   droppedEdge, droppedNonFinite, groups, meta, n (= nEpochs), params,
%   created.
%
%   See also epochTable, selectChannels, renderEvoked, renderHeatmap.

arguments
    Y {mustBeNumeric}
    fs (1,1) double {mustBePositive}
    E table
    opts.Window (1,2) double = [-0.1 0.5]
    opts.Channels (1,:) double = []
    opts.Labels (1,:) string = string.empty(1,0)
    opts.Baseline double = []
    opts.Detrend (1,1) logical = false
    opts.Incomplete (1,1) string {mustBeMember(opts.Incomplete, ["drop" "nan"])} = "drop"
    opts.KeepEpochs (1,1) logical = false
    opts.Groups = []
    opts.Meta = []
    opts.Units (1,1) string = "uV"
end

ch = opts.Channels;
if isempty(ch); ch = 1:size(Y, 2); end
if any(ch < 1 | ch > size(Y, 2))
    error('evokedPotential:BadChannels', 'Channels must be columns 1..%d of Y.', size(Y, 2));
end
W = opts.Window;
if ~(W(2) > W(1))
    error('evokedPotential:BadWindow', 'Window must be [pre post] with pre < post.');
end
s0 = round(W(1) * fs);
s1 = round(W(2) * fs);
t = (s0:s1).' / fs;
nT = numel(t);
nC = numel(ch);
b = opts.Baseline;
useBase = ~isempty(b);
if useBase
    if numel(b) ~= 2 || ~(b(2) >= b(1))
        error('evokedPotential:BadBaseline', 'Baseline must be [b0 b1] with b0 <= b1.');
    end
    inBase = t >= b(1) - 1e-12 & t <= b(2) + 1e-12;
    if ~any(inBase)
        error('evokedPotential:BadBaseline', 'Baseline [%g %g] s holds no sample of the window.', b(1), b(2));
    end
end

G = groupsFor(E, opts.Groups);
nG = height(G);
nE = height(E);
base = round(E.t0 * fs);
S = zeros(nT, nC, nG); SS = zeros(nT, nC, nG); N = zeros(nT, nC, nG);
kept = false(nE, 1);
dropEdge = 0; dropNonFinite = 0;
if opts.KeepEpochs; data = zeros(nT, nC, nE, 'single'); else; data = []; end
Ysel = Y(:, ch);
for e = 1:nE
    [X, inside] = epochSamples(Ysel, base(e), s0, s1);
    if opts.Incomplete == "drop"
        if ~inside; dropEdge = dropEdge + 1; continue; end
        if any(~isfinite(X(:))); dropNonFinite = dropNonFinite + 1; continue; end
    end
    if opts.Detrend
        X = detrendNaN(X, t);
    end
    if useBase
        X = X - mean(X(inBase, :), 1, 'omitnan');
    end
    g = E.groupIndex(e);
    ok = isfinite(X);
    X0 = X; X0(~ok) = 0;
    S(:, :, g) = S(:, :, g) + X0;
    SS(:, :, g) = SS(:, :, g) + X0 .^ 2;
    N(:, :, g) = N(:, :, g) + ok;
    kept(e) = true;
    if opts.KeepEpochs; data(:, :, e) = single(X); end
end
M = S ./ N;
V = (SS - S .^ 2 ./ N) ./ (N - 1);
SE = sqrt(max(V, 0)) ./ sqrt(N);
SE(N < 2) = NaN;
M(N == 0) = NaN;
if opts.KeepEpochs; data = data(:, :, kept); end

R = struct();
R.kind = "evoked";
R.t = t;
R.mean = M;
R.sem = SE;
R.nEpochs = accumarray(E.groupIndex(kept), 1, [nG 1]);
R.data = data;
R.channels = ch(:);
labels = opts.Labels;
if isempty(labels) && istable(opts.Meta) && height(opts.Meta) == nC && ismember("label", string(opts.Meta.Properties.VariableNames))
    labels = opts.Meta.label;
end
if numel(labels) ~= nC; labels = "ch" + ch(:); end
R.labels = reshape(string(labels), [], 1);
R.fs = fs;
R.units = opts.Units;
R.sampleOffsets = [s0 s1];
R.onsetRule = "event";
R.keptEpochs = E.epoch(kept);
R.droppedEdge = dropEdge;
R.droppedNonFinite = dropNonFinite;
R.groups = G;
R.meta = opts.Meta;
R.n = R.nEpochs;
R.params = struct('Window', W, 'Baseline', b, 'Detrend', opts.Detrend, 'Incomplete', opts.Incomplete);
R.created = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end


function X = detrendNaN(X, t)
%detrendNaN  Remove a least-squares line from each column (finite samples).
A = [t ones(size(t))];
for c = 1:size(X, 2)
    ok = isfinite(X(:, c));
    if nnz(ok) < 2; continue; end
    p = A(ok, :) \ X(ok, c);
    X(:, c) = X(:, c) - A * p;
end
end
