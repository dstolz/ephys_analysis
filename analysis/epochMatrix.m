function [R, T] = epochMatrix(source, S, opts)
%epochMatrix  Every dataset's units or channels around an event, in one matrix: data(row, time, group).
%   [R, T] = epochMatrix(RUNNER, S) computes, for each dataset of RUNNER (an
%   EphysAnalysisRunner that has found its datasets; or an
%   EphysAnalysisConfig, whose datasets are found first, as
%   populationAnalysis does), one part with the settings S
%   (epochMatrixSettings: a struct, [] for the defaults, or a settings
%   file), and assembles the parts into R. T is DatasetRuns.run's table:
%   key, name, status ("done", "cached", "skipped", "error"), message,
%   seconds. R = epochMatrix(PARTS, S, Info=) only assembles PARTS (below).
%
%   A part is one dataset's result. For spikes (S.data "units" or
%   "detected") it is the per-dataset loop of the OFC analysis script:
%     [st, u] = selectUnits(src, S.units, Ref=S.ref, Selection=S.selection)
%     [E, G]  = epochTable(src, S.ref, Window=S.window, Selection=S.selection)
%     P = spikePSTH(st, E, Window=[pre post], BinSec=S.binSec, Raster=false,
%           Meta=u, Groups=G, Check=, Measure=S.measure)
%     (measure "auroc": BaselineMode="auroc", Baseline=S.baseline,
%           Auroc=S.auroc instead of Measure)
%   with the rows from P.meta (Auroc.modulatedOnly may drop units). No
%   Baseline= is passed to epochTable, as in the script. For signals
%   (S.data "LFP", "MUA", "SPIKE" or "AUX"):
%     [Y, fs, meta] = selectChannels(src, S.data)   (AUX: Channels=S.signal.channels)
%     [E, G] = epochTable(src, S.ref, Window=S.window, Selection=S.selection)
%     P = evokedPotential(Y, fs, E, Window=[pre post], Channels=<the columns
%           whose meta.recordingChannel is in S.signal.channels and whose
%           meta.shank is in S.signal.shanks>, Groups=G, Meta=, Baseline=,
%           Detrend=, Rectify=, Magnitude=, Statistic=, Units=, Check=)
%   using P.mean, one row per channel (one row with signal.magnitude, the
%   channels' vector magnitude, e.g. AUX's accelerometer). Only the group
%   means are kept, and the epochs only with S.keepEpochs (Raster=true for
%   spikes, KeepEpochs=true for signals). signal.channels are recording
%   channels, as units.channels are (AUX: its columns); signal.shanks is
%   not used for AUX.
%   A part is a struct: values [time x row x group], t (column), labels
%   (one per group, column), groupValues (table: one row per group, one
%   column per groupBy parameter, the group's value; no columns without
%   groupBy), rows (table), nEpochs (per group), valueUnits, and with
%   S.keepEpochs epochs (struct: E, the epochs (epochTable's rows; for
%   signals only those evokedPotential kept, in data's order); spikes, one
%   per row, times and epoch from P.raster; data, signals' P.data as [row
%   x time x epoch]). With one
%   groupBy parameter a label is the group's bare value: a number (double)
%   for a numeric parameter, else its text ("<missing>" for a missing
%   value); with several, G.label ("Depth = 3, Level = 2"); without
%   groupBy, "all".
%
%   The parts are kept in a DatasetRuns (Runs=) under the name
%   "epochMatrix/" + S.data with the id of epochMatrixSettings and the
%   stamp of the dataset's outputs (StampFcn; default outputsStamp), so a
%   dataset is computed again only when the settings that apply to S.data
%   change (a change to an LFP option keeps the spike parts), when its
%   outputs change (a new sort, phy curation, a new spikes, signal,
%   behavior or manifest file), with Recompute, or when it is new. A
%   dataset with nothing to compute is "skipped" (the error ids of
%   populationAnalysis, plus selectChannels:NoSignal,
%   spikePSTH:NoneModulated and epochMatrix:NoChannels) and kept so until
%   its stamp changes; any other error leaves it out with the warning
%   DatasetRuns:DatasetFailed.
%
%   Assembly matches the script: the rows are stacked in dataset order
%   (the union of their columns; a column some datasets lack is missing,
%   NaN, NaT or <missing>, in their rows, and an integer column becomes
%   double); groups are matched across datasets and ordered by
%   S.selection.groupOrder ("ascending", "descending" reverses it,
%   "appearance": as first met, dataset by dataset):
%     one parameter    matched by label. Numbers stay numbers when every
%                      dataset's are (ascending: up, NaN last; NaN is one
%                      label); otherwise every label is text, string(value)
%                      for a number ("3", "0.5", "NaN"), so a dataset whose
%                      Depth is numeric and one whose Depth is text line up.
%                      Text sorts alphabetically, as selectTrials sorts a
%                      text parameter; with numbers and text mixed, the
%                      labels that read as numbers come first, by value.
%     several          matched by their values (groupValues), each
%                      parameter as above (numbers by value, text
%                      alphabetically), the first parameter first, as
%                      selectTrials orders a dataset's groups (Depth 9
%                      before Depth 10 ascending). The labels are text,
%                      "Depth = 9, Level = 2" (numbers "%.10g").
%   Session numbers each subject's datasets by date (below). Last, the
%   values are normalized as S.normalize asks (epochMatrixNormalize; none
%   by default): a change to it computes no dataset again.
%
%   R fields (size(R.data) = [height(R.rows), numel(R.t), numel(R.groupLabels)])
%     R.data         double [nRows x nTime x nGroups]
%                    The values: data(row, time, group). It holds the
%                    measure (rate, count or auROC) for spikes, and the
%                    group mean or median for signals. Wherever a row's
%                    dataset has no epochs in a group, the value is NaN.
%                    With settings.normalize.method other than "none" the
%                    values are normalized (R.raw holds them before).
%     R.rows         table, nRows rows
%                    One row per unit (spikes) or channel (signals), in
%                    data's first-dimension order. Columns for every kind:
%                    label, Dataset (key), Subject, Date (day), Session,
%                    Tags (";"-joined). Units add unitId, class ("su",
%                    "mua", "det", ...), channel, channelName, shank, x, y,
%                    nSpikes, and nSites/sites when merged. Channels add
%                    channel, shank, x, y, units. A column that some
%                    datasets lack is missing (missing/NaN) in their rows.
%     R.t            double column, nTime
%                    Times along data's second dimension, in s from the
%                    event. For spikes these are bin centers (auROC window
%                    centers for auroc); for signals, sample times.
%     R.groupLabels  column, nGroups
%                    Labels along data's third dimension, in
%                    settings.selection.groupOrder. Numeric when grouped by
%                    one parameter that is numeric in every dataset (e.g.
%                    Depth), otherwise string: the value's text for one
%                    parameter, "Depth = 3, Level = 2" for several.
%     R.rowKind      string
%                    "unit" or "channel".
%     R.valueUnits   string
%                    The unit of data: "spikes/s", "spikes/bin", "auROC",
%                    "uV" or "V"; normalized: "z", "%", "x baseline" or
%                    "0-1" ("subtract" keeps the unit). Use it for axis
%                    labels.
%     R.settings     struct
%                    The settings that made R (see the table above), e.g.
%                    R.settings.measure, R.settings.data,
%                    R.settings.window.pre.
%     R.datasets     table, one row per ticked dataset
%                    key, name, subject, date, status ("done", "cached",
%                    "skipped" or "error"), message, nRows, nEpochs,
%                    nGroups, seconds. This table answers "why is dataset
%                    X missing".
%     R.keys         string column
%                    The datasets whose rows are in R, in row order.
%     R.created      datetime
%                    When the result was assembled.
%     R.raw          double, the size of R.data, or []
%                    The values before normalization ([] when
%                    settings.normalize.method is "none").
%     R.normalization struct
%                    How R.data was normalized (epochMatrixNormalize):
%                    method, baseline, scope, rawUnits, center and scale
%                    (R.data = (R.raw - center) ./ scale), undefined
%                    (logical [nRows x nGroups]: NaN for a zero or flat
%                    baseline), nBaseline.
%     R.labels       struct
%                    Labels and a description in words (epochMatrixLabels):
%                    value (R.data's axis label), measure, time (R.t's),
%                    event, group, groups (one per group), rows, trials,
%                    window, bins, baseline, normalization, description.
%     R.epochs       struct column, one per dataset of R.keys, or []
%                    Each epoch before any average, with
%                    settings.keepEpochs ([] without). Fields: key, name,
%                    rows (its rows of R.rows and R.data), E (its epochs,
%                    epochTable's table, plus resultGroup: the epoch's
%                    group in R.groupLabels, data's third dimension),
%                    spikes and data. Spikes: spikes(k) for its k-th row
%                    holds times (s from the event, inside the window's
%                    whole bins) and epoch (each spike's row of E); data is
%                    []. Signals: data single [nRows x nTime x nEpochs],
%                    data(row, time, epoch) at R.t, each epoch after
%                    detrend, baseline, magnitude and rectify (what is
%                    averaged), E's rows in its third dimension's order
%                    (the epochs off the signal or not finite are left
%                    out); spikes is []. Never normalized.
%   Notes on the fields:
%     Subject and Date come from subjectAndDate: the subject from the
%     dataset's name (the project's name pattern); the date is the day
%     the recording started (the project's AcqDate) when that is known,
%     else the date in the name. DatasetBrowser's table gives the same
%     (both use one function with the same inputs).
%     Session is each subject's datasets numbered 1, 2, ... by date,
%     counting only the datasets that contribute rows (as the script
%     does): the rank of the dataset's date among them, so two datasets
%     of one day share a number. A NaT date gives NaN.
%     Group labels: NaN is treated as one label, and groups are matched
%     across datasets as described above.
%   ("The table above" is epochMatrixSettings' list of the fields of S.)
%
%   Options
%     Datasets     the datasets to use: keys, names or indices of the
%                  runner ([] = all of them)
%     Info         table: key, name, subject, date (datetime, the day),
%                  tags (";"-joined), one row per dataset; default: from
%                  the runner without loading a source (subject and date
%                  as described above, outputTags). Its rows give R.rows'
%                  Subject, Date and Tags
%     Runs         a DatasetRuns that keeps the parts (default: a new one,
%                  dropped afterwards). Pass one to reuse parts across
%                  calls; after a cancel it holds the parts finished
%     StampFcn     STAMP = StampFcn(key), the stamp of the dataset's
%                  outputs a kept part must match (DatasetRuns.run).
%                  Default: outputsStamp of the runner's DatasetOutputs
%                  (no file opened; one listing of the sorting folder per
%                  dataset, cached ones included). DatasetBrowser passes
%                  the stamps of its scan. @(key) "" ignores the outputs
%     Recompute    true: compute every dataset again (default false); the
%                  kept parts of the datasets are dropped first
%     ProgressFcn  ProgressFcn(fraction, message) before each dataset
%     CheckFcn     CheckFcn() before each dataset and between units (every
%                  16 epochs for signals); it may throw an error whose id
%                  ends in ":Canceled" to stop
%     LogFcn       LogFcn(message) per dataset (default: print; [] = quiet)
%     Workers      0 (default): the datasets one after the other, here;
%                  N >= 1: up to N at once on process workers
%                  (DatasetRuns.run's Workers; CheckFcn then stops between
%                  datasets, not inside one)
%
%   PARTS (assembly only) is a struct array or a cell array of part
%   structs; each may hold key (default "part<k>"); nEpochs, valueUnits and
%   groupValues are optional (without groupValues of two or more columns,
%   the groups are matched by label). Info (optional) names the keys'
%   datasets.
%
%   Errors: epochMatrix:NoData (no dataset gave rows; the message lists
%   why), epochMatrix:TimeBase (the datasets' t differ, e.g. different bins
%   or signal rates; named), epochMatrix:Canceled (the finished parts stay
%   in Runs), epochMatrix:UnknownDataset, epochMatrix:BadSource,
%   epochMatrix:BadPart, and epochMatrixSettings' (SeveralData: S.data
%   holds several kinds; compute each with epochMatrixSettings(S, Kind=K),
%   as DatasetBrowser does).
%
%   Example
%     cfg = EphysAnalysisConfig(); cfg.Source.Root = "D:\EPHYS";
%     r = EphysAnalysisRunner(cfg);
%     S = epochMatrixSettings(ref=eventRef(line="Stim"), window=epochWindow(pre=-1, post=1), ...
%         selection=trialSelection(response="Hit", groupBy="Depth", groupOrder="descending"), ...
%         data="detected", units=struct('shanks', 1:4, 'merge', struct('enabled', true)));
%     runs = DatasetRuns();
%     R = epochMatrix(r, S, Runs=runs);
%     imagesc(R.t, 1:height(R.rows), R.data(:, :, 1));
%
%   See also epochMatrixSettings, DatasetRuns, outputsStamp, spikePSTH,
%   evokedPotential, selectUnits, selectChannels, epochTable, selectTrials,
%   subjectAndDate, populationAnalysis.

arguments
    source
    S = []
    opts.Datasets = []
    opts.Info = []
    opts.Runs = []
    opts.Recompute (1,1) logical = false
    opts.ProgressFcn = []
    opts.CheckFcn = []
    opts.LogFcn = @(msg) fprintf('%s\n', msg)
    opts.StampFcn = []
    opts.Workers (1,1) double {mustBeInteger, mustBeNonnegative} = 0
end

[S, ID, partName] = epochMatrixSettings(S);

% --- assembly only --------------------------------------------------------------------------
if isstruct(source) || iscell(source)
    [values, keys] = asParts(source);
    info = completeInfo(opts.Info, keys);
    n = numel(keys);
    T = table(keys, info.name, repmat("done", n, 1), strings(n, 1), NaN(n, 1), ...
        'VariableNames', {'key', 'name', 'status', 'message', 'seconds'});
    R = assemble(values, T, info, S);
    return
end

% --- the datasets ---------------------------------------------------------------------------
if isa(source, 'EphysAnalysisRunner')
    runner = source;
elseif isa(source, 'EphysAnalysisConfig')
    runner = EphysAnalysisRunner(source, LogFcn=[]);
else
    error('epochMatrix:BadSource', 'Pass an EphysAnalysisRunner, an EphysAnalysisConfig or a list of parts.');
end
keys = datasetKeys(runner, opts.Datasets);
if isempty(opts.Info)
    info = datasetInfo(runner, keys);
else
    info = completeInfo(opts.Info, keys);
end
runs = opts.Runs;
if isempty(runs)
    runs = DatasetRuns();
elseif ~isa(runs, 'DatasetRuns')
    error('epochMatrix:BadSource', 'Runs must be a DatasetRuns.');
end

if isSpikes(S.data)
    fn = @(src, info, check) spikePart(src, S, check);
else
    fn = @(src, info, check) signalPart(src, S, check);
end
skipIds = ["selectUnits:NoUnits" "selectUnits:NoDetected" "selectUnits:NoneLeft" "epochTable:NoEpochs" ...
    "resolveEvents:NoEvents" "resolveEvents:NoLine" "responseStats:NoEpochs" ...
    "selectChannels:NoSignal" "spikePSTH:NoneModulated" "epochMatrix:NoChannels"];
stampFcn = opts.StampFcn;
if isempty(stampFcn); stampFcn = @(key) stampOf(runner, key); end
try
    [values, T] = runs.run(runner, keys, fn, Name=partName, Id=ID, Info=info, ...
        Recompute=opts.Recompute, ProgressFcn=opts.ProgressFcn, CheckFcn=opts.CheckFcn, LogFcn=opts.LogFcn, ...
        SkipIds=skipIds, StampFcn=stampFcn, Workers=opts.Workers);
catch ME
    if ME.identifier == "DatasetRuns:Canceled"
        C = MException('epochMatrix:Canceled', '%s', ME.message);
        C = C.addCause(ME);
        throw(C);
    end
    rethrow(ME);
end
R = assemble(values, T, info, S);
end


% ===== part builders ===========================================================================

function part = spikePart(src, S, check)
%spikePart  One dataset's spike histograms (the script's per-dataset loop).
[st, u] = selectUnits(src, S.units, Ref=S.ref, Selection=S.selection);
[E, G] = epochTable(src, S.ref, Window=S.window, Selection=S.selection);
args = {'Window', [S.window.pre S.window.post], 'BinSec', S.binSec, 'Raster', S.keepEpochs, 'Meta', u, 'Groups', G, 'Check', check};
if S.measure == "auroc"
    P = spikePSTH(st, E, args{:}, 'BaselineMode', "auroc", 'Baseline', S.baseline, 'Auroc', S.auroc);
else
    P = spikePSTH(st, E, args{:}, 'Measure', S.measure);
end
[labels, gv] = groupLabels(G, S.selection);
part = struct('values', P.rate, 't', P.t(:), 'labels', labels, 'groupValues', gv, 'rows', P.meta, ...
    'nEpochs', P.nEpochs(:), 'valueUnits', string(P.units));
if S.keepEpochs
    spikes = struct('times', {P.raster.times}, 'epoch', {P.raster.epoch});   % one per row; the epoch is a row of E
    part.epochs = struct('E', E, 'spikes', reshape(spikes, [], 1), 'data', []);
end
end


function part = signalPart(src, S, check)
%signalPart  One dataset's group means of a derived signal.
sig = S.signal;
if S.data == "AUX"
    [Y, fs, meta] = selectChannels(src, S.data, Channels=sig.channels);   % AUX's columns: it has no probe
    cols = 1:height(meta);
else
    [Y, fs, meta] = selectChannels(src, S.data);   % the cached signal, not a copy; evokedPotential takes the columns
    keep = true(height(meta), 1);
    if ~isempty(sig.channels); keep = keep & ismember(meta.recordingChannel, sig.channels); end
    if ~isempty(sig.shanks); keep = keep & ismember(meta.shank, sig.shanks); end
    cols = reshape(find(keep), 1, []);
    if isempty(cols)
        error('epochMatrix:NoChannels', '%s: no %s channel is among recording channel(s) %s on shank(s) %s.', ...
            src.name, S.data, listText(sig.channels), listText(sig.shanks));
    end
end
units = "uV";
if height(meta) > 0; units = string(meta.units(1)); end
[E, G] = epochTable(src, S.ref, Window=S.window, Selection=S.selection);
P = evokedPotential(Y, fs, E, Window=[S.window.pre S.window.post], Channels=cols, Groups=G, Meta=meta(cols, :), ...
    Baseline=sig.baseline, Detrend=sig.detrend, Rectify=sig.rectify, Magnitude=sig.magnitude, ...
    Statistic=sig.statistic, Units=units, Check=check, KeepEpochs=S.keepEpochs);
rows = meta(cols, :);
if sig.magnitude
    rows = table(P.labels, NaN, NaN, NaN, NaN, NaN, units, 'VariableNames', ...
        {'label', 'channel', 'recordingChannel', 'shank', 'x', 'y', 'units'});
end
[labels, gv] = groupLabels(G, S.selection);
part = struct('values', P.mean, 't', P.t(:), 'labels', labels, 'groupValues', gv, 'rows', rows, ...
    'nEpochs', P.nEpochs(:), 'valueUnits', units);
if S.keepEpochs
    % the epochs evokedPotential kept (it drops those off the signal or not finite), in P.data's order
    [~, k] = ismember(P.keptEpochs, E.epoch);
    part.epochs = struct('E', E(k, :), 'spikes', [], 'data', permute(P.data, [2 1 3]));   % (row, time, epoch)
end
end


function [labels, values] = groupLabels(G, sel)
%groupLabels  One label per group, and each group's value of every groupBy parameter (a table).
%   One parameter: its bare value, numeric (double) for a numeric
%   parameter, else text (<missing> as "<missing>"). Several: G's label
%   text (assembly orders and labels them again from VALUES). No groupBy:
%   G's label ("all").
p = reshape(string(sel.groupBy), 1, []);
nG = height(G);
if isempty(p) || ~all(ismember(p, string(G.Properties.VariableNames)))
    labels = reshape(string(G.label), [], 1);
    values = G(:, []);
    return
end
values = G(:, cellstr(p));
if isscalar(p)
    labels = asLabel(G.(p));
else
    labels = string(G.label);
end
labels = reshape(labels, [], 1);
end


function v = asLabel(v)
%asLabel  A group value as a label: numbers as double, anything else as text ("<missing>" for missing).
if iscell(v); v = string(v); end
if isnumeric(v) || islogical(v)
    v = double(v);
else
    v = asText(v);
end
end


function s = asText(v)
%asText  Values as text: numbers by string() (NaN as "NaN"), missing text as "<missing>".
if iscell(v); v = string(v); end
if isnumeric(v) || islogical(v)
    s = string(double(v));
    s(ismissing(s)) = "NaN";
else
    s = string(v);
    s(ismissing(s)) = "<missing>";
end
end


% ===== datasets and their info =================================================================

function keys = datasetKeys(runner, want)
%datasetKeys  The runner's keys of WANT (keys, names or indices; [] = all).
if isempty(want)
    keys = reshape(runner.Keys, [], 1);
    return
end
if ~isnumeric(want); want = string(want); end
keys = strings(numel(want), 1);
for j = 1:numel(want)
    k = runner.index(want(j));
    if k == 0
        error('epochMatrix:UnknownDataset', 'No dataset "%s".', string(want(j)));
    end
    keys(j) = runner.Keys(k);
end
end


function info = datasetInfo(runner, keys)
%datasetInfo  key, name, subject, date, tags of each dataset, without loading a source.
%   Subject and date come from runnerIdentity, as DatasetBrowser's table.
n = numel(keys);
idx = zeros(n, 1);
for j = 1:n; idx(j) = runner.index(keys(j)); end
names = reshape(runner.Names(idx), [], 1);
[subject, day] = runnerIdentity(runner, keys);
tags = strings(n, 1);
for j = 1:n
    tags(j) = TagSet.toText(outputTags(runner.Outputs(idx(j))), TagSet.ExportDelimiter);
end
info = table(keys, names, subject, day, tags, 'VariableNames', {'key', 'name', 'subject', 'date', 'tags'});
end


function s = stampOf(runner, key)
%stampOf  The default StampFcn: outputsStamp of the runner's outputs of KEY.
s = outputsStamp(runner.Outputs(runner.index(key)));
end


function d = toDay(day)
d = NaT(numel(day), 1);
has = day ~= "";
if any(has); d(has) = datetime(day(has), 'InputFormat', 'yyyy-MM-dd'); end
end


function info = completeInfo(info, keys)
%completeInfo  Info's rows for KEYS (in that order), every column present: key, name, subject, date, tags.
n = numel(keys);
out = table(keys, keys, strings(n, 1), NaT(n, 1), strings(n, 1), 'VariableNames', {'key', 'name', 'subject', 'date', 'tags'});
if isempty(info)
    info = out;
    return
end
if ~istable(info) || ~ismember("key", string(info.Properties.VariableNames))
    error('epochMatrix:BadSource', 'Info must be a table with a key column.');
end
have = string(info.Properties.VariableNames);
[tf, loc] = ismember(keys, string(info.key));
for c = ["name" "subject" "tags"]
    if ~ismember(c, have); continue; end
    v = string(info.(c));
    out.(c)(tf) = v(loc(tf));
end
if ismember("date", have)
    v = info.date;
    if ~isdatetime(v); v = toDay(string(v)); end
    out.date(tf) = dateshift(v(loc(tf)), 'start', 'day');
end
out.name(out.name == "" | ismissing(out.name)) = out.key(out.name == "" | ismissing(out.name));
for c = ["subject" "tags"]
    out.(c)(ismissing(out.(c))) = "";
end
info = out;
end


function [values, keys] = asParts(parts)
%asParts  PARTS (a struct array or a cell of structs) as a cell column, and their keys.
if isstruct(parts); parts = num2cell(parts); end
values = reshape(parts, [], 1);
n = numel(values);
keys = "part" + (1:n).';
for j = 1:n
    p = values{j};
    if ~(isstruct(p) && isscalar(p) && all(isfield(p, ["values" "t" "labels" "rows"])))
        error('epochMatrix:BadPart', 'Part %d must be a struct with values, t, labels and rows.', j);
    end
    if isfield(p, 'key') && string(p.key) ~= ""; keys(j) = string(p.key); end
end
end


% ===== assembly =================================================================================

function R = assemble(values, T, info, S)
%assemble  The parts as one matrix (see the help), with R.datasets from T and INFO.
n = height(T);
[tf, loc] = ismember(T.key, info.key);
D = table(T.key, T.name, strings(n, 1), NaT(n, 1), T.status, T.message, zeros(n, 1), zeros(n, 1), zeros(n, 1), T.seconds, ...
    'VariableNames', {'key', 'name', 'subject', 'date', 'status', 'message', 'nRows', 'nEpochs', 'nGroups', 'seconds'});
D.subject(tf) = info.subject(loc(tf));
D.date(tf) = info.date(loc(tf));
ok = false(n, 1);
for j = 1:n
    p = values{j};
    if ~isstruct(p) || isempty(p); continue; end
    checkPart(p, T.name(j));
    D.nRows(j) = height(p.rows);
    D.nGroups(j) = numel(p.labels);
    if isfield(p, 'nEpochs') && ~isempty(p.nEpochs); D.nEpochs(j) = sum(p.nEpochs); end
    ok(j) = height(p.rows) > 0;
end
if ~any(ok)
    why = compose("%s: %s", D.name, D.status);
    has = D.message ~= "";
    why(has) = why(has) + " (" + D.message(has) + ")";
    error('epochMatrix:NoData', 'No dataset gave rows to assemble:%s', sprintf('\n  %s', why));
end
use = find(ok).';

% one time base
t = values{use(1)}.t(:);
differ = strings(1, 0);
for j = use(2:end)
    tj = values{j}.t(:);
    if numel(tj) ~= numel(t) || max(abs(tj - t)) > 1e-9 * max(1, max(abs(t)))
        differ(end+1) = sprintf('%s (%d times, %g to %g s)', T.name(j), numel(tj), tj(1), tj(end)); %#ok<AGROW>
    end
end
if ~isempty(differ)
    error('epochMatrix:TimeBase', ['The datasets'' time bases differ (different bins or signal rates); ' ...
        'there is no resampling. %s has %d times, %g to %g s; these differ: %s.'], ...
        T.name(use(1)), numel(t), t(1), t(end), strjoin(differ, "; "));
end

% the groups: by their values of several groupBy parameters, else by label
gv = cellfun(@partValues, values(use), 'UniformOutput', false);
multi = cellfun(@(v) istable(v) && width(v) >= 2, gv);
if any(multi)
    if ~all(multi) || ~all(cellfun(@(v) isequal(v.Properties.VariableNames, gv{1}.Properties.VariableNames), gv))
        error('epochMatrix:BadPart', 'The parts are grouped by different parameters (groupValues): they cannot be matched.');
    end
    [groupLabels, cols] = unionGroups(gv, S.selection.groupOrder);
else
    labs = cellfun(@(p) reshape(p.labels, [], 1), values(use), 'UniformOutput', false);
    [groupLabels, cols] = unionLabels(labs, S.selection.groupOrder);
end

% the rows
tabs = cell(1, numel(use));
for i = 1:numel(use)
    j = use(i);
    U = values{j}.rows;
    m = height(U);
    r = find(info.key == T.key(j), 1);
    U.Dataset = repmat(T.key(j), m, 1);
    U.Subject = repmat(info.subject(r), m, 1);
    U.Date = repmat(info.date(r), m, 1);
    U.Tags = repmat(info.tags(r), m, 1);
    tabs{i} = U;
end
rows = stackRows(tabs);
rows.Session = sessionNumbers(rows.Subject, rows.Date);

data = NaN(height(rows), numel(t), numel(groupLabels));
row = 0;
epochs = [];
if S.keepEpochs
    epochs = struct('key', cell(numel(use), 1), 'name', [], 'rows', [], 'E', [], 'spikes', [], 'data', []);
end
for i = 1:numel(use)
    v = permute(values{use(i)}.values, [2 1 3]);   % (row, time, group)
    data(row + (1:size(v, 1)), :, cols{i}) = v;
    if S.keepEpochs
        epochs(i) = partEpochs(values{use(i)}, T.key(use(i)), T.name(use(i)), row + (1:size(v, 1)).', cols{i}); %#ok<AGROW> preallocated above
    end
    row = row + size(v, 1);
end

kind = "channel";
if isSpikes(S.data); kind = "unit"; end
vu = "";
if isfield(values{use(1)}, 'valueUnits'); vu = string(values{use(1)}.valueUnits); end

R = struct();
R.data = data;
R.rows = rows;
R.t = t;
R.groupLabels = groupLabels;
R.rowKind = kind;
R.valueUnits = vu;
R.settings = S;
R.datasets = D;
R.keys = unique(rows.Dataset, 'stable');
R.created = datetime('now');
R.raw = [];
R.normalization = [];
R.labels = [];
R.epochs = epochs;
R = epochMatrixNormalize(R);   % S.normalize; the labels
end


function e = partEpochs(p, key, name, rows, cols)
%partEpochs  One dataset's element of R.epochs: its rows of R, its epochs (E with resultGroup), spikes or data.
%   COLS maps the part's groups (E.groupIndex) to R.groupLabels. A part
%   without epochs (made with keepEpochs off, or given to assembly
%   without them) gives empty E, spikes and data.
e = struct('key', key, 'name', name, 'rows', rows, 'E', [], 'spikes', [], 'data', []);
if ~isfield(p, 'epochs') || isempty(p.epochs); return; end
E = p.epochs.E;
E.resultGroup = reshape(cols(E.groupIndex), [], 1);
e.E = E;
e.spikes = p.epochs.spikes;
e.data = p.epochs.data;
end


function checkPart(p, name)
%checkPart  values [numel(t) x height(rows) x numel(labels)]; groupValues one row per label.
sz = size(p.values, [1 2 3]);
want = [numel(p.t), height(p.rows), numel(p.labels)];
if ~isequal(sz, want) && ~(height(p.rows) == 0 && isempty(p.values))
    error('epochMatrix:BadPart', '%s: values is %s but t, rows and labels give %s.', name, mat2str(sz), mat2str(want));
end
gv = partValues(p);
if ~isempty(gv) && (~istable(gv) || height(gv) ~= numel(p.labels))
    error('epochMatrix:BadPart', '%s: groupValues must be a table with one row per label.', name);
end
end


function v = partValues(p)
%partValues  The part's groupValues table ([] when it has none).
v = [];
if isfield(p, 'groupValues'); v = p.groupValues; end
end


function [labels, cols] = unionLabels(labs, order)
%unionLabels  Every part's group labels, once each (NaN one label), in ORDER; COLS{i} each part's place in them.
%   Numbers stay numbers when every part's are; otherwise every label is
%   text (asText: string(value)). Text sorts alphabetically, as
%   selectTrials sorts a text parameter; when numbers and text are mixed,
%   the labels that read as numbers come first, by value (orderText).
isText = cellfun(@(x) isstring(x) || ischar(x) || iscellstr(x), labs);
anyText = any(isText);
mixed = anyText && ~all(isText);
if anyText
    labs = cellfun(@(x) reshape(asText(x), [], 1), labs, 'UniformOutput', false);
else
    labs = cellfun(@double, labs, 'UniformOutput', false);
end
pooled = vertcat(labs{:});
if anyText
    if order == "appearance"
        labels = unique(pooled, 'stable');
    elseif mixed
        labels = orderText(unique(pooled), order);
    else
        labels = unique(pooled);   % alphabetical
        if order == "descending"; labels = flipud(labels); end
    end
else
    isN = isnan(pooled);
    hasNaN = any(isN);
    if order == "appearance"
        labels = zeros(0, 1);
        seenNaN = false;
        for k = 1:numel(pooled)
            if isN(k)
                if ~seenNaN; labels(end+1, 1) = NaN; seenNaN = true; end %#ok<AGROW>
            elseif ~any(labels == pooled(k))
                labels(end+1, 1) = pooled(k); %#ok<AGROW>
            end
        end
    else
        u = unique(pooled(~isN));
        if order == "descending"
            labels = flipud(u(:));
            if hasNaN; labels = [NaN; labels]; end
        else
            labels = u(:);
            if hasNaN; labels = [labels; NaN]; end
        end
    end
end
cols = cell(size(labs));
for i = 1:numel(labs)
    x = labs{i};
    if anyText
        [~, c] = ismember(x, labels);
    else
        [~, c] = ismember(x, labels);
        c(isnan(x)) = find(isnan(labels), 1);
    end
    cols{i} = reshape(c, 1, []);
end
end


function s = orderText(s, order)
%orderText  Text labels: those that read as numbers first, by value, then the rest alphabetically; "descending" reverses.
x = str2double(s);
num = ~isnan(x) | lower(strtrim(s)) == "nan";
x(lower(strtrim(s)) == "nan") = Inf;   % NaN after the numbers, as selectTrials orders it
[~, i1] = sort(x(num));
a = s(num);
b = sort(s(~num));
s = [a(i1); b];
if order == "descending"; s = flipud(s); end
end


function [labels, cols] = unionGroups(vals, order)
%unionGroups  Groups of several parameters, matched across parts by their values and ordered as selectTrials orders them.
%   VALS{i} is part i's groupValues (one row per group, one column per
%   groupBy parameter). A parameter whose values are numbers in every
%   part is matched by value (NaN one value) and sorts by value, NaN
%   last; otherwise its values are text (asText) and sort alphabetically,
%   or, when numbers and text are mixed, those that read as numbers first
%   by value (orderText). The groups sort by the first parameter, then the
%   next, ...; "descending" reverses the whole order, "appearance" keeps
%   them as first met, part by part. LABELS is text, "Depth = 3, Level =
%   low" (numbers written "%.10g", as selectTrials' labels); COLS{i} each
%   part's groups' places in LABELS.
names = string(vals{1}.Properties.VariableNames);
nP = numel(names);
nPart = numel(vals);
heights = cellfun(@height, vals);
total = sum(heights);
pooled = cell(1, nP);
isNum = false(1, nP);
mixed = false(1, nP);
keyText = strings(total, nP);
for j = 1:nP
    numPart = cellfun(@(v) isnumeric(v.(names(j))) || islogical(v.(names(j))), vals);
    isNum(j) = all(numPart);
    mixed(j) = any(numPart) && ~isNum(j);
    col = cell(nPart, 1);
    for i = 1:nPart
        v = vals{i}.(names(j));
        if isNum(j)
            col{i} = reshape(double(v), [], 1);
        else
            col{i} = reshape(asText(v), [], 1);
        end
    end
    pooled{j} = vertcat(col{:});
    if isNum(j)
        keyText(:, j) = compose("%.17g", pooled{j});   % NaN gives "NaN": one value
    else
        keyText(:, j) = pooled{j};
    end
end
partOf = repelem((1:nPart).', heights(:));
[~, first, gIdx] = unique(join(keyText, char(31), 2), 'stable');
nG = numel(first);
ord = (1:nG).';
if order ~= "appearance"
    sk = zeros(nG, nP);
    for j = 1:nP
        v = pooled{j}(first);
        if isNum(j)
            s = v;
            s(isnan(s)) = Inf;
        elseif mixed(j)
            [~, s] = ismember(v, orderText(unique(v), "ascending"));
        else
            [~, ~, s] = unique(v);   % alphabetical rank
        end
        sk(:, j) = s;
    end
    [~, ord] = sortrows(sk);
    if order == "descending"; ord = flipud(ord); end
end
rank = zeros(nG, 1);
rank(ord) = 1:nG;
labels = strings(nG, 1);
for g = 1:nG
    r = first(ord(g));
    parts = strings(1, nP);
    for j = 1:nP
        if isNum(j)
            parts(j) = names(j) + " = " + compose("%.10g", pooled{j}(r));
        else
            parts(j) = names(j) + " = " + pooled{j}(r);
        end
    end
    labels(g) = strjoin(parts, ", ");
end
g = rank(gIdx);
cols = cell(1, nPart);
for i = 1:nPart
    cols{i} = reshape(g(partOf == i), 1, []);
end
end


function T = stackRows(tabs)
%stackRows  The tables one under the other: the union of their columns, missing where a table lacks one.
%   A column some tables lack, or that is integer in some and of another
%   class in others, is double in every table that holds it, so a NaN
%   fill or another table's NaN never turns into 0.
names = strings(1, 0);
for i = 1:numel(tabs)
    v = string(tabs{i}.Properties.VariableNames);
    names = [names, v(~ismember(v, names))]; %#ok<AGROW>
end
for c = names
    has = cellfun(@(U) ismember(c, string(U.Properties.VariableNames)), tabs);
    held = find(has);
    isInt = cellfun(@(U) isinteger(U.(c)), tabs(held));
    if any(isInt)
        cls = cellfun(@(U) string(class(U.(c))), tabs(held));
        if ~all(has) || ~all(cls == cls(1))   % NaN cannot fill an integer column, and vertcat keeps the integer class
            for i = held(isInt); tabs{i}.(c) = double(tabs{i}.(c)); end
        end
    end
    if all(has); continue; end
    tmpl = tabs{held(1)}.(c);
    for i = find(~has)
        tabs{i}.(c) = missingLike(tmpl(1:min(1, end), :), height(tabs{i}));
    end
end
for i = 1:numel(tabs)
    tabs{i} = tabs{i}(:, cellstr(names));
end
T = vertcat(tabs{:});
end


function f = missingLike(v, n)
%missingLike  N rows of "missing" in the class of column V.
w = max(1, size(v, 2));
if isnumeric(v) || islogical(v)
    f = NaN(n, w);
elseif isstring(v)
    f = strings(n, w);
    f(:) = missing;
elseif isdatetime(v)
    f = NaT(n, w);
elseif isduration(v)
    f = NaN(n, w) * seconds(1);
elseif iscategorical(v)
    f = categorical(NaN(n, w));
elseif iscell(v)
    f = cell(n, w);
else
    f = repmat(missing, n, w);
end
end


function s = sessionNumbers(subject, date)
%sessionNumbers  Per subject, 1, 2, ... for each recording day in order (NaN for NaT).
s = NaN(numel(subject), 1);
subject = string(subject);
subject(ismissing(subject)) = "";
for sub = unique(subject).'
    m = subject == sub & ~isnat(date);
    if ~any(m); continue; end
    [~, ~, r] = unique(date(m));
    s(m) = r;
end
end


function tf = isSpikes(d)
tf = ismember(d, ["units" "detected"]);
end


function s = listText(v)
%listText  A channel or shank list for a message: "(all)" when blank.
s = "(all)";
if ~isempty(v); s = mat2str(v); end
end
