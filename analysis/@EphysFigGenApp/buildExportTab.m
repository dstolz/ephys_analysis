function buildExportTab(obj)
%buildExportTab  Export and Report sections; Validate, Plan, Test report, Run, results.
%   The plan and results tables take whatever columns the runner gives:
%   a figure's rows have Kind "figure" (File > Generate selected figure fills
%   the results table too). Test report (onTestReport) draws every enabled
%   figure of the active dataset for the observation picked on the Figures
%   tab, and the dataset's figures, as an HTML report in a temporary folder.
%   Workers (beside Cancel; preference ReportWorkers) is how many process
%   workers a run draws and writes its pages on (EphysAnalysisRunner.Workers).
%   The figure Folder and File names, and the report's Title and Folder,
%   each have a "{x}" button at their right (labelVariableButton; in
%   ExportControls.varButton and ReportControls.varButton by field name):
%   a menu of the pattern's tokens (figureFileTokens), each with its value
%   now, the one picked added as the pattern takes it (addToken).
g = uigridlayout(obj.TabExport, [1 2]);
g.ColumnWidth = {470, '1x'};
g.Padding = [8 8 8 8];
changed = @(~,~) obj.onConfigChanged("export");

left = uigridlayout(g, [2 1]);
left.RowHeight = {'fit', 'fit'};
left.Padding = [0 0 0 0];

% --- Export ------------------------------------------------------------------
xp = uipanel(left, "Title", "Figure files");
xg = uigridlayout(xp, [7 4]);
xg.RowHeight = repmat({22}, 1, 7);
xg.ColumnWidth = {150, '1x', '1x', 104};
xg.RowSpacing = 4;
X = struct();
X.Enabled = uicheckbox(xg, "Text", "Write figure files", "FontWeight", "bold", "ValueChangedFcn", changed);
place(X.Enabled, 1, [1 4]);
lab(xg, "Formats:", 2, 1);
fg = uigridlayout(xg, [1 4]); fg.Padding = [0 0 0 0]; fg.Layout.Row = 2; fg.Layout.Column = [2 4];
for f = ["png" "eps" "svg" "pdf"]
    X.(f) = uicheckbox(fg, "Text", f, "ValueChangedFcn", changed);
end
lab(xg, "Folder:", 3, 1);
X.Folder = uieditfield(xg, "text", "ValueChangedFcn", changed, ...
    "Tooltip", "Tokens: {OutputFolder} (each dataset's output folder), {OutputRoot}, {Root}, {Name}, {Date}.");
place(X.Folder, 3, [2 3]);
X.Browse = uibutton(xg, "Text", "Browse...", "Icon", buttonIcon("browse"), "ButtonPushedFcn", @(~,~) browse(obj, X.Folder));
place(X.Browse, 3, 4);
lab(xg, "File names:", 4, 1);
X.FilenamePattern = uieditfield(xg, "text", "ValueChangedFcn", changed, ...
    "Tooltip", "Tokens: {Name} {Plot} (the figure's id) {Kind} {Group} {Unit} {Index} {Date}; a figure drawn for " + ...
    "several observations adds _<Unit> unless {Unit} or {Index} is used.");
place(X.FilenamePattern, 4, [2 4]);
lab(xg, "Resolution (dpi, PNG):", 5, 1);
X.Dpi = uieditfield(xg, "numeric", "Limits", [10 2400], "Value", 150, "ValueChangedFcn", changed, ...
    "Tooltip", "Dots per inch of the PNG files (150 is fine for a screen, 300 or more for print)." + newline + "Script name: Export.Dpi");
place(X.Dpi, 5, 2);
X.Overwrite = uicheckbox(xg, "Text", "Overwrite existing", "ValueChangedFcn", changed);
place(X.Overwrite, 5, [3 4]);
lab(xg, "Size (cm):", 6, 1);
X.Width = uieditfield(xg, "numeric", "Limits", [2 200], "Value", 18, "ValueChangedFcn", changed, "Tooltip", "Figure width.");
place(X.Width, 6, 2);
X.Height = uieditfield(xg, "numeric", "Limits", [2 200], "Value", 12, "ValueChangedFcn", changed, "Tooltip", "Figure height.");
place(X.Height, 6, 3);
tok = uilabel(xg, "Text", "e.g. {OutputRoot}\analysis  and  {Name}_{Plot}", "FontColor", [0.35 0.35 0.35]);
place(tok, 7, [1 4]);
X.varButton = struct();
X.varButton.Folder = tokenButton(obj, X.Folder, "folder");
X.varButton.FilenamePattern = tokenButton(obj, X.FilenamePattern, "file");
obj.ExportControls = X;

