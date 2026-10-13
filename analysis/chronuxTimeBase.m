function TB = chronuxTimeBase(mode, opts)
%chronuxTimeBase  The trials a Chronux analysis averages over: epochs around events, or segments of a stretch.
%   Chronux averages over trials of one length. TB says where each trial
%   starts on the continuous clock (row k of a signal at (k-1)/Fs, the
%   clock of spike times too), its window, and which group it belongs to.
%   Pure: no I/O.
%
%   TB = chronuxTimeBase("aligned", E=E, Groups=G, Window=[pre post])
%   takes the epochs of an epochTable E (and its groups table G): trial e
%   covers [pre post] s around E.t0Continuous(e), the event on the
%   continuous clock. epochTable has already left out the epochs that
%   leave the recording or touch an artifact period (for this window: pass
%   it the same one). UseGroups=false puts every epoch in one group.
%
%   TB = chronuxTimeBase("range", Range=[from to], Artifacts=IV,
%   Duration=D, Segment=SEG) cuts the stretch [from to) s (to Inf = the
%   end, D s) into back-to-back segments SEG s long, each a trial, inside
%   the stretches clear of the artifact periods IV ([k x 2] [tStart tEnd)
%   s): a segment never touches one. What is left at the end of a clear
%   stretch, too short for a segment, is left out (secondsShort). With
%   Fs=FS (a signal's rate) and NRows the segments are cut on its rows:
%   the rows the periods touch are EphysDataset.intervalRows', a segment
%   is round(SEG*FS) rows, and TB.window [0 (rows-1)/FS], so a trial is
%   exactly that many samples; without Fs (spike trains) on the clock
%   itself, TB.window [0 SEG].
%
%   TB fields: mode, starts [n x 1] s (each trial's time 0 on the
%   continuous clock: the event, or the segment's first sample), window
%   [a b] s from it, span [t0 t1] s (what has to be read: from the first
%   trial's start to the last one's end; range: the clear stretches), groupIndex [n x 1], groups
%   (index, label, color, n: trials per group), nTrials, runs [k x 2] s
%   (range: the clear stretches, [start end)), runRows [k x 2] (range
%   with Fs: their rows), secondsUsed, secondsArtifact, secondsShort,
%   nDroppedEdge, nDroppedArtifact (aligned: epochTable's counts), label
%   (what was asked: Label=, else the range), text (a sentence saying it).
%
%   Errors: chronuxTimeBase:NoTrials (no trial fits), chronuxTimeBase:BadValue.
%
%   See also epochTable, chronuxSettings, chronuxSpectrum.

arguments
    mode (1,1) string {mustBeMember(mode, ["aligned" "range"])}
    opts.E = []
    opts.Groups = []
    opts.Window double = []
    opts.UseGroups (1,1) logical = true
    opts.Label (1,1) string = ""
    opts.Range double = [0 Inf]
    opts.Artifacts double = zeros(0, 2)
    opts.Duration (1,1) double = NaN
    opts.Fs (1,1) double = NaN
    opts.NRows (1,1) double = NaN
    opts.Segment (1,1) double = NaN
end

TB = struct('mode', mode, 'starts', zeros(0, 1), 'window', [0 0], 'span', [0 0], 'groupIndex', zeros(0, 1), ...
    'groups', table(), 'nTrials', 0, 'runs', zeros(0, 2), 'runRows', zeros(0, 2), 'secondsUsed', 0, ...
    'secondsArtifact', 0, 'secondsShort', 0, 'nDroppedEdge', 0, 'nDroppedArtifact', 0, 'label', opts.Label, 'text', "");
if mode == "aligned"
    TB = aligned(TB, opts);
else
    TB = ranged(TB, opts);
end
end


function TB = aligned(TB, opts)
E = opts.E;
w = reshape(double(opts.Window), 1, []);
if ~istable(E) || ~all(ismember(["t0Continuous" "groupIndex"], string(E.Properties.VariableNames)))
    error('chronuxTimeBase:BadValue', 'E must be an epochTable.');
end
if numel(w) ~= 2 || ~(w(2) > w(1))
    error('chronuxTimeBase:BadValue', 'Window must be [pre post] s with post > pre.');
end
if height(E) == 0
    error('chronuxTimeBase:NoTrials', 'No epoch is left to analyze.');
end
TB.starts = double(E.t0Continuous(:));
TB.window = w;
if opts.UseGroups && istable(opts.Groups) && height(opts.Groups) > 0
    G = opts.Groups;
    gi = double(E.groupIndex(:));
else
    G = oneGroup("all epochs");
    gi = ones(height(E), 1);
end
G.n = accumarray(gi, 1, [height(G) 1]);
TB.groupIndex = gi;
TB.groups = G(:, ["index" "label" "color" "n"]);
TB.nTrials = numel(TB.starts);
TB.span = [min(TB.starts) + w(1), max(TB.starts) + w(2)];
TB.secondsUsed = TB.nTrials * diff(w);
U = E.Properties.UserData;
if isstruct(U)
    if isfield(U, 'nDroppedEdge'); TB.nDroppedEdge = U.nDroppedEdge; end
    if isfield(U, 'nDroppedArtifact'); TB.nDroppedArtifact = U.nDroppedArtifact; end
end
what = TB.label;
if what == ""; what = "the event"; end
TB.text = sprintf("%d epochs of [%g %g] s around %s", TB.nTrials, w(1), w(2), what);
drops = strings(1, 0);
if TB.nDroppedEdge > 0; drops(end+1) = sprintf("%d at the recording's edges", TB.nDroppedEdge); end
if TB.nDroppedArtifact > 0; drops(end+1) = sprintf("%d touching artifact periods", TB.nDroppedArtifact); end
if ~isempty(drops); TB.text = TB.text + "; left out: " + strjoin(drops, ", "); end
end


function TB = ranged(TB, opts)
seg = opts.Segment;
if ~(isfinite(seg) && seg > 0)
    error('chronuxTimeBase:BadValue', 'Segment must be a positive number of seconds.');
end
r = reshape(double(opts.Range), 1, []);
dur = opts.Duration;
fs = opts.Fs;
if isfinite(fs)
    if ~(fs > 0 && isfinite(opts.NRows) && opts.NRows >= 1)
        error('chronuxTimeBase:BadValue', 'With Fs, NRows (the signal''s rows) is needed.');
    end
    dur = opts.NRows / fs;
end
if ~(isfinite(dur) && dur > 0)
    error('chronuxTimeBase:BadValue', 'The recording''s duration is unknown.');
end
if numel(r) ~= 2 || r(1) < 0 || ~(r(2) > r(1))
    error('chronuxTimeBase:BadValue', 'Range must be [from to] s with 0 <= from < to.');
end
a = r(1);
b = min(r(2), dur);
if ~(b > a)
    error('chronuxTimeBase:NoTrials', 'The range starts at %g s, after the recording''s end (%g s).', a, dur);
end
iv = EphysDataset.mergeIntervals(reshape(double(opts.Artifacts), [], 2));
if TB.label == ""; TB.label = sprintf("%s-%s s", num(a), num(b)); end

if isfinite(fs)
    r0 = ceil(a * fs - 1e-9) + 1;             % the first row at or after a
    r1 = min(opts.NRows, ceil(b * fs - 1e-9));   % the last row before b
    bad = EphysDataset.intervalRows(iv, fs, opts.NRows);
    runs = complementRuns(r0, r1, bad);
    n = round(seg * fs);
    if n < 2
        error('chronuxTimeBase:BadValue', 'A %g s segment is under two samples at %g Hz.', seg, fs);
    end
    len = runs(:, 2) - runs(:, 1) + 1;
    k = floor(len / n);
    starts = zeros(sum(k), 1);
    j = 0;
    for i = 1:size(runs, 1)
        starts(j + (1:k(i))) = runs(i, 1) + (0:k(i) - 1).' * n;
        j = j + k(i);
    end
    TB.runRows = runs;
    TB.runs = [(runs(:, 1) - 1) / fs, runs(:, 2) / fs];
    TB.starts = (starts - 1) / fs;
    TB.window = [0 (n - 1) / fs];
    total = (r1 - r0 + 1) / fs;
    clean = sum(len) / fs;
    TB.secondsUsed = sum(k) * n / fs;
    longest = max([len; 0]) / fs;
else
    runs = complementSpans(a, b, iv);
    len = runs(:, 2) - runs(:, 1);
    k = floor(len / seg + 1e-9);
    starts = zeros(sum(k), 1);
    j = 0;
    for i = 1:size(runs, 1)
        starts(j + (1:k(i))) = runs(i, 1) + (0:k(i) - 1).' * seg;
        j = j + k(i);
    end
    TB.runs = runs;
    TB.starts = starts;
    TB.window = [0 seg];
    total = b - a;
    clean = sum(len);
    TB.secondsUsed = sum(k) * seg;
    longest = max([len; 0]);
end
TB.secondsArtifact = max(0, total - clean);
TB.secondsShort = max(0, clean - TB.secondsUsed);
TB.nTrials = numel(TB.starts);
if TB.nTrials == 0
    error('chronuxTimeBase:NoTrials', ['No %g s segment fits in %s clear of artifact periods (the longest clear ' ...
        'stretch is %.3g s): use shorter segments.'], seg, TB.label, longest);
end
TB.groupIndex = ones(TB.nTrials, 1);
TB.groups = oneGroup(TB.label);
TB.groups.n = TB.nTrials;
TB.span = [TB.runs(1, 1), TB.runs(end, 2)];   % every clear stretch: a spectrogram reads them whole
TB.text = sprintf("%d segments of %g s from %s", TB.nTrials, seg, TB.label);
left = strings(1, 0);
if TB.secondsArtifact > 0; left(end+1) = sprintf("%.3g s of artifact periods", TB.secondsArtifact); end
if TB.secondsShort > 0; left(end+1) = sprintf("%.3g s too short for a segment", TB.secondsShort); end
if ~isempty(left); TB.text = TB.text + "; left out: " + strjoin(left, ", "); end
end


function G = oneGroup(label)
G = table(1, string(label), [0.15 0.15 0.15], 0, 'VariableNames', {'index', 'label', 'color', 'n'});
end


function runs = complementRuns(r0, r1, bad)
%complementRuns  The rows r0..r1 outside the [first last] row runs BAD (merged, sorted), as runs.
runs = zeros(0, 2);
cur = r0;
for i = 1:size(bad, 1)
    if bad(i, 2) < cur; continue; end
    if bad(i, 1) > r1; break; end
    if bad(i, 1) > cur; runs(end+1, :) = [cur, bad(i, 1) - 1]; end %#ok<AGROW>
    cur = bad(i, 2) + 1;
end
if cur <= r1; runs(end+1, :) = [cur, r1]; end
end


function runs = complementSpans(a, b, iv)
%complementSpans  [a b) outside the half-open periods IV (merged, sorted), as [start end) spans.
runs = zeros(0, 2);
cur = a;
for i = 1:size(iv, 1)
    if iv(i, 2) <= cur; continue; end
    if iv(i, 1) >= b; break; end
    if iv(i, 1) > cur; runs(end+1, :) = [cur, iv(i, 1)]; end %#ok<AGROW>
    cur = iv(i, 2);
end
if cur < b; runs(end+1, :) = [cur, b]; end
end


function s = num(x)
s = string(sprintf('%.6g', x));
end
