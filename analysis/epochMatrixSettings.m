function [S, ID, name] = epochMatrixSettings(S0, opts)
%epochMatrixSettings  The settings of epochMatrix: defaults, overlay, checks, and the cache identity.
%   S = epochMatrixSettings() gives the default settings; S =
%   epochMatrixSettings(S0, Name=Value) overlays the struct S0 (or [], the
%   defaults; or the path of a settings file, below) on the defaults, then
%   the options, and checks the result. A struct option (ref, window,
%   selection, units, signal, auroc) is merged field by field over the
%   value it replaces, so units=struct('shanks', 1:2) keeps the other unit
%   fields; any other option replaces its field. [S, ID] = ... also gives
%   the cache identity (below), and [S, ID, NAME] = ... the DatasetRuns
%   name epochMatrix keeps the parts under: "epochMatrix/" + data, with
%   "/epochs" added when keepEpochs is on (such parts hold the epochs, so
%   they are kept apart from those without). ID and NAME are those of one
%   kind of data: with several kinds in data, ask for each with Kind=.
%
%   [S, ID, NAME] = epochMatrixSettings(S0, Kind=K) gives the settings of
%   kind K of S0's data alone (data = K; units.source = K for spikes), its
%   ID and NAME: what epochMatrix computes for K. Among other kinds, AUX
%   (no probe) takes all its columns: signal.channels and signal.shanks
%   are the probe's pick then, so K = "AUX" clears them; and
%   signal.magnitude is AUX's, so a probe signal K clears it when AUX is
%   in data.
%
%   Fields of S, in this order
%     data       what is computed, one kind or several (a string row, each
%                kind once, in the order given; epochMatrix computes one
%                at a time: Kind=): "units" (default; the sorted units of
%                the sorting folder) | "detected" (the Spikes step's
%                threshold detections, one train per channel) | "LFP" |
%                "MUA" | "SPIKE" | "AUX" (a derived signal). The fields
%                of every kind in data are checked
%     ref        eventRef: the event each epoch is aligned to
%     window     epochWindow; its mode must be "fixed" (default [-1 1] s)
%     selection  trialSelection: the trials kept and their groups
%   Spikes (data "units" or "detected")
%     units      UnitSelection (selectUnits): its source is set from data;
%                classes defaults to empty, meaning every class (not
%                UnitSelection's ["su" "mua"])
%     measure    "rate" (default; spikes/s) | "count" (spikes per bin per
%                epoch) | "auroc" (each auROC window against the baseline)
%     binSec     the bin width, s (default 0.01); at least one whole bin,
%                edged at the event, must fit in [pre post] (spikePSTH)
%     baseline   [b0 b1] s from the event: the auROC's baseline (default
%                [-0.5 0]; b0 < b1 with measure "auroc")
%     auroc      the Auroc section (aurocCurves' settings), with cutoff
%                "none" by default
%   Signals (data "LFP", "MUA", "SPIKE" or "AUX")
%     signal     struct:
%                  channels   recording channels kept, 1-based (the probe
%                             map's chanMap + 1, as units.channels; AUX:
%                             its 1-based columns) ([] = all)
%                  shanks     probe shanks kept ([] = all; selectChannels'
%                             meta.shank, the probe map's kcoords; not used
%                             for AUX)
%                  baseline   [b0 b1] s: each epoch's mean over it is
%                             subtracted, per channel ([] = none)
%                  detrend    remove each epoch's linear trend (false)
%                  rectify    the absolute value before the average (false)
%                  magnitude  the channels' vector magnitude, one row
%                             (AUX's accelerometer; false)
%                  statistic  "mean" (default) | "median" over the epochs
%   Every kind
%     normalize  struct, applied to the assembled matrix (epochMatrixNormalize),
%                each row's trace in each group against its own values:
%                  method    "none" (default) | "subtract" (x - b) |
%                            "ratio" (x / b) | "percent" (100 (x - b) / |b|)
%                            | "zscore" ((x - b) / SD) | "minmax" ((x -
%                            min) / (max - min), 0 to 1 over the window).
%                            b and SD are the mean and SD of the trace's
%                            values at the times of R.t in baseline (the
%                            bins of the mean trace, not the epochs). Not
%                            applied to measure "auroc"
%                  baseline  [b0 b1] s from the event (default [-0.5 0]);
%                            must overlap the window for a method that
%                            uses it
%                  scope     "row" (default): one baseline (or range) per
%                            row, from all its groups, so the groups keep
%                            their differences | "group": each group its own
%     keepEpochs false (default); true: the result keeps each epoch, before
%                any average (epochMatrix's R.epochs): spikes, every spike's
%                time from the event and its epoch; signals, every epoch's
%                trace [row x time x epoch], single. Signal epochs are large
%                (they go into the result file's kept parts)
%   Fields that do not apply to data are kept in S, unchecked beyond their
%   form, and left out of ID, so a change to an LFP option keeps the
%   cached spike results. normalize is left out of ID too: it is applied
%   after the parts are assembled, so a change to it computes nothing again.
%
%   ID is the cache identity of the results S gives: a struct holding data,
%   ref, window, selection, the fields that apply to data (spikes: units,
%   measure, binSec, baseline, auroc; signals: signal), keepEpochs (only
%   when true, so the identity without it is unchanged) and version,
%   epochMatrixSettings' version of the part builders (see below).
%   DatasetRuns.idText(ID) is its text, which is the same after a JSON
%   round trip and for row or column vectors.
%
%   Settings files are JSON: {"schema": "epoch-matrix-settings",
%   "version": 1, "settings": {...}}, with non-finite numbers written as
%   the strings "Inf", "-Inf" and "NaN". Other top-level fields (DatasetBrowser
%   writes "definitions" beside "settings") are left alone.
%
%   Options
%     data, ref, window, selection, units, signal, measure, binSec,
%     baseline, auroc, normalize, keepEpochs   the fields above
%     Kind       one kind of data: S, ID and NAME of that kind alone (above)
%     SaveAs     a .json file: write the checked settings returned there
%
%   Errors: epochMatrixSettings:UnknownField (a field S has no place for, at
%   the top or inside units, signal, auroc or normalize; ref, window and
%   selection raise theirs as this too), epochMatrixSettings:BadValue (any
%   value that does not fit, a Kind not in data, or a file that is not a
%   settings file), epochMatrixSettings:SeveralData (ID or NAME asked for
%   with several kinds in data and no Kind).
%
%   The version constant (PartVersion below) goes into ID. Bump it whenever
%   what a part builder of epochMatrix computes changes (spikePart,
%   signalPart, or what they call with which options), so cached results
%   of the old code are computed again.
%
%   See also epochMatrix, DatasetRuns, eventRef, epochWindow, trialSelection,
%   selectUnits, spikePSTH, evokedPotential.

arguments
    S0 = []
    opts.data
    opts.ref
    opts.window
    opts.selection
    opts.units
    opts.signal
    opts.measure
    opts.binSec
    opts.baseline
    opts.auroc
    opts.normalize
    opts.keepEpochs
    opts.Kind (1,1) string = ""
    opts.SaveAs (1,1) string = ""
end

PartVersion = 3;   % bump when a part builder's computation changes (see the help); 2: groupValues, bare text labels; 3: signal.channels are recording channels
Fields = ["data" "ref" "window" "selection" "units" "measure" "binSec" "baseline" "auroc" "signal" "normalize" "keepEpochs"];

% --- the input: [], a struct or a settings file ------------------------------------------
if isempty(S0)
    in = struct();
elseif (isstring(S0) || ischar(S0)) && isscalar(string(S0))
    in = readSettingsFile(string(S0));
elseif isstruct(S0) && isscalar(S0)
    in = S0;
else
    error('epochMatrixSettings:BadValue', 'Pass a settings struct, [] or the path of a .json settings file.');
end
unknown = setdiff(string(fieldnames(in)).', Fields, 'stable');
if ~isempty(unknown)
    error('epochMatrixSettings:UnknownField', 'Unknown setting(s): %s.', strjoin(unknown, ", "));
end

% --- overlay: defaults <- S0 <- options -------------------------------------------------
S = defaultSettings();
S = overlay(S, in);
given = rmfield(opts, {'SaveAs', 'Kind'});
S = overlay(S, given);

% --- normalize and check ------------------------------------------------------------------
S.data = checkData(S.data);
spikes = any(isSpikes(S.data));
signals = any(~isSpikes(S.data));
S.ref = wrapped(@() eventRef(S.ref), "ref");
S.window = wrapped(@() epochWindow(S.window), "window");
if S.window.mode ~= "fixed"
    error('epochMatrixSettings:BadValue', 'window.mode must be "fixed" (got "%s").', S.window.mode);
end
S.selection = wrapped(@() trialSelection(S.selection), "selection");
S.units = section("UnitSelection", S.units, "units");
if spikes; S.units.source = S.data(find(isSpikes(S.data), 1)); end
if ~ismember(S.units.source, ["units" "detected"])
    error('epochMatrixSettings:BadValue', 'units.source must be "units" or "detected" (got "%s").', S.units.source);
end
S.measure = checkWord(S.measure, ["rate" "count" "auroc"], "measure");
S.binSec = checkNumber(S.binSec, "binSec", 1);
if ~(isfinite(S.binSec) && S.binSec > 0)
    error('epochMatrixSettings:BadValue', 'binSec must be a positive number of seconds (got %g).', S.binSec);
end
S.baseline = checkSpan(S.baseline, "baseline");
S.auroc = section("Auroc", S.auroc, "auroc");
S.signal = checkSignal(S.signal);
S.normalize = checkNormalize(S.normalize);
S.keepEpochs = toLogical(S.keepEpochs, "keepEpochs");

nb = S.normalize.baseline;
normalized = signals || S.measure ~= "auroc";   % auROC is not normalized
if ismember(S.normalize.method, ["subtract" "ratio" "percent" "zscore"]) && normalized ...
        && (nb(2) < S.window.pre || nb(1) > S.window.post)
    error('epochMatrixSettings:BadValue', 'normalize.baseline [%g %g] s lies outside the window [%g %g] s.', ...
        nb(1), nb(2), S.window.pre, S.window.post);
end

if spikes
    pre = S.window.pre; post = S.window.post;
    edges = (ceil(pre / S.binSec - 1e-9) : floor(post / S.binSec + 1e-9)) * S.binSec;   % spikePSTH's whole bins
    if numel(edges) < 2
        error('epochMatrixSettings:BadValue', 'window [%g %g] s holds no whole %g s bin edged at the event.', pre, post, S.binSec);
    end
    if S.measure == "auroc" && ~(numel(S.baseline) == 2 && S.baseline(1) < S.baseline(2))
        error('epochMatrixSettings:BadValue', 'measure "auroc" needs baseline = [b0 b1] with b0 < b1.');
    end
end
if signals
    b = S.signal.baseline;
    if ~isempty(b) && (b(2) < S.window.pre || b(1) > S.window.post)
        error('epochMatrixSettings:BadValue', 'signal.baseline [%g %g] s lies outside the window [%g %g] s.', ...
            b(1), b(2), S.window.pre, S.window.post);
    end
end

% --- one kind of data ------------------------------------------------------------------------
if opts.Kind ~= ""
    k = checkData(opts.Kind);
    if ~ismember(k, S.data)
        error('epochMatrixSettings:BadValue', 'Kind "%s" is not in data (%s).', k, strjoin(S.data, ", "));
    end
    if k == "AUX" && numel(S.data) > 1
        S.signal.channels = [];   % the probe's pick: AUX takes all its columns
        S.signal.shanks = [];
    elseif ~isSpikes(k) && ismember("AUX", S.data)
        S.signal.magnitude = false;   % AUX's (the accelerometer's), not the probe signal's
    end
    S.data = k;
    if isSpikes(k); S.units.source = k; end
end

% --- the cache identity ---------------------------------------------------------------------
if nargout > 1
    if ~isscalar(S.data)
        error('epochMatrixSettings:SeveralData', ['The cache identity is per kind of data, and data holds %s: ' ...
            'ask for each kind with Kind= (epochMatrix computes one at a time).'], strjoin(S.data, ", "));
    end
    ID = struct('data', S.data, 'ref', S.ref, 'window', S.window, 'selection', S.selection);
    if isSpikes(S.data)
        for f = ["units" "measure" "binSec" "baseline" "auroc"]
            ID.(f) = S.(f);
        end
    else
        ID.signal = S.signal;
    end
    if S.keepEpochs; ID.keepEpochs = true; end
    ID.version = PartVersion;
    name = "epochMatrix/" + S.data;
    if S.keepEpochs; name = name + "/epochs"; end
end

if opts.SaveAs ~= ""
    writeJsonFile(opts.SaveAs, struct('schema', "epoch-matrix-settings", 'version', 1, 'settings', S), NonFinite="string");
end
end


function S = defaultSettings()
%defaultSettings  Every field at its default, in the documented order.
units = EphysAnalysisConfig.normalizeSection("UnitSelection", struct('classes', string.empty(1, 0)));
S = struct( ...
    'data',      "units", ...
    'ref',       eventRef(), ...
    'window',    epochWindow(), ...
    'selection', trialSelection(), ...
    'units',     units, ...
    'measure',   "rate", ...
    'binSec',    0.01, ...
    'baseline',  [-0.5 0], ...
    'auroc',     EphysAnalysisConfig.normalizeSection("Auroc", struct('cutoff', "none")), ...
    'signal',    struct('channels', [], 'shanks', [], 'baseline', [], 'detrend', false, 'rectify', false, ...
                        'magnitude', false, 'statistic', "mean"), ...
    'normalize', normalizeDefaults(), ...
    'keepEpochs', false);
end


function n = normalizeDefaults()
n = struct('method', "none", 'baseline', [-0.5 0], 'scope', "row");
end


function S = overlay(S, in)
%overlay  IN's fields over S's: a struct over a struct field by field, anything else replaces.
for f = string(fieldnames(in)).'
    v = in.(f);
    if isstruct(v) && isscalar(v) && isstruct(S.(f)) && isscalar(S.(f))
        for g = string(fieldnames(v)).'
            S.(f).(g) = v.(g);
        end
    else
        S.(f) = v;
    end
end
end


function in = readSettingsFile(file)
%readSettingsFile  The settings struct of a settings file.
if ~isfile(file)
    error('epochMatrixSettings:BadValue', 'No settings file %s.', file);
end
try
    s = readJsonFile(file);
catch ME
    error('epochMatrixSettings:BadValue', 'Cannot read the settings file %s: %s', file, ME.message);
end
if ~(isstruct(s) && isfield(s, 'schema') && string(s.schema) == "epoch-matrix-settings" && isfield(s, 'settings'))
    error('epochMatrixSettings:BadValue', '%s is not an epoch-matrix settings file (schema "epoch-matrix-settings").', file);
end
if ~isfield(s, 'version') || ~(isnumeric(s.version) && isscalar(s.version) && s.version <= 1)
    error('epochMatrixSettings:BadValue', '%s: settings file version %s is newer than this code reads (1).', ...
        file, string(s.version));
end
in = s.settings;
if isempty(in); in = struct(); end
if ~(isstruct(in) && isscalar(in))
    error('epochMatrixSettings:BadValue', '%s: "settings" must be an object.', file);
end
end


function v = wrapped(fcn, name)
%wrapped  Call FCN (eventRef, epochWindow, trialSelection); its errors as this function's.
try
    v = fcn();
catch ME
    if endsWith(string(ME.identifier), ":UnknownField")
        error('epochMatrixSettings:UnknownField', '%s: %s', name, ME.message);
    end
    error('epochMatrixSettings:BadValue', '%s: %s', name, ME.message);
end
end


function s = section(sec, v, name)
%section  EphysAnalysisConfig.normalizeSection(SEC, V); unknown fields are an error.
if isempty(v); v = struct(); end
if ~(isstruct(v) && isscalar(v))
    error('epochMatrixSettings:BadValue', '%s must be a struct.', name);
end
try
    [s, unknown] = EphysAnalysisConfig.normalizeSection(sec, v);
catch ME
    error('epochMatrixSettings:BadValue', '%s: %s', name, ME.message);
end
if ~isempty(unknown)
    error('epochMatrixSettings:UnknownField', 'Unknown %s field(s): %s.', name, ...
        strjoin(regexprep(unknown, "^" + sec + "\.", name + "."), ", "));
end
end


function d = checkData(d)
%checkData  A row of kinds, each "units" | "detected" | a signal type (case ignored), each once: one at least.
if iscell(d)
    if ~all(cellfun(@(v) (isstring(v) && isscalar(v)) || (ischar(v) && (isrow(v) || isempty(v))), d))
        error('epochMatrixSettings:BadValue', 'data must be text.');
    end
    d = string(d);
elseif ischar(d) && (isrow(d) || isempty(d))
    d = string(d);
elseif ~isstring(d)
    error('epochMatrixSettings:BadValue', 'data must be text.');
end
d = reshape(d, 1, []);
if isempty(d) || any(ismissing(d)) || any(strtrim(d) == "")
    error('epochMatrixSettings:BadValue', 'data must name at least one kind: "units", "detected", "LFP", "MUA", "SPIKE" or "AUX".');
end
for k = 1:numel(d)
    if ismember(lower(d(k)), ["units" "detected"])
        d(k) = lower(d(k));
    elseif ismember(upper(d(k)), DatasetOutputs.SignalTypes)
        d(k) = upper(d(k));
    else
        error('epochMatrixSettings:BadValue', 'data must be "units", "detected", "LFP", "MUA", "SPIKE" or "AUX" (got "%s").', d(k));
    end
end
d = reshape(unique(d, 'stable'), 1, []);
end


function tf = isSpikes(d)
tf = ismember(d, ["units" "detected"]);
end


function v = checkWord(v, allowed, name)
v = checkText(v, name);
if ~ismember(v, allowed)
    error('epochMatrixSettings:BadValue', '%s must be one of %s (got "%s").', name, strjoin(allowed, ", "), v);
end
end


function v = checkText(v, name)
if iscell(v) && isscalar(v); v = v{1}; end
if ~((isstring(v) && isscalar(v)) || (ischar(v) && (isrow(v) || isempty(v))))
    error('epochMatrixSettings:BadValue', '%s must be text.', name);
end
v = string(v);
end


function v = checkNumber(v, name, n)
%checkNumber  A numeric row ("Inf" / "-Inf" / "NaN" strings and cells of them as numbers); N elements when N is given.
v = toNumber(v, name);
if nargin > 2 && numel(v) ~= n
    error('epochMatrixSettings:BadValue', '%s must have %d element(s) (got %d).', name, n, numel(v));
end
end


function v = toNumber(v, name)
if isempty(v)
    v = [];
    return
end
if iscell(v)
    out = zeros(1, numel(v));
    for k = 1:numel(v)
        out(k) = toNumber(v{k}, name);
    end
    v = out;
    return
end
if isstring(v) || ischar(v)
    t = lower(strtrim(string(v)));
    x = str2double(t);
    x(t == "inf" | t == "+inf") = Inf;
    x(t == "-inf") = -Inf;
    bad = isnan(x) & t ~= "nan";
    if any(bad)
        error('epochMatrixSettings:BadValue', '%s: "%s" is not a number.', name, t(find(bad, 1)));
    end
    v = reshape(x, 1, []);
    return
end
if ~(isnumeric(v) || islogical(v))
    error('epochMatrixSettings:BadValue', '%s must be numeric.', name);
end
v = reshape(double(v), 1, []);
end


function b = checkSpan(b, name)
%checkSpan  [] or [b0 b1] with b0 <= b1, finite.
b = toNumber(b, name);
if isempty(b); return; end
if ~(numel(b) == 2 && all(isfinite(b)) && b(1) <= b(2))
    error('epochMatrixSettings:BadValue', '%s must be [] or [b0 b1] s with b0 <= b1.', name);
end
end


function s = checkSignal(s)
%checkSignal  The signal struct: known fields, each in its form.
def = struct('channels', [], 'shanks', [], 'baseline', [], 'detrend', false, 'rectify', false, ...
    'magnitude', false, 'statistic', "mean");
if isempty(s); s = struct(); end
if ~(isstruct(s) && isscalar(s))
    error('epochMatrixSettings:BadValue', 'signal must be a struct.');
end
unknown = setdiff(string(fieldnames(s)).', string(fieldnames(def)).', 'stable');
if ~isempty(unknown)
    error('epochMatrixSettings:UnknownField', 'Unknown signal field(s): %s.', strjoin("signal." + unknown, ", "));
end
in = s;
s = def;
for f = string(fieldnames(in)).'
    s.(f) = in.(f);
end
s.channels = toNumber(s.channels, "signal.channels");
if ~all(s.channels >= 1 & s.channels == round(s.channels) & isfinite(s.channels))
    error('epochMatrixSettings:BadValue', 'signal.channels must be [] or 1-based channel numbers.');
end
s.shanks = toNumber(s.shanks, "signal.shanks");
if ~all(isfinite(s.shanks))
    error('epochMatrixSettings:BadValue', 'signal.shanks must be [] or shank numbers.');
end
s.baseline = checkSpan(s.baseline, "signal.baseline");
for f = ["detrend" "rectify" "magnitude"]
    s.(f) = toLogical(s.(f), "signal." + f);
end
s.statistic = checkWord(s.statistic, ["mean" "median"], "signal.statistic");
end


function n = checkNormalize(n)
%checkNormalize  The normalize struct: known fields, each in its form; baseline [b0 b1] with b0 < b1.
def = normalizeDefaults();
if isempty(n); n = struct(); end
if ~(isstruct(n) && isscalar(n))
    error('epochMatrixSettings:BadValue', 'normalize must be a struct.');
end
unknown = setdiff(string(fieldnames(n)).', string(fieldnames(def)).', 'stable');
if ~isempty(unknown)
    error('epochMatrixSettings:UnknownField', 'Unknown normalize field(s): %s.', strjoin("normalize." + unknown, ", "));
end
in = n;
n = def;
for f = string(fieldnames(in)).'
    n.(f) = in.(f);
end
n.method = checkWord(n.method, ["none" "subtract" "ratio" "percent" "zscore" "minmax"], "normalize.method");
n.baseline = checkSpan(n.baseline, "normalize.baseline");
if ~(numel(n.baseline) == 2 && n.baseline(1) < n.baseline(2))
    error('epochMatrixSettings:BadValue', 'normalize.baseline must be [b0 b1] s with b0 < b1.');
end
n.scope = checkWord(n.scope, ["row" "group"], "normalize.scope");
end


function v = toLogical(v, name)
if (islogical(v) || isnumeric(v)) && isscalar(v) && ~isnan(double(v))
    v = logical(v);
elseif (isstring(v) || ischar(v)) && any(lower(strtrim(string(v))) == ["true" "false" "1" "0"])
    v = any(lower(strtrim(string(v))) == ["true" "1"]);
else
    error('epochMatrixSettings:BadValue', '%s must be true or false.', name);
end
end
