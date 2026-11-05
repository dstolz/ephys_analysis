classdef TrialDataExport
    %TrialDataExport  The per-trial values of a figure's trial panels as one table: copied to the clipboard, saved as CSV, or offered on the panels' right-click menus.
    %   A trial panel (trialDist, trialHist, trialScatter) computes one value
    %   per trial for each of its layers (computeTrialPanel: R.values); this
    %   class puts them in one table that a spreadsheet or a script reads.
    %
    %     T = TrialDataExport.valuesTable(F)           every trial panel of the computed figure F
    %     T = TrialDataExport.valuesTable(F, K)        panel K: its index or id (several: a list)
    %     txt = TrialDataExport.tableText(T)           T as tab-separated text, the header first
    %     txt = TrialDataExport.copy(F, K)             that text on the clipboard (K optional)
    %     file = TrialDataExport.export(F, K, FILE)    T written as CSV (writetable); FILE "" = a save dialog
    %     n = TrialDataExport.attach(F, H)             the right-click items on the trial panels renderFigure drew
    %
    %   F: EphysAnalysisRunner.computeFigure's result (a session figure's
    %   too: figureSessionCompute). T has one row per value, a layer's rows
    %   after another's, a panel's after another's, with the columns
    %     figure       F.id
    %     panel        the panel's id
    %     layer        the layer's name (by default its measure's label)
    %     measure      the measure's label with its unit ("Stim onset ->
    %                  Platform offset (ms)"; a scatter's y)
    %     dataset      the dataset the value comes from
    %     session, sessionKey  its session (1, and the dataset's key, in a
    %                  dataset's figure; a session figure's merged rows say
    %                  which)
    %     trial        the row of the dataset's trials table
    %     group, groupLabel  the trial group (the selection's: 0 / "" none)
    %     category, categoryLabel  its category (a distribution's x; the
    %                  others have one, "all")
    %     series, seriesLabel  its series (the colors)
    %     value        the measure's value, in its unit
    %     x            a scatter's x measure's value (NaN elsewhere)
    %     tA, tB       the A and B events' times, s (NaN where the measure
    %                  has none)
    %   then the trial parameters the values carry (the selection's groupBy,
    %   a category or series parameter), panels lacking one left missing.
    %   Errors: TrialDataExport:NoPanel (K names no panel of F),
    %   TrialDataExport:NotTrialPanel (K is not a trial panel).
    %
    %   attach(F, H) (renderFigure calls it in a visible, editable figure,
    %   after FigureDataTips.attach; H is renderFigure's output) adds "Copy
    %   data table" and "Export data (CSV)..." to the right-click menus
    %   (PlotAesthetics' "Edit aesthetics..." menus) of each trial panel's
    %   axes, its further axes (a scatter's marginal strips) and every part
    %   drawn in them, after "Edit aesthetics..." (PlotAesthetics.
    %   addMenuItem: made when a menu first opens). Each item reads that
    %   panel's values; the save dialog starts in the current folder with the
    %   name "<figure>_<panel>_trials.csv". A menu given them before (a part
    %   renderFigure kept: Reuse) is left as it is. N: the menus given them.
    %
    %   See also computeTrialPanel, trialMeasure, renderFigure, FigureDataTips, writetable.

    properties (Constant)
        MenuTag = "TrialDataExportMenu"   % the items' Tag, and the appdata of a menu that has them
    end

    methods (Static)
        function T = valuesTable(F, k)
            %valuesTable  One table of every value of the trial panels K of F (all of them when K is omitted or []).
            if nargin < 2; k = []; end
            idx = panelIndices(F, k);
            parts = cell(1, 0);
            for kk = idx
                P = F.panels(kk);
                for j = 1:numel(P.layers)
                    R = P.layers(j).R;
                    if P.layers(j).skip ~= "" || ~isstruct(R) || ~isfield(R, 'values') || ~istable(R.values); continue; end
                    parts{end+1} = layerTable(F, P, j, R); %#ok<AGROW>
                end
            end
            T = stackTables(parts);
        end

        function txt = tableText(T)
            %tableText  Table T as tab-separated text: the column names, then a line per row; NaN and missing as empty cells.
            names = string(T.Properties.VariableNames);
            n = height(T);
            C = strings(n, numel(names));
            for i = 1:numel(names)
                C(:, i) = cellText(T.(names(i)));
            end
            lines = strjoin(names, char(9));
            if n > 0; lines = [lines; join(C, char(9), 2)]; end
            txt = strjoin(lines, newline) + newline;
        end

        function txt = copy(F, k)
            %copy  The values of the trial panels K of F (all when omitted) on the clipboard as tab-separated text (tableText), to paste into a spreadsheet.
            if nargin < 2; k = []; end
            txt = TrialDataExport.tableText(TrialDataExport.valuesTable(F, k));
            clipboard('copy', char(txt));
        end

        function file = export(F, k, file)
            %export  The values of the trial panels K of F written to FILE as CSV (writetable; ".csv" added without an extension).
            %   FILE "" (default): a save dialog (uiputfile), starting in the
            %   current folder with the name "<figure>_<panel>_trials.csv";
            %   canceled, FILE is "" and nothing is written.
            if nargin < 2; k = []; end
            if nargin < 3; file = ""; end
            file = string(file);
            T = TrialDataExport.valuesTable(F, k);
            if file == ""
                name = string(F.id);
                idx = panelIndices(F, k);
                if isscalar(idx); name = name + "_" + string(F.panels(idx).id); end
                [f, d] = uiputfile({'*.csv', 'CSV (*.csv)'}, 'Export data', char(fullfile(pwd, name + "_trials.csv")));
                if isequal(f, 0)
                    file = "";
                    return
                end
                file = string(fullfile(d, f));
            end
            [~, ~, ext] = fileparts(file);
            if ext == ""; file = file + ".csv"; end
            writetable(T, file);
        end

        function n = attach(F, h)
            %attach  "Copy data table" and "Export data (CSV)..." on the right-click menus of each trial panel renderFigure drew (H: its output).
            n = 0;
            if ~isstruct(h) || ~isfield(h, 'panels') || ~isfield(F, 'panels'); return; end
            types = EphysAnalysisConfig.TrialPanelTypes;
            for k = 1:min(numel(h.panels), numel(F.panels))
                hp = h.panels(k);
                if ~ismember(string(hp.type), types) || ~hasValues(F.panels(k)); continue; end
                A = [reshape(hp.axes, 1, []) reshape(hp.extraAxes, 1, [])];
                A = A(isgraphics(A));
                if isempty(A); continue; end
                objs = A;
                for a = A
                    objs = [objs reshape(allchild(a), 1, [])]; %#ok<AGROW>
                end
                Fk = F;
                Fk.panels = F.panels(k);   % the menu keeps this panel's values only
                for o = objs
                    if ~isprop(o, 'ContextMenu'); continue; end
                    cm = o.ContextMenu;
                    if isempty(cm) || ~isvalid(cm) || ~strcmp(cm.Tag, PlotAesthetics.MenuTag) || isappdata(cm, TrialDataExport.MenuTag)
                        continue
                    end
                    setappdata(cm, TrialDataExport.MenuTag, true);
                    PlotAesthetics.addMenuItem(cm, @(m) TrialDataExport.menuItems(m, Fk));
                    n = n + 1;
                end
            end
        end
    end

    methods (Static, Hidden)
        function menuItems(cm, F)
            %menuItems  "Copy data table" and "Export data (CSV)..." in the right-click menu CM, for the one trial panel F holds.
            uimenu(cm, 'Text', 'Copy data table', 'Tag', TrialDataExport.MenuTag, ...
                'MenuSelectedFcn', @(~, ~) TrialDataExport.onMenu(cm, F, "copy"));
            uimenu(cm, 'Text', 'Export data (CSV)...', 'Tag', TrialDataExport.MenuTag, ...
                'MenuSelectedFcn', @(~, ~) TrialDataExport.onMenu(cm, F, "export"));
        end

        function onMenu(cm, F, what)
            %onMenu  A menu item's action: the values copied, or exported through a save dialog; a failure said over the figure.
            try
                if what == "copy"
                    TrialDataExport.copy(F, 1);
                else
                    TrialDataExport.export(F, 1, "");
                end
            catch ME
                fig = ancestor(cm, 'figure');
                if ~isempty(fig); uialert(fig, ME.message, 'Trial data'); else; warning('TrialDataExport:Failed', '%s', ME.message); end
            end
        end
    end
end


function idx = panelIndices(F, k)
%panelIndices  The indices of the trial panels K names (indices or ids); all of F's trial panels for [].
types = EphysAnalysisConfig.TrialPanelTypes;
np = numel(F.panels);
kinds = strings(1, np);
ids = strings(1, np);
for i = 1:np
    kinds(i) = string(F.panels(i).type);
    ids(i) = string(F.panels(i).id);
end
if isempty(k)
    idx = find(ismember(kinds, types));
    return
end
if isstring(k) || ischar(k) || iscellstr(k)
    k = string(k);
    idx = zeros(1, numel(k));
    for i = 1:numel(k)
        j = find(ids == k(i), 1);
        if isempty(j); error('TrialDataExport:NoPanel', 'The figure %s has no panel "%s".', string(F.id), k(i)); end
        idx(i) = j;
    end
else
    idx = reshape(double(k), 1, []);
    if any(idx < 1 | idx > np | idx ~= round(idx))
        error('TrialDataExport:NoPanel', 'The figure %s has %d panels, not panel %s.', string(F.id), np, mat2str(idx));
    end
end
bad = idx(~ismember(kinds(idx), types));
if ~isempty(bad)
    error('TrialDataExport:NotTrialPanel', 'Panel "%s" is a %s panel, not a trial panel (%s).', ids(bad(1)), kinds(bad(1)), ...
        strjoin(types, ", "));
end
end


function tf = hasValues(P)
%hasValues  The panel has a computed layer with values.
tf = false;
for j = 1:numel(P.layers)
    R = P.layers(j).R;
    if P.layers(j).skip == "" && isstruct(R) && isfield(R, 'values') && istable(R.values); tf = true; return; end
end
end


function T = layerTable(F, P, j, R)
%layerTable  One layer's values with the export's columns.
V = R.values;
n = height(V);
vars = string(V.Properties.VariableNames);
col = @(name, default) colOr(V, vars, name, default, n);
session = double(col("session", 1));
key = string(col("sessionKey", ""));
dataset = datasetOf(F, R, V, vars, session, n);
key(ismissing(key) | key == "") = dataset(ismissing(key) | key == "");
group = double(col("group", 0));
category = double(col("category", 0));
series = double(col("series", 0));
T = table(repmat(string(F.id), n, 1), repmat(string(P.id), n, 1), repmat(string(P.layers(j).name), n, 1), ...
    repmat(string(R.label), n, 1), dataset, session, key, double(col("trial", NaN)), group, ...
    labelsOf(R, 'groups', group), category, labelsOf(R, 'categories', category), series, labelsOf(R, 'series', series), ...
    double(col("value", NaN)), double(col("x", NaN)), double(col("tA", NaN)), double(col("tB", NaN)), ...
    'VariableNames', {'figure', 'panel', 'layer', 'measure', 'dataset', 'session', 'sessionKey', 'trial', 'group', ...
    'groupLabel', 'category', 'categoryLabel', 'series', 'seriesLabel', 'value', 'x', 'tA', 'tB'});
std = ["trial" "value" "x" "tA" "tB" "k" "group" "session" "sessionKey" "layer" "category" "series" "groupIndex" "dataset"];
for v = vars(~ismember(vars, std))
    c = V.(v);
    if size(c, 2) ~= 1 || ismember(v, string(T.Properties.VariableNames)); continue; end
    if isnumeric(c) || islogical(c)
        T.(v) = double(c);
    else
        T.(v) = string(c);
    end
end
end


function c = colOr(V, vars, name, default, n)
%colOr  A column of the values table, or DEFAULT for every row when it has none.
if ismember(name, vars)
    c = V.(name);
else
    c = repmat(default, n, 1);
end
end


function d = datasetOf(F, R, V, vars, session, n)
%datasetOf  The dataset of each value: its own column, a merged figure's sessions, else the layer's (or the figure's) dataset.
if ismember("dataset", vars)
    d = string(V.dataset);
    return
end
if isfield(R, 'sessions') && istable(R.sessions)
    S = R.sessions;
    sv = string(S.Properties.VariableNames);
    name = sv(ismember(sv, ["dataset" "name" "label"]));
    if ~isempty(name)
        lab = string(S.(name(1)));
        d = strings(n, 1);
        ok = session >= 1 & session <= numel(lab);
        d(ok) = lab(session(ok));
        return
    end
end
src = "";
if isfield(R, 'dataset'); src = strjoin(string(R.dataset), ", "); end
if src == "" && isfield(F, 'dataset'); src = strjoin(string(F.dataset), ", "); end
d = repmat(src, n, 1);
end


function s = labelsOf(R, field, idx)
%labelsOf  The label of each level index IDX in R.(FIELD) (a levels table): "" where it is none.
s = strings(numel(idx), 1);
if ~isfield(R, field) || ~istable(R.(field)) || ~ismember("label", string(R.(field).Properties.VariableNames)); return; end
lab = string(R.(field).label);
ok = idx >= 1 & idx <= numel(lab) & idx == round(idx);
s(ok) = lab(idx(ok));
end


function T = stackTables(parts)
%stackTables  The layers' tables one after another, a parameter column a table lacks filled with NaN or missing.
lead = {'figure', 'panel', 'layer', 'measure', 'dataset', 'session', 'sessionKey', 'trial', 'group', 'groupLabel', ...
    'category', 'categoryLabel', 'series', 'seriesLabel', 'value', 'x', 'tA', 'tB'};
if isempty(parts)
    s = strings(0, 1);
    d = zeros(0, 1);
    T = table(s, s, s, s, s, d, s, d, d, s, d, s, d, s, d, d, d, d, 'VariableNames', lead);
    return
end
names = string(parts{1}.Properties.VariableNames);
for i = 2:numel(parts)
    names = [names setdiff(string(parts{i}.Properties.VariableNames), names, 'stable')]; %#ok<AGROW>
end
for i = 1:numel(parts)
    Ti = parts{i};
    have = string(Ti.Properties.VariableNames);
    for v = names(~ismember(names, have))
        numeric = true;
        for q = 1:numel(parts)
            if ismember(v, string(parts{q}.Properties.VariableNames)); numeric = isnumeric(parts{q}.(v)); break; end
        end
        if numeric
            Ti.(v) = NaN(height(Ti), 1);
        else
            Ti.(v) = repmat(string(missing), height(Ti), 1);
        end
    end
    parts{i} = Ti(:, cellstr(names));
end
T = vertcat(parts{:});
end


function s = cellText(c)
%cellText  A column's cells as text: numbers to 10 significant digits, NaN and missing empty, tabs and line breaks as spaces.
n = size(c, 1);
if isnumeric(c) || islogical(c)
    v = double(c(:, 1));
    s = compose("%.10g", v);
    s(isnan(v)) = "";
    return
end
if iscell(c); c = string(c); end
s = string(c(:, 1));
s(ismissing(s)) = "";
s = regexprep(s, '[\t\r\n]+', ' ');
s = reshape(s, n, 1);
end
