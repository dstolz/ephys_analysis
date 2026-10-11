function M = syntheticModel(S, D, Fs, nSamp, nCh, opts)
%syntheticModel  Resolve a SyntheticDesign against a schedule: spike trains, evoked potentials, the signal.
%   M = syntheticModel(S, D, Fs, nSamp, nCh) draws, from the current random
%   stream, the spike times of design D for a recording of nSamp samples
%   at Fs on nCh channels, with the events of schedule S
%   (syntheticTaskSchedule), over D's white noise and sine.
%   makeSyntheticRecording writes M; the app's Synthetic tab previews it,
%   so a preview shows the spikes that are then written (same seed, same
%   model).
%
%   Clocks (see documentation/README.md, "Time and indexing conventions"):
%   S.events and the trial Onset / Offset are seconds with t = row/Fs, as
%   readers return them (row = round(t * Fs)); an edge at row r happened at
%   (r - 1)/Fs, which is where responses are aligned (plus their latency),
%   and sample row r of the signal lies at (r - 1)/Fs. A line already on at
%   the first sample has no onset there, one still on at the last sample
%   no offset.
%
%   Options
%     Artifacts   true: a noise burst (22 % in) and a saturating step (63 % in)
%
%   M fields
%     Fs, nSamp, nCh, duration, lineNames, trialLine, design (D)
%     rows          struct: line -> [k x 2] 1-based [first last] ON rows
%                   (overlapping intervals merged, clipped to the recording)
%     trialRows     [nTrials x 2] each trial's rows, NaN outside the recording
%     units         struct array: id (0-based), name, peakChannel,
%                   amplitudeUV, baselineHz, event, edge, gain, latencyMs,
%                   durationMs, parameter, modulation ("driven" |
%                   "suppressed" | "none"), samples (1-based rows of the
%                   spikes' troughs), template ([nt x nCh] uV, zero off its
%                   channel), and per event: eventTimes (s), starts
%                   (eventTimes + latency, s), eventScale (0..1), eventTrial
%     lfp           struct array: the LFP row's values plus gain (1 x nCh:
%                   1 on its channel(s), else 0) and per event eventTimes,
%                   starts, eventScale, eventTrial
%     artifacts     [k x 2] rows; artifactKinds ("burst" | "saturate")
%     nt, p0        template length and the trough's row in it
%     signal(s0, n)     [n x nCh] uV of rows s0+1 .. s0+n (fresh noise each call)
%     expectedRate(u, tau, idx)   mean model rate (Hz) of unit u at TAU s
%                       from its events IDX (default all)
%     componentWave(c, tau, idx)  mean waveform (uV, gain 1) of LFP
%                       component c at TAU s from its events IDX
%
%   See also makeSyntheticRecording, SyntheticDesign, syntheticTaskSchedule.

arguments
    S (1,1) struct
    D (1,1) SyntheticDesign
    Fs (1,1) double {mustBePositive}
    nSamp (1,1) double {mustBeInteger, mustBePositive}
    nCh (1,1) double {mustBeInteger, mustBePositive}
    opts.Artifacts (1,1) logical = true
end

L = nSamp / Fs;
lineNames = reshape(string(S.lineNames), 1, []);
trials = S.trials;
params = numericParameters(trials);
issues = D.validate(lineNames, params, nCh);
if ~isempty(issues)
    error('syntheticModel:Design', 'The design cannot be generated:\n  %s', strjoin(issues, newline + "  "));
end

% --- the lines at Fs -----------------------------------------------------------
rows = struct();
for ln = lineNames
    rows.(ln) = mergeRows(toRows(S.events.(ln), Fs, nSamp));
end
trialRows = NaN(height(trials), 2);
if height(trials) > 0
    trialRows = toRowsKeepAll([trials.Onset trials.Offset], Fs, nSamp);
