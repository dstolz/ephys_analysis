function onIssueActivated(obj, evt)
%onIssueActivated  A double click on a row of the Export tab's issues, plan or results table: go to what it is about.
%   EVT is the table's DoubleClickedFcn event (its InteractionInformation's
%   Row is the row in Data, whatever the sort shows). The row decides:
%     a Validate issue (Section, Field columns)
%         Source    the Data tab, the control of that field (Root, Folders ...)
%         Defaults  the Alignment tab, the event, window or selection
%         Export, Report  the Export tab, the control of that field
%         Figures   the Figures tab: the figure, panel and layer the Field
%                   path names ("<figure>.<panel>.layers(2).source"), the
%                   section or row of the editor that holds the setting
%     a plan or results row (Plot column)
%         the Figures tab with that figure, and the dataset it is about
%   Where nothing more exact is known it at least shows the tab. The status
%   bar says where it went.
%
%   See also onValidate, onPlan, onRunExport, gotoFigureRow, gotoFigureSection.
info = evt.InteractionInformation;
if isempty(info.Row); return; end
src = evt.Source;
T = src.Data;
if ~istable(T) || info.Row < 1 || info.Row > height(T); return; end
vars = string(T.Properties.VariableNames);
row = T(info.Row, :);
if all(ismember(["Section" "Field"], vars))
    gotoIssue(obj, string(row.Section), string(row.Field));
elseif ismember("Plot", vars)
    gotoPlanRow(obj, string(row.Plot), rowText(row, "Dataset"));
end
end


function gotoIssue(obj, section, field)
%gotoIssue  Show the setting a validate issue (SECTION, FIELD) is about.
switch section
    case "Source"
        ctl = struct('Mode', obj.SourceModeDropDown, 'Root', obj.RootField, 'OutputRoot', obj.OutputRootField, ...
            'NamePattern', obj.NamePatternField, 'Recordings', obj.RecordingsDropDown, 'Folders', obj.FoldersArea, ...
            'Selection', obj.DatasetsTable, 'Datasets', obj.DatasetsTable);
        showAt(obj, obj.TabData, pick(ctl, field), "Data tab: " + field);
    case "Defaults"
        C = obj.AlignControls;
        ctl = struct('EventRef', C.Line, 'Window', C.Pre, 'Selection', C.Filter);
        showAt(obj, obj.TabAlign, pick(ctl, field), "Alignment tab: " + field);
    case "Export"
        X = obj.ExportControls;
        key = extractBefore(field + ".", ".");
        if key == "Formats"; key = "png"; end
        if key == "SessionsFolder" || key == "Data"; key = "Folder"; end
        showAt(obj, obj.TabExport, pick(X, key), "Export tab: " + field);
    case "Report"
        showAt(obj, obj.TabExport, pick(obj.ReportControls, extractBefore(field + ".", ".")), "Export tab: Report " + field);
    case "Figures"
        gotoFigureField(obj, field);
    otherwise
        obj.selectTab(obj.TabExport);
end
end


function gotoPlanRow(obj, plot, dataset)
%gotoPlanRow  The Figures tab with figure PLOT (and, for a dataset row, that dataset) shown.
k = obj.Config.figureIndex(plot);
if k < 1
    obj.selectTab(obj.TabFigures);
    obj.setStatus("Figure " + plot + " is not in the config any more.");
    return
end
if dataset ~= "" && ~startsWith(dataset, "sessions: ") && ~isempty(obj.Runner)
    idx = find(obj.Runner.Names == dataset, 1);
    if ~isempty(idx) && idx ~= obj.ActiveIdx; obj.selectDataset(idx); end
end
obj.selectTab(obj.TabFigures);
if k ~= obj.SelectedFigure; obj.onFigureSelected(k); end
msg = "Showing " + plot;
if dataset ~= "" && ~startsWith(dataset, "sessions: "); msg = msg + " on " + dataset; end
obj.setStatus(msg + ".");
end


function gotoFigureField(obj, field)
%gotoFigureField  Show the figure, panel, layer and editor section that a "<figure>.<panel>.layers(2).source" path names.
cfg = obj.Config;
if field == "enabled"   % "No figure is enabled."
    obj.selectTab(obj.TabFigures);
    obj.setStatus("No figure is enabled: tick one in the Figures tab's list.");
    return
