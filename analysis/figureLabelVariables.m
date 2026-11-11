function [T, V] = figureLabelVariables(spec, F, opts)
%figureLabelVariables  The variables a figure's text may name, such as {Line} or {Response}: what each means, and its value for one figure.
%   T = figureLabelVariables() lists them: a table with a row per variable,
%   Name ("Line"), Topic ("Alignment", "Trials", "Observation", "Data",
%   "Figure"), Meaning and Example. A figure's title, a panel's title, its
%   X and Y axis labels, its layers' names (the legend) and its note may
%   name any of them in braces: "Time (s) re {Line} {Edge}", "{Response}
%   trials". renderFigure fills them in for each figure it draws
%   (figureLabelFill), so one text serves every unit, channel, trial group
%   and dataset. A name not on the list is left as typed (TeX braces, as in
%   x^{2}, are safe); names are case-sensitive. The same texts print TeX
%   character names as their characters ("\muV" is "µV":
%   figureLabelSymbols).
%
%   [T, V] = figureLabelVariables(SPEC, F, Panel=K) also gives each one's
%   value: T gets a Value column, V holds the values as a struct (a field
%   per Name, each a string) for figureFileName(TEXT, V, Kind="label").
%   SPEC is the figure (EphysAnalysisConfig.figureFor's: its ref, window
%   and selection resolved); F its computed result (figureCompute's, a
%   figure merged across sessions or a probe figure), or [] when there is
%   none: the variables that need it (the observation's, the dataset's, the
%   epochs) are then "<Name>". K is the panel whose alignment, trial
%   selection, id and bins the values follow (an index into SPEC.panels;
%   0, the default, is the figure's own: its title).
%   PerObservation=false leaves the observation's variables (Group,
%   Epochs, Unit, Observation, Channel, Shank, Depth) "<Name>" even with
%   F: a report's heading for a figure drawn for many observations.
%
%   Dataset variables (DatasetVariables: values recorded on a dataset, such
%   as probeDepth = 1200) are label variables too, named as themselves:
%   {probeDepth} prints the figure's dataset's value ("1200"; a number as
%   DatasetVariables.valueText writes it, without its units). One whose
%   name is a variable's below (a dataset variable named Depth) is
%   {var_Depth}. F holds them: F.variables (figureCompute's, a probe
%   figure's) or, for a figure merged across sessions, the var_ columns of
%   F.sessions, the values of the sessions merged joined ", " ("1200,
%   1400"). A dataset without the variable leaves its name as typed, as a
%   name not on the list. T lists them (Topic "Dataset variables", Meaning
%   the label and units, Example the values in use) with Variables=SETS,
%   a cell of the datasets' sets (DatasetVariables; outputVariables reads
%   one from a manifest), and with F those F holds.
%
%   The variables
%     Alignment    Line, Edge (the event the epochs are aligned to; with a
%                  sequence, the step aligned to), Event (eventRefLabel:
%                  the whole reference in words), Window ("-1 to 1 s")
%     Trials       Response (the response words kept, "Hit or FA"; "all"
%                  without), Filter (the filter expression; blank without),
%                  GroupBy (the grouping parameters; blank without), Group
%                  (the trial group of a figure drawn once per group; "all"
%                  otherwise), Epochs (how many are drawn)
%     Observation  Unit (its short label, as the files' {Unit}: "su12",
%                  "ch7", "dataset"), Observation (its full label), Channel,
%                  Shank, Depth (µm; blank where unknown)
%     Data         Name (the dataset; across sessions "3 sessions
%                  (SYNTH-01)"), Subject, Sessions (how many are merged; 1
%                  for one dataset)
%     Figure       Figure (its id), Panel (the panel's id), Bin and Smooth
%                  (the panel's bin width and smoothing, ms; blank for a
%                  type without bins), Measure and MeasureX (a trial
%                  panel's measure and a trial scatter's x measure,
%                  trialMeasureLabel of its first enabled trials layer's;
%                  for the figure's own text, K = 0, its first trial
%                  panel's; blank without one), Date (today, yyyy-MM-dd)
%     Dataset variables  one per variable recorded on the datasets
%                  (probeDepth, cohort, ...: see above)
%
%   See also figureFileName, renderFigure, eventRefLabel, DatasetVariables.

arguments
    spec = []
    F = []
    opts.Panel (1,1) double {mustBeInteger, mustBeNonnegative} = 0
    opts.PerObservation (1,1) logical = true
    opts.Variables = {}   % a cell of sets ([]: none)
end

T = listOf();
builtIn = T.Name;
dv = datasetValues(F);
T = [T; datasetRows(opts.Variables, dv, builtIn)];
if nargout < 2 && isempty(spec); return; end
if ~isstruct(spec)
    error('figureLabelVariables:BadSpec', 'SPEC is a figure (EphysAnalysisConfig.figureFor), or [] for the list alone.');
end
V = valuesOf(spec, F, opts.Panel);
if ~opts.PerObservation
    for n = ["Group" "Epochs" "Unit" "Observation" "Channel" "Shank" "Depth"]; V.(n) = "<" + n + ">"; end
end
for n = string(fieldnames(dv)).'
    V.(datasetLabelName(n, builtIn)) = dv.(n);
end
T.Value = strings(height(T), 1);
for i = 1:height(T)
    if isfield(V, T.Name(i))
        T.Value(i) = V.(T.Name(i));
    elseif ~isstruct(F)
        T.Value(i) = "<" + T.Name(i) + ">";   % a dataset variable, not computed yet
    end   % (a dataset variable the figure's dataset lacks: blank, and its name stays as typed)
end
end


function T = listOf()
%listOf  The variables, their topic, meaning and an example: the one list the app, the checks and the docs read.
rows = {
    "Line",        "Alignment",   "The event line the epochs are aligned to (with a sequence: the step aligned to)", "Stim"
    "Edge",        "Alignment",   "That event's edge: onset or offset", "onset"
    "Event",       "Alignment",   "The whole event reference in words, with its sequence", "Stim onset then Lick onset within 1 s"
    "Window",      "Alignment",   "The epoch window around the event", "-1 to 1 s"
    "Response",    "Trials",      "The response words the trial selection keeps (all: none picked)", "Hit or FA"
    "Filter",      "Trials",      "The trial selection's filter expression (blank: none)", "Level > 40"
    "GroupBy",     "Trials",      "The trial parameters the trials are grouped by (blank: none)", "Freq, Level"
    "Group",       "Trials",      "The trial group drawn, in a figure drawn once per group (all: otherwise)", "Freq = 8000"
    "Epochs",      "Trials",      "How many epochs (trials) the panel draws", "40"
    "Unit",        "Observation", "The unit's or channel's short label, as in file names", "su12"
    "Observation", "Observation", "The unit's or channel's full label", "su12_RAT1_260918T1015"
    "Channel",     "Observation", "Its recording channel", "7"
    "Shank",       "Observation", "Its shank", "1"
    "Depth",       "Observation", "Its depth on the probe, µm", "350"
    "Name",        "Data",        "The dataset's name (across sessions: how many, and the subjects)", "RAT1_260918_101500"
    "Subject",     "Data",        "The subject", "RAT1"
    "Sessions",    "Data",        "How many sessions the figure merges (1 for one dataset)", "3"
    "Figure",      "Figure",      "The figure's id", "Raster+PSTH units"
    "Panel",       "Figure",      "The panel's id", "psth_1"
    "Bin",         "Figure",      "The panel's bin width, ms (blank for a type without bins)", "10"
    "Smooth",      "Figure",      "The panel's smoothing (Gaussian SD), ms (0: none)", "10"
    "Measure",     "Figure",      "The panel's trial measure (its first trials layer's; blank for a panel without one)", "Stim onset → Platform offset (ms)"
    "MeasureX",    "Figure",      "A trial scatter's x measure (blank for other panels)", "Trial onset → Stim onset (ms)"
    "Date",        "Figure",      "Today's date", "2026-11-04"
    };
T = cell2table(rows, 'VariableNames', {'Name', 'Topic', 'Meaning', 'Example'});
for v = ["Name" "Topic" "Meaning" "Example"]
    T.(v) = string(T.(v));
end
end


function R = datasetRows(sets, dv, builtIn)
%datasetRows  The list's rows for the dataset variables: those of SETS (a cell of sets), then those DV holds (datasetValues: the figure's) that SETS lacks.
%   Name is the label variable's (datasetLabelName), Topic "Dataset
%   variables", Meaning the label with its units (and the description,
%   cut short), Example the values in use (at most three).
R = table('Size', [0 4], 'VariableTypes', repmat("string", 1, 4), 'VariableNames', ["Name" "Topic" "Meaning" "Example"]);
topic = "Dataset variables";
if ~iscell(sets); sets = {}; end
sets = cellfun(@DatasetVariables.fromInfo, reshape(sets, 1, []), 'UniformOutput', false);
voc = DatasetVariables.vocabulary(sets);
listed = strings(1, 0);
for i = 1:numel(voc)
    n = string(voc(i).name);
    inUse = strings(1, 0);
    for k = 1:numel(sets)
        if isfield(sets{k}, n); inUse(end+1) = DatasetVariables.valueText(sets{k}.(n).value); end %#ok<AGROW>
    end
    R(end+1, :) = {datasetLabelName(n, builtIn), topic, meaningOf(voc(i)), examplesOf(inUse)}; %#ok<AGROW>
    listed(end+1) = n; %#ok<AGROW>
end
for n = setdiff(string(fieldnames(dv)).', listed, 'stable')
    R(end+1, :) = {datasetLabelName(n, builtIn), topic, DatasetVariables.suggestLabel(n), dv.(n)}; %#ok<AGROW>
end
end


function m = meaningOf(v)
%meaningOf  A dataset variable's meaning: "Probe Depth (µm)", with its description after a colon (at most 60 characters).
m = DatasetVariables.displayLabel(v.label, v.units);
d = strtrim(string(v.description));
if d == ""; return; end
if strlength(d) > 60; d = strtrim(extractBefore(d, 58)) + "..."; end
m = m + ": " + d;
end


function s = examplesOf(t)
%examplesOf  The values in use as one text: the first three, then "...".
s = "";
if isempty(t); return; end
t = unique(t, 'stable');
s = strjoin(t(1:min(end, 3)), ", ");
if numel(t) > 3; s = s + ", ..."; end
end


function n = datasetLabelName(n, builtIn)
%datasetLabelName  The label variable a dataset variable is: its own name, or var_<name> when that is a built-in variable's (Depth).
if ismember(n, builtIn); n = DatasetVariables.ColumnPrefix + n; end
end


function dv = datasetValues(F)
%datasetValues  The dataset variables of a computed figure F as text, a field per variable (as the dataset names it); struct() for none or no F.
%   F.variables (figureCompute's, a probe figure's: the dataset's values),
%   or for a figure merged across sessions the var_ columns of F.sessions
%   over the sessions merged (status "done"), their values joined ", ".
dv = struct();
if ~(isstruct(F) && isscalar(F)); return; end
S = field(F, 'sessions');
if istable(S)
    keep = true(height(S), 1);
    if ismember("status", string(S.Properties.VariableNames)); keep = string(S.status) == "done"; end
    prefix = DatasetVariables.ColumnPrefix;
    for c = string(S.Properties.VariableNames)
        if ~startsWith(c, prefix); continue; end
        x = S.(c)(keep);
        x = x(~ismissing(x));
        if isempty(x); continue; end
        t = strings(1, numel(x));
        for k = 1:numel(x); t(k) = DatasetVariables.valueText(x(k)); end
        dv.(extractAfter(c, strlength(prefix))) = strjoin(unique(t, 'stable'), ", ");
    end
    return
end
v = field(F, 'variables');
if ~(isstruct(v) && isscalar(v)); return; end
for n = string(fieldnames(v)).'
    dv.(n) = DatasetVariables.valueText(v.(n));
end
end


function V = valuesOf(spec, F, k)
%valuesOf  Every variable's value for panel K of SPEC (0: the figure's own) as computed in F ([] = not computed).
V = struct();
ref = field(spec, 'ref');
win = field(spec, 'window');
sel = field(spec, 'selection');
p = [];
if k > 0 && isfield(spec, 'panels') && k <= numel(spec.panels)
    p = spec.panels(k);
    if isstruct(field(p, 'ref')); ref = p.ref; end
    if isstruct(field(p, 'window')); win = p.window; end
    if isstruct(field(p, 'selection')); sel = p.selection; end
end

% alignment
[V.Line, V.Edge, V.Event] = deal("<Line>", "<Edge>", "<Event>");
if isstruct(ref)
    ref = EphysAnalysisConfig.normalizeSection("EventRef", ref);
    [V.Line, V.Edge] = alignedEvent(ref);
    V.Event = eventRefLabel(ref);
end
V.Window = "<Window>";
if isstruct(win)
    V.Window = windowText(win);
end

% trials
[V.Response, V.Filter, V.GroupBy] = deal("<Response>", "<Filter>", "<GroupBy>");
if isstruct(sel)
    r = string(field(sel, 'response'));
    r = r(r ~= "");
    V.Response = "all";
    if ~isempty(r); V.Response = strjoin(r, " or "); end
    V.Filter = strtrim(string(field(sel, 'filter')));
    if isempty(V.Filter) || ismissing(V.Filter); V.Filter = ""; end
    g = string(field(sel, 'groupBy'));
    V.GroupBy = strjoin(g(g ~= ""), ", ");
end

% the observation, the epochs and the data: only with a computed figure
names = ["Group" "Epochs" "Unit" "Observation" "Channel" "Shank" "Depth" "Name" "Subject" "Sessions"];
for n = names; V.(n) = "<" + n + ">"; end
if isstruct(F)
    obs = field(F, 'observation');
    if ~isstruct(obs); obs = struct(); end
    grp = text1(field(obs, 'groupLabel'));
    V.Group = "all";
    if grp ~= ""; V.Group = grp; end
    V.Epochs = epochCount(F, k);
    V.Unit = observationShortLabel(obs);
    V.Observation = text1(field(obs, 'label'));
    if V.Observation == ""; V.Observation = V.Unit; end
    V.Channel = number(field(obs, 'channel'));
    V.Shank = number(field(obs, 'shank'));
    V.Depth = number(field(obs, 'depth'));
    V.Name = text1(field(F, 'dataset'));
    V.Subject = text1(field(F, 'subject'));
    V.Sessions = "1";
    if isfield(F, 'nSessions'); V.Sessions = string(F.nSessions); end
end

% the figure and the panel
V.Figure = text1(field(spec, 'id'));
V.Panel = "";
[V.Bin, V.Smooth] = deal("");
if ~isempty(p)
    V.Panel = text1(p.id);
    b = field(field(p, 'options'), 'bins');
    if isstruct(b) && isfield(b, 'BinSec') && isfield(b, 'SmoothSec')
        V.Bin = string(sprintf('%g', 1000 * b.BinSec));
        V.Smooth = string(sprintf('%g', 1000 * b.SmoothSec));
    end
end
[V.Measure, V.MeasureX] = measuresOf(spec, p);
V.Date = string(datetime('now', 'Format', 'yyyy-MM-dd'));
end


function [y, x] = measuresOf(spec, p)
%measuresOf  The trial measure (and a scatter's x measure) of panel P's first enabled trials layer; P [] = the figure's first such panel.
[y, x] = deal("");
P = p;
if isempty(P) && isfield(spec, 'panels'); P = spec.panels; end
for q = 1:numel(P)
    L = field(P(q), 'layers');
    if ~isstruct(L) || isempty(L) || ~isfield(L, 'source') || ~isfield(L, 'measure'); continue; end
    i = find([L.enabled] & [L.source] == "trials", 1);
    if isempty(i); continue; end
    y = trialMeasureLabel(L(i).measure);
    if string(field(P(q), 'type')) == "trialScatter"; x = trialMeasureLabel(L(i).xMeasure); end
    return
end
end


function [line, edge] = alignedEvent(ref)
%alignedEvent  The line and edge the epochs are aligned to: the reference's own, or its sequence step alignStep (as eventRefLabel reads it).
line = ref.line;
edge = ref.edge;
steps = ref.sequence;
if isempty(steps); return; end
a = ref.alignStep;
last = find([steps.relation] == "followedBy", 1, 'last');
if isempty(last); last = 0; end
if isinf(a); a = last; end
if a >= 1 && a <= numel(steps)
    line = steps(a).line;
    edge = steps(a).edge;
end
end


function s = windowText(w)
%windowText  An epoch window in words: "-1 to 1 s"; a "between" window "-0.2 s to Lick onset +0.5 s".
pre = double(field(w, 'pre'));
post = double(field(w, 'post'));
if isempty(pre); pre = NaN; end
if isempty(post); post = NaN; end
stop = field(w, 'stop');
if string(field(w, 'mode')) == "between" && isstruct(stop)
    s = string(sprintf('%g s to %s %+g s', pre, eventRefLabel(stop), post));
else
    s = string(sprintf('%g to %g s', pre, post));
end
end


function s = epochCount(F, k)
%epochCount  How many epochs panel K draws (its own epochs, else the figure's); blank for a panel that takes none.
E = field(F, 'epochs');
if k > 0 && isfield(F, 'panels') && k <= numel(F.panels) && istable(field(F.panels(k), 'epochs'))
    E = F.panels(k).epochs;
end
s = "";
if istable(E); s = string(height(E)); end
end


function v = field(s, name)
%field  S.(NAME) of a struct, else [].
v = [];
if isstruct(s) && isscalar(s) && isfield(s, name); v = s.(name); end
end


function s = text1(v)
%text1  A value as one string ("" for empty or missing).
if iscell(v) && isscalar(v); v = v{1}; end
s = "";
if isempty(v); return; end
v = string(v);
v = v(~ismissing(v));
if isempty(v); return; end
s = strjoin(reshape(v, 1, []), ", ");
end


function s = number(v)
%number  A finite number as text ("%g"); blank otherwise.
s = "";
if iscell(v) && isscalar(v); v = v{1}; end
if isnumeric(v) && isscalar(v) && isfinite(v); s = string(sprintf('%g', v)); end
end