% --- Report -------------------------------------------------------------------
rp = uipanel(left, "Title", "Report");
rg = uigridlayout(rp, [8 4]);
rg.RowHeight = repmat({22}, 1, 8);
rg.ColumnWidth = {150, '1x', '1x', 104};
rg.RowSpacing = 4;
P = struct();
P.Enabled = uicheckbox(rg, "Text", "Write a report", "FontWeight", "bold", "ValueChangedFcn", changed);
place(P.Enabled, 1, [1 2]);
P.Format = uidropdown(rg, "Items", ["HTML (one self-contained file)" "PDF (multi-page)" "HTML and PDF"], ...
    "ItemsData", ["html" "pdf" "both"], "ValueChangedFcn", changed);
place(P.Format, 1, [3 4]);
lab(rg, "Title:", 2, 1);
P.Title = uieditfield(rg, "text", "ValueChangedFcn", changed, "Tooltip", "{Name} = the config's name, {Date} = today.");
place(P.Title, 2, [2 4]);
lab(rg, "Folder:", 3, 1);
P.Folder = uieditfield(rg, "text", "ValueChangedFcn", changed, "Tooltip", "Tokens as for the figure folder.");
place(P.Folder, 3, [2 3]);
P.Browse = uibutton(rg, "Text", "Browse...", "Icon", buttonIcon("browse"), "ButtonPushedFcn", @(~,~) browse(obj, P.Folder));
place(P.Browse, 3, 4);
lab(rg, "File name:", 4, 1);
P.FileName = uieditfield(rg, "text", "ValueChangedFcn", changed);
place(P.FileName, 4, 2);
P.PerDataset = uicheckbox(rg, "Text", "One per dataset", "ValueChangedFcn", changed);
place(P.PerDataset, 4, [3 4]);
lab(rg, "HTML images:", 5, 1);
P.EmbedFormat = uidropdown(rg, "Items", ["png" "svg"], "ValueChangedFcn", changed);
place(P.EmbedFormat, 5, 2);
lab(rg, "Resolution (dpi):", 5, 3);
P.Dpi = uieditfield(rg, "numeric", "Limits", [10 1200], "Value", 110, "ValueChangedFcn", changed);
place(P.Dpi, 5, 4);
ig = uigridlayout(rg, [1 3]); ig.Padding = [0 0 0 0]; ig.Layout.Row = 6; ig.Layout.Column = [1 4];
P.IncludeSummary = uicheckbox(ig, "Text", "Summary tables", "ValueChangedFcn", changed);
P.IncludeParameters = uicheckbox(ig, "Text", "Figure parameters", "ValueChangedFcn", changed, ...
    "Tooltip", "Each figure's settings, folded under it in the report.");
P.IncludeConfig = uicheckbox(ig, "Text", "The config", "ValueChangedFcn", changed);
lab(rg, "Order:", 7, 1);
P.Order = uidropdown(rg, "Items", ["By figure (a figure's units together)" "By unit (a unit's figures together)"], ...
    "ItemsData", ["figure" "unit"], "ValueChangedFcn", changed, ...
    "Tooltip", "Within a dataset: each figure with all its units, channels or the dataset in turn, or each unit " + ...
    "(channel, or the dataset) under a heading with all its figures in turn.");
