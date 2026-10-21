function refreshFigureObservations(obj, opts)
%refreshFigureObservations  List the selected figure's observations on the active dataset in the picker.
%   FigureObservations becomes figureObservations(src, spec) (the units the
%   Observations section keeps, the channels, or the dataset, in probe
%   order) and the picker (FigureObservationDropDown) lists their labels,
%   a sorted unit's ending in its number of spikes ("  (5,210 spikes)")
%   and a detection channel's in its number of detections (from the
%   unit's selectUnits row: nothing more is read), a starred unit, channel
%   or dataset's starting with "★ " (favoriteMarks), one with a note with
%   "✎ " (noteMarks, after the star's). With Starred only
%   (observe.starred) only the starred ones are listed, read from the
%   stars in memory (Favorites; figureObservations Favorites=). The figure's pick is
%   kept by its label without the count (FigureObservation: figure id ->
%   label), so it survives a filter change or another dataset while that
%   label is still there; else the first is picked. The list is made again
%   only when what it depends on changed -- the observe block and what it
%   resolves to, the figure's event and selection (the response test; with
%   Per trial group, the groups: one row per observation and group, and
%   the window too), the
%   sort options, the dataset (by its key; a scan forgets the list,
%   onScan) -- unless Force is set; an empty list is kept as well. When the
%   list cannot be made, the picker's UserData.error says why (the preview
%   shows it). The Observations section's count line follows (ending
%   ", starred only" with Starred only). < and > are
%   enabled when there is somewhere to go. A figure across sessions lists
%   its matched observations (figureSessionObservations), a match starred
%   on any of its sessions starting with "★ " (favoriteMarks with the
%   sessions' datasets, kept in the picker's UserData.sessions).
arguments
    obj (1,1) EphysAnalysisApp
    opts.Force (1,1) logical = false
end
dd = obj.FigureObservationDropDown;
E = obj.FigureEditor;
k = obj.SelectedFigure;
none = @(msg) setNone(obj, msg);
if k < 1 || k > numel(obj.Config.Figures)
    none("(no figure)");
    E.obsCount.Text = "";
    return
end
spec = obj.Config.figureFor(k);
if spec.sessions.enabled && ~isempty(obj.Runner)   % a session figure: matched across the datasets, not on the active one
    sessionObservations(obj, spec, opts.Force);
    return
end
if isempty(obj.Runner) || obj.ActiveIdx < 1
    none("(scan and pick a dataset)");
    E.obsCount.Text = "Scan and pick a dataset to list what the figure is drawn for.";
    return
end
st = spec.style;
key = struct('id', spec.id, 'dataset', string(obj.Runner.Keys(obj.ActiveIdx)), 'observe', spec.observe, 'ref', spec.ref, ...
    'selection', spec.selection, 'sort', [st.SortDepth st.SortShank st.LabelDepth st.LabelShank]);   % the dataset by its key (onScan forgets the list)
if spec.observe.perGroup; key.window = spec.window; end   % one row per trial group: the groups with epochs in the window
if ~opts.Force && isstruct(dd.UserData) && isfield(dd.UserData, 'key') && isequaln(dd.UserData.key, key)
    return
end
try
    src = obj.Runner.source(obj.ActiveIdx);
    fav = [];
    if numel(obj.Favorites) >= obj.ActiveIdx; fav = obj.Favorites(obj.ActiveIdx); end
    T = figureObservations(src, spec, Favorites=fav);
catch ME
    msg = "Cannot list the observations: " + string(ME.message);
    none("(cannot list them)");
    E.obsCount.Text = msg;
    dd.UserData = struct('key', key, 'error', msg);   % kept, so the preview can say why
    return
end
obj.FigureObservations = T;
dd.UserData = struct('key', key, 'error', "");
n = height(T);
kind = spec.observe.kind;
switch kind
    case "unit"
        what = "unit";
        if spec.observe.data == "detected"; what = "detection channel"; end
    case "channel"
        what = spec.observe.data + " channel";
    otherwise
        what = "dataset";
