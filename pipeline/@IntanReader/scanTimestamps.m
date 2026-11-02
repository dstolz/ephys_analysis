function S = scanTimestamps(ffn, offset, stride, n, step, unsigned)
%scanTimestamps  The acquisition clock of an Intan file: its first stamp, its end and every jump.
%   S = IntanReader.scanTimestamps(FFN, OFFSET, STRIDE, N, STEP) reads the
%   32-bit sample timestamps RHX and the RHD2000 Interface count on through
%   a recording. The N stamps sit at byte OFFSET + k*STRIDE of the file FFN
%   (k = 0..N-1) and each should be STEP more than the one before:
%     traditional *.rhd   the first int32 of each data block - OFFSET the
%                         header size, STRIDE the bytes per block, STEP the
%                         samples per block
%     split time.dat      every int32 of the file - OFFSET 0, STRIDE 4, STEP 1
%   S = IntanReader.scanTimestamps(..., UNSIGNED) with UNSIGNED true reads
%   the stamps of a file before version 1.2 as uint32 for S.first / S.end.
%   S has
%     first    the first stamp
%     end      the stamp the next file should start at: the last stamp + STEP
%     index    0-based number of each stamp that does not follow the one
%              before by STEP (the block, or the sample, after a jump)
%     jumps    how far each is from where it should be, in samples: positive
%              = samples missing, negative = the clock went back
%
%   Only the first and the last stamp are read when the file spans exactly
%   the samples it holds (the usual case, so a scan costs two reads). A
%   file that does not is read stamp by stamp, a strided fread of 4 bytes a
%   block, a million blocks at a time, to find where. The stamps are
%   compared modulo 2^32, so the signed 32-bit count wrapping after
%   2^31 samples is no jump.
%
%   See also IntanReader.refreshMetadata, IntanReader.parseIntanHeader.

arguments
    ffn (1,1) string
    offset (1,1) double
    stride (1,1) double
    n (1,1) double
    step (1,1) double
    unsigned (1,1) logical = false
end

S = struct('first', NaN, 'end', NaN, 'index', zeros(0, 1), 'jumps', zeros(0, 1));
if n <= 0
    return
end
fid = fopen(ffn, 'r', 'ieee-le');
if fid < 0
    error('IntanReader:scanTimestamps:OpenFailed', 'Could not open %s', ffn);
end
closer = onCleanup(@() fclose(fid));

a = readStamp(fid, offset, ffn);
b = readStamp(fid, offset + (n - 1) * stride, ffn);
S.first = a;
S.end = b + step;
if unsigned
    S.first = mod(a, 2^32);
    S.end = mod(b + step, 2^32);
end
if mod(b - a + step, 2^32) == mod(n * step, 2^32)
    return                                          % spans exactly its samples: no jump
end

chunk = 2^20;
c0 = 0;
while c0 < n - 1
    m = min(chunk + 1, n - c0);                     % one stamp more than a chunk's diffs need
    if fseek(fid, offset + c0 * stride, 'bof') ~= 0
        error('IntanReader:scanTimestamps:SeekFailed', 'Could not seek to stamp %d of %s', c0, ffn);
    end
    ts = fread(fid, m, 'int32=>double', stride - 4);
    if numel(ts) < 2; break; end
    d = mod(diff(ts) - step + 2^31, 2^32) - 2^31;   % the signed jump from the expected step
    k = find(d ~= 0);
    S.index = [S.index; c0 + k];
    S.jumps = [S.jumps; d(k)];
    c0 = c0 + chunk;
end
end


function v = readStamp(fid, at, ffn)
%readStamp  The int32 at byte AT, as double.
if fseek(fid, at, 'bof') ~= 0
    error('IntanReader:scanTimestamps:SeekFailed', 'Could not seek to byte %d of %s', at, ffn);
end
v = fread(fid, 1, 'int32=>double');
if isempty(v)
    error('IntanReader:scanTimestamps:ShortRead', '%s ends before the timestamp at byte %d.', ffn, at);
end
end