end

    function [te, rowE] = edges(line, edge)
        %edges  Continuous times of a line's edges inside the recording.
        r = rows.(line);
        if edge == "onset"
            rowE = r(r(:, 1) > 1, 1);
        else
            rowE = r(r(:, 2) < nSamp, 2);
        end
        te = (rowE - 1) / Fs;
    end

    function [sc, trialOf] = scales(rowE, param)
        %scales  Each event's response scale (0..1): its trial's PARAM normalized over the session.
        trialOf = NaN(numel(rowE), 1);
        for k = find(~isnan(trialRows(:, 1))).'
            trialOf(rowE >= trialRows(k, 1) & rowE <= trialRows(k, 2)) = k;
        end
        sc = ones(numel(rowE), 1);
        if param == ""; return; end
        v = double(trials.(param));
        lo = min(v(isfinite(v))); hi = max(v(isfinite(v)));
        has = ~isnan(trialOf);
        x = ones(nnz(has), 1);   % a parameter with one value: every event responds fully
        if ~isempty(lo) && hi > lo
            x = (v(trialOf(has)) - lo) / (hi - lo);
            x(~isfinite(x)) = 0;   % a trial without a value does not respond
        end
        sc(has) = x;
    end

% --- units ---------------------------------------------------------------------
U = D.Units;
nU = height(U);
nt = round(0.002 * Fs) + 1;                 % 2 ms template (61 samples at 30 kHz)
p0 = round(nt / 3);                         % the trough sits here
tmsT = ((1:nt) - p0).' / Fs * 1000;
shape = -exp(-tmsT.^2 / (2 * 0.2^2));       % a negative Gaussian, sigma 0.2 ms, -1 at the trough
units = struct('id', {}, 'name', {}, 'peakChannel', {}, 'amplitudeUV', {}, 'baselineHz', {}, ...
    'event', {}, 'edge', {}, 'gain', {}, 'latencyMs', {}, 'durationMs', {}, 'parameter', {}, ...
    'modulation', {}, 'samples', {}, 'template', {}, 'eventTimes', {}, 'starts', {}, ...
    'eventScale', {}, 'eventTrial', {});
for u = 1:nU
    tmpl = zeros(nt, nCh);
    tmpl(:, U.Channel(u)) = U.AmplitudeUV(u) * shape;
    ev = U.Event(u);
    gain = U.Gain(u);
    dur = U.DurationMs(u) / 1000;
    te = zeros(0, 1); sc = zeros(0, 1); tr = zeros(0, 1);
    if ev ~= ""
        [te, rowE] = edges(ev, U.Edge(u));
        [sc, tr] = scales(rowE, U.Parameter(u));
    end
    st = te + U.LatencyMs(u) / 1000;
    modulation = "none";
    if ev ~= "" && gain > 1; modulation = "driven"; end
    if ev ~= "" && gain < 1; modulation = "suppressed"; end

    % spikes: candidates at the peak rate (2 ms dead time), each kept with
    % probability rate(t) / peak; inside a response the rate is x (1 + (gain - 1) x scale)
    peak = 1;
    if modulation == "driven"; peak = 1 + (gain - 1) * max([sc; 0]) * maxOverlap(st, dur); end
    tt = candidates(U.BaselineHz(u) * peak, L);
    if modulation ~= "none" && ~isempty(tt)
        f = ones(numel(tt), 1);
        E = [-Inf; tt; Inf];
        i1 = discretize(st, E);                  % the first candidate after each start
        i2 = discretize(st + dur, E) - 1;        % the last one before each end
        for ie = find(i2 >= i1).'
            k = i1(ie):i2(ie);
            f(k) = f(k) + (gain - 1) * sc(ie);
        end
        tt = tt(rand(numel(tt), 1) < max(f, 0) / peak);
    end
    smp = floor(tt * Fs) + 1;
    smp = smp(smp > p0 + 1 & smp < nSamp - (nt - p0) - 1);
    units(u) = struct('id', u - 1, 'name', U.Name(u), 'peakChannel', U.Channel(u), ...
        'amplitudeUV', U.AmplitudeUV(u), 'baselineHz', U.BaselineHz(u), 'event', ev, 'edge', U.Edge(u), ...
        'gain', gain, 'latencyMs', U.LatencyMs(u), 'durationMs', U.DurationMs(u), 'parameter', U.Parameter(u), ...
        'modulation', modulation, 'samples', smp, 'template', tmpl, 'eventTimes', te, 'starts', st, ...
        'eventScale', sc, 'eventTrial', tr);