end
nG = 0;   % per trial group: the observations' groups
if n > 0 && any(isfinite(T.group)); nG = numel(unique(T.group(isfinite(T.group)))); end
if kind == "dataset" && n == 0 && spec.observe.starred
    E.obsCount.Text = src.name + " is not starred: no figure (Starred only).";
elseif kind == "dataset" && nG == 0
    E.obsCount.Text = "The whole dataset: one figure for " + src.name + ".";
elseif kind == "dataset"
    E.obsCount.Text = sprintf("The whole dataset, once per trial group: %d figures for %s.", n, src.name);
elseif nG > 0
    nObs = n / nG;
    E.obsCount.Text = sprintf("%d %s%s x %d trial groups on %s.", nObs, what, repmat('s', 1, nObs ~= 1), nG, src.name);
else
    E.obsCount.Text = sprintf("%d %s%s on %s.", n, what, repmat('s', 1, n ~= 1), src.name);
end
if spec.observe.starred && kind ~= "dataset"; E.obsCount.Text = extractBefore(E.obsCount.Text, strlength(E.obsCount.Text)) + ", starred only."; end
if n == 0
    none("(no " + kind + " passes the filter)");
    dd.UserData = struct('key', key, 'error', "");   % an empty list is kept too: the filter is not run again until it changes
    return
end
labels = reshape(T.label, 1, []);
i = 1;
id = char(spec.id);
if isKey(obj.FigureObservation, id)
    j = find(labels == string(obj.FigureObservation(id)), 1);
    if ~isempty(j); i = j; end
end
obj.FigureObservation(id) = labels(i);
dd.ItemsData = [];
set(dd, "Items", favoriteMarks(obj, T, spec.observe.data) + noteMarks(obj, T, spec.observe.data) + labels + ...
    spikeCounts(T, spec.observe.data), "ItemsData", 1:n, "Value", i);
syncSteps(obj);
end


function s = spikeCounts(T, data)
%spikeCounts  What each observation's label ends in: "  (5,210 spikes)" for a sorted unit, detections for a channel's.
%   From the unit's selectUnits row (its nSpikes); "" for a channel, the
%   dataset, or a unit whose count is not known.
s = strings(1, height(T));
if ~ismember(data, EphysAnalysisConfig.SpikeSources); return; end
word = "spike";
if data == "detected"; word = "detection"; end
for k = 1:height(T)
    m = T.meta{k};
    if ~(istable(m) && ismember("nSpikes", string(m.Properties.VariableNames))); continue; end
    n = double(m.nSpikes(1));
    if ~isfinite(n); continue; end
    txt = regexprep(sprintf('%d', round(n)), '(\d)(?=(\d{3})+$)', '$1,');   % thousands separated
    s(k) = "  (" + txt + " " + word + repmat('s', 1, n ~= 1) + ")";
end
end


