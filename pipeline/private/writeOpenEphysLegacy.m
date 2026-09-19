function W = writeOpenEphysLegacy(session, meta)
%writeOpenEphysLegacy  Streaming writer of an Open Ephys format session (test data).
%   W = writeOpenEphysLegacy(SESSION, META) writes, under SESSION/Record Node
%   <META.NodeId>, what the GUI's "Open Ephys" record engine writes (GUI 0.6+
%   file names; META.Layout "0.5" writes the GUI 0.4/0.5 names and
%   all_channels.events instead):
%     <proc>_<stream>_<channel>[_<E>].continuous   1024-byte header, then
%        2070-byte records: int64 first sample number, uint16 1024, uint16
%        recording number (0-based), 1024 big-endian int16, 10-byte marker
%     <proc>_<stream>[_<E>].events   16-byte TTL records (type 3)
%     <proc>_<stream>[_<E>].timestamps   one float64 per record
%     messages[_<E>].events   "<ms>, Software Time ..." per recording
%     structure[_<E>].openephys   XML (EXPERIMENT / RECORDING / STREAM / CHANNEL)
%   Handles as writeOpenEphysBinary: begin(E, R, FIRSTSAMPLE, START),
%   append(X, WORD, AUX, ADC), skip(n) (whole dropped records only: n must
%   be a multiple of 1024 at a record boundary), finish(); then closeAll()
%   after the last recording. As the GUI does, finish() fills the last
%   record of a recording with zeros, and date_created leaves the seconds
%   unpadded ("17-Sep-2026 10:30:5").

meta = defaults(meta);
node = string(fullfile(session, "Record Node " + meta.NodeId));
if ~isfolder(node); mkdir(node); end
streamTok = replace(replace(meta.StreamName, " ", ""), "_", "-");
names = ["CH" + (1:meta.NumChannels), "AUX" + (1:meta.AuxCount), "ADC" + (1:meta.AdcCount)];
bitv = [repmat(meta.BitVolts, 1, meta.NumChannels), repmat(meta.AuxBitVolts, 1, meta.AuxCount), ...
    repmat(meta.AdcBitVolts, 1, meta.AdcCount)];
nAll = numel(names);
S = struct('exp', 0, 'rec', 0, 'fids', [], 'evFid', -1, 'tsFid', -1, 'buf', zeros(0, nAll), ...
    'bufFirst', 0, 'next', 0, 'first', 0, 'lastWord', NaN, 'open', false, 'recs', {{}});

