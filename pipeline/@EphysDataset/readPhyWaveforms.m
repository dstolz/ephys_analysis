function [W, info] = readPhyWaveforms(resultsDir, samples, opts)
%readPhyWaveforms  Spike waveforms cut from the data a Kilosort4 / phy sort read.
%   W = EphysDataset.readPhyWaveforms(resultsDir, samples) cuts one window
%   per spike from the binary file the sort's params.py names (dat_path, the
%   .bin runKilosort wrote) and prepares it the way Kilosort4 saw the data
%   before whitening: the sorted channels (channel_map.npy), each window's
%   channel means removed, the median across the sorted channels subtracted
%   when Kilosort4 did (do_CAR in settings.json, on by default), and
%   Kilosort4's zero-phase high-pass (a 3rd-order Butterworth at
%   highpass_cutoff, 300 Hz by default). The waveforms are then comparable
%   with the templates EphysDataset.readPhyUnits returns: the same channels,
%   time axis and units.
%
%   SAMPLES are spike_times.npy values: 0-based samples of the recording,
%   such as units.samples{u} from readPhyUnits. Each window spans the
%   template's samples, SAMPLES - nt0min + (0:nt-1) (nt and nt0min from
%   settings.json, else templates.npy's length and Kilosort4's default
%   floor(20*nt/61)), so W(:, c, k) lines up with units.templateTimeMs and
%   with templateFull(:, c, u). Spikes whose window leaves the file are
%   skipped (INFO.skipped). The high-pass runs over each window plus 10 ms
%   on either side, which it settles within.
%
%   RESULTSDIR may be the folder holding params.py, or a dataset / kilosort4
%   run folder above it (see EphysDataset.resolvePhyDir). When the file
%   dat_path names is not there (the output folder moved), a file of the same
%   name in the results folder or one of its two parents is used.
%
%   Options
%   -------
%     Channels   sorted channels to return, 1-based as units.ksChannel and
%                the templates' channels (default all)
%     MaxSpikes  read at most this many spikes, picked at random from the
%                SAMPLES whose window fits the file, with a fixed seed, so
%                the same call gives the same spikes (default Inf = all)
%     Filter     apply the high-pass (default true)
%     DataFile   binary file to read instead of dat_path
%
%   W is [nt x nChannels x nSpikes], in INFO.units:
%     "uV"        bin_scale (the .bin's units per uV) is in settings.json
%                 (runKilosort writes it)
%     "bin"       the .bin's units (no bin_scale)
%     "whitened"  dat_path is Kilosort4's preprocessed copy (params.py
%                 hp_filtered = True, temp_wh.dat) and it has no usable
%                 whitening_mat_inv.npy; with one, that copy is unwhitened
%                 into "uV" / "bin" as the templates are. The copy is used
%                 as it is (already filtered and referenced)
%
%   INFO: samples (the spikes read, 0-based int64, in time order), skipped,
%   channels (sorted channels of W), binRows (their 1-based rows of the data
%   file), timeMs [1 x nt] (the templates' time axis), nt0min (W(nt0min+1,
%   :, k) is the spike's sample), units, dataFile, fs, highpassHz (NaN when
%   not filtered here), car (the median was subtracted here).
%
%   Error identifiers: EphysDataset:readPhyWaveforms:NoResultsDir,
%   :NoParams, :BadParams, :NoDataFile, :BadChannels.
%
%   See also EphysDataset.readPhyUnits, EphysDataset.readSortedUnits,
%   EphysDataset.runKilosort.

arguments
    resultsDir (1,1) string
    samples {mustBeNumeric}
    opts.Channels (1,:) double = []
    opts.MaxSpikes (1,1) double {mustBePositive} = Inf
    opts.Filter (1,1) logical = true
    opts.DataFile (1,1) string = ""
end

dir0 = EphysDataset.resolvePhyDir(resultsDir);
if ~isfolder(dir0)
    error('EphysDataset:readPhyWaveforms:NoResultsDir', 'Not a folder: %s', resultsDir);
end
P = readParams(dir0);
S = readJsonFile(fullfile(dir0, 'settings.json'), ErrorOnFail=false);
if ~isstruct(S); S = struct(); end
fs = P.fs;
if ~isfinite(fs) && isNumber(S, 'fs'); fs = double(S.fs); end
if ~isfinite(fs)
    error('EphysDataset:readPhyWaveforms:BadParams', 'No sample_rate in %s.', fullfile(dir0, 'params.py'));
