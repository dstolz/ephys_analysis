function O = tdtStreamOffsets(tsqPath, code, chans, counts)
%tdtStreamOffsets  TEV byte offsets of one stream store's chunks.
%   O = tdtStreamOffsets(TSQPATH, CODE, CHANS, COUNTS) reads the TSQ headers
%   of the store with code CODE and returns O, [max(COUNTS) x numel(CHANS)]
%   uint64: column c holds the TEV offsets of channel CHANS(c)'s chunks in
%   file order (chunk k of a channel is its samples (k-1)*npts+1 .. k*npts).
%   CHANS and COUNTS are tdtScanTsq's streamChan / streamCount; a channel
%   with fewer chunks than the most leaves zeros at the end of its column.
%
%   Plain MATLAB (no string or arguments syntax) so it also runs in Octave.

fid = fopen(tsqPath, 'r', 'ieee-le');
if fid < 0
    error('TDTReader:Open', 'Cannot open %s', tsqPath);
end
closer = onCleanup(@() fclose(fid));

O = zeros(max([counts(:); 0]), numel(chans), 'uint64');
filled = zeros(1, numel(chans));
col = zeros(65536, 1);
col(chans + 1) = 1:numel(chans);
fseek(fid, 40, 'bof');
blockHeaders = 2^20;
while true
    raw = fread(fid, 10 * blockHeaders, 'uint32=>uint32');
    if isempty(raw); break; end
    raw = raw(1:end - mod(numel(raw), 10));
    if isempty(raw); break; end
    H = reshape(raw, 10, []);
    H = H(:, double(H(3, :)) == code);
    if isempty(H); continue; end
    c = col(double(bitand(H(4, :), uint32(65535))) + 1);
    off = reshape(typecast(reshape(H(7:8, :), 1, []), 'uint64'), [], 1);
    for j = unique(c(:)).'
        if j == 0; continue; end            % a channel the scan did not see
        v = off(c == j);
        n = min(numel(v), size(O, 1) - filled(j));
        O(filled(j) + (1:n), j) = v(1:n);
        filled(j) = filled(j) + n;
    end
end
if ~isequal(filled, reshape(counts, 1, []))
    error('TDTReader:TsqChanged', ...
        '%s: the stream''s chunk counts changed since the block was scanned; refresh the metadata.', tsqPath);
end
end