W = struct('begin', @begin, 'append', @append, 'skip', @skip, 'finish', @finish, ...
    'closeAll', @closeAll, 'nodeFolder', node, 'channelFile', @channelFile);

    function f = channelFile(k, e)
        suffix = ""; if e > 1; suffix = "_" + e; end
        if meta.Layout == "0.5"
            f = string(meta.ProcessorId) + "_" + names(k) + suffix + ".continuous";
        else
            f = string(meta.ProcessorId) + "_" + streamTok + "_" + names(k) + suffix + ".continuous";
        end
    end

    function begin(e, r, firstSample, start)
        if e ~= S.exp
            closeExperiment();
            S.exp = e;
            S.recs = {};
            suffix = ""; if e > 1; suffix = "_" + e; end
            S.fids = zeros(1, nAll);
            mon = ["Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"];
            if meta.Layout == "0.5"
                dateTxt = sprintf("%02d-%s-%d %02d%02d%02d", start.Day, mon(start.Month), start.Year, ...
                    start.Hour, start.Minute, floor(start.Second));
            else
                dateTxt = sprintf("%02d-%s-%d %02d:%02d:%d", start.Day, mon(start.Month), start.Year, ...
                    start.Hour, start.Minute, floor(start.Second));
            end
            for k = 1:nAll
                S.fids(k) = fopen(fullfile(node, channelFile(k, e)), 'w');
                writeHeader(S.fids(k), sprintf(['header.channel = ''%s'';\nheader.channelType = ''Continuous'';\n' ...
                    'header.sampleRate = %d;\nheader.blockLength = 1024;\nheader.bitVolts = %.10g;\n'], ...
                    names(k), meta.Fs, bitv(k)), dateTxt);
            end
            if meta.Layout == "0.5"
                ev = "all_channels" + suffix + ".events";
            else
                ev = string(meta.ProcessorId) + "_" + streamTok + suffix + ".events";
                S.tsFid = fopen(fullfile(node, string(meta.ProcessorId) + "_" + streamTok + suffix + ".timestamps"), 'w');
            end
            S.evFid = fopen(fullfile(node, ev), 'w');
            writeHeader(S.evFid, sprintf('header.channel = ''Events'';\nheader.channelType = ''Event'';\nheader.blockLength = 1024;\n'), dateTxt);
            S.msgFile = fullfile(node, "messages" + suffix + ".events");
            if isfile(S.msgFile); delete(S.msgFile); end
        end
        S.rec = r - 1;
        S.first = firstSample; S.next = firstSample; S.bufFirst = firstSample;
        S.buf = zeros(0, nAll);
        S.lastWord = NaN;
        S.open = true;
        S.recs{end+1} = r;
        fid = fopen(S.msgFile, 'a');
        fprintf(fid, '%d, Software Time (milliseconds since midnight Jan 1st 1970 UTC)\n', ...
            round(posixtime(localToUtc(start)) * 1000));
        fprintf(fid, '%d, Start Time for %s (%d) - %s @ %d Hz\n', firstSample, meta.ProcessorName, ...
            meta.ProcessorId, meta.StreamName, meta.Fs);
        fclose(fid);
    end

    function append(X, word, aux, adc)
        n = size(X, 1);
        if nargin < 3 || isempty(aux); aux = zeros(n, meta.AuxCount); end
        if nargin < 4 || isempty(adc); adc = zeros(n, meta.AdcCount); end
        raw = [X, aux, adc] ./ bitv;
        sn = S.next + (0:n-1).';
        word = double(word(:));
        if isnan(S.lastWord); S.lastWord = word(1); end
        prev = [S.lastWord; word(1:end-1)];
        for i = find(word ~= prev).'
            changed = bitxor(uint64(word(i)), uint64(prev(i)));
            for L = find(bitget(changed, 1:16))
                up = bitget(uint64(word(i)), L) == 1;
                writeEvent(sn(i), up, L - 1);
            end
        end
        S.lastWord = word(end);
        S.buf = [S.buf; raw];
        S.next = S.next + n;
        flushRecords(false);
    end

    function skip(n)
        if size(S.buf, 1) ~= 0 || mod(n, 1024) ~= 0
            error('writeOpenEphysLegacy:Skip', 'Only whole records can be dropped, at a record boundary.');
        end
        S.next = S.next + n;
        S.bufFirst = S.next;
    end

    function writeEvent(sn, up, line0)
        rec = zeros(1, 16, 'uint8');
        rec(1:8) = typecast(int64(sn), 'uint8');
        rec(9:10) = typecast(int16(0), 'uint8');
        rec(11) = 3;
        rec(12) = uint8(mod(meta.ProcessorId, 256));
        rec(13) = uint8(up);
        rec(14) = uint8(line0);
        rec(15:16) = typecast(uint16(S.rec), 'uint8');
        fwrite(S.evFid, rec, 'uint8');
    end

    function flushRecords(padLast)
        nFull = floor(size(S.buf, 1) / 1024);
        if padLast && mod(size(S.buf, 1), 1024) ~= 0
            S.buf(end+1 : (nFull + 1) * 1024, :) = 0;
            nFull = nFull + 1;
        end
        if nFull > 0
            sn0 = S.bufFirst + (0:nFull-1) * 1024;
            head = [reshape(typecast(int64(sn0), 'uint8'), 8, nFull); ...
                repmat(typecast(uint16(1024), 'uint8').', 1, nFull); ...
                repmat(typecast(uint16(S.rec), 'uint8').', 1, nFull)];
            marker = repmat(uint8([0 1 2 3 4 5 6 7 8 255]).', 1, nFull);
            for k = 1:nAll
                v = swapbytes(int16(min(max(round(S.buf(1:nFull * 1024, k)), -32768), 32767)));
                B = [head; reshape(typecast(v, 'uint8'), 2048, nFull); marker];
                fwrite(S.fids(k), B, 'uint8');
            end
            if S.tsFid > 0
                fwrite(S.tsFid, double(sn0 - S.first) / meta.Fs, 'double');
            end
        end
        S.buf = S.buf(nFull * 1024 + 1 : end, :);
        S.bufFirst = S.bufFirst + nFull * 1024;
    end

    function finish()
        if ~S.open; return; end
        flushRecords(true);
        S.open = false;
        writeXml();
    end

    function closeExperiment()
        if S.exp == 0; return; end
        for k = 1:numel(S.fids); fclose(S.fids(k)); end
        fclose(S.evFid);
        if S.tsFid > 0; fclose(S.tsFid); S.tsFid = -1; end
        S.fids = [];
    end

    function writeXml()
        if meta.Layout == "0.5"; return; end
        suffix = ""; if S.exp > 1; suffix = "_" + S.exp; end
        f = fullfile(node, "structure" + suffix + ".openephys");
        fid = fopen(f, 'w');
        fprintf(fid, '<?xml version="1.0" encoding="UTF-8"?>\n\n<EXPERIMENT format_version="1.0" number="%d">\n', S.exp);
        for r = [S.recs{:}]
            fprintf(fid, '  <RECORDING number="%d">\n', r);
            fprintf(fid, '    <STREAM name="%s" source_node_id="%d" source_node_name="%s" sample_rate="%d">\n', ...
                meta.StreamName, meta.ProcessorId, meta.ProcessorName, meta.Fs);
            for k = 1:nAll
                fprintf(fid, '      <CHANNEL name="%s" bitVolts="%.10g" filename="%s" position="1024"/>\n', ...
                    names(k), bitv(k), channelFile(k, S.exp));
            end
            fprintf(fid, '      <EVENTS filename="%d_%s%s.events"/>\n', meta.ProcessorId, streamTok, suffix);
            fprintf(fid, '    </STREAM>\n  </RECORDING>\n');
        end
        fprintf(fid, '</EXPERIMENT>\n');
        fclose(fid);
    end

    function closeAll()
        finish();
        closeExperiment();
    end
end


function writeHeader(fid, body, dateTxt)
h = sprintf(['header.format = ''Open Ephys Data Format''; \nheader.version = 1.0; \n' ...
    'header.header_bytes = 1024;\nheader.description = ''synthetic''; \n' ...
    'header.date_created = ''%s'';\n%s'], dateTxt, body);
h = [h repmat(' ', 1, 1024 - numel(h))];
fwrite(fid, h(1:1024), 'char');
end


function meta = defaults(meta)
d = struct('Fs', 30000, 'NumChannels', 16, 'AuxCount', 3, 'AdcCount', 0, 'BitVolts', 0.195, ...
    'AuxBitVolts', 0.0000374, 'AdcBitVolts', 0.00015258789, 'NodeId', 101, ...
    'ProcessorName', "Acquisition Board", 'ProcessorId', 100, 'StreamName', "Rhythm Data", ...
    'Layout', "0.6");
for f = string(fieldnames(d)).'
    if ~isfield(meta, f); meta.(f) = d.(f); end
end
end


function t = localToUtc(t)
t.TimeZone = 'local';
t.TimeZone = 'UTC';
end
