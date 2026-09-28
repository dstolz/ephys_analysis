function S = tdtScanTsq(tsqPath)
%tdtScanTsq  One pass over a TDT block's TSQ file: stores, epocs, stream chunks.
%   S = tdtScanTsq(TSQPATH) reads the 40-byte event headers of TSQPATH in
%   blocks and returns
%     startTime, stopTime  block start / stop (seconds since 1970, UTC) from
%                          the start and stop marks (code 1 and 2); stopTime
%                          is NaN when the block did not end cleanly
%     nHeaders             headers read (after the file header)
%     nTrailing            trailing words dropped (the file does not end on a
%                          whole header)
%     nBadCodes            headers with code 0, dropped (as TDT's readers do)
%     stores               struct array, one per store in order of first
%                          appearance: name (4 chars, NULs as spaces,
%                          trailing blanks removed), code, type, typeStr
%                          ('epocs' | 'snips' | 'streams' | 'scalars' |
%                          'unknown'), epocType ('onset' | 'offset' | ''),
%                          ucf (stream data in SEV files), dform, size (words,
%                          header included), fs (the header's float32 rate),
%                          buddy (epoc buddy name), count (headers),
%                          sizeMismatch (a header whose size differs from
%                          the first)
%     epocTs{k}, epocVal{k}      epoc store k: onset times (s from the block
%                          start, rounded to the 195312.5 Hz tick as TDT's
%                          readers do) and the strobe values (double)
%     streamChan{k}        stream store k: channel numbers present (sorted)
%     streamCount{k}       chunks per channel (aligned with streamChan)
%     streamTs{k}          chunk times of the lowest channel (s, rounded)
%   The TEV offsets of a stream's chunks are read by tdtStreamOffsets.
%
%   Header words (uint32, little-endian): 1 size, 2 type, 3 code, 4 channel
%   (low 16 bits) + sort code, or the epoc buddy name, 5-6 timestamp
%   (double, s since 1970), 7-8 TEV offset (uint64) or strobe value
%   (double), 9 data format, 10 sampling rate (float32).
%
%   Plain MATLAB (no string or arguments syntax) so it also runs in Octave.

fid = fopen(tsqPath, 'r', 'ieee-le');
if fid < 0
    error('TDTReader:Open', 'Cannot open %s', tsqPath);
end
closer = onCleanup(@() fclose(fid));

fseek(fid, 0, 'eof');
nBytes = ftell(fid);
if nBytes < 80
    error('TDTReader:BadTsq', '%s is too short to be a TSQ file (%d bytes).', tsqPath, nBytes);
end
fseek(fid, 48, 'bof');
code1 = fread(fid, 1, 'int32=>double');
if code1 ~= 1
    error('TDTReader:BadTsq', '%s: block start marker not found.', tsqPath);
end
fseek(fid, 56, 'bof');
S.startTime = fread(fid, 1, 'double=>double');
S.stopTime = NaN;
fseek(fid, -32, 'eof');
code2 = fread(fid, 1, 'int32=>double');
if code2 == 2
    fseek(fid, -24, 'eof');
    S.stopTime = fread(fid, 1, 'double=>double');
end

stores = struct('name', {}, 'code', {}, 'type', {}, 'typeStr', {}, 'epocType', {}, ...
    'ucf', {}, 'dform', {}, 'size', {}, 'fs', {}, 'buddy', {}, 'count', {}, 'sizeMismatch', {});
codeList = zeros(1, 0);
epocTs = {}; epocVal = {};
chanCount = {}; minChan = []; tsParts = {};

fseek(fid, 40, 'bof');
blockHeaders = 2^20;
nHeaders = 0; nTrailing = 0; nBadCodes = 0;
while true
    raw = fread(fid, 10 * blockHeaders, 'uint32=>uint32');
    if isempty(raw); break; end
    rem10 = mod(numel(raw), 10);
    if rem10 ~= 0
        nTrailing = rem10;
        raw = raw(1:end - rem10);
    end
    if isempty(raw); break; end
    H = reshape(raw, 10, []);
    nHeaders = nHeaders + size(H, 2);
    codes = double(H(3, :));
    bad = codes == 0;
    if any(bad)
        nBadCodes = nBadCodes + nnz(bad);
        H = H(:, ~bad);
        codes = codes(~bad);
    end
    keep = codes ~= 1 & codes ~= 2;            % block start / stop marks
    H = H(:, keep);
    codes = codes(keep);
    if isempty(codes); continue; end
    [u, firstIdx] = unique(codes, 'first');
    [~, order] = sort(firstIdx);               % stores in order of appearance
    u = u(order);
    for code = u
        m = codes == code;
        k = find(codeList == code, 1);
        if isempty(k)
            j = find(m, 1);
            st = newStore(H(:, j), code);
            stores(end + 1) = st; %#ok<AGROW>
            codeList(end + 1) = code; %#ok<AGROW>
            k = numel(codeList);
            epocTs{k} = zeros(0, 1); epocVal{k} = zeros(0, 1); %#ok<AGROW>
            chanCount{k} = zeros(65536, 1); minChan(k) = Inf; tsParts{k} = {}; %#ok<AGROW>
        end
        Hm = H(:, m);
        stores(k).count = stores(k).count + size(Hm, 2);
        if any(double(Hm(1, :)) ~= stores(k).size)
            stores(k).sizeMismatch = true;
        end
        switch stores(k).typeStr
            case 'epocs'
                ts = tickRound(wordsToDouble(Hm(5:6, :)) - S.startTime);
                epocTs{k} = [epocTs{k}; ts(:)];
                epocVal{k} = [epocVal{k}; reshape(wordsToDouble(Hm(7:8, :)), [], 1)];
            case 'streams'
                ch = channelOf(Hm(4, :));
                chanCount{k} = chanCount{k} + accumarray(ch(:) + 1, 1, [65536 1]);
                % Chunk times of the lowest channel only. A channel first seen
                % here has no earlier chunks, so a lower one replaces the parts.
                if min(ch) < minChan(k)
                    minChan(k) = min(ch);
                    tsParts{k} = {};
                end
                tsParts{k}{end + 1} = tickRound(wordsToDouble(Hm(5:6, ch == minChan(k))) - S.startTime);
        end
    end
end

S.nHeaders = nHeaders;
S.nTrailing = nTrailing;
S.nBadCodes = nBadCodes;
S.stores = stores;
S.epocTs = epocTs;
S.epocVal = epocVal;
S.streamChan = cell(1, numel(stores));
S.streamCount = cell(1, numel(stores));
S.streamTs = cell(1, numel(stores));
for k = 1:numel(stores)
    if ~strcmp(stores(k).typeStr, 'streams'); continue; end
    present = find(chanCount{k}) - 1;
    S.streamChan{k} = reshape(present, 1, []);
    S.streamCount{k} = reshape(chanCount{k}(present + 1), 1, []);
    S.streamTs{k} = reshape([zeros(1, 0) tsParts{k}{:}], [], 1);
end
end


function st = newStore(h, code)
%newStore  A store's description from its first header.
type = double(h(2));
st.name = codeName(code);
st.code = code;
st.type = type;
st.typeStr = typeOf(type);
st.epocType = '';
if strcmp(st.typeStr, 'epocs')
    if type == hex2dec('101') || type == hex2dec('8801')
        st.epocType = 'onset';
    elseif type == hex2dec('102')
        st.epocType = 'offset';
    end
end
st.ucf = bitand(type, hex2dec('10')) == hex2dec('10');
st.dform = double(h(9));
st.size = double(h(1));
st.fs = double(typecast(h(10), 'single'));
st.buddy = '';
if strcmp(st.typeStr, 'epocs')
    st.buddy = cleanName(char(typecast(h(4), 'uint8')));
end
st.count = 0;
st.sizeMismatch = false;
end


function s = typeOf(type)
%typeOf  Store kind of an event type (TDTbin2mat code2type).
if any(type == [hex2dec('101') hex2dec('102') hex2dec('8801')])
    s = 'epocs';
elseif type == hex2dec('8201')
    s = 'snips';
elseif bitand(type, hex2dec('FF0F')) == hex2dec('8101')
    s = 'streams';
elseif type == hex2dec('201')
    s = 'scalars';
else
    s = 'unknown';
end
end


function name = codeName(code)
%codeName  The 4-character store name of a store code.
name = cleanName(char(typecast(uint32(code), 'uint8')));
end


function name = cleanName(name)
%cleanName  NULs as spaces, trailing blanks removed.
name = reshape(name, 1, []);
name(name == char(0)) = ' ';
name = deblank(name);
end


function ch = channelOf(w)
%channelOf  Channel numbers (low 16 bits of header word 4).
ch = double(bitand(w, uint32(65535)));
end


function d = wordsToDouble(W)
%wordsToDouble  Pairs of uint32 words (2 x n) as n doubles.
d = typecast(reshape(W, 1, []), 'double');
end


function t = tickRound(t)
%tickRound  Times rounded to the 195312.5 Hz tick (TDT's time2sample TO_TIME).
fs = 195312.5;
s = round(t * fs * 1e9) / 1e9;
t = round(s) / fs;
end
