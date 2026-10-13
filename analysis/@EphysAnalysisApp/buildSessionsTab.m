function buildSessionsTab(obj)
%buildSessionsTab  Session plots (one plot merged across datasets), their editor and the preview.
%   Left: the session plots (SessionList, "<id>  (<base plot>)", "(off)"
%   when disabled), the base plot to add one on (the plots whose kind can
%   be merged: EphysAnalysisConfig.SessionKinds) with Add, and Remove,
%   Duplicate, Up, Down. Middle: the editor, a column of sections
%   (formSection) -- the session plot's base plot kind, Enabled, Id, Title,
%   Base plot, Layout and Trial groups, always open; then Sessions (which
%   datasets, facets, series, color order, the sessions under a summary,
%   the error band), Matching (how units are matched across sessions, the
%   mapping file, the minimum number of sessions) and Data (what the data
%   export holds; To workspace, Save .mat...), each collapsing under its
%   colored header (onSessionSectionToggled) with its key, Ctrl+1 to Ctrl+3
%   (gotoSessionSection; onKeyPress). syncSessionEditor shows the rows the
%   session plot uses; layoutSessionEditor packs them. Right: how many
%   sessions it covers, Preview (refreshSessionPreview: the base plot on
%   every session, merged), Auto, the figure picked when it makes several
%   (facets, trial groups), the pages, the panel, a badge saying where the
%   preview is (setSessionPreviewState), its status line and page label.
g = uigridlayout(obj.TabSessions, [1 3]);
g.ColumnWidth = {285, 470, '1x'};
g.Padding = [8 8 8 8];
changed = @(~,~) obj.onConfigChanged("sessions");

% --- left: the session plots ----------------------------------------------------------------
lg = uigridlayout(g, [7 2]);
lg.RowHeight = {22, '1x', 22, 28, 30, 30, 30};
lg.ColumnWidth = {'1x', '1x'};
lg.Padding = [0 0 0 0];
l = uilabel(lg, "Text", "Session plots", "FontWeight", "bold");
place(l, 1, [1 2]);
obj.SessionList = uilistbox(lg, "Items", {}, "ValueChangedFcn", @(lb, ~) obj.onSessionPlotSelected(lb.Value), ...
    "Tooltip", "Each session plot draws one plot of the Plots tab (its base plot: event, window, units, bins, " + ...
    "look) over several datasets at once, merged: the sessions as colors, or averaged per subject or over all. " + ...
    "Click one to edit it.");
place(obj.SessionList, 2, [1 2]);
l = uilabel(lg, "Text", "Base plot of a new one:");
place(l, 3, [1 2]);
obj.AddSessionBaseDropDown = uidropdown(lg, "Items", "(no plot to merge)", "ItemsData", "", ...
    "Tooltip", "The plot (Plots tab) the new session plot draws across sessions. Only the kinds that can be " + ...
    "merged are listed: PSTH, raster, evoked potential, firing rate, tuning, behavior, heatmap and unit waveforms.");
place(obj.AddSessionBaseDropDown, 4, [1 2]);
obj.AddSessionButton = uibutton(lg, "Text", "Add", "ButtonPushedFcn", @(~,~) obj.onAddSessionPlot(), ...
    "Tooltip", "Add a session plot on the base plot above and edit it.");
place(obj.AddSessionButton, 5, [1 2]);
obj.RemoveSessionButton = uibutton(lg, "Text", "Remove", "ButtonPushedFcn", @(~,~) obj.onRemoveSessionPlot(), ...
    "Tooltip", "Remove the selected session plot from the config (its base plot stays).");
place(obj.RemoveSessionButton, 6, 1);
obj.DuplicateSessionButton = uibutton(lg, "Text", "Duplicate", "ButtonPushedFcn", @(~,~) obj.onDuplicateSessionPlot(), ...
    "Tooltip", "Copy the selected session plot under a new id, right after it; the copy is selected.");
place(obj.DuplicateSessionButton, 6, 2);
obj.UpSessionButton = uibutton(lg, "Text", "Up", "ButtonPushedFcn", @(~,~) obj.onMoveSessionPlot(-1), ...
    "Tooltip", "Move the selected session plot up: runs draw them in this order.");
