function X = tdtReadTev(tevPath, O, npts, fmt, itemSize, rowOffset, nRows, cols)
%tdtReadTev  Rows of a TEV-stored stream, as stored (double).
%   X = tdtReadTev(TEVPATH, O, NPTS, FMT, ITEMSIZE, ROWOFFSET, NROWS, COLS)
%   returns samples ROWOFFSET+1 .. ROWOFFSET+NROWS (0-based ROWOFFSET) of
%   the stream channels COLS (columns of O, the tdtStreamOffsets matrix) as
%   an [NROWS x numel(COLS)] double of the stored values. Chunk k of a
%   channel holds its samples (k-1)*NPTS+1 .. k*NPTS, NPTS values of class
%   FMT (ITEMSIZE bytes each) at byte O(k, c) of the TEV file. Chunks are
%   read in groups spanning at most 16 MB of the file.
%
%   Plain MATLAB (no string or arguments syntax) so it also runs in Octave.

nC = numel(cols);
X = zeros(nRows, nC);
if nRows == 0 || nC == 0; return; end
first = floor(rowOffset / npts) + 1;
last = floor((rowOffset + nRows - 1) / npts) + 1;
if last > size(O, 1)
    error('TDTReader:BadWindow', 'Rows %d-%d are past the stream''s %d chunks of %d samples.', ...
        rowOffset + 1, rowOffset + nRows, size(O, 1), npts);
end
fid = fopen(tevPath, 'r', 'ieee-le');
if fid < 0
    error('TDTReader:Open', 'Cannot open %s', tevPath);
end
closer = onCleanup(@() fclose(fid));

bytesPer = npts * itemSize;
maxSpan = 2^24;
Ow = O(first:last, cols);                      % chunk rows of the window x channels
lo = double(min(Ow, [], 2));
hi = double(max(Ow, [], 2)) + bytesPer;
nK = size(Ow, 1);
Y = zeros(nK * npts, nC);                      % whole chunks of the window
k = 1;
while k <= nK
    g = k;
    gLo = lo(k); gHi = hi(k);
    while g < nK && max(gHi, hi(g + 1)) - min(gLo, lo(g + 1)) <= maxSpan
        g = g + 1;
        gLo = min(gLo, lo(g)); gHi = max(gHi, hi(g));
    end
    span = gHi - gLo;
    fseek(fid, gLo, 'bof');
    buf = fread(fid, span, 'uint8=>uint8');
    if numel(buf) < span
        error('TDTReader:TevTruncated', ...
            '%s ends at byte %d, before the data of stream chunk %d (byte %d).', ...
            tevPath, gLo + numel(buf), first + k - 1, gHi - bytesPer);
    end
    rel = double(Ow(k:g, :)) - gLo;            % [nG x nC] bytes into buf
    idx = bsxfun(@plus, uint32(1:bytesPer).', uint32(reshape(rel, 1, [])));
    V = reshape(typecast(reshape(buf(idx), [], 1), fmt), npts, []);
    nG = g - k + 1;
    rows = (k - 1) * npts + (1:nG * npts);
    for j = 1:nC
        Y(rows, j) = double(reshape(V(:, (j - 1) * nG + (1:nG)), [], 1));
    end
    k = g + 1;
end
a = rowOffset - (first - 1) * npts;            % rows of the first chunk before the window
X(:, :) = Y(a + (1:nRows), :);
end
