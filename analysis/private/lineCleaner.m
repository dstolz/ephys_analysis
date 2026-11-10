function fix = lineCleaner(src, r)
%lineCleaner  A function that stitches and drops a line's intervals as an event reference asks.
%   FIX = lineCleaner(SRC, R) takes the dataset SRC (loadAnalysisSource)
%   and an event reference or sequence step R (fields line, stitchGapSec,
%   refractorySec; a missing one is 0) and returns FIX, with
%   IV = FIX(IV) the cleaned intervals (cleanIntervals) of any set IV of
%   R.line's intervals: one trial's (its TrialEvents) or the whole line's.
%
%   The line is cleaned once, over the whole recording (lineIntervals),
%   so a trial's first interval is judged against the interval before it
%   even when that one lies in another trial. FIX then gives, for the
%   intervals of IV (matched to the line's by their onsets, to within half
%   a sample), the cleaned intervals they went to, once each, sorted by
%   onset: a stitched interval whole, a dropped one not at all. An
%   interval the line does not hold is kept as it is.
%
%   With neither setting above 0, or a line the recording lacks (the
%   caller says so), FIX returns IV unchanged.
%
%   See also cleanIntervals, lineIntervals, resolveEvents, stopTimes, eventsNear.

fix = @(iv) iv;
stitch = settingOf(r, 'stitchGapSec');
refr = settingOf(r, 'refractorySec');
if ~(stitch > 0 || refr > 0); return; end
try
    raw = lineIntervals(src, r.line);
catch ME
    if ME.identifier ~= "resolveEvents:NoLine"; rethrow(ME); end
    return
end
[clean, map] = cleanIntervals(raw, stitch, refr);
tol = 1e-6;
if isfield(src, 'fs') && isscalar(src.fs) && isfinite(src.fs) && src.fs > 0; tol = 0.5 / src.fs; end
fix = @(iv) cleaned(iv, raw, clean, map, tol);
end


function iv = cleaned(iv, raw, clean, map, tol)
%cleaned  The cleaned intervals the intervals IV of the line went to.
if isempty(iv); return; end
iv = double(iv);
[in, loc] = ismembertol(iv(:, 1), raw(:, 1), tol, 'DataScale', 1);
k = unique(nonzeros(map(loc(in))));
iv = sortrows([clean(k, :); iv(~in, :)]);
end


function v = settingOf(r, name)
v = 0;
if isfield(r, name) && isscalar(r.(name)) && isnumeric(r.(name)); v = double(r.(name)); end
end