function sessionObservations(obj, spec, force)
%sessionObservations  A session figure's picker: figureSessionObservations over the ticked (or listed) datasets.
%   Each label says across how many sessions it is matched; the list is kept
%   while the datasets, the observe and sessions blocks (and the mapping
%   file's date), the event, the selection and the sort are the same.
dd = obj.FigureObservationDropDown;
E = obj.FigureEditor;
idx = obj.tickedDatasetIndices();
idx = obj.Runner.sessionFigureIndices(spec, idx);
st = spec.style;
mapDate = NaN;
if spec.sessions.mappingFile ~= "" && isfile(spec.sessions.mappingFile); d = dir(spec.sessions.mappingFile); mapDate = d(1).datenum; end
key = struct('id', spec.id, 'datasets', reshape(obj.Runner.Keys(idx), 1, []), 'observe', spec.observe, 'sessions', spec.sessions, ...
    'mapDate', mapDate, 'ref', spec.ref, 'selection', spec.selection, 'sort', [st.SortDepth st.SortShank st.LabelDepth st.LabelShank]);
if ~force && isstruct(dd.UserData) && isfield(dd.UserData, 'key') && isequaln(dd.UserData.key, key)
    return
end
if isempty(idx)
    setNone(obj, "(no dataset to draw it across)");
    E.obsCount.Text = "Tick datasets on the Data tab (or pick them in the Sessions section) to draw the figure across.";
    dd.UserData = struct('key', key, 'error', "no dataset is ticked or listed");
    return
end
try
    [T, S] = obj.Runner.sessionFigureObservations(spec, idx);
catch ME
    msg = "Cannot match the observations across the sessions: " + string(ME.message);
    setNone(obj, "(cannot list them)");
    E.obsCount.Text = msg;
    dd.UserData = struct('key', key, 'error', msg);
    return
end
obj.FigureObservations = T;
dd.UserData = struct('key', key, 'error', "", 'sessions', reshape(S.index, 1, []));   % each session's dataset: the ★ marks (favoriteMarks)
n = height(T);
nS = height(S);
switch spec.observe.kind
    case "unit"
        what = "site";
        if spec.sessions.match == "mapping"; what = "cell"; end
    case "channel"
        what = spec.observe.data + " channel";
    otherwise
        what = "dataset";
end
if spec.observe.kind == "dataset"
    E.obsCount.Text = sprintf("The datasets together: one figure across %d session%s.", nS, repmat('s', 1, nS ~= 1));
else
    E.obsCount.Text = sprintf("%d %s%s matched across %d session%s (at least %d each).", n, what, repmat('s', 1, n ~= 1), ...
        nS, repmat('s', 1, nS ~= 1), max(1, spec.sessions.minSessions));
end
if spec.observe.starred && spec.observe.kind ~= "dataset"
    E.obsCount.Text = extractBefore(E.obsCount.Text, strlength(E.obsCount.Text)) + ", starred on any session.";
elseif spec.observe.starred && n == 0
    E.obsCount.Text = "No dataset of these sessions is starred: no figure (Starred only).";
end
if n == 0
    setNone(obj, "(no " + what + " is matched across the sessions)");
    dd.UserData = struct('key', key, 'error', "", 'sessions', reshape(S.index, 1, []));
    return
end
labels = reshape(T.label + "  (across " + T.nSessions + " session" + repmat("s", n, 1) + ")", 1, []);
labels(T.nSessions == 1) = T.label(T.nSessions == 1).' + "  (across 1 session)";
i = 1;
id = char(spec.id);
if isKey(obj.FigureObservation, id)
    j = find(T.label == string(obj.FigureObservation(id)), 1);
    if ~isempty(j); i = j; end
end
obj.FigureObservation(id) = T.label(i);
dd.ItemsData = [];
set(dd, "Items", favoriteMarks(obj, T, spec.observe.data, reshape(S.index, 1, [])) + labels, "ItemsData", 1:n, "Value", i);
syncSteps(obj);
end


function setNone(obj, msg)
%setNone  An empty picker saying MSG.
obj.FigureObservations = [];
dd = obj.FigureObservationDropDown;
dd.ItemsData = [];
set(dd, "Items", msg, "ItemsData", 0, "Value", 0);
dd.UserData = [];
syncSteps(obj);
end


function syncSteps(obj)
%syncSteps  < and > enabled when there is an observation before / after the one picked; the star toggle follows the pick.
dd = obj.FigureObservationDropDown;
i = dd.Value;
n = 0;
if istable(obj.FigureObservations); n = height(obj.FigureObservations); end
obj.FigureObsPrevButton.Enable = matlab.lang.OnOffSwitchState(n > 0 && i > 1);
obj.FigureObsNextButton.Enable = matlab.lang.OnOffSwitchState(n > 0 && i < n);
syncStarButtons(obj);
end