end

% --- window: the templates' samples -----------------------------------------
nt = 61;
if isNumber(S, 'nt')
    nt = double(S.nt);
elseif isfile(fullfile(dir0, 'templates.npy'))
    [~, shp] = readNPY(fullfile(dir0, 'templates.npy'), Range=[1 0]);
    if numel(shp) >= 2; nt = shp(2); end
end
nt0min = floor(20 * nt / 61);
if isNumber(S, 'nt0min'); nt0min = double(S.nt0min); end

% --- channels ------------------------------------------------------------------
binRowsAll = (1:P.nChan).';
cm = fullfile(dir0, 'channel_map.npy');
if isfile(cm); binRowsAll = double(reshape(readNPY(cm), [], 1)) + 1; end
nSorted = numel(binRowsAll);
chans = opts.Channels(:);
if isempty(chans); chans = (1:nSorted).'; end
if any(chans < 1 | chans > nSorted | chans ~= round(chans)) || any(binRowsAll > P.nChan)
    error('EphysDataset:readPhyWaveforms:BadChannels', ...
        'Channels must be sorted channels 1..%d of the %d-channel data file.', nSorted, P.nChan);
end

% --- the data file and how its values become the templates' units -----------------
dataFile = resolveDataFile(dir0, P.datPath, opts.DataFile);
nFile = floor((fileBytes(dataFile) - P.offset) / (P.nChan * P.bytes));
if P.hpFiltered
    % Kilosort4's copy: its whitened data x 200, as int16.
    [M, units] = templateConversion(dir0, nSorted);
    scale = 1 / 200;
    doFilter = false;
    car = false;
else
    M = [];
    units = "bin";
    scale = 1;
    if isNumber(S, 'bin_scale') && S.bin_scale ~= 0
        scale = 1 / double(S.bin_scale);
        units = "uV";
    end
    doFilter = opts.Filter;
    car = ~(isfield(S, 'do_CAR') && isequal(S.do_CAR, false));
end
hp = 300;
if isNumber(S, 'highpass_cutoff') && S.highpass_cutoff > 0; hp = double(S.highpass_cutoff); end
pad = 0;
if doFilter
    [z, p, k] = butter(3, hp / (fs / 2), 'high');
    [sos, g] = zp2sos(z, p, k);
    pad = ceil(0.010 * fs);
else
    hp = NaN;
end

% --- which spikes -------------------------------------------------------------------
s = sort(int64(samples(:)));
first = double(s) - nt0min;                  % 0-based first sample of each window
ok = first >= 0 & first + nt <= nFile;
skipped = nnz(~ok);
s = s(ok);
first = first(ok);
if numel(s) > opts.MaxSpikes
    pick = sort(randperm(RandStream('mt19937ar', 'Seed', 0), numel(s), floor(opts.MaxSpikes)));
    s = s(pick);
    first = first(pick);
end

% --- read ------------------------------------------------------------------------------
nK = numel(s);
W = zeros(nt, numel(chans), nK);
if nK > 0
    fid = fopen(dataFile, 'r', 'ieee-le');
    if fid < 0
        error('EphysDataset:readPhyWaveforms:NoDataFile', 'Cannot open %s.', dataFile);
    end
    closer = onCleanup(@() fclose(fid));
    prec = char(P.precision + "=>double");
    L = nt + 2 * pad;
    for kk = 1:nK
        a = first(kk) - pad;                 % the padded window, 0-based [a, a+L)
        a0 = max(a, 0);
        b0 = min(a + L, nFile);
        fseek(fid, P.offset + a0 * P.nChan * P.bytes, 'bof');
        X = fread(fid, [P.nChan, b0 - a0], prec);
        X = X(binRowsAll, :).' * scale;      % [samples x sorted channels]
        X = [repmat(X(1, :), a0 - a, 1); X; repmat(X(end, :), a + L - b0, 1)]; %#ok<AGROW>
        if isempty(M)
            if ~P.hpFiltered
                X = X - mean(X, 1);
                if car; X = X - median(X, 2); end
            end
        else
            X = X * M;
        end
        X = X(:, chans);
        if doFilter; X = filtfilt(sos, g, X); end
        W(:, :, kk) = X(pad + 1:pad + nt, :);
    end
end

