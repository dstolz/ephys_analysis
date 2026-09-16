function P = pairEpsychTrials(trials, events, Fs, opts)
%pairEpsychTrials  Pair Epsych2 trials with the [onset offset] of a digital line.
%   P = pairEpsychTrials(TRIALS, EVENTS, Fs, Name=Value) matches each row of
%   TRIALS (readEpsychSession: one row per trial) to one interval of the
%   digital line Epsych2 holds high for the duration of a trial (TrialLine,
%   default "InTrial") and returns the timing of every trial in seconds and in
%   samples, plus the intervals of every other line that overlap each trial.
%   Nothing here depends on the acquisition system: EVENTS is the universal
%   events struct (one field per line, [k x 2] [t_on t_off] seconds with
%   t = row/Fs, see EphysReader) and Fs its sample rate.
%
%   Matching
%   --------
%   With a computerTimestamp column (Epsych2 stamps each trial when it ends)
%   trials and intervals are aligned in order by dynamic programming: the
%   clock offset between the two is the most common timestamp - offset
%   difference, a pair costs |residual| / ToleranceS (capped at LateCost, so a
%   trial stamped late by seconds still pairs, plus 0.02 per second of
%   residual so the smaller of two large residuals wins), and every trial or interval
%   left without a partner costs GapCost. So a phantom or missing TTL, or a
%   session that stopped early, is skipped rather than shifting every later
%   trial. Without timestamps trials pair with intervals in order (the first
%   min(nTrials, nIntervals)). Assignment=<vector> skips both and uses the
%   given interval per trial (a reviewed pairing).
%   Every result is meant to be reviewed (see EphysDataset.pairTrials).
%
%   Line polarity
%   -------------
%   EVENTS holds the HIGH runs of every line, as readers return them. Lines
%   named in InvertedLines are on while low: their onset is the falling edge
%   and their offset the last low sample (digitalLinePolarity, which needs
%   NumSamples). Pass EVENTS that already had the polarity applied (e.g. an
%   extract's events) with InvertedLines empty.
%
%   Options
%   -------
%     TrialLine       "InTrial"   line whose intervals are trials
%     InvertedLines   string list of lines with inverted polarity (default
%                     none; names the struct lacks are ignored)
%     NumSamples      recording length in samples (needed to invert a line)
%     ToleranceS      0.5  residual (s) within which a timestamp agrees
%     GapCost         3    cost of an unpaired trial or interval
%     LateCost        4    cost cap of a pair whose timestamp disagrees
%                          (must stay below 2*GapCost)
%     TimestampField  "computerTimestamp"
%     Assignment      [] or [nTrials x 1] interval index per trial (NaN = none)
%     SignalFs        struct of derived-signal rates, e.g. struct('LFP', 1000)
%
%   Output P
%   --------
%     trialLine, invertedLines (those applied), Fs, nTrials, nIntervals, method
%        ("timestamps" | "order" | "manual")
%     interval        [nTrials x 1] index into the trial line's intervals (NaN)
%     onset, offset   [nTrials x 1] seconds (t = row/Fs), NaN when unpaired
%     onsetSample, offsetSample   1-based rows at Fs (first / last on sample)
%     signalFs        struct: <signal> -> rate used (valid SignalFs entries)
%     signalSamples   struct: <signal> -> [nTrials x 2] round(t * signalFs)
%                     (ChronuxDataset.trials' "event" onset rule)
%     residual        [nTrials x 1] s, timestamp - (offset + clockOffsetS)
%     clockOffsetS    timestamp clock minus recording clock (s), NaN without
%     flag            [nTrials x 1] "ok" | "timestamp off" | "unpaired"
%     unpairedTrials, unpairedIntervals   indices
%     nPaired, nTimestampOff
%     lines           struct: <line> -> {nTrials x 1} [n x 2] seconds of that
%                     line's intervals overlapping the trial (every line but
%                     the trial line, polarity applied)
%     columns         table (nTrials rows) to append to TRIALS: TrialInterval,
%                     TrialOnset, TrialOffset, TrialOnsetSample,
%                     TrialOffsetSample, TrialOnsetSample_<SIG>,
%                     TrialOffsetSample_<SIG>, TimestampResidual, PairingFlag,
%                     TrialEvents (struct: <line> -> [n x 2] s) and
%                     TrialEventSamples (<line> -> [n x 2] rows at Fs)
%     summary         one line of text
%
%   See also readEpsychSession, EphysDataset.pairTrials, ChronuxDataset.trials.

arguments
    trials table
    events (1,1) struct
    Fs (1,1) double {mustBePositive}
    opts.TrialLine (1,1) string = "InTrial"
    opts.InvertedLines (1,:) string = string.empty(1,0)
    opts.NumSamples (1,1) double = NaN
    opts.ToleranceS (1,1) double {mustBePositive} = 0.5
    opts.GapCost (1,1) double {mustBePositive} = 3
    opts.LateCost (1,1) double {mustBePositive} = 4
    opts.TimestampField (1,1) string = "computerTimestamp"
    opts.Assignment double = []
    opts.SignalFs (1,1) struct = struct()
end

lineNames = string(fieldnames(events)).';
if ~ismember(opts.TrialLine, lineNames)
    error('pairEpsychTrials:NoTrialLine', 'No digital line "%s" (lines: %s).', ...
        opts.TrialLine, strjoin(lineNames, ", "));
end

% --- polarity ---------------------------------------------------------------
[events, inverted] = digitalLinePolarity(events, opts.InvertedLines, opts.NumSamples, Fs);
for ln = lineNames
    iv = double(events.(ln));
    if isempty(iv); iv = zeros(0, 2); end
    events.(ln) = iv;
end
trialIv = events.(opts.TrialLine);

nT = height(trials);
nI = size(trialIv, 1);
P = struct();
P.trialLine      = opts.TrialLine;
P.invertedLines  = inverted;
P.Fs             = Fs;
P.nTrials        = nT;
P.nIntervals     = nI;

% --- timestamps (seconds since the first valid one) ------------------------
ts = NaN(nT, 1);
if ismember(opts.TimestampField, string(trials.Properties.VariableNames)) && nT > 0
    raw = trials.(opts.TimestampField);
    if iscell(raw)
        ok = cellfun(@(x) isdatetime(x) && isscalar(x), raw);
        dt = NaT(nT, 1);
        dt(ok) = [raw{ok}];
        raw = dt;
    end
    if isdatetime(raw)
        raw = raw(:);
        first = raw(find(~isnat(raw), 1));
        if ~isempty(first)
            ts = seconds(raw - first);
        end
    end
end

% --- assignment -------------------------------------------------------------
c = NaN;
if ~isempty(opts.Assignment)
    a = double(opts.Assignment(:));
    if numel(a) ~= nT
        error('pairEpsychTrials:Assignment', 'Assignment has %d entries for %d trials.', numel(a), nT);
    end
    used = a(~isnan(a));
    if any(used < 1 | used > nI | used ~= round(used)) || numel(unique(used)) ~= numel(used)
        error('pairEpsychTrials:Assignment', ...
            'Assignment must hold distinct interval indices in 1..%d (NaN = unpaired).', nI);
    end
    P.method = "manual";
    have = ~isnan(a) & ~isnan(ts);
    if any(have)
        c = median(ts(have) - trialIv(a(have), 2));
    end
elseif sum(~isnan(ts)) >= 2 && nI > 0
    P.method = "timestamps";
    c = clockOffset(ts, trialIv(:, 2), opts.ToleranceS);
    a = alignDP(ts, trialIv(:, 2), c, opts);
    have = ~isnan(a) & ~isnan(ts);
    r = ts(have) - trialIv(a(have), 2) - c;
    inl = abs(r) <= opts.ToleranceS;
    if any(inl)
        c = c + median(r(inl));        % refine on the agreeing pairs
    end
else
    P.method = "order";
    a = NaN(nT, 1);
    n = min(nT, nI);
    a(1:n) = (1:n).';
    have = ~isnan(a) & ~isnan(ts);
    if any(have)
        c = median(ts(have) - trialIv(a(have), 2));
    end
end

paired = ~isnan(a);
P.interval = a;
P.onset = NaN(nT, 1);
P.offset = NaN(nT, 1);
P.onset(paired)  = trialIv(a(paired), 1);
P.offset(paired) = trialIv(a(paired), 2);
P.onsetSample  = round(P.onset * Fs);
P.offsetSample = round(P.offset * Fs);

P.signalFs = struct();
P.signalSamples = struct();
for sig = string(fieldnames(opts.SignalFs)).'
    fsSig = double(opts.SignalFs.(sig));
    if isscalar(fsSig) && isfinite(fsSig) && fsSig > 0
        P.signalFs.(sig) = fsSig;
        P.signalSamples.(sig) = round([P.onset P.offset] * fsSig);
    end
end

P.clockOffsetS = c;
P.residual = ts - P.offset - c;
P.flag = repmat("ok", nT, 1);
P.flag(paired & abs(P.residual) > opts.ToleranceS) = "timestamp off";
P.flag(~paired) = "unpaired";
P.unpairedTrials = find(~paired);
P.unpairedIntervals = setdiff((1:nI).', a(paired));
P.nPaired = sum(paired);
P.nTimestampOff = sum(P.flag == "timestamp off");

% --- other lines, per trial -------------------------------------------------
P.lines = struct();
others = lineNames(lineNames ~= opts.TrialLine);
trialEv = repmat(struct(), nT, 1);
trialEvS = repmat(struct(), nT, 1);
for ln = others
    iv = events.(ln);
    per = cell(nT, 1);
    for i = 1:nT
        if paired(i) && ~isempty(iv)
            per{i} = iv(iv(:, 1) <= P.offset(i) & iv(:, 2) >= P.onset(i), :);
        else
            per{i} = zeros(0, 2);
        end
        trialEv(i).(ln) = per{i};
        trialEvS(i).(ln) = round(per{i} * Fs);
    end
    P.lines.(ln) = per;
end

% --- columns to append to the trials table ---------------------------------
C = table(P.interval, P.onset, P.offset, P.onsetSample, P.offsetSample, ...
    'VariableNames', {'TrialInterval', 'TrialOnset', 'TrialOffset', 'TrialOnsetSample', 'TrialOffsetSample'});
for sig = string(fieldnames(P.signalSamples)).'
    C.("TrialOnsetSample_" + sig)  = P.signalSamples.(sig)(:, 1);
    C.("TrialOffsetSample_" + sig) = P.signalSamples.(sig)(:, 2);
end
C.TimestampResidual = P.residual;
C.PairingFlag = P.flag;
C.TrialEvents = trialEv;
C.TrialEventSamples = trialEvS;
P.columns = C;

P.summary = sprintf("%d of %d trial(s) paired with %d %s interval(s) (%s); %d unpaired interval(s), %d timestamp(s) off by > %g s", ...
    P.nPaired, nT, nI, opts.TrialLine, P.method, numel(P.unpairedIntervals), P.nTimestampOff, opts.ToleranceS);
end


function c = clockOffset(ts, off, tol)
%clockOffset  Most common timestamp - offset difference (a 2*tol window).
%   Ties (e.g. evenly spaced trials) go to the window nearest the in-order
%   offset, median(ts(i) - off(i)) over the first trials.
t = ts(~isnan(ts));
d = sort(reshape(t - off.', [], 1));
if isempty(d); c = NaN; return; end
m = min(numel(t), numel(off));
c0 = median(t(1:m) - off(1:m));
w = 2 * tol;
counts = zeros(numel(d), 1); centers = zeros(numel(d), 1);
hi = 1;
for lo = 1:numel(d)
    while hi < numel(d) && d(hi + 1) - d(lo) <= w
        hi = hi + 1;
    end
    counts(lo) = hi - lo + 1;
    centers(lo) = median(d(lo:hi));
end
best = find(counts == max(counts));
[~, pick] = min(abs(centers(best) - c0));
c = centers(best(pick));
end


function a = alignDP(ts, off, c, opts)
%alignDP  Order-preserving pairing of trials (ts) with intervals (off).
%   D(i+1,j+1) is the cheapest cost of the first i trials and j intervals.
%   Trials without a timestamp pair at a neutral cost of 1.
nT = numel(ts); nI = numel(off);
g = opts.GapCost;
D = inf(nT + 1, nI + 1);
B = zeros(nT + 1, nI + 1, 'uint8');     % 1 = pair, 2 = skip trial, 3 = skip interval
D(1, :) = (0:nI) * g;  B(1, 2:end) = 3;
D(:, 1) = (0:nT).' * g; B(2:end, 1) = 2;
for i = 1:nT
    if isnan(ts(i))
        cost = ones(1, nI);
    else
        r = abs(ts(i) - off.' - c);
        cost = min(r / opts.ToleranceS, opts.LateCost) + 0.02 * r;   % slope breaks ties toward the smaller residual
    end
    for j = 1:nI
        [D(i + 1, j + 1), B(i + 1, j + 1)] = min([D(i, j) + cost(j), D(i, j + 1) + g, D(i + 1, j) + g]);
    end
end
a = NaN(nT, 1);
i = nT; j = nI;
while i > 0 || j > 0
    switch B(i + 1, j + 1)
        case 1
            a(i) = j; i = i - 1; j = j - 1;
        case 2
            i = i - 1;
        otherwise
            j = j - 1;
    end
end
end