place(obj.UpSessionButton, 7, 1);
obj.DownSessionButton = uibutton(lg, "Text", "Down", "ButtonPushedFcn", @(~,~) obj.onMoveSessionPlot(1), ...
    "Tooltip", "Move the selected session plot down.");
place(obj.DownSessionButton, 7, 2);

% --- middle: the editor ---------------------------------------------------------------------
ep = uipanel(g, "Title", "Session plot");
obj.SessionEditorPanel = ep;
eg = uigridlayout(ep, [5 1]);
eg.RowHeight = [repmat({0}, 1, 4) {'1x'}];
eg.RowSpacing = 6;
eg.Padding = [4 4 4 4];
eg.Scrollable = "on";
obj.SessionEditorGrid = eg;
E = struct();
order = ["sessions" "matching" "data"];   % the sections with a header, in order: a color each and the keys 1, 2, 3
hue = turbo(256);
hue = hue(round(linspace(40, 216, numel(order))), :);
tint = @(name) hue(order == name, :);

% the session plot: always open
S = formSection(eg, 1, "general", "");
[S, r] = formRow(S, ["kind" "enabled"], "Base kind:");
kg = subgrid(S.Body, r, {'1x', 'fit'});
E.kind = uilabel(kg, "Text", "", "FontWeight", "bold");
E.enabled = uicheckbox(kg, "Text", "Enabled", "ValueChangedFcn", changed, ...
    "Tooltip", "Unticked, the session plot stays in the config but runs do not draw it.");
[S, r] = formRow(S, "note", "", 30);
E.note = uilabel(S.Body, "Text", "", "FontColor", [0.35 0.35 0.35], "WordWrap", "on", "VerticalAlignment", "top");
place(E.note, r, [1 2]);
[S, r] = formRow(S, "id", "Id:");
E.id = uieditfield(S.Body, "text", "ValueChangedFcn", changed, ...
    "Tooltip", "Unique among the session plots; names its figure and data files.");
place(E.id, r, 2);
[S, r] = formRow(S, "title", "Title:");
E.title = uieditfield(S.Body, "text", "Placeholder", "automatic", "ValueChangedFcn", changed, ...
    "Tooltip", "Blank: the base plot's title, which says how many sessions and epochs it holds.");
place(E.title, r, 2);
[S, r] = formRow(S, "plot", "Base plot:");
E.plot = uidropdown(S.Body, "Items", "", "ValueChangedFcn", changed, ...
    "Tooltip", "The plot (Plots tab) computed on every session and merged: its event, window, trial selection, " + ...
    "units, bins and look. Its own Enabled box does not matter here.");
place(E.plot, r, 2);
[S, r] = formRow(S, "layout", "Layout:");
E.layout = uidropdown(S.Body, "Items", "(base plot's)", "ItemsData", "base", "ValueChangedFcn", changed, ...
    "Tooltip", "How the merged plot is laid out: the base plot's layout, or another of its kind's.");
place(E.layout, r, 2);
[S, r] = formRow(S, "trialGroups", "Trial groups:");
E.trialGroups = uidropdown(S.Body, "Items", ["Pool them (a color per session)" "A figure per group" ...
    "Combine (a line style per group)"], "ItemsData", EphysAnalysisConfig.SessionTrialGroups, "ValueChangedFcn", changed, ...
    "Tooltip", "The base plot's trial groups (its Group by). Pool: every epoch of a session together, the " + ...
    "colors are the sessions. A figure per group: each group merged across sessions on its own figure. " + ...
    "Combine: every group kept, a color per session and a line style per group.");
place(E.trialGroups, r, 2);
sec = S;

% which sessions, and how they are drawn
S = formSection(eg, 2, "sessions", "Sessions", Color=tint("sessions"));
[S, r] = formRow(S, "datasets", "Datasets:");
E.datasets = uidropdown(S.Body, "Items", ["The ticked datasets" "These datasets"], "ItemsData", ["ticked" "list"], ...
    "ValueChangedFcn", changed, "Tooltip", "The ticked datasets: those ticked to run on the Data tab. These " + ...
    "datasets: a list of dataset keys of their own (Pick...).");
