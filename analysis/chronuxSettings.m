function S = chronuxSettings(s)
%chronuxSettings  Complete, checked settings of a Chronux analysis (the analysis app's Chronux tab).
%   S = chronuxSettings() returns the defaults; S = chronuxSettings(S0)
%   overlays the struct S0 on them (S0.display on S.display) and checks
%   the result. What is analyzed:
%     analysis      "spectrum" (mtspectrumc) | "specgram" (mtspecgramc) |
%                   "coherence" (coherencyc; cohgramc when overTime) |
%                   "spikeSpectrum" (mtspectrumpt) | "spikeField"
%                   (coherencycpt) | "unitCoherence" (coherencypt)
%     signal        the continuous signal: "LFP" (default) | "MUA" |
%                   "SPIKE" | "AUX"
%     channels      columns of the signal ([] = all)
%     pairMode      coherence: "seed" (seed against every other channel
%                   or unit picked) | "pair" (seed against partner)
%     seed, partner coherence: channels (columns of the signal)
%     overTime      coherence: over time (cohgramc) instead of one
%                   spectrum of coherence
%     spikeSource   spike analyses: "units" (sorted units) | "detected"
%     units         spike analyses: indices into the file's spike trains
%                   ([] = all)
%     unitSeed, unitPartner   unit-unit coherence: indices of the pair
%     fieldChannel  spike-field coherence: the signal's column
%   Over which time:
%     timeBase      "aligned" (epochs around the Alignment tab's event) |
%                   "range" (a stretch of the recording)
%     window        aligned: [pre post] s around the event (a fixed window:
%                   Chronux takes trials of one length)
%     useGroups     aligned: one result per trial group (else all epochs
%                   as one)
%     range         range: [from to] s on the continuous clock (to Inf =
%                   the end)
%     segmentSec    range: the artifact-free stretches are cut into
%                   back-to-back segments this long, taken as trials
%   Chronux params:
%     taperMode     "TWK": tapers [TW K] as given | "Wp": the half
%                   bandwidth W (Hz) and p, over the trial's (or moving
%                   window's) length T: [W*T, floor(2*W*T)-p]
%                   (ChronuxDataset.tapersFor)
%     TW, K, W, p   the tapers
%     pad           FFT padding (-1, 0, 1, ...)
%     fpass         [fmin fmax] Hz (fmax Inf = Nyquist)
%     err           "none" | "theoretical" | "jackknife" error bars
%     errP          their p (0.05: 95%)
%     fscorr        spike analyses: the finite-size correction
%     spikeFs       spike analyses: the rate of the time grid (Hz)
%     movingwin     spectrogram, coherence over time: [window step] s
%     detrend       each trial's "none" | "constant" (default: its mean
%                   removed) | "linear" trend removed before the spectra
%     baseline      aligned spectrogram: "none" | "db" | "percent" |
%                   "zscore" | "ratio" against baselineWindow
%     baselineWindow  [b0 b1] s from the event
%   How it is drawn (display): scale ("db" | "log" | "linear"), layout
%   ("grid": a tile per channel, groups overlaid; "overlay": a tile per
%   group, channels overlaid), showErr, showPhase, maxTiles, ylim, clim
%   ([] = automatic), page.
%
%   Errors: chronuxSettings:BadValue, chronuxSettings:UnknownField.
%
%   See also chronuxTimeBase, chronuxSpectrum, chronuxSpecgram, renderChronux.

if nargin < 1 || isempty(s); s = struct(); end
if ~isstruct(s) || ~isscalar(s)
    error('chronuxSettings:BadValue', 'Pass a struct of settings.');
end
S = defaults();
for f = string(fieldnames(s)).'
    if ~isfield(S, f)
        error('chronuxSettings:UnknownField', 'Unknown Chronux setting "%s".', f);
    end
    if f == "display"
        for g = string(fieldnames(s.display)).'
            if ~isfield(S.display, g)
                error('chronuxSettings:UnknownField', 'Unknown Chronux display setting "%s".', g);
            end
            S.display.(g) = s.display.(g);
        end
    else
        S.(f) = s.(f);
    end
end
S = check(S);
end


function S = defaults()
S = struct( ...
    'analysis',     "spectrum", ...
    'signal',       "LFP", ...
    'channels',     zeros(1, 0), ...
    'pairMode',     "seed", ...
    'seed',         1, ...
    'partner',      2, ...
    'overTime',     false, ...
    'spikeSource',  "units", ...
    'units',        zeros(1, 0), ...
    'unitSeed',     1, ...
    'unitPartner',  2, ...
    'fieldChannel', 1, ...
    'timeBase',     "aligned", ...
    'window',       [-0.5 1], ...
    'useGroups',    true, ...
    'range',        [0 Inf], ...
    'segmentSec',   2, ...
    'taperMode',    "TWK", ...
    'TW',           3, ...
    'K',            5, ...
    'W',            4, ...
    'p',            1, ...
    'pad',          0, ...
    'fpass',        [0 100], ...
    'err',          "jackknife", ...
    'errP',         0.05, ...
    'fscorr',       false, ...
    'spikeFs',      1000, ...
    'movingwin',    [0.5 0.05], ...
    'detrend',      "constant", ...
    'baseline',     "none", ...
    'baselineWindow', [-0.5 0], ...
    'display',      struct('scale', "db", 'layout', "grid", 'showErr', true, 'showPhase', true, ...
                        'maxTiles', 16, 'ylim', zeros(1, 0), 'clim', zeros(1, 0), 'page', 1));
end


function S = check(S)
S.analysis = member(S.analysis, "analysis", ["spectrum" "specgram" "coherence" "spikeSpectrum" "spikeField" "unitCoherence"]);
S.signal = member(S.signal, "signal", ["LFP" "MUA" "SPIKE" "AUX"]);
S.channels = whole(S.channels, "channels");
S.pairMode = member(S.pairMode, "pairMode", ["seed" "pair"]);
S.seed = whole(S.seed, "seed", true);
S.partner = whole(S.partner, "partner", true);
S.overTime = logical(S.overTime);
S.spikeSource = member(S.spikeSource, "spikeSource", ["units" "detected"]);
S.units = whole(S.units, "units");
S.unitSeed = whole(S.unitSeed, "unitSeed", true);
S.unitPartner = whole(S.unitPartner, "unitPartner", true);
S.fieldChannel = whole(S.fieldChannel, "fieldChannel", true);
S.timeBase = member(S.timeBase, "timeBase", ["aligned" "range"]);
S.window = span(S.window, "window");
if diff(S.window) <= 0
    error('chronuxSettings:BadValue', 'The window [pre post] needs post > pre (got [%g %g]).', S.window(1), S.window(2));
end
S.useGroups = logical(S.useGroups);
S.range = reshape(double(S.range), 1, []);
if numel(S.range) ~= 2 || any(isnan(S.range)) || S.range(1) < 0 || S.range(2) <= S.range(1)
    error('chronuxSettings:BadValue', 'range must be [from to] s with 0 <= from < to (to may be Inf).');
end
S.segmentSec = positive(S.segmentSec, "segmentSec");
S.taperMode = member(S.taperMode, "taperMode", ["TWK" "Wp"]);
S.TW = positive(S.TW, "TW");
S.K = whole(S.K, "K", true);
S.W = positive(S.W, "W");
S.p = whole(S.p, "p", true, 0);
S.pad = whole(S.pad, "pad", true, -1);
S.fpass = reshape(double(S.fpass), 1, []);
if numel(S.fpass) ~= 2 || isnan(S.fpass(1)) || S.fpass(1) < 0 || ~(S.fpass(2) > S.fpass(1))
    error('chronuxSettings:BadValue', 'fpass must be [fmin fmax] Hz with 0 <= fmin < fmax (fmax may be Inf).');
end
S.err = member(S.err, "err", ["none" "theoretical" "jackknife"]);
S.errP = double(S.errP);
if ~isscalar(S.errP) || ~(S.errP > 0 && S.errP < 1)
    error('chronuxSettings:BadValue', 'errP must be between 0 and 1.');
end
S.fscorr = logical(S.fscorr);
S.spikeFs = positive(S.spikeFs, "spikeFs");
S.movingwin = reshape(double(S.movingwin), 1, []);
if numel(S.movingwin) ~= 2 || any(~(S.movingwin > 0)) || any(~isfinite(S.movingwin))
    error('chronuxSettings:BadValue', 'movingwin must be [window step] s, both positive.');
end
S.detrend = member(S.detrend, "detrend", ["none" "constant" "linear"]);
S.baseline = member(S.baseline, "baseline", ["none" "db" "percent" "zscore" "ratio"]);
S.baselineWindow = span(S.baselineWindow, "baselineWindow");
if S.baseline ~= "none" && S.analysis == "specgram" && S.timeBase == "aligned"
    if diff(S.baselineWindow) <= 0
        error('chronuxSettings:BadValue', 'The baseline window needs its end after its start.');
    end
    if S.baselineWindow(1) < S.window(1) - 1e-9 || S.baselineWindow(2) > S.window(2) + 1e-9
        error('chronuxSettings:Baseline', 'The baseline window [%g %g] s must lie inside the window [%g %g] s.', ...
            S.baselineWindow(1), S.baselineWindow(2), S.window(1), S.window(2));
    end
end
d = S.display;
d.scale = member(d.scale, "display.scale", ["db" "log" "linear"]);
d.layout = member(d.layout, "display.layout", ["grid" "overlay"]);
d.showErr = logical(d.showErr);
d.showPhase = logical(d.showPhase);
d.maxTiles = whole(d.maxTiles, "display.maxTiles", true);
d.ylim = limits(d.ylim, "display.ylim");
d.clim = limits(d.clim, "display.clim");
d.page = whole(d.page, "display.page", true);
S.display = d;
end


function v = member(v, name, allowed)
v = string(v);
if ~isscalar(v) || ~ismember(v, allowed)
    error('chronuxSettings:BadValue', '%s must be one of %s.', name, strjoin(allowed, ", "));
end
end


function v = whole(v, name, scalar, low)
if nargin < 3; scalar = false; end
if nargin < 4; low = 1; end
v = reshape(double(v), 1, []);
if (scalar && ~isscalar(v)) || any(v ~= round(v)) || any(v < low)
    error('chronuxSettings:BadValue', '%s must be %s whole number(s) of at least %d.', name, ...
        ternary(scalar, "a", "any"), low);
end
end


function v = positive(v, name)
v = double(v);
if ~isscalar(v) || ~(v > 0) || ~isfinite(v)
    error('chronuxSettings:BadValue', '%s must be a positive number.', name);
end
end


function v = span(v, name)
v = reshape(double(v), 1, []);
if numel(v) ~= 2 || any(~isfinite(v))
    error('chronuxSettings:BadValue', '%s must be two finite numbers, s.', name);
end
end


function v = limits(v, name)
v = reshape(double(v), 1, []);
if isempty(v); v = zeros(1, 0); return; end
if numel(v) ~= 2 || any(~isfinite(v)) || v(2) <= v(1)
    error('chronuxSettings:BadValue', '%s must be [low high] (or empty: automatic).', name);
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
