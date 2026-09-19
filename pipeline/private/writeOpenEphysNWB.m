function W = writeOpenEphysNWB(session, meta)
%writeOpenEphysNWB  Streaming writer of an Open Ephys NWB 2 session (test data).
%   W = writeOpenEphysNWB(SESSION, META) writes, under SESSION/Record Node
%   <META.NodeId>, one experiment<E>.nwb per experiment laid out as the GUI's
%   NWB2 record engine writes it: /acquisition/<proc>-<id>.<stream> holds
%   data [channels x samples] int16 (MATLAB order), sync (sample numbers),
%   timestamps (attribute interval = 1/Fs), channel_conversion (bit volts /
%   1e6), channel_type (0 headstage, 1 AUX, 2 ADC) and electrodes; the
%   .TTL series holds data (+/- line), sync and full_word; sync_messages
%   holds "Software Time ..." (sync = ms since 1970 UTC) and "Start Time for
%   ..." (sync = first sample) for every recording; recordings of one
%   experiment are appended to the same datasets.
%   Handles as writeOpenEphysBinary: begin(E, R, FIRSTSAMPLE, START),
%   append(X, WORD, AUX, ADC), skip(n), finish().

meta = defaults(meta);
node = string(fullfile(session, "Record Node " + meta.NodeId));
if ~isfolder(node); mkdir(node); end
key = meta.ProcessorName + "-" + meta.ProcessorId + "." + meta.StreamName;
base = "/acquisition/" + key;
ttl = base + ".TTL";
sm = "/acquisition/sync_messages";
bitv = [repmat(meta.BitVolts, 1, meta.NumChannels), repmat(meta.AuxBitVolts, 1, meta.AuxCount), ...
    repmat(meta.AdcBitVolts, 1, meta.AdcCount)];
types = uint8([zeros(1, meta.NumChannels), ones(1, meta.AuxCount), 2 * ones(1, meta.AdcCount)]);
nAll = numel(bitv);
S = struct('file', "", 'pos', 0, 'evPos', 0, 'smPos', 0, 'next', 0, 'first', 0, 'lastWord', NaN, 'open', false);

