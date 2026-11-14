function R = rippleStrf(spikes, records, index, sets, opts)
%rippleStrf  Spectrotemporal receptive fields from responses to TORCs or dynamic moving ripples.
%   R = rippleStrf(SPIKES, RECORDS, INDEX, SETS) estimates, for each set of
%   epochs, the spectrotemporal receptive field (STRF) of a spike train
%   from the stimuli the epochs presented, with its significance, ripple
%   transfer function, conditioned response histogram and statistics:
%     SPIKES   nE x 1 cell: each epoch's spike times, s from its stimulus
%              onset (epochSpikes of a window covering the stimulus)
%     RECORDS  1 x nU cell: stimgen generation records (stimgen.TORC or
%              stimgen.DMR, Generated true: rippleStimuli's records)
%     INDEX    nE x 1: each epoch's record (NaN: the epoch is not used)
%     SETS     nE x 1: each epoch's set, 1..nS (NaN: not used), e.g. its
%              trial group or bank item. Each set gets its own STRF
%
%   Every set holds one kind of stimulus (a set mixing TORCs, DMRs and
%   ripple noise is refused: rippleStrf:MixedStimuli) on one carrier grid
%   (rippleStrf:Grid). Times are on a grid of Rate Hz (default 4000, the
%   rate Escabi & Schreiner sampled their envelopes at): each spike is
%   placed at the nearest grid time, and the STRF is read at lags
%   0:1/Rate:MaxLag (default 0.1 s, their 0-100 ms). Each presentation is
%   analyzed from Skip s after its onset to its end; the spikes in the
%   first Skip s are left out (default NaN = automatic: MaxLag for a DMR or
%   ripple noise, so every lag reads the stimulus; for a TORC one ripple
%   period when it holds two or more, else 0). The envelope is the one
%   each presentation played: stimgen.TORC.envelope_from_record and
%   stimgen.DMR.envelope_from_record (stimgen on the MATLAB path), or the
%   function Envelope= names.
%
%   The STRF (Escabi MA, Schreiner CE 2002, J Neurosci 22:4114-4131;
%   Klein DJ, Depireux DA, Simon JZ, Shamma SA 2000, J Comput Neurosci
%   9:85-111) is a sum of the envelope S (dB) at each spike's lags,
%   divided by a normalizer and the time analyzed:
%     DMR, ripple noise   STRF(tau,x) = 1/(sigma^2 T) sum_n S(t_n - tau, x)
%                         (Escabi & Schreiner Eq. 10): sigma^2 the mean
%                         square of the envelope over the time analyzed (dB^2;
%                         M^2/8 for a DMR), T that time (s). Units: spikes/s
%                         per dB. strfRate = sigma * STRF (their rate-normalized
%                         STRF, spikes/s) is what is drawn
%     TORC                C(tau,x) = 1/T sum_n S(t_n - tau, x) of each TORC
%                         (Klein et al. Eq. 19, the period-averaged
%                         response against one period: the envelope is
%                         periodic, so lags before the onset read the
%                         period before), STRF = C / a^2 (Eq. 38), a the
%                         TORC's RippleAmplitude; TORCs of one ripple set
%                         (the same rates and densities: phase averaging,
%                         Eq. 33-34) averaged, different sets (method I)
%                         summed (Eq. 39). Sets that share a ripple
%                         component are refused (rippleStrf:Overlap): the
%                         sum would count it twice. Units: spikes/s per
%                         dB; strfRate = STRF
%   Significance (Escabi & Schreiner, "Statistically significant STRF"):
%   with spike times unrelated to the stimulus, each pixel is normal with
%   mean 0 and variance sum_u w_u^2 N_u sigma_u^2 (w_u the weight of
%   stimulus u above, N_u its spikes, sigma_u^2 its envelope's mean
%   square): pixels beyond z = sqrt(2) erfcinv(Alpha) times that SD are
%   significant (Alpha 0.002: 3.09 SD). For a TORC this is the same null
%   applied to the TORC's envelope (Klein et al. state none). R.sets.sig
%   is that mask; strfSig the drawn STRF with the other pixels 0.
%
%   R.sets(s), for each set:
%     label, kind ("TORC" | "DMR" | "RN"), nEpochs, nStimuli, nSpikes (the
%     spikes analyzed), duration (T, s), rate (nSpikes / T, spikes/s), skip
%     (s; a TORC's per stimulus), lags (1 x nL, s), x (nX x 1, octaves above
%     the lowest carrier), freq (nX x 1, Hz), strf, strfRate, strfSig
%     (nX x nL), units (of strfRate), sigma2 (DMR, RN: dB^2; TORC: NaN),
%     amplitude (TORC: each stimulus's a, dB), threshold (the SD times z,
%     in STRF units), sig (logical nX x nL), rippleSets (TORC: how many),
%     droppedSpikes (in the stimulus but off the grid's end, or, for a DMR,
%     too early for every lag to read the stimulus)
%     rtf (nOmega x nFm), rtfFm (1 x nFm, Hz), rtfOmega (nOmega x 1, c/o):
%       the ripple transfer function, |H(w, Omega)| of the significant
%       STRF (strfSig), Klein et al. Eq. 14: H(w, Omega) = 1/(TX) sum over
%       tau, x of STRF(tau, x) exp(-i 2 pi (w tau - Omega x)), on
%       Omega >= 0 (the rest is its mirror). H is indexed by the stimulus
%       ripple: w > 0 with Omega > 0 is a downward-moving ripple (the TORC's
%       positive RippleDensity, the DMR's positive Fm), as the CRH's axes.
%       Escabi & Schreiner draw their RTFs with the opposite sign of Fm
%       (positive = upward sweep). RtfPad (default 1) zero-pads the
%       transform RtfPad times in each dimension (a finer grid, the same
%       transform)
%     best: the best ripple, struct with fm, omega (Hz, c/o: |H|'s peak;
%       Escabi & Schreiner's bTM, bRD), magnitude, and the peaks of each
%       half (fmPos, omegaPos, magPos for w >= 0; fmNeg, omegaNeg, magNeg
%       for w <= 0); secondary true when the other half's peak is at least
%       half the best's (their rule for a second best); NaN with no
%       significant pixel
%     crh (nOmega x nFm counts), crhRate (spikes/s: counts / crhOccupancy),
%       crhOccupancy (s the stimulus spent in each bin over the time
%       analyzed), crhFmEdges, crhOmegaEdges: the conditioned response
%       histogram of a DMR (Escabi & Schreiner Eq. 15): each spike counted
%       at the Fm and Omega its stimulus had CrhLag s (default 0) before
%       it, in bins CrhBins = [dFm dOmega] (default [25 0.25]); [] for a
%       TORC or ripple noise (its envelope is a sum of NumEnvelopes ripples)
%     energy   DMR, RN: Eq. 13, sqrt(sum over x and tau of strfSig^2 dtau)
%              (strfSig of the rate-normalized STRF, dtau in s); NaN for
%              a TORC
%     pli      DMR, RN: Eq. 14, (max - min of strfSig) / rate / Delta,
%              Delta = (max S - min S) / sigma of the envelopes played
%              (Appendix C: sqrt(8) for a DMR, sqrt(12) for uniform ripple
%              noise); NaN for a TORC
%     delta    that Delta
%     snrMean, snrMax   with SnrSpikes (default 100) spikes chosen at
%              random (a fixed seed: the same each time; the global stream
%              is not touched), their STRF's significant pixels' rms and
%              maximum |value| in SDs of the null (Escabi & Schreiner); NaN
%              with fewer spikes or no significant pixel
%     notes    lines worth saying (what was left out, the normalizer)
%   R.compare: a table, a row per pair of sets (a, b: labels; ia, ib):
%     si   similarity index (Eq. 11), the correlation of the two STRFs over
%          the pixels significant in either (NaN: other grids, no pixel)
%     rdi  rate disparity index (Eq. 12), percent: s((ra/rb)^s - 1) 100,
%          s = sign(ra - rb)
%     mdi  magnitude disparity index, as rdi with the energies (NaN for TORCs)
%   R.settings: rate, maxLag, skip, alpha, z, rtfPad, crhBins, crhLag,
%   snrSpikes. R.kind "rippleStrf".
%
%   Options: SetLabels (string, one per set), Rate, MaxLag, Skip, Alpha,
%   RtfPad, CrhBins, CrhLag, SnrSpikes, Envelope (@(rec, t) -> [S, x]),
%   Trajectory (@(rec, t) -> struct Omega, Fm), Check (called between
%   blocks: a checkpoint that may throw), MaxPoints (grid times per
%   envelope block, default 32768).
%   Errors: rippleStrf:NoStimgen, rippleStrf:MixedStimuli, rippleStrf:Grid,
%   rippleStrf:Skip, rippleStrf:MaxLag, rippleStrf:Overlap.
%
%   See also rippleStimuli, epochSpikes.

arguments
    spikes cell
    records cell
    index double
    sets double
    opts.SetLabels string = strings(1, 0)
    opts.Rate (1,1) double {mustBePositive, mustBeFinite} = 4000
    opts.MaxLag (1,1) double {mustBePositive, mustBeFinite} = 0.1
    opts.Skip (1,1) double = NaN
    opts.Alpha (1,1) double {mustBeGreaterThan(opts.Alpha, 0), mustBeLessThan(opts.Alpha, 1)} = 0.002
    opts.RtfPad (1,1) double {mustBeInteger, mustBePositive} = 1
    opts.CrhBins (1,2) double {mustBePositive, mustBeFinite} = [25 0.25]
    opts.CrhLag (1,1) double {mustBeNonnegative, mustBeFinite} = 0
    opts.SnrSpikes (1,1) double {mustBeInteger, mustBePositive} = 100
    opts.Envelope = []
    opts.Trajectory = []
    opts.Check = []
    opts.MaxPoints (1,1) double {mustBeInteger, mustBePositive} = 32768
end

spikes = cellfun(@(v) double(v(:)), spikes(:), 'UniformOutput', false);
index = double(index(:));
sets = double(sets(:));
nE = numel(spikes);
if numel(index) ~= nE || numel(sets) ~= nE
    error('rippleStrf:Size', 'SPIKES, INDEX and SETS hold one entry per epoch (%d, %d, %d).', nE, numel(index), numel(sets));
end
dt = 1 / opts.Rate;
nL = floor(opts.MaxLag * opts.Rate + 1e-9) + 1;
lags = (0:nL - 1) * dt;
z = sqrt(2) * erfcinv(opts.Alpha);
use = isfinite(index) & isfinite(sets);
setIds = unique(sets(use)).';
labels = opts.SetLabels;

S0 = struct('label', "", 'kind', "", 'nEpochs', 0, 'nStimuli', 0, 'nSpikes', 0, 'duration', 0, 'rate', NaN, ...
    'skip', [], 'lags', lags, 'x', [], 'freq', [], 'strf', [], 'strfRate', [], 'strfSig', [], 'units', "", ...
    'sigma2', NaN, 'amplitude', [], 'threshold', NaN, 'sig', [], 'rippleSets', 0, 'droppedSpikes', 0, ...
    'rtf', [], 'rtfFm', [], 'rtfOmega', [], 'best', [], 'crh', [], 'crhRate', [], 'crhOccupancy', [], ...
    'crhFmEdges', [], 'crhOmegaEdges', [], 'energy', NaN, 'pli', NaN, 'delta', NaN, 'snrMean', NaN, 'snrMax', NaN, ...
    'notes', strings(0, 1));
out = repmat(S0, 1, numel(setIds));
for q = 1:numel(setIds)
    s = setIds(q);
    lab = "set " + s;
    if s >= 1 && s <= numel(labels) && s == round(s); lab = labels(s); end
    es = find(use & sets == s);
    out(q) = oneSet(S0, lab, spikes(es), index(es), records, opts, dt, nL, lags, z);
end

R = struct();
R.kind = "rippleStrf";
R.sets = out;
R.compare = compareSets(out);
R.settings = struct('rate', opts.Rate, 'maxLag', opts.MaxLag, 'skip', opts.Skip, 'alpha', opts.Alpha, 'z', z, ...
    'rtfPad', opts.RtfPad, 'crhBins', opts.CrhBins, 'crhLag', opts.CrhLag, 'snrSpikes', opts.SnrSpikes);
end


% ======================================================================================================

function o = oneSet(o, label, spk, idx, records, opts, dt, nL, lags, z)
%oneSet  One set's STRF and everything read from it.
o.label = label;
o.nEpochs = numel(spk);
us = unique(idx).';
recs = records(us);
kinds = strings(1, numel(us));
for k = 1:numel(us); kinds(k) = kindOf(recs{k}); end
if numel(unique(kinds)) > 1
    error('rippleStrf:MixedStimuli', ['Set "%s" holds %s presentations: a STRF is estimated from one kind of stimulus. ' ...
        'Split the epochs (by trial group or by bank item) so each set holds one.'], label, strjoin(unique(kinds), " and "));
end
kind = kinds(1);
o.kind = kind;
o.nStimuli = numel(us);
x = double(recs{1}.OctaveAxis(:));
for k = 2:numel(recs)
    xk = double(recs{k}.OctaveAxis(:));
    if numel(xk) ~= numel(x) || any(abs(xk - x) > 1e-9) || abs(recs{k}.CarrierFrequencies(1) - recs{1}.CarrierFrequencies(1)) > 1e-6
        error('rippleStrf:Grid', 'Set "%s" holds stimuli on different carrier grids: their STRFs cannot be added.', label);
    end
end
o.x = x;
o.freq = double(recs{1}.CarrierFrequencies(1)) .* 2 .^ x;
[env, traj] = handles(opts, kind);

% each stimulus: its presentations' spikes on the grid, its time analyzed, its envelope's statistics
nU = numel(us);
U = repmat(struct('rec', [], 'D', 0, 'skip', 0, 'period', NaN, 'T', 0, 'bins', zeros(0, 1), 't', zeros(0, 1), ...
    'ms', NaN, 'mx', NaN, 'mn', NaN, 'n', 0, 'tq', [], 'wq', 0), 1, nU);
for k = 1:nU
    r = recs{k};
    D = double(r.N) / double(r.Fs);
    P = NaN;
    if kind == "TORC"; P = double(r.RipplePeriod); end
    sk = opts.Skip;
    if isnan(sk)
        if kind == "TORC"
            sk = 0;
            if double(r.NumPeriods) >= 2; sk = P; end
        else
            sk = opts.MaxLag;
        end
    end
    if kind ~= "TORC" && sk < opts.MaxLag - 1e-12
        error('rippleStrf:Skip', ['Skip (%g s) is shorter than the longest lag (%g s): at the lags beyond it a spike near ' ...
            'the onset would read the silence before the %s, which is not the stimulus. Skip at least %g s.'], ...
            sk, opts.MaxLag, kind, opts.MaxLag);
    end
    if kind == "TORC" && opts.MaxLag >= P - 1e-12
        error('rippleStrf:MaxLag', ['The longest lag (%g s) reaches the TORC''s ripple period (%g s): its envelope ' ...
            'is periodic, so a lag of a period reads lag 0 again. Use a shorter longest lag.'], opts.MaxLag, P);
    end
    if sk < 0 || sk >= D
        error('rippleStrf:Skip', 'Skip (%g s) leaves nothing of the %g s stimulus to analyze.', sk, D);
    end
    on = find(idx == us(k));
    t = vertcat(zeros(0, 1), spk{on});
    t = double(t(:));
    t = t(t >= sk & t < D);
    b = round(t * opts.Rate);
    ok = b * dt <= D;
    if kind ~= "TORC"; ok = ok & b >= nL - 1; end   % every lag inside the stimulus
    o.droppedSpikes = o.droppedSpikes + nnz(~ok);
    U(k).rec = r;
    U(k).D = D;
    U(k).skip = sk;
    U(k).period = P;
    U(k).T = numel(on) * (D - sk);
    U(k).bins = b(ok);
    U(k).t = t(ok);
    U(k).n = nnz(ok);
    % the envelope's mean square, extremes over the time analyzed (an even grid of at most 20000 times)
    nq = max(1, min(ceil((D - sk) * opts.Rate), 20000));
    tq = sk + (0:nq - 1) * ((D - sk) / nq);
    Sq = env(r, tq);
    U(k).ms = mean(Sq(:) .^ 2);
    U(k).mx = max(Sq(:));
    U(k).mn = min(Sq(:));
    U(k).tq = tq;
    U(k).wq = (D - sk) / nq * numel(on);   % s of stimulus each sample stands for, over every presentation
    tick(opts.Check);
end
o.skip = unique([U.skip]);
T = sum([U.T]);
N = sum([U.n]);
o.duration = T;
o.nSpikes = N;
o.rate = N / T;

% the weights: STRF = sum_u w_u C_u, C_u = sum over u's spikes of the envelope at their lags
w = zeros(1, nU);
if kind == "TORC"
    keys = cell(1, nU);
    for k = 1:nU
        keys{k} = sortrows([double(U(k).rec.RippleRates(:)) double(U(k).rec.RippleDensities(:))]);
    end
    grp = zeros(1, nU);
    reps = {};
    for k = 1:nU
        g = find(cellfun(@(c) isequal(c, keys{k}), reps), 1);
        if isempty(g); reps{end+1} = keys{k}; g = numel(reps); end %#ok<AGROW>
        grp(k) = g;
    end
    for g1 = 1:numel(reps)
        for g2 = g1 + 1:numel(reps)
            shared = intersect(reps{g1}, reps{g2}, 'rows');
            if ~isempty(shared)
                error('rippleStrf:Overlap', ['Set "%s" holds TORCs of different ripple sets that share %d component(s) ' ...
                    '(e.g. %g Hz, %g c/o): summed (Klein et al. Eq. 39), the shared ones would count twice.'], ...
                    label, size(shared, 1), shared(1, 1), shared(1, 2));
            end
        end
    end
    m = accumarray(grp(:), 1).';
    a = arrayfun(@(u) double(u.rec.RippleAmplitude), U);
    w = 1 ./ (m(grp) .* a .^ 2 .* [U.T]);
    o.amplitude = a;
    o.rippleSets = numel(reps);
    o.units = "spikes/s per dB";
    o.notes(end+1, 1) = sprintf("TORC: STRF = C / a^2 (Klein et al. 2000 Eq. 38-39): %d ripple set(s), %d TORC(s)", ...
        numel(reps), nU);
    if any(m > 1); o.notes(end+1, 1) = "TORCs of one ripple set (other phases) averaged (Eq. 33-34)"; end
    if any([U.skip] == 0 & arrayfun(@(u) double(u.rec.NumPeriods), U) < 2)
        o.notes(end+1, 1) = "One-period TORC, nothing skipped: lags before the onset read the periodic envelope, not the silence";
    end
else
    sigma2 = sum([U.T] .* [U.ms]) / T;
    w(:) = 1 / (sigma2 * T);
    o.sigma2 = sigma2;
    o.units = "spikes/s";
    o.notes(end+1, 1) = sprintf("%s: STRF = sum S / (sigma^2 T) (Escabi & Schreiner 2002 Eq. 10), sigma^2 = %.4g dB^2", ...
        kind, sigma2);
end
if o.droppedSpikes > 0
    o.notes(end+1, 1) = sprintf("%d spike(s) off the analysis grid left out", o.droppedSpikes);
end

% the SnrSpikes spikes chosen at random (a stream of its own: the global one is not touched)
pick = cell(1, nU);
for k = 1:nU; pick{k} = false(U(k).n, 1); end
if N >= opts.SnrSpikes
    rs = RandStream('mt19937ar', 'Seed', 0);
    chosen = sort(randperm(rs, N, opts.SnrSpikes));
    ends = cumsum([U.n]);
    starts = ends - [U.n] + 1;
    for k = 1:nU
        in = chosen(chosen >= starts(k) & chosen <= ends(k)) - starts(k) + 1;
        pick{k}(in) = true;
    end
end

% the sums of the envelope at every spike's lags, block by block of the grid
nX = numel(x);
C = zeros(nX, nL);
C100 = zeros(nX, nL);
for k = 1:nU
    [Ck, C100k] = lagSums(U(k), pick{k}, env, kind, nL, dt, opts);
    C = C + w(k) * Ck;
    C100 = C100 + w(k) * C100k;
end
o.strf = C;
sd = sqrt(sum(w .^ 2 .* [U.n] .* [U.ms]));
o.threshold = z * sd;
o.sig = abs(C) > o.threshold;
if kind == "TORC"
    scale = 1;
else
    scale = sqrt(o.sigma2);
end
o.strfRate = scale * C;
o.strfSig = o.strfRate .* o.sig;

% the statistics of Escabi & Schreiner (a DMR's or ripple noise's)
if kind ~= "TORC"
    sigma = sqrt(o.sigma2);
    o.delta = (max([U.mx]) - min([U.mn])) / sigma;
    o.energy = sqrt(sum(o.strfSig(:) .^ 2) * dt);
    if o.rate > 0
        o.pli = (max(o.strfSig(:)) - min(o.strfSig(:))) / o.rate / o.delta;
    end
end
if N >= opts.SnrSpikes
    pk = cellfun(@nnz, pick);
    sd100 = sqrt(sum(w .^ 2 .* pk .* [U.ms]));
    sig100 = abs(C100) > z * sd100;
    if any(sig100(:)) && sd100 > 0
        o.snrMean = sqrt(mean(C100(sig100) .^ 2)) / sd100;
        o.snrMax = max(abs(C100(sig100))) / sd100;
    end
else
    o.notes(end+1, 1) = sprintf("SNR: %d spike(s), fewer than %d", N, opts.SnrSpikes);
end

% the ripple transfer function of the significant STRF, and its peak
[o.rtf, o.rtfFm, o.rtfOmega] = rippleTransfer(o.strfSig, dt, x, opts.RtfPad);
o.best = bestRipple(o.rtf, o.rtfFm, o.rtfOmega);

% the conditioned response histogram (a DMR's)
if kind == "DMR"
    [o.crh, o.crhOccupancy, o.crhFmEdges, o.crhOmegaEdges] = crhOf(U, traj, opts);
    o.crhRate = o.crh ./ o.crhOccupancy;
    o.crhRate(o.crhOccupancy == 0) = NaN;
elseif kind == "RN"
    o.notes(end+1, 1) = "No CRH: ripple noise is a sum of several DMR envelopes (Eq. 15 is a DMR's)";
end
end


function [C, C100] = lagSums(u, pick, env, kind, nL, dt, opts)
%lagSums  C(:, j+1) = sum over u's spikes of the envelope j grid steps before each (and over the chosen spikes: C100).
x0 = u.rec.OctaveAxis;
nX = numel(x0);
C = zeros(nX, nL);
C100 = zeros(nX, nL);
if u.n == 0; return; end
[b, order] = sort(u.bins);
p = pick(order);
[ub, first] = unique(b);
cnt = diff([first; numel(b) + 1]);
c100 = accumarray(cumsum([1; diff(b) ~= 0]), double(p));
i0 = 1;
while i0 <= numel(ub)
    % a block: bins whose lag windows fit in MaxPoints grid times
    i1 = i0;
    while i1 < numel(ub) && ub(i1 + 1) - ub(i0) + nL <= opts.MaxPoints
        i1 = i1 + 1;
    end
    m0 = ub(i0) - nL + 1;
    m = m0:ub(i1);
    tm = m * dt;
    if kind == "TORC"
        tm = mod(tm, u.period);   % the envelope is periodic in the ripple period (Eq. 11)
    else
        tm = min(max(tm, 0), u.D);   % (inside by construction; only rounding is clipped)
    end
    Sb = env(u.rec, tm);
    bb = ub(i0:i1) - m0 + 1;
    cc = cnt(i0:i1);
    c1 = c100(i0:i1);
    has100 = any(c1);
    for j = 0:nL - 1
        cols = bb - j;
        Sj = Sb(:, cols);
        C(:, j + 1) = C(:, j + 1) + Sj * cc;
        if has100; C100(:, j + 1) = C100(:, j + 1) + Sj * c1; end
    end
    tick(opts.Check);
    i0 = i1 + 1;
end
end


function [H, fm, om] = rippleTransfer(A, dt, x, pad)
%rippleTransfer  |H(w, Omega)| of Klein et al. Eq. 14 on Omega >= 0: 1/(TX) sum STRF exp(-i 2 pi (w tau - Omega x)).
[nX, nL] = size(A);
H = [];
fm = [];
om = [];
if nX < 2 || nL < 2; return; end
dx = median(diff(x));
P = nL * pad;
Q = nX * pad;
F = fft2(A.', P, Q);   % F(p, q) = sum_j sum_k A(k, j) exp(-i 2 pi (p j / P + q k / Q))
p = -floor(P / 2):ceil(P / 2) - 1;
q = 0:floor(Q / 2);
% H(w_p, Omega_q) = F at (p, -q): exp(-i 2 pi (w tau - Omega x)) is the transform with the x frequency negated
H = abs(F(mod(p, P) + 1, mod(-q, Q) + 1)).' / (nL * nX);   % nOmega x nFm
fm = p / (P * dt);
om = (q / (Q * dx)).';
end


function b = bestRipple(H, fm, om)
%bestRipple  The peak of |H| (bTM, bRD), the peak of each half of the Fm axis, and whether the other half is a second best.
b = struct('fm', NaN, 'omega', NaN, 'magnitude', NaN, 'fmPos', NaN, 'omegaPos', NaN, 'magPos', NaN, ...
    'fmNeg', NaN, 'omegaNeg', NaN, 'magNeg', NaN, 'secondary', false);
if isempty(H) || ~any(H(:) > 0); return; end
[b.magnitude, i] = max(H(:));
[r, c] = ind2sub(size(H), i);
b.fm = fm(c);
b.omega = om(r);
[b.magPos, b.fmPos, b.omegaPos] = peakOf(H, fm, om, fm >= 0);
[b.magNeg, b.fmNeg, b.omegaNeg] = peakOf(H, fm, om, fm <= 0);
if b.fm >= 0
    other = [b.magNeg b.fmNeg b.omegaNeg];
else
    other = [b.magPos b.fmPos b.omegaPos];
end
b.secondary = other(1) >= 0.5 * b.magnitude && ~(other(2) == b.fm && other(3) == b.omega) && other(2) ~= 0;
end


function [mag, f, o] = peakOf(H, fm, om, cols)
Hc = H(:, cols);
fc = fm(cols);
[mag, i] = max(Hc(:));
[r, c] = ind2sub(size(Hc), i);
f = fc(c);
o = om(r);
end


function [counts, occ, fmEdges, omEdges] = crhOf(U, traj, opts)
%crhOf  Spikes counted at the Fm and Omega their stimulus had CrhLag s before them; the time the stimulus spent in each bin.
lo = [Inf Inf];
hi = [-Inf -Inf];
for k = 1:numel(U)
    r = U(k).rec;
    lo = min(lo, [r.ModulationRateRange(1) r.RippleDensityRange(1)]);
    hi = max(hi, [r.ModulationRateRange(2) r.RippleDensityRange(2)]);
end
fmEdges = edgesOf(lo(1), hi(1), opts.CrhBins(1));
omEdges = edgesOf(lo(2), hi(2), opts.CrhBins(2));
counts = zeros(numel(omEdges) - 1, numel(fmEdges) - 1);
occ = counts;
lag = opts.CrhLag;
for k = 1:numel(U)
    t = U(k).t - lag;
    t = t(t >= 0 & t <= U(k).D);
    if ~isempty(t)
        tr = traj(U(k).rec, t);
        counts = counts + histcounts2(tr.Omega(1, :), tr.Fm(1, :), omEdges, fmEdges);
    end
    tq = U(k).tq - lag;
    tq = tq(tq >= 0 & tq <= U(k).D);
    if ~isempty(tq)
        tr = traj(U(k).rec, tq);
        occ = occ + U(k).wq * histcounts2(tr.Omega(1, :), tr.Fm(1, :), omEdges, fmEdges);
    end
    tick(opts.Check);
end
end


function e = edgesOf(lo, hi, step)
e = lo:step:hi;
if isempty(e); e = lo; end
if e(end) < hi - 1e-9 * max(1, abs(hi)); e(end + 1) = e(end) + step; end
if numel(e) < 2; e = [lo lo + step]; end
end


function T = compareSets(o)
%compareSets  Similarity, rate and magnitude disparity indices of every pair of sets (Escabi & Schreiner Eq. 11-13).
n = numel(o);
a = strings(0, 1); b = strings(0, 1); ia = zeros(0, 1); ib = zeros(0, 1); si = zeros(0, 1); rdi = zeros(0, 1); mdi = zeros(0, 1);
for i = 1:n
    for j = i + 1:n
        a(end+1, 1) = o(i).label; %#ok<AGROW>
        b(end+1, 1) = o(j).label; %#ok<AGROW>
        ia(end+1, 1) = i; %#ok<AGROW>
        ib(end+1, 1) = j; %#ok<AGROW>
        s = NaN;
        if isequal(size(o(i).strf), size(o(j).strf)) && isequal(numel(o(i).x), numel(o(j).x)) && all(abs(o(i).x - o(j).x) < 1e-9)
            mask = o(i).sig | o(j).sig;
            u = o(i).strfRate(mask);
            v = o(j).strfRate(mask);
            if ~isempty(u) && norm(u) > 0 && norm(v) > 0
                s = (u.' * v) / (norm(u) * norm(v));
            end
        end
        si(end+1, 1) = s; %#ok<AGROW>
        rdi(end+1, 1) = disparity(o(i).rate, o(j).rate); %#ok<AGROW>
        mdi(end+1, 1) = disparity(o(i).energy, o(j).energy); %#ok<AGROW>
    end
end
T = table(a, b, ia, ib, si, rdi, mdi);
end


function d = disparity(ra, rb)
%disparity  s((ra/rb)^s - 1) 100, s = sign(ra - rb): Escabi & Schreiner Eq. 12 (0 when equal).
d = NaN;
if ~(isfinite(ra) && isfinite(rb)); return; end
s = sign(ra - rb);
if s == 0; d = 0; return; end
d = s * ((ra / rb) ^ s - 1) * 100;
end


function k = kindOf(rec)
k = "TORC";
if string(rec.Class) == "stimgen.DMR"
    k = "DMR";
    if string(rec.EnvelopeMode) == "RippleNoise"; k = "RN"; end
end
end


function [env, traj] = handles(opts, kind)
%handles  The envelope (and a DMR's trajectory) of a record at chosen times: the caller's, else stimgen's.
env = opts.Envelope;
traj = opts.Trajectory;
if isempty(env)
    cls = "stimgen.TORC";
    if kind ~= "TORC"; cls = "stimgen.DMR"; end
    if exist(cls, 'class') ~= 8
        error('rippleStrf:NoStimgen', 'The envelope of a %s is rebuilt by %s, which is not on the MATLAB path (add stimgen''s root).', kind, cls);
    end
    if kind == "TORC"
        env = @(r, t) stimgen.TORC.envelope_from_record(r, t);
    else
        env = @(r, t) stimgen.DMR.envelope_from_record(r, t);
    end
end
if isempty(traj) && kind == "DMR"
    traj = @(r, t) stimgen.DMR.trajectory_from_record(r, t);
end
end


function tick(chk)
if ~isempty(chk); chk(); end
end
