function buildExportTab(obj)
%buildExportTab  Export and Report sections; Validate, Plan, Run, results.
g = uigridlayout(obj.TabExport, [1 2]);
g.ColumnWidth = {470, '1x'};
g.Padding = [8 8 8 8];
changed = @(~,~) obj.onConfigChanged("export");

left = uigridlayout(g, [2 1]);
left.RowHeight = {'fit', 'fit'};
left.Padding = [0 0 0 0];

% --- Export ------------------------------------------------------------------
xp = uipanel(left, "Title", "Figure files (config: Export)");
xg = uigridlayout(xp, [7 4]);
xg.RowHeight = repmat({22}, 1, 7);
xg.ColumnWidth = {100, '1x', '1x', 70};
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
X.Browse = uibutton(xg, "Text", "Browse...", "ButtonPushedFcn", @(~,~) browse(obj, X.Folder));
place(X.Browse, 3, 4);
lab(xg, "File names:", 4, 1);
X.FilenamePattern = uieditfield(xg, "text", "ValueChangedFcn", changed, ...
    "Tooltip", "Tokens: {Name} {Plot} {Kind} {Group} {Unit} {Index} {Date}; a paged plot adds _p<page> unless {Index} or {Unit} is used.");
place(X.FilenamePattern, 4, [2 4]);
lab(xg, "Dpi (png):", 5, 1);
X.Dpi = uieditfield(xg, "numeric", "Limits", [10 2400], "Value", 150, "ValueChangedFcn", changed);
place(X.Dpi, 5, 2);
X.Overwrite = uicheckbox(xg, "Text", "Overwrite existing", "ValueChangedFcn", changed);
place(X.Overwrite, 5, [3 4]);
lab(xg, "Size (cm):", 6, 1);
X.Width = uieditfield(xg, "numeric", "Limits", [2 200], "Value", 18, "ValueChangedFcn", changed, "Tooltip", "Figure width.");
place(X.Width, 6, 2);
X.Height = uieditfield(xg, "numeric", "Limits", [2 200], "Value", 12, "ValueChangedFcn", changed, "Tooltip", "Figure height.");
place(X.Height, 6, 3);
tok = uilabel(xg, "Text", "e.g. {OutputFolder}\analysis  and  {Name}_{Plot}", "FontColor", [0.35 0.35 0.35]);
place(tok, 7, [1 4]);
obj.ExportControls = X;

% --- Report -------------------------------------------------------------------
rp = uipanel(left, "Title", "Report (config: Report)");
rg = uigridlayout(rp, [7 4]);
rg.RowHeight = repmat({22}, 1, 7);
rg.ColumnWidth = {100, '1x', '1x', 70};
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
P.Browse = uibutton(rg, "Text", "Browse...", "ButtonPushedFcn", @(~,~) browse(obj, P.Folder));
place(P.Browse, 3, 4);
lab(rg, "File name:", 4, 1);
P.FileName = uieditfield(rg, "text", "ValueChangedFcn", changed);
place(P.FileName, 4, 2);
P.PerDataset = uicheckbox(rg, "Text", "One per dataset", "ValueChangedFcn", changed);
place(P.PerDataset, 4, [3 4]);
lab(rg, "HTML images:", 5, 1);
P.EmbedFormat = uidropdown(rg, "Items", ["png" "svg"], "ValueChangedFcn", changed);
place(P.EmbedFormat, 5, 2);
lab(rg, "Dpi:", 5, 3);
P.Dpi = uieditfield(rg, "numeric", "Limits", [10 1200], "Value", 110, "ValueChangedFcn", changed);
place(P.Dpi, 5, 4);
ig = uigridlayout(rg, [1 3]); ig.Padding = [0 0 0 0]; ig.Layout.Row = 6; ig.Layout.Column = [1 4];
P.IncludeSummary = uicheckbox(ig, "Text", "Summary tables", "ValueChangedFcn", changed);
P.IncludeParameters = uicheckbox(ig, "Text", "Plot parameters", "ValueChangedFcn", changed);
P.IncludeConfig = uicheckbox(ig, "Text", "The config", "ValueChangedFcn", changed);
obj.ReportControls = P;

% --- run ------------------------------------------------------------------------
right = uigridlayout(g, [5 6]);
right.RowHeight = {26, '1x', 22, '1x', 26};
right.ColumnWidth = {'fit', 'fit', 'fit', 'fit', '1x', 'fit'};
right.Padding = [0 0 0 0];
obj.ValidateButton = uibutton(right, "Text", "Validate", "ButtonPushedFcn", @(~,~) obj.onValidate());
place(obj.ValidateButton, 1, 1);
obj.PlanButton = uibutton(right, "Text", "Plan", "Tooltip", "Which plot runs on which ticked dataset, and why one is skipped.", ...
    "ButtonPushedFcn", @(~,~) obj.onPlan());
place(obj.PlanButton, 1, 2);
obj.RunButton = uibutton(right, "Text", "Run", "FontWeight", "bold", ...
    "Tooltip", "Every enabled plot on every ticked dataset: figures and report.", "ButtonPushedFcn", @(~,~) obj.onRunExport());
place(obj.RunButton, 1, 3);
obj.CancelButton = uibutton(right, "Text", "Cancel", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onCancelRun());
place(obj.CancelButton, 1, 4);
obj.IssuesTable = uitable(right, "RowName", {}, "ColumnWidth", 'auto');
place(obj.IssuesTable, 2, [1 6]);
obj.RunLabel = uilabel(right, "Text", "Results", "FontWeight", "bold");
place(obj.RunLabel, 3, [1 6]);
obj.ResultsTable = uitable(right, "RowName", {}, "ColumnWidth", 'auto');
place(obj.ResultsTable, 4, [1 6]);
obj.OpenReportButton = uibutton(right, "Text", "Open report", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onOpenReport());
place(obj.OpenReportButton, 5, 1);
obj.OpenFolderButton = uibutton(right, "Text", "Open figure folder", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onOpenExportFolder());
place(obj.OpenFolderButton, 5, 2);
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
