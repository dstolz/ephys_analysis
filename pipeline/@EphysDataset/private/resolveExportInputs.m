function in = resolveExportInputs(obj, opts, who)
%resolveExportInputs  Shared input resolution for the export<Format> methods.
%   Turns the exporter options into concrete data:
%     in.S         toMat-shaped extract struct (Y, events, info)
%     in.signals   signals to export (present in in.S.Y)
%     in.units     readSortedUnits struct or []
%     in.detected  spikesToMat detected struct or []
%     in.events    dig-in events struct (or empty struct)
%     in.sources   provenance (extractFile, spikesFile, sortingDir)
%
%   opts fields: Extract, Signals, Units, Detected, Events, Groups.
%
%   Extract may be one file, several files (e.g. the per-signal-type files of
%   toMat(SeparateFiles=true), merged here: Y / info signals from every file,
%   everything else from the first) or a struct. The default "" is
%   <outputFolder>/<Name>_extract.mat, or when that does not exist the
%   <Name>_extract_<TYPE>.mat files that do.

in = struct('S', [], 'signals', string.empty(1,0), 'units', [], 'detected', [], ...
    'events', struct(), 'sources', struct());
src = struct('extractFile', "", 'spikesFile', "", 'sortingDir', "");

% --- extract (continuous signals) ------------------------------------------
ex = opts.Extract;
if isstruct(ex)
    S = ex;
elseif isstring(ex) || ischar(ex) || iscellstr(ex)
    f = string(ex);
    f = f(:).';
    if isscalar(f) && f == ""
        f = string(fullfile(obj.outputFolder(), obj.Name + "_extract.mat"));
        if ~isfile(f)
            perType = EphysDataset.signalFiles(f, ["LFP" "MUA" "SPIKE" "AUX"]);
            if any(isfile(perType))
                f = perType(isfile(perType));
            end
        end
    end
    missingFiles = f(~isfile(f));
    if isempty(f) || ~isempty(missingFiles)
        error(['EphysDataset:' who ':NoExtract'], ...
            ['No extract file %s. Run toMat (the Signals step) first, or pass ' ...
             'Extract=<file(s) or struct>.'], strjoin(missingFiles, ', '));
    end
    S = load(f(1));
    for k = 2:numel(f)
        S = mergeExtract(S, load(f(k)), f(k), who);
    end
    src.extractFile = strjoin(f, "; ");
else
    error(['EphysDataset:' who ':Extract'], 'Extract must be a file path or a toMat-shaped struct.');
end
if ~isstruct(S) || ~all(isfield(S, {'Y', 'info'}))
    error(['EphysDataset:' who ':Extract'], 'The extract has no Y / info variables.');
end
in.S = S;

present = string.empty(1, 0);
for sig = ["LFP" "MUA" "SPIKE" "AUX"]
    if isfield(S.Y, sig) && ~isempty(S.Y.(sig)) && isfield(S.info, sig)
        present(end+1) = sig; %#ok<AGROW>
    end
end
want = opts.Signals;
if isempty(want)
    in.signals = present;
else
    missing = setdiff(want, present);
    if ~isempty(missing)
        error(['EphysDataset:' who ':SignalMissing'], ...
            'The extract holds no %s signal (present: %s).', strjoin(missing, ', '), strjoin(present, ', '));
    end
    in.signals = want;
end

% --- events -------------------------------------------------------------------
if opts.Events && isfield(S, 'events') && isstruct(S.events)
    in.events = S.events;
end

% --- sorted units -----------------------------------------------------------
u = opts.Units;
if isstruct(u)
    in.units = u;
elseif islogical(u) && ~u
    in.units = [];
elseif isempty(u)
    if obj.hasKilosortResults()
        in.units = obj.readSortedUnits(Groups=opts.Groups);
        src.sortingDir = string(obj.sortingResultsDir());
    end
else
    error(['EphysDataset:' who ':Units'], 'Units must be a units struct, [] (auto) or false.');
end

% --- detected spikes ---------------------------------------------------------
d = opts.Detected;
if isstruct(d)
    in.detected = d;
elseif isstring(d) || ischar(d)
    f = string(d);
    if f ~= ""
        if ~isfile(f)
            error(['EphysDataset:' who ':NoSpikes'], 'No spikes file %s.', f);
        end
        M = load(f, 'detected');
        if isfield(M, 'detected') && ~isempty(M.detected)
            in.detected = M.detected;
            src.spikesFile = f;
        end
    end
elseif islogical(d) && d
    f = string(fullfile(obj.outputFolder(), obj.Name + "_spikes.mat"));
    if isfile(f)
        M = load(f, 'detected');
        if isfield(M, 'detected') && ~isempty(M.detected)
            in.detected = M.detected;
            src.spikesFile = f;
        end
    end
end

in.sources = src;
end


function S = mergeExtract(S, T, file, who)
%mergeExtract  Add the signals of extract T (loaded from FILE) to extract S.
if ~all(isfield(T, {'Y', 'info'}))
    error(['EphysDataset:' who ':Extract'], '%s has no Y / info variables.', file);
end
for sig = ["LFP" "MUA" "SPIKE" "AUX"]
    if isfield(T.Y, sig) && ~isempty(T.Y.(sig)) && isfield(T.info, sig)
        if isfield(S.Y, sig) && ~isempty(S.Y.(sig))
            error(['EphysDataset:' who ':Extract'], ...
                'Signal %s is present in more than one extract file (%s).', sig, file);
        end
        S.Y.(sig) = T.Y.(sig);
        S.info.(sig) = T.info.(sig);
    end
end
end
