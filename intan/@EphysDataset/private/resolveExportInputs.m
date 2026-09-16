function in = resolveExportInputs(obj, opts, who)
%resolveExportInputs  Shared input resolution for exportChronux / exportFieldTrip.
%   Turns the exporter options into concrete data:
%     in.S         toMat-shaped extract struct (Y, events, info, [behavior])
%     in.signals   signals to export (present in in.S.Y)
%     in.units     readSortedUnits struct or []
%     in.detected  spikesToMat detected struct or []
%     in.events    dig-in events struct (or empty struct)
%     in.behavior  behavior struct or []
%     in.sources   provenance (extractFile, spikesFile, sortingDir, behaviorFile)
%
%   opts fields: Extract, Signals, Units, Detected, Events, Behavior, Groups.

in = struct('S', [], 'signals', string.empty(1,0), 'units', [], 'detected', [], ...
    'events', struct(), 'behavior', [], 'sources', struct());
src = struct('extractFile', "", 'spikesFile', "", 'sortingDir', "", 'behaviorFile', "");

% --- extract (continuous signals) ------------------------------------------
ex = opts.Extract;
if isstruct(ex)
    S = ex;
elseif isstring(ex) || ischar(ex)
    f = string(ex);
    if f == ""
        f = string(fullfile(obj.outputFolder(), obj.Name + "_extract.mat"));
    end
    if ~isfile(f)
        error(['EphysDataset:' who ':NoExtract'], ...
            ['No extract file %s. Run toMat (the Signals step) first, or pass ' ...
             'Extract=<file or struct>.'], f);
    end
    S = load(f);
    src.extractFile = f;
else
    error(['EphysDataset:' who ':Extract'], 'Extract must be a file path or a toMat-shaped struct.');
end
if ~isstruct(S) || ~all(isfield(S, {'Y', 'info'}))
    error(['EphysDataset:' who ':Extract'], 'The extract has no Y / info variables.');
end
in.S = S;

present = string.empty(1, 0);
for sig = ["LFP" "MUA" "SPIKE"]
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

% --- behavior ----------------------------------------------------------------
b = opts.Behavior;
if isstruct(b)
    in.behavior = b;
elseif islogical(b) && ~b
    in.behavior = [];
elseif isfield(S, 'behavior') && isstruct(S.behavior) && ~isempty(S.behavior)
    in.behavior = S.behavior;
else
    in.behavior = obj.behaviorStruct();
    if ~isempty(in.behavior); src.behaviorFile = obj.BehaviorFile; end
end

in.sources = src;
end
