classdef FigureDataTips
    %FigureDataTips  Data tips on a drawn figure that say what a point is: its quantity, trial, unit and dataset.
    %   renderFigure gives the parts it draws in a visible figure data tips
    %   (its DataTips option) through FigureDataTips.attach: instead of a
    %   bare X and Y a tip names the quantities with their units (Time from
    %   Stim onset: 0.125 s, Rate: 42.1 Hz), and says which trial, trial
    %   group, unit or channel, layer, panel, observation and dataset the
    %   point belongs to. What it knows comes from the computed figure F,
    %   the panel's axes (their labels and color bar) and the tags every
    %   part carries (tagPart: its role and group), so a new panel type
    %   gets sensible tips without code of its own.
    %
    %   Fields (FigureDataTips.fields: Key, Label, Section, Default, Description)
    %     Point   x, y (the axes' quantities and units; a time panel's x
    %             is the time from its event), value (a heat map cell's or
    %             a probe site's, in its color bar's unit; a PSTH's latency
    %             box plot part: its median, quartiles, whiskers, outliers
    %             and n), row (a heat map row's label: unit, channel or
    %             epoch)
    %     Trial   trial (a raster tick's, stop dot's, first-spike mark's or
    %             mark's trial, a
    %             heat map row of trials'), trialGroup (that trial's group,
    %             or the trace's), parameters (the trial's parameter values)
    %     Source  series (the unit, channel or event a trace draws), layer,
    %             panel (its id and type), observation, dataset, part (what
    %             was drawn: PSTH, Error band, Raster ticks, ...)
    %   The user picks the fields (DataTipFieldsDialog: the figure's
    %   right-click "Data tip fields...", or the analysis app's Design
    %   menu). The choice is a preference (AppPrefs group "FigureDataTips",
    %   "Fields": the keys shown), used by every figure drawn after and, on
    %   OK, by every figure on screen (refresh). No field ticked gives
    %   MATLAB's own X and Y.
    %
    %   How the tips are shown: an object with a DataTipTemplate (plot
    %   lines, scatter, bar, error bars, box charts) gets its rows
    %   (dataTipTextRow: property rows with a format in the quantity's
    %   unit, per-point vectors as long as its data, constant text as a
    %   one-category categorical); the others (line() objects such as
    %   raster ticks, images, patches), which have no template in R2025a,
    %   get theirs from the figure's data cursor UpdateFcn (onUpdate),
    %   which writes the same rows (tipText). A template wins over the
    %   UpdateFcn; parts without tip information that other code drew in
    %   the same figure get a plain X / Y tip from it.
    %
    %     T = FigureDataTips.fields()
    %     keys = FigureDataTips.chosen()          the keys shown
    %     FigureDataTips.setChosen(KEYS)          [] = the defaults again
    %     n = FigureDataTips.attach(F, SPEC, H)   tips on what renderFigure drew (H: its output); n parts
    %     n = FigureDataTips.refresh(TARGET)      the chosen fields again on the parts in TARGET (default: every figure)
    %     L = FigureDataTips.tipText(OBJ, I)      the tip of OBJ's point I (an image: [x y]) as lines "Label: value"
    %
    %   See also DataTipFieldsDialog, renderFigure, tagPart, PlotAesthetics, AppPrefs.

    properties (Constant)
        PrefGroup = "FigureDataTips"    % AppPrefs group: Fields, the keys shown
        InfoKey = "FigureDataTip"       % appdata of each part given tips: what its tip can say
        MenuTag = "FigureDataTipsMenu"
    end

    methods (Static)
        function T = fields()
            %fields  Every field a tip can show: Key, Label, Section, Default (shown until the user chooses), Description.
            x = [ ...
                "x"           "X value"            "Point"  "1" "The x position with its axis' quantity and unit: time from the event, frequency, a parameter"
                "y"           "Y value"            "Point"  "1" "The y value with its quantity and unit: rate, z-score, µV, power, coherence"
                "value"       "Cell value"         "Point"  "1" "A heat map, spectrogram or probe map value, in its color bar's unit"
                "row"         "Row"                "Point"  "1" "A heat map row's label: its unit, channel or epoch"
                "trial"       "Trial"              "Trial"  "1" "The trial of a raster tick, stop dot or event mark, or of a heat map row of trials"
                "trialGroup"  "Trial group"        "Trial"  "1" "That trial's group, or the trial group a trace or band draws"
                "parameters"  "Trial parameters"   "Trial"  "0" "The trial's parameter values (the group-by parameters and the columns the figure reads)"
                "series"      "Unit / channel"     "Source" "1" "The unit, channel, event or series a trace draws"
                "layer"       "Layer"              "Source" "1" "The panel's layer the part draws"
                "panel"       "Panel"              "Source" "1" "The panel's id and type"
                "observation" "Observation"        "Source" "1" "The figure's observation: its unit, channel or the dataset"
                "dataset"     "Dataset"            "Source" "1" "The dataset (or sessions) the figure draws"
                "part"        "Part"               "Source" "0" "What was drawn: PSTH, Error band, Raster ticks, Image, ..."];
            T = table(x(:, 1), x(:, 2), x(:, 3), x(:, 4) == "1", x(:, 5), ...
                'VariableNames', ["Key" "Label" "Section" "Default" "Description"]);
        end

        function keys = chosen()
            %chosen  The keys of the fields shown: the user's choice (preferences), else the defaults.
            T = FigureDataTips.fields();
            keys = T.Key(T.Default).';
            try
                if AppPrefs.ispref(FigureDataTips.PrefGroup, "Fields")
                    v = string(AppPrefs.getpref(FigureDataTips.PrefGroup, "Fields"));
                    keys = T.Key(ismember(T.Key, v)).';   % in the table's order; unknown keys dropped
                end
            catch
            end
        end

        function setChosen(keys)
            %setChosen  Keep KEYS as the fields shown (preferences); [] forgets the choice (the defaults again).
            %   Errors (FigureDataTips:BadField) on a key fields does not list.
            if isempty(keys) && ~isstring(keys)
                AppPrefs.rmpref(FigureDataTips.PrefGroup, "Fields");
                return
            end
            keys = reshape(string(keys), 1, []);
            T = FigureDataTips.fields();
            bad = keys(~ismember(keys, T.Key));
            if ~isempty(bad)
                error('FigureDataTips:BadField', 'No data tip field "%s"; the fields are %s.', bad(1), strjoin(T.Key, ", "));
            end
            AppPrefs.setpref(FigureDataTips.PrefGroup, "Fields", T.Key(ismember(T.Key, keys)).');
        end

        function n = attach(F, spec, h)
            %attach  Data tips on every part renderFigure drew: H is its output, F and SPEC what it drew.
            %   Each part's tip information is kept on it (appdata InfoKey),
            %   so refresh can show other fields without F. The figure's
            %   right-click menus (PlotAesthetics', when it is editable) get
            %   "Data tip fields...". N: the parts given tips.
            n = 0;
            if ~isstruct(h) || ~isfield(h, 'panels') || isempty(h.panels); return; end
            keys = FigureDataTips.chosen();
            PT = EphysAnalysisConfig.panelTypes();
            src = sourceRows(F);
            fig = [];
            for k = 1:numel(h.panels)
                hp = h.panels(k);
                axs = [reshape(hp.axes, 1, []) reshape(hp.extraAxes, 1, [])];
                axs = axs(isgraphics(axs));
                if isempty(axs) || k > numel(F.panels) || k > numel(spec.panels); continue; end
                ctx = panelContext(F, spec.panels(k), F.panels(k), PT, src);
                for ax = axs
                    if isempty(fig); fig = ancestor(ax, 'figure'); end
                    for o = tipObjects(ax)
                        I = objectInfo(o, ax, ctx);
                        setappdata(o, FigureDataTips.InfoKey, I);
                        applyRows(o, I, keys);
                        n = n + 1;
                    end
                end
            end
            if n == 0 || isempty(fig); return; end
            useUpdateFcn(fig);
            addMenus(fig, [h.panels.axes]);
        end

        function n = refresh(target)
            %refresh  Show the chosen fields on the tips of the parts in TARGET (default: every open figure).
            if nargin < 1 || isempty(target); target = groot; end
            objs = findall(target, '-function', @(o) isappdata(o, FigureDataTips.InfoKey));
            keys = FigureDataTips.chosen();
            n = 0;
            for o = reshape(objs, 1, [])
                I = getappdata(o, FigureDataTips.InfoKey);
                if ~isstruct(I); continue; end
                applyRows(o, I, keys);
                n = n + 1;
            end
        end

        function L = tipText(obj, idx)
            %tipText  The tip of point IDX of OBJ (an image: IDX = [x y] of the point) as lines "Label: value".
            %   A part without tip information (not drawn by renderFigure)
            %   gives X and Y.
            if ~isappdata(obj, FigureDataTips.InfoKey)
                L = plainText(obj, idx);
                return
            end
            I = getappdata(obj, FigureDataTips.InfoKey);
            R = tipRows(obj, I, FigureDataTips.chosen());
            if isempty(R)
                L = plainText(obj, idx);
                return
            end
            L = strings(numel(R), 1);
            for r = 1:numel(R)
                L(r) = R(r).label + ": " + valueText(obj, R(r), idx, I);
            end
        end
    end

    methods (Static, Hidden)
        function txt = onUpdate(~, ev)
            %onUpdate  The figure's data cursor UpdateFcn: a renderFigure part's tip from its rows, else X and Y.
            obj = ev.Target;
            try
                if isa(obj, 'matlab.graphics.primitive.Image') || isa(obj, 'matlab.graphics.primitive.Surface')
                    idx = ev.Position(1:2);
                else
                    idx = ev.DataIndex;
                end
                txt = cellstr(FigureDataTips.tipText(obj, idx));
            catch
                p = ev.Position;
                txt = {sprintf('X: %.4g', p(1)), sprintf('Y: %.4g', p(2))};
            end
        end

        function onMenu(menu, ~)
            %onMenu  "Data tip fields...": the dialog over the figure the menu belongs to.
            try
                DataTipFieldsDialog(Parent=ancestor(menu, 'figure'));
            catch ME
                fig = ancestor(menu, 'figure');
                if ~isempty(fig); uialert(fig, ME.message, 'Data tip fields'); end
            end
        end
    end
end


%% --- what a panel and a part can tell ------------------------------------------
function S = sourceRows(F)
%sourceRows  The figure's dataset and observation, as tip text.
S = struct('dataset', "", 'observation', "", 'obsKind', "");
if isfield(F, 'dataset'); S.dataset = strjoin(string(F.dataset), ", "); end
if isfield(F, 'nSessions') && S.dataset == ""; S.dataset = sprintf('%d sessions', F.nSessions); end
obs = [];
if isfield(F, 'observation'); obs = F.observation; end
if istable(obs) && height(obs) > 0; obs = table2struct(obs(1, :)); end
if isstruct(obs) && isfield(obs, 'kind')
    S.obsKind = string(obs.kind);
    if isfield(obs, 'label') && string(obs.label) ~= "" && S.obsKind ~= "dataset"
        S.observation = string(obs.label) + " (" + S.obsKind + ")";
    else
        S.observation = S.obsKind;
    end
    if isfield(obs, 'groupLabel') && string(obs.groupLabel) ~= ""
        S.observation = S.observation + " · " + string(obs.groupLabel);
    end
end
end


function C = panelContext(F, p, P, PT, src)
%panelContext  What every part of one panel shares: its name, time axis, groups, epochs and layers.
C = struct();
C.src = src;
C.type = string(p.type);
row = PT.Type == C.type;
label = C.type;
if any(row); label = string(PT.Label(row)); end
C.panel = string(p.id) + " (" + label + ")";
C.isTime = any(row) && PT.SharesTime(row);
if C.type == "coherence" && isfield(p.options, 'overTime') && p.options.overTime
    C.isTime = isfield(p.options, 'timeBase') && p.options.timeBase == "aligned";
end
C.event = "";
if isfield(p, 'ref') && isstruct(p.ref)
    try
        C.event = eventRefLabel(p.ref);
    catch
    end
end
C.groups = strings(1, 0);
G = [];
if isfield(P, 'groups') && istable(P.groups); G = P.groups; elseif istable(F.groups); G = F.groups; end
if istable(G) && ismember('label', G.Properties.VariableNames); C.groups = reshape(string(G.label), 1, []); end
C.epochs = [];
if isfield(P, 'epochs') && istable(P.epochs); C.epochs = P.epochs; elseif istable(F.epochs); C.epochs = F.epochs; end
C.layers = P.layers;
end


function objs = tipObjects(ax)
%tipObjects  The parts of an axes a tip can point at: data objects (no text, constant lines or legend stand-ins).
kids = allchild(ax);
keep = false(size(kids));
for i = 1:numel(kids)
    o = kids(i);
    if ~isprop(o, 'XData') || isa(o, 'matlab.graphics.primitive.Text'); continue; end
    x = o.XData;
    if ~isnumeric(x) || isempty(x) || all(isnan(x(:)))
        if ~(isa(o, 'matlab.graphics.chart.primitive.BoxChart')); continue; end
    end
    keep(i) = true;
end
objs = reshape(kids(keep), 1, []);
end


function I = objectInfo(o, ax, C)
%objectInfo  What the tip of part O can say: its quantities, constant rows and per-point rows.
role = string(o.Tag);
group = "";
if isappdata(o, 'PlotGroup'); group = string(getappdata(o, 'PlotGroup')); end
I = struct('kind', "xy", 'template', isprop(o, 'DataTipTemplate'), 'box', isa(o, 'matlab.graphics.chart.primitive.BoxChart'), ...
    'x', qty("", ""), 'showX', true, 'y', qty("", ""), 'showY', true, 'yOffset', 0, 'value', qty("", ""), 'showValue', false, ...
    'rowName', "Row", 'rowLabels', strings(0, 1), 'const', repmat(struct('key', "", 'label', "", 'text', ""), 1, 0), ...
    'point', repmat(struct('key', "", 'label', "", 'value', []), 1, 0), 'rowPoint', repmat(struct('key', "", 'label', "", 'value', []), 1, 0));
if isa(o, 'matlab.graphics.primitive.Image') || isa(o, 'matlab.graphics.primitive.Surface'); I.kind = "image"; end

% the quantities: the axes' labels, a time panel's x as the time from its event
I.x = labelQty(ax.XLabel.String);
if C.isTime && ~(isfield(I.x, 'unit') && I.x.unit == "ms")
    I.x = qty("Time", "s");
    if C.event ~= ""; I.x.name = "Time from " + C.event; end
elseif I.x.name == ""
    I.showX = strcmp(ax.XTickLabelMode, 'auto');   % a categorical axis (a rate panel's groups): its position says nothing
    I.x.name = "X";
end
I.y = unitOnly(labelQty(ax.YLabel.String), C.type);
if I.y.name == ""; I.y.name = "Y"; end
inset = startsWith(role, "wave") && C.type ~= "waveforms";   % a waveform inset: drawn in the panel's units, not data
if inset || (C.type == "waveforms" && strjoin(string(ax.XLabel.String), "") ~= "Time (ms)")
    I.showX = false;
    I.showY = false;
end
if ismember(role, ["rasterTicks" "rasterStop" "rasterEvent" "rasterBand" "stackBase" "firstSpike"]) || strcmp(ax.Tag, 'rasterAxes')
    I.showY = false;   % rows, not a quantity: the trial says it
end
if startsWith(role, "latency")   % a PSTH's latency box plot: its height is a lane, not a rate
    I.showY = false;
end
if I.kind == "image"
    I.showY = false;
    I.showValue = true;
    I.value = unitOnly(colorbarQty(ax), C.type);
    I.rowName = I.y.name;
    if I.rowName == "Y"; I.rowName = "Row"; end
    I.rowLabels = imageRowLabels(o, ax);
elseif isa(o, 'matlab.graphics.chart.primitive.Scatter') && numel(o.CData) == numel(o.XData) && numel(o.XData) > 1
    I.showValue = true;
    I.value = unitOnly(colorbarQty(ax), C.type);
end
I.yOffset = stackOffset(o, ax, group, I);

% the source: series and trial group from the part's group, its layer, the panel, observation, dataset
[series, tg] = splitGroup(group, C.groups, role);
if ismember(role, ["image" "colorbar"]) && I.kind == "image"
    layerName = group;   % a map's group is its layer's name (or its trial group's label)
    if any(C.groups == group); layerName = ""; tg = group; end
    series = "";
else
    layerName = "";
end
if layerName == ""; layerName = layerOf(C.layers, series); end
seriesLabel = "Unit / channel";
if ismember(role, ["rasterEvent" "eventLine" "eventRug"]); seriesLabel = "Event"; end
I.const = addConst(I.const, "trialGroup", "Trial group", tg);
I.const = addConst(I.const, "series", seriesLabel, series);
I.const = addConst(I.const, "layer", "Layer", layerName);
I.const = addConst(I.const, "panel", "Panel", C.panel);
I.const = addConst(I.const, "observation", "Observation", C.src.observation);
I.const = addConst(I.const, "dataset", "Dataset", C.src.dataset);
I.const = addConst(I.const, "part", "Part", PlotAesthetics.roleLabel(role));
if isappdata(o, 'LatencyStats')   % a latency box plot's part: its statistics, in the Cell value field
    I.const = addConst(I.const, "value", "First-spike latency", latencyText(getappdata(o, 'LatencyStats')));
end

% per point: a raster part's trials, a heat map of trials' rows
if ismember(role, ["rasterTicks" "rasterStop" "rasterEvent" "firstSpike"])
    [ep, unitLabel, lay] = rasterEpochs(o, role, C.layers, group);
    if ~isempty(ep)
        I.point = trialRows(ep, lay, C);
        if unitLabel ~= "" && ~any([I.const.key] == "series")
            I.const = addConst(I.const, "series", "Unit / channel", unitLabel);
        end
        if lay ~= "" && ~any([I.const.key] == "layer"); I.const = addConst(I.const, "layer", "Layer", lay); end
        I.const = I.const([I.const.key] ~= "trialGroup");   % the point's own group
    end
elseif I.kind == "image" && C.type == "heatmap"
    for j = 1:numel(C.layers)
        R = C.layers(j).R;
        if C.layers(j).skip ~= "" || ~isstruct(R) || ~isfield(R, 'trialMatrix') || ~isfield(R, 'trialOrder'); continue; end
        if size(o.CData, 1) ~= numel(R.trialOrder); continue; end
        S = struct('epoch', R.trialOrder(:), 'group', R.trialGroup(R.trialOrder(:)), 'groupLabels', reshape(string(R.groups.label), 1, []));
        I.rowPoint = trialRows(S, C.layers(j).name, C);
        I.const = I.const([I.const.key] ~= "trialGroup");
        I.rowName = "Epoch";
        I.rowLabels = strings(0, 1);
        break
    end
end
[~, order] = ismember([I.const.key], FigureDataTips.fields().Key);   % the fields' order, whatever was found first
[~, order] = sort(order);
I.const = I.const(order);
end


function q = unitOnly(q, type)
%unitOnly  A label that is a unit alone ("spikes/s", "Hz", "µV"): the panel type's quantity in that unit.
if q.unit ~= "" || q.name == "" || ~(contains(q.name, "/") || ismember(q.name, ["Hz" "s" "ms" "µV" "uV" "mV" "dB" "spikes" "%"]))
    return
end
names = struct('psth', "Rate", 'rate', "Rate", 'tuning', "Rate", 'continuous', "Amplitude", 'spectrum', "Power");
name = "Value";
if isvarname(type) && isfield(names, type); name = names.(type); end
q = qty(name, q.name);
end


function q = qty(name, unit)
q = struct('name', string(name), 'unit', string(unit));
end


function q = labelQty(s)
%labelQty  A quantity from an axis label: "Rate (Hz)" is Rate in Hz; a label whose parentheses say more (Epoch (by level)) has no unit.
s = strtrim(strjoin(string(s), " "));
q = qty(s, "");
if s == ""; return; end
tok = regexp(s, '^(.*\S)\s*\(([^()]{1,12})\)$', 'tokens', 'once');
if ~isempty(tok) && ~contains(strtrim(tok{2}), " ")
    q = qty(tok{1}, strtrim(tok{2}));
end
end


function q = colorbarQty(ax)
%colorbarQty  The quantity an axes' color bar shows (its label), else Value.
q = qty("Value", "");
cb = [];
try
    cb = ax.Colorbar;
catch
end
if isempty(cb) || ~isgraphics(cb)   % a color bar placed in a layout's tile is still the axes'
    fig = ancestor(ax, 'figure');
    bars = findall(fig, 'Type', 'colorbar');
    for c = reshape(bars, 1, [])
        try
            if isequal(c.Axes, ax); cb = c; break; end
        catch
        end
    end
end
if ~isempty(cb) && isgraphics(cb)
    q = labelQty(cb.Label.String);
    if q.name == ""; q.name = "Value"; end
end
end


function L = imageRowLabels(o, ax)
%imageRowLabels  An image's row labels from its y tick labels, when there is one per row.
L = strings(0, 1);
n = size(o.CData, 1);
y = o.YData;
if n < 1 || numel(y) < 1; return; end
yc = linspace(y(1), y(end), n);
if numel(y) == n; yc = y(:).'; end
tk = ax.YTick;
lab = string(ax.YTickLabel);
if numel(tk) ~= n || numel(lab) ~= n || any(abs(sort(tk(:)) - sort(yc(:))) > 1e-9); return; end
L = strings(n, 1);
for r = 1:n
    [~, i] = min(abs(tk - yc(r)));
    L(r) = lab(i);
end
end


function off = stackOffset(o, ax, group, I)
%stackOffset  A trace drawn in a stack's row (a stacked PSTH or continuous panel): the row's base, taken off its y.
off = 0;
if I.kind == "image" || ~I.showY || ~isprop(o, 'YData'); return; end
kids = allchild(ax);
bases = kids(strcmp(get(kids, 'Tag'), 'stackBase'));
for b = reshape(bases, 1, [])
    if isappdata(b, 'PlotGroup') && string(getappdata(b, 'PlotGroup')) ~= "" && endsWith(group, string(getappdata(b, 'PlotGroup')))
        off = b.YData(1);
        return
    end
end
if ~isempty(bases) || ~strcmp(ax.YTickLabelMode, 'manual'); return; end
lab = string(ax.YTickLabel);
tk = ax.YTick;
parts = split(group, " · ");
for i = 1:numel(lab)   % a continuous stack: each item's row is at its tick, labeled with its name
    if i <= numel(tk) && lab(i) ~= "" && any(parts == lab(i))
        off = tk(i);
        return
    end
end
end


function [series, tg] = splitGroup(group, groups, role)
%splitGroup  A part's group as its series (unit, channel, event) and its trial group: "<item> · <group>", or either alone.
series = "";
tg = "";
if group == ""; return; end
parts = strtrim(split(group, " · ")).';
isG = ismember(parts, groups);
if any(isG); tg = strjoin(parts(isG), " · "); end
rest = parts(~isG);
if ~isempty(rest); series = strjoin(rest, " · "); end
if ismember(role, ["overlayLine" "overlayRegion"]); series = group; tg = ""; end
end


function name = layerOf(layers, series)
%layerOf  The layer a part draws: the panel's only computed one, else the one whose name or units name its series.
name = "";
ok = false(1, numel(layers));
for j = 1:numel(layers); ok(j) = layers(j).skip == "" && isstruct(layers(j).R); end
if nnz(ok) == 1
    name = string(layers(find(ok, 1)).name);
    return
end
if series == ""; return; end
for j = find(ok)
    R = layers(j).R;
    hit = string(layers(j).name) == series;
    if ~hit && isfield(R, 'labels')
        lab = string(R.labels);
        hit = any(lab == series) || any(shortUnitLabels(lab) == series);
    end
    if hit
        name = string(layers(j).name);
        return
    end
end
end


function C = addConst(C, key, label, text)
text = string(text);
if ~isscalar(text) || ismissing(text) || text == ""; return; end
C(end+1) = struct('key', key, 'label', string(label), 'text', text);
end


function [S, unitLabel, layName] = rasterEpochs(o, role, layers, group)
%rasterEpochs  The epoch of each point of a raster part, found by its times among the panel's raster layers.
%   A tick line holds three points per spike (x, x, NaN), in the order of
%   R.raster(u).times of the epochs in its group (GROUP, the line's
%   label; every epoch if it names none); a stop line the epochs' stop latencies in the
%   window; an event mark's line its events' latencies in the window; a
%   first-spike line its epochs in appdata PlotEpochs (rasterInto).
S = [];
unitLabel = "";
layName = "";
x = o.XData(:);
for j = 1:numel(layers)
    R = layers(j).R;
    if layers(j).skip ~= "" || ~isstruct(R) || ~isfield(R, 'raster') || isempty(R.raster); continue; end
    gl = reshape(string(R.groups.label), 1, []);
    switch role
        case "rasterTicks"
            for u = 1:numel(R.raster)
                t = R.raster(u).times(:);
                ep = R.raster(u).epoch(:);
                gi = find(gl == group, 1);
                if ~isempty(gi)   % one group's ticks
                    in = groupOf(R, ep) == gi;
                    t = t(in);
                    ep = ep(in);
                end
                if numel(x) ~= 3 * numel(t) || ~isequal(x(1:3:end), t); continue; end
                ep3 = reshape(repmat(ep.', 3, 1), [], 1);
                ep3(3:3:end) = NaN;
                S = struct('epoch', ep3, 'group', groupOf(R, ep3), 'groupLabels', gl);
                names = shortUnitLabels(string(R.labels));
                if u <= numel(names); unitLabel = names(u); end
                layName = string(layers(j).name);
                return
            end
        case "firstSpike"
            ep = [];
            if isappdata(o, 'PlotEpochs'); ep = double(reshape(getappdata(o, 'PlotEpochs'), [], 1)); end
            if numel(ep) ~= numel(x) || any(ep < 1 | ep > numel(R.epochGroup)); continue; end
            S = struct('epoch', ep, 'group', groupOf(R, ep), 'groupLabels', gl);
            layName = string(layers(j).name);
            return
        case "rasterStop"
            if ~isfield(R, 'epochStop'); continue; end
            W = R.edges([1 end]);
            stop = R.epochStop(:);
            ok = isfinite(stop) & stop >= W(1) & stop <= W(2);
            if isequal(x, stop(ok))
                ep = find(ok);
                S = struct('epoch', ep, 'group', groupOf(R, ep), 'groupLabels', gl);
                return
            end
        otherwise   % rasterEvent: the marks of the panel's events layers
            W = R.edges([1 end]);
            for jj = 1:numel(layers)
                Re = layers(jj).R;
                if layers(jj).skip ~= "" || ~isstruct(Re) || ~isfield(Re, 'marks') || isempty(Re.marks); continue; end
                for m = 1:numel(Re.marks)
                    ev = Re.marks(m);
                    ok = ev.t >= W(1) & ev.t <= W(2);
                    if numel(x) == nnz(ok) && isequal(x, reshape(ev.t(ok), [], 1))
                        ep = reshape(ev.epoch(ok), [], 1);
                        S = struct('epoch', ep, 'group', groupOf(R, ep), 'groupLabels', gl);
                        return
                    end
                end
            end
    end
end
end


function s = latencyText(S)
%latencyText  A latency box plot's statistics as one line: "median 12.5 ms, quartiles 8-20 ms, whiskers 4-31 ms, 2 outliers; n = 37 of 40 epochs".
ms = @(v) string(sprintf('%.3g', 1000 * v));
s = "median " + ms(S.q(2)) + " ms, quartiles " + ms(S.q(1)) + "-" + ms(S.q(3)) + " ms, whiskers " + ms(S.whiskers(1)) + ...
    "-" + ms(S.whiskers(2)) + " ms";
if S.nOutliers > 0; s = s + sprintf(", %d outlier%s", S.nOutliers, repmat('s', 1, S.nOutliers ~= 1)); end
s = s + sprintf("; n = %d of %d epochs", S.n, S.nEpochs);
end


function g = groupOf(R, ep)
%groupOf  Each epoch's group index (NaN where the epoch is NaN).
g = NaN(size(ep));
ok = isfinite(ep) & ep >= 1 & ep <= numel(R.epochGroup);
g(ok) = R.epochGroup(ep(ok));
end


function P = trialRows(S, ~, C)
%trialRows  Per-point rows of trials: the trial number (else the epoch), its group, its parameters.
P = repmat(struct('key', "", 'label', "", 'value', []), 1, 0);
ep = double(S.epoch(:));
E = C.epochs;
okE = istable(E) && height(E) >= max([ep(isfinite(ep)); 0]);
num = ep;
label = "Epoch";
if okE && ismember('trial', E.Properties.VariableNames)
    tr = NaN(size(ep));
    ok = isfinite(ep);
    tr(ok) = double(E.trial(ep(ok)));
    if any(isfinite(tr)); num = tr; label = "Trial"; end
end
P(end+1) = struct('key', "trial", 'label', label, 'value', num.');
g = double(S.group(:));
labels = string(S.groupLabels);
if numel(labels) > 1
    gc = strings(size(g));
    ok = isfinite(g) & g >= 1 & g <= numel(labels);
    gc(ok) = labels(g(ok));
    gc(~ok) = missing;
    P(end+1) = struct('key', "trialGroup", 'label', "Trial group", 'value', categorical(gc.'));
end
if ~okE; return; end
std = ["epoch" "trial" "t0" "t0Continuous" "t1" "tStart" "tStop" "duration" "complete" "artifact" "groupIndex" "group"];
names = string(E.Properties.VariableNames);
names = names(~ismember(names, std));
ok = isfinite(ep);
for v = names(1:min(end, 8))
    col = E.(v);
    if size(col, 2) ~= 1; continue; end
    if isnumeric(col) || islogical(col)
        val = NaN(size(ep));
        val(ok) = double(col(ep(ok)));
        val = val.';
    else
        sv = strings(size(ep));
        sv(ok) = string(col(ep(ok)));
        sv(~ok) = missing;
        val = categorical(sv.');
    end
    P(end+1) = struct('key', "parameters", 'label', v, 'value', val); %#ok<AGROW>
end
end


%% --- the rows shown -------------------------------------------------------------
function R = tipRows(o, I, keys)
%tipRows  The rows a part's tip shows for the chosen KEYS: label, kind ("x" | "y" | "value" | "row" | "point" | "rowPoint" | "const"), value.
R = repmat(struct('label', "", 'kind', "", 'value', [], 'unit', ""), 1, 0);
on = @(k) any(keys == k);
if on("x") && I.showX; R(end+1) = struct('label', I.x.name, 'kind', "x", 'value', [], 'unit', I.x.unit); end
if on("y") && I.showY && I.kind == "xy" && ~I.box; R(end+1) = struct('label', I.y.name, 'kind', "y", 'value', [], 'unit', I.y.unit); end
if on("value") && I.showValue; R(end+1) = struct('label', I.value.name, 'kind', "value", 'value', [], 'unit', I.value.unit); end
if on("row") && I.kind == "image" && isempty(I.rowPoint)
    R(end+1) = struct('label', I.rowName, 'kind', "row", 'value', [], 'unit', "");
end
for p = I.rowPoint
    if on(p.key); R(end+1) = struct('label', p.label, 'kind', "rowPoint", 'value', p.value, 'unit', ""); end %#ok<AGROW>
end
n = numel(o.XData);
for p = I.point
    if on(p.key) && numel(p.value) == n; R(end+1) = struct('label', p.label, 'kind', "point", 'value', p.value, 'unit', ""); end %#ok<AGROW>
end
for c = I.const
    if on(c.key); R(end+1) = struct('label', c.label, 'kind', "const", 'value', c.text, 'unit', ""); end %#ok<AGROW>
end
end


function applyRows(o, I, keys)
%applyRows  Set a part's DataTipTemplate rows (when it has one) for the chosen KEYS.
if ~I.template; return; end
try
    tpl = o.DataTipTemplate;
catch
    return
end
R = tipRows(o, I, keys);
if I.box   % a box chart's own rows say what the box is; ours follow them
    base = boxRows();
else
    base = [];
end
rows = base;
for r = R
    switch r.kind
        case "x"
            rows = [rows dataTipTextRow(char(r.label), 'XData', numFormat(r.unit))]; %#ok<AGROW>
        case "y"
            if I.yOffset == 0
                rows = [rows dataTipTextRow(char(r.label), 'YData', numFormat(r.unit))]; %#ok<AGROW>
            else
                rows = [rows dataTipTextRow(char(r.label), reshape(o.YData, 1, []) - I.yOffset, numFormat(r.unit))]; %#ok<AGROW>
            end
        case "value"
            rows = [rows dataTipTextRow(char(r.label), 'CData', numFormat(r.unit))]; %#ok<AGROW>
        case "point"
            if isnumeric(r.value)
                rows = [rows dataTipTextRow(char(r.label), r.value, '%g')]; %#ok<AGROW>
            else
                rows = [rows dataTipTextRow(char(r.label), r.value)]; %#ok<AGROW>
            end
        case "const"   % one category for every point: a byte a point (a format must print the value)
            rows = [rows dataTipTextRow(char(r.label), categorical(ones(1, numel(o.XData)), 1, cellstr(r.value)))]; %#ok<AGROW>
    end
end
if isempty(rows)   % nothing chosen: MATLAB's own X and Y
    rows = [dataTipTextRow('X', 'XData') dataTipTextRow('Y', 'YData')];
end
tpl.DataTipRows = rows;
end


function rows = boxRows()
rows = [dataTipTextRow('Median', 'Median') dataTipTextRow('Quartiles', 'Quartiles') dataTipTextRow('Whiskers', 'Whiskers') ...
    dataTipTextRow('Num Points', 'Num Points')];
end


function f = numFormat(unit)
%numFormat  A number's tip format, with its unit after it.
f = '%.4g';
if unit ~= ""; f = [f ' ' escapeFormat(unit)]; end
end


function f = escapeFormat(s)
%escapeFormat  Text as part of a format: its % and \ printed as they are.
f = char(strrep(strrep(string(s), "\", "\\"), "%", "%%"));
end


function s = valueText(o, r, idx, I)
%valueText  One row's value at point IDX of part O (an image: IDX = [x y]), as text.
switch r.kind
    case "const"
        s = r.value;
        return
    case {"x" "y" "value"}
        if I.kind == "image"
            [rr, cc] = imageCell(o, idx);
            switch r.kind
                case "x", v = idx(1);
                case "y", v = idx(2);
                otherwise, v = double(o.CData(rr, cc));
            end
        else
            i = idx(1);
            switch r.kind
                case "x", v = o.XData(i);
                case "y", v = o.YData(i) - I.yOffset;
                otherwise, v = double(o.CData(min(i, numel(o.CData))));
            end
        end
        s = string(sprintf('%.4g', v));
        if r.unit ~= ""; s = s + " " + r.unit; end
    case "row"
        rr = imageCell(o, idx);
        if rr <= numel(I.rowLabels); s = I.rowLabels(rr); else; s = string(rr); end
    case {"point" "rowPoint"}
        if r.kind == "rowPoint"; i = imageCell(o, idx); else; i = idx(1); end
        v = r.value(i);
        if isnumeric(v); s = string(sprintf('%g', v)); else; s = string(v); end
        if ismissing(s); s = ""; end
end
end


function [r, c] = imageCell(o, xy)
%imageCell  The row and column of an image's cell at the point [x y].
[nr, nc] = size(o.CData, [1 2]);
X = o.XData; Y = o.YData;
c = cellIndex(xy(1), X, nc);
r = cellIndex(xy(2), Y, nr);
end


function k = cellIndex(v, lim, n)
if n <= 1 || numel(lim) < 1
    k = 1;
    return
end
if numel(lim) == n
    [~, k] = min(abs(lim(:) - v));
    return
end
d = (lim(end) - lim(1)) / (n - 1);
if d == 0; k = 1; return; end
k = min(n, max(1, round((v - lim(1)) / d) + 1));
end


function L = plainText(o, idx)
%plainText  X and Y of a point of a part without tip information.
if numel(idx) >= 2
    L = [string(sprintf('X: %.4g', idx(1))); string(sprintf('Y: %.4g', idx(2)))];
    return
end
L = [string(sprintf('X: %.4g', o.XData(idx))); string(sprintf('Y: %.4g', o.YData(idx)))];
end


%% --- the figure ------------------------------------------------------------------
function useUpdateFcn(fig)
%useUpdateFcn  The figure's data cursor writes the tips of the parts without a template (a template wins over it).
try
    dcm = datacursormode(fig);
    if ~isequal(dcm.UpdateFcn, @FigureDataTips.onUpdate)
        dcm.UpdateFcn = @FigureDataTips.onUpdate;
    end
catch
end
end


function addMenus(fig, axs)
%addMenus  "Data tip fields..." on the right-click menus of the drawn panels' parts (PlotAesthetics' menus), after "Edit aesthetics...".
menus = findall(fig, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag);
axs = axs(isgraphics(axs));
for cm = reshape(menus, 1, [])
    o = cm.UserData;
    if isempty(o) || ~isgraphics(o) || ~isempty(findobj(cm.Children, 'flat', 'Tag', FigureDataTips.MenuTag)); continue; end
    a = ancestor(o, 'axes');
    if ~isempty(a) && ~any(a == axs) && ~isa(o, 'matlab.graphics.layout.TiledChartLayout'); continue; end
    m = uimenu(cm, 'Text', 'Data tip fields...', 'Tag', FigureDataTips.MenuTag, 'MenuSelectedFcn', @FigureDataTips.onMenu);
    edit = findobj(cm.Children, 'flat', 'Text', 'Edit aesthetics...');
    if ~isempty(edit)
        kids = cm.Children;   % newest first: put it just after the editor's item
        kids(kids == m) = [];
        i = find(kids == edit(1), 1);
        cm.Children = [kids(1:i-1); m; kids(i:end)];
    end
end
end