info = struct();
info.samples    = s;
info.skipped    = skipped;
info.channels   = chans.';
info.binRows    = binRowsAll(chans).';
info.timeMs     = (0:nt-1) / fs * 1000;
info.nt0min     = nt0min;
info.units      = units;
info.dataFile   = string(dataFile);
info.fs         = fs;
info.highpassHz = hp;
info.car        = car && ~P.hpFiltered;
end


%% ---------------------------------------------------------------------------
function P = readParams(dir0)
%readParams  dat_path, n_channels_dat, dtype, offset, sample_rate, hp_filtered.
f = fullfile(dir0, 'params.py');
if ~isfile(f)
    error('EphysDataset:readPhyWaveforms:NoParams', 'No params.py in %s.', dir0);
end
lines = strtrim(splitlines(string(fileread(f))));
lines = lines(~startsWith(lines, "#"));
P = struct();
P.datPath = quotedStrings(value(lines, "dat_path"));
P.nChan = str2double(value(lines, "n_channels_dat"));
P.offset = str2double(value(lines, "offset"));
if isnan(P.offset); P.offset = 0; end
P.fs = str2double(value(lines, "sample_rate"));
P.hpFiltered = strcmpi(value(lines, "hp_filtered"), "True");
dtype = quotedStrings(value(lines, "dtype"));
if isempty(dtype); dtype = "int16"; end
switch lower(dtype(1))
    case {"int16", "uint16", "int32", "uint32", "int8", "uint8"}
        P.precision = lower(dtype(1));
        P.bytes = str2double(extractAfter(P.precision, "int")) / 8;
    case "float32"; P.precision = "single"; P.bytes = 4;
    case "float64"; P.precision = "double"; P.bytes = 8;
    otherwise
        error('EphysDataset:readPhyWaveforms:BadParams', 'Unsupported dtype %s in %s.', dtype(1), f);
end
if ~(P.nChan >= 1 && P.nChan == round(P.nChan))
    error('EphysDataset:readPhyWaveforms:BadParams', 'No n_channels_dat in %s.', f);
end
end


function v = value(lines, key)
%value  The text after "KEY =" on its line of params.py ("" when absent).
v = "";
tok = regexp(lines, "^" + key + "\s*=\s*(.*)$", 'tokens', 'once');
hit = find(~cellfun(@isempty, tok), 1);
if ~isempty(hit); v = strtrim(string(tok{hit}{1})); end
end


function s = quotedStrings(v)
%quotedStrings  The Python string literals in V: 'a', "a", r'a' or a list of them.
s = strings(1, 0);
tok = regexp(v, '(r?)([''"])(.*?)\2', 'tokens');
for k = 1:numel(tok)
    t = string(tok{k}{3});
    if tok{k}{1} == ""; t = replace(t, "\\", "\"); end
    s(end+1) = t; %#ok<AGROW>
end
end


function f = resolveDataFile(dir0, datPath, override)
%resolveDataFile  The binary to read: DataFile, dat_path, else its name nearby.
if override ~= ""
    if ~isfile(override)
        error('EphysDataset:readPhyWaveforms:NoDataFile', 'DataFile not found: %s', override);
    end
    f = char(override);
    return
end
if isempty(datPath) || datPath(1) == "no_path.bin"
    error('EphysDataset:readPhyWaveforms:NoDataFile', ...
        'params.py in %s names no data file (dat_path).', dir0);
end
if numel(datPath) > 1
    error('EphysDataset:readPhyWaveforms:NoDataFile', ...
        'params.py in %s names %d data files; pass DataFile.', dir0, numel(datPath));
end
p = datPath(1);
if isempty(regexp(p, '^([A-Za-z]:|[\\/])', 'once'))
    p = string(fullfile(dir0, p));
end
[~, nm, ext] = fileparts(p);
up1 = fileparts(dir0);
tried = [p, string(fullfile(dir0, nm + ext)), string(fullfile(up1, nm + ext)), ...
    string(fullfile(fileparts(up1), nm + ext))];
hit = find(arrayfun(@isfile, tried), 1);
if isempty(hit)
    error('EphysDataset:readPhyWaveforms:NoDataFile', ...
        'The sorted data file is not there: %s (also looked for %s in the results folder and the two above it).', ...
        datPath(1), nm + ext);
end
f = char(tried(hit));
end


function n = fileBytes(f)
d = dir(f);
n = d.bytes;
end


function tf = isNumber(S, name)
%isNumber  S.(NAME) is a finite numeric scalar.
tf = isfield(S, name) && isnumeric(S.(name)) && isscalar(S.(name)) && isfinite(S.(name));
end