end

% --- evoked potentials -----------------------------------------------------------
C = D.LFP;
lfp = struct('name', {}, 'channel', {}, 'amplitudeUV', {}, 'event', {}, 'edge', {}, 'latencyMs', {}, ...
    'durationMs', {}, 'parameter', {}, 'gain', {}, 'eventTimes', {}, 'starts', {}, 'eventScale', {}, ...
    'eventTrial', {});
for c = 1:height(C)
    g = ones(1, nCh);
    if ~isnan(C.Channel(c)); g = zeros(1, nCh); g(C.Channel(c)) = 1; end
    [te, rowE] = edges(C.Event(c), C.Edge(c));
    [sc, tr] = scales(rowE, C.Parameter(c));
    lfp(c) = struct('name', C.Name(c), 'channel', C.Channel(c), 'amplitudeUV', C.AmplitudeUV(c), ...
        'event', C.Event(c), 'edge', C.Edge(c), 'latencyMs', C.LatencyMs(c), 'durationMs', C.DurationMs(c), ...
        'parameter', C.Parameter(c), 'gain', g, 'eventTimes', te, 'starts', te + C.LatencyMs(c) / 1000, ...
        'eventScale', sc, 'eventTrial', tr);
end

% --- artifacts -----------------------------------------------------------------
artS = zeros(0, 2); artKind = strings(0, 1);
if opts.Artifacts
    artS = [0.22 * L, 0.22 * L + 0.15; 0.63 * L, 0.63 * L + 0.4];
    artKind = ["burst"; "saturate"];
end
artRows = [floor(artS(:, 1) * Fs) + 1, max(ceil(artS(:, 2) * Fs), floor(artS(:, 1) * Fs) + 1)];
artRows = min(max(artRows, 1), nSamp);
noiseUV = D.NoiseUV;
sineUV = D.SineUV;
sineHz = SyntheticDesign.SineHz;

    function X = signal(s0, n)
        t = (s0 + (0:n-1)).' / Fs;
        X = noiseUV * randn(n, nCh) + sineUV * sin(2 * pi * sineHz * t);
        % evoked potentials
        for cc = 1:numel(lfp)
            q = lfp(cc);
            d = q.durationMs / 1000;
            for i = find(q.starts <= t(end) & q.starts + d >= t(1)).'
                m = t >= q.starts(i) & t < q.starts(i) + d;
                if ~any(m); continue; end
                X(m, :) = X(m, :) + q.amplitudeUV * q.eventScale(i) * bump(t(m) - q.starts(i), d) * q.gain;
            end
        end
        % spikes
        for uu = 1:nU
            su = units(uu).samples;
            ch = units(uu).peakChannel;
            w = units(uu).template(:, ch);
            for j = find(su >= s0 + 1 - (nt - p0) & su <= s0 + n + p0).'
                r = su(j) - p0 + (1:nt).' - s0;
                ok = r >= 1 & r <= n;
                X(r(ok), ch) = X(r(ok), ch) + w(ok);
            end
        end
        % artifacts
        for k = find(artRows(:, 2) >= s0 + 1 & artRows(:, 1) <= s0 + n).'
            r = (max(artRows(k, 1), s0 + 1) : min(artRows(k, 2), s0 + n)) - s0;
            if artKind(k) == "burst"
                X(r, :) = X(r, :) + 1500 * randn(numel(r), nCh);
            else
                X(r, :) = X(r, :) + 7000;
            end
        end
    end

    function r = expectedRate(u, tau, idx)
        q = units(u);
        if nargin < 3; idx = 1:numel(q.starts); end
        tau = tau(:);
        r = q.baselineHz * ones(numel(tau), 1);
        if q.modulation ~= "none" && ~isempty(idx)
            lat = q.latencyMs / 1000;
            in = tau >= lat & tau < lat + q.durationMs / 1000;
            r(in) = q.baselineHz * max(1 + (q.gain - 1) * mean(q.eventScale(idx)), 0);
        end
    end

    function y = componentWave(c, tau, idx)
        q = lfp(c);
        if nargin < 3; idx = 1:numel(q.starts); end
        tau = tau(:);
        y = zeros(numel(tau), 1);
        if isempty(idx); return; end
        s = tau - q.latencyMs / 1000;
        y = q.amplitudeUV * mean(q.eventScale(idx)) * bump(s, q.durationMs / 1000);
    end

