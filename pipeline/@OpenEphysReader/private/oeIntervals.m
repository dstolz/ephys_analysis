function iv = oeIntervals(ev, runs, nRows, nLines, where)
%oeIntervals  TTL edges -> [on off] rows (1-based, within one recording) per line.
%   IV = oeIntervals(EV, RUNS, NROWS, NLINES, WHERE) returns a 1 x NLINES
%   cell, IV{L} = [k x 2] [first high row, last high row] of TTL line L.
%   Event sample numbers become rows through the recording's stored-sample
%   RUNS ([firstRow lastRow firstSample], oePartDetails); a sample inside a
%   gap maps to the next stored row, with one warning. A rising edge at row
%   r opens an interval at r, a falling edge at r closes it at r - 1. A line
%   high before its first edge (first edge falling, set in the initial TTL
%   word, or set in the TTL words without any edge of its own) starts at
%   row 1; one still high after its last edge ends at NROWS. Repeated
%   same-state edges are ignored.

iv = repmat({zeros(0, 2)}, 1, nLines);
if nLines == 0; return; end
rows = sampleToRow(ev.sn, runs, nRows, where);
for L = 1:nLines
    sel = ev.line == L;
    s = rows(sel); st = ev.state(sel);
    if isfinite(ev.initialWord)
        high = bitget(uint64(ev.initialWord), L) == 1;
    elseif ~isempty(st)
        high = st(1) == 0;
    elseif ~isempty(ev.fullWord)
        high = bitget(ev.fullWord(1), L) == 1;
    else
        high = false;
    end
    on = 1;
    out = zeros(0, 2);
    for k = 1:numel(s)
        if st(k) == 1
            if ~high; on = s(k); high = true; end
        elseif high
            off = min(s(k) - 1, nRows);
            if off >= on && on <= nRows; out(end+1, :) = [on off]; end %#ok<AGROW>
            high = false;
        end
    end
    if high && on <= nRows
        out(end+1, :) = [on nRows]; %#ok<AGROW>
    end
    iv{L} = out;
end
end


function rows = sampleToRow(sn, runs, nRows, where)
%sampleToRow  Stored row of each sample number (1 before the recording,
%   nRows + 1 after it, the next stored row inside a gap).
rows = zeros(size(sn));
if isempty(sn) || isempty(runs); rows(:) = 1; return; end
placed = false(size(sn));
inGap = false;
for k = 1:size(runs, 1)
    first = runs(k, 3);
    len = runs(k, 2) - runs(k, 1) + 1;
    in = ~placed & sn >= first & sn < first + len;
    rows(in) = runs(k, 1) + (sn(in) - first);
    placed = placed | in;
    if k < size(runs, 1)
        gap = ~placed & sn >= first + len & sn < runs(k + 1, 3);
        rows(gap) = runs(k + 1, 1);
        placed = placed | gap;
        inGap = inGap || any(gap);
    end
end
rows(~placed & sn < runs(1, 3)) = 1;
rows(~placed & sn >= runs(end, 3) + (runs(end, 2) - runs(end, 1) + 1)) = nRows + 1;
if inGap
    warning('OpenEphysReader:EventInGap', ...
        '%s: TTL edges fall in dropped samples; they are placed at the next stored sample.', where);
end
end
