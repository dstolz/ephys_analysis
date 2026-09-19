function ev = oeReadEvents(format, P, stream)
%oeReadEvents  TTL edges of one recording of a stream.
%   EV = oeReadEvents(FORMAT, P, STREAM) returns
%     sn           [k x 1] sample numbers (the stream's clock)
%     line         [k x 1] TTL line, 1-based (TTL1 = line 1)
%     state        [k x 1] 1 rising / 0 falling
%     fullWord     [k x 1] TTL word after each event (uint64; [] if not saved)
%     initialWord  TTL word when the recording started (NaN if unknown)
%   Binary: the stream's first TTL event channel (states / sample_numbers /
%   full_words.npy, initial_state from structure.oebin). Open Ephys format:
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
        catch
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