place(P.Order, 7, [2 4]);
lab(rg, "Per page:", 8, 1);
pg = uigridlayout(rg, [1 3]); pg.Padding = [0 0 0 0]; pg.Layout.Row = 8; pg.Layout.Column = [2 4];
pg.ColumnWidth = {60, '1x', '1x'};
pageTip = "Figure pages on one sheet. 1: each its own page, at the size it was drawn. More: the PDF puts up to " + ...
    "that many on a sheet of the paper and orientation beside, in the rows that draw them largest, all at one " + ...
    "scale and never enlarged, a figure's pages (by unit: an observation's) kept on one sheet where they fit; " + ...
    "the HTML sets them side by side the same way.";
P.FiguresPerPage = uispinner(pg, "Limits", [1 16], "RoundFractionalValues", "on", "Value", 1, ...
    "ValueChangedFcn", changed, "Tooltip", pageTip);
P.PageSize = uidropdown(pg, "Items", ["Letter" "A4"], "ItemsData", ["letter" "a4"], "ValueChangedFcn", changed, ...
    "Tooltip", "The sheet the figure pages are tiled on, with more than one per page.");
P.PageOrientation = uidropdown(pg, "Items", ["Best fit" "Portrait" "Landscape"], ...
    "ItemsData", ["auto" "portrait" "landscape"], "ValueChangedFcn", changed, ...
    "Tooltip", "Best fit: portrait or landscape, whichever draws a sheet's pages larger.");
P.varButton = struct();
P.varButton.Title = tokenButton(obj, P.Title, "title");
P.varButton.Folder = tokenButton(obj, P.Folder, "folder");
obj.ReportControls = P;

% --- run ------------------------------------------------------------------------
right = uigridlayout(g, [6 6]);
right.RowHeight = {30, '1x', 20, 22, '1x', 30};
right.ColumnWidth = {112, 90, 136, 90, 104, '1x'};
right.Padding = [0 0 0 0];
obj.ValidateButton = uibutton(right, "Text", "Validate", "Icon", buttonIcon("validate"), "ButtonPushedFcn", @(~,~) obj.onValidate());
place(obj.ValidateButton, 1, 1);
obj.PlanButton = uibutton(right, "Text", "Plan", "Icon", buttonIcon("plan"), "Tooltip", "Which figure runs on which ticked dataset (and each session figure across them), and why one is skipped.", ...
    "ButtonPushedFcn", @(~,~) obj.onPlan());
place(obj.PlanButton, 1, 2);
cmdKey = "Ctrl";
if ismac; cmdKey = "Cmd"; end
obj.TestReportButton = uibutton(right, "Text", "Test report", "Icon", buttonIcon("test"), "Enable", "off", ...
    "Tooltip", "A spot check: every enabled figure (and the one selected on the Figures tab) on the active dataset, " + ...
    "drawn for the unit or channel picked over the Figures tab's preview only, as an HTML report in a temporary " + ...
    "folder that opens in the browser, in the report's Order. A figure of channels or detections draws what is on " + ...
    "the unit's channel; a figure of the dataset draws the dataset; one with nothing there is listed as left out, " + ...
    "as are the figures across sessions. No figure files; the output folder is not touched. (" + cmdKey + "+U on the Figures tab)", ...
    "ButtonPushedFcn", @(~,~) obj.onTestReport());
place(obj.TestReportButton, 1, 3);
obj.RunButton = uibutton(right, "Text", "Run", "Icon", buttonIcon("run"), ...
    "Tooltip", "Every enabled figure on every ticked dataset, then every enabled session figure across them: " + ...
    "figure files and report. A figure is drawn once per observation (File > Generate selected figure draws one " + ...
    "figure alone).", "ButtonPushedFcn", @(~,~) obj.onRunExport());
