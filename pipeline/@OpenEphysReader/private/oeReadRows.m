function X = oeReadRows(format, P, r0, n, chanIdx)
%oeReadRows  Raw int16 samples of one recording: rows r0..r0+n-1, stream channels CHANIDX.
%   X = oeReadRows(FORMAT, P, R0, N, CHANIDX) returns [N x numel(CHANIDX)]
%   int16 values as stored (scale with each channel's bitVolts). P is the
%   part (oePartDetails); rows are 1-based within the part; CHANIDX are
%   1-based positions in the stream's channel list.

chanIdx = reshape(chanIdx, 1, []);
X = zeros(n, numel(chanIdx), 'int16');
if n <= 0 || isempty(chanIdx); return; end
switch format
    case "binary"
        fid = fopen(P.datFile, 'r', 'ieee-le');
        if fid < 0; error('OpenEphysReader:Open', 'Cannot open %s', P.datFile); end
        closer = onCleanup(@() fclose(fid));
        nc = P.nChanStream;
        if fseek(fid, (r0 - 1) * nc * 2, 'bof') ~= 0
            error('OpenEphysReader:Seek', 'Cannot seek to row %d of %s', r0, P.datFile);
        end
        raw = fread(fid, [nc, n], 'int16=>int16');
        X(1:size(raw, 2), :) = raw(chanIdx, :).';
    case "legacy"
        k0 = P.firstRecord + floor((r0 - 1) / 1024);      % first record (0-based)
        off = mod(r0 - 1, 1024);
        nRec = ceil((off + n) / 1024);
        for j = 1:numel(chanIdx)
            f = P.channelFiles(chanIdx(j));
            fid = fopen(f, 'r', 'ieee-be');
            if fid < 0; error('OpenEphysReader:Open', 'Cannot open %s', f); end
            closer = onCleanup(@() fclose(fid));
            fseek(fid, 1024 + k0 * 2070 + 12, 'bof');
            v = fread(fid, nRec * 1024, '1024*int16=>int16', 22);   % skip marker + next header
            v = v(off + 1 : min(off + n, numel(v)));
            X(1:numel(v), j) = v;
            clear closer
        end
    case "nwb"
        lo = min(chanIdx); hi = max(chanIdx);
        raw = h5read(P.file, P.dsPath + "/data", [lo, P.rowOffset + r0], [hi - lo + 1, n]);
        X(:, :) = int16(raw(chanIdx - lo + 1, :)).';
end
end
