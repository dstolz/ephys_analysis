function T = unitTable(units, opts)
%unitTable  One row per sorted unit: label, recording, location and notes.
%   T = unitTable(UNITS) turns sorted units into a table to filter, sort and
%   join across recordings:
%     T = unitTable(["D:\out\A_spikes.mat" "D:\out\B_spikes.mat"]);
%     su = T(T.class == "su" & T.subject == "1255", :);
%     deep = T(T.shank == 2 & T.y > 400, :);
%   UNITS is a units struct (EphysDataset.readSortedUnits / readPhyUnits), a
%   struct or cell array of them, or .mat file path(s) holding a "units"
%   variable (<Name>_spikes.mat, <Name>_chronux.mat). Entries without sorted
%   units (units = []) are skipped.
%
%   Columns
%     label           "su042_1255_260908T1039": class, unit id, subject,
%                     recording start (yyMMdd T HHmm)
%     class           "su" | "mua" | "noise" | "uns" | "other"
%     subject, recordingStart, datasetKey   the recording the unit came from
%     unitId          cluster id in the sort (spike_clusters.npy)
%     group           phy / Kilosort label ("good", "mua", ...)
%     channel         peak recording channel (1-based)
%     channelName     its native name, e.g. "A-012"
%     channelNumber   its hardware number (A-012 -> 12); the probe chanMap
%                     value is channel - 1
%     ksChannel       peak channel among the sorted channels
%     shank
%     peakX, peakY    site position of the peak channel (probe units, um)
%     x, y            template centre (amplitude-weighted site position)
%     notes           cluster_notes.tsv text (see EphysDataset.writeUnitNotes)
%     nSpikes, amplitude, contamPct, curated, fs, resultsDir
%     times           {spike times, s} (Times=true)
%
%   Options
%     Times         include the times column (default true)
%     RefreshNotes  re-read notes from cluster_notes.tsv in each unit's
%                   resultsDir when that folder is reachable, so notes typed
%                   after a file was saved show up (default true)
%
%   A unit is its datasetKey (resultsDir for units read without a dataset)
%   plus unitId: the same unit twice throws unitTable:DuplicateUnit. Two
%   units sharing a label (recordings of one subject starting in the same
%   minute, or units read without a dataset) warn unitTable:DuplicateLabel.
%
%   See also EphysDataset.readSortedUnits, EphysDataset.readPhyUnits,
%   EphysDataset.writeUnitNotes, EphysProject.unitIdentities.

arguments
    units
    opts.Times (1,1) logical = true
    opts.RefreshNotes (1,1) logical = true
end

list = collect(units, {});
parts = cell(numel(list) + 1, 1);
parts{1} = oneTable(struct('unitId', zeros(0, 1)), opts);   % typed empty table
for k = 1:numel(list)
    parts{k + 1} = oneTable(list{k}, opts);
end
T = vertcat(parts{:});

if opts.RefreshNotes
    for dir0 = unique(T.resultsDir(T.resultsDir ~= "")).'
        if ~isfolder(dir0); continue; end
        rows = find(T.resultsDir == dir0);
        [ids, notes] = EphysDataset.readUnitNotes(dir0);
        [tf, loc] = ismember(T.unitId(rows), ids);
        T.notes(rows) = "";
        T.notes(rows(tf)) = notes(loc(tf));
    end
end

owner = T.datasetKey;
owner(owner == "") = T.resultsDir(owner == "");
[~, first] = unique(owner + "|" + string(T.unitId), 'stable');
dup = setdiff(1:height(T), first);
if ~isempty(dup)
    error('unitTable:DuplicateUnit', ...
        ['Unit %d of %s appears more than once. Each recording''s units may be ' ...
         'passed only once (datasetKey "" means the units were read without a dataset).'], ...
        T.unitId(dup(1)), owner(dup(1)));
end
[~, first] = unique(T.label, 'stable');
dup = setdiff(1:height(T), first);
if ~isempty(dup)
    same = unique(T.label(dup));
    warning('unitTable:DuplicateLabel', ...
        ['%d unit label(s) are used by more than one unit (e.g. %s): two recordings of ' ...
         'one subject start in the same minute, or units were read without a dataset. ' ...
         'Use datasetKey + unitId to tell them apart.'], ...
        numel(same), strjoin(same(1:min(3, end)).', ", "));
end
end


function list = collect(x, list)
%collect  Flatten structs, cells and file paths into a cell of units structs.
if isempty(x)
    return
elseif iscell(x)
    for k = 1:numel(x)
        list = collect(x{k}, list);
    end
elseif isstring(x) || ischar(x)
    files = string(x);
    for f = files(:).'
        if ~isfile(f)
            error('unitTable:NoFile', 'File not found: %s', f);
        end
        vars = whos('-file', f);
        if ~ismember("units", string({vars.name}))
            error('unitTable:NoUnits', 'File %s has no "units" variable.', f);
        end
        S = load(f, 'units');
        list = collect(S.units, list);
    end
elseif isstruct(x)
    for k = 1:numel(x)
        if ~isfield(x(k), 'unitId')
            error('unitTable:BadInput', 'A units struct needs a unitId field (see EphysDataset.readPhyUnits).');
        end
        if ~isempty(x(k).unitId)
            list{end+1} = x(k); %#ok<AGROW>
        end
    end
else
    error('unitTable:BadInput', 'Pass units structs, a cell of them, or .mat file paths (got %s).', class(x));
end
end


function T = oneTable(u, opts)
%oneTable  Table rows for one units struct (missing fields become defaults).
n = numel(u.unitId);
    function v = col(name, default)
        if isfield(u, name) && numel(u.(name)) == n && ~ischar(u.(name))
            v = reshape(u.(name), n, 1);
        else
            v = repmat(default, n, 1);
        end
    end
    function v = perRun(name, default)
        v = default;
        if isfield(u, name) && ~isempty(u.(name)); v = u.(name); end
        v = repmat(v, n, 1);
    end
noTime = NaT('Format', 'yyyy-MM-dd HH:mm:ss');
T = table();
T.label          = string(col('label', ""));
T.class          = string(col('class', ""));
T.subject        = string(col('subject', ""));
T.recordingStart = col('recordingStart', noTime);
T.datasetKey     = string(col('datasetKey', ""));
T.unitId         = double(col('unitId', NaN));
T.group          = string(col('group', ""));
T.channel        = double(col('channel', NaN));
T.channelName    = string(col('channelName', ""));
T.channelNumber  = double(col('channelNumber', NaN));
T.ksChannel      = double(col('ksChannel', NaN));
T.shank          = double(col('shank', NaN));
T.peakX          = double(col('peakX', NaN));
T.peakY          = double(col('peakY', NaN));
T.x              = double(col('x', NaN));
T.y              = double(col('y', NaN));
T.notes          = string(col('notes', ""));
T.nSpikes        = double(col('nSpikes', NaN));
T.amplitude      = double(col('amplitude', NaN));
T.contamPct      = double(col('contamPct', NaN));
T.curated        = logical(perRun('curated', false));
T.fs             = double(perRun('fs', NaN));
T.resultsDir     = string(perRun('resultsDir', ""));
if opts.Times
    T.times = col('times', {zeros(0, 1)});
end
end
