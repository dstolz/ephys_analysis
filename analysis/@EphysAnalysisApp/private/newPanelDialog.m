function c = newPanelDialog(fig, F, anchor, lines, params, start, sets)
%newPanelDialog  Pick a new panel's type, name, place and key parameters in a modal window over FIG.
%   C = newPanelDialog(FIG, F, ANCHOR, LINES, PARAMS) shows the New panel
%   window for the figure entry F, whose selected panel is ANCHOR (its
%   id; "" when F has no panel yet). On the left a tile per panel type
%   (EphysAnalysisConfig.panelTypes, every row, so a new type shows
%   without a change here), each a small representative plot of the type
%   (analysis/icons/panels/<type>.png, made by tools/makePanelThumbnails
%   from the real draw functions; a gray placeholder for a type without
%   one) over its label; the type picked is amber. On the right, for the type picked: its label
%   and description, Name (the panel's id: "<type>_<n>" until one is
%   typed; it must be unique in the figure), Title (blank = none), Place
%   (Below, Above, Right or Left of ANCHOR: a new row or column; the
%   first panel goes to row 1, column 1) and the type's key parameters:
%     every type      what it reads (the sources the type draws; a
%                     coherence panel its seed and its partner) and the
%                     binding (follows the observation or fixed; fixed
%                     where the layer cannot follow), but an event-trace
%                     panel, which reads its lines
%     raster          Sort rows by (trial order, the stop event, the
%                     first-spike latency, or one of PARAMS)
%     psth            Bin and Smooth (ms), Measure, Display (a trace or a
%                     heat map)
%     continuous      Stack (off, a row per group or per channel), Error
%                     band
%     heatmap         Rows (the layer's units or channels, or one unit's
%                     epochs), Bin (ms)
%     waveforms       Layout (grid or probe)
%     probemap        Value
%     corrmap         Epoch rate, Correlation
%     rate            Measure, Display
%     tuning          Parameter and Series (PARAMS)
%     spectrum        Frequency range (Hz), Scale
%     spectrogram     Frequency range (Hz), Moving window (s)
%     coherence       Frequency range (Hz)
%     eventTrace      Lines (LINES: one events layer each), Display
%   OK returns C, a struct onNewPanel takes as its options: Type, Where,
%   Id, Title, Source, Partner, Binding, Lines and Options (the partial
%   options the parameters set), Set ("") and Alignment; a name another
%   panel of F has is refused with a red line instead. Cancel, or closing
%   the window, returns [].
%   C = newPanelDialog(..., START): the parameters of each type start from
%   START.(<type>), its options (onNewPanel: the options remembered for
%   the type over its defaults); without it, from the type's defaults. A
%   sort, parameter or series START names that PARAMS has not starts
%   blank.
%   C = newPanelDialog(..., START, SETS): under the types, "Saved figures"
%   and a tile per row of SETS (FigureTemplate.panelTypes: the built-in
%   Raster over PSTH, then the figures you saved as panel types), its
%   picture the type pictures of its panels where they sit in its grid.
%   One picked shows its name, description and shape, the ids its panels
%   will have in F (Name, not editable), Place, and as its key parameter
%   Alignment: "This figure's" (its panels follow F's event reference,
%   window and trial selection) or "Its own, as saved" (offered when the
%   saved figure has its own). OK then returns C with Set (its Key), Where
%   and Alignment ("figure" | "own"), Type "".
%   The window's UserData holds its controls for the tests: Types (the
%   tiles, a struct by type), Pick (a function: Pick(TYPE) picks a
%   type), Sets (a struct array: Key, Tile), PickSet (PickSet(KEY) picks
%   a saved figure), Name, Title, Where, Params (a function returning the
%   current parameters' controls, a struct by name: Source, Partner,
%   Binding, Sort, BinMs, SmoothMs, Measure, Display, ErrorType, Rows,
%   Layout, Value, Metric, Correlation, Param, Series, FreqFrom, FreqTo,
%   Scale, WinSec, StepSec, Lines; a saved figure's: Alignment), Message,
%   Ok and Cancel.
%
%   See also onNewPanel, EphysAnalysisConfig.panelTypes, figureEditorChoices,
%   FigureTemplate.panelTypes, EphysAnalysisConfig.placePanels.
T = EphysAnalysisConfig.panelTypes();
n = height(T);
if nargin < 6; start = struct(); end
if nargin < 7; sets = FigureTemplate.panelTypes(Yours=false); end
ns = height(sets);
c = [];
taken = string.empty(1, 0);
if ~isempty(F.panels); taken = [F.panels.id]; end
iconDir = fullfile(fileparts(fileparts(fileparts(mfilename("fullpath")))), "icons", "panels");
gray = [0.35 0.35 0.35];

pos = [200 120 960 620];
if ns > 0   % taller by the saved figures' rows, as far as the screen allows (the tiles scroll past that)
    screen = get(groot, 'ScreenSize');
    pos(4) = max(620, min(620 + 30 + ceil(ns / 4) * 132, screen(4) - 120));
end
try
    q = getpixelposition(fig);
    pos(1:2) = max(1, q(1:2) + (q(3:4) - pos(3:4)) / 2);
catch
end
d = uifigure("Name", "New panel", "Position", pos, "WindowStyle", "modal");
g = uigridlayout(d, [2 2], "ColumnWidth", {'1x', 360}, "RowHeight", {'1x', 36}, "Padding", [12 12 12 12], ...
    "ColumnSpacing", 14);

% the types: a tile each, a small representative plot over the label; then the saved figures, a tile each
nc = 4;
nr = ceil(n / nc);
nrs = ceil(ns / nc);
heights = repmat({124}, 1, nr);
if ns > 0; heights = [heights {22} repmat({124}, 1, nrs)]; end
tg = uigridlayout(g, [numel(heights) nc], "RowHeight", heights, "ColumnWidth", repmat({'1x'}, 1, nc), ...
    "Padding", [0 0 0 0], "RowSpacing", 8, "ColumnSpacing", 8, "Scrollable", "on");
tg.Layout.Row = 1; tg.Layout.Column = 1;
tiles = struct();
for i = 1:n
    t = T.Type(i);
    b = uibutton(tg, "state", "Text", T.Label(i), "Icon", thumbnail(iconDir, t), "IconAlignment", "top", ...
        "Tooltip", T.Description(i), "ValueChangedFcn", @(~, ~) pick(t));
    b.Layout.Row = floor((i - 1) / nc) + 1;
    b.Layout.Column = mod(i - 1, nc) + 1;
    tiles.(t) = b;
end
setTiles = struct('Key', {}, 'Tile', {});
if ns > 0
    l = uilabel(tg, "Text", "Saved figures  (all their panels, as arranged)", "FontWeight", "bold", "VerticalAlignment", "bottom", ...
        "Tooltip", "A saved figure places all its panels, arranged as saved, next to the selected panel. Save as panel " + ...
        "type... under the figure list adds the figure shown here.");
    l.Layout.Row = nr + 1; l.Layout.Column = [1 nc];
end
for i = 1:ns
    key = sets.Key(i);
    tip = sets.Label(i);
    if sets.Description(i) ~= ""; tip = tip + ": " + sets.Description(i); end
    tip = tip + newline + sets.Summary(i);
    b = uibutton(tg, "state", "Text", sets.Label(i), "Icon", setThumbnail(iconDir, sets.Figure{i}), "IconAlignment", "top", ...
        "Tooltip", tip, "ValueChangedFcn", @(~, ~) pickSet(key));
    b.Layout.Row = nr + 1 + floor((i - 1) / nc) + 1;
    b.Layout.Column = mod(i - 1, nc) + 1;
    setTiles(i) = struct('Key', key, 'Tile', b);
end

% the panel picked: its name, title and place, then the type's key parameters
rg = uigridlayout(g, [7 2], "RowHeight", {24, 66, 26, 26, 26, 24, '1x'}, "ColumnWidth", {90, '1x'}, ...
    "Padding", [0 0 0 0], "RowSpacing", 6);
rg.Layout.Row = 1; rg.Layout.Column = 2;
typeLabel = uilabel(rg, "Text", "", "FontWeight", "bold", "FontSize", 15);
typeLabel.Layout.Row = 1; typeLabel.Layout.Column = [1 2];
descLabel = uilabel(rg, "Text", "", "WordWrap", "on", "VerticalAlignment", "top", "FontColor", gray);
descLabel.Layout.Row = 2; descLabel.Layout.Column = [1 2];
l = uilabel(rg, "Text", "Name:"); l.Layout.Row = 3;
nameField = uieditfield(rg, "text", "ValueChangedFcn", @(~, ~) nameTyped(), ...
    "Tooltip", "The panel's id, unique in the figure: the aesthetics editor and the issue list name the panel by it.");
nameField.Layout.Row = 3; nameField.Layout.Column = 2;
l = uilabel(rg, "Text", "Title:"); l.Layout.Row = 4;
titleField = uieditfield(rg, "text", "Placeholder", "none", ...
    "Tooltip", "The panel's own title (blank = none; under a figure title of your own the top-left panel names the observation).");
titleField.Layout.Row = 4; titleField.Layout.Column = 2;
l = uilabel(rg, "Text", "Place:"); l.Layout.Row = 5;
if anchor == ""
    whereDD = uidropdown(rg, "Items", "row 1, column 1 (the first panel)", "ItemsData", "below", "Enable", "off", ...
        "Tooltip", "The first panel of a figure fills its one cell.");
else
    w = ["below" "above" "right" "left"];
    whereDD = uidropdown(rg, "Items", ["Below" "Above" "Right of" "Left of"] + " " + anchor, "ItemsData", w, "Value", "below", ...
        "Tooltip", "Where the panel goes next to the selected panel: Above and Below make a new row of the grid " + ...
        "(the new panel takes the selected panel's columns), Left and Right a new column (it takes its rows).");
end
whereDD.Layout.Row = 5; whereDD.Layout.Column = 2;
l = uilabel(rg, "Text", "Key parameters", "FontWeight", "bold"); l.Layout.Row = 6; l.Layout.Column = [1 2];
pp = uipanel(rg, "BorderType", "none");
pp.Layout.Row = 7; pp.Layout.Column = [1 2];

% the message line and the buttons
msg = uilabel(g, "Text", "Pick a type; every other setting can be changed in the editor later.", "FontColor", gray);
msg.Layout.Row = 2; msg.Layout.Column = 1;
bg = uigridlayout(g, [1 3], "ColumnWidth", {'1x', 120, 120}, "Padding", [0 0 0 0]);
bg.Layout.Row = 2; bg.Layout.Column = 2;
uilabel(bg, "Text", "");
okB = uibutton(bg, "Text", "OK", "ButtonPushedFcn", @(~, ~) finish(true), "Tooltip", "Add the panel and select it.");
cancelB = uibutton(bg, "Text", "Cancel", "ButtonPushedFcn", @(~, ~) finish(false), "Tooltip", "Add nothing.");
styleButton(findall(d, "Type", "uibutton"));
styleButton(okB, "confirm");

typed = false;
current = "";
currentSet = "";
P = struct();
first = "psth";
if ~any(T.Type == first); first = T.Type(1); end
pick(first);
d.CloseRequestFcn = @(~, ~) finish(false);
d.UserData = struct('Types', tiles, 'Pick', @pick, 'Sets', setTiles, 'PickSet', @pickSet, 'Name', nameField, ...
    'Title', titleField, 'Where', whereDD, 'Params', @currentParams, 'Message', msg, 'Ok', okB, 'Cancel', cancelB);
uiwait(d);
if isvalid(d); delete(d); end


    function pick(t)
        %pick  Type T picked: its tile pressed (the others not), its label, description, default name and parameters.
        press(t, "");
        current = t;
        currentSet = "";
        row = T.Type == t;
        typeLabel.Text = T.Label(row);
        descLabel.Text = T.Description(row);
        set([nameField titleField], "Enable", "on");
        titleField.Placeholder = "none";
        if ~typed; nameField.Value = EphysAnalysisConfig.freeId(t, taken); end
        def = T.DefaultOptions{row};
        if isfield(start, t); def = start.(t); end
        P = buildParams(pp, t, def, T.DefaultBinding(row), lines, params, F.observe.data);
        msg.Text = "Pick a type; every other setting can be changed in the editor later.";
        msg.FontColor = gray;
    end

    function pickSet(key)
        %pickSet  Saved figure KEY picked: its tile pressed, its name, description and shape, the ids its panels get, Alignment.
        si = find(sets.Key == key, 1);
        if isempty(si); return; end
        press("", key);
        current = "";
        currentSet = key;
        typed = false;   % a type picked next gets its own free name
        typeLabel.Text = sets.Label(si);
        txt = sets.Summary(si);
        if sets.Description(si) ~= ""; txt = sets.Description(si) + ". " + txt; end
        descLabel.Text = txt + ". Its panels are copied into the figure as one block; each is an ordinary panel afterwards.";
        B = sets.Figure{si};
        ids = strings(1, 0);
        try
            [~, ids] = EphysAnalysisConfig.placePanels(F, B, string(whereDD.Value), anchor);
        catch
        end
        nameField.Value = strjoin(ids, ", ");
        titleField.Value = "";
        titleField.Placeholder = "each panel keeps its own";
        set([nameField titleField], "Enable", "off");
        P = buildSetParams(pp, B);
        msg.Text = "Pick a type or a saved figure; every setting can be changed in the editor later.";
        msg.FontColor = gray;
    end

    function press(t, key)
        %press  The tile of type T or saved figure KEY pressed and amber, every other one not.
        for x = reshape(T.Type, 1, [])
            tiles.(x).Value = x == t;
            styleButton(tiles.(x), ternary(x == t, "active", "secondary"));   % the type picked in amber
        end
        for j = 1:numel(setTiles)
            on = setTiles(j).Key == key;
            setTiles(j).Tile.Value = on;
            styleButton(setTiles(j).Tile, ternary(on, "active", "secondary"));
            if on
                try
                    scroll(tg, setTiles(j).Tile);   % in view, when the tiles scroll
                catch
                end
            end
        end
    end

    function out = currentParams()
        %currentParams  The current parameters' controls (made again at every pick).
        out = P;
    end

    function nameTyped()
        typed = strtrim(string(nameField.Value)) ~= "";
    end

    function finish(accept)
        if accept
            if currentSet ~= ""
                c = gatherParams(struct(), "");
                c.Type = "";
                c.Id = "";
                c.Title = "";
                c.Set = currentSet;
                if isfield(P, 'Alignment'); c.Alignment = string(P.Alignment.Value); end
            else
                id = strtrim(string(nameField.Value));
                if any(taken == id)
                    msg.Text = "Another panel of " + F.id + " is named " + id + ": pick another name.";
                    msg.FontColor = [0.75 0.1 0.1];
                    return
                end
                c = gatherParams(P, current);
                c.Type = current;
                c.Id = id;
                c.Title = string(titleField.Value);
            end
            c.Where = string(whereDD.Value);
            c = orderfields(c, {'Type', 'Where', 'Id', 'Title', 'Source', 'Partner', 'Binding', 'Lines', 'Options', 'Set', 'Alignment'});
        end
        uiresume(d);
    end
end


function P = buildSetParams(pp, B)
%buildSetParams  A saved figure B's key parameter in the panel PP (its children replaced): Alignment, when it has its own.
delete(pp.Children);
P = struct();
gr = uigridlayout(pp, [2 2], "RowHeight", {26, 'fit'}, "ColumnWidth", {120, '1x'}, "Padding", [0 0 0 0], "RowSpacing", 6);
own = arrayfun(@(f) isstruct(B.(f)), ["ref" "window" "selection"]);
if ~any(own)
    l = uilabel(gr, "Text", "None: its panels follow this figure's event reference, window and trial selection (or " + ...
        "their own, where they have them). The editor has every option.", "WordWrap", "on", "FontColor", [0.35 0.35 0.35]);
    l.Layout.Row = [1 2]; l.Layout.Column = [1 2];
    return
end
names = ["event reference" "epoch window" "trial selection"];
what = names(own);
if isstruct(B.ref); what(1) = what(1) + " (" + eventRefLabel(B.ref) + ")"; end
l = uilabel(gr, "Text", "Alignment:");
l.Layout.Row = 1; l.Layout.Column = 1;
P.Alignment = uidropdown(gr, "Items", ["This figure's" "Its own, as saved"], "ItemsData", ["figure" "own"], "Value", "figure", ...
    "Tooltip", "This figure's: the panels follow this figure's event reference, window and trial selection. Its own: " + ...
    "each panel that followed the saved figure's takes the saved figure's own (" + strjoin(what, ", ") + ").");
P.Alignment.Layout.Row = 1; P.Alignment.Layout.Column = 2;
l = uilabel(gr, "Text", "The saved figure has its own " + strjoin(what, ", ") + ".", "WordWrap", "on", ...
    "FontColor", [0.35 0.35 0.35]);
l.Layout.Row = 2; l.Layout.Column = [1 2];
end


function P = buildParams(pp, t, def, binding, lines, params, observed)
%buildParams  Make the key parameters of panel type T in the panel PP (its children replaced): a struct of controls by name.
%   OBSERVED: the figure's observe.data (what a layer may follow).
delete(pp.Children);
P = struct();
specs = {};   % {name, label, maker}: a row each
ch = figureEditorChoices(t, "");
srcs = ch.Sources(ch.Sources ~= "events");
labels = ch.SourceLabels(ch.Sources ~= "events");
if t ~= "eventTrace" && ~isempty(srcs)
    first = EphysAnalysisConfig.defaultLayer(t).source;
    if ~ismember(first, srcs); first = srcs(1); end
    specs(end+1, :) = {"Source", ternary(t == "coherence", "Seed:", "Reads:"), ...
        @(gr) uidropdown(gr, "Items", labels, "ItemsData", srcs, "Value", first, ...
        "Tooltip", "What the panel's first layer reads; more layers can be added in the editor's Layers section.")};
    if t == "coherence"
        specs(end+1, :) = {"Partner", "Partner:", @(gr) uidropdown(gr, "Items", labels, "ItemsData", srcs, ...
            "Value", ternary(ismember("LFP", srcs), "LFP", srcs(1)), ...
            "Tooltip", "The second layer: the seed's first item is paired with each of its items.")};
    end
    specs(end+1, :) = {"Binding", "Binding:", @(gr) uidropdown(gr, "Items", ["Follows the observation" "Fixed"], ...
        "ItemsData", ["observation" "fixed"], "Value", binding, ...
        "Tooltip", "Follows the observation: reads the unit or channel the figure is drawn for. Fixed: reads the " + ...
        "items named in the editor's Layers section (all of them until you name some). Grayed out where the layer " + ...
        "cannot follow.")};
end
switch t
    case "raster"
        specs(end+1, :) = {"Sort", "Sort rows by:", @(gr) uidropdown(gr, "Items", ["trial order" "the stop event" "first-spike latency" params], ...
            "ItemsData", ["" "stop" "latency" params], "Value", among(def.rasterSort, ["" "stop" "latency" params]), ...
            "Tooltip", "The rows' order within each trial group.")};
    case "psth"
        specs = [specs; binRows(def); measureRow(def)];
        specs(end+1, :) = {"Display", "Display:", @(gr) uidropdown(gr, "Items", ["trace (bars or a line per group)" ...
            "heat map (a row per group)"], "ItemsData", ["trace" "heatmap"], "Value", def.display, ...
            "Tooltip", "Each trial group's PSTH as bars or a line, or the unit's PSTH as an image with a row per group.")};
    case "continuous"
        specs(end+1, :) = {"Stack", "Stack:", @(gr) uidropdown(gr, "Items", ["Off (overlaid)" "One row per group" ...
            "One row per channel"], "ItemsData", ["off" "groups" "items"], "Value", def.stack, ...
            "Tooltip", "Overlaid lines, a row of its own per trial group, or a row of its own per channel.")};
        specs(end+1, :) = {"ErrorType", "Error band:", @(gr) uidropdown(gr, "Items", ["off" "mean ± SEM" "mean ± SD" ...
            "bootstrap 95% CI" "interquartile range"], "ItemsData", EphysAnalysisConfig.AuxErrorTypes, "Value", def.errorType, ...
            "Tooltip", "The band around the epochs' mean.")};
    case "heatmap"
        specs(end+1, :) = {"Rows", "Rows:", @(gr) uidropdown(gr, "Items", ["the layer's units or channels" ...
            "one unit's epochs (trials)"], "ItemsData", ["items" "trials"], "Value", def.rows, ...
            "Tooltip", "A row per unit or channel (one trial group), or a row per epoch of one unit (every group, sorted as a raster).")};
        specs = [specs; binRows(def, false)];
    case "waveforms"
        specs(end+1, :) = {"Layout", "Layout:", @(gr) uidropdown(gr, "Items", ["grid: the unit" "probe: every unit at its site"], ...
            "ItemsData", ["grid" "probe"], "Value", def.layout, "Tooltip", "The unit's waveform, or every unit of the layer on the probe.")};
    case "probemap"
        specs(end+1, :) = {"Value", "Value:", @(gr) uidropdown(gr, "Items", ["rate (spikes/s)" "spike count" "units per site"], ...
            "ItemsData", ["rate" "nSpikes" "nUnits"], "Value", among(def.value, ["rate" "nSpikes" "nUnits"]), ...
            "Tooltip", "Each unit's rate or spike count, drawn on the unit; or the units per site, drawn on the site.")};
    case "corrmap"
        specs(end+1, :) = {"Metric", "Epoch rate:", @(gr) uidropdown(gr, "Items", ["mean" "peak"], "Value", def.metric, ...
            "Tooltip", "Each epoch's mean rate, or its peak binned rate.")};
        specs(end+1, :) = {"Correlation", "Correlation:", @(gr) uidropdown(gr, "Items", ["pearson" "spearman"], ...
            "Value", def.correlation, "Tooltip", "The correlation between two units' per-epoch rates.")};
    case "rate"
        specs = [specs; measureRow(def)];
        specs(end+1, :) = {"Display", "Display:", @(gr) uidropdown(gr, "Items", ["bars (mean, error bar)" "boxes" "points (each epoch)"], ...
            "ItemsData", ["bar" "box" "points"], "Value", def.display, "Tooltip", "How each trial group's rates are drawn.")};
    case "tuning"
        specs(end+1, :) = {"Param", "Parameter:", @(gr) uidropdown(gr, "Editable", "on", "Items", ["" params], ...
            "Value", among(def.param, ["" params]), ...
            "Tooltip", "The trial parameter on the x axis (blank: the figure's first group-by parameter, else the first numeric one).")};
        specs(end+1, :) = {"Series", "Series:", @(gr) uidropdown(gr, "Editable", "on", "Items", ["" params], ...
            "Value", among(def.seriesParam, ["" params]), ...
            "Tooltip", "One curve per value of this trial parameter (blank: one curve).")};
    case "spectrum"
        specs = [specs; freqRow(def)];
        specs(end+1, :) = {"Scale", "Scale:", @(gr) uidropdown(gr, "Items", ["dB" "log axis" "linear"], ...
            "ItemsData", ["db" "log" "linear"], "Value", def.scale, "Tooltip", "How the power is shown.")};
    case "spectrogram"
        specs = [specs; freqRow(def)];
        specs(end+1, :) = {"WinSec", "Moving window (s):", @(gr) pair(gr, def.movingwin, "step", ...
            "The moving window and its step, s.")};
    case "coherence"
        specs = [specs; freqRow(def)];
    case "eventTrace"
        L = lines(lines ~= "Trial");
        if isempty(L)
            specs(end+1, :) = {"Lines", "Lines:", @(gr) uieditfield(gr, "text", "Value", "Stim", ...
                "Tooltip", "The digital or derived lines drawn, a row each, separated by spaces.")};
        else
            pre = L(1);
            if ismember("Stim", L); pre = "Stim"; end
            specs(end+1, :) = {"Lines", "Lines:", @(gr) uilistbox(gr, "Items", L, "Multiselect", "on", "Value", {char(pre)}, ...
                "Tooltip", "The lines drawn, a row each (Ctrl+click picks several).")};
        end
        specs(end+1, :) = {"Display", "Draw as:", @(gr) uidropdown(gr, "Items", ["solid bars (onset to offset)" "a logic level (a line)"], ...
            "ItemsData", ["bars" "line"], "Value", def.display, "Tooltip", "How each interval of a line is drawn.")};
end
m = size(specs, 1);
gr = uigridlayout(pp, [max(m, 1) 2], "RowHeight", repmat({26}, 1, max(m, 1)), "ColumnWidth", {120, '1x'}, ...
    "Padding", [0 0 0 0], "RowSpacing", 6);
if m == 0
    l = uilabel(gr, "Text", "None: the editor has every option.", "FontColor", [0.35 0.35 0.35]);
    l.Layout.Column = [1 2];
    return
end
for r = 1:m
    l = uilabel(gr, "Text", specs{r, 2});
    l.Layout.Row = r; l.Layout.Column = 1;
    h = specs{r, 3}(gr);
    h.Layout.Row = r; h.Layout.Column = 2;
    if isa(h, 'matlab.ui.control.ListBox'); gr.RowHeight{r} = 78; end
    P.(specs{r, 1}) = h;
end
if isfield(P, 'Binding')   % fixed where the layer cannot follow
    follow = @() syncBinding(P, t, observed);
    P.Source.ValueChangedFcn = @(~, ~) follow();
    if isfield(P, 'Rows')
        P.Rows.ValueChangedFcn = @(~, ~) rowsChanged(P, t, observed);
    end
    syncBinding(P, t, observed);
end
if isfield(P, 'WinSec')   % a pair of fields: the window and its step
    kids = P.WinSec.Children;
    P.WinSec = findobj(kids, 'Tag', 'first');
    P.StepSec = findobj(kids, 'Tag', 'second');
end
if isfield(P, 'FreqFrom')
    kids = P.FreqFrom.Children;
    P.FreqFrom = findobj(kids, 'Tag', 'first');
    P.FreqTo = findobj(kids, 'Tag', 'second');
end
end


function rows = binRows(def, smooth)
%binRows  Bin (ms) and, unless SMOOTH is false, Smooth (ms): the type's bins.
if nargin < 2; smooth = true; end
rows = {"BinMs", "Bin (ms):", @(gr) uieditfield(gr, "numeric", "Value", 1000 * def.bins.BinSec, "Limits", [0 Inf], ...
    "LowerLimitInclusive", "off", "Tooltip", "The histogram's bin width, ms.")};
if smooth
    rows(end+1, :) = {"SmoothMs", "Smooth (ms):", @(gr) uieditfield(gr, "numeric", "Value", 1000 * def.bins.SmoothSec, ...
        "Limits", [0 Inf], "Tooltip", "The Gaussian smoothing's SD, ms (0 = none).")};
end
end


function row = measureRow(def)
%measureRow  Measure: rate, count or probability (DEF's measure).
row = {"Measure", "Measure:", @(gr) uidropdown(gr, "Items", ["rate (spikes/s)" "count" "probability"], ...
    "ItemsData", ["rate" "count" "probability"], "Value", among(def.measure, ["rate" "count" "probability"]), ...
    "Tooltip", "What the panel shows of the spikes.")};
end


function v = among(v, allowed)
%among  V when ALLOWED has it, else ALLOWED's first (a remembered value the dataset or the list lacks).
v = string(v);
if ~(isscalar(v) && ismember(v, allowed)); v = allowed(1); end
end


function row = freqRow(def)
%freqRow  Frequency range (Hz): fpass.
row = {"FreqFrom", "Frequency (Hz):", @(gr) pair(gr, def.fpass, "to", "The frequencies shown, Hz (Inf = Nyquist).")};
end


function h = pair(gr, v, word, tip)
%pair  Two numeric fields with WORD between them in a grid of their own (Tags "first" and "second").
h = uigridlayout(gr, [1 3], "ColumnWidth", {'1x', 'fit', '1x'}, "Padding", [0 0 0 0], "ColumnSpacing", 6);
uieditfield(h, "numeric", "Value", v(1), "Tag", "first", "Tooltip", tip);
uilabel(h, "Text", word);
uieditfield(h, "numeric", "Value", v(2), "Tag", "second", "Tooltip", tip);
end


function syncBinding(P, t, observed)
%syncBinding  The binding open where the first layer's source may follow the observation (OBSERVED) on type T, else fixed.
rows = "items";
if isfield(P, 'Rows'); rows = string(P.Rows.Value); end
ok = figureEditorChoices(t, string(P.Source.Value), rows, Observed=observed).Bindable;
if ~ok; P.Binding.Value = "fixed"; end
P.Binding.Enable = matlab.lang.OnOffSwitchState(ok);
end


function rowsChanged(P, t, observed)
%rowsChanged  A heat map of one unit's epochs follows the observation by default (a fixed layer keeps every unit).
if string(P.Rows.Value) == "trials"; P.Binding.Value = "observation"; end
syncBinding(P, t, observed);
end


function c = gatherParams(P, t)
%gatherParams  What the parameters say, as onNewPanel's options: Source, Partner, Binding, Lines and Options (Set "", Alignment "figure").
c = struct('Source', "", 'Partner', "", 'Binding', "", 'Lines', string.empty(1, 0), 'Options', struct(), ...
    'Set', "", 'Alignment', "figure");
o = struct();
if isfield(P, 'Source'); c.Source = string(P.Source.Value); end
if isfield(P, 'Partner'); c.Partner = string(P.Partner.Value); end
if isfield(P, 'Binding'); c.Binding = string(P.Binding.Value); end
if isfield(P, 'Lines')
    v = P.Lines.Value;
    if isa(P.Lines, 'matlab.ui.control.EditField'); v = split(strtrim(string(v))); end
    v = reshape(string(v), 1, []);
    c.Lines = v(v ~= "");
end
if isfield(P, 'Sort'); o.rasterSort = string(P.Sort.Value); end
if isfield(P, 'BinMs'); o.bins.BinSec = P.BinMs.Value / 1000; end
if isfield(P, 'SmoothMs'); o.bins.SmoothSec = P.SmoothMs.Value / 1000; end
if isfield(P, 'Measure'); o.measure = string(P.Measure.Value); end
if isfield(P, 'Display'); o.display = string(P.Display.Value); end
if isfield(P, 'Stack'); o.stack = string(P.Stack.Value); end
if isfield(P, 'ErrorType'); o.errorType = string(P.ErrorType.Value); end
if isfield(P, 'Rows'); o.rows = string(P.Rows.Value); end
if isfield(P, 'Layout'); o.layout = string(P.Layout.Value); end
if isfield(P, 'Value'); o.value = string(P.Value.Value); end
if isfield(P, 'Metric'); o.metric = string(P.Metric.Value); end
if isfield(P, 'Correlation'); o.correlation = string(P.Correlation.Value); end
if isfield(P, 'Param'); o.param = strtrim(string(P.Param.Value)); end
if isfield(P, 'Series'); o.seriesParam = strtrim(string(P.Series.Value)); end
if isfield(P, 'FreqFrom'); o.fpass = [P.FreqFrom.Value P.FreqTo.Value]; end
if isfield(P, 'Scale'); o.scale = string(P.Scale.Value); end
if isfield(P, 'WinSec'); o.movingwin = [P.WinSec.Value P.StepSec.Value]; end
c.Options = o;
if t == "eventTrace"; c.Source = ""; end
end


function img = setThumbnail(iconDir, B)
%setThumbnail  The tile's picture of saved figure B: each panel's type picture where the panel sits in B's grid (rows and columns in proportion).
H = 84; W = 112;
img = ones(H, W, 3);
G = B.grid;
nr = max(1, round(double(G.rows)));
nc = max(1, round(double(G.cols)));
rh = sizes(G.rowHeights, nr);
cw = sizes(G.colWidths, nc);
yb = round([0 cumsum(rh)] / sum(rh) * H);   % the rows' and columns' edges, px
xb = round([0 cumsum(cw)] / sum(cw) * W);
for p = reshape(B.panels, 1, [])
    r1 = min(max(p.row, 1), nr); r2 = min(max(p.row + p.rowSpan - 1, r1), nr);
    c1 = min(max(p.col, 1), nc); c2 = min(max(p.col + p.colSpan - 1, c1), nc);
    ys = yb(r1) + 1 + (r1 > 1); ye = yb(r2 + 1) - (r2 < nr);   % a px apart from a neighbor
    xs = xb(c1) + 1 + (c1 > 1); xe = xb(c2 + 1) - (c2 < nc);
    if ye < ys || xe < xs; continue; end
    img(ys:ye, xs:xe, :) = imresize(iconImage(iconDir, p.type), [ye - ys + 1, xe - xs + 1]);
end
img = min(max(img, 0), 1);
end


function s = sizes(v, n)
%sizes  N relative sizes: V when it holds N positive numbers, else equal ones.
s = ones(1, n);
v = reshape(double(v), 1, []);
if numel(v) == n && all(isfinite(v) & v > 0); s = v; end
end


function img = iconImage(iconDir, t)
%iconImage  Panel type T's picture as an RGB array in [0, 1]: its PNG (white under its transparent parts), else the placeholder.
f = fullfile(iconDir, t + ".png");
img = thumbnail(iconDir, t);
if ~isfile(f); return; end
[x, ~, alpha] = imread(f);
x = unitScale(x);
if size(x, 3) == 1; x = repmat(x, 1, 1, 3); end
if ~isempty(alpha)
    a = unitScale(alpha);
    x = x .* a + (1 - a);
end
img = x;
end


function x = unitScale(x)
%unitScale  Image data X as doubles in [0, 1] (an integer class by its range).
if isinteger(x)
    x = double(x) / double(intmax(class(x)));
else
    x = double(x);
end
end


function img = thumbnail(iconDir, t)
%thumbnail  The tile's picture of panel type T: its PNG under ICONDIR, else a gray placeholder (a framed plot area).
f = fullfile(iconDir, t + ".png");
if isfile(f)
    img = char(f);
    return
end
img = repmat(reshape([0.93 0.93 0.93], 1, 1, 3), 84, 112);
img([8 77], 10:103, :) = 0.6;
img(8:77, [10 103], :) = 0.6;
x = round(linspace(14, 99, 40));
y = round(60 - 30 * sin(linspace(0, 2 * pi, 40)) .* linspace(1, 0.3, 40));
for i = 1:numel(x)
    img(y(i) + (0:1), x(i), :) = repmat(reshape([0.2 0.4 0.75], 1, 1, 3), 2, 1);
end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
