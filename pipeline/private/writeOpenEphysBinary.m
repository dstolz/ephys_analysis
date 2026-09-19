function W = writeOpenEphysBinary(session, meta)
%writeOpenEphysBinary  Streaming writer of an Open Ephys GUI Binary session (test data).
%   W = writeOpenEphysBinary(SESSION, META) returns handles that write, under
%   SESSION/Record Node <META.NodeId>, what the GUI's Binary record engine
%   writes (GUI 0.6+ layout):
%     W.begin(E, R, FIRSTSAMPLE, START)   start experiment E, recording R, whose
%                                         first sample number is FIRSTSAMPLE and
%                                         wall-clock start START (datetime)
%     W.append(X, WORD, AUX, ADC)         X [n x nHs] microvolts, WORD [n x 1]
%                                         TTL word per sample (bit L-1 = line L),
%                                         AUX [n x nAux] volts, ADC [n x nAdc] volts
%     W.skip(n)                           drop n samples (a gap in the sample numbers)
%     W.finish()                          close the recording (npy headers,
%                                         structure.oebin, sync_messages.txt)
%   META: Fs, NumChannels, AuxCount (3), AdcCount (0), BitVolts (0.195),
%   AuxBitVolts (0.0000374), AdcBitVolts (0.00015258789), NodeId (101),
%   ProcessorName ("Acquisition Board"), ProcessorId (100), StreamName
%   ("Rhythm Data"), GuiVersion ("1.0.1").
%   TTL events are the WORD changes between consecutive samples of a
%   recording (sample number = first sample with the new state); the word
%   at the first sample is the recording's initial_state.

meta = defaults(meta);
node = fullfile(session, "Record Node " + meta.NodeId);
key = strrep(meta.ProcessorName, " ", "_") + "-" + meta.ProcessorId + "." + meta.StreamName;
S = struct('dir', "", 'fid', -1, 'snFid', -1, 'tsFid', -1, 'n', 0, 'first', 0, 'next', 0, ...
    'start', NaT, 'lastWord', NaN, 'initWord', 0, 'evSn', zeros(0, 1), 'evState', zeros(0, 1), ...
    'evWord', zeros(0, 1, 'uint64'), 'open', false);