W = struct('begin', @begin, 'append', @append, 'skip', @skip, 'finish', @finish, ...
    'nodeFolder', node, 'streamKey', key);

    function begin(e, r, firstSample, start)
        f = string(fullfile(node, "experiment" + e + ".nwb"));
        if r == 1 || S.file ~= f
            if isfile(f); delete(f); end
            S.file = f; S.pos = 0; S.evPos = 0; S.smPos = 0;
            h5create(f, base + "/data", [nAll Inf], 'Datatype', 'int16', 'ChunkSize', [nAll 1024]);
            h5create(f, base + "/sync", Inf, 'Datatype', 'int64', 'ChunkSize', 4096);
            h5create(f, base + "/timestamps", Inf, 'Datatype', 'double', 'ChunkSize', 4096);
            h5writeatt(f, base + "/timestamps", 'interval', single(1 / meta.Fs));
            h5create(f, base + "/channel_conversion", nAll, 'Datatype', 'single');
            h5write(f, base + "/channel_conversion", single(bitv(:) / 1e6));
            h5create(f, base + "/channel_type", nAll, 'Datatype', 'uint8');
            h5write(f, base + "/channel_type", types(:));
            h5create(f, base + "/electrodes", nAll, 'Datatype', 'int32');
            h5write(f, base + "/electrodes", int32((0:nAll-1).'));
            h5writeatt(f, base, 'neurodata_type', 'ElectricalSeries');
            h5create(f, ttl + "/data", Inf, 'Datatype', 'int8', 'ChunkSize', 8);
            h5create(f, ttl + "/sync", Inf, 'Datatype', 'int64', 'ChunkSize', 8);
            h5create(f, ttl + "/timestamps", Inf, 'Datatype', 'double', 'ChunkSize', 8);
            h5create(f, ttl + "/full_word", Inf, 'Datatype', 'uint64', 'ChunkSize', 8);
            h5writeatt(f, ttl, 'neurodata_type', 'TimeSeries');
            h5create(f, sm + "/data", Inf, 'Datatype', 'string', 'ChunkSize', 1);
            h5create(f, sm + "/sync", Inf, 'Datatype', 'int64', 'ChunkSize', 1);
            h5writeatt(f, sm, 'neurodata_type', 'AnnotationSeries');
            h5create(f, "/general/extracellular_ephys/electrodes/id", nAll, 'Datatype', 'int32');
            h5write(f, "/general/extracellular_ephys/electrodes/id", int32((0:nAll-1).'));
            h5create(f, "/general/extracellular_ephys/electrodes/group_name", nAll, 'Datatype', 'string');
            h5write(f, "/general/extracellular_ephys/electrodes/group_name", repmat(key, nAll, 1));
            iso = start; iso.TimeZone = 'local'; iso.Format = 'yyyy-MM-dd''T''HH:mm:ssxxx';
            h5create(f, "/session_start_time", 1, 'Datatype', 'string');
            h5write(f, "/session_start_time", string(iso));
        end
        S.first = firstSample; S.next = firstSample; S.lastWord = NaN; S.open = true;
        ms = round(posixtime(localToUtc(start)) * 1000);
        txt = ["Software Time (milliseconds since midnight Jan 1st 1970 UTC)"; ...
            sprintf("Start Time for %s (%d) - %s @ %d Hz", meta.ProcessorName, meta.ProcessorId, meta.StreamName, meta.Fs)];
        h5write(S.file, sm + "/data", txt, S.smPos + 1, 2);
        h5write(S.file, sm + "/sync", int64([ms; firstSample]), S.smPos + 1, 2);
        S.smPos = S.smPos + 2;
    end

    function append(X, word, aux, adc)
        n = size(X, 1);
        if nargin < 3 || isempty(aux); aux = zeros(n, meta.AuxCount); end
        if nargin < 4 || isempty(adc); adc = zeros(n, meta.AdcCount); end
        raw = int16(min(max(round([X, aux, adc] ./ bitv), -32768), 32767)).';
        h5write(S.file, base + "/data", raw, [1 S.pos + 1], [nAll n]);
        sn = S.next + (0:n-1).';
        h5write(S.file, base + "/sync", int64(sn), S.pos + 1, n);
        h5write(S.file, base + "/timestamps", double(sn - S.first) / meta.Fs, S.pos + 1, n);
        word = double(word(:));
        if isnan(S.lastWord); S.lastWord = word(1); end
        prev = [S.lastWord; word(1:end-1)];
        d = zeros(0, 1); s = zeros(0, 1); w = zeros(0, 1, 'uint64');
        for i = find(word ~= prev).'
            changed = bitxor(uint64(word(i)), uint64(prev(i)));
            for L = find(bitget(changed, 1:16))
                up = bitget(uint64(word(i)), L) == 1;
                d(end+1, 1) = L * (2 * up - 1); %#ok<AGROW>
                s(end+1, 1) = sn(i); %#ok<AGROW>
                w(end+1, 1) = uint64(word(i)); %#ok<AGROW>
            end
        end
        if ~isempty(d)
            k = numel(d);
            h5write(S.file, ttl + "/data", int8(d), S.evPos + 1, k);
            h5write(S.file, ttl + "/sync", int64(s), S.evPos + 1, k);
            h5write(S.file, ttl + "/timestamps", double(s - S.first) / meta.Fs, S.evPos + 1, k);
            h5write(S.file, ttl + "/full_word", w, S.evPos + 1, k);
            S.evPos = S.evPos + k;
        end
        S.lastWord = word(end);
        S.pos = S.pos + n;
        S.next = S.next + n;
    end

    function skip(n)
        S.next = S.next + n;
    end

    function finish()
        S.open = false;
    end
end


function meta = defaults(meta)
d = struct('Fs', 30000, 'NumChannels', 16, 'AuxCount', 3, 'AdcCount', 0, 'BitVolts', 0.195, ...
    'AuxBitVolts', 0.0000374, 'AdcBitVolts', 0.00015258789, 'NodeId', 101, ...
    'ProcessorName', "Acquisition Board", 'ProcessorId', 100, 'StreamName', "Rhythm Data");
for f = string(fieldnames(d)).'
    if ~isfield(meta, f); meta.(f) = d.(f); end
end
end


function t = localToUtc(t)
t.TimeZone = 'local';
t.TimeZone = 'UTC';
end