f = []; tt = []; tmpl = []; %#ok<NASGU> the handles below keep this workspace alive: drop the big temporaries
M = struct();
M.Fs            = Fs;
M.nSamp         = nSamp;
M.nCh           = nCh;
M.duration      = L;
M.lineNames     = lineNames;
M.trialLine     = string(S.trialLine);
M.design        = D;
M.rows          = rows;
M.trialRows     = trialRows;
M.units         = units;
M.lfp           = lfp;
M.artifacts     = artRows;
M.artifactKinds = artKind;
M.nt            = nt;
M.p0            = p0;
M.signal        = @signal;
M.expectedRate  = @expectedRate;
M.componentWave = @componentWave;
end


%% ---------------------------------------------------------------------------
function p = numericParameters(T)
%numericParameters  Epsych2 parameters (table columns other than Onset / Offset) holding numbers.
p = strings(1, 0);
for v = string(T.Properties.VariableNames)
    if ismember(v, ["Onset" "Offset"]); continue; end
    x = T.(v);
    if (isnumeric(x) || islogical(x)) && size(x, 2) == 1
        p(end+1) = v; %#ok<AGROW>
    end
end
end


function y = bump(s, d)
%bump  A raised cosine over [0, d) peaking at d/2 (1 there), 0 outside.
y = sin(pi * s / d).^2 .* (s >= 0 & s < d);
end


function tt = candidates(rMax, L)
%candidates  Spike candidates over [0, L) s at rMax Hz, at least 2 ms apart (sorted, unique).
%   The intervals are 2 ms plus an exponential one at rE, so that their rate,
%   1 / (0.002 + 1/rE), is rMax (at most 450 Hz: the dead time caps it at 500).
tt = zeros(0, 1);
if ~(rMax > 0); return; end
rMax = min(rMax, 450);
rE = rMax / (1 - 0.002 * rMax);
t0 = 0;
while t0 < L
    n = ceil((L - t0) * rMax * 1.1) + 20;
    c = t0 + cumsum(0.002 - log(rand(n, 1)) / rE);
    tt = [tt; c(c < L)]; %#ok<AGROW>
    t0 = c(end);
end
end


function n = maxOverlap(st, d)
%maxOverlap  The most responses [st, st + d) that are on at once (at least 1).
n = 1;
if numel(st) < 2; return; end
[~, order] = sort([st; st + d]);
step = [ones(numel(st), 1); -ones(numel(st), 1)];
n = max(1, max(cumsum(step(order))));
end


function rows = toRows(iv, Fs, nSamp)
%toRows  Seconds [on off] (t = row/Fs) -> 1-based rows, clipped; intervals outside dropped.
rows = toRowsKeepAll(iv, Fs, nSamp);
rows = rows(~isnan(rows(:, 1)), :);
if isempty(rows); rows = zeros(0, 2); end
rows = sortrows(rows);
end


function rows = toRowsKeepAll(iv, Fs, nSamp)
%toRowsKeepAll  As toRows, but intervals outside the recording become NaN rows.
if isempty(iv); rows = zeros(0, 2); return; end
on  = round(iv(:, 1) * Fs);
off = max(round(iv(:, 2) * Fs), on);
keep = off >= 1 & on <= nSamp & isfinite(on) & isfinite(off);
on  = max(on, 1); off = min(off, nSamp);
rows = [on off];
rows(~keep, :) = NaN;
end


function r = mergeRows(r)
%mergeRows  Overlapping or touching intervals become one (the line is simply on).
if size(r, 1) < 2; return; end
out = r(1, :);
for k = 2:size(r, 1)
    if r(k, 1) <= out(end, 2) + 1
        out(end, 2) = max(out(end, 2), r(k, 2));
    else
        out(end+1, :) = r(k, :); %#ok<AGROW>
    end
end
r = out;
end