end
ids = cfg.figureIds();
fk = 0; rest = "";
for k = 1:numel(ids)   % the longest id that starts the path (an id may hold dots)
    if startsWith(field, ids(k) + ".") && (fk == 0 || strlength(ids(k)) > strlength(ids(fk)))
        fk = k; rest = extractAfter(field, strlength(ids(k)) + 1);
    end
end
obj.selectTab(obj.TabFigures);
if fk == 0
    obj.setStatus("Figures tab: " + field);
    return
end
if fk ~= obj.SelectedFigure; obj.onFigureSelected(fk); end
fig = cfg.Figures(fk);
panelIds = string.empty(1, 0);
if ~isempty(fig.panels); panelIds = [fig.panels.id]; end
pk = 0;
for p = 1:numel(panelIds)
    if startsWith(rest, panelIds(p) + ".") && (pk == 0 || strlength(panelIds(p)) > strlength(panelIds(pk)))
        pk = p;
    end
end
layerNo = 0;
if pk > 0
    rest = extractAfter(rest, strlength(panelIds(pk)) + 1);
    if obj.SelectedPanel ~= pk; obj.onPanelSelected(pk); end
    tok = regexp(rest, '^layers\((\d+)\)\.(.*)$', 'tokens', 'once');
    if ~isempty(tok)
        layerNo = str2double(tok{1});
        rest = string(tok{2});
        if layerNo >= 1 && layerNo <= numel(fig.panels(pk).layers) && obj.SelectedLayer ~= layerNo
            obj.onLayerSelected(layerNo);
        end
    end
end
where = ids(fk);
if pk > 0; where = where + " > " + panelIds(pk); end
if layerNo > 0; where = where + " > layer " + layerNo; end
[section, key] = figureTarget(rest, pk > 0, layerNo > 0);
X = obj.FigureSearchIndex;
i = 0;
if key ~= ""
    i = find(cellfun(@(c) any(c == key), {X.Keys}), 1);
    if isempty(i); i = 0; end
end
if i > 0 && obj.gotoFigureRow(i)
    obj.setStatus(where + " > " + rest);
    return
end
if section ~= ""
    obj.gotoFigureSection(section);
end
obj.setStatus(where + " > " + rest);
end


function [section, key] = figureTarget(rest, inPanel, inLayer)
%figureTarget  The editor section, and the formRow key when one is known, of the setting REST names.
section = ""; key = "";
head = extractBefore(rest + ".", ".");
if inLayer
    section = "layers";
    switch head
        case "binding", key = "layerBinding";
        case "source", key = "layerSource";
        case "aggregate", key = "layerAggregate";
        case "channels", key = "layerChannels";
        case "units", key = "layerMaxUnits";
        case "eventsAs", key = "evDrawAs";
        case "name", key = "layerName";
    end
elseif inPanel
    switch head
        case "type", section = "panel"; key = "panelType";
        case "title", section = "panel"; key = "panelTitle";
        case "xLabel", section = "panel"; key = "panelXLabel";
        case "yLabel", section = "panel"; key = "panelYLabel";
        case "note", section = "annotations"; key = "annText";
        case {"align", "valign", "box", "ref", "window", "selection"}, section = "palign";
        case "layers", section = "layers";
        case "options", section = "analysis";
        otherwise, section = "panel";
    end
else
    switch head
        case "id", key = "id";
        case "title", key = "title";
        case "size", key = "sizeWidth";
        case "ref", section = "ref";
        case "window", section = "window";
        case "selection", section = "selection";
        case "observe", section = "observations";
        case "grid", section = "arrangement";
        case "sessions", section = "sessions";
        case "probe", section = "probe";
        case "latency", key = "latMethod";
        case "panels", section = "arrangement";
        otherwise, section = "observations";
    end
end
end


function showAt(obj, tab, ctl, where)
%showAt  Show TAB and focus CTL ([] = none); the status bar says WHERE.
obj.selectTab(tab);
if ~isempty(ctl)
    try focus(ctl); catch; end
end
obj.setStatus(where);
end


function c = pick(S, name)
%pick  The control named NAME in struct S, [] when there is none.
c = [];
name = char(name);
if isstruct(S) && isfield(S, name) && isscalar(S.(name)) && isgraphics(S.(name))
    c = S.(name);
end
end


function t = rowText(row, name)
t = "";
if ismember(name, string(row.Properties.VariableNames)); t = string(row.(name)); end
end
