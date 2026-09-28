function X = tdtReadSev(files, counts, fmt, itemSize, rowOffset, nRows)
%tdtReadSev  Rows of a SEV-stored stream, as stored (double).
%   X = tdtReadSev(FILES, COUNTS, FMT, ITEMSIZE, ROWOFFSET, NROWS) returns
%   samples ROWOFFSET+1 .. ROWOFFSET+NROWS (0-based ROWOFFSET) as an
%   [NROWS x nChan] double of the stored values. FILES is a cell array
%   {nChan x nHours} of SEV paths (one channel per row, hours in order) and
%   COUNTS [nChan x nHours] their sample counts; a channel's hours follow
%   one another. The data of each file starts after its 40-byte header.
%
%   Plain MATLAB (no string or arguments syntax) so it also runs in Octave.

nC = size(files, 1);
X = zeros(nRows, nC);
if nRows == 0 || nC == 0; return; end
a = rowOffset + 1; b = rowOffset + nRows;      % 1-based rows of the channel
for c = 1:nC
    edges = [0 cumsum(counts(c, :))];
    if b > edges(end)
        error('TDTReader:BadWindow', 'Rows %d-%d are past the %d samples of %s.', ...
            a, b, edges(end), files{c, 1});
    end
    for h = 1:size(files, 2)
        lo = max(a, edges(h) + 1); hi = min(b, edges(h + 1));
        if hi < lo; continue; end
        fid = fopen(files{c, h}, 'r', 'ieee-le');
        if fid < 0
            error('TDTReader:Open', 'Cannot open %s', files{c, h});
        end
        fseek(fid, 40 + (lo - edges(h) - 1) * itemSize, 'bof');
        n = hi - lo + 1;
        v = fread(fid, n, [fmt '=>double']);
        fclose(fid);
        if numel(v) < n
            error('TDTReader:SevTruncated', '%s: %d of %d samples read.', files{c, h}, numel(v), n);
        end
        X(lo - a + 1:hi - a + 1, c) = v;
    end
end
end
