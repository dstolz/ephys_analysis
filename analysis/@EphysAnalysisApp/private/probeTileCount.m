function P = probeTileCount(obj, spec, opts)
%probeTileCount  A probe figure's tiles on the active dataset (figureProbeTiles) and their words, kept while what they depend on holds.
%   P = probeTileCount(OBJ, SPEC) lays the figure SPEC (Config.figureFor,
%   probe.enabled) out on the active dataset: [T, LEFT] =
%   figureProbeTiles(src, SPEC), kept in FigureProbeTiles under its key
%   (the figure's id, the dataset's key, its observe and probe blocks,
%   event, selection, sort, and the scan: FigurePreviewGeneration), so the
%   Probe layout section's note (syncFigureEditor) and the observation
%   picker (refreshFigureObservations) count them once per edit. Force
%   lays them out again. forgetFigurePickers forgets it.
%   P fields
%     key      the key it was counted for ([] with no dataset)
%     open     a dataset is open (scanned and picked)
%     T, left  figureProbeTiles' outputs ([] when not counted)
%     dataset  the dataset's name
%     error    why the tiles cannot be counted ("" when they are)
%     n        the tiles (height of T); nLeft the observations left out
%     what     "23 units on 2 shanks"
%     why      "1 without a position, 2 over 3 per site" ("" with none left out)
%     note     the section's note: "23 tiles: 23 units on 2 shanks; 3 left
%              out (1 without a position, 2 over 3 per site)"
%     entry    the picker's one entry: "the probe: 23 units on 2 shanks"
%     count    the count line: "Laid out on the probe: 23 tiles; 3 left out (...)."
%
%   See also figureProbeTiles, refreshFigureObservations, syncFigureEditor.
arguments
    obj (1,1) EphysAnalysisApp
    spec (1,1) struct
    opts.Force (1,1) logical = false
end
P = struct('key', [], 'open', false, 'T', [], 'left', [], 'dataset', "", 'error', "", 'n', 0, 'nLeft', 0, ...
    'what', "", 'why', "", 'note', "Scan and pick a dataset to count the tiles.", 'entry', "", 'count', "");
if isempty(obj.Runner) || obj.ActiveIdx < 1 || obj.ActiveIdx > numel(obj.Runner.Keys); return; end
st = spec.style;
key = struct('id', spec.id, 'dataset', string(obj.Runner.Keys(obj.ActiveIdx)), 'observe', spec.observe, 'probe', spec.probe, ...
    'ref', spec.ref, 'selection', spec.selection, 'sort', [st.SortDepth st.SortShank st.LabelDepth st.LabelShank], ...
    'generation', obj.FigurePreviewGeneration);
C = obj.FigureProbeTiles;
if ~opts.Force && isstruct(C) && isfield(C, 'key') && isequaln(C.key, key)
    P = C;
    return
end
P.key = key;
P.open = true;
try
    src = obj.Runner.source(obj.ActiveIdx);
    P.dataset = string(src.name);
    [P.T, P.left] = figureProbeTiles(src, spec);
catch ME
    P.error = string(ME.message);
    P.note = "Cannot count the tiles: " + P.error;
    P.count = "Cannot lay the observations out on the probe: " + P.error;
    obj.FigureProbeTiles = P;
    return
end
T = P.T;
n = height(T);
P.n = n;
[P.why, P.nLeft] = leftText(P.left, spec.probe);
nSh = 0;
if n > 0 && ismember("shank", string(T.Properties.VariableNames)); nSh = numel(unique(T.shank(isfinite(T.shank)))); end
P.what = sprintf("%d %s", n, plural(observedWord(spec), n));
if nSh > 0; P.what = P.what + sprintf(" on %d shank%s", nSh, repmat('s', 1, nSh ~= 1)); end
tiles = sprintf("%d tile%s", n, repmat('s', 1, n ~= 1));
left = "";
if P.nLeft > 0; left = sprintf("; %d left out (%s)", P.nLeft, P.why); end
if n == 0
    P.note = "No tile on " + P.dataset + ": no " + observedWord(spec) + " has a site laid out" + left + ".";
else
    P.note = tiles + ": " + P.what + left + ".";
end
P.entry = "the probe: " + P.what;
P.count = "Laid out on the probe: " + tiles + left + ".";
obj.FigureProbeTiles = P;
end


function [txt, nLeft] = leftText(left, popts)
%leftText  What figureProbeTiles left out, in words, and how many: "1 without a position, 2 over 3 per site".
parts = strings(1, 0);
nLeft = 0;
if ~isstruct(left); txt = ""; return; end
say = struct('noPosition', "%d without a position", 'filtered', "%d outside the shanks, channels or depth range", ...
    'overSite', "%d over " + popts.maxPerSite + " per site", 'overMax', "%d over " + popts.maxTiles + " tiles");
for f = ["noPosition" "filtered" "overSite" "overMax"]
    if ~isfield(left, f) || ~(left.(f) > 0); continue; end
    nLeft = nLeft + left.(f);
    parts(end+1) = sprintf(say.(f), left.(f)); %#ok<AGROW>
end
txt = strjoin(parts, ", ");
end


function w = observedWord(spec)
%observedWord  What one tile is, in a word: "unit", "detection channel", "LFP channel".
switch spec.observe.kind
    case "unit"
        w = "unit";
        if spec.observe.data == "detected"; w = "detection channel"; end
    case "channel"
        w = spec.observe.data + " channel";
    otherwise
        w = "observation";
end
end


function w = plural(w, n)
if n ~= 1; w = w + "s"; end
end