place(E.datasets, r, 2);
[S, r] = formRow(S, ["datasetKeys" "pickDatasets"], "Keys:");
dg = subgrid(S.Body, r, {'1x', 70});
E.datasetKeys = uieditfield(dg, "text", "Editable", "off", "Placeholder", "none picked", ...
    "Tooltip", "The keys of the datasets this session plot draws (the Data tab's Key column).");
E.pickDatasets = uibutton(dg, "Text", "Pick...", "ButtonPushedFcn", @(~,~) obj.onPickSessionDatasets(), ...
    "Tooltip", "Tick the datasets to draw, from the scanned ones, with their subject and date.");
[S, r] = formRow(S, "facet", "Figures:");
E.facet = uidropdown(S.Body, "Items", ["One for all the sessions" "One per subject"], ...
    "ItemsData", EphysAnalysisConfig.SessionFacets, "ValueChangedFcn", changed, ...
    "Tooltip", "One figure over every session, or one per subject with that subject's sessions.");
place(E.facet, r, 2);
[S, r] = formRow(S, "series", "A color per:");
E.series = uidropdown(S.Body, "Items", ["Session" "Subject (its sessions averaged)" "Nothing (all sessions averaged)"], ...
    "ItemsData", EphysAnalysisConfig.SessionSeries, "ValueChangedFcn", changed, ...
    "Tooltip", "What gets a color: each session; each subject, the mean of its sessions; or one mean over every session.");
place(E.series, r, 2);
[S, r] = formRow(S, "colorOrder", "Colors:");
E.colorOrder = uidropdown(S.Body, "Items", ["The design's palette" "By date (sequential)"], ...
    "ItemsData", EphysAnalysisConfig.SessionColorOrders, "ValueChangedFcn", changed, ...
    "Tooltip", "The palette's colors in turn, or a sequential map in date order (the design's), so the days read as a progression.");
place(E.colorOrder, r, 2);
[S, r] = formRow(S, "showMembers", "");
E.showMembers = uicheckbox(S.Body, "Text", "Show each session faintly under its mean", "ValueChangedFcn", changed, ...
    "Tooltip", "With a color per subject or one mean: each session's own trace, pale, under the mean.");
place(E.showMembers, r, [1 2]);
[S, r] = formRow(S, "error", "Error band:");
E.error = uidropdown(S.Body, "Items", ["mean ± SEM" "mean ± SD" "95% CI" "None"], ...
    "ItemsData", EphysAnalysisConfig.SessionErrors, "ValueChangedFcn", changed, ...
    "Tooltip", "With a color per subject or one mean: the band across the sessions averaged (the 95% CI uses " + ...
    "Student's t, Statistics and Machine Learning Toolbox; 1.96 SEM without it). None with fewer than two sessions.");
place(E.error, r, 2);
sec(end+1) = S;

% matching units across sessions
S = formSection(eg, 3, "matching", "Matching", Color=tint("matching"));
[S, r] = formRow(S, "match", "Units:");
E.match = uidropdown(S.Body, "Items", ["Pool: each session's units, a tile each" "Site: one tile per recording channel" ...
    "Mapping: a table names each cell's units"], "ItemsData", EphysAnalysisConfig.SessionMatches, "ValueChangedFcn", changed, ...
    "Tooltip", "How the units of different sessions meet on a tile. Pool: every session's units on tiles of their " + ...
    "own. Site: a tile per recording channel, a session's units there averaged. Mapping: a tile per cell of the " + ...
    "mapping file, each session's unit ids from its column. Signals always match by recording channel.");
place(E.match, r, 2);
[S, r] = formRow(S, ["mappingFile" "browseMapping" "editMapping"], "Mapping file:");
mg = subgrid(S.Body, r, {'1x', 76, 58});
E.mappingFile = uieditfield(mg, "text", "Placeholder", "a .csv file", "ValueChangedFcn", changed, ...
    "Tooltip", "A CSV: a column ""cell"", then one column per dataset key holding that dataset's unit id(s) for the cell.");
