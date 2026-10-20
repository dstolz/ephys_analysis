function [Z, info] = weightedCAR(Z, n, opts)
%weightedCAR  Adaptive weighted common average reference (Khorasani et al. 2019).
%   [S, INFO] = weightedCAR(Z, N, Fs=..., Q=...) removes from each channel
%   of Z its own adaptively weighted share of the common average N, as in
%   Khorasani, Shalchyan & Daliri 2019, "Adaptive Artifact Removal From
%   Intracortical Channels for Accurate Decoding of a Force Signal in
%   Freely Moving Rats", Front. Neurosci. 13:350
%   (doi:10.3389/fnins.2019.00350).
%
%   Each channel is modeled as z_i(t) = s_i(t) + w_i(t)' * n(t), where n(t)
%   holds the common average and its previous Order-1 values. A Kalman
%   filter tracks each channel's weights w_i sample by sample (the paper's
%   eqs. 6-8):
%       state        w(t+1) = alpha * w(t) + lambda,  lambda ~ N(0, V)
%       observation  z(t)   = n(t)' * w(t) + s(t),    s ~ N(0, q)
%   and the output is s_i = z_i - n' * w_i. Plain CAR is w_i = [1 0 ...]
%   held fixed.
%
%   Inputs
%     Z   [nSamples x nCol] microvolts, single or double; S is returned in
%         Z's class. Called as Z = weightedCAR(Z, ...), Z is overwritten in
%         place, one column at a time, and the recording is not copied.
%     N   [nSamples x 1], the plain common average of the reference
%         channels (EphysDataset.referenceTrace with Mode="car").
%
%   Options
%     Fs           Hz, required. The sample rate of Z and N.
%     Q            required, finite > 0: the observation variance q (uV^2),
%                  the variance of each channel's own signal s_i. The paper
%                  takes q = E[s_i^2]; deriveSignals' automatic value is the
%                  robust variance of the high-passed plain-CAR residual.
%     Order        M, 1..16 (default 1): the weights per channel, i.e. the
%                  common average and its previous M-1 samples. The paper
%                  does not state M for its recordings.
%     Alpha1k      (0, 1] (default 1): the state transition alpha at 1 kHz.
%                  alpha = Alpha1k^(1000/Fs) per sample, so the decay per
%                  second does not depend on Fs. alpha < 1 pulls the weights
%                  toward 0 (no reference). The paper's 0.99 was fitted to
%                  simulated ground truth; 1 (a random walk) was the more
%                  robust in our own simulations.
%     DriftPerSec  > 0 (default 1): the process variance per second; V =
%                  DriftPerSec/Fs * I per sample. Larger adapts faster.
%     HighpassHz   >= 0 (default 0.5, the paper's lower band edge): a
%                  zero-phase 4th-order Butterworth high-pass (second-order
%                  sections, FILTFILT) applied to Z and N before the weights
%                  are estimated. The subtracted term uses the high-passed
%                  N too, so nothing below HighpassHz is removed and a
%                  channel's DC offset never leaks into another through the
%                  weights. 0 = no high-pass.
%     Estimate     "prior" (default) | "posterior": the weights subtracted
%                  at sample t. "prior" is the one-step prediction
%                  alpha * w_hat(t-1), made before z(t) is seen.
%                  "posterior" is the paper's w_hat(t) (its Fig. 1 / eq. 8).
%                  The posterior residual is the innovation scaled by
%                  q / (n' * P^- * n + q), so a sample with a large common
%                  signal is scaled down whole, neural signal included (a
%                  soft blanking that distorts amplitudes).
%     W0           initial lag-0 weight (default 1: starts as plain CAR);
%                  the other lags start at 0. The first sample's prediction
%                  is [W0; 0 ...] with covariance P0 * I.
%     P0           > 0 (default 1): the initial weight variance.
%
%   Running a recording in pieces (EphysDataset's streamed weighted CAR)
%     Rows         [first last] (default all): the rows of Z whose weights
%                  are tracked and whose output is computed. The rows
%                  outside are only the high-pass's padding: they are
%                  filtered with the others and returned unchanged.
%     Initial      struct with fields P ([Order x Order]), W ([Order x
%                  nCol]) and NLag ([Order-1 x 1]): the prior state at
%                  Rows(1), i.e. the covariance, each column's predicted
%                  weights and the high-passed N of the Order-1 rows before
%                  it. Replaces W0 / P0 (default struct(): from them, with
%                  NLag 0, as at a recording's start).
%     StateRows    rows of Z within Rows, increasing (default none): the
%                  rows whose prior state INFO.states holds.
%     Output       true (default); false leaves Z as given (the state alone
%                  is wanted), so Z is not copied.
%   INFO.final is the prior state of the row after Rows(2), and
%   INFO.states the prior states at StateRows, so one piece continues
%   where the last left off (Initial = INFO.final) or any piece starts at
%   a stored state: the recursion is the same as one run over the whole.
%   Only the high-pass depends on the rows given: pad each piece on both
%   sides by the filter's memory (see EphysDataset.prepareWCAR).
%
%   Shared gain: V, q and P0 are the same for every channel (as in the
%   paper: "Parameters V and q were assumed constant for all intracortical
%   channels"), so the covariance P(t) and gain K(t) depend on N only. They
%   are computed once, and each channel then needs only
%       w <- alpha * (w + K(t) * (z_hp(t) - n_hp(t)' * w)).
%   This is the per-channel Kalman filter exactly, at 1/nCol of its cost.
%
%   INFO: Fs, Order, Alpha1k, DriftPerSec, Q, HighpassHz, Estimate, W0, P0,
%   alpha and V (per sample), weights, a summary per channel over time
%   (sampled every 0.1 s): p5, median, p95 and final, each [Order x nCol]
%   (row m = lag m-1), final (struct P, W, NLag: the prior state of the
%   row after the last one run) and states (struct rows, P [Order x Order
%   x k], W [Order x nCol x k], NLag [Order-1 x k]: the prior state at
%   each of StateRows).
%
%   Memory: the high-passed N and the gains ([Order x nSamples] double) are
%   held whole; each column is worked on in double, one at a time.
%
%   Requires the Signal Processing Toolbox (BUTTER, ZP2SOS, FILTFILT) and
%   the Statistics and Machine Learning Toolbox (PRCTILE).
%
%   See also EphysDataset.deriveSignals, EphysDataset.prepareWCAR,
%   EphysDataset.referenceTrace, EphysDataset.applyReference.

arguments
    Z {mustBeFloat, mustBeReal}
    n {mustBeFloat, mustBeReal}
    opts.Fs (1,1) double = NaN
    opts.Q (1,1) double = NaN
    opts.Order (1,1) double = 1
    opts.Alpha1k (1,1) double = 1
    opts.DriftPerSec (1,1) double = 1
    opts.HighpassHz (1,1) double = 0.5
    opts.Estimate (1,1) string = "prior"
    opts.W0 (1,1) double = 1
    opts.P0 (1,1) double = 1
    opts.Rows (1,:) double = []
    opts.Initial (1,1) struct = struct()
    opts.StateRows (1,:) double = []
    opts.Output (1,1) logical = true
end

[nS, nCol] = size(Z);
checkOptions(opts, n, nS, ismatrix(Z));
M = opts.Order;
alpha = opts.Alpha1k ^ (1000 / opts.Fs);
v = opts.DriftPerSec / opts.Fs;
q = opts.Q;
post = opts.Estimate == "posterior";
[r1, r2] = runRows(opts.Rows, nS);
nR = r2 - r1 + 1;
init = initialState(opts.Initial, opts.W0, opts.P0, M, nCol);
st = stateRows(opts.StateRows, r1, r2);   % relative to r1

% The common average, high-passed over every row given, then the rows run,
% with the M-1 values before the first of them (the lags: 0 before the
% recording starts); n(t)'s lag m-1 is nPad(t+M-m).
hp = highpassSOS(opts.HighpassHz, opts.Fs);
nh = filterHP(double(n(:)), hp);
nPad = [init.NLag; nh(r1:r2)];
[K, Pend, Pst] = gains(nPad, M, alpha, v, q, init.P, nR, st);
kn = [];
if post   % n(t)' * K(t), the share of the innovation the posterior takes
    kn = zeros(nR, 1);
    for m = 1:M
        kn = kn + nPad((1:nR) + M - m) .* K(m, :).';
    end
end

snapEvery = max(1, round(opts.Fs / 10));
nSnap = floor(nR / snapEvery);
wts = struct('p5', zeros(M, nCol), 'median', zeros(M, nCol), ...
    'p95', zeros(M, nCol), 'final', zeros(M, nCol));
Wst = zeros(M, nCol, numel(st));
for c = 1:nCol
    z = double(Z(:, c));
    zh = filterHP(z, hp);
    z = z(r1:r2);
    zh = zh(r1:r2);
    if M == 1
        [s, w, snaps, ws] = channelLag0(z, zh, nPad, K, kn, alpha, init.W(:, c), snapEvery, nSnap, st);
    else
        [s, w, snaps, ws] = channelLags(z, zh, nPad, K, kn, alpha, init.W(:, c), snapEvery, nSnap, st);
    end
    if opts.Output
        Z(r1:r2, c) = s;   % in Z's class
    end
    wts.final(:, c) = w;
    Wst(:, c, :) = reshape(ws, M, 1, []);
    if nSnap == 0
        snaps = w;
    end
    pr = prctile(snaps, [5 50 95], 2);
    wts.p5(:, c) = pr(:, 1);
    wts.median(:, c) = pr(:, 2);
    wts.p95(:, c) = pr(:, 3);
end

lagSt = zeros(M - 1, numel(st));
for j = 1:numel(st) * (M > 1)
    lagSt(:, j) = nPad(st(j) : st(j) + M - 2);   % the M-1 values before row st(j)
end
info = struct('Fs', opts.Fs, 'Order', M, 'Alpha1k', opts.Alpha1k, ...
    'DriftPerSec', opts.DriftPerSec, 'Q', q, 'HighpassHz', opts.HighpassHz, ...
    'Estimate', opts.Estimate, 'W0', opts.W0, 'P0', opts.P0, ...
    'alpha', alpha, 'V', v, 'weights', wts);
info.final = struct('P', Pend, 'W', wts.final, 'NLag', nPad(nR + 1 : end));
info.states = struct('rows', st + r1 - 1, 'P', Pst, 'W', Wst, 'NLag', lagSt);
end


function checkOptions(opts, n, nS, isMat)
%checkOptions  Required options, ranges and sizes.
bad = @(id, varargin) error(['weightedCAR:' id], varargin{:});
if ~isMat
    bad('Size', 'Z must be a [nSamples x nCol] matrix.');
end
if numel(n) ~= nS || ~(isvector(n) || isempty(n))
    bad('Size', 'N must be a vector with one value per row of Z (%d), not %d.', nS, numel(n));
end
if ~(isfinite(opts.Fs) && opts.Fs > 0)
    bad('Fs', 'Fs (the sample rate, Hz) is required and must be finite and positive.');
end
if ~(isfinite(opts.Q) && opts.Q > 0)
    bad('Q', 'Q (the observation variance, uV^2) is required and must be finite and positive.');
end
if ~(opts.Order >= 1 && opts.Order <= 16 && opts.Order == round(opts.Order))
    bad('Order', 'Order must be an integer in 1..16.');
end
if ~(opts.Alpha1k > 0 && opts.Alpha1k <= 1)
    bad('Alpha1k', 'Alpha1k must lie in (0, 1].');
end
if ~(isfinite(opts.DriftPerSec) && opts.DriftPerSec > 0)
    bad('DriftPerSec', 'DriftPerSec must be finite and positive.');
end
if ~(opts.HighpassHz >= 0 && opts.HighpassHz < opts.Fs / 2)
    bad('HighpassHz', 'HighpassHz must be 0 (none) or positive and below Fs/2 (%g Hz).', opts.Fs / 2);
end
if ~ismember(opts.Estimate, ["prior" "posterior"])
    bad('Estimate', 'Estimate must be "prior" or "posterior".');
end
if ~(isfinite(opts.W0) && isfinite(opts.P0) && opts.P0 > 0)
    bad('Initial', 'W0 must be finite and P0 finite and positive.');
end
end


function [r1, r2] = runRows(rows, nS)
%runRows  The first and last row run (Rows option; [] = all).
if isempty(rows)
    r1 = 1;
    r2 = nS;
    return
end
if ~(numel(rows) == 2 && all(rows == round(rows)) && rows(1) >= 1 && rows(2) <= nS && rows(2) >= rows(1) - 1)
    error('weightedCAR:Rows', 'Rows must be [first last] rows of Z (1..%d), first <= last + 1.', nS);
end
r1 = rows(1);
r2 = rows(2);
end


function S = initialState(init, W0, P0, M, nCol)
%initialState  The prior state at the first row run: from Initial, else
%   [W0; 0 ...] for every column with covariance P0 * I and lags 0.
S = struct('P', P0 * eye(M), 'W', repmat([W0; zeros(M - 1, 1)], 1, nCol), 'NLag', zeros(M - 1, 1));
if isempty(fieldnames(init))
    return
end
ok = all(isfield(init, {'P', 'W', 'NLag'})) && isnumeric(init.P) && isnumeric(init.W) ...
    && isnumeric(init.NLag) && isequal(size(init.P), [M M]) && isequal(size(init.W), [M nCol]) ...
    && numel(init.NLag) == M - 1;
if ok
    ok = all(isfinite(init.P), 'all') && all(isfinite(init.W), 'all') && all(isfinite(init.NLag));
end
if ~ok
    error('weightedCAR:Initial', ['Initial must hold finite P [%d x %d], W [%d x %d] and ' ...
        'NLag (%d values).'], M, M, M, nCol, M - 1);
end
S = struct('P', double(init.P), 'W', double(init.W), 'NLag', double(init.NLag(:)));
end


function st = stateRows(rows, r1, r2)
%stateRows  StateRows relative to the first row run, checked.
st = zeros(1, 0);
if isempty(rows)
    return
end
if ~(all(rows == round(rows)) && all(rows >= r1 & rows <= r2) && all(diff(rows) > 0))
    error('weightedCAR:StateRows', 'StateRows must be increasing rows within Rows (%d..%d).', r1, r2);
end
st = rows - r1 + 1;
end


function hp = highpassSOS(cutHz, Fs)
%highpassSOS  4th-order Butterworth high-pass as second-order sections
%   (stable far below Fs, as EphysDataset.filterContinuous uses them); []
%   for none.
hp = [];
if cutHz > 0
    [zz, pp, kk] = butter(4, cutHz / (Fs / 2), 'high');
    [hp.sos, hp.g] = zp2sos(zz, pp, kk);
end
end


function x = filterHP(x, hp)
%filterHP  Zero-phase high-pass of a double column (none for hp = []).
if ~isempty(hp) && numel(x) > 3 * 2 * size(hp.sos, 1)   % FILTFILT's minimum length
    x = filtfilt(hp.sos, hp.g, x);
end
end


function [K, P, Pst] = gains(nPad, M, alpha, v, q, P, nS, st)
%gains  The Kalman gain K(t) = P^- n / (n' P^- n + q), [M x nS], shared by
%   every channel, with P^-(1) = P (P0 * I at a recording's start) and
%   P^-(t+1) = alpha^2 * (P^- - K n' P^-) + V. P is returned as P^-(nS+1),
%   and PST holds P^- at the rows ST.
K = zeros(M, nS);
Pst = zeros(M, M, numel(st));
j = 1;
next = Inf;
if ~isempty(st); next = st(1); end
a2 = alpha^2;
if M == 1
    for t = 1:nS
        if t == next
            Pst(j) = P;
            j = j + 1;
            if j <= numel(st); next = st(j); else; next = Inf; end
        end
        nt = nPad(t);
        pn = P * nt;
        k = pn / (nt * pn + q);
        K(t) = k;
        P = a2 * (P - k * pn) + v;
    end
    return
end
V = v * eye(M);
for t = 1:nS
    if t == next
        Pst(:, :, j) = P;
        j = j + 1;
        if j <= numel(st); next = st(j); else; next = Inf; end
    end
    nt = nPad(t + M - 1:-1:t);
    pn = P * nt;
    d = nt.' * pn + q;
    K(:, t) = pn / d;
    P = a2 * (P - (pn * pn.') / d) + V;   % symmetric by construction
end
end


function [s, w, snaps, ws] = channelLag0(z, zh, nh, K, kn, alpha, w, snapEvery, nSnap, st)
%channelLag0  One channel, Order 1: scalar loop (fast under the JIT). WS
%   holds w^- at the rows ST.
nS = numel(z);
s = z;
snaps = zeros(1, nSnap);
ws = zeros(1, numel(st));
js = 1;
next = Inf;
if ~isempty(st); next = st(1); end
j = 0;
c = 0;
post = ~isempty(kn);
for t = 1:nS
    if t == next
        ws(js) = w;
        js = js + 1;
        if js <= numel(st); next = st(js); else; next = Inf; end
    end
    pred = nh(t) * w;                % n' * w^-(t)
    e = zh(t) - pred;                % innovation
    if post
        s(t) = z(t) - (pred + kn(t) * e);   % n' * w_hat(t)
    else
        s(t) = z(t) - pred;
    end
    w = alpha * (w + K(t) * e);      % w^-(t+1) = alpha * w_hat(t)
    c = c + 1;
    if c == snapEvery
        c = 0;
        j = j + 1;
        snaps(j) = w;
    end
end
end


function [s, w, snaps, ws] = channelLags(z, zh, nPad, K, kn, alpha, w, snapEvery, nSnap, st)
%channelLags  One channel, Order > 1: the lags as scalar inner loops. WS
%   holds w^- at the rows ST.
nS = numel(z);
M = numel(w);
s = z;
snaps = zeros(M, nSnap);
ws = zeros(M, numel(st));
js = 1;
next = Inf;
if ~isempty(st); next = st(1); end
j = 0;
c = 0;
post = ~isempty(kn);
for t = 1:nS
    if t == next
        ws(:, js) = w;
        js = js + 1;
        if js <= numel(st); next = st(js); else; next = Inf; end
    end
    pred = 0;
    for m = 1:M
        pred = pred + nPad(t + M - m) * w(m);
    end
    e = zh(t) - pred;
    if post
        s(t) = z(t) - (pred + kn(t) * e);
    else
        s(t) = z(t) - pred;
    end
    for m = 1:M
        w(m) = alpha * (w(m) + K(m, t) * e);
    end
    c = c + 1;
    if c == snapEvery
        c = 0;
        j = j + 1;
        snaps(:, j) = w;
    end
end
end
