function refreshFigureObservations(obj, opts)
%refreshFigureObservations  List the selected figure's observations on the active dataset in the picker.
%   FigureObservations becomes figureObservations(src, spec) (the units the
%   Observations section keeps, the channels, or the dataset, in probe
%   order) and the picker (FigureObservationDropDown) lists their labels.
%   The figure's pick is kept by its label (FigureObservation: figure id
%   -> label), so it survives a filter change or another dataset while that
%   label is still there; else the first is picked. The list is made again
%   only when what it depends on changed -- the observe block and what it
%   resolves to, the figure's event and selection (the response test; with
%   Per trial group, the groups: one row per observation and group, and
%   the window too), the
%   sort options, the dataset (by its key; a scan forgets the list,
%   onScan) -- unless Force is set; an empty list is kept as well. When the
%   list cannot be made, the picker's UserData.error says why (the preview
%   shows it). The Observations section's count line follows. < and > are
%   enabled when there is somewhere to go.
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
if isempty(obj.Runner) || obj.ActiveIdx < 1
    none("(scan and pick a dataset)");
    E.obsCount.Text = "Scan and pick a dataset to list what the figure is drawn for.";
    return
end
spec = obj.Config.figureFor(k);
st = spec.style;
key = struct('id', spec.id, 'dataset', string(obj.Runner.Keys(obj.ActiveIdx)), 'observe', spec.observe, 'ref', spec.ref, ...
    'selection', spec.selection, 'sort', [st.SortDepth st.SortShank st.LabelDepth st.LabelShank]);   % the dataset by its key (onScan forgets the list)
if spec.observe.perGroup; key.window = spec.window; end   % one row per trial group: the groups with epochs in the window
if ~opts.Force && isstruct(dd.UserData) && isfield(dd.UserData, 'key') && isequaln(dd.UserData.key, key)
    return
end
try
    src = obj.Runner.source(obj.ActiveIdx);
    T = figureObservations(src, spec);
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
        if spec.observe.source == "detected"; what = "detection channel"; end
    case "channel"
        what = spec.observe.signal + " channel";
    otherwise
        what = "dataset";
end
nG = 0;   % per trial group: the observations' groups
if n > 0 && any(isfinite(T.group)); nG = numel(unique(T.group(isfinite(T.group)))); end
if kind == "dataset" && nG == 0
    E.obsCount.Text = "The whole dataset: one figure for " + src.name + ".";
elseif kind == "dataset"
    E.obsCount.Text = sprintf("The whole dataset, once per trial group: %d figures for %s.", n, src.name);
elseif nG > 0
    nObs = n / nG;
    E.obsCount.Text = sprintf("%d %s%s x %d trial groups on %s.", nObs, what, repmat('s', 1, nObs ~= 1), nG, src.name);
else
    E.obsCount.Text = sprintf("%d %s%s on %s.", n, what, repmat('s', 1, n ~= 1), src.name);
end
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
set(dd, "Items", labels, "ItemsData", 1:n, "Value", i);
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
%syncSteps  < and > enabled when there is an observation before / after the one picked.
dd = obj.FigureObservationDropDown;
i = dd.Value;
n = 0;
if istable(obj.FigureObservations); n = height(obj.FigureObservations); end
obj.FigureObsPrevButton.Enable = matlab.lang.OnOffSwitchState(n > 0 && i > 1);
obj.FigureObsNextButton.Enable = matlab.lang.OnOffSwitchState(n > 0 && i < n);
end
