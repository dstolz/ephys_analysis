function ev = oeReadEvents(format, P, stream)
%oeReadEvents  TTL edges of one recording of a stream.
%   EV = oeReadEvents(FORMAT, P, STREAM) returns
%     sn           [k x 1] sample numbers (the stream's clock)
%     line         [k x 1] TTL line, 1-based (TTL1 = line 1)
%     state        [k x 1] 1 rising / 0 falling
%     fullWord     [k x 1] TTL word after each event (uint64; [] if not saved)
%     initialWord  TTL word when the recording started (NaN if unknown)
%   Binary: the stream's first TTL event channel (states / sample_numbers /
%   full_words.npy, initial_state from structure.oebin); with P.eventsMapped
%   (EventStream) the TTL channel of another stream, its sample_numbers
%   replaced by the continuous stream's sample numbers at the events'
%   timestamps.npy times. Open Ephys format:
%   the 16-byte records of the stream's .events file (all_channels.events
%   before GUI 0.6) with event type 3 (TTL) and this recording's number.
%   NWB: the stream's .TTL TimeSeries (data = +/-line, sync, full_word),
%   restricted to this recording's sample numbers.

ev = struct('sn', zeros(0, 1), 'line', zeros(0, 1), 'state', zeros(0, 1), ...
    'fullWord', uint64([]), 'initialWord', NaN);
switch format
    case "binary"
        if isempty(P.eventDirs); return; end
        if numel(P.eventDirs) > 1
            warning('OpenEphysReader:TTLChannels', ...
                'Stream %s has %d TTL event channels; only %s is read.', stream.name, ...
                numel(P.eventDirs), P.eventDirs(1).name);
        end
        d = P.eventDirs(1);
        fs = fullfile(d.dir, "states.npy"); fn = fullfile(d.dir, "sample_numbers.npy");
        if ~isfile(fs) || ~isfile(fn); return; end
        st = double(readNPY(fs));
        sn = double(readNPY(fn));
        k = min(numel(st), numel(sn));
        if P.eventsMapped
            % The events belong to another stream (EventStream): their sample
            % numbers count that stream's clock, so their timestamps.npy
            % (seconds) are put on this stream's through its own timestamps.npy.
            sn = onStreamClock(d, P, stream, k);
        end
        ev.sn = sn(1:k); ev.line = abs(st(1:k)); ev.state = double(st(1:k) > 0);
        fw = fullfile(d.dir, "full_words.npy");
        if isfile(fw)
            w = readNPY(fw);
            if numel(w) >= k; ev.fullWord = uint64(w(1:k)); end
        end
        ev.initialWord = d.initialState;
    case "legacy"
        f = P.eventsFile;
        if f == "" || ~isfile(f); return; end
        fid = fopen(f, 'r', 'ieee-le');
        closer = onCleanup(@() fclose(fid));
        fseek(fid, 1024, 'bof');
        raw = fread(fid, [16, Inf], 'uint8=>uint8');
        if isempty(raw); return; end
        sn    = double(typecast(reshape(raw(1:8, :), [], 1), 'int64'));
        type  = double(raw(11, :)).';
        proc  = double(raw(12, :)).';
        state = double(raw(13, :)).';
        chan  = double(raw(14, :)).';
        rec   = double(typecast(reshape(raw(15:16, :), [], 1), 'uint16'));
        keep = type == 3 & rec == P.recNumber;
        if endsWith(f, "all_channels.events") || contains(f, "all_channels_")
            % GUI 0.4 / 0.5: one file for every processor (uint8 id).
            pid = mod(str2double(stream.processorId), 256);
            if isfinite(pid) && any(keep & proc == pid); keep = keep & proc == pid; end
        end
        ev.sn = sn(keep); ev.line = chan(keep) + 1; ev.state = double(state(keep) > 0);
    case "nwb"
        g = "/acquisition/" + stream.key + ".TTL";
        try
            data = double(h5read(P.file, g + "/data"));
            sn = double(h5read(P.file, g + "/sync"));
        catch ME
            if hasGroup(P.file, g)   % no TTL series at all is normal: no events
                warning('OpenEphysReader:UnreadableTTL', ...
                    '%s: cannot read the TTL series %s (%s); the recording gets no events from it.', ...
                    P.file, g, ME.message);
            end
            return
        end
        data = data(:); sn = sn(:);
        k = min(numel(data), numel(sn));
        data = data(1:k); sn = sn(1:k);
        lastSample = P.runs(end, 3) + (P.runs(end, 2) - P.runs(end, 1));
        in = sn >= P.firstSample & sn <= lastSample;
        ev.sn = sn(in); ev.line = abs(data(in)); ev.state = double(data(in) > 0);
        try
            w = h5read(P.file, g + "/full_word");
            w = uint64(w(:));
            if numel(w) >= k; ev.fullWord = w(in); end
        catch
        end
end
[ev.sn, order] = sort(ev.sn);
ev.line = ev.line(order); ev.state = ev.state(order);
if ~isempty(ev.fullWord); ev.fullWord = ev.fullWord(order); end
end


function sn = onStreamClock(d, P, stream, k)
%onStreamClock  Sample numbers of the stream's clock at the times of the first K events of folder D.
%   The events' timestamps.npy hold seconds on the session's synchronized
%   clock, and so does the stream's own timestamps.npy (P.clockFile) beside
%   its sample numbers. The stream's timestamp at the first row of each run
%   of stored samples (P.runs) fixes where that run lies on the clock, so
%   an event at time t is sample  firstSample(run) + round((t - t0(run))*Fs)
%   of the last run that starts at or before t (the first run for earlier
%   times). A time in a stretch of dropped samples gets a sample number
%   there, which oeIntervals places on the next stored row. The two clocks
%   must be synchronized (the GUI's main-stream sync): their timestamps are
%   taken to share a zero.
tf = fullfile(d.dir, "timestamps.npy");
if ~isfile(tf)
    error('OpenEphysReader:EventTimestamps', ...
        ['%s has no timestamps.npy, which puts the events of %s on the clock of the ' ...
         'continuous stream %s; they cannot be read with EventStream.'], d.dir, d.stream, stream.key);
end
if ~isfile(P.clockFile)
    error('OpenEphysReader:EventTimestamps', ...
        'Missing %s: the continuous stream %s has no timestamps to put the events of %s on its clock.', ...
        P.clockFile, stream.key, d.stream);
end
t = double(readNPY(tf));
if numel(t) < k
    error('OpenEphysReader:EventTimestamps', ...
        '%s holds %d timestamps for %d events.', tf, numel(t), k);
end
t = t(1:k);
H = OpenEphysReader.npyHeader(P.clockFile);
fid = fopen(P.clockFile, 'r', 'ieee-le');
if fid < 0; error('OpenEphysReader:Open', 'Cannot open %s', P.clockFile); end
closer = onCleanup(@() fclose(fid));
t0 = zeros(size(P.runs, 1), 1);
for r = 1:numel(t0)
    t0(r) = OpenEphysReader.npyAt(fid, H, P.runs(r, 1));
end
clear closer
j = ones(k, 1);
for r = 2:numel(t0)
    j(t >= t0(r)) = r;
end
sn = P.runs(j, 3) + round((t(:) - t0(j)) * stream.Fs);
end


function tf = hasGroup(file, g)
%hasGroup  True when the HDF5 file holds group G.
tf = true;
try
    h5info(file, g);
catch
    tf = false;   % h5info errors when the group is absent
end
end
