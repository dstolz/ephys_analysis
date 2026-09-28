function F = tdtSevFiles(folder)
%tdtSevFiles  The SEV files of a TDT block folder and their 40-byte headers.
%   F = tdtSevFiles(FOLDER) lists FOLDER/*.sev (not sub-folders; "._"
%   resource forks skipped) and returns a struct array, one element per
%   file, sorted by store, hour and channel:
%     file        full path          name      file name
%     store       store name (header, versions 3; the file name's store
%                 part otherwise, as SEV2mat takes it)
%     chan        channel number (header)       nChan  channels in the store (header)
%     hour        hour index of a split recording (the "-<H>h" suffix; 0 without)
%     version     header version (1-3; 0 = empty header)
%     fmt         'single' | 'int32' | 'int16' | 'int8' | 'double' | 'int64' |
%                 'rawpacked' | '' (unknown)
%     itemSize    bytes per sample      npts   whole samples in the file
%     partial     the data is not a whole number of samples
%     fs          2^(rate-12) * 25e6 / decimate (NaN for version 0)
%   and, from a store's RS4 log file (<Store>..._log.txt without a hyphen,
%   parsed as SEV2mat does), for the files of that store and hour:
%     startSample recording started at sample (1 without a log)
%     gaps        [k x 2] "last saved sample, new saved sample" pairs
%
%   Plain MATLAB (no string or arguments syntax) so it also runs in Octave.

formats = {'single', 'int32', 'int16', 'int8', 'double', 'int64', '', '', 'rawpacked'};
sizes   = [4 4 2 1 8 8 0 0 4];

proto = struct('file', '', 'name', '', 'store', '', 'chan', NaN, 'nChan', NaN, ...
    'hour', 0, 'version', NaN, 'fmt', '', 'itemSize', NaN, 'npts', 0, 'partial', false, ...
    'fs', NaN, 'startSample', 1, 'gaps', zeros(0, 2));
F = repmat(proto, 1, 0);
D = dir(fullfile(folder, '*.sev'));
D = D(~[D.isdir]);
D = D(~strncmp({D.name}, '._', 2));
if isempty(D); return; end

logs = readLogs(folder);

for i = 1:numel(D)
    f = proto;
    f.name = D(i).name;
    f.file = fullfile(folder, D(i).name);
    [~, stem] = fileparts(D(i).name);
    m = regexp(stem, '-[0-9]+h', 'match');
    if ~isempty(m); f.hour = str2double(m{end}(2:end - 1)); end
    m = regexp(stem, '_[Cc]h[0-9]*', 'match');
    if ~isempty(m); f.chan = str2double(m{end}(4:end)); end
    parts = regexp(stem, '_', 'split');
    parts = parts(~cellfun('isempty', parts));
    if numel(parts) > 1
        nm = [parts{end - 1} '____'];
        f.store = nm(1:4);
    else
        f.store = stem;
    end

    fid = fopen(f.file, 'r', 'ieee-le');
    if fid < 0
        error('TDTReader:Open', 'Cannot open %s', f.file);
    end
    fread(fid, 1, 'uint64=>double');                  % file size (bytes)
    fread(fid, 3, 'uint8=>char');                     % "SEV"
    f.version = fread(fid, 1, 'uint8=>double');
    hdrName = fread(fid, 4, 'uint8=>char').';
    chan = fread(fid, 1, 'uint16=>double');
    nChan = fread(fid, 1, 'uint16=>double');
    fread(fid, 1, 'uint16=>double');                  % sample width (bytes)
    fread(fid, 1, 'uint16=>double');                  % reserved
    dForm = fread(fid, 1, 'uint8=>double');
    decimate = fread(fid, 1, 'uint8=>double');
    rate = fread(fid, 1, 'uint16=>double');
    fclose(fid);
    if isempty(rate)
        error('TDTReader:BadSev', '%s is shorter than the 40-byte SEV header.', f.file);
    end
    if f.version >= 4
        error('TDTReader:BadSev', '%s has an unknown SEV header version %d.', f.file, f.version);
    end
    if f.version == 3
        f.store = hdrName;
    elseif ~(strcmp(f.store, hdrName) || strcmp(f.store, fliplr(hdrName)))
        f.store = hdrName;                            % SEV2mat: a file name far from the header's
    end
    f.store = deblank(strrep(f.store, char(0), ' '));
    if f.version > 0
        f.chan = chan;
        f.nChan = nChan;
        k = bitand(dForm, 15) + 1;
        if k <= numel(formats) && ~isempty(formats{k})
            f.fmt = formats{k};
            f.itemSize = sizes(k);
        end
        f.fs = 2^(rate - 12) * 25e6 / decimate;
    end
    if ~isnan(f.itemSize)
        dataBytes = D(i).bytes - 40;
        f.npts = floor(dataBytes / f.itemSize);
        f.partial = mod(dataBytes, f.itemSize) ~= 0;
    end
    for L = 1:numel(logs)
        if strcmp(logs(L).store, f.store) && logs(L).hour == f.hour
            f.startSample = logs(L).startSample;
            f.gaps = logs(L).gaps;
        end
    end
    F(end + 1) = f; %#ok<AGROW>
end
key = cell(1, numel(F));
for i = 1:numel(F)
    key{i} = sprintf('%s|%06d|%06d', F(i).store, F(i).hour, F(i).chan);
end
[~, order] = sort(key);
F = F(order);
end


function L = readLogs(folder)
%readLogs  RS4 log files: store, hour, start sample and gaps (as SEV2mat).
L = struct('store', {}, 'hour', {}, 'startSample', {}, 'gaps', {});
D = dir(fullfile(folder, '*log.txt'));
for i = 1:numel(D)
    if D(i).isdir || any(D(i).name == '-'); continue; end   % hour segments have a hyphen
    m = regexp(D(i).name, '^[^_|-]+(?=_|-)', 'match');
    if isempty(m); continue; end
    fid = fopen(fullfile(folder, D(i).name), 'r');
    if fid < 0; continue; end
    txt = fread(fid, Inf, 'uint8=>char').';
    fclose(fid);
    rec.store = m{1};
    rec.hour = 0;
    t = regexp(D(i).name, '-(\d)h', 'tokens');
    if ~isempty(t); rec.hour = str2double(t{1}{1}); end
    rec.startSample = 1;
    t = regexp(txt, 'recording started at sample: (\d*)', 'tokens');
    if ~isempty(t); rec.startSample = str2double(t{1}{1}); end
    rec.gaps = zeros(0, 2);
    t = regexp(txt, 'gap detected. last saved sample: (\d*), new saved sample: (\d*)', 'tokens');
    for j = 1:numel(t)
        rec.gaps(end + 1, :) = [str2double(t{j}{1}) str2double(t{j}{2})];
    end
    L(end + 1) = rec; %#ok<AGROW>
end
end
