function base = artifactBaseline(obj, plan, chanOrder, filt, det, Fs, ctx)
%artifactBaseline  The recording's own baselines for the artifact detection scores.
%   BASE = artifactBaseline(DS, PLAN, CHANORDER, FILT, DET, FS, CTX) returns
%   struct(center, sigma), each [1 x nChan] (after CHANORDER): the median and
%   the robust SD (1.4826 x MAD) of the statistic DET.method scores against
%   -- the running RMS for "rms", the signal for "mad" -- read the way the
%   detection reads it (common reference, CHANORDER, FILT). BASE is [] for the
%   methods with no baseline ("microvolts", "commonmode"), when the chunks of
%   PLAN do not say where they lie in the recording, or when the reader has no
%   random access (every chunk then takes its own).
%
%   The samples are fixed by the recording alone, not by how it is cut into
%   chunks: the whole of it when it is short (PLAN's chunks that touch are
%   read as one), else 32 pieces spread evenly along it, 2^14 rows each. So
%   the baselines, and the detection scored against them, are the same
%   whatever MaxChunkSamples is, and a stretch of stimulation that fills a
%   chunk cannot set the baseline of the chunk it fills: the pieces are
%   spread over the recording and the median / MAD are robust to a minority
%   of them. Each piece is read with CTX rows of context on either side, which
%   the filter and the running RMS use and the baseline does not.
%
%   See also artifactChunk, artifactScore, EphysDataset.detectArtifacts.

BUDGET = 2^19;        % rows read at most; the whole recording below this
NPIECES = 32;

base = [];
if ~any(det.method == ["rms" "mad"]) || isempty(plan) || ~obj.supportsRandomAccess()
    return
end
off = [plan.sampleOffset];
len = [plan.nSamples];
if any(~isfinite(off)) || any(~isfinite(len)) || any(len <= 0)
    return
end
[off, o] = sort(off(:));
len = len(o);
len = len(:);
[off, len] = touchingRanges(off, len);
total = sum(len);
if total <= BUDGET
    pieces = [off, len];
else
    L = floor(BUDGET / NPIECES);
    start = round(linspace(0, total - L, NPIECES)).';      % along the ranges laid end to end
    pieces = zeros(0, 2);
    edges = [0; cumsum(len)];
    for s = start.'
        for k = 1:numel(len)
            a = max(s, edges(k));
            b = min(s + L, edges(k+1));
            if b > a
                pieces(end+1, :) = [off(k) + (a - edges(k)), b - a]; %#ok<AGROW>
            end
        end
    end
end

reference = true;     % "rms" and "mad" read the referenced signal
w = 1;
if det.method == "rms"
    [~, wms] = artifactScore(zeros(1, 1), "rms", Fs, det.rmsWindowMs);
    w = max(1, round(wms * 1e-3 * Fs));
end
V = [];
for k = 1:size(pieces, 1)
    a = pieces(k, 1);
    n = pieces(k, 2);
    a0 = max(0, a - ctx);
    X = obj.readWindowUV(a0, n + (a - a0) + ctx, Reference=reference);
    if ~isempty(chanOrder)
        X = X(:, chanOrder);
    end
    if filt.use
        X = obj.filterContinuous(X, Type=filt.type, Cutoff=filt.cutoff, ...
            Order=filt.order, Fs=Fs);
    end
    stride = 1;      % artifactScore's rule: the running RMS averages w samples, so every 8th is enough
    if det.method == "rms" && w >= 8 && size(X, 1) >= 2^17
        stride = 8;
    end
    rows = (a - a0) + (1:stride:n);
    rows = rows(rows <= size(X, 1));
    if det.method == "rms"
        X = artifactScore(X, "rms", Fs, det.rmsWindowMs, struct('center', 0, 'sigma', 1));   % the running RMS
    end
    V = [V; single(X(rows, :))]; %#ok<AGROW>
end
if isempty(V)
    base = [];
    return
end
center = median(V, 1, 'omitnan');
sigma = median(abs(V - center), 1, 'omitnan') * 1.4826;
base = struct('center', double(center), 'sigma', double(sigma));
end


function [off, len] = touchingRanges(off, len)
%touchingRanges  Sorted ranges [off, off + len) with the ones that touch joined.
first = [true; off(2:end) ~= off(1:end-1) + len(1:end-1)];
last = [first(2:end); true];
ends = off + len;
off = off(first);
len = ends(last) - off;
end
