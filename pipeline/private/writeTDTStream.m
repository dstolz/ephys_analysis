function W = writeTDTStream(action, W, varargin)
%writeTDTStream  Streaming writer of a TDT Synapse block (synthetic recordings).
%   W = writeTDTStream("open", [], FOLDER, META) creates FOLDER and starts
%   <META.Name>.tsq / .tev there (the file header and the block start mark).
%   W = writeTDTStream("append", W, X, WORD) appends samples:
%     X     [n x nChan] microvolts: stored as float32 volts in the stream
%           store META.StreamName, one TSQ header + TEV chunk per channel
%           and META.Npts samples (n must be whole chunks)
%     WORD  [n x 1] digital word: bit k-1 is line k, written as the strobe
%           epoc store META.LineStores{k} (onset at the first high sample,
%           offset, in the buddy store with "/" for the last character, at
%           the first low sample; value 1). A line high at the first sample
%           has its onset at 0; one still high at the end has no offset.
%   writeTDTStream("close", W) writes the stop mark and closes the files.
%   Headers are written in time order; a chunk's time is that of its first
%   sample, an epoc's that of its sample, on the block clock (TDT rounds
%   times to its 195312.5 Hz tick, so META.Fs should divide it).
%
%   META: Name, Fs, NumChannels, StartTime (seconds since 1970, UTC),
%   LineStores (cellstr, 4 characters each), StreamName ('Wav1'), Npts (256).
%
%   Plain MATLAB (no string or arguments syntax) so it also runs in Octave.

switch action
    case 'open'
        folder = varargin{1};
        meta = varargin{2};
        if ~isfield(meta, 'StreamName'); meta.StreamName = 'Wav1'; end
        if ~isfield(meta, 'Npts'); meta.Npts = 256; end
        if ~exist(folder, 'dir'); mkdir(folder); end
        base = fullfile(folder, char(meta.Name));
        W = struct();
        W.meta = meta;
        W.tsq = fopen([base '.tsq'], 'w', 'ieee-le');
        W.tev = fopen([base '.tev'], 'w', 'ieee-le');
        if W.tsq < 0 || W.tev < 0
            error('writeTDTStream:Open', 'Cannot create %s.tsq / .tev', base);
        end
        W.pos = 0;                                   % bytes written to the TEV
        W.row = 0;                                   % samples written
        W.state = false(1, numel(meta.LineStores));  % each line's last state
        W.streamCode = nameCode(meta.StreamName);
        W.onCode = zeros(1, numel(meta.LineStores));
        W.offCode = zeros(1, numel(meta.LineStores));
        W.onName = cell(1, numel(meta.LineStores));
        W.offName = cell(1, numel(meta.LineStores));
        for k = 1:numel(meta.LineStores)
            on = pad4(meta.LineStores{k});
            off = [on(1:3) '/'];
            W.onName{k} = on; W.offName{k} = off;
            W.onCode(k) = nameCode(on); W.offCode(k) = nameCode(off);
        end
        fwrite(W.tsq, zeros(10, 1, 'uint32'), 'uint32');
        fwrite(W.tsq, markWords(1, meta.StartTime), 'uint32');

    case 'append'
        X = varargin{1};
        word = varargin{2};
        m = W.meta;
        [n, nCh] = size(X);
        if nCh ~= m.NumChannels
            error('writeTDTStream:Channels', '%d channels given, the block has %d.', nCh, m.NumChannels);
        end
        if mod(n, m.Npts) ~= 0
            error('writeTDTStream:Chunks', '%d samples are not whole chunks of %d.', n, m.Npts);
        end
        nc = n / m.Npts;
        % stream chunks, chunk-major (all channels of chunk 1, then chunk 2, ...)
        D = reshape(permute(reshape(single(X * 1e-6), m.Npts, nc, nCh), [1 3 2]), m.Npts, nc * nCh);
        tc = reshape(repmat((W.row + (0:nc - 1) * m.Npts) / m.Fs, nCh, 1), 1, []);
        Hs = zeros(10, nc * nCh, 'uint32');
        Hs(1, :) = 10 + m.Npts;                      % float32: one word a sample
        Hs(2, :) = hex2dec('8101');
        Hs(3, :) = W.streamCode;
        Hs(4, :) = repmat(uint32(1:nCh), 1, nc);
        Hs(5:6, :) = reshape(typecast(double(m.StartTime + tc), 'uint32'), 2, []);
        Hs(7:8, :) = reshape(typecast(uint64(W.pos + (0:nc * nCh - 1) * 4 * m.Npts), 'uint32'), 2, []);
        Hs(10, :) = typecast(single(m.Fs), 'uint32');
        % epoc onsets / offsets from the word
        te = zeros(1, 0); He = zeros(10, 0, 'uint32');
        word = double(word(:));
        for k = 1:numel(W.onName)
            x = bitand(word, 2^(k - 1)) > 0;
            prev = [W.state(k); x(1:end - 1)];
            on = find(x & ~prev).';
            off = find(~x & prev).';
            te = [te, (W.row + on - 1) / m.Fs, (W.row + off - 1) / m.Fs]; %#ok<AGROW>
            He = [He, epocWords(numel(on), hex2dec('101'), W.onCode(k), W.offName{k}), ...
                epocWords(numel(off), hex2dec('102'), W.offCode(k), W.onName{k})]; %#ok<AGROW>
            if n > 0; W.state(k) = x(end); end
        end
        if ~isempty(te)
            He(5:6, :) = reshape(typecast(double(m.StartTime + te), 'uint32'), 2, []);
        end
        % time order; the chunks keep their order, so the TEV holds them as D
        [~, order] = sortrows([[tc te].' (1:numel(tc) + numel(te)).']);
        H = [Hs He];
        fwrite(W.tev, D(:), 'single');
        W.pos = W.pos + 4 * numel(D);
        fwrite(W.tsq, H(:, order), 'uint32');
        W.row = W.row + n;

    case 'close'
        fwrite(W.tsq, markWords(2, W.meta.StartTime + W.row / W.meta.Fs), 'uint32');
        fclose(W.tsq);
        fclose(W.tev);

    otherwise
        error('writeTDTStream:Action', 'Unknown action %s.', action);
end
end


function h = epocWords(n, type, code, buddy)
%epocWords  N epoc headers (times filled in by the caller), value 1.
h = zeros(10, n, 'uint32');
h(1, :) = 10; h(2, :) = type; h(3, :) = code;
h(4, :) = typecast(uint8(buddy), 'uint32');
h(7:8, :) = repmat(typecast(double(1), 'uint32').', 1, n);
h(9, :) = 4;
end


function w = markWords(code, t)
w = zeros(10, 1, 'uint32');
w(1) = 10; w(2) = hex2dec('8801'); w(3) = code;
w(5:6) = typecast(double(t), 'uint32');
end


function c = nameCode(name)
c = double(typecast(uint8(pad4(char(name))), 'uint32'));
end


function s = pad4(s)
s = [char(s) repmat(' ', 1, 4 - numel(char(s)))];
s = s(1:4);
end
