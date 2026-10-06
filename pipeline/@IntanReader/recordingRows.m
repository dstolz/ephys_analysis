function X = recordingRows(obj, a, b)
%recordingRows  Rows A..B of a traditional recording, in microvolts.
%   X = recordingRows(obj, A, B) returns [B-A+1 x nChan] double microvolts,
%   every amplifier channel in header order, for the 1-based rows A..B of
%   the whole recording (every file, in order; B no more than it holds).
%   Only the data blocks holding those rows are read (rhdRows).
%
%   Files saved before version 3.0 with the software notch on are filtered
%   as READ_INTAN_RHD2000_FILE_MODIFIED filters one file (notchFilter), but
%   as one stream over each run of consecutive files with the same notch:
%   the filter starts at the run's first row, as Intan's loop starts, and
%   goes on across the files without a step. A read further in starts it
%   notchLeadIn rows (1.76 s) before its first row instead of at the run's
%   start: the filter has forgotten its start by then, so the rows equal
%   those of the run filtered in one go, to rounding, and no read costs
%   more than its rows and that lead-in, wherever it falls.
%
%   See also IntanReader.readWindowUV, IntanReader.readChunkUV,
%   IntanReader.notchFilter, IntanReader.notchLeadIn.

if b < a
    X = zeros(0, obj.NumChannels);
    return
end
[hz, first, runFirst] = obj.fileNotch();
counts = [obj.PerFile.numAmplifierSamples];
in = find(counts > 0 & first + counts - 1 >= a & first <= b);   % the files holding the rows
runs = unique(runFirst(in));
if ~isscalar(runs)
    X = zeros(b - a + 1, obj.NumChannels);
end
for r = runs
    k = in(runFirst(in) == r);
    lo = max(a, first(k(1)));
    hi = min(b, first(k(end)) + counts(k(end)) - 1);
    if hz(k(1)) == 0
        R = obj.rawRows(lo, hi);
    else
        s = max(r, lo - IntanReader.notchLeadIn(obj.Fs));
        R = IntanReader.notchFilter(obj.rawRows(s, hi), obj.Fs, hz(k(1)));
        R = R(lo - s + 1 : end, :);
    end
    if isscalar(runs)
        X = R;
    else
        X(lo - a + 1 : hi - a + 1, :) = R;
    end
end
end
