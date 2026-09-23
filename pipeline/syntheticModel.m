function M = syntheticModel(S, D, Fs, nSamp, probe, opts)
%syntheticModel  Resolve a SyntheticDesign against a schedule: spike trains, LFP, the signal.
%   M = syntheticModel(S, D, Fs, nSamp, PROBE) draws, from the current
%   random stream, everything random in design D (the NaN unit values,
%   latency jitter, spike times, oscillation phases) for a recording of
%   nSamp samples at Fs with the events of schedule S (syntheticTaskSchedule
%   or syntheticSessionSchedule), on the sites of PROBE (struct with xc, yc:
%   one site per channel). makeSyntheticRecording writes M; the app's
%   Synthetic tab previews it, so a preview shows the spikes that are then
%   written (same seed, same model).
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
%     Artifacts   true: a burst (22 % in) and a saturating step (63 % in)
%
%   M fields
%     Fs, nSamp, nCh, xc, yc (the sites), duration, lineNames, trialLine,
%     design (D), background
%     rows          struct: line -> [k x 2] 1-based [first last] ON rows
%                   (overlapping intervals merged, clipped to the recording)
%     trialRows     [nTrials x 2] each trial's rows, NaN outside the recording
%     units         struct array: id (0-based), name, peakChannel,
%                   amplitudeUV, widthMs, baselineHz, event, edge, shape,
%                   gain, latencyMs, durationMs, jitterMs, parameter,
%                   tuning, modulation ("driven" | "suppressed" | "none"),
%                   samples (1-based rows of the spikes' troughs), scales
%                   (per-spike amplitude factors), template ([nt x nCh] uV),
%                   and per event: eventTimes (s), starts (response start,
%                   s), durations (s), eventScale (0..1), eventTrial
%     lfp           struct array: the LFP row's values plus gain (1 x nCh),
%                   peakChannel and per event eventTimes, starts,
%                   durations, phases, eventScale, eventTrial
%     artifacts     [k x 2] rows; artifactKinds ("burst" | "saturate")
%     nt, p0        template length and the trough's row in it
%     signal(s0, n)     [n x nCh] uV of rows s0+1 .. s0+n; call in order
%                       (the slow noise carries its filter state)
%     window(s0, n)     the same for any window, without touching that state
%     expectedRate(u, tau, idx)   mean model rate (Hz) of unit u at TAU s
%                       from its events IDX (default all)
%     componentWave(c, tau, idx)  mean noiseless waveform (uV, gain 1) of LFP
%                       component c at TAU s from its events IDX
%     componentEnvelope(c, tau, idx)  its mean amplitude envelope
%
%   See also makeSyntheticRecording, SyntheticDesign, syntheticTaskSchedule,
%   syntheticSessionSchedule.

arguments
    S (1,1) struct
    D (1,1) SyntheticDesign
    Fs (1,1) double {mustBePositive}
    nSamp (1,1) double {mustBeInteger, mustBePositive}
    probe (1,1) struct
    opts.Artifacts (1,1) logical = true
end

xc = double(probe.xc(:)); yc = double(probe.yc(:));
nCh = numel(xc);
L = nSamp / Fs;
lineNames = reshape(string(S.lineNames), 1, []);
trials = S.trials;
params = numericParameters(trials);
issues = D.validate(lineNames, params, nCh, Fs);
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

    function [te, dur, rowE] = edges(line, edge)
        %edges  Continuous times of a line's edges inside the recording, with the interval lengths.
        r = rows.(line);
        if edge == "onset"
            r = r(r(:, 1) > 1, :);
            rowE = r(:, 1);
        else
            r = r(r(:, 2) < nSamp, :);
            rowE = r(:, 2);
        end
        te = (rowE - 1) / Fs;
        dur = (r(:, 2) - r(:, 1) + 1) / Fs;
    end

    function [sc, trialOf] = scales(rowE, param, tuning)
        %scales  Each event's response scale (0..1) from its trial's PARAM.
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
            if tuning == "decreasing"; x = 1 - x; end
            x(~isfinite(x)) = 0;   % a trial without a value does not respond, either way
        end
        sc(has) = x;
    end

% --- units ---------------------------------------------------------------------
U = D.Units;
nU = height(U);
pos = (1:nU).';
ch = U.Channel;
spread = isnan(ch);
ch(spread) = max(1, min(nCh, round((pos(spread) - 0.5) * nCh / nU)));
amp = drawNaN(U.AmplitudeUV, @(k) exp(log(60) + (log(200) - log(60)) * rand(k, 1)));
wid = drawNaN(U.WidthMs,     @(k) 0.15 + 0.15 * rand(k, 1));
base = drawNaN(U.BaselineHz, @(k) 1.5 + 6.5 * rand(k, 1));
gain = drawNaN(U.Gain,       @(k) 2 + 3 * rand(k, 1));
nt = round(0.002 * Fs) + 1;                 % 2 ms template (61 samples at 30 kHz)
p0 = round(nt / 3);                         % the trough sits here
tmsT = ((1:nt) - p0).' / Fs * 1000;
kT = max(2, round(0.1e-3 * Fs));            % 0.1 ms raised-cosine ends: a wide spike leaves no step
taper = ones(nt, 1);
taper(1:kT) = 0.5 - 0.5 * cos(pi * (0:kT-1).' / kT);
taper(end-kT+1:end) = flipud(taper(1:kT));
units = struct('id', {}, 'name', {}, 'peakChannel', {}, 'amplitudeUV', {}, 'widthMs', {}, ...
    'baselineHz', {}, 'event', {}, 'edge', {}, 'shape', {}, 'gain', {}, 'latencyMs', {}, ...
    'durationMs', {}, 'jitterMs', {}, 'parameter', {}, 'tuning', {}, 'modulation', {}, ...
    'samples', {}, 'scales', {}, 'template', {}, 'eventTimes', {}, 'starts', {}, ...
    'durations', {}, 'eventScale', {}, 'eventTrial', {});
for u = 1:nU
    w = taper .* amp(u) .* (-exp(-tmsT.^2 / (2 * wid(u)^2)) + 0.3 * exp(-(tmsT - 0.6).^2 / (2 * 0.45^2)));
    d = hypot(xc - xc(ch(u)), yc - yc(ch(u)));
    tmpl = w * exp(-d.^2 / (2 * 40^2)).';                      % [nt x nCh]

    ev = U.Event(u);
    te = zeros(0, 1); st = zeros(0, 1); du = zeros(0, 1); sc = zeros(0, 1); tr = zeros(0, 1);
    if ev ~= ""
        [te, iv, rowE] = edges(ev, U.Edge(u));
        [sc, tr] = scales(rowE, U.Parameter(u), U.Tuning(u));
        st = te + U.LatencyMs(u) / 1000;
        if U.JitterMs(u) > 0; st = st + U.JitterMs(u) / 1000 * randn(numel(st), 1); end
        du = iv;
        if ~isnan(U.DurationMs(u)); du(:) = U.DurationMs(u) / 1000; end
    end
    modulation = "none";
    if ev ~= "" && gain(u) > 1; modulation = "driven"; end
    if ev ~= "" && gain(u) < 1; modulation = "suppressed"; end

    % spikes: candidates at the peak rate (2 ms dead time), each kept with
    % probability rate(t) / peak, the rate evaluated exactly at its time
    peak = 1;
    if modulation == "driven"; peak = 1 + (gain(u) - 1) * max([sc; 0]) * maxOverlap(st, du); end
    tt = candidates(base(u) * peak, L);
    if modulation ~= "none" && ~isempty(tt)
        f = ones(numel(tt), 1);
        E = [-Inf; tt; Inf];
        i1 = discretize(st, E);                  % the first candidate after each start
        i2 = discretize(st + du, E) - 1;         % the last one before each end
        for ie = find(i2 >= i1).'
            k = i1(ie):i2(ie);
            f(k) = f(k) + (gain(u) - 1) * sc(ie) * envelope(tt(k) - st(ie), du(ie), U.Shape(u));
        end
        tt = tt(rand(numel(tt), 1) < max(f, 0) / peak);
    end
    smp = floor(tt * Fs) + 1;
    smp = smp(smp > p0 + 1 & smp < nSamp - (nt - p0) - 1);
    units(u) = struct('id', u - 1, 'name', U.Name(u), 'peakChannel', ch(u), 'amplitudeUV', amp(u), ...
        'widthMs', wid(u), 'baselineHz', base(u), 'event', ev, 'edge', U.Edge(u), 'shape', U.Shape(u), ...
        'gain', gain(u), 'latencyMs', U.LatencyMs(u), 'durationMs', U.DurationMs(u), ...
        'jitterMs', U.JitterMs(u), 'parameter', U.Parameter(u), 'tuning', U.Tuning(u), ...
        'modulation', modulation, 'samples', smp, 'scales', 1 + 0.06 * randn(numel(smp), 1), ...
        'template', tmpl, 'eventTimes', te, 'starts', st, 'durations', du, 'eventScale', sc, 'eventTrial', tr);
end

% --- event-linked LFP components -------------------------------------------------
C = D.LFP;
dep = yc;
if max(dep) > min(dep); dep = (dep - min(dep)) / (max(dep) - min(dep)); else; dep(:) = 0.5; end
lfp = struct('name', {}, 'kind', {}, 'event', {}, 'edge', {}, 'frequencyHz', {}, 'amplitudeUV', {}, ...
    'latencyMs', {}, 'durationMs', {}, 'riseMs', {}, 'phaseLocked', {}, 'profile', {}, 'jitterMs', {}, ...
    'parameter', {}, 'tuning', {}, 'gain', {}, 'peakChannel', {}, 'eventTimes', {}, 'starts', {}, ...
    'durations', {}, 'phases', {}, 'eventScale', {}, 'eventTrial', {});
for c = 1:height(C)
    g = profileGain(C.Profile(c), dep).';
    [~, pk] = max(abs(g));
    [te, iv, rowE] = edges(C.Event(c), C.Edge(c));
    [sc, tr] = scales(rowE, C.Parameter(c), C.Tuning(c));
    st = te + C.LatencyMs(c) / 1000;
    if C.JitterMs(c) > 0; st = st + C.JitterMs(c) / 1000 * randn(numel(st), 1); end
    if C.Kind(c) == "oscillation"
        du = iv;
        if ~isnan(C.DurationMs(c)); du(:) = C.DurationMs(c) / 1000; end
        ph = zeros(numel(st), 1);
        if ~C.PhaseLocked(c); ph = 2 * pi * rand(numel(st), 1); end
    else
        du = repmat(8 * C.RiseMs(c) / 1000, numel(st), 1);
        if ~isnan(C.DurationMs(c)); du(:) = C.DurationMs(c) / 1000; end
        ph = zeros(numel(st), 1);
    end
    lfp(c) = struct('name', C.Name(c), 'kind', C.Kind(c), 'event', C.Event(c), 'edge', C.Edge(c), ...
        'frequencyHz', C.FrequencyHz(c), 'amplitudeUV', C.AmplitudeUV(c), 'latencyMs', C.LatencyMs(c), ...
        'durationMs', C.DurationMs(c), 'riseMs', C.RiseMs(c), 'phaseLocked', C.PhaseLocked(c), ...
        'profile', C.Profile(c), 'jitterMs', C.JitterMs(c), 'parameter', C.Parameter(c), ...
        'tuning', C.Tuning(c), 'gain', g, 'peakChannel', pk, 'eventTimes', te, 'starts', st, ...
        'durations', du, 'phases', ph, 'eventScale', sc, 'eventTrial', tr);
end

% --- artifacts -----------------------------------------------------------------
artS = zeros(0, 2); artKind = strings(0, 1);
if opts.Artifacts
    artS = [0.22 * L, 0.22 * L + 0.15; 0.63 * L, 0.63 * L + 0.4];
    artKind = ["burst"; "saturate"];
end
artRows = [floor(artS(:, 1) * Fs) + 1, max(ceil(artS(:, 2) * Fs), floor(artS(:, 1) * Fs) + 1)];
artRows = min(max(artRows, 1), nSamp);

% --- background ----------------------------------------------------------------
B = D.Background;
gLFP  = (1.2 - 0.8 * (0:nCh-1) / max(nCh - 1, 1));               % depth gradient, 1 x nCh
phLine = 0.3 * randn(1, nCh);                                     % line-noise phase per channel
alpha = exp(-2 * pi * 4 / Fs);                                    % 4 Hz one-pole low-pass
bS = 1 - alpha; aS = [1 -alpha];
sigSlowIn = B.PinkUV * sqrt((1 + alpha) / (1 - alpha));           % -> PinkUV RMS out
ziSlow = zeros(1, nCh);

    function X = signal(s0, n)
        t = (s0 + (0:n-1)).' / Fs;
        rh = 120 * (1 + 0.4 * sin(2 * pi * 0.07 * t)) .* sin(2 * pi * 1.7 * t + 0.3) ...
            + 60 * (1 + 0.5 * sin(2 * pi * 0.11 * t + 1)) .* sin(2 * pi * 7.3 * t) ...
            + 25 * sin(2 * pi * 12.5 * t + 2);
        X = (B.RhythmScale * rh) * gLFP;
        [slow, ziSlow] = filter(bS, aS, sigSlowIn * randn(n, nCh), ziSlow);
        X = X + slow + B.NoiseUV * randn(n, nCh);
        fL = B.LineFreqHz;
        X = X + B.LineNoiseUV * (sin(2 * pi * fL * t) * cos(phLine) + cos(2 * pi * fL * t) * sin(phLine)) ...
              + 0.3 * B.LineNoiseUV * sin(2 * pi * 3 * fL * t) * ones(1, nCh);
        % event-linked LFP
        for cc = 1:numel(lfp)
            q = lfp(cc);
            for i = find(q.starts <= t(end) & q.starts + q.durations >= t(1)).'
                m = t >= q.starts(i) & t < q.starts(i) + q.durations(i);
                if ~any(m); continue; end
                X(m, :) = X(m, :) + waveOne(q, i, t(m) - q.starts(i)) * q.gain;
            end
        end
        % spikes
        for uu = 1:nU
            su = units(uu).samples; sk = units(uu).scales;
            for j = find(su >= s0 + 1 - (nt - p0) & su <= s0 + n + p0).'
                r = su(j) - p0 + (1:nt).' - s0;
                ok = r >= 1 & r <= n;
                X(r(ok), :) = X(r(ok), :) + sk(j) * units(uu).template(ok, :);
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

    function X = window(s0, n)
        % A warm-up before the window settles the slow noise; the running state is kept.
        saved = ziSlow;
        ziSlow = zeros(1, nCh);
        w0 = max(0, s0 - round(0.3 * Fs));
        X = signal(w0, n + s0 - w0);
        X = X(s0 - w0 + 1:end, :);
        ziSlow = saved;
    end

    function r = expectedRate(u, tau, idx)
        q = units(u);
        if nargin < 3; idx = 1:numel(q.starts); end
        tau = tau(:);
        acc = zeros(numel(tau), 1);
        if q.modulation ~= "none" && ~isempty(idx)
            for i = idx(:).'
                acc = acc + q.eventScale(i) * envelope(tau - (q.starts(i) - q.eventTimes(i)), q.durations(i), q.shape);
            end
            acc = acc / numel(idx);
        end
        r = q.baselineHz * max(1 + (q.gain - 1) * acc, 0);
    end

    function y = componentWave(c, tau, idx)
        q = lfp(c);
        if nargin < 3; idx = 1:numel(q.starts); end
        tau = tau(:);
        y = zeros(numel(tau), 1);
        for i = idx(:).'
            s = tau - (q.starts(i) - q.eventTimes(i));
            m = s >= 0 & s < q.durations(i);
            y(m) = y(m) + waveOne(q, i, s(m));
        end
        if ~isempty(idx); y = y / numel(idx); end
    end

    function y = componentEnvelope(c, tau, idx)
        q = lfp(c);
        if nargin < 3; idx = 1:numel(q.starts); end
        tau = tau(:);
        y = zeros(numel(tau), 1);
        for i = idx(:).'
            s = tau - (q.starts(i) - q.eventTimes(i));
            if q.kind == "oscillation"
                e = tukey(s, q.durations(i), min(q.riseMs / 1000, q.durations(i) / 2));
            else
                e = abs(evokedShape(s, q.riseMs / 1000, q.durations(i)));
            end
            y = y + abs(q.amplitudeUV) * q.eventScale(i) * e;
        end
        if ~isempty(idx); y = y / numel(idx); end
    end

f = []; tt = []; tmpl = []; %#ok<NASGU> the handles below keep this workspace alive: drop the big temporaries
M = struct();
M.Fs            = Fs;
M.nSamp         = nSamp;
M.nCh           = nCh;
M.xc            = xc;
M.yc            = yc;
M.duration      = L;
M.lineNames     = lineNames;
M.trialLine     = string(S.trialLine);
M.design        = D;
M.background    = B;
M.rows          = rows;
M.trialRows     = trialRows;
M.units         = units;
M.lfp           = lfp;
M.artifacts     = artRows;
M.artifactKinds = artKind;
M.nt            = nt;
M.p0            = p0;
M.signal        = @signal;
M.window        = @window;
M.expectedRate  = @expectedRate;
M.componentWave = @componentWave;
M.componentEnvelope = @componentEnvelope;
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


function x = drawNaN(x, draw)
m = isnan(x);
if any(m); x(m) = draw(nnz(m)); end
end


function e = envelope(tau, d, shape)
%envelope  A unit's response envelope (0..1) TAU s after its start, D s long.
in = tau >= 0 & tau < d;
switch shape
    case "transient"
        e = sin(pi * tau / d).^2 .* in;
    case "phasic-tonic"
        dp = 0.3 * d;
        e = max(sin(pi * tau / dp).^2 .* (tau >= 0 & tau < dp), 0.4 * in);
    otherwise   % sustained
        e = double(in);
end
end


function e = tukey(s, d, r)
%tukey  1 over [0, d) with raised-cosine ramps of r s at both ends.
e = double(s >= 0 & s < d);
if r > 0
    up = s >= 0 & s < r;
    e(up) = 0.5 * (1 - cos(pi * s(up) / r));
    dn = s >= d - r & s < d;
    e(dn) = min(e(dn), 0.5 * (1 - cos(pi * (d - s(dn)) / r)));
end
end


function y = evokedShape(s, tp, d)
y = (s / tp) .* exp(1 - s / tp) .* (s >= 0 & s < d);
end


function y = waveOne(q, i, s)
%waveOne  Component Q's waveform (uV, gain 1) S s after the start of its event I.
a = q.amplitudeUV * q.eventScale(i);
if q.kind == "oscillation"
    y = a * tukey(s, q.durations(i), min(q.riseMs / 1000, q.durations(i) / 2)) ...
        .* sin(2 * pi * q.frequencyHz * s + q.phases(i));
else
    y = a * evokedShape(s, q.riseMs / 1000, q.durations(i));
end
end


function g = profileGain(profile, d)
%profileGain  Gain per site from its normalised depth D (0 = deepest, 1 = top).
switch profile
    case "superficial", g = exp(-((d - 1) / 0.3).^2);
    case "middle",      g = exp(-((d - 0.5) / 0.3).^2);
    case "deep",        g = exp(-(d / 0.3).^2);
    case "reversal",    g = tanh((d - 0.5) / 0.2);
    otherwise,          g = ones(size(d));
end
if max(abs(g)) > 0; g = g / max(abs(g)); end
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


function n = maxOverlap(st, du)
%maxOverlap  The most responses [st, st + du) that are on at once (at least 1).
n = 1;
if numel(st) < 2; return; end
[~, order] = sort([st; st + du]);
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
