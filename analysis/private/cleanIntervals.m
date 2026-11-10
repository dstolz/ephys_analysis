function [out, map] = cleanIntervals(iv, stitchGapSec, refractorySec)
%cleanIntervals  A line's intervals with short gaps stitched and re-entries inside a refractory period dropped.
%   [OUT, MAP] = cleanIntervals(IV, STITCHGAPSEC, REFRACTORYSEC) takes the
%   [on off] intervals IV [n x 2] (s) of one digital line and, in this order:
%     stitch      an interval that starts at most STITCHGAPSEC after the end
%                 of the one before joins it: the two become one interval,
%                 from the first onset to the last offset (so do a run of
%                 them). 0: none
%     refractory  an interval that starts less than REFRACTORYSEC after the
%                 end of the interval before it (stitched as above) is
%                 dropped: its onset is not a new event, and the interval
%                 before keeps its offset. Each gap is measured from the
%                 interval before, kept or not, so a run of blips each
%                 closer than REFRACTORYSEC to the last goes whole. 0: none
%   OUT is the cleaned list, sorted by onset; MAP [n x 1] the row of OUT
%   each row of IV went to (0: dropped). With both 0, OUT is IV as given
%   and MAP is 1:n. An interval with a time that is not finite is left as
%   it is, after the others. Pure: no I/O.
%
%   An event reference's stitchGapSec / refractorySec and a sequence
%   step's are these (eventRef); lineCleaner applies them to a dataset's
%   line.
%
%   See also lineCleaner, eventRef, followSequence.

n = size(iv, 1);
out = iv;
map = (1:n).';
if n == 0 || ~(stitchGapSec > 0 || refractorySec > 0); return; end

fin = all(isfinite(iv), 2);
rows = find(fin);
[s, o] = sortrows(iv(fin, :));
m = size(s, 1);
g = (1:m).';                               % the stitched interval of each sorted one
if stitchGapSec > 0 && m > 1
    runEnd = cummax(s(:, 2));
    g = cumsum([true; s(2:end, 1) - runEnd(1:end-1) > stitchGapSec]);
    s = [accumarray(g, s(:, 1), [], @min) accumarray(g, s(:, 2), [], @max)];
end
keep = true(size(s, 1), 1);
if refractorySec > 0 && size(s, 1) > 1
    runEnd = cummax(s(:, 2));
    keep(2:end) = s(2:end, 1) - runEnd(1:end-1) >= refractorySec;
end
idx = cumsum(keep);
idx(~keep) = 0;
out = [s(keep, :); iv(~fin, :)];
map = zeros(n, 1);
map(rows(o)) = idx(g);
map(~fin) = nnz(keep) + (1:nnz(~fin)).';
end