place(obj.RunButton, 1, 4);
obj.CancelButton = uibutton(right, "Text", "Cancel", "Icon", buttonIcon("stop"), "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onCancelRun());
place(obj.CancelButton, 1, 5);
wg = uigridlayout(right, [1 3], "Padding", [8 0 0 0], "ColumnWidth", {'fit', 60, '1x'}, "ColumnSpacing", 4);
place(wg, 1, 6);
wTip = "Process workers that draw and write the pages of a run (Parallel Computing Toolbox): they start once a " + ...
    "run has 20 pages (about half a minute, once; they stay open for the next runs) and draw the pages while the " + ...
    "figures are computed here. 0 = draw every page in this MATLAB. Each worker takes about 1-2 GB of memory.";
uilabel(wg, "Text", "Workers:", "Tooltip", wTip);
obj.WorkersSpinner = uispinner(wg, "Limits", [0 max(4, feature('numcores'))], "RoundFractionalValues", "on", ...
    "Value", 4, "Tooltip", wTip, "ValueChangedFcn", @(src, ~) AppPrefs.setpref(obj.PrefGroup, 'ReportWorkers', src.Value));
obj.IssuesTable = uitable(right, "RowName", {}, "ColumnWidth", 'auto', "ColumnSortable", true, ...
    "DoubleClickedFcn", @(~, evt) obj.onIssueActivated(evt), ...
    "Tooltip", "The problems Validate found, or the plan: double-click a row to go to the setting or figure it is about.");
place(obj.IssuesTable, 2, [1 6]);
hint = uilabel(right, "Text", "Double-click a row to go to the setting or figure it is about.", "FontColor", [0.35 0.35 0.35]);
place(hint, 3, [1 6]);
obj.RunLabel = uilabel(right, "Text", "Results", "FontWeight", "bold");
place(obj.RunLabel, 4, [1 6]);
obj.ResultsTable = uitable(right, "RowName", {}, "ColumnWidth", 'auto', "ColumnSortable", true, ...
    "DoubleClickedFcn", @(~, evt) obj.onIssueActivated(evt), ...
    "Tooltip", "What the last run did, a row per dataset and figure: double-click a row to show its figure on the Figures tab.");
place(obj.ResultsTable, 5, [1 6]);
og = uigridlayout(right, [1 3], "Padding", [0 0 0 0], "ColumnWidth", {'fit', 'fit', '1x'});
place(og, 6, [1 6]);
obj.OpenReportButton = uibutton(og, "Text", "Open report", "Icon", buttonIcon("report"), "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onOpenReport());
obj.OpenFolderButton = uibutton(og, "Text", "Open figure folder", "Icon", buttonIcon("figureFolder"), "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onOpenExportFolder(), ...
    "Tooltip", "The first dataset's figure folder of the last run. The session figures' files go to the sessions folder (Export.SessionsFolder).");
end


function b = tokenButton(obj, field, kind)
%tokenButton  The "{x}" button at the right of FIELD, a KIND pattern ("file", "folder", "title"): its tokens' menu.
switch kind
    case "file"
        tip = "Add a token, such as {Plot} or {Unit}, to the file names: each file written fills it in " + ...
            "({Name}_{Plot} gives <dataset>_<figure id>). Each one is added after a _. The menu says what each " + ...
            "one is and its value now: the active dataset, and the figure and observation picked on the Figures tab.";
    case "folder"
        tip = "Add a token to the folder: each dataset's run fills it in. {OutputFolder}, {OutputRoot} and {Root} " + ...
            "are whole folders: one goes at the start, in place of the one there (or of a full path). {Name} and " + ...
            "{Date} are added as a subfolder at the end. The menu says what each one is and its value now, for the active dataset.";
    otherwise
        tip = "Add a token to the title: {Name} is the config's name, {Date} today's date.";
end
b = labelVariableButton(field, Values=@() tokenValues(obj, kind), Insert=@(t, name) addToken(t, name, kind), Tooltip=tip);
end


function T = tokenValues(obj, kind)
%tokenValues  The tokens of a KIND pattern (figureFileTokens) with their values now (blank where unknown).
%   A folder's: the active dataset's. A file name's: as a run fills them for
%   the figure in the Figures tab's editor and the observation picked over
%   its preview. The title's: the config's name and today.
T = figureFileTokens(kind);
T.Value = strings(height(T), 1);
V = struct();
try
    r = obj.Runner;
    k = obj.ActiveIdx;
    known = ~isempty(r) && k >= 1 && k <= numel(r.Names);
    switch kind
        case "title"
            V.Name = obj.Config.Name;
            V.Date = string(datetime('now', 'Format', 'yyyy-MM-dd'));
        case "folder"
            V.Root = obj.Config.Source.Root;
            V.Date = string(datetime('now', 'Format', 'yyyyMMdd'));
            if ~isempty(r); V.OutputRoot = r.outputRoot(); end
            if known
                V.OutputFolder = r.datasetFolder(k);
                V.Name = figureFileName("{Name}", struct('Name', r.Names(k)), Kind="folder");   % as a run fills it
            end
        case "file"
            if known; V = fileTokenValues(obj, T.Name); end
    end
catch
end
for i = 1:height(T)
    if isfield(V, T.Name(i)); T.Value(i) = string(V.(T.Name(i))); end
end
end


function V = fileTokenValues(obj, names)
%fileTokenValues  The file-name tokens NAMES as a run fills them for the figure in the editor and the observation picked.
%   The names a run would write (figureOutputName; a session figure's:
%   EphysAnalysisRunner.sessionOutputName, as onExportPreview names them)
%   for a pattern of every token joined by spaces, then split: a filled
%   token holds no space. A struct, empty when there is no figure or
%   observation (or a session figure not previewed).
V = struct();
cfg = obj.Config;
k = obj.SelectedFigure;
T = obj.FigureObservations;
if isempty(cfg) || k < 1 || k > numel(cfg.Figures) || ~istable(T) || height(T) < 1; return; end
i = obj.FigureObservationDropDown.Value;
if ~(isnumeric(i) && isscalar(i) && i >= 1 && i <= height(T)); return; end
pattern = strjoin("{" + reshape(names, 1, []) + "}", " ");
spec = cfg.Figures(k);
if spec.sessions.enabled
    K = obj.FigureSessionResults;
    if ~(isstruct(K) && isfield(K, 'res') && isfield(K, 'label')); return; end
    e = K.res(find(string({K.res.label}) == K.label, 1));
    if isempty(e); return; end
    f = EphysAnalysisRunner.sessionOutputName(pattern, K.spec, T(i, :), e.facet, e.group, i, height(T));
else
    f = figureOutputName(pattern, obj.Runner.Names(obj.ActiveIdx), spec, T(i, :), i, height(T));
end
v = split(f, " ");
if numel(v) ~= numel(names); return; end
for j = 1:numel(names)
    V.(names(j)) = v(j);
end
end


function t = addToken(t, name, kind)
%addToken  The text T with the token NAME ("{Plot}") added as a KIND pattern takes it.
%   A file name's: at the end, after a "_". A folder's: {Name} and {Date}
%   at the end as a subfolder; a whole folder ({OutputFolder}, {OutputRoot},
%   {Root}: figureFileTokens' Path) at the start, in place of the one there,
%   or of a full path ("D:\out"), else before the text. A title's: at the
%   end, after a space.
t = strtrim(t);
switch kind
    case "file"
        if t ~= "" && ~endsWith(t, ["_" "-" "."]); t = t + "_"; end
        t = t + name;
    case "folder"
        T = figureFileTokens("folder");
        roots = "{" + T.Name(T.Path) + "}";
        if ismember(name, roots)
            lead = roots(arrayfun(@(x) startsWith(t, x), roots));
            if ~isempty(lead)
                t = name + extractAfter(t, strlength(lead(1)));
            elseif t == "" || ~isempty(regexp(t, '^([A-Za-z]:|[\\/])', 'once'))   % nothing, or a full path: the token is the folder
                t = name;
            else
                t = name + filesep + t;
            end
        else
            if t ~= "" && ~endsWith(t, ["\" "/"]); t = t + filesep; end
            t = t + name;
        end
    otherwise
        if t ~= "" && ~endsWith(t, " "); t = t + " "; end
        t = t + name;
end
end


function browse(obj, field)
start = char(field.Value);
if isempty(start) || ~isfolder(start); start = pwd; end
d = uigetdir(start, "Choose a folder");
figure(obj.Fig);
if isequal(d, 0); return; end
field.Value = d;
obj.onConfigChanged("export");
end


function l = lab(parent, txt, row, col)
l = uilabel(parent, "Text", txt);
l.Layout.Row = row;
l.Layout.Column = col;
end


function place(c, row, col)
c.Layout.Row = row;
c.Layout.Column = col;
end