E.browseMapping = uibutton(mg, "Text", "Browse...", "ButtonPushedFcn", @(~,~) obj.onBrowseUnitMapping(), ...
    "Tooltip", "Pick the mapping file.");
E.editMapping = uibutton(mg, "Text", "Edit...", "ButtonPushedFcn", @(~,~) obj.onEditUnitMapping(), ...
    "Tooltip", "Edit the mapping: a row per cell, a column per dataset.");
[S, r] = formRow(S, "minSessions", "Min. sessions:");
E.minSessions = uispinner(S.Body, "Limits", [1 Inf], "Step", 1, "Value", 1, "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "A tile (site, cell, channel) is drawn only when at least this many sessions have data for it.");
place(E.minSessions, r, 2);
sec(end+1) = S;

% the data behind the plot
S = formSection(eg, 4, "data", "Data", Color=tint("data"));
[S, r] = formRow(S, ["dataResults" "dataEpochs" "dataSignals"], "Export holds:");
xg = subgrid(S.Body, r, {'fit', 'fit', 'fit', '1x'});
xg.ColumnSpacing = 12;
E.dataResults = uicheckbox(xg, "Text", "results", "ValueChangedFcn", changed, ...
    "Tooltip", "Each session's own result of the base plot, besides the merged one.");
E.dataEpochs = uicheckbox(xg, "Text", "epochs", "ValueChangedFcn", changed, ...
    "Tooltip", "Each session's epochs: the epoch table, spike times and binned counts per unit.");
E.dataSignals = uicheckbox(xg, "Text", "signals", "ValueChangedFcn", changed, ...
    "Tooltip", "With epochs, a signal base plot's epoched samples too (time x channel x epoch); they can be large.");
[S, r] = formRow(S, ["toWorkspace" "saveMat"], "", 30);
bg = subgrid(S.Body, r, {'1x', '1x'});
place(bg, r, [1 2]);
E.toWorkspace = uibutton(bg, "Text", "To workspace", "ButtonPushedFcn", @(~,~) withSelected(obj, @(id) obj.onSessionsToWorkspace(id)), ...
    "Tooltip", "Compute the session plot over its datasets and put its data in the base workspace as sessions_<id>.");
E.saveMat = uibutton(bg, "Text", "Save .mat...", "ButtonPushedFcn", @(~,~) withSelected(obj, @(id) obj.onSaveSessionData(id)), ...
    "Tooltip", "Compute the session plot over its datasets and save its data as a .mat file.");
sec(end+1) = S;

for i = 2:numel(sec)
    name = sec(i).Name;
    sec(i).Toggle.ButtonPushedFcn = @(~,~) obj.onSessionSectionToggled(name);
    sec(i).Key = string(find(order == name));   % Ctrl+1 ... Ctrl+3 (onKeyPress)
end
obj.SessionEditor = E;
obj.SessionSections = sec;
obj.layoutSessionEditor();

% --- right: the preview ---------------------------------------------------------------------
pg = uigridlayout(g, [4 4]);
pg.RowHeight = {30, 30, '1x', 26};
pg.ColumnWidth = {100, 'fit', 'fit', '1x'};   % Preview over two rows, Auto and the pages, then the labels and their controls
pg.Padding = [0 0 0 0];
obj.SessionPreviewButton = uibutton(pg, "Text", "Preview", "ButtonPushedFcn", @(~,~) obj.refreshSessionPreview(), ...
    "Tooltip", "Compute the base plot on every session of the selected session plot and draw them merged. " + ...
    "Every page and figure is computed, so < > and the figure box only draw. Orange: it changed since it was drawn.");
place(obj.SessionPreviewButton, [1 2], 1);
cg = uigridlayout(pg, [2 1], "RowHeight", {30, 30}, "ColumnWidth", {'fit'}, "Padding", [0 0 0 0], "RowSpacing", pg.RowSpacing);
place(cg, [1 2], 2);
obj.SessionAutoCheckBox = uicheckbox(cg, "Text", "Auto", "Value", false, ...
    "ValueChangedFcn", @(~,~) obj.onSessionAutoPreviewToggled(), ...
    "Tooltip", "Redraw on every change while a preview takes under 2 s. Off by default: a session preview reads every dataset.");
obj.SessionAutoCheckBox.Layout.Row = 1;
kg = uigridlayout(cg, [1 2], "ColumnWidth", {34, 34}, "ColumnSpacing", 4, "Padding", [0 0 0 0]);
kg.Layout.Row = 2;
obj.SessionPrevPageButton = uibutton(kg, "Text", "<", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onSessionPreviewPage(-1), ...
    "Tooltip", "The previous page of a paged grid (Page Up).");
obj.SessionNextPageButton = uibutton(kg, "Text", ">", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onSessionPreviewPage(1), ...
    "Tooltip", "The next page of a paged grid (Page Down).");
fg = uigridlayout(pg, [1 2], "ColumnWidth", {'fit', '1x'}, "Padding", [0 0 0 0], "ColumnSpacing", 6, "Visible", "off");
place(fg, 2, [3 4]);   % shown while the session plot makes several figures (refreshSessionPreview)
uilabel(fg, "Text", "Figure:");
obj.SessionGroupDropDown = uidropdown(fg, "Items", "all", "ItemsData", 1, ...
    "ValueChangedFcn", @(dd, ~) obj.onSessionGroupChanged(dd.Value), ...
    "Tooltip", "The figure shown when the session plot makes several: one per subject (Figures), or per " + ...
    "trial group (A figure per group). All of them were computed: picking one only draws it.");
obj.SessionCountLabel = uilabel(pg, "Text", "Sessions: scan the datasets first (Data tab).", "FontColor", [0.25 0.25 0.25], ...
    "Tooltip", "The sessions the selected session plot draws: the datasets ticked on the Data tab, or its own list.");
place(obj.SessionCountLabel, 1, [3 4]);
obj.SessionPreviewPanel = uipanel(pg, "BackgroundColor", "w", "BorderType", "line");
place(obj.SessionPreviewPanel, 3, [1 4]);
sg = uigridlayout(pg, [1 3], "ColumnWidth", {'fit', '1x', 'fit'}, "Padding", [0 0 0 0], "ColumnSpacing", 8);
place(sg, 4, [1 4]);
B.Grid = uigridlayout(sg, [1 2], "ColumnWidth", {18, 'fit'}, "Padding", [6 2 10 2], "ColumnSpacing", 5);
B.Icon = uiimage(B.Grid, "ScaleMethod", "fit");
B.Text = uilabel(B.Grid, "FontWeight", "bold");
obj.SessionPreviewBadge = B;
obj.SessionPreviewLabel = uilabel(sg, "Text", "Add a session plot, scan and tick datasets to preview.", "FontColor", [0.35 0.35 0.35]);
obj.SessionPageLabel = uilabel(sg, "Text", "", "HorizontalAlignment", "right", "FontSize", 11, "FontColor", [0.35 0.35 0.35], ...
    "Tooltip", "The page of a paged grid shown (Page Up and Page Down flip pages).");
obj.setSessionPreviewState("idle");
end


function withSelected(obj, fcn)
%withSelected  FCN(id) on the session plot in the editor; the status bar says so when there is none.
k = obj.SelectedSessionPlot;
if k < 1 || k > numel(obj.Config.SessionPlots)
    obj.setStatus("Sessions: add or select a session plot first.");
    return
end
fcn(obj.Config.SessionPlots(k).id);
end


function sg = subgrid(parent, row, widths)
%subgrid  A borderless one-row grid in column 2 of form row ROW.
sg = uigridlayout(parent, [1 numel(widths)]);
sg.ColumnWidth = widths;
sg.Padding = [0 0 0 0];
sg.ColumnSpacing = 6;
place(sg, row, 2);
end


function place(c, row, col)
c.Layout.Row = row;
c.Layout.Column = col;
end