W = struct('begin', @begin, 'append', @append, 'skip', @skip, 'finish', @finish, ...
    'nodeFolder', string(node), 'streamKey', key);

    function begin(e, r, firstSample, start)
        S.dir = string(fullfile(node, "experiment" + e, "recording" + r));
        cdir = fullfile(S.dir, "continuous", key);
        if ~isfolder(cdir); mkdir(cdir); end
        S.fid = fopen(fullfile(cdir, "continuous.dat"), 'w', 'ieee-le');
        S.snFid = npyOpen(fullfile(cdir, "sample_numbers.npy"), '<i8');
        S.tsFid = npyOpen(fullfile(cdir, "timestamps.npy"), '<f8');
        S.n = 0; S.first = firstSample; S.next = firstSample; S.start = start;
        S.lastWord = NaN; S.initWord = 0;
        S.evSn = zeros(0, 1); S.evState = zeros(0, 1); S.evWord = zeros(0, 1, 'uint64');
        S.open = true;
        if e > 1 || r == 1
            writeSettings(node, e);
        end
    end

    function append(X, word, aux, adc)
        n = size(X, 1);
        if nargin < 3 || isempty(aux); aux = zeros(n, meta.AuxCount); end
        if nargin < 4 || isempty(adc); adc = zeros(n, meta.AdcCount); end
        raw = [X / meta.BitVolts, aux / meta.AuxBitVolts, adc / meta.AdcBitVolts];
        fwrite(S.fid, int16(min(max(round(raw), -32768), 32767)).', 'int16');
        sn = S.next + (0:n-1).';
        fwrite(S.snFid, int64(sn), 'int64');
        fwrite(S.tsFid, double(sn - S.first) / meta.Fs, 'double');
        word = double(word(:));
        if isnan(S.lastWord); S.initWord = word(1); S.lastWord = word(1); end
        prev = [S.lastWord; word(1:end-1)];
        for i = find(word ~= prev).'
            changed = bitxor(uint64(word(i)), uint64(prev(i)));
            for L = find(bitget(changed, 1:16))
                up = bitget(uint64(word(i)), L) == 1;
                S.evSn(end+1, 1) = sn(i);
                S.evState(end+1, 1) = L * (2 * up - 1);
                S.evWord(end+1, 1) = uint64(word(i));
            end
        end
        S.lastWord = word(end);
        S.n = S.n + n;
        S.next = S.next + n;
    end

    function skip(n)
        S.next = S.next + n;
    end

    function finish()
        if ~S.open; return; end
        fclose(S.fid);
        npyClose(S.snFid, S.n);
        npyClose(S.tsFid, S.n);
        edir = fullfile(S.dir, "events", key, "TTL");
        if ~isfolder(edir); mkdir(edir); end
        writeNPY(fullfile(edir, "states.npy"), int16(S.evState), "<i2");
        writeNPY(fullfile(edir, "sample_numbers.npy"), int64(S.evSn), "<i8");
        writeNPY(fullfile(edir, "timestamps.npy"), double(S.evSn - S.first) / meta.Fs, "<f8");
        writeNPY(fullfile(edir, "full_words.npy"), uint64(S.evWord), "<u8");
        writeOebin();
        fid = fopen(fullfile(S.dir, "sync_messages.txt"), 'w');
        ms = round(posixtime(localToUtc(S.start)) * 1000);
        fprintf(fid, 'Software Time (milliseconds since midnight Jan 1st 1970 UTC): %d\r\n', ms);
        fprintf(fid, 'Start Time for %s (%d) - %s @ %d Hz: %d\r\n', meta.ProcessorName, ...
            meta.ProcessorId, meta.StreamName, meta.Fs, S.first);
        fclose(fid);
        S.open = false;
    end

    function writeOebin()
        ch = {};
        for k = 1:meta.NumChannels
            ch{end+1} = chan("CH" + k, "Headstage data channel", meta.BitVolts, "uV", 0); %#ok<AGROW>
        end
        for k = 1:meta.AuxCount
            ch{end+1} = chan("AUX" + k, "Auxiliary input", meta.AuxBitVolts, "V", 1); %#ok<AGROW>
        end
        for k = 1:meta.AdcCount
            ch{end+1} = chan("ADC" + k, "ADC input", meta.AdcBitVolts, "V", 2); %#ok<AGROW>
        end
        cont = struct('folder_name', key + "/", 'sample_rate', meta.Fs, ...
            'source_processor_name', meta.ProcessorName, 'source_processor_id', meta.ProcessorId, ...
            'stream_name', meta.StreamName, 'recorded_processor', "Record Node", ...
            'recorded_processor_id', meta.NodeId, 'num_channels', numel(ch), 'channels', {ch});
        ev = struct('folder_name', key + "/TTL/", 'channel_name', "TTL Input", ...
            'description', "TTL Events", 'identifier', "acq-board.ttl", 'sample_rate', meta.Fs, ...
            'type', "int16", 'source_processor', meta.ProcessorName, 'stream_name', meta.StreamName, ...
            'initial_state', S.initWord);
        o = struct('GUI_version', meta.GuiVersion, 'continuous', {{cont}}, 'events', {{ev}}, 'spikes', {{}});
        txt = jsonencode(o, 'PrettyPrint', true);
        txt = strrep(txt, '"GUI_version"', '"GUI version"');
        fid = fopen(fullfile(S.dir, "structure.oebin"), 'w');
        fwrite(fid, txt, 'char');
        fclose(fid);
    end
end


function c = chan(name, desc, bv, units, type)
c = struct('channel_name', name, 'description', desc, 'identifier', "genericdata.continuous", ...
    'history', "Acquisition Board -> Record Node", 'bit_volts', bv, 'units', units, 'type', type);
end


function meta = defaults(meta)
d = struct('Fs', 30000, 'NumChannels', 16, 'AuxCount', 3, 'AdcCount', 0, 'BitVolts', 0.195, ...
    'AuxBitVolts', 0.0000374, 'AdcBitVolts', 0.00015258789, 'NodeId', 101, ...
    'ProcessorName', "Acquisition Board", 'ProcessorId', 100, 'StreamName', "Rhythm Data", ...
    'GuiVersion', "1.0.1");
for f = string(fieldnames(d)).'
    if ~isfield(meta, f); meta.(f) = d.(f); end
end
end


function writeSettings(node, e)
if ~isfolder(node); mkdir(node); end
name = "settings.xml";
if e > 1; name = "settings_" + e + ".xml"; end
fid = fopen(fullfile(node, name), 'w');
fprintf(fid, '<?xml version="1.0" encoding="UTF-8"?>\n<SETTINGS>\n  <INFO>\n    <VERSION>1.0.1</VERSION>\n  </INFO>\n</SETTINGS>\n');
fclose(fid);
end


function fid = npyOpen(file, descr)
%npyOpen  Start a 1-D .npy file whose length is written by npyClose.
fid = fopen(file, 'w+', 'ieee-le');
writeHeader(fid, descr, 0);
end


function npyClose(fid, n)
frewind(fid);
fread(fid, 10, 'uint8');                           % magic, version, header length
hdr = fread(fid, [1 64 - 10], '*char');
descr = regexp(hdr, '''descr'': ''([^'']+)''', 'tokens', 'once');
frewind(fid);
writeHeader(fid, descr{1}, n);
fclose(fid);
end


function writeHeader(fid, descr, n)
%writeHeader  A fixed 128-byte v1.0 header, so the length can be rewritten in place.
h = sprintf('{''descr'': ''%s'', ''fortran_order'': False, ''shape'': (%d,), }', descr, n);
h = [h repmat(' ', 1, 128 - 10 - numel(h) - 1) newline];
fwrite(fid, uint8([147 78 85 77 80 89 1 0]), 'uint8');
fwrite(fid, uint16(numel(h)), 'uint16');
fwrite(fid, h, 'char');
end


function t = localToUtc(t)
t.TimeZone = 'local';
t.TimeZone = 'UTC';
end
