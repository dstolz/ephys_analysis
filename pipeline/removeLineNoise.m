function [X, info] = removeLineNoise(X, opts)
%removeLineNoise  Subtract mains interference (a line frequency and its harmonics) fitted window by window.
%   [Y, INFO] = removeLineNoise(X, Fs=..., Name=Value) removes from each
%   column of X sinusoids at the line frequency (LineHz) and its Harmonics.
%   Their frequency is re-estimated in every window, within MaxDeviationHz
%   of LineHz, and each channel's amplitude and phase are its own. The
%   fitted sinusoids are subtracted, nothing is filtered: the signal beside
%   the line keeps its phase, and transients do not ring as they do through
%   a notch.
%
%   Method
%     1. Windows of WindowSec, half overlapping, each weighted by a Hann
%        taper. Every sum below is over whole line cycles (blocks of
%        BlockSamples), made once from X in a single pass: the harmonics and
%        their mirror images fall on the nulls of a whole-cycle sum, so the
%        harmonics are measured one apart from another.
%     2. Frequency: in each window, the fundamental f within LineHz +/-
%        MaxDeviationHz (harmonic k at k*f) at which the line power, summed
%        over the harmonics and channels and each term divided by its own
%        background, is largest. A window whose peak does not stand clear of
%        the noise is not trusted: it takes its neighbors' frequency. A
%        running median over SmoothWindows windows steadies the track.
%     3. Amplitude and phase: each channel's Hann-weighted projection onto
%        each harmonic at that frequency (least squares, for windows of many
%        cycles). The background is the same projection at 3-6 frequency
%        resolutions (1/WindowSec) on either side; the Hann taper's nulls
%        fall there, so a strong line does not inflate it (a window with
%        part of its taper missing has no such nulls and takes the nearest
%        whole window's background). SNR = line power over background, and
%        Gate scales each fit by it.
%     4. Each window's sinusoids are crossfaded into the next with the Hann
%        taper (the two weights sum to 1) and subtracted from X.
%
%   Channels
%     The frequency is the mains' own, the same on every channel recorded
%     together, so it is estimated from all channels at once (PerChannel
%     false): the channels with the most line set it, and a quiet channel
%     is not left to find a frequency of its own in its neural signal.
%     Amplitude and phase are always per channel. A channel is never given
%     another channel's sinusoid: what is subtracted from it is the
%     projection of its own signal, and with Gate "soft" (or "hard") only
%     as far as its line stands out of its own background. A channel with
%     no line keeps its signal, and a broadband transient (whose projection
%     is no larger than its background) is not taken for line noise.
%
%   Inputs
%     X   [nSamples x nCol], single or double; Y has X's class. NaN or Inf
%         samples stay as they are and take no part in any fit (their
%         blocks are left out for that channel). Called as
%         X = removeLineNoise(X, ...), X is overwritten in place.
%
%   Options
%     Fs              Hz, required.
%     LineHz          Hz (default 60): the nominal line frequency (50 in
%                     Europe).
%     Harmonics       positive integers (default 1:3): the harmonics
%                     removed, 1 = LineHz itself; each must stay below
%                     Nyquist.
%     WindowSec       s (default 2): the fit window; windows step by half
%                     of it. Longer = finer frequency estimates and a
%                     narrower band taken from the signal (about
%                     2/WindowSec Hz around each harmonic), but slower
%                     tracking of the line's amplitude. Rounded to whole
%                     blocks (INFO.WindowSec is the one used).
%     MaxDeviationHz  Hz >= 0 (default 0.25): how far the fundamental may
%                     be from LineHz. Power grids hold well within 0.1 Hz;
%                     a wider range costs time and, on a weak line, lets
%                     the search wander. 0 = LineHz exactly.
%     Tracking        "window" (default): a frequency per window, as above.
%                     "global": one frequency for all of X, the best over
%                     every window together (short or quiet recordings).
%                     "fixed": LineHz exactly.
%     SmoothWindows   odd number of windows >= 1 (default 5): the running
%                     median over the trusted windows' frequencies
%                     (Tracking "window"). 1 = each window's own estimate.
%     PerChannel      false (default): one frequency for all channels.
%                     true: each channel's own (channels not recorded
%                     together); slower, and weak on a quiet channel.
%     Gate            "soft" (default): each fit is scaled by
%                     max(0, 1 - 1/SNR), so a line far above its background
%                     is removed whole and a channel or window without one
%                     is barely touched. "hard": removed whole where SNR >=
%                     MinSNR, else left. "none": always removed whole.
%     MinSNR          dB (default 6): the "hard" gate's threshold.
%     Exclude         [k x 2] rows [first last] of X (default none): left
%                     out of every fit, e.g. artifact periods. The line is
%                     still subtracted there, from the windows around them.
%                     A window with less than 40% of its taper left is not
%                     fitted; its neighbor's sinusoids reach over it.
%
%   Running a recording in pieces
%     FirstRow        the recording row of X's first row (default 1). The
%                     windows and blocks are laid on the recording's own
%                     grid, so a piece run with INFO.MarginRows extra rows
%                     on either side gives, between the margins, what one
%                     run over the whole recording gives (Tracking "window"
%                     or "fixed"; an untrusted window's frequency and a
%                     partial window's background come from the nearest
%                     good window within the piece).
%
%   INFO: Fs, LineHz, Harmonics, WindowSec and HopSec (as used),
%   BlockSamples, MaxDeviationHz, Tracking, SmoothWindows, PerChannel,
%   Gate, MinSNR, MarginRows; per window: time (s, the window's center,
%   (row-1)/Fs), frequency (Hz, [nWin x 1], or [nWin x nCol] with
%   PerChannel), trusted (same size: the window's own search found a clear
%   line), fitted ([nWin x nCol]: enough data to fit), amplitude ([nWin x
%   nCol x nHarmonics], the peak amplitude subtracted, X's units) and snr
%   (same size, dB, NaN where not fitted).
%
%   Accuracy: the whole-cycle nulls sit at the nominal harmonics, so a line
%   off LineHz by d leaks into its neighbors' fits at about d/LineHz: the
%   residual of a steady line is near -80 dB on LineHz and -55 dB 0.1 Hz
%   off (blocks of a non-whole number of samples, e.g. TDT's 24414.0625 Hz,
%   add a little). In recordings, noise and the line's own changes within a
%   window are what limit it.
%
%   Speed and memory: one pass over X for the block sums and one to
%   subtract, each in double a few hundred MB at a time; the search and
%   fits work on the block sums (one per few line cycles). About 2 min per
%   64-channel hour at 30 kHz. X is not copied whole.
%
%   Needs no toolbox.
%
%   See also EphysDataset.deriveSignals, weightedCAR.

arguments
    X {mustBeFloat, mustBeReal}
    opts.Fs (1,1) double = NaN
    opts.LineHz (1,1) double {mustBePositive, mustBeFinite} = 60
    opts.Harmonics (1,:) double {mustBeInteger, mustBePositive} = 1:3
    opts.WindowSec (1,1) double {mustBePositive, mustBeFinite} = 2
    opts.MaxDeviationHz (1,1) double {mustBeNonnegative, mustBeFinite} = 0.25
    opts.Tracking (1,1) string {mustBeMember(opts.Tracking, ["window" "global" "fixed"])} = "window"
    opts.SmoothWindows (1,1) double {mustBeInteger, mustBePositive} = 5
    opts.PerChannel (1,1) logical = false
    opts.Gate (1,1) string {mustBeMember(opts.Gate, ["soft" "hard" "none"])} = "soft"
    opts.MinSNR (1,1) double {mustBeNonNan} = 6
    opts.Exclude (:,2) double {mustBeInteger} = zeros(0, 2)
    opts.FirstRow (1,1) double {mustBeInteger, mustBePositive} = 1
end

if ~ismatrix(X)
    error('removeLineNoise:X', 'X must be [nSamples x nCol].');
end
if mod(opts.SmoothWindows, 2) ~= 1
    error('removeLineNoise:SmoothWindows', 'SmoothWindows must be odd (%d).', opts.SmoothWindows);
end
[N, nCh] = size(X);
if any(opts.Exclude(:) < 1 | opts.Exclude(:) > N) || any(opts.Exclude(:, 1) > opts.Exclude(:, 2))
    error('removeLineNoise:Exclude', 'Exclude rows must be [first last] pairs within 1..%d.', N);
end
G = geometry(opts);

% Windows j are centered on recording sample j*H (0-based) and span
% [(j-1)*H, (j+1)*H): those from jmin to jmax cover X. Blocks b span
% [b*D, (b+1)*D); window j holds blocks (j-1)*nBh .. (j+1)*nBh-1.
r0 = opts.FirstRow - 1;
jmin = floor(r0 / G.H);
jmax = floor((r0 + N - 1) / G.H) + 1;
nWin = jmax - jmin + 1;
centers = (jmin:jmax)' * G.H;
[Z, valid] = blockSums(X, G, r0, (jmin - 1) * G.nBh, (nWin + 1) * G.nBh, opts.Exclude);
idx = (0:nWin-1) * G.nBh + (1:2*G.nBh)';
wSum = reshape(G.hb' * reshape(double(valid(idx, :)), 2 * G.nBh, []), nWin, nCh);
fitted = wSum >= MIN_COVER * sum(G.hb);

nScope = 1 + (nCh - 1) * opts.PerChannel;
trusted = false(nWin, nScope);
if opts.Tracking == "fixed" || G.dev == 0
    delta = zeros(nWin, nScope);
else
    [dWin, trusted, dAll] = searchFrequency(Z, idx, fitted, G, opts.PerChannel);
    if opts.Tracking == "global"
        delta = repmat(dAll, nWin, 1);
    else
        delta = smoothTrack(dWin, trusted, opts.SmoothWindows);
    end
end
[A, snr] = lineFits(Z, idx, fitted, wSum, delta, centers, G, opts);
X = subtractLines(X, A, fitted, delta, G, r0, jmin);

if opts.Tracking == "global"
    margin = Inf;
elseif opts.Tracking == "fixed"
    margin = 2 * G.H;
else
    margin = ((opts.SmoothWindows - 1) / 2 + 2) * G.H;
end
info = struct('Fs', G.Fs, 'LineHz', G.f0, 'Harmonics', G.K, 'WindowSec', G.T, ...
    'HopSec', G.H / G.Fs, 'BlockSamples', G.D, 'MaxDeviationHz', opts.MaxDeviationHz, ...
    'Tracking', opts.Tracking, 'SmoothWindows', opts.SmoothWindows, ...
    'PerChannel', opts.PerChannel, 'Gate', opts.Gate, 'MinSNR', opts.MinSNR, ...
    'MarginRows', margin, 'time', centers / G.Fs, 'frequency', G.f0 + delta, ...
    'trusted', trusted, 'fitted', fitted, 'amplitude', abs(A), 'snr', snr);
end


function m = BACKGROUND
%BACKGROUND  The background's offsets from a harmonic, in frequency resolutions (1/T).
m = 3:6;
end


function c = MIN_COVER
%MIN_COVER  The share of a window's taper that must hold data for it to be fitted.
c = 0.4;
end


function G = geometry(opts)
%geometry  Blocks, windows and taper. A block is m whole line cycles, so
%   every harmonic and mirror image lands on a null of the block sum; m is
%   the largest whose block rate LineHz/m still leaves 2.5x room for the
%   frequency search plus the background offsets, preferring the m whose
%   cycles are the closest to whole samples (exact when Fs/LineHz is).
Fs = opts.Fs;
if ~(isfinite(Fs) && Fs > 0)
    error('removeLineNoise:Fs', 'Fs (the sample rate, Hz) is required.');
end
G.Fs = Fs;
G.f0 = opts.LineHz;
G.K = unique(opts.Harmonics);
G.nK = numel(G.K);
G.dev = opts.MaxDeviationHz * (opts.Tracking ~= "fixed");
kmax = G.K(end);
reach = @(T) max(BACKGROUND) / T + kmax * G.dev;   % farthest offset, Hz
if kmax * (G.f0 + G.dev) + reach(opts.WindowSec) >= Fs / 2
    error('removeLineNoise:Harmonics', ...
        'Harmonic %d of %g Hz (+/- %g Hz and the background beside it) is not below Nyquist (%g Hz).', ...
        kmax, G.f0, G.dev, Fs / 2);
end
mMax = floor(G.f0 / (2.5 * reach(opts.WindowSec)));
if mMax < 1
    room = G.f0 / 2.5 - kmax * G.dev;
    if room > 0
        need = sprintf('at least %.3g s', max(BACKGROUND) / room);
    else
        need = 'a smaller MaxDeviationHz or fewer harmonics';
    end
    error('removeLineNoise:WindowSec', ...
        'WindowSec %g s is too short for MaxDeviationHz %g up to harmonic %d of %g Hz: %s.', ...
        opts.WindowSec, G.dev, kmax, G.f0, need);
end
cyc = (1:mMax) * Fs / G.f0;
err = abs(cyc - round(cyc)) ./ cyc;
m = find(err <= min(err) + 1e-12, 1, 'last');
G.D = max(1, round(cyc(m)));
G.nBh = max(2, round(opts.WindowSec * Fs / (2 * G.D)));
G.H = G.nBh * G.D;
G.T = 2 * G.H / Fs;
if reach(G.T) >= Fs / G.D / 2
    error('removeLineNoise:WindowSec', 'WindowSec %g s is too short at %g Hz.', opts.WindowSec, Fs);
end
G.tau = ((0:2*G.nBh-1)' - G.nBh) * G.D + (G.D - 1) / 2;   % block centers re the window's
G.hb = cos(pi * G.tau / (2 * G.H)).^2;
G.offs = [-flip(BACKGROUND) BACKGROUND]' / G.T;
end


function [Z, valid] = blockSums(X, G, r0, b0, nB, exclude)
%blockSums  Z(b, ch, k): the sum over block b of X times exp(-i*w_k*n),
%   w_k = 2*pi*K(k)*LineHz/Fs, n the recording sample (0-based); b counts
%   from block b0. Only blocks wholly inside X, without NaN / Inf and
%   clear of EXCLUDE are valid; the others are 0.
[N, nCh] = size(X);
Z = complex(zeros(nB, nCh, G.nK));
valid = false(nB, nCh);
w = 2 * pi * G.K * G.f0 / G.Fs;
inner = exp(-1i * (0:G.D-1)' * w);
Q = [real(inner) imag(inner)].';
bf = ceil(r0 / G.D);
bl = floor((r0 + N) / G.D) - 1;
per = max(1, floor(2^24 / (G.D * nCh)));   % blocks per pass: ~128 MB of double
for s = bf:per:bl
    e = min(bl, s + per - 1);
    nb = e - s + 1;
    rows = s * G.D - r0 + (1:nb*G.D);
    S = Q * reshape(double(X(rows, :)), G.D, nb * nCh);
    z = complex(S(1:G.nK, :), S(G.nK+1:end, :));
    z = permute(reshape(z, G.nK, nb, nCh), [2 3 1]);
    z = z .* reshape(exp(-2i * pi * mod((s:e)' * G.D * (G.K * G.f0) / G.Fs, 1)), nb, 1, G.nK);
    ok = all(isfinite(z), 3);
    z(repmat(~ok, 1, 1, G.nK)) = 0;
    L = s - b0 + (1:nb);
    Z(L, :, :) = z;
    valid(L, :) = ok;
end
for r = 1:size(exclude, 1)
    L = (floor((r0 + exclude(r, 1) - 1) / G.D):floor((r0 + exclude(r, 2) - 1) / G.D)) - b0 + 1;
    L = L(L >= 1 & L <= nB);
    valid(L, :) = false;
    Z(L, :, :) = 0;
end
end


function per = groupSize(G, nCh, nRow)
%groupSize  Windows worked on at once: about 256 MB of block sums and grid.
per = max(1, floor(2^28 / (nCh * (2 * G.nBh * G.nK * 16 + nRow * 16))));
end


function [dWin, trusted, dAll] = searchFrequency(Z, idx, fitted, G, perChannel)
%searchFrequency  The fundamental's offset from LineHz per window (and over
%   all windows), from J(d) = sum over harmonics (and channels) of the line
%   power at k*(LineHz + d), each term over its background: on a grid of d
%   fine enough for the highest harmonic's peak, refined by a parabola.
%   A window is trusted when its peak is 5 SD above J's mean under noise
%   alone (each term ~1, so mean n, SD sqrt(n) over n terms).
[nWin, nCh] = size(fitted);
step = max(1 / (32 * G.K(end) * G.T), 2 * G.dev / 256);
nG = 2 * ceil(G.dev / step) + 1;
grid = linspace(-G.dev, G.dev, nG)';
E = cell(1, G.nK);
Eb = cell(1, G.nK);
for k = 1:G.nK
    E{k} = G.hb.' .* exp(-2i * pi * G.K(k) * grid * G.tau.' / G.Fs);
    off = sign(G.offs) .* (abs(G.offs) + G.K(k) * G.dev);   % beyond the search band
    Eb{k} = G.hb.' .* exp(-2i * pi * off * G.tau.' / G.Fs);
end
nScope = 1 + (nCh - 1) * perChannel;
dWin = zeros(nWin, nScope);
jPeak = zeros(nWin, nScope);
nTerm = zeros(nWin, nScope);
jSum = zeros(nG, nScope);
per = groupSize(G, nCh, nG);
for w1 = 1:per:nWin
    w = w1:min(nWin, w1 + per - 1);
    nw = numel(w);
    Zg = reshape(Z(idx(:, w), :, :), 2 * G.nBh, nw * nCh, G.nK);
    ok = reshape(fitted(w, :), 1, []);
    P = cell(1, G.nK);
    mu = cell(1, G.nK);
    top = zeros(1, nw * nCh);
    for k = 1:G.nK
        P{k} = abs(E{k} * Zg(:, :, k)).^2;
        mu{k} = median(abs(Eb{k} * Zg(:, :, k)).^2, 1) / log(2);
        top = max(top, max(P{k}, [], 1));
    end
    % The block sums leak each harmonic into the others at about
    % |offset|/LineHz: no background is taken as lower than that, or a
    % harmonic holding only leakage would pull the peak.
    least = max((G.dev / G.f0)^2, 1e-12) * top;
    J = zeros(nG, nw * nCh);
    n = zeros(1, nw * nCh);
    for k = 1:G.nK
        m = max(mu{k}, least);
        use = ok & m > 0;
        J(:, use) = J(:, use) + P{k}(:, use) ./ m(use);
        n = n + use;
    end
    if ~perChannel
        J = sum(reshape(J, nG, nw, nCh), 3);
        n = sum(reshape(n, nw, nCh), 2)';
    end
    [pk, d] = peak(J, grid);
    dWin(w, :) = reshape(d, nw, nScope);
    jPeak(w, :) = reshape(pk, nw, nScope);
    nTerm(w, :) = reshape(n, nw, nScope);
    jSum = jSum + reshape(sum(reshape(J, nG, nw, nScope), 2), nG, nScope);
end
trusted = nTerm > 0 & jPeak >= nTerm + 5 * sqrt(nTerm);
[~, dAll] = peak(jSum, grid);
end


function [pk, d] = peak(J, grid)
%peak  Each column's maximum over GRID, refined by a parabola through it and its neighbors.
[pk, p] = max(J, [], 1);
d = grid(p).';
nG = numel(grid);
in = find(p > 1 & p < nG);
if isempty(in)
    return
end
lin = (in - 1) * nG + p(in);
y1 = J(lin - 1);
y2 = J(lin);
y3 = J(lin + 1);
den = y1 - 2 * y2 + y3;
frac = 0.5 * (y1 - y3) ./ den;
frac(~(den < 0)) = 0;
d(in) = d(in) + min(0.5, max(-0.5, frac)) * (grid(2) - grid(1));
end


function d = smoothTrack(d, trusted, n)
%smoothTrack  The trusted windows' frequencies, median-smoothed over N
%   windows; the others take the nearest trusted one (LineHz if none).
d(~trusted) = NaN;
if n > 1
    d = movmedian(d, n, 1, 'omitnan');
end
d = fillmissing(d, 'nearest', 1);
d(isnan(d)) = 0;
end


function [A, snr] = lineFits(Z, idx, fitted, wSum, delta, centers, G, opts)
%lineFits  A(w, ch, k): the complex amplitude of harmonic k in window w,
%   gated, such that the line is 2*Re(A * exp(i*w_k*(n - center))) with
%   w_k = 2*pi*K(k)*(LineHz + delta)/Fs. The projection at the fitted
%   frequency divides out the taper's sum, the block length and the block
%   sum's gain at that offset from K(k)*LineHz (the Dirichlet kernel).
%   A window with part of its taper missing (the ends of X, Exclude, NaN)
%   has no nulls at the background offsets, so the line leaks into its own
%   background there: it takes the nearest whole window's background.
[nWin, nCh] = size(fitted);
A = complex(zeros(nWin, nCh, G.nK));
mu = NaN(nWin, nCh, G.nK);
Eo = G.hb.' .* exp(-2i * pi * [0; G.offs] * G.tau.' / G.Fs);
per = groupSize(G, nCh, 1);
for w1 = 1:per:nWin
    w = w1:min(nWin, w1 + per - 1);
    nw = numel(w);
    Zg = reshape(Z(idx(:, w), :, :), 2 * G.nBh, nw * nCh, G.nK);
    if size(delta, 2) == 1
        dcol = repmat(delta(w), 1, nCh);
    else
        dcol = delta(w, :);
    end
    dcol = reshape(dcol, 1, []);
    ws = reshape(wSum(w, :), 1, []);
    ph = reshape(repmat(centers(w), 1, nCh), 1, []);
    for k = 1:G.nK
        nu = 2 * pi * G.K(k) * dcol / G.Fs;
        c = Eo * (Zg(:, :, k) .* exp(-1i * G.tau * nu));
        c = c ./ (G.D * ws .* dirichlet(nu + 2 * pi * [0; G.offs] / G.Fs, G.D));
        A(w, :, k) = reshape(2 * c(1, :) .* exp(2i * pi * mod(G.K(k) * G.f0 * ph / G.Fs, 1)), nw, nCh);
        mu(w, :, k) = reshape(4 * median(abs(c(2:end, :)).^2, 1) / log(2), nw, nCh);
    end
end
A(~repmat(fitted, 1, 1, G.nK)) = 0;   % no data: c is 0/0
whole = repmat(wSum >= (1 - 1e-9) * sum(G.hb), 1, 1, G.nK);
if any(whole(:)) && ~all(whole(:))
    m = mu;
    m(~whole) = NaN;
    m = fillmissing(m, 'nearest', 1);
    mu(~whole & ~isnan(m)) = m(~whole & ~isnan(m));
end
s = abs(A).^2 ./ mu;
switch opts.Gate
    case "soft"
        g = max(0, 1 - 1 ./ s);
    case "hard"
        g = double(s >= 10^(opts.MinSNR / 10));
    otherwise
        g = ones(size(s));
end
g(isnan(g)) = 0;
A = A .* g;
s(~repmat(fitted, 1, 1, G.nK)) = NaN;
snr = 10 * log10(s);
end


function g = dirichlet(nu, D)
%dirichlet  The gain of a D-sample block sum, per sample, at NU rad/sample (1 at 0).
g = sin(nu * D / 2) ./ (D * sin(nu / 2));
g(nu == 0) = 1;
end


function X = subtractLines(X, A, fitted, delta, G, r0, jmin)
%subtractLines  Subtract the fits, hop by hop: the rows between window
%   centers i and i+1 take sin^2 / cos^2 shares of the two (summing to 1);
%   where one of them was not fitted, the other's alone.
[N, nCh] = size(X);
nWin = size(A, 1);
perCh = size(delta, 2) > 1;
for i = 1:nWin-1
    j = jmin + i - 1;
    n1 = max(j * G.H, r0);
    n2 = min((j + 1) * G.H, r0 + N) - 1;
    vl = fitted(i, :);
    vr = fitted(i + 1, :);
    if n2 < n1 || ~any(vl | vr)
        continue
    end
    nr = n2 - n1 + 1;
    t1 = n1 - j * G.H;
    tau = t1 + (0:nr-1)';
    wr = sin(pi * tau / (2 * G.H)).^2;
    wl = 1 - wr;
    Al = reshape(A(i, :, :), nCh, G.nK).';
    Ar = reshape(A(i + 1, :, :), nCh, G.nK).';
    both = vl & vr;
    C = [Al .* both; Ar .* both; Al .* (vl & ~vr); Ar .* (vr & ~vl)];
    % Re(B * C) as one real product, in X's class
    C = cast([real(C); -imag(C)], 'like', X);
    if ~perCh
        Pl = phasors(t1, nr, 2 * pi * G.K * (G.f0 + delta(i)) / G.Fs);
        Pr = phasors(t1 - G.H, nr, 2 * pi * G.K * (G.f0 + delta(i + 1)) / G.Fs);
        B = [wl .* Pl, wr .* Pr, Pl, Pr];
        S = cast([real(B) imag(B)], 'like', X) * C;
    else
        S = zeros(nr, nCh, 'like', X);
        for ch = find(vl | vr)
            Pl = phasors(t1, nr, 2 * pi * G.K * (G.f0 + delta(i, ch)) / G.Fs);
            Pr = phasors(t1 - G.H, nr, 2 * pi * G.K * (G.f0 + delta(i + 1, ch)) / G.Fs);
            B = [wl .* Pl, wr .* Pr, Pl, Pr];
            S(:, ch) = cast([real(B) imag(B)], 'like', X) * C(:, ch);
        end
    end
    rows = n1 - r0 + (1:nr);
    X(rows, :) = X(rows, :) - S;
end
end


function P = phasors(t0, n, w)
%phasors  exp(1i*(t0 + (0:n-1)')*w) for the frequencies W (rad/sample, a
%   row), as the product of an in-block and a block-start table: two short
%   EXPs instead of n per frequency.
b = ceil(sqrt(n));
nK = numel(w);
inner = exp(1i * (0:b-1)' * w);
outer = exp(1i * (t0 + (0:b:n-1)') * w);
P = reshape(reshape(inner, b, 1, nK) .* reshape(outer, 1, [], nK), [], nK);
P = P(1:n, :);
end
