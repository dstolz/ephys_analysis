function buildFiguresTab(obj)
%buildFiguresTab  The Figures tab: the figures, their editor with the arrangement's schematic, and the preview of one observation.
%   A figure (the Figures section of the config) is designed for one
%   observation -- a sorted unit, a signal channel, or the dataset -- as a
%   grid of panels (raster, PSTH, continuous signal, heat map, ...), each
%   holding layers of data that follow the observation or name fixed items.
%   Three columns:
%   Left    the figures as a tree (FiguresTree, refreshFigureList: a
%           leaf "<id>  (<n> panels)", with ", per <kind>" unless grouped by
%           it and "(off)" when disabled unless grouped by status) under
%           the groups Group by names (what it observes: unit, channel or
%           dataset; enabled / off; none), each node with a check box that
%           ticks or unticks the figure, or every figure of a group
%           (onFigureTreeClicked), All / None / Invert (onFigureCheck);
%           Add (a blank figure, then the New panel window: onAddFigure),
%           Remove, Duplicate ("<id> (2)": onDuplicateFigure), Up, Down
%           (within its group) and
%           Copy settings... (onCopyFigureSettings: a figure's settings, one
%           by one, onto other figures or into a design). The tree drives the preview: the figure picked
%           there is the one the editor and the preview show (its own
%           container, syncFigureView), and a figure selected any other way
%           (Favorites, Go to setting, Undo, Add, Duplicate, Remove, a
%           config opened) is selected in the tree. Its nodes are marked
%           (markFigureTree): the figure shown in bold; a preview out of
%           date (its figure, the defaults it uses, the dataset or the
%           observation changed since it was drawn, or it waits for
%           Preview) amber and italic, a failed one red, one not drawn (not
%           shown yet, dropped from the kept ones, or the dataset cannot
%           draw it) gray.
%   Middle  the editor, a column of sections (formSection): Id (with
%           auto: the id follows the panels and data until one is typed:
%           onIdEdited, onIdAutoToggled), Title, Size (the page it is
%           exported on: a drop-down of suggestions you can type in, the
%           width and height in px, in or cm with a lock for the aspect
%           ratio: onFigureSizeEdited; the preview is shaped like it),
%           Enabled and a summary, always open; then Observations (the data
%           the figure is drawn for, Starred only, the unit filter or the
%           channels, Per trial group: one
%           figure per observation and group), Panels (the
%           schematic of the grid, drawFigureSchematic: click a panel to
%           pick it, or drag it to an empty cell or to an edge of another
%           panel, onSchematicPress; New panel... (the New panel window:
%           its type, name, place and key parameters, onNewPanel); its
%           spans, its row's height and column's width, its own size in its
%           cell and where it sits there, the spacing with Spacing...
%           (figureSpacingDialog: the gaps between the panels),
%           Remove panel, Move), Selected panel (its type, title, box,
%           group shown), the
%           figure's Event reference, Epoch window and Trial selection (the
%           Alignment tab's while "Use default" is ticked; Epoch Diagram),
%           Panel alignment
%           (the panel's own event and window, locked to the figure's while
%           "Same as the figure" is ticked; its own trial selection, locked
%           to the figure's while "Trial selection as the figure" is ticked:
%           onPanelSelectionToggled; Apply to all panels, Re-link all
%           panels), Layers (the panel's layers, Add a source the type
%           draws, Remove, Up, Down, and the rows of the layer picked), the
%           panel type's Options (all of the panel's own; Apply to all
%           panels: applyOptionsToAll; a raster's First spike row and a
%           PSTH's Latency box row each show a summary beside a button that
%           opens their modal window: latencyDialog), its Waveform
%           (the unit's waveform: an inset on a raster, PSTH, firing rate
%           or tuning curve panel, the panel itself on a unit waveforms
%           panel; what it shows, its x and y scales, size, place and
%           label; shown for every type whose layers may be spikes, with
%           a note on what it sets or why the type draws none:
%           waveformSection, waveformNote),
%           the panel's Text note and Overlays (for the selected panel:
%           onAddFigureOverlay, onFigureOverlayPicked),
%           Appearance, Looks and Sessions (Across sessions: the figure
%           drawn once over the ticked or picked datasets, its facet, colors,
%           error band, unit matching with the mapping file's Browse... and
%           Edit..., minimum sessions and trial groups; then the picker
%           lists the matched observations and the preview draws them
%           across the sessions, with a "Figure:" drop-down under it for
%           one figure per subject or trial group, and the Dataset
%           drop-down is off). Each section collapses under its colored
%           header (onFigureSectionToggled). The sections stand under three
%           supersections, each a dark header that collapses them all
%           (onFigureSuperToggled): Figure (Observations, Event reference,
%           Epoch window, Trial selection, Sessions, Panels), Panel
%           (Selected panel, Panel alignment, Layers, Options, Waveform, Text note, Overlays;
%           its header names the selected panel) and Look (Appearance,
%           Looks), built in that order so Tab follows it. Alt+1 to Alt+3
%           go to a supersection (gotoFigureSuper), Ctrl+1 to Ctrl+9 and
%           Ctrl+0 to the first ten sections, Observations to Text note
%           (gotoFigureSection; onKeyPress); Sessions, Waveform, Overlays,
%           Appearance and Looks have no key. Over the editor, a search field
%           (Ctrl+F; onFigureSearch) lists the rows whose label (or
%           tooltip) has the words typed, "Supersection > Section > Row",
%           in a list under it; Enter or a click goes there (gotoFigureRow),
%           "?" lists the tab's keys (onFigureKeys). Every color field
%           (a mark's, a layer's, the ticks', bands', bars' outline,
%           baseline's, text's, ground's, an overlay's line, fill and
%           outline, the group colors, the error band's fill and edge) has
%           a swatch at its right (colorSwatch, E.swatch by field name)
%           that opens the color chooser (uisetcolor: ColorPicker); the
%           color picked is one named edit, as if typed. syncFigureEditor
%           shows the rows the figure, panel and layer use;
%           layoutFigureEditor packs them.
%   Right   a column of buttons at the left -- Preview, Redraw All
%           (every enabled figure's preview drawn again where out of date,
%           the shown figure first: onRedrawAllFigures; the selected
%           figure's files for every observation are the File menu's
%           Generate selected figure, onGenerateFigure), Unit report (every enabled
%           figure for the observation picked, as an HTML report in a
%           temporary folder: onUnitReport), Auto, and < and > on a row
%           (Page Up / Page Down) -- beside the dataset, the observation
%           picked (figureObservations' labels) and the Favorites
%           (buildFavorites: a filter and every starred dataset, channel
%           and unit, picked to preview: onFavoritePicked), the first two
%           with their star toggle (starButton, onStarToggled) and note
%           button (noteButton: the NotePad, onNoteButton). The Design
%           drop-down is right of the dataset (the design every figure is
%           drawn in, also in the Design menu: onDesignChosen; Save look as
%           design... under it: the preview's look as a design of yours,
%           onSaveDesign). Under them a row: Template: (your figure
%           templates, FigureTemplate: the drop-down, re-listed as it
%           opens, refreshTemplates; Apply... into figures picked or as a
%           new figure, onApplyTemplate; Save as..., Update, Remove,
%           Import..., Export... and Report issue, onFigureTemplate) and,
%           at its right, Apply last change... (Edit > Apply last change
%           to figures, onApplyToFigures; on and tooltipped with the menu
%           item, naming the step: refreshEditMenu). Under it the preview
%           (refreshFigurePreview: computeFigure and renderFigure for that
%           one observation; the selected panel outlined there,
%           markFigurePanel): a container per figure (FigurePreviewHost,
%           one cell; syncFigureView shows the selected figure's,
%           FigurePreviewPanel, and hides the others: a tab group's strip
%           cannot be hidden reliably), so a figure keeps its drawing,
%           badge and status line when another is shown and comes back
%           without being computed or drawn again, unless it is out of date
%           (previewFigureView); the MaxFigureViews (8) shown last are
%           kept, the rest drawn again when shown. The editor too comes
%           back as the figure left it: its sections open or collapsed,
%           its scroll, its panel and layer (saveFigureEditorState). The
%           preview's badge (setFigurePreviewState) and status
%           line, with Export preview (the observation picked, written
%           as a run writes it into a preview folder and shown:
%           onExportPreview, also on the Export tab), Export code (the code
%           that loads the data in the preview's epochs and draws the
%           preview, in the editor: onFigureCode) and Open
%           in window (onOpenFigureWindow: the figure in a figure() of its
%           own) at its right. Every button has a key, named in its tooltip
%           (onKeyPress): Ctrl+P Preview, Ctrl+R Redraw All, Ctrl+U Unit
%           report, Ctrl+T Auto, Page Up / Page Down < and >, Ctrl+K Export
%           preview, Ctrl+E Export code, Ctrl+W Open in window.
g = uigridlayout(obj.TabFigures, [1 3]);
g.ColumnWidth = {285, 560, '1x'};
g.Padding = [8 8 8 8];
changed = @(src, ~) obj.onConfigChanged("figure", src);   % the control names the edit (undo history)
gray = [0.35 0.35 0.35];
obj.FigureObservation = containers.Map('KeyType', 'char', 'ValueType', 'any');
obj.FigureIdRenames = containers.Map('KeyType', 'char', 'ValueType', 'any');
PT = EphysAnalysisConfig.panelTypes();

% --- left: the figures, a tree under groups ------------------------------------------------------
lg = uigridlayout(g, [9 2]);
lg.RowHeight = {22, 28, 30, '1x', 30, 30, 30, 30, 64};
lg.ColumnWidth = {'1x', '1x'};
lg.Padding = [0 0 0 0];
l = uilabel(lg, "Text", "Figures  (ticked = enabled)", "FontWeight", "bold");
place(l, 1, [1 2]);
l = uilabel(lg, "Text", "Group by:");
place(l, 2, 1);
obj.FigureGroupDropDown = uidropdown(lg, "Items", ["What it observes" "Enabled / off" "None"], ...
    "ItemsData", ["observe" "status" "none"], "Value", "observe", "ValueChangedFcn", @(~,~) onGroupByChanged(obj), ...
    "Tooltip", "How the tree sorts the figures: by what each is drawn for (a unit, a channel or the dataset; a figure " + ...
    "across sessions too), enabled or off, or a flat list. Within a group the figures keep the run order; Up / Down " + ...
    "move a figure within its group.");
place(obj.FigureGroupDropDown, 2, 2);
cg = uigridlayout(lg, [1 3], "Padding", [0 0 0 0], "ColumnSpacing", 4);
place(cg, 3, [1 2]);
uibutton(cg, "Text", "All", "ButtonPushedFcn", @(~,~) obj.onFigureCheck("all"), "Tooltip", "Enable every figure (tick them all).");
uibutton(cg, "Text", "None", "ButtonPushedFcn", @(~,~) obj.onFigureCheck("none"), ...
    "Tooltip", "Disable every figure (untick them all). They stay in the config.");
uibutton(cg, "Text", "Invert", "ButtonPushedFcn", @(~,~) obj.onFigureCheck("invert"), ...
    "Tooltip", "Enable the disabled figures and disable the enabled ones.");
obj.FiguresTree = uitree(lg, "Multiselect", "off", "SelectionChangedFcn", @(~, evt) obj.onFigureTreeSelected(evt.SelectedNodes), ...
    "NodeExpandedFcn", @(~, evt) obj.onFigureGroupToggled(evt.Node, false), ...
    "NodeCollapsedFcn", @(~, evt) obj.onFigureGroupToggled(evt.Node, true), ...
    "ClickedFcn", @(~, evt) obj.onFigureTreeClicked(evt), ...
    "Tooltip", "Each figure is one observation's panels: a unit's, a channel's or the dataset's. Click one to edit " + ...
    "and preview it. The box on a figure is ticked while it is enabled (Run draws it): click the box to tick or " + ...
    "untick it. A group's box is ticked when all its figures are, half-filled when some are; click it to tick or untick them all. " + ...
    "Bold: the figure shown. Amber italic: its preview is out of date; red: it failed; gray: not drawn yet. Each " + ...
    "figure keeps its preview, so coming back to one shows it at once.");
place(obj.FiguresTree, 4, [1 2]);
obj.AddFigureButton = uibutton(lg, "Text", "Add", "ButtonPushedFcn", @(~,~) obj.onAddFigure(), ...
    "Tooltip", "Add a blank figure and pick its first panel in the New panel window (Cancel leaves it blank).");
place(obj.AddFigureButton, 5, [1 2]);
obj.RemoveFigureButton = uibutton(lg, "Text", "Remove", "ButtonPushedFcn", @(~,~) obj.onRemoveFigure(), ...
    "Tooltip", "Remove the selected figure from the config.");
place(obj.RemoveFigureButton, 6, 1);
obj.DuplicateFigureButton = uibutton(lg, "Text", "Duplicate", "ButtonPushedFcn", @(~,~) obj.onDuplicateFigure(), ...
    "Tooltip", "Copy the selected figure right after it, as ""<id> (2)"" (the next free number); the copy is selected.");
place(obj.DuplicateFigureButton, 6, 2);
obj.UpFigureButton = uibutton(lg, "Text", "Up", "ButtonPushedFcn", @(~,~) obj.onMoveFigure(-1), ...
    "Tooltip", "Move the selected figure up its group (the run order).");
place(obj.UpFigureButton, 7, 1);
obj.DownFigureButton = uibutton(lg, "Text", "Down", "ButtonPushedFcn", @(~,~) obj.onMoveFigure(1), ...
    "Tooltip", "Move the selected figure down its group (the run order).");
place(obj.DownFigureButton, 7, 2);
obj.CopyFigureButton = uibutton(lg, "Text", "Copy settings...", "ButtonPushedFcn", @(~,~) obj.onCopyFigureSettings(), ...
    "Tooltip", "Copy a figure's settings onto other figures (one or many) or into a design: tick the settings one by one " + ...
    "(observations, alignment, panels, each panel's options, appearance, looks, across sessions). Each figure keeps its " + ...
    "id, title and enabled; one step of Undo; the other figures' previews are marked out of date, not drawn again.");
place(obj.CopyFigureButton, 8, [1 2]);
l = uilabel(lg, "Text", "A figure is one observation's panels: a unit's, a channel's or the dataset's. " + ...
    "File > Generate selected figure draws it for each observation; Run (Export tab) draws the enabled ones.", ...
    "WordWrap", "on", "FontColor", gray, "VerticalAlignment", "top");
place(l, 9, [1 2]);

% --- middle: the search field, its matches and the editor ------------------------------------------
mc = uigridlayout(g, [3 1], "RowHeight", {30, 0, '1x'}, "Padding", [0 0 0 0], "RowSpacing", 4);
fg0 = uigridlayout(mc, [1 2], "ColumnWidth", {'1x', 34}, "Padding", [0 0 0 0], "ColumnSpacing", 4);
obj.FigureSearchField = uieditfield(fg0, "text", "Placeholder", "Find a setting by name  (Ctrl+F)", ...
    "ValueChangingFcn", @(~, evt) obj.onFigureSearch(evt.Value), ...
    "Tooltip", "Type part of a setting's name (or a word of its tooltip): the matches are listed below as " + ...
    """Supersection > Section > Row"". Enter goes to the first (Down and Up pick another), as does a click on one: " + ...
    "its supersection and section open, the editor scrolls to it, and the row is highlighted. Escape clears the search.");
obj.FigureKeysButton = uibutton(fg0, "Text", "?", "FontWeight", "bold", "ButtonPushedFcn", @(~,~) obj.onFigureKeys(), ...
    "Tooltip", "The Figures tab's keys: to move between the supersections, sections, columns and panels with the keyboard.");
obj.FigureSearchList = uilistbox(mc, "Items", {}, "Visible", "off", ...
    "ValueChangedFcn", @(lb, ~) searchPicked(obj, lb, false), "ClickedFcn", @(lb, evt) searchClicked(obj, lb, evt), ...
    "Tooltip", "The settings that match. Click one to go there; with the keyboard, the arrows show each and Enter goes there.");
ep = uipanel(mc, "Title", "Figure");
ep.Layout.Row = 3;
obj.FigureEditorPanel = ep;
eg = uigridlayout(ep, [20 1]);
eg.RowHeight = [repmat({0}, 1, 19) {'1x'}];
eg.RowSpacing = 6;
eg.Padding = [4 4 4 4];
eg.Scrollable = "on";
obj.FigureEditorGrid = eg;
E = struct();

% the sections with a header, in order (built so, so Tab follows it): a header color each (a step along the turbo map)
% and the keys 1-9, 0
order = ["observations" "ref" "window" "selection" "sessions" "arrangement" "panel" "palign" "layers" "options" "note" ...
    "overlays" "style" "looks"];
keyed = order(~ismember(order, ["sessions" "overlays" "style" "looks"]));   % Observations Ctrl+1 ... Options Ctrl+9, Text note Ctrl+0
hue = turbo(256);
hue = hue(round(linspace(24, 232, numel(order))), :);
tint = @(name) hue(order == name, :);

% the figure: always open
S = formSection(eg, 1, "general", "");
[S, r] = formRow(S, ["id" "idAuto"], "Id:");
ig = subgrid(S.Body, r, {'1x', 'fit'});
E.id = uieditfield(ig, "text", "ValueChangedFcn", @(f, evt) onIdEdited(obj, f, evt), ...
    "Tooltip", "Unique among the figures; it names the figure's files ({Plot} in the Export tab's file names). " + ...
    "Gray while automatic: it follows the active panel types and the data (""Raster+PSTH units""). Typing an id " + ...
    "makes it yours.");
E.idAuto = uicheckbox(ig, "Text", "auto", "Value", true, "ValueChangedFcn", @(b, ~) onIdAutoToggled(obj, b), ...
    "Tooltip", "Ticked: the id follows the figure's active panel types and data (""Raster+PSTH units"", ""Continuous LFP""; " + ...
    "a "" (2)"" when another figure has it). Typing an id unticks it; tick it to go back to the automatic id.");
[S, r] = formRow(S, "title", "Title:");
E.title = uieditfield(S.Body, "text", "Placeholder", "automatic", "ValueChangedFcn", changed, ...
    "Tooltip", "Blank: ""<id>: <observation> — <event> (<n> epochs)"". A title of your own names no " + ...
    "observation, so the top-left panel names it.");
place(E.title, r, 2);
[S, r] = formRow(S, "size", "Size:");
E.sizePreset = uidropdown(S.Body, "Editable", "on", "Items", cellstr(figureSizePresets().Label), "Value", "Export tab size", ...
    "ValueChangedFcn", @(~, ~) obj.onFigureSizeEdited("preset"), ...
    "Tooltip", "The page the figure is exported on, and the shape of the preview. Pick a suggestion or type " + ...
    """6 x 4 in"", ""1200 x 800 px"" (pixels of the PNG, at the Export dpi) or ""15 x 10 cm"". Export tab size: " + ...
    "the Export tab's Width and Height, taller when the rows need it. Fit preview: the preview area's shape and size now.");
place(E.sizePreset, r, 2);
[S, r] = formRow(S, ["sizeWidth" "sizeHeight" "sizeUnits" "sizeLock"], "Width x height:");
zg = subgrid(S.Body, r, {'1x', 'fit', '1x', 56, 'fit'});
E.sizeWidth = uieditfield(zg, "numeric", "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueDisplayFormat", "%.5g", "Value", 18, ...
    "ValueChangedFcn", @(~, ~) obj.onFigureSizeEdited("width"), ...
    "Tooltip", "The page's width, in the units at the right. Editing it gives the figure a size of its own (""Export tab size"" is left).");
uilabel(zg, "Text", "x");
E.sizeHeight = uieditfield(zg, "numeric", "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueDisplayFormat", "%.5g", "Value", 12, ...
    "ValueChangedFcn", @(~, ~) obj.onFigureSizeEdited("height"), ...
    "Tooltip", "The page's height, in the units at the right.");
E.sizeUnits = uidropdown(zg, "Items", ["px" "in" "cm"], "Value", "cm", "ValueChangedFcn", @(~, ~) obj.onFigureSizeEdited("units"), ...
    "Tooltip", "px: pixels of the exported PNG, so inches at the Export tab's dpi. Changing the units keeps the page the same size.");
E.sizeLock = uicheckbox(zg, "Text", "Lock ratio", "ValueChangedFcn", @(~, ~) obj.onFigureSizeEdited("lock"), ...
    "Tooltip", "Keep the aspect ratio: editing the width changes the height with it, and the other way round.");
[S, r] = formRow(S, "enabled", "");
E.enabled = uicheckbox(S.Body, "Text", "Enabled", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Unticked, the figure stays in the config but Run (Export tab) skips it. Generate selected figure and the preview still draw it; Redraw All leaves it out.");
place(E.enabled, r, [1 2]);
[S, r] = formRow(S, "summary", "");
E.summary = uilabel(S.Body, "Text", "", "FontColor", gray);
place(E.summary, r, [1 2]);
sec = S;
hFigure = superHeader(eg);   % the Figure supersection's header (each made where its sections start: Tab reaches it first)

% what the figure is drawn for
S = formSection(eg, 2, "observations", "Observations", Color=tint("observations"));
[S, r] = formRow(S, "observe", "Observe:");
E.observe = uidropdown(S.Body, "Items", "Sorted units", "ItemsData", "units", "ValueChangedFcn", changed, ...
    "Tooltip", "The data one figure is drawn for, and what the picker above the preview lists: each sorted " + ...
    "unit, each channel's detected spikes, each channel of a signal, or the dataset once. What the active " + ...
    "dataset holds comes first; a type it lacks says so and can still be picked.");   % applyFigureEditor lists them (observeItems)
place(E.observe, r, 2);
[S, r] = formRow(S, "obsStarred", "Favorites:");
E.obsStarred = uicheckbox(S.Body, "Text", "Starred only", "ValueChangedFcn", changed, ...
    "Tooltip", "Observe only what is starred (★): the starred units of the sort in use, the starred channels (a " + ...
    "detection channel by its channel) or, for a figure of the dataset, a starred dataset. Generate selected figure, < > and " + ...
    "Export runs then draw just the favorites (observe.starred in the config); across sessions, an observation " + ...
    "starred on any of its sessions.");
place(E.obsStarred, r, 2);
[S, r] = formRow(S, "obsClasses", "Unit classes:");
cg = subgrid(S.Body, r, repmat({'fit'}, 1, 4));
cg.ColumnSpacing = 12;
E.obsClasses = struct();
for c = ["su" "mua" "uns" "noise"]
    E.obsClasses.(c) = uicheckbox(cg, "Text", c, "Value", ismember(c, ["su" "mua"]), "ValueChangedFcn", changed, ...
        "Tooltip", "Sorted-unit classes observed (none ticked = every class).");
end
[S, r] = formRow(S, "obsIds", "Unit ids:");
E.obsIds = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "Unit ids (sorted units) or channels (detections), e.g. 3 5 8:12.");
place(E.obsIds, r, 2);
[S, r] = formRow(S, "obsQuality", "Quality:");
E.obsQuality = uicheckbox(S.Body, "Text", "Good units only", "ValueChangedFcn", changed, ...
    "Tooltip", "Observe only the sorted units that meet the good-unit criteria (observe.units.quality in the config).");
place(E.obsQuality, r, 2);
[S, r] = formRow(S, ["obsResponse" "obsRespTest" "obsRespDirection"], "Response:");
rg = subgrid(S.Body, r, {'fit', '1x', '1x'});
E.obsResponse = uicheckbox(rg, "Text", "Responsive only", "ValueChangedFcn", changed, ...
    "Tooltip", "Observe only the units that respond to the figure's event (responseStats; Statistics and Machine " + ...
    "Learning Toolbox), over the figure's epochs.");
E.obsRespTest = uidropdown(rg, "Items", ["vs baseline" "tuned" "either" "both" "auROC"], "ItemsData", ["evoked" "tuning" "either" "both" "auroc"], ...
    "ValueChangedFcn", changed, "Tooltip", "vs baseline: the response window's rate differs from the baseline's " + ...
    "(signrank). tuned: it differs across the parameter's levels (kruskalwallis). either / both of them. " + ...
    "auROC: the auROC calls the unit modulated over the response window.");
E.obsRespDirection = uidropdown(rg, "Items", ["any" "excited" "suppressed"], "ValueChangedFcn", changed, ...
    "Tooltip", "vs baseline: keep the units whose rate rises (excited), falls (suppressed), or either.");
[S, r] = formRow(S, ["obsRespBaseFrom" "obsRespBaseTo" "obsRespFrom" "obsRespTo"], "Test windows (s):");
wg = subgrid(S.Body, r, {'1x', 'fit', '1x', 'fit', '1x', 'fit', '1x'});
E.obsRespBaseFrom = uieditfield(wg, "numeric", "Value", -0.2, "ValueChangedFcn", changed, "Tooltip", "The test's baseline window start (s from the event).");
uilabel(wg, "Text", "to");
E.obsRespBaseTo = uieditfield(wg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "The test's baseline window end (s).");
uilabel(wg, "Text", "response");
E.obsRespFrom = uieditfield(wg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "The response window start (s from the event).");
uilabel(wg, "Text", "to");
E.obsRespTo = uieditfield(wg, "numeric", "Value", 0.2, "ValueChangedFcn", changed, "Tooltip", "The response window end (s).");
[S, r] = formRow(S, ["obsRespParam" "obsRespCorrection" "obsRespAlpha"], "Test options:");
og = subgrid(S.Body, r, {'1x', 'fit', '1x', 'fit', '1x'});
E.obsRespParam = uidropdown(og, "Editable", "on", "Items", "", "ValueChangedFcn", changed, ...
    "Tooltip", "The trial parameter of the tuning test.");
uilabel(og, "Text", "correction:");
E.obsRespCorrection = uidropdown(og, "Items", ["BH (FDR)" "Holm" "Bonferroni" "none"], "ItemsData", ["bh" "holm" "bonferroni" "none"], ...
    "ValueChangedFcn", changed, "Tooltip", "How the p values are adjusted for the number of units tested (pAdjust).");
uilabel(og, "Text", "alpha:");
E.obsRespAlpha = uieditfield(og, "numeric", "Value", 0.05, "Limits", [0 1], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "A unit passes when its adjusted p is at most alpha.");
[S, E] = aurocRows(S, E, "obsRa", changed);
[S, r] = formRow(S, "obsMaxUnits", "Max units:");
E.obsMaxUnits = uieditfield(S.Body, "text", "Value", "Inf", "ValueChangedFcn", changed, ...
    "Tooltip", "The most units observed (Inf = all), in probe order.");
place(E.obsMaxUnits, r, 2);
[S, r] = formRow(S, "obsShanks", "Shanks:");
E.obsShanks = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed);
place(E.obsShanks, r, 2);
[S, r] = formRow(S, "obsUnitChannels", "Channels:");
E.obsUnitChannels = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "The recording channels whose units are observed, e.g. 1:8.");
place(E.obsUnitChannels, r, 2);
[S, r] = formRow(S, "obsChannels", "Channels:");
E.obsChannels = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "The extract's columns observed, e.g. 1 3 5 (blank = all).");
place(E.obsChannels, r, 2);
[S, r] = formRow(S, "obsPerGroup", "");
E.obsPerGroup = uicheckbox(S.Body, "Text", "Per trial group (one figure per group)", "ValueChangedFcn", changed, ...
    "Tooltip", "Draw each observation once per trial group of the figure's trial selection (its Group by): the " + ...
    "picker lists every observation and group, and each figure keeps that group's epochs only. A panel with a " + ...
    "trial selection of its own keeps its own groups. Needs a Group by.");
place(E.obsPerGroup, r, [1 2]);
[S, r] = formRow(S, "obsCount", "");
E.obsCount = uilabel(S.Body, "Text", "", "FontColor", gray);
place(E.obsCount, r, [1 2]);
sec(end+1) = S;

% the figure's event reference, window and selection: the Alignment tab's controls
Sr = formSection(eg, 5, "ref", "Event reference", "panel", Color=tint("ref"));
Sw = formSection(eg, 6, "window", "Epoch window", "panel", Color=tint("window"));
Ss = formSection(eg, 7, "selection", "Trial selection", "panel", Color=tint("selection"));
E.defaultRef = defaultBox(obj, Sr, "event reference");
E.defaultWindow = defaultBox(obj, Sw, "epoch window");
E.defaultSelection = defaultBox(obj, Ss, "trial selection");
C = obj.buildAlignControls([Sr.Body Sw.Body Ss.Body], @(part) obj.onFigureAlignEdited(part));
E.epochs = C.Diagram;
E.epochs.ButtonPushedFcn = @(~,~) obj.onShowEpochs();
E.epochs.Tooltip = "A window, kept above the app, that draws how this figure's event reference, epoch window and " + ...
    "trial selection cut the active dataset into epochs. It follows every edit.";
set([C.RefGrid C.WindowGrid C.SelectionGrid], 'Padding', [4 2 4 2]);
Sr.BodyHeight = gridHeight(C.RefGrid);
Sw.BodyHeight = gridHeight(C.WindowGrid);
Ss.BodyHeight = gridHeight(C.SelectionGrid);
obj.FigureAlignControls = C;
sec = [sec Sr Sw Ss];

% across sessions: the figure drawn once over several datasets, each layer merged (figureSessionCompute); no key
S = formSection(eg, 14, "sessions", "Sessions", Color=tint("sessions"));
[S, r] = formRow(S, "sesEnabled", "");
E.sesEnabled = uicheckbox(S.Body, "Text", "Across sessions (one figure over several datasets)", "ValueChangedFcn", changed, ...
    "Tooltip", "Draw this figure once across the datasets instead of once per dataset: each observation (a site, " + ...
    "a cell of the mapping, a channel or the dataset) is computed on every session and each panel's layers are " + ...
    "merged, a color per session (or subject). Generate selected figure and Run then write it to the sessions folder.");
place(E.sesEnabled, r, [1 2]);
[S, r] = formRow(S, "sesDatasets", "Datasets:");
E.sesDatasets = uidropdown(S.Body, "Items", ["The ticked datasets" "These datasets"], "ItemsData", ["ticked" "list"], ...
    "ValueChangedFcn", changed, "Tooltip", "The ticked datasets: those ticked to run on the Data tab. These " + ...
    "datasets: a list of dataset keys of its own (Pick...).");
place(E.sesDatasets, r, 2);
[S, r] = formRow(S, ["sesKeys" "sesPick"], "Keys:");
dg = subgrid(S.Body, r, {'1x', 70});
E.sesKeys = uieditfield(dg, "text", "Editable", "off", "Placeholder", "none picked", ...
    "Tooltip", "The keys of the datasets this figure is drawn across (the Data tab's Key column).");
E.sesPick = uibutton(dg, "Text", "Pick...", "ButtonPushedFcn", @(~,~) obj.onPickFigureDatasets(), ...
    "Tooltip", "Tick the datasets to draw, from the scanned ones, with their subject and date.");
[S, r] = formRow(S, "sesFacet", "Figures:");
E.sesFacet = uidropdown(S.Body, "Items", ["One for all the sessions" "One per subject"], ...
    "ItemsData", EphysAnalysisConfig.SessionFacets, "ValueChangedFcn", changed, ...
    "Tooltip", "One figure over every session, or one per subject with that subject's sessions.");
place(E.sesFacet, r, 2);
[S, r] = formRow(S, "sesSeries", "A color per:");
E.sesSeries = uidropdown(S.Body, "Items", ["Session" "Subject (its sessions averaged)" "Nothing (all sessions averaged)"], ...
    "ItemsData", EphysAnalysisConfig.SessionSeries, "ValueChangedFcn", changed, ...
    "Tooltip", "What gets a color: each session; each subject, the mean of its sessions; or one mean over every session.");
place(E.sesSeries, r, 2);
[S, r] = formRow(S, "sesColorOrder", "Colors:");
E.sesColorOrder = uidropdown(S.Body, "Items", ["The design's palette" "By date (sequential)"], ...
    "ItemsData", EphysAnalysisConfig.SessionColorOrders, "ValueChangedFcn", changed, ...
    "Tooltip", "The palette's colors in turn, or a sequential map in date order, so the days read as a progression.");
place(E.sesColorOrder, r, 2);
[S, r] = formRow(S, "sesShowMembers", "");
E.sesShowMembers = uicheckbox(S.Body, "Text", "Show each session faintly under its mean", "ValueChangedFcn", changed, ...
    "Tooltip", "With a color per subject or one mean: each session's own trace, pale, under the mean.");
place(E.sesShowMembers, r, [1 2]);
[S, r] = formRow(S, "sesError", "Error band:");
E.sesError = uidropdown(S.Body, "Items", ["mean ± SEM" "mean ± SD" "95% CI" "None"], ...
    "ItemsData", EphysAnalysisConfig.SessionErrors, "ValueChangedFcn", changed, ...
    "Tooltip", "With a color per subject or one mean: the band across the sessions averaged (the 95% CI uses " + ...
    "Student's t, Statistics and Machine Learning Toolbox; 1.96 SEM without it).");
place(E.sesError, r, 2);
[S, r] = formRow(S, "sesMatch", "Units matched by:");
E.sesMatch = uidropdown(S.Body, "Items", ["Site: the unit's recording channel" "Mapping: a table names each cell's units"], ...
    "ItemsData", EphysAnalysisConfig.FigureSessionMatches, "ValueChangedFcn", changed, ...
    "Tooltip", "How the observed unit is found in each session. Site: the units on the same recording channel (the " + ...
    "first in probe order). Mapping: a cell of the mapping file, each session's unit id from its column.");
place(E.sesMatch, r, 2);
[S, r] = formRow(S, ["sesMappingFile" "sesBrowse" "sesEdit"], "Mapping file:");
mg = subgrid(S.Body, r, {'1x', 76, 58});
E.sesMappingFile = uieditfield(mg, "text", "Placeholder", "a .csv file", "ValueChangedFcn", changed, ...
    "Tooltip", "A CSV: a column ""cell"", then one column per dataset key holding that dataset's unit id(s) for the cell.");
E.sesBrowse = uibutton(mg, "Text", "Browse...", "ButtonPushedFcn", @(~,~) obj.onBrowseFigureMapping(), ...
    "Tooltip", "Pick the mapping file.");
E.sesEdit = uibutton(mg, "Text", "Edit...", "ButtonPushedFcn", @(~,~) obj.onEditUnitMapping(), ...
    "Tooltip", "Edit the mapping: a row per cell, a column per dataset.");
[S, r] = formRow(S, "sesMinSessions", "Min. sessions:");
E.sesMinSessions = uispinner(S.Body, "Limits", [1 Inf], "Step", 1, "Value", 1, "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "An observation is drawn only when at least this many sessions hold it.");
place(E.sesMinSessions, r, 2);
[S, r] = formRow(S, "sesTrialGroups", "Trial groups:");
E.sesTrialGroups = uidropdown(S.Body, "Items", ["Pool them (a color per session)" "A figure per group" ...
    "Combine (a line style per group)"], "ItemsData", EphysAnalysisConfig.SessionTrialGroups, "ValueChangedFcn", changed, ...
    "Tooltip", "The figure's trial groups (its Group by). Pool: every epoch of a session together. A figure per " + ...
    "group: each group merged across sessions on its own figure. Combine: a color per session, a line style per group.");
place(E.sesTrialGroups, r, 2);
[S, r] = formRow(S, "sesNote", "", 44);
E.sesNote = uilabel(S.Body, "Text", "", "FontColor", gray, "WordWrap", "on", "VerticalAlignment", "top");
place(E.sesNote, r, [1 2]);
sec(end+1) = S;

% the panels: the schematic, adding (New panel...), sizing and moving them (the section's key stays "arrangement")
S = formSection(eg, 3, "arrangement", "Panels", Color=tint("arrangement"));
[S, r] = formRow(S, "schematic", "", 160);
E.schematicPanel = uipanel(S.Body, "BorderType", "none", "UserData", false);   % formLayout shows and hides the row's panel
place(E.schematicPanel, r, [1 2]);   % its axes: drawFigureSchematic makes it while the row is shown (one made or kept at 0 px does not draw)
[S, r] = formRow(S, "newPanel", "", 30);
E.newPanel = uibutton(S.Body, "Text", "New panel...", "ButtonPushedFcn", @(~,~) obj.onNewPanel(), ...
    "Tooltip", "Add a panel: pick its type (each shown as a small plot), its name, where it goes next to the " + ...
    "selected panel (a new row or column) and its key parameters. The first panel goes to row 1, column 1.");
place(E.newPanel, r, [1 2]);
[S, r] = formRow(S, "selPanel", "Selected panel:");
E.selPanel = uilabel(S.Body, "Text", "", "FontWeight", "bold");
place(E.selPanel, r, 2);
[S, r] = formRow(S, "noPanel", "");
E.noPanel = uilabel(S.Body, "Text", "No panel yet: press New panel... to add one.", "FontColor", gray);
place(E.noPanel, r, [1 2]);
[S, r] = formRow(S, "rowSpan", "Row span:");
E.rowSpan = uispinner(S.Body, "Limits", [1 32], "Step", 1, "Value", 1, "RoundFractionalValues", "on", ...
    "ValueChangedFcn", @(sp, evt) onSpanEdited(obj, sp, evt, "row"), ...
    "Tooltip", "How many rows of the grid the selected panel covers, down from its own.");
place(E.rowSpan, r, 2);
[S, r] = formRow(S, "colSpan", "Column span:");
E.colSpan = uispinner(S.Body, "Limits", [1 32], "Step", 1, "Value", 1, "RoundFractionalValues", "on", ...
    "ValueChangedFcn", @(sp, evt) onSpanEdited(obj, sp, evt, "col"), ...
    "Tooltip", "How many columns of the grid the selected panel covers, right from its own.");
place(E.colSpan, r, 2);
[S, r] = formRow(S, "rowHeight", "Row height:");
E.rowHeight = uispinner(S.Body, "Limits", [0 Inf], "LowerLimitInclusive", "off", "Step", 0.25, "Value", 1, "ValueDisplayFormat", "%.4gx", ...
    "ValueChangedFcn", changed, "Tooltip", "The relative height of the selected panel's (first) row, against the " + ...
    "other rows' (1 each when all are equal): every panel of the row. The rows' plot areas take exactly these shares.");
place(E.rowHeight, r, 2);
[S, r] = formRow(S, "colWidth", "Column width:");
E.colWidth = uispinner(S.Body, "Limits", [0 Inf], "LowerLimitInclusive", "off", "Step", 0.25, "Value", 1, "ValueDisplayFormat", "%.4gx", ...
    "ValueChangedFcn", changed, "Tooltip", "The relative width of the selected panel's (first) column, against the " + ...
    "other columns': every panel of the column.");
place(E.colWidth, r, 2);
[S, r] = formRow(S, ["panelWidth" "panelHeight"], "Panel size:");
zg = subgrid(S.Body, r, {'1x', 'fit', '1x', 'fit'});
E.panelWidth = uispinner(zg, "Limits", [1 100], "Step", 5, "Value", 100, "ValueDisplayFormat", "%.4g %%", ...
    "ValueChangedFcn", changed, "Tooltip", "The selected panel's width, as a share of its cell's: this panel only, " + ...
    "not the others of its column. Under 100 %, Align places it in the cell.");
uilabel(zg, "Text", "wide");
E.panelHeight = uispinner(zg, "Limits", [1 100], "Step", 5, "Value", 100, "ValueDisplayFormat", "%.4g %%", ...
    "ValueChangedFcn", changed, "Tooltip", "The selected panel's height, as a share of its cell's: this panel only, " + ...
    "not the others of its row. Under 100 %, Align places it in the cell.");
uilabel(zg, "Text", "high");
[S, r] = formRow(S, ["panelAlign" "panelVAlign"], "Align in cell:");
ng = subgrid(S.Body, r, {'1x', '1x'});
E.panelAlign = uidropdown(ng, "Items", EphysAnalysisConfig.PanelAligns, "Value", "center", "ValueChangedFcn", changed, ...
    "Tooltip", "Where a panel narrower than its cell sits in it.");
E.panelVAlign = uidropdown(ng, "Items", EphysAnalysisConfig.PanelVAligns, "Value", "middle", "ValueChangedFcn", changed, ...
    "Tooltip", "Where a panel shorter than its cell sits in it.");
[S, r] = formRow(S, ["spacing" "spacingDialog"], "Spacing:", 30);
sg = subgrid(S.Body, r, {'1x', 'fit'});
E.spacing = uidropdown(sg, "Items", ["loose" "compact" "tight" "none (flush)" "custom"], "ItemsData", EphysAnalysisConfig.GridSpacings, ...
    "ValueChangedFcn", changed, "Tooltip", "The clear space between neighboring panels' labels: loose, compact, tight " + ...
    "(24, 12, 6 px), none (flush: stacked time panels share their edges) or custom (Spacing...: px or %, each gap " + ...
    "between two rows or columns of its own).");
E.spacingDialog = uibutton(sg, "Text", "Spacing...", "ButtonPushedFcn", @(~,~) figureSpacingDialog(obj), ...
    "Tooltip", "Set the gaps between the panels: a preset or custom, in px or % of the panels' size, one gap " + ...
    "between rows and one between columns, or each gap apart. Apply shows it in the preview.");
[S, r] = formRow(S, "panelButtons", "", 30);
pb = subgrid(S.Body, r, {'fit', 'fit', 40, 40, 40, 40});
place(pb, r, [1 2]);
E.removePanel = uibutton(pb, "Text", "Remove panel", "ButtonPushedFcn", @(~,~) obj.onRemovePanel(), ...
    "Tooltip", "Remove the selected panel; the rows and columns no panel starts in any more go with it.");
uilabel(pb, "Text", "  Move:", "HorizontalAlignment", "right");
dirs = ["up" "down" "left" "right"];
arrows = ["↑" "↓" "←" "→"];
for i = 1:4
    d = dirs(i);
    E.("move" + upper(extractBefore(d, 2)) + extractAfter(d, 1)) = uibutton(pb, "Text", arrows(i), ...
        "ButtonPushedFcn", @(~,~) obj.onMovePanel(d), ...
        "Tooltip", "Swap the selected panel with the panel of the same shape " + ternary(ismember(d, ["up" "down"]), ...
        ternary(d == "up", "above", "below") + " it", "to its " + d) + ".");
end
sec(end+1) = S;

hPanel = superHeader(eg);   % the Panel supersection's header

% the selected panel (the section's key stays "panel")
S = formSection(eg, 4, "panel", "Selected panel", Color=tint("panel"));
[S, r] = formRow(S, "panelType", "Type:");
E.panelType = uidropdown(S.Body, "Items", PT.Label, "ItemsData", PT.Type, "ValueChangedFcn", @(~,~) obj.onPanelTypeChanged(), ...
    "Tooltip", "The panel's type. A change starts its options afresh (keeping what both types share), drops the " + ...
    "layers the new type cannot draw and, when none is left, adds the type's default layer.");
place(E.panelType, r, 2);
[S, r] = formRow(S, "panelTitle", "Title:");
E.panelTitle = uieditfield(S.Body, "text", "Placeholder", "automatic", "ValueChangedFcn", changed, ...
    "Tooltip", "Blank: none (the top-left panel names the observation under a title of the figure's own).");
place(E.panelTitle, r, 2);
[S, r] = formRow(S, "panelBox", "Box:");
E.panelBox = uidropdown(S.Body, "Items", ["auto (the design's)" "on" "off"], "ItemsData", ["auto" "on" "off"], ...
    "ValueChangedFcn", changed, "Tooltip", "The frame around the panel's axes. auto: the design's (and the looks remembered for " + ...
    "the panel's kind); on or off: this panel's own, over them.");
place(E.panelBox, r, 2);
[S, r] = formRow(S, ["panelXLabel" "panelXSide"], "X axis:");
xg = subgrid(S.Body, r, {'1x', 90});
E.panelXLabel = uieditfield(xg, "text", "Placeholder", "automatic", "ValueChangedFcn", changed, ...
    "Tooltip", "The x axis' label. Blank: the panel type's (""Time (s)"" on a time axis). A stack of time panels " + ...
    "is labeled once: this text shows where this panel tells the time. Right-click the label in the preview to edit it there.");
E.panelXSide = uidropdown(xg, "Items", ["bottom" "top"], "ItemsData", EphysAnalysisConfig.PanelXSides, ...
    "ValueChangedFcn", changed, "Tooltip", "Where the x axis' ticks and label go: below or above the panel. A stack " + ...
    "of time panels with their x axes on top tells the time once, at its top.");
[S, r] = formRow(S, ["panelYLabel" "panelYSide"], "Y axis:");
yg = subgrid(S.Body, r, {'1x', 90});
E.panelYLabel = uieditfield(yg, "text", "Placeholder", "automatic", "ValueChangedFcn", changed, ...
    "Tooltip", "The y axis' label. Blank: the panel type's. Right-click the label in the preview to edit it there.");
E.panelYSide = uidropdown(yg, "Items", ["left" "right"], "ItemsData", EphysAnalysisConfig.PanelYSides, ...
    "ValueChangedFcn", changed, "Tooltip", "Where the y axis' ticks and label go: left or right of the panel " + ...
    "(a color bar beside it moves to the other side).");
[S, r] = formRow(S, "group", "Group shown:");
E.group = uispinner(S.Body, "Limits", [1 100], "Step", 1, "Value", 1, "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "The trial group a heat map or a unit correlation map draws (1 = the first of the figure's groups).");
place(E.group, r, 2);
sec(end+1) = S;

% the selected panel's own event reference and window
S = formSection(eg, 9, "palign", "Panel alignment", "panel", Color=tint("palign"));
E.panelSame = uicheckbox(S.HeaderGrid, "Text", "Same as the figure", "Value", true, ...
    "ValueChangedFcn", @(~,~) obj.onPanelDefaultToggled(), ...
    "Tooltip", "Ticked: the panel uses the figure's event reference and epoch window (the rows below show them, " + ...
    "locked), shares its time axis, and follows every change of them. Untick to give the panel its own, starting " + ...
    "from the figure's (its own epochs; its trial selection: the box below); tick again to go back.");
E.panelSame.Layout.Column = 2;
pg = uigridlayout(S.Body, [6 1]);
pg.Padding = [0 0 0 0];
pg.RowSpacing = 4;
E.palignNote = uilabel(pg, "Text", "", "FontColor", gray, "WordWrap", "on");
E.palignNote.Layout.Row = 1;
bg = uigridlayout(pg, [1 2], "ColumnWidth", {'1x', '1x'}, "Padding", [4 0 4 0], "ColumnSpacing", 6);
bg.Layout.Row = 2;
E.alignApplyAll = uibutton(bg, "Text", "Apply to all panels", "ButtonPushedFcn", @(~,~) applyAlignToAll(obj), ...
    "Tooltip", "Make this panel's own event, window and trial selection the figure's, and link every panel to them " + ...
    "again (Same as the figure). Only while this panel has its own.");
E.alignRelinkAll = uibutton(bg, "Text", "Re-link all panels", "ButtonPushedFcn", @(~,~) relinkAll(obj), ...
    "Tooltip", "Every panel uses the figure's event, window and trial selection again: the panels' own event, " + ...
    "window and selection are dropped (their options stay their own). Only while a panel has its own.");
pr = uipanel(pg, "BorderType", "none");
pr.Layout.Row = 3;
pw = uipanel(pg, "BorderType", "none");
pw.Layout.Row = 4;
E.panelSameSel = uicheckbox(pg, "Text", "Trial selection as the figure", "Value", true, ...
    "ValueChangedFcn", @(~,~) onPanelSelectionToggled(obj), ...
    "Tooltip", "Ticked: the panel uses the figure's trial selection (the rows below show it, locked): its groups, " + ...
    "colors and legend are the figure's. Untick to give the panel its own, starting from the figure's: its own " + ...
    "epochs and groups, colored apart, with a legend inside the panel. Tick again to go back.");
E.panelSameSel.Layout.Row = 5;
ps = uipanel(pg, "BorderType", "none");   % the panel's own trial selection (the figure's while linked)
ps.Layout.Row = 6;
C2 = obj.buildAlignControls([pr pw ps], @(part) obj.onPanelAlignEdited(part));
C2.Diagram.Visible = "off";
C2.WindowGrid.RowHeight{end} = 0;
set([C2.RefGrid C2.WindowGrid C2.SelectionGrid], 'Padding', [4 2 4 2]);
hr = gridHeight(C2.RefGrid);
hw = gridHeight(C2.WindowGrid);
hs = gridHeight(C2.SelectionGrid);
pg.RowHeight = {0, 30, hr, hw, 22, hs};
pg.UserData = [hr hw hs];
E.palignGrid = pg;
S.BodyHeight = 30 + hr + hw + 22 + hs + 5 * pg.RowSpacing;
obj.PanelAlignControls = C2;
sec(end+1) = S;

% the selected panel's layers
S = formSection(eg, 10, "layers", "Layers", Color=tint("layers"));
[S, r] = formRow(S, "layerList", "", 92);
E.layerList = uilistbox(S.Body, "Items", {}, "ValueChangedFcn", @(lb, ~) obj.onLayerSelected(lb.Value), ...
    "Tooltip", "The data the panel draws, one binding each: a layer follows the observation (the unit or channel " + ...
    "picked over the preview) or names fixed items. Pick one to edit it below.");
place(E.layerList, r, [1 2]);
[S, r] = formRow(S, "layerAdd", "", 30);
lb = subgrid(S.Body, r, {'1x', 'fit', 'fit', 'fit', 'fit'});
place(lb, r, [1 2]);
E.addSource = uidropdown(lb, "Items", "units", "ValueChangedFcn", @(dd, ~) setAddSource(obj, dd.Value), ...
    "Tooltip", "The source of the layer Add adds: only those the panel's type draws.");
obj.FigureAddSource = "units";
E.addLayer = uibutton(lb, "Text", "Add", "ButtonPushedFcn", @(~,~) obj.onAddLayer(), ...
    "Tooltip", "Add a layer of the source on the left to the panel.");
E.removeLayer = uibutton(lb, "Text", "Remove", "ButtonPushedFcn", @(~,~) obj.onRemoveLayer(), ...
    "Tooltip", "Remove the layer picked from the panel.");
E.layerUp = uibutton(lb, "Text", "Up", "ButtonPushedFcn", @(~,~) obj.onMoveLayer(-1), ...
    "Tooltip", "Draw the layer picked earlier (under the later ones; the first layer's units are a raster's top rows).");
E.layerDown = uibutton(lb, "Text", "Down", "ButtonPushedFcn", @(~,~) obj.onMoveLayer(1), ...
    "Tooltip", "Draw the layer picked later.");
[S, r] = formRow(S, "layerNote", "");
E.layerNote = uilabel(S.Body, "Text", "", "FontColor", [0.70 0.15 0.10]);
place(E.layerNote, r, [1 2]);
[S, r] = formRow(S, ["layerName" "layerEnabled"], "Name:");
ng = subgrid(S.Body, r, {'1x', 'fit'});
E.layerName = uieditfield(ng, "text", "Placeholder", "automatic", "ValueChangedFcn", changed, ...
    "Tooltip", "The layer's name in the legend and the aesthetics editor (blank: the unit's, channel's or event's label).");
E.layerEnabled = uicheckbox(ng, "Text", "Enabled", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Unticked, the layer stays in the panel but is not drawn.");
[S, r] = formRow(S, "layerSource", "Source:");
E.layerSource = uidropdown(S.Body, "Items", "units", "ValueChangedFcn", changed, ...
    "Tooltip", "What the layer reads: only the sources the panel's type draws. Events layers are always fixed.");
place(E.layerSource, r, 2);
[S, r] = formRow(S, "layerBinding", "Binding:");
E.layerBinding = uidropdown(S.Body, "Items", ["Follows the observation" "Fixed"], "ItemsData", ["observation" "fixed"], ...
    "ValueChangedFcn", @(~, evt) onBindingEdited(obj, evt), "Tooltip", "Follows the observation: the unit or " + ...
    "channel picked over the preview (another spike source: its channel's; a signal: the unit's own channel). Fixed: " + ...
    "the units or channels named below; a spike layer fixed while it shows a unit keeps that unit (its id).");
place(E.layerBinding, r, 2);
[S, r] = formRow(S, "layerFollows", "", 30);
E.layerFollows = uilabel(S.Body, "Text", "", "FontColor", gray, "WordWrap", "on");
place(E.layerFollows, r, [1 2]);
[S, r] = formRow(S, "layerClasses", "Unit classes:");
cg = subgrid(S.Body, r, repmat({'fit'}, 1, 4));
cg.ColumnSpacing = 12;
E.layerClasses = struct();
for c = ["su" "mua" "uns" "noise"]
    E.layerClasses.(c) = uicheckbox(cg, "Text", c, "Value", ismember(c, ["su" "mua"]), "ValueChangedFcn", changed, ...
        "Tooltip", "Sorted-unit classes the layer keeps (none ticked = every class).");
end
[S, r] = formRow(S, "layerIds", "Unit ids:");
E.layerIds = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "Unit ids (sorted units) or channels (detections) the layer draws, e.g. 3 5.");
place(E.layerIds, r, 2);
[S, r] = formRow(S, ["layerQuality" "layerResponse"], "");
qg = subgrid(S.Body, r, {'fit', 'fit', '1x'});
qg.ColumnSpacing = 12;
E.layerQuality = uicheckbox(qg, "Text", "Good units only", "ValueChangedFcn", changed, ...
    "Tooltip", "Keep only the sorted units that meet the good-unit criteria.");
E.layerResponse = uicheckbox(qg, "Text", "Responsive only", "ValueChangedFcn", changed, ...
    "Tooltip", "Keep only the units that respond to the event (the test settings in the config).");
[S, r] = formRow(S, "layerMaxUnits", "Max units:");
E.layerMaxUnits = uieditfield(S.Body, "text", "Value", "Inf", "ValueChangedFcn", changed);
place(E.layerMaxUnits, r, 2);
[S, r] = formRow(S, "layerShanks", "Shanks:");
E.layerShanks = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed);
place(E.layerShanks, r, 2);
[S, r] = formRow(S, "layerUnitChannels", "Channels:");
E.layerUnitChannels = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "The recording channels whose units the layer keeps.");
place(E.layerUnitChannels, r, 2);
[S, r] = formRow(S, "layerChannels", "Channels:");
E.layerChannels = uieditfield(S.Body, "text", "Placeholder", "all, e.g. 3 5 8", "ValueChangedFcn", changed, ...
    "Tooltip", "The extract's columns the layer draws (blank = all).");
place(E.layerChannels, r, 2);
[S, r] = formRow(S, "layerAggregate", "Aggregate:");
E.layerAggregate = uidropdown(S.Body, "Items", ["each one" "their mean"], "ItemsData", ["each" "mean"], "ValueChangedFcn", changed, ...
    "Tooltip", "Several units or channels: a trace or block for each, or their mean with a band across them. On a " + ...
    "spectrum, spectrogram or coherence panel a signal's channels as one: their vector magnitude, sqrt(x² + y² + z²), " + ...
    "each channel's 2 s running mean taken out first (e.g. an accelerometer's offsets and gravity).");
place(E.layerAggregate, r, 2);
[S, r] = formRow(S, "evLine", "Line:");
E.evLine = uidropdown(S.Body, "Editable", "on", "Items", "Stim", "Value", "Stim", "ValueChangedFcn", changed, ...
    "Tooltip", "The digital or derived line whose events the layer draws; ""Trial"" is the paired trial line.");
place(E.evLine, r, 2);
[S, r] = formRow(S, "evEdge", "Edge:");
E.evEdge = uidropdown(S.Body, "Items", ["onset" "offset"], "ValueChangedFcn", changed, "Tooltip", "The line's onsets or offsets.");
place(E.evEdge, r, 2);
[S, r] = formRow(S, ["evSeqText" "evSeqEdit"], "Sequence:");
sg = subgrid(S.Body, r, {'1x', 70});
E.evSeqText = uilabel(sg, "Text", "none");
setSequenceHolder(E.evSeqText, struct('sequence', repmat(EphysAnalysisConfig.defaults("SequenceStep"), 1, 0), 'alignStep', Inf));
E.evSeqEdit = uibutton(sg, "Text", "Edit...", "Tooltip", "Events that must (or must not) follow the line's event, " + ...
    "e.g. Stim onset then Trough onset: the first Trough onset after each Stim onset.");
E.evSeqEdit.ButtonPushedFcn = @(~,~) obj.editSequence(E.evSeqText, E.evLine, E.evEdge, @() obj.onConfigChanged("figure", "Event sequence"));
[S, r] = formRow(S, "evDrawAs", "Draw as:");
E.evDrawAs = uidropdown(S.Body, "Items", ["marks (on the rows / latency lines)" "a spike train of its own" ...
    "a line from onset to offset"], "ItemsData", ["marks" "train" "span"], "ValueChangedFcn", changed, ...
    "Tooltip", "Marks: a mark at each event on a raster's rows, a line at each group's median latency elsewhere. A " + ...
    "train: the events as a spike train, drawn as a unit would be (rows of their own in a raster, a PSTH of their " + ...
    "own). A line from onset to offset: on each raster row a line from each interval's onset to its offset; " + ...
    "elsewhere a line per trial group from the median onset to the median offset, near the top. An event-trace " + ...
    "panel draws its lines its own way (its Options).");
place(E.evDrawAs, r, 2);
MK = PlotAesthetics.catalog().Marker;
[S, r] = formRow(S, ["evMarker" "evSize"], "Marker:");
mg = subgrid(S.Body, r, {'1x', 'fit', 70});
E.evMarker = uidropdown(mg, "Items", MK.ChoiceLabels(2:end), "ItemsData", MK.Choices(2:end), "Value", "diamond", ...
    "ValueChangedFcn", changed, "Tooltip", "The mark drawn at each event on the raster's rows.");
uilabel(mg, "Text", "size:");
E.evSize = uispinner(mg, "Limits", [0.5 60], "Step", 1, "Value", 4, "ValueChangedFcn", changed, "Tooltip", "The mark's size, points.");
[S, r] = formRow(S, "evColor", "Mark color:");
E.evColor = uidropdown(S.Body, "Editable", "on", "Items", ["auto" "black" "red" "blue" "#ff7f0e" "#9467bd"], "Value", "auto", ...
    "ValueChangedFcn", changed, "Tooltip", "auto: the mark's automatic color; or a name or #RRGGBB. A span's line takes it too.");
place(E.evColor, r, 2);
[S, r] = formRow(S, ["evSpanStyle" "evSpanWidth" "evSpanAlpha"], "Span line:");
spg = subgrid(S.Body, r, {'1x', 'fit', 60, 'fit', 50});
E.evSpanStyle = uidropdown(spg, "Items", ["solid" "dashed" "dotted" "dash-dot"], "ItemsData", EphysAnalysisConfig.OverlayLineStyles, ...
    "Value", "-", "ValueChangedFcn", changed, "Tooltip", "The style of the line from each onset to its offset.");
uilabel(spg, "Text", "width");
E.evSpanWidth = uispinner(spg, "Limits", [0.25 12], "Step", 0.25, "Value", 1.5, "ValueChangedFcn", changed, ...
    "Tooltip", "The span line's width, points.");
uilabel(spg, "Text", "opacity");
E.evSpanAlpha = uieditfield(spg, "numeric", "Limits", [0 1], "Value", 1, "ValueChangedFcn", changed, ...
    "Tooltip", "0 (invisible) to 1 (solid).");
[S, r] = formRow(S, "layerColor", "Color:");
E.layerColor = uidropdown(S.Body, "Editable", "on", "Items", ["auto" "black" "gray" "red" "blue" "#1f77b4" "#d62728"], ...
    "Value", "auto", "ValueChangedFcn", changed, "Tooltip", "auto: each trial group's color (an event-trace panel: a " + ...
    "palette color per line); or one color (a name or #RRGGBB) for every trace of this layer.");
place(E.layerColor, r, 2);
[S, r] = formRow(S, "layerLineStyle", "Line style:");
E.layerLineStyle = uidropdown(S.Body, "Items", ["auto (by layer order)" "solid" "dashed" "dotted" "dash-dot"], ...
    "ItemsData", ["auto" EphysAnalysisConfig.OverlayLineStyles], "Value", "auto", "ValueChangedFcn", changed, ...
    "Tooltip", "auto: the first layer solid, the next dashed, dotted, dash-dot.");
place(E.layerLineStyle, r, 2);
sec(end+1) = S;

% the panel type's options: every type's rows, shown per type (syncFigureEditor)
S = formSection(eg, 11, "options", "Options", Color=tint("options"));
[S, r] = formRow(S, "optApplyAll", "", 30);
E.optApplyAll = uibutton(S.Body, "Text", "Apply to all panels", "ButtonPushedFcn", @(~,~) applyOptionsToAll(obj), ...
    "Tooltip", "Copy this panel's bins, smoothing, measure, baseline (with its window and auROC settings), mask and " + ...
    "waveform inset (the Waveform section) to every other panel that has those rows (the baseline only where the type takes its mode), " + ...
    "its other options to the other panels of its type, and its X axis and Y axis sides to every other panel " + ...
    "(not its label texts).");
place(E.optApplyAll, r, [1 2]);
[S, r] = formRow(S, "binMs", "Bin (ms):");
E.binMs = uieditfield(S.Body, "numeric", "Value", 10, "Limits", [0.001 Inf], "ValueChangedFcn", changed);
place(E.binMs, r, 2);
[S, r] = formRow(S, "smoothMs", "Smooth (ms):");
E.smoothMs = uieditfield(S.Body, "numeric", "Value", 10, "Limits", [0 Inf], "ValueChangedFcn", changed, "Tooltip", "Gaussian SD; 0 = none.");
place(E.smoothMs, r, 2);
[S, r] = formRow(S, "measure", "Measure:");
E.measure = uidropdown(S.Body, "Items", ["rate" "count" "probability"], "ValueChangedFcn", changed, ...
    "Tooltip", "rate: spikes/s; count: spikes per bin; probability: the share of epochs with a spike in the bin.");
place(E.measure, r, 2);
[S, r] = formRow(S, "baselineMode", "Baseline:");
E.baselineMode = uidropdown(S.Body, "Items", "none", "ValueChangedFcn", changed, ...
    "Tooltip", "subtract / zscore / percent / ratio: against the baseline window's value, epoch by epoch. auroc (PSTH, " + ...
    "heat map of spikes): each window's auROC against the baseline, 0.5 = no change, above = more firing (Cohen et " + ...
    "al. 2012; Macedo-Lima et al. 2024); its settings below.");
place(E.baselineMode, r, 2);
[S, r] = formRow(S, ["baseFrom" "baseTo"], "Baseline (s):");
bg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.baseFrom = uieditfield(bg, "numeric", "Value", -0.2, "ValueChangedFcn", changed, "Tooltip", "Baseline window start (s from the event).");
uilabel(bg, "Text", "to");
E.baseTo = uieditfield(bg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "Baseline window end (s).");
[S, E] = aurocRows(S, E, "au", changed, true);
[S, r] = formRow(S, ["param" "seriesParam"], "Parameter:");
pg2 = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.param = uidropdown(pg2, "Editable", "on", "Items", "", "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "The trial parameter on the x axis. Blank: the figure's first group-by parameter, else the first numeric one.");
uilabel(pg2, "Text", "series:");
E.seriesParam = uidropdown(pg2, "Editable", "on", "Items", "", "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "One curve per value of this trial parameter (blank: one curve).");
[S, r] = formRow(S, "rateDisplay", "Display:");
E.rateDisplay = uidropdown(S.Body, "Items", ["bars (mean, error bar)" "boxes" "points (each epoch)"], ...
    "ItemsData", ["bar" "box" "points"], "ValueChangedFcn", changed, "Tooltip", "Per trial group along x: the mean " + ...
    "with its error bar, a box of the epochs' rates, or each epoch's rate as a dot over a bar of their mean (a " + ...
    "layer's mean over units: of the units' means).");
place(E.rateDisplay, r, 2);
[S, r] = formRow(S, "waveLayout", "Layout:");
E.waveLayout = uidropdown(S.Body, "Items", ["grid (the unit, or several overlaid)" "probe (every unit at its place)"], ...
    "ItemsData", ["grid" "probe"], "ValueChangedFcn", changed, "Tooltip", "Probe: every unit of the first layer drawn " + ...
    "at its place on the probe (bind that layer to fixed units); a further layer, e.g. one following the observed " + ...
    "unit, is framed in red there.");
place(E.waveLayout, r, 2);
[S, r] = formRow(S, "heatRows", "Rows:");
E.heatRows = uidropdown(S.Body, "Items", ["the layer's units or channels" "one unit's epochs (trials)"], ...
    "ItemsData", ["items" "trials"], "ValueChangedFcn", changed, "Tooltip", "Units or channels: a row each, one " + ...
    "trial group (Group shown). Trials: a row per epoch of one unit (a layer following the observation, or fixed " + ...
    "to one unit), every group, sorted as a raster's rows (Sort rows by), the groups as a color strip at the left.");
place(E.heatRows, r, 2);
[S, r] = formRow(S, ["rasterSort" "rasterSortOrder"], "Sort rows by:");
rsg = subgrid(S.Body, r, {'1x', 110});
E.rasterSort = uidropdown(rsg, "Editable", "on", "Items", ["" "stop" "event" "latency"], "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "The order of the raster's epochs: blank = trial (time) order; stop = the stop event's latency; " + ...
    "event = the latency of the sort event below; latency = the first spike's latency (a raster: in the First spike " + ...
    "window, else from the event to the window's end; none in the window = last); or a trial parameter. Missing values go last.");
E.rasterSortOrder = uidropdown(rsg, "Items", ["ascending" "descending"], "ValueChangedFcn", changed, ...
    "Tooltip", "The sort's direction. Missing values stay last.");
[S, r] = formRow(S, ["sortLine" "sortEdge"], "Sort event:");
seg = subgrid(S.Body, r, {'1x', 80});
E.sortLine = uidropdown(seg, "Editable", "on", "Items", "", "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "Sort rows by ""event"": the line whose event orders the rows by its latency from each epoch's event.");
E.sortEdge = uidropdown(seg, "Items", ["onset" "offset"], "ValueChangedFcn", changed, "Tooltip", "The sort event's edge.");
[S, r] = formRow(S, ["sortSeqText" "sortSeqEdit"], "Sort sequence:");
ssg = subgrid(S.Body, r, {'1x', 70});
E.sortSeqText = uilabel(ssg, "Text", "none");
setSequenceHolder(E.sortSeqText, struct('sequence', repmat(EphysAnalysisConfig.defaults("SequenceStep"), 1, 0), 'alignStep', Inf));
E.sortSeqEdit = uibutton(ssg, "Text", "Edit...", "Tooltip", "Events that must follow the sort event's line.");
E.sortSeqEdit.ButtonPushedFcn = @(~,~) obj.editSequence(E.sortSeqText, E.sortLine, E.sortEdge, @() obj.onConfigChanged("figure", "Sort sequence"));
[S, r] = formRow(S, "rasterByGroup", "");
E.rasterByGroup = uicheckbox(S.Body, "Text", "Rows by group first", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Ticked: each group's epochs together. Unticked: every epoch sorted as one block.");
place(E.rasterByGroup, r, [1 2]);
[S, r] = formRow(S, "yTicks", "");
E.yTicks = uicheckbox(S.Body, "Text", "Show y ticks", "ValueChangedFcn", changed, ...
    "Tooltip", "Ticked: the y axis keeps its tick marks and epoch numbers. Unticked (the default): none; the y label stays, " + ...
    "and so do the names of a raster's further blocks.");
place(E.yTicks, r, [1 2]);
[S, r] = formRow(S, ["tickColor" "backColor"], "Colors:");
rcg = subgrid(S.Body, r, {'fit', '1x', 'fit', '1x'});
uilabel(rcg, "Text", "ticks");
E.tickColor = uidropdown(rcg, "Editable", "on", "Items", ["groups" "black" "white" "gray" "red" "blue" "#ff7f0e"], "Value", "groups", ...
    "ValueChangedFcn", changed, "Tooltip", "The color of the ticks: groups = each group's color (as the PSTH's traces); " + ...
    "or a color name or #RRGGBB for every tick. A layer's own Color wins.");
uilabel(rcg, "Text", "bands");
E.backColor = uidropdown(rcg, "Editable", "on", "Items", ["none" "groups" "white" "black" "gray" "#f0f0f0" "#fffbe6"], "Value", "none", ...
    "ValueChangedFcn", changed, "Tooltip", "Bands behind the rows: none; groups = each group's pale band; or a color " + ...
    "name or #RRGGBB, the same for every group.");
[S, r] = formRow(S, "tickWidth", "Tick width:");
E.tickWidth = uispinner(S.Body, "Limits", [0 12], "Step", 0.25, "Value", 0, "ValueChangedFcn", changed, ...
    "Tooltip", "The ticks' line width in points; 0 = the plot design's width.");
place(E.tickWidth, r, 2);
[S, r] = formRow(S, ["firstSpike" "firstSpikeDialog"], "First spike:", 30);
fsg = subgrid(S.Body, r, {'1x', 'fit'});
E.firstSpike = uilabel(fsg, "Text", "off", "Tooltip", "The first-spike latency marks: on or off, the latency window " + ...
    "(ms from the event; end = the window's end) and the mark.");
E.firstSpikeDialog = uibutton(fsg, "Text", "First-spike latency...", "ButtonPushedFcn", @(~,~) latencyDialog(obj, "firstSpike"), ...
    "Tooltip", "Mark each epoch's first spike in a latency window (its minimum and maximum, ms from the event) on " + ...
    "its row, over the ticks: the marker, its size and color (each group's or one), filled or not.");
[S, r] = formRow(S, "maskAfterStop", "");
E.maskAfterStop = uicheckbox(S.Body, "Text", "Mask after the stop event", "ValueChangedFcn", changed, ...
    "Tooltip", "Drop what follows each epoch's stop event (the Epoch window's).");
place(E.maskAfterStop, r, [1 2]);
[S, r] = formRow(S, "psthDisplay", "Display:");
E.psthDisplay = uidropdown(S.Body, "Items", ["trace (bars or a line per group)" "heat map (a row per group)"], ...
    "ItemsData", ["trace" "heatmap"], "ValueChangedFcn", changed, "Tooltip", "Trace: each trial group's PSTH as bars " + ...
    "or a line (PSTH as). Heat map: the unit's PSTH as an image, a row per trial group (the first on top), colored by " + ...
    "its rate on this unit's own range (Colormap, Color limits); with several units or layers, the first is drawn.");
place(E.psthDisplay, r, 2);
[S, r] = formRow(S, "histStyle", "PSTH as:");
E.histStyle = uidropdown(S.Body, "Items", ["bar" "line"], "ValueChangedFcn", changed, "Tooltip", "One bar per bin, or a line through the bin centers.");
place(E.histStyle, r, 2);
[S, r] = formRow(S, ["fill" "fillAlpha"], "Fill:");
fg = subgrid(S.Body, r, {'fit', 'fit', '1x'});
E.fill = uicheckbox(fg, "Text", "Filled", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Fill the bars, or the area under the line.");
uilabel(fg, "Text", "opacity:");
E.fillAlpha = uieditfield(fg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "auto", "Limits", [0 1], ...
    "ValueChangedFcn", changed, "Tooltip", "Fill opacity, 0 to 1 (blank: 0.5 where groups overlap, else 1).");
[S, r] = formRow(S, "normalize", "Normalize:");
E.normalize = uidropdown(S.Body, "Items", ["none" "across groups" "within groups" "across all"], "ItemsData", ["none" "unitPeak" "groupPeak" "allPeak"], ...
    "ValueChangedFcn", changed, "Tooltip", "Divide each unit's PSTHs by their largest peak (across groups), each PSTH " + ...
    "by its own (within groups), or every PSTH by the largest of all.");
place(E.normalize, r, 2);
[S, r] = formRow(S, ["stack" "stackSpacing"], "Stack:");
sk = subgrid(S.Body, r, {'1x', 'fit', 60});
E.stack = uidropdown(sk, "Items", ["Off (overlaid)" "One row per group" "One row per channel"], "ItemsData", ["off" "groups" "items"], ...
    "ValueChangedFcn", changed, "Tooltip", "Off: the trial groups overlaid (a heat map, spectrogram or coherogram: the one " + ...
    "group of Group). One row per group: each trial group in a row of its own, the first on top (as a raster lists " + ...
    "them), named on the left axis; lines show each row's top (a PSTH's peak) on the right axis, images share the " + ...
    "time axis and one color bar, each with its group's color strip. One row per channel (a continuous panel): each " + ...
    "channel in a row of its own, the groups overlaid in it. A raster lists its groups in blocks already, a firing " + ...
    "rate panel puts them along x, and a waveforms, probe map, unit correlation or event-trace panel has no groups " + ...
    "over a shared axis: none of them stacks.");
uilabel(sk, "Text", "spacing:");
E.stackSpacing = uieditfield(sk, "numeric", "Value", 1.1, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "The row step, x the row height (the tallest row): 1 the rows touch, below 1 " + ...
    "they overlap (an image row never does: below 1 counts as 1).");
[S, r] = formRow(S, ["latencyBox" "latencyBoxDialog"], "Latency box:", 30);
lbg = subgrid(S.Body, r, {'1x', 'fit'});
E.latencyBox = uilabel(lbg, "Text", "off", "Tooltip", "The box plot of the first-spike latencies: on or off, the latency " + ...
    "window (ms from the event; end = the window's end) and its color.");
E.latencyBoxDialog = uibutton(lbg, "Text", "Latency box plot...", "ButtonPushedFcn", @(~,~) latencyDialog(obj, "latencyBox"), ...
    "Tooltip", "A box plot of each epoch's first-spike latency per trial group (median, quartiles, whiskers to 1.5 " + ...
    "IQR, outliers) in a band above the traces (stacked: in each row): the latency window, color, line, box height, " + ...
    "fill and outliers.");
[S, r] = formRow(S, "trialCount", "Trial count:");
E.trialCount = uidropdown(S.Body, "Items", ["Off" "Text in the plot (n = 24)" "In the legend entries"], "ItemsData", ["off" "text" "legend"], ...
    "ValueChangedFcn", changed, "Tooltip", "How many trials each group has: written in the group's color in the plot " + ...
    "(top left; stacked and heat map: at the right end of each row), or after the group's name in the legend " + ...
    "(a heat map: in the row's label). A single group has no legend entry: it gets the text.");
place(E.trialCount, r, 2);
[S, r] = formRow(S, ["statistic" "transform"], "Signal:");
tg = subgrid(S.Body, r, {'1x', '1x'});
E.statistic = uidropdown(tg, "Items", ["Mean" "Median"], "ItemsData", EphysAnalysisConfig.AuxStatistics, "ValueChangedFcn", changed, ...
    "Tooltip", "What is drawn at each sample, over the epochs of a group.");
E.transform = uidropdown(tg, "Items", ["As recorded" "Rectified |x|" "Vector magnitude"], "ItemsData", EphysAnalysisConfig.AuxTransforms, ...
    "ValueChangedFcn", changed, "Tooltip", "Rectified: each epoch's absolute value, before the mean or median. Vector " + ...
    "magnitude: each layer's channels as one trace, sqrt(x² + y² + z²) at every sample of each epoch, after the baseline " + ...
    "(subtract one to take out each axis's offset, e.g. gravity on an accelerometer), before the mean or median.");
[S, r] = formRow(S, "errorType", "Error band:");
E.errorType = uidropdown(S.Body, "Items", ["Off" "mean ± SEM" "mean ± SD" "bootstrap 95% CI" "interquartile range"], ...
    "ItemsData", EphysAnalysisConfig.AuxErrorTypes, "ValueChangedFcn", changed, ...
    "Tooltip", "The band around each trace, over the epochs (the bootstrap and the interquartile range need the " + ...
    "Statistics and Machine Learning Toolbox).");
place(E.errorType, r, 2);
[S, r] = formRow(S, ["contTrials" "maxTrials"], "Trials:");
tg2 = subgrid(S.Body, r, {'1x', 'fit', 70});
E.contTrials = uidropdown(tg2, "Items", ["Off" "Faint, behind the mean" "Only the trials"], "ItemsData", ["off" "faint" "only"], ...
    "ValueChangedFcn", changed, "Tooltip", "Each epoch's trace: off; faint (pale and thin, behind the mean and its " + ...
    "band); or only the traces, without the mean.");
uilabel(tg2, "Text", "at most:");
E.maxTrials = uieditfield(tg2, "numeric", "Value", 100, "Limits", [1 Inf], "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "The most epochs drawn, picked evenly over their order (default 100; Inf = every one).");
[S, r] = formRow(S, "order", "Row order:");
E.order = uidropdown(S.Body, "Items", ["probe" "peak" "modulation"], "ValueChangedFcn", changed, ...
    "Tooltip", "probe: the rows follow the sort options (Appearance); peak: by the time of each row's maximum; " + ...
    "modulation (the auROC baseline): by the mean auROC in the call window, highest first.");
place(E.order, r, 2);
[S, r] = formRow(S, "value", "Value:");
E.value = uidropdown(S.Body, "Items", ["rate" "nSpikes" "nUnits"], "ValueChangedFcn", changed, "Tooltip", "What colors each site.");
place(E.value, r, 2);
[S, r] = formRow(S, "metric", "Epoch rate:");
E.metric = uidropdown(S.Body, "Items", ["mean" "peak"], "ValueChangedFcn", changed, ...
    "Tooltip", "Each epoch's mean rate over its window, or its peak binned rate.");
place(E.metric, r, 2);
[S, r] = formRow(S, "correlation", "Correlation:");
E.correlation = uidropdown(S.Body, "Items", ["Pearson" "Spearman"], "ItemsData", ["pearson" "spearman"], "ValueChangedFcn", changed);
place(E.correlation, r, 2);
[S, r] = formRow(S, "fisherZ", "");
E.fisherZ = uicheckbox(S.Body, "Text", "Fisher z transform", "ValueChangedFcn", changed, ...
    "Tooltip", "Draw z = atanh(r) instead of r.");
place(E.fisherZ, r, [1 2]);
% the event-trace panel: a row per line, its intervals as bars or a logic level
[S, r] = formRow(S, "etDisplay", "Draw as:");
E.etDisplay = uidropdown(S.Body, "Items", ["solid bars (onset to offset)" "a logic level (a line)"], "ItemsData", ["bars" "line"], ...
    "ValueChangedFcn", changed, "Tooltip", "Bars: a solid bar from each onset to its offset. A logic level: a line " + ...
    "that is low, rises at each onset and falls at its offset. Intervals that start before or end after the window " + ...
    "are drawn to its edge.");
place(E.etDisplay, r, 2);
[S, r] = formRow(S, ["etTrials" "etGroupBands"], "Trials:");
etg = subgrid(S.Body, r, {'1x', 'fit'});
E.etTrials = uidropdown(etg, "Items", ["every epoch overlaid in the line's row" "a sub-row per epoch"], "ItemsData", ["overlay" "rows"], ...
    "ValueChangedFcn", changed, "Tooltip", "Overlaid: every epoch drawn in the line's row, translucent, so the " + ...
    "spread of the timing shows. A sub-row per epoch: each epoch in a sub-row of its own inside the line's row, " + ...
    "sorted as a raster's rows (Sort rows by; by default by trial group and then time).");
E.etGroupBands = uicheckbox(etg, "Text", "group bands", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "A sub-row per epoch: a pale band of each trial group's color behind its sub-rows.");
[S, r] = formRow(S, "etColorBy", "Color by:");
E.etColorBy = uidropdown(S.Body, "Items", ["line (the layer's color, else a palette color)" "trial group"], "ItemsData", ["layer" "group"], ...
    "ValueChangedFcn", changed, "Tooltip", "Line: each line in its layer's Color (Layers), or a color of the " + ...
    "design's palette. Trial group: each epoch in its group's color, the groups in the legend.");
place(E.etColorBy, r, 2);
[S, r] = formRow(S, ["etHeight" "etAlpha"], "Height:");
ehg = subgrid(S.Body, r, {'1x', 'fit', 60});
E.etHeight = uispinner(ehg, "Limits", [0.05 1], "Step", 0.05, "Value", 0.6, "ValueChangedFcn", changed, ...
    "Tooltip", "The bars' (or the level's) height, a share of the line's row (a sub-row per epoch: of the epoch's sub-row).");
uilabel(ehg, "Text", "opacity:");
E.etAlpha = uieditfield(ehg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "auto", "Limits", [0 1], ...
    "ValueChangedFcn", changed, "Tooltip", "The bars' and lines' opacity, 0 to 1 (blank: 0.3 overlaid, 1 in sub-rows).");
[S, r] = formRow(S, ["etEdge" "etEdgeWidth"], "Bar outline:");
eeg = subgrid(S.Body, r, {'1x', 'fit', 60});
E.etEdge = uidropdown(eeg, "Editable", "on", "Items", ["none" "auto" "black" "white" "gray"], "Value", "none", ...
    "ValueChangedFcn", changed, "Tooltip", "none: no outline; auto: the bar's own color; or a name or #RRGGBB.");
uilabel(eeg, "Text", "width");
E.etEdgeWidth = uispinner(eeg, "Limits", [0.25 12], "Step", 0.25, "Value", 0.5, "ValueChangedFcn", changed, ...
    "Tooltip", "The outline's width, points.");
[S, r] = formRow(S, "etMinWidth", "Narrowest bar:");
E.etMinWidth = uispinner(S.Body, "Limits", [0 12], "Step", 0.25, "Value", 1, "ValueChangedFcn", changed, ...
    "Tooltip", "Points. A bar drawn narrower than this (a zero-length interval too) also gets a tick this wide " + ...
    "through its middle, in its color, so a short interval shows at any size and in exported files. 0: no tick.");
place(E.etMinWidth, r, 2);
[S, r] = formRow(S, ["etLineStyle" "etLineWidth"], "Level line:");
elg = subgrid(S.Body, r, {'1x', 'fit', 60});
E.etLineStyle = uidropdown(elg, "Items", ["solid" "dashed" "dotted" "dash-dot"], "ItemsData", EphysAnalysisConfig.OverlayLineStyles, ...
    "Value", "-", "ValueChangedFcn", changed, "Tooltip", "The logic level's style (a layer's own Line style wins).");
uilabel(elg, "Text", "width");
E.etLineWidth = uispinner(elg, "Limits", [0.25 12], "Step", 0.25, "Value", 1.5, "ValueChangedFcn", changed, ...
    "Tooltip", "The logic level's width, points.");
[S, r] = formRow(S, ["etBaseline" "etBaseColor"], "Baseline:");
ebg = subgrid(S.Body, r, {'fit', '1x'});
E.etBaseline = uicheckbox(ebg, "Text", "Draw", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "A line along each row: through the middle of the bars, or at the logic level's low (zero) level.");
E.etBaseColor = uidropdown(ebg, "Editable", "on", "Items", ["auto" "gray" "black" "white" "#bbbbbb"], "Value", "auto", ...
    "ValueChangedFcn", changed, "Tooltip", "auto: gray; or a name or #RRGGBB.");
[S, r] = formRow(S, ["etBaseStyle" "etBaseWidth"], "Baseline line:");
ebs = subgrid(S.Body, r, {'1x', 'fit', 60});
E.etBaseStyle = uidropdown(ebs, "Items", ["solid" "dashed" "dotted" "dash-dot"], "ItemsData", EphysAnalysisConfig.OverlayLineStyles, ...
    "Value", ":", "ValueChangedFcn", changed, "Tooltip", "The baseline's style.");
uilabel(ebs, "Text", "width");
E.etBaseWidth = uispinner(ebs, "Limits", [0.25 12], "Step", 0.25, "Value", 0.5, "ValueChangedFcn", changed, ...
    "Tooltip", "The baseline's width, points.");
[S, r] = formRow(S, "etRowSpacing", "Row spacing:");
E.etRowSpacing = uieditfield(S.Body, "numeric", "Value", 1.25, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "The step from one line's row to the next, in row heights (1: the rows touch; more leaves a gap).");
place(E.etRowSpacing, r, 2);
[S, r] = formRow(S, ["yLim" "yLimMode"], "Y limits:");
yg = subgrid(S.Body, r, {'1x', '1x'});
E.yLimMode = uidropdown(yg, "Items", ["Auto" "Shared by rows" "Shared by batch" "Fixed"], ...
    "ItemsData", EphysAnalysisConfig.YLimModes, "ValueChangedFcn", changed, "Tooltip", "Auto: the axis fits this " + ...
    "panel's data (in a stack each row fits itself, its top on the right axis). Shared by rows: a stack's rows share " + ...
    "one scale (overlaid groups share the one axis already). Shared by batch: every observation of a Generate selected figure or " + ...
    "Export run of this figure on one range, the union over the run's datasets (the preview draws its own range). " + ...
    "Fixed: the limits typed beside it.");
E.yLim = uieditfield(yg, "text", "Placeholder", "lo hi", "ValueChangedFcn", changed, ...
    "Tooltip", "Fixed: the y axis' two ascending values (a stack: every row's range).");
[S, r] = formRow(S, "panelColormap", "Colormap:");
E.panelColormap = uidropdown(S.Body, "Editable", "on", "Items", ["auto" "parula" "turbo" "hot" "gray" "jet" "cool" "blueWhiteRed"], ...
    "Value", "auto", "ValueChangedFcn", changed, "Tooltip", "This panel's colors: auto = Heat colors (Appearance), else " + ...
    "the design's heat colormap (an auROC: its diverging one); or the name of a colormap function.");
place(E.panelColormap, r, 2);
[S, r] = formRow(S, "cLim", "Color limits:");
E.cLim = uieditfield(S.Body, "text", "Placeholder", "automatic, or lo hi", "ValueChangedFcn", changed, ...
    "Tooltip", "This panel's color scale: two ascending values. Blank: automatic.");
place(E.cLim, r, 2);
% the spectral panels (spectrum, spectrogram, coherence): the Chronux tab's rows
[S, r] = formRow(S, "spTimeBase", "Time base:");
E.spTimeBase = uidropdown(S.Body, "Items", ["the panel's epochs" "segments of the recording"], "ItemsData", ["aligned" "range"], ...
    "ValueChangedFcn", changed, "Tooltip", "Epochs: the trials are the panel's epochs around its event, one result per " + ...
    "trial group. Segments: a stretch of the recording (Range) cut into back-to-back segments clear of the artifact " + ...
    "periods, all one group; the figure's event and window are not used.");
place(E.spTimeBase, r, 2);
[S, r] = formRow(S, ["spRangeFrom" "spRangeTo"], "Range (s):");
rg2 = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.spRangeFrom = uieditfield(rg2, "numeric", "Value", 0, "Limits", [0 Inf], "ValueChangedFcn", changed, ...
    "Tooltip", "Segments: the stretch's start, s on the recording's clock.");
uilabel(rg2, "Text", "to");
E.spRangeTo = uieditfield(rg2, "numeric", "Value", Inf, "Limits", [0 Inf], "ValueChangedFcn", changed, ...
    "Tooltip", "Segments: the stretch's end, s (Inf = the recording's end).");
[S, r] = formRow(S, "spSegment", "Segment (s):");
E.spSegment = uieditfield(S.Body, "numeric", "Value", 2, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "Segments: each one's length, s (a trial of the spectra).");
place(E.spSegment, r, 2);
[S, r] = formRow(S, "spTaperMode", "Tapers:");
E.spTaperMode = uidropdown(S.Body, "Items", ["TW and K" "W (Hz) and p"], "ItemsData", ["TWK" "Wp"], "ValueChangedFcn", changed, ...
    "Tooltip", "TW and K: the time-bandwidth product and the number of tapers as given. W and p: the half bandwidth " + ...
    "W Hz over the trial's (or moving window's) length T: tapers [W*T, 2*W*T - p].");
place(E.spTaperMode, r, 2);
[S, r] = formRow(S, ["spTW" "spK"], "TW, K:");
tk = subgrid(S.Body, r, {'1x', '1x'});
E.spTW = uieditfield(tk, "numeric", "Value", 3, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The time-bandwidth product TW.");
E.spK = uieditfield(tk, "numeric", "Value", 5, "Limits", [1 Inf], "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "The number of tapers K (at most 2TW - 1).");
[S, r] = formRow(S, ["spW" "spP"], "W (Hz), p:");
wp = subgrid(S.Body, r, {'1x', '1x'});
E.spW = uieditfield(wp, "numeric", "Value", 4, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The half bandwidth W, Hz.");
E.spP = uieditfield(wp, "numeric", "Value", 1, "Limits", [0 Inf], "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "p: the tapers are 2*W*T - p.");
[S, r] = formRow(S, "spPad", "Pad:");
E.spPad = uispinner(S.Body, "Limits", [-1 8], "Step", 1, "Value", 0, "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "FFT padding: -1 none, 0 to the next power of 2, 1 to the one after, ...");
place(E.spPad, r, 2);
[S, r] = formRow(S, ["spFmin" "spFmax"], "Frequency range:");
fr = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.spFmin = uieditfield(fr, "numeric", "Value", 0, "Limits", [0 Inf], "ValueChangedFcn", changed, "Tooltip", "The lowest frequency, Hz.");
uilabel(fr, "Text", "to");
E.spFmax = uieditfield(fr, "numeric", "Value", 100, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The highest frequency, Hz (Inf = the Nyquist frequency).");
[S, r] = formRow(S, ["spErr" "spErrP"], "Error:");
er = subgrid(S.Body, r, {'1x', 'fit', 60});
E.spErr = uidropdown(er, "Items", ["none" "theoretical" "jackknife"], "ValueChangedFcn", changed, ...
    "Tooltip", "The error bars: none; theoretical; jackknife (over the trials). A coherence's confidence level " + ...
    "needs either; its band, jackknife.");
uilabel(er, "Text", "p-value:");
E.spErrP = uieditfield(er, "numeric", "Value", 0.05, "Limits", [0 1], "LowerLimitInclusive", "off", "UpperLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "The bars' p (0.05: 95%).");
[S, r] = formRow(S, "spDetrend", "Detrend:");
E.spDetrend = uidropdown(S.Body, "Items", ["none" "constant (the mean)" "linear"], "ItemsData", ["none" "constant" "linear"], ...
    "ValueChangedFcn", changed, "Tooltip", "Removed from each trial before the spectra.");
place(E.spDetrend, r, 2);
[S, r] = formRow(S, "spScale", "Scale:");
E.spScale = uidropdown(S.Body, "Items", ["dB (10 log10)" "log axis" "linear"], "ItemsData", ["db" "log" "linear"], ...
    "ValueChangedFcn", changed, "Tooltip", "The power drawn: in dB, on a log axis, or as is (a spectrogram: dB or as is).");
place(E.spScale, r, 2);
[S, r] = formRow(S, "spSpikeFs", "Spike rate (Hz):");
E.spSpikeFs = uieditfield(S.Body, "numeric", "Value", 1000, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "Spike trains: the rate of the time grid their spectra are computed on.");
place(E.spSpikeFs, r, 2);
[S, r] = formRow(S, "spOverTime", "");
E.spOverTime = uicheckbox(S.Body, "Text", "Over time (a coherogram)", "ValueChangedFcn", changed, ...
    "Tooltip", "The coherence over the moving window, an image over time and frequency (on the epochs, on the " + ...
    "figure's time axis), of the first pair and the group shown: signals, spike trains, or one of each.");
place(E.spOverTime, r, [1 2]);
[S, r] = formRow(S, ["spWin" "spStep"], "Moving window (s):");
mw = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.spWin = uieditfield(mw, "numeric", "Value", 0.5, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "Each spectrum's window, s.");
uilabel(mw, "Text", "step:");
E.spStep = uieditfield(mw, "numeric", "Value", 0.05, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The window's step, s.");
[S, r] = formRow(S, "spShowPhase", "");
E.spShowPhase = uicheckbox(S.Body, "Text", "Show phase (under the magnitude)", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "The phase at the frequencies where the coherence is over its confidence level, in a strip under it.");
place(E.spShowPhase, r, [1 2]);
sec(end+1) = S;

% the selected panel's unit waveform: its own section, for every type whose layers may be spikes (waveformSection)
[S, E] = waveformSection(eg, E, changed, (tint("options") + tint("note")) / 2);   % its hue between its neighbors'
sec(end+1) = S;

% the selected panel's descriptive text (its note: drawNote)
S = formSection(eg, 15, "note", "Text note", Color=tint("note"));
[S, r] = formRow(S, "annText", "Text:", 78);
E.annText = uitextarea(S.Body, "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "Words to put on the selected panel -- a caption, a condition, a remark. Each new line is a line of " + ...
    "text; blank draws nothing. Where it goes, and how it looks, are set below.");
place(E.annText, r, 2);
[S, r] = formRow(S, "annPlace", "Place:");
E.annPlace = uidropdown(S.Body, "Items", ["Below the panel" "Above the panel" "Right of the panel" "Left of the panel" ...
    "Over the panel: top left" "Over the panel: top" "Over the panel: top right" "Over the panel: left" "Over the panel: center" ...
    "Over the panel: right" "Over the panel: bottom left" "Over the panel: bottom" "Over the panel: bottom right" "At x, y"], ...
    "ItemsData", EphysAnalysisConfig.NotePlacements, "Value", "below", "ValueChangedFcn", changed, ...
    "Tooltip", "Beside the panel, its tile gives up a band for the text next to its axes. Over the panel, the text " + ...
    "sits at that place in its axes, on top of what is drawn there. At x, y puts its anchor at the point below.");
place(E.annPlace, r, 2);
[S, r] = formRow(S, ["annX" "annY"], "At x, y:");
xyg = subgrid(S.Body, r, {'fit', '1x', 'fit', '1x'});
uilabel(xyg, "Text", "x");
E.annX = uieditfield(xyg, "numeric", "Value", 0.5, "Limits", [-2 3], "ValueChangedFcn", changed, ...
    "Tooltip", "Across the panel: 0 is its left edge, 1 its right. The text's anchor (its left, center or right edge, by Align) goes here.");
uilabel(xyg, "Text", "y");
E.annY = uieditfield(xyg, "numeric", "Value", 0.5, "Limits", [-2 3], "ValueChangedFcn", changed, ...
    "Tooltip", "Up the panel: 0 is its bottom edge, 1 its top. The text's anchor (its top, middle or bottom, by Align) goes here.");
[S, r] = formRow(S, ["annAlign" "annVAlign"], "Align:");
ag2 = subgrid(S.Body, r, {'1x', '1x'});
E.annAlign = uidropdown(ag2, "Items", ["Left" "Center" "Right"], "ItemsData", ["left" "center" "right"], "Value", "left", ...
    "ValueChangedFcn", changed, "Tooltip", "How the lines line up, left to right. Below and above the panel it is also " + ...
    "where the text sits across it; at x, y it is the anchor.");
E.annVAlign = uidropdown(ag2, "Items", ["Top" "Middle" "Bottom"], "ItemsData", ["top" "middle" "bottom"], "Value", "middle", ...
    "ValueChangedFcn", changed, "Tooltip", "Where the text sits up the panel beside it (right and left), or its anchor at x, y.");
[S, r] = formRow(S, "annRotation", "Rotation:");
E.annRotation = uispinner(S.Body, "Limits", [-180 180], "Step", 15, "Value", 0, "ValueDisplayFormat", "%g°", ...
    "ValueChangedFcn", changed, "Tooltip", "Degrees, counter-clockwise: 90 reads upwards (for the band beside the panel).");
place(E.annRotation, r, 2);
[S, r] = formRow(S, ["annFont" "annSize"], "Font:");
fg2 = subgrid(S.Body, r, {'1x', 70});
E.annFont = uidropdown(fg2, "Editable", "on", "Items", ["auto" "Arial" "Helvetica" "Times New Roman" "Courier New" "Calibri" ...
    "Segoe UI" "Verdana" "Georgia" "Palatino Linotype"], "Value", "auto", "ValueChangedFcn", changed, ...
    "Tooltip", "auto: the design's font. Or any installed font's name.");
E.annSize = uieditfield(fg2, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "auto", "Limits", [1 200], ...
    "ValueChangedFcn", changed, "Tooltip", "Points; blank is the figure's font size (Appearance).");
[S, r] = formRow(S, ["annBold" "annItalic" "annBox"], "Style:");
stg = subgrid(S.Body, r, {'fit', 'fit', 'fit', '1x'});
stg.ColumnSpacing = 12;
E.annBold = uicheckbox(stg, "Text", "Bold", "ValueChangedFcn", changed);
E.annItalic = uicheckbox(stg, "Text", "Italic", "ValueChangedFcn", changed);
E.annBox = uicheckbox(stg, "Text", "Outline", "ValueChangedFcn", changed, "Tooltip", "Draw a box round the text, in its color.");
[S, r] = formRow(S, ["annColor" "annBackground"], "Colors:");
ncg = subgrid(S.Body, r, {'fit', '1x', 'fit', '1x'});
uilabel(ncg, "Text", "text");
E.annColor = uidropdown(ncg, "Editable", "on", "Items", ["auto" "black" "white" "red" "blue" "green" "magenta" "cyan"], ...
    "Value", "auto", "ValueChangedFcn", changed, "Tooltip", "auto: the design's text color; or a name or #RRGGBB.");
uilabel(ncg, "Text", "ground");
E.annBackground = uidropdown(ncg, "Editable", "on", "Items", ["none" "white" "black" "yellow" "cyan" "#F0F0F0"], ...
    "Value", "none", "ValueChangedFcn", changed, "Tooltip", "none: the panel shows through; or a name or #RRGGBB behind the text.");
[S, r] = formRow(S, "annInterp", "Interpreter:");
E.annInterp = uidropdown(S.Body, "Items", ["As typed" "TeX"], "ItemsData", ["none" "tex"], "Value", "none", ...
    "ValueChangedFcn", changed, "Tooltip", "As typed: every character is printed as it is. TeX: \mu, \pm, x^2, x_i, \bf{...} " + ...
    "set symbols, powers, subscripts and bold or italic runs.");
place(E.annInterp, r, 2);
sec(end+1) = S;

% lines and patches on the selected panel's axes: a list, and the rows of the one picked (drawOverlays)
S = formSection(eg, 16, "overlays", "Overlays", Color=tint("overlays"));
[S, r] = formRow(S, ["ovList" "ovAddLine"], "Overlays:", 112);
olg = subgrid(S.Body, r, {'1x', 96});
E.ovList = uilistbox(olg, "Items", {}, "ValueChangedFcn", @(~,~) obj.onFigureOverlayPicked(), ...
    "Tooltip", "The graphics drawn on the selected panel's axes in data units: a vertical or horizontal line, or a " + ...
    "semitransparent patch between two x or two y values. Add as many as you like; each has its own place and " + ...
    "look. Pick one to edit it below.");
E.ovList.Layout.Column = 1;
E.ovList.UserData = struct('items', repmat(EphysAnalysisConfig.defaults("Overlay"), 1, 0), 'shown', 0);
obg = uigridlayout(olg, [4 1], "RowHeight", {24, 24, 24, 24}, "Padding", [0 0 0 0], "RowSpacing", 4);
obg.Layout.Column = 2;
E.ovAddLine = uibutton(obg, "Text", "Add line", "ButtonPushedFcn", @(~,~) obj.onAddFigureOverlay("line"), ...
    "Tooltip", "Add a line across the panel's axis: vertical at an x value, or horizontal at a y value.");
E.ovAddRegion = uibutton(obg, "Text", "Add patch", "ButtonPushedFcn", @(~,~) obj.onAddFigureOverlay("region"), ...
    "Tooltip", "Add a semitransparent patch between two x values (the full height of the axis) or two y values (the full width).");
E.ovDuplicate = uibutton(obg, "Text", "Duplicate", "ButtonPushedFcn", @(~,~) obj.onDuplicateFigureOverlay(), ...
    "Tooltip", "Copy the overlay picked, with its look, right after it.");
E.ovRemove = uibutton(obg, "Text", "Remove", "ButtonPushedFcn", @(~,~) obj.onRemoveFigureOverlay(), ...
    "Tooltip", "Remove the overlay picked from the panel.");
[S, r] = formRow(S, ["ovName" "ovEnabled"], "Name:");
ong = subgrid(S.Body, r, {'1x', 'fit'});
E.ovName = uieditfield(ong, "text", "Placeholder", "Overlay", "ValueChangedFcn", changed, ...
    "Tooltip", "What the list and the aesthetics editor (right-click the preview) call this overlay. Keep it different " + ...
    "from the panel's other overlays: a look remembered for the name reaches every overlay that has it.");
E.ovEnabled = uicheckbox(ong, "Text", "Enabled", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Unticked, the overlay stays in the config but is not drawn.");
[S, r] = formRow(S, "ovKind", "Draw:");
E.ovKind = uidropdown(S.Body, "Items", ["Vertical line, at an x value" "Horizontal line, at a y value" ...
    "Patch between two x values" "Patch between two y values"], "ItemsData", ["line|x" "line|y" "region|x" "region|y"], ...
    "Value", "line|x", "ValueChangedFcn", changed, "Tooltip", "Values are in the axis' own units: seconds from the event " + ...
    "on a time axis, a PSTH's rate on its y axis, an epoch number on a raster's rows. An overlay does not widen the " + ...
    "axis: one outside its limits is not seen.");
place(E.ovKind, r, 2);
[S, r] = formRow(S, "ovValue", "At:");
E.ovValue = uieditfield(S.Body, "text", "Value", "0", "ValueChangedFcn", changed, ...
    "Tooltip", "Where the line crosses its axis (a number).");
place(E.ovValue, r, 2);
[S, r] = formRow(S, ["ovFrom" "ovTo"], "From / to:");
ofg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.ovFrom = uieditfield(ofg, "text", "Value", "0", "ValueChangedFcn", changed, "Tooltip", "One edge of the patch (a number).");
uilabel(ofg, "Text", "to");
E.ovTo = uieditfield(ofg, "text", "Value", "0.1", "ValueChangedFcn", changed, "Tooltip", "The other edge (a number; either order).");
E.ovPanel = struct('Value', 'all', 'ItemsData', "all");   % no row: a panel's overlays go on its own axes (overlayRead / overlayShow read it)
[S, r] = formRow(S, "ovLayer", "Layer:");
E.ovLayer = uidropdown(S.Body, "Items", ["Over the data" "Under the data"], "ItemsData", EphysAnalysisConfig.OverlayLayers, ...
    "Value", "over", "ValueChangedFcn", changed, "Tooltip", "Over: drawn after the panel's lines, points, bars and bands. " + ...
    "Under: behind them, so they hide it where they are opaque.");
place(E.ovLayer, r, 2);
[S, r] = formRow(S, ["ovColor" "ovAlpha"], "Color:");
ocg = subgrid(S.Body, r, {'1x', 'fit', 60});
E.ovColor = uidropdown(ocg, "Editable", "on", "Items", ["#d62728" "red" "black" "white" "blue" "green" "magenta" "cyan" "orange"], ...
    "Value", "#d62728", "ValueChangedFcn", changed, "Tooltip", "The line's color: a name or #RRGGBB.");
uilabel(ocg, "Text", "opacity");
E.ovAlpha = uieditfield(ocg, "numeric", "Limits", [0 1], "Value", 1, "ValueChangedFcn", changed, ...
    "Tooltip", "0 (invisible) to 1 (solid).");
[S, r] = formRow(S, ["ovFill" "ovFillAlpha"], "Fill:");
ofc = subgrid(S.Body, r, {'1x', 'fit', 60});
E.ovFill = uidropdown(ofc, "Editable", "on", "Items", ["#808080" "gray" "black" "white" "red" "blue" "green" "yellow" "cyan"], ...
    "Value", "#808080", "ValueChangedFcn", changed, "Tooltip", "The patch's color: a name or #RRGGBB.");
uilabel(ofc, "Text", "opacity");
E.ovFillAlpha = uieditfield(ofc, "numeric", "Limits", [0 1], "Value", 0.25, "ValueChangedFcn", changed, ...
    "Tooltip", "0 (invisible) to 1 (solid); a semitransparent patch lets the data show through.");
[S, r] = formRow(S, "ovEdge", "Outline:");
E.ovEdge = uidropdown(S.Body, "Editable", "on", "Items", ["none" "black" "white" "red" "blue" "gray"], "Value", "none", ...
    "ValueChangedFcn", changed, "Tooltip", "none: the patch has no outline; or a color (a name or #RRGGBB), drawn in the style " + ...
    "and width below.");
place(E.ovEdge, r, 2);
[S, r] = formRow(S, ["ovStyle" "ovWidth"], "Line:");
olnG = subgrid(S.Body, r, {'1x', 'fit', 60});
E.ovStyle = uidropdown(olnG, "Items", ["solid" "dashed" "dotted" "dash-dot"], "ItemsData", EphysAnalysisConfig.OverlayLineStyles, ...
    "Value", "--", "ValueChangedFcn", changed, "Tooltip", "The line's style (a patch's outline).");
uilabel(olnG, "Text", "width");
E.ovWidth = uispinner(olnG, "Limits", [0.25 12], "Step", 0.25, "Value", 1.5, "ValueChangedFcn", changed, ...
    "Tooltip", "Points (a patch's outline).");
sec(end+1) = S;

hLook = superHeader(eg);   % the Look supersection's header

% appearance: the figure's style (no tiles, grid spacing or limits: the arrangement and the panels have those)
S = formSection(eg, 12, "style", "Appearance", Color=tint("style"));
[S, r] = formRow(S, "fontSize", "Font size:");
E.fontSize = uispinner(S.Body, "Limits", [5 24], "Value", 9, "ValueChangedFcn", changed);
place(E.fontSize, r, 2);
[S, r] = formRow(S, "lineWidth", "Line width:");
E.lineWidth = uispinner(S.Body, "Limits", [0.25 6], "Step", 0.25, "Value", 1.2, "ValueChangedFcn", changed, ...
    "Tooltip", "PSTH lines and outlines, signal traces.");
place(E.lineWidth, r, 2);
[S, r] = formRow(S, "siteSize", "Site size:");
E.siteSize = uispinner(S.Body, "Limits", [1 40], "Step", 1, "Value", 8, "ValueChangedFcn", changed, ...
    "Tooltip", "Probe map: size of the plotted sites (points).");
place(E.siteSize, r, 2);
[S, r] = formRow(S, "colormap", "Group colors:");
E.colormap = uidropdown(S.Body, "Editable", "on", "Items", ["lines" "parula" "turbo" "jet" "hot" "cool" "gray" "black"], ...
    "Value", "lines", "ValueChangedFcn", changed, "Tooltip", "lines: the trial selection's colors; a colormap function; " + ...
    "or one color for every group (a name or #RRGGBB).");
place(E.colormap, r, 2);
[S, r] = formRow(S, "heatColormap", "Heat colors:");
E.heatColormap = uidropdown(S.Body, "Items", ["auto" "parula" "turbo" "hot" "gray" "jet" "cool" "blueWhiteRed"], ...
    "ValueChangedFcn", changed, "Tooltip", "auto: parula; blueWhiteRed for unit correlation.");
place(E.heatColormap, r, 2);
[S, r] = formRow(S, ["sortDepth" "sortShank"], "Sort by:");
sog = subgrid(S.Body, r, {'fit', 'fit', '1x'});
sog.ColumnSpacing = 12;
E.sortDepth = uicheckbox(sog, "Text", "Depth", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Units / channels with the top of the probe first: the observation picker's order too.");
E.sortShank = uicheckbox(sog, "Text", "Shank", "ValueChangedFcn", changed, "Tooltip", "Units / channels grouped by shank first.");
[S, r] = formRow(S, ["labelDepth" "labelShank"], "Label with:");
lag = subgrid(S.Body, r, {'fit', 'fit', '1x'});
lag.ColumnSpacing = 12;
E.labelDepth = uicheckbox(lag, "Text", "Depth", "ValueChangedFcn", changed, "Tooltip", "Append each unit's / channel's probe depth to its label.");
E.labelShank = uicheckbox(lag, "Text", "Shank", "ValueChangedFcn", changed, "Tooltip", "Append each unit's / channel's shank to its label.");
[S, r] = formRow(S, ["showSEM" "showStop" "showArtifactNote" "legend" "grid"], "Show:");
shg = subgrid(S.Body, r, repmat({'fit'}, 1, 5));
shg.ColumnSpacing = 12;
E.showSEM = uicheckbox(shg, "Text", "Error", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Draw the error of the means: bands behind PSTH traces.");
E.showStop = uicheckbox(shg, "Text", "Stop marks", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Mark each epoch's stop event (the Epoch window's).");
E.showArtifactNote = uicheckbox(shg, "Text", "Artifact note", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Under the title, say how many of the drawn epochs touch an artifact period (kept when the " + ...
    "trial selection's Artifacts: Exclude epochs is off).");
E.legend = uicheckbox(shg, "Text", "Legend", "Value", true, "ValueChangedFcn", changed);
E.grid = uicheckbox(shg, "Text", "Grid", "Value", true, "ValueChangedFcn", changed);
[S, r] = formRow(S, ["legendLoc" "legendOrient" "legendBox"], "Legend:");
lgg = subgrid(S.Body, r, {'1x', '1x', 'fit'});
E.legendLoc = uidropdown(lgg, "Items", ["Auto" "Inside" "North (above)" "South (below)" "East (right)" "West (left)"], ...
    "ItemsData", ["auto" "inside" "north" "south" "east" "west"], "Value", "auto", "ValueChangedFcn", changed, ...
    "Tooltip", "Where the figure's one legend goes.");
E.legendOrient = uidropdown(lgg, "Items", ["Auto" "Vertical" "Horizontal"], "ItemsData", ["auto" "vertical" "horizontal"], ...
    "Value", "auto", "ValueChangedFcn", changed, "Tooltip", "How the legend's entries line up.");
E.legendBox = uicheckbox(lgg, "Text", "Box", "ValueChangedFcn", changed, "Tooltip", "Draw the legend's outline and background.");
[S, r] = formRow(S, ["errType" "errResamples"], "Error:");
erg = subgrid(S.Body, r, {'1x', 'fit', 80});
E.errType = uidropdown(erg, "Items", ["mean ± SEM" "mean ± SD" "bootstrap 95% CI"], "ItemsData", EphysAnalysisConfig.ErrorTypes, ...
    "Value", "sem", "ValueChangedFcn", changed, "Tooltip", "What the PSTH bands show, over " + ...
    "the epochs (the bootstrap needs the Statistics and Machine Learning Toolbox). A continuous panel's band is its own option.");
uilabel(erg, "Text", "resamples:");
E.errResamples = uispinner(erg, "Limits", [1 1e6], "Step", 500, "Value", 1000, "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "Bootstrap 95% CI: how many resamples.");
[S, r] = formRow(S, ["errFace" "errAlpha"], "Band fill:");
bfg = subgrid(S.Body, r, {'1x', 'fit', 60});
E.errFace = uidropdown(bfg, "Editable", "on", "Items", ["auto" "gray" "black" "white" "#d9d9d9"], "Value", "auto", ...
    "ValueChangedFcn", changed, "Tooltip", "auto: the trace's color; or one color for every band (a name or #RRGGBB).");
uilabel(bfg, "Text", "opacity");
E.errAlpha = uieditfield(bfg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "opaque", "Limits", [0 1], ...
    "ValueChangedFcn", changed, "Tooltip", "Blank: opaque, paled towards the ground. 0 to 1: that opacity.");
[S, r] = formRow(S, ["errEdge" "errEdgeStyle"], "Band edge:");
beg = subgrid(S.Body, r, {'1x', '1x', 60});
E.errEdge = uidropdown(beg, "Editable", "on", "Items", ["none" "auto" "black" "gray"], "Value", "none", ...
    "ValueChangedFcn", changed, "Tooltip", "none: no outline; auto: the fill's color; or a color.");
E.errEdgeStyle = uidropdown(beg, "Items", ["solid" "dashed" "dotted" "dash-dot"], "ItemsData", EphysAnalysisConfig.OverlayLineStyles, ...
    "Value", "-", "ValueChangedFcn", changed, "Tooltip", "The outline's line style.");
E.errEdgeWidth = uispinner(beg, "Limits", [0.1 6], "Step", 0.25, "Value", 0.5, "ValueChangedFcn", changed, ...
    "Tooltip", "The outline's width, points.");
sec(end+1) = S;

% the looks remembered for the figure (the preview's right-click editor)
S = formSection(eg, 13, "looks", "Looks", Color=tint("looks"));
[S, r] = formRow(S, ["looksText" "looksForget"], "", 30);
kg = subgrid(S.Body, r, {'1x', 'fit'});
place(kg, r, [1 2]);
E.looksText = uilabel(kg, "Text", "", "WordWrap", "on");
E.looksForget = uibutton(kg, "Text", "Forget", "ButtonPushedFcn", @(~,~) onForgetLooks(obj), ...
    "Tooltip", "Forget the looks remembered for this figure (colors, lines, fonts set in the right-click editor).");
sec(end+1) = S;

names = [sec.Name];
for i = 2:numel(sec)
    name = sec(i).Name;
    sec(i).Toggle.ButtonPushedFcn = @(~,~) obj.onFigureSectionToggled(name);
    k = find(keyed == name);
    if ~isempty(k); sec(i).Key = string(mod(k, 10)); end   % Ctrl+1 ... Ctrl+9, then Ctrl+0 for the tenth (onKeyPress)
end
for i = find(ismember(names, ["note" "overlays" "style" "looks" "sessions"]))
    sec(i).Expanded = false;   % collapsed until opened (then kept: FigureSectionsCollapsed)
end
% the supersections: each collapses its sections under a dark header, which Alt+1 to Alt+3 go to (onKeyPress)
U = struct('Name', {"figure" "panel" "look"}, 'Title', {"Figure" "Panel" "Look"}, ...
    'Sections', {["observations" "ref" "window" "selection" "sessions" "arrangement"], ...
    ["panel" "palign" "layers" "options" "waveform" "note" "overlays"], ["style" "looks"]}, ...
    'Header', {hFigure hPanel hLook}, 'Expanded', true, 'Key', {"1" "2" "3"});
[sec.Super] = deal("");
for u = 1:numel(U)
    name = U(u).Name;
    U(u).Header.ButtonPushedFcn = @(~,~) obj.onFigureSuperToggled(name);
    for i = find(ismember(names, U(u).Sections))
        sec(i).Super = name;
        sec(i).Grid.Padding = [12 0 0 0];   % indented under its supersection's header
    end
end
% a swatch beside each color field that opens the color chooser (colorSwatch; the ColorPicker read when pressed)
pickColor = @(c, t) feval(obj.ColorPicker, c, t);
E.swatch = struct();
for f = ["evColor" "layerColor" "tickColor" "backColor" "etEdge" "etBaseColor" "annColor" "annBackground" ...
        "ovColor" "ovFill" "ovEdge" "colormap" "errFace" "errEdge"]
    E.swatch.(f) = colorSwatch(E.(f), Picker=pickColor);
end
obj.FigureEditor = E;
obj.FigureSections = sec;
obj.FigureSupers = U;
obj.layoutFigureEditor();
obj.FigureSearchIndex = figureSearchIndex(obj.FigureSections, U);   % the rows as built (formLayout found their controls)

% --- right: the observation picker and the preview ----------------------------------------------
% the buttons in a column of their own at the left, beside the Dataset, Observation and Favorites rows (three rows
% tall enough for its five); Design and Save look as design sit at the right of Dataset and Observation; the
% template row (and Apply last change) above the preview. Ctrl is Cmd on a Mac (onKeyPress).
pg = uigridlayout(g, [6 5]);
pg.RowHeight = {46, 46, 46, 34, '1x', 30};
pg.ColumnWidth = {90, 'fit', '1x', 'fit', 125};
pg.ColumnSpacing = 6;
pg.Padding = [0 0 0 0];
bg = uigridlayout(pg, [5 1], "RowHeight", {30, 30, 30, 24, 30}, "ColumnWidth", {'1x'}, "RowSpacing", 3, "Padding", [0 0 0 0]);
bg.Layout.Row = [1 3]; bg.Layout.Column = 1;
cmdKey = "Ctrl";
if ismac; cmdKey = "Cmd"; end
obj.FigurePreviewButton = uibutton(bg, "Text", "Preview", ...
    "Tooltip", "Compute and draw the selected figure for the observation picked, on the active dataset. " + ...
    "Orange: the figure changed since it was drawn. (" + cmdKey + "+P)", ...
    "ButtonPushedFcn", @(~,~) obj.refreshFigurePreview(Force=true));
obj.FigurePreviewButton.Layout.Row = 1;
obj.FigureRedrawAllButton = uibutton(bg, "Text", "Redraw All", "Enable", "off", ...
    "Tooltip", "Compute and draw again the preview of every enabled figure (and the shown one) for its observation " + ...
    "on the active dataset, the shown figure first; a preview still current is left as it is. The " + ...
    obj.MaxFigureViews + " previews kept at most: beyond them, the figures shown most recently. The toolbar's Cancel " + ...
    "stops it. Writing the figure's files is File > Generate selected figure (" + cmdKey + "+G). (" + cmdKey + "+R)", ...
    "ButtonPushedFcn", @(~,~) obj.onRedrawAllFigures());
obj.FigureRedrawAllButton.Layout.Row = 2;
obj.FigureUnitReportButton = uibutton(bg, "Text", "Unit report", "Enable", "off", ...
    "Tooltip", "A spot check: every enabled figure (and this one) drawn for the unit or channel picked only, " + ...
    "on the active dataset, as an HTML report in a temporary folder that opens in the browser. A figure of " + ...
    "channels or detections draws what is on the unit's channel; a figure of the dataset, or one with nothing " + ...
    "there, is listed as left out. No figure files, no session figures; the output folder is not touched. (" + cmdKey + "+U)", ...
    "ButtonPushedFcn", @(~,~) obj.onUnitReport());
obj.FigureUnitReportButton.Layout.Row = 3;
obj.FigureAutoCheckBox = uicheckbox(bg, "Text", "Auto", "Value", true, ...
    "Tooltip", "Redraw on every change while a preview takes under " + obj.AutoPreviewSeconds + " s (one observation is quick). (" + cmdKey + "+T)", ...
    "ValueChangedFcn", @(~,~) obj.onFigureAutoPreviewToggled());
obj.FigureAutoCheckBox.Layout.Row = 4;
kg = uigridlayout(bg, [1 2], "ColumnWidth", {'1x', '1x'}, "ColumnSpacing", 4, "Padding", [0 0 0 0]);
kg.Layout.Row = 5;
obj.FigureObsPrevButton = uibutton(kg, "Text", "<", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onFigureObservationStep(-1), ...
    "Tooltip", "The previous observation (Page Up).");
obj.FigureObsNextButton = uibutton(kg, "Text", ">", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onFigureObservationStep(1), ...
    "Tooltip", "The next observation (Page Down).");
l = uilabel(pg, "Text", "Dataset:");
l.Layout.Row = 1; l.Layout.Column = 2;
sg = uigridlayout(pg, [1 3], "ColumnWidth", {'1x', 34, 34}, "ColumnSpacing", 4, "Padding", [0 0 0 0]);   % the drop-down, its star and its note
sg.Layout.Row = 1; sg.Layout.Column = 3;
obj.FiguresDatasetDropDown = uidropdown(sg, "Items", "(scan first)", "ItemsData", 0, ...
    "ValueChangedFcn", @(dd, ~) obj.selectDataset(dd.Value), "Tooltip", "The active dataset (the same on every tab).");
obj.FiguresDatasetStar = starButton(obj, sg, "dataset");
obj.FiguresDatasetNote = noteButton(obj, sg, "dataset");
l = uilabel(pg, "Text", "Observation:");
l.Layout.Row = 2; l.Layout.Column = 2;
sg = uigridlayout(pg, [1 3], "ColumnWidth", {'1x', 34, 34}, "ColumnSpacing", 4, "Padding", [0 0 0 0]);
sg.Layout.Row = 2; sg.Layout.Column = 3;
obj.FigureObservationDropDown = uidropdown(sg, "Items", "(no observation)", "ItemsData", 0, ...
    "ValueChangedFcn", @(~,~) obj.onFigureObservationChanged(), ...
    "Tooltip", "What the preview draws the figure for: one of the units, channels or the dataset the Observations " + ...
    "section keeps, in probe order. Each figure remembers its pick. ★: starred. ✎: has a note.");
obj.FigureObservationStar = starButton(obj, sg, "observation");
obj.FigureObservationNote = noteButton(obj, sg, "observation");
l = uilabel(pg, "Text", "Favorites:");
l.Layout.Row = 3; l.Layout.Column = 2;
obj.FigureFavorites = buildFavorites(obj, pg, "FigureFavorites");   % every starred dataset, channel and unit
obj.FigureFavorites.Grid.Layout.Row = 3; obj.FigureFavorites.Grid.Layout.Column = [3 5];
% the design every figure is drawn in (PlotDesign; also the Design menu), right of the Dataset and Observation
% drop-downs, and the preview's look kept as one
l = uilabel(pg, "Text", "Design:");
l.Layout.Row = 1; l.Layout.Column = 4;
obj.DesignDropDown = uidropdown(pg, "Items", PlotDesign.DefaultName, "ItemsData", PlotDesign.DefaultName, ...
    "ValueChangedFcn", @(dd, ~) obj.onDesignChosen(dd.Value), ...
    "Tooltip", "The look of every figure: its ground, colors, fonts, axes, ticks, lines and marks. " + ...
    "Choosing one redraws every figure on screen; runs draw their figures in it too.");
obj.DesignDropDown.Layout.Row = 1; obj.DesignDropDown.Layout.Column = 5;
obj.SaveDesignButton = uibutton(pg, "Text", "Save look as design...", "ButtonPushedFcn", @(~,~) obj.onSaveDesign(), ...
    "Tooltip", "Keep the preview's look -- every property of every component, its ground and its group " + ...
    "colors -- as a design of your own, to choose for any figure. The axes of heat map, probe map, " + ...
    "correlation map and spectrogram panels are kept for those panel types only. Preview first if the " + ...
    "preview is out of date.");
obj.SaveDesignButton.Layout.Row = 2; obj.SaveDesignButton.Layout.Column = [4 5];
% the figure templates of yours (FigureTemplate: a figure's settings, copied into figures when applied), and Apply
% last change (Edit > Apply last change to figures...), in the row above the preview
tg = uigridlayout(pg, [1 11], "ColumnWidth", {'fit', '1x', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 8, 'fit'}, ...
    "ColumnSpacing", 4, "Padding", [0 2 0 2]);
tg.Layout.Row = 4; tg.Layout.Column = [1 5];
uilabel(tg, "Text", "Template:", "FontWeight", "bold", ...
    "Tooltip", "Figure templates: a figure's settings kept under a name, to copy into other figures. Applying copies once: " + ...
    "a template changed later reaches a figure only when it is applied again.");
obj.FigureTemplateDropDown = uidropdown(tg, "Items", "(no templates)", "ItemsData", "", ...
    "ValueChangedFcn", @(~, ~) obj.refreshTemplates(), "DropDownOpeningFcn", @(~, ~) obj.refreshTemplates(), ...
    "Tooltip", "Your figure templates (in your templates folder, " + FigureTemplate.folder() + ").");
cm = uicontextmenu(obj.Fig);   % the folder, and the issues about templates
uimenu(cm, "Text", "Open my templates folder", "MenuSelectedFcn", @(~,~) obj.onFigureTemplate("folder"));
uimenu(cm, "Text", "Keep my templates in...", "Tooltip", "Another folder for your templates, such as one the lab shares.", ...
    "MenuSelectedFcn", @(~,~) obj.onFigureTemplate("choose"));
uimenu(cm, "Text", "Report a template issue on GitHub...", "Separator", "on", "MenuSelectedFcn", @(~,~) obj.onFigureTemplate("issue"));
uimenu(cm, "Text", "Request a template feature on GitHub...", "MenuSelectedFcn", @(~,~) obj.onFigureTemplate("feature"));
obj.FigureTemplateDropDown.ContextMenu = cm;
obj.FigureTemplateApplyButton = uibutton(tg, "Text", "Apply...", "ButtonPushedFcn", @(~,~) obj.onApplyTemplate(), ...
    "Tooltip", "Copy the template's settings into figures: pick them in a list (the figure shown ticked), and which " + ...
    "settings; or add the template as a new figure. One step of Undo. Each figure keeps its id, title and enabled. " + ...
    "The copy is made once: there is no link, so apply it again to give figures a template's later changes.");
obj.FigureTemplateSaveButton = uibutton(tg, "Text", "Save as...", "ButtonPushedFcn", @(~,~) obj.onFigureTemplate("save"), ...
    "Tooltip", "Save the figure shown as a new template: every setting (observations, alignment, page size, panels with their " + ...
    "options, layers, notes and overlays, spacing, appearance, remembered looks, sessions) but its id, title and enabled.");
obj.FigureTemplateUpdateButton = uibutton(tg, "Text", "Update", "ButtonPushedFcn", @(~,~) obj.onFigureTemplate("update"), ...
    "Tooltip", "Replace the template picked with the settings of the figure shown (asks first). The figures it was applied " + ...
    "to keep their settings until it is applied to them again.");
obj.FigureTemplateRemoveButton = uibutton(tg, "Text", "Remove", "ButtonPushedFcn", @(~,~) obj.onFigureTemplate("remove"), ...
    "Tooltip", "Delete the template picked (asks first). The figures it was applied to keep their settings.");
obj.FigureTemplateImportButton = uibutton(tg, "Text", "Import...", "ButtonPushedFcn", @(~,~) obj.onFigureTemplate("import"), ...
    "Tooltip", "Copy template files (.json), a colleague's say, into your templates folder.");
obj.FigureTemplateExportButton = uibutton(tg, "Text", "Export...", "ButtonPushedFcn", @(~,~) obj.onFigureTemplate("export"), ...
    "Tooltip", "Write the template picked to a .json file, to share it (Import... adds it on another computer).");
obj.FigureTemplateIssueLink = uihyperlink(tg, "Text", "Report issue", ...
    "HyperlinkClickedFcn", @(~, ~) obj.onFigureTemplate("issue"), ...
    "Tooltip", "Report a problem with figure templates: an issue on GitHub, opened prefilled with the template picked. " + ...
    "To ask for something they do not do: Help > Request a figure template feature..., or right-click the list.");
obj.FigureApplyLastButton = uibutton(tg, "Text", "Apply last change...", "Enable", "off", ...
    "ButtonPushedFcn", @(~,~) obj.onApplyToFigures(), ...
    "Tooltip", "Apply last change to figures (" + cmdKey + "+Shift+A)");   % named after the step: refreshEditMenu
obj.FigureApplyLastButton.Layout.Column = 11;
obj.refreshTemplates();
% the previews: a container per figure, all in this one cell, the selected figure's shown (syncFigureView); the
% first, "", is shown while no figure is selected
obj.FigurePreviewHost = uipanel(pg, "BorderType", "none", "BackgroundColor", [0.88 0.88 0.88], "AutoResizeChildren", "off", ...
    "SizeChangedFcn", @(~, ~) obj.fitFigureViews());   % each container is shaped like its figure's export page and centered in it (fitFigureViews)
obj.FigurePreviewHost.Layout.Row = 5; obj.FigurePreviewHost.Layout.Column = [1 5];
obj.FigureEditorStates = containers.Map('KeyType', 'char', 'ValueType', 'any');
obj.FigurePickers = containers.Map('KeyType', 'char', 'ValueType', 'any');
v = newFigureView(obj, "");
v.Panel.Visible = "on";
obj.FigureViews = v;
obj.FigureViewId = "";
obj.FigurePreviewPanel = v.Panel;
% the status line: badge, text, the session pick (opens when there are several), Export preview, Export code, Open in window
sg = uigridlayout(pg, [1 6], "ColumnWidth", {'fit', '1x', 0, 120, 105, 130}, "Padding", [0 0 0 0], "ColumnSpacing", 8);
sg.Layout.Row = 6; sg.Layout.Column = [1 5];
B.Grid = uigridlayout(sg, [1 2], "ColumnWidth", {18, 'fit'}, "Padding", [6 2 10 2], "ColumnSpacing", 5);
B.Icon = uiimage(B.Grid, "ScaleMethod", "fit");
B.Text = uilabel(B.Grid, "FontWeight", "bold");
obj.FigurePreviewBadge = B;
obj.FigurePreviewLabel = uilabel(sg, "Text", "Add a figure, scan and pick a dataset to preview.", "FontColor", gray);
obj.FigureSessionDropDown = uidropdown(sg, "Items", "(all)", "ItemsData", 1, "Visible", "off", ...
    "ValueChangedFcn", @(~,~) obj.onFigureSessionPicked(), ...
    "Tooltip", "A figure across sessions makes one figure per subject (Figures: one per subject) or per trial group " + ...
    "(Trial groups: a figure per group): the one the preview shows.");   % its column opens when there are several
obj.FigureExportPreviewButton = uibutton(sg, "Text", "Export preview", "Enable", "off", ...
    "Tooltip", "Spot-check the Export tab's settings: this figure for the observation picked, drawn and written as a " + ...
    "run writes it (size, formats, dpi, file name) into a preview folder -- not the figure folder -- and shown in a " + ...
    "window. (" + cmdKey + "+K)", "ButtonPushedFcn", @(~,~) obj.onExportPreview());
obj.FigureExportPreviewButton.Layout.Row = 1; obj.FigureExportPreviewButton.Layout.Column = 4;
obj.FigureCodeButton = uibutton(sg, "Text", "Export code", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onFigureCode(), ...
    "Tooltip", "Open the code behind this preview in the MATLAB editor, as a new unsaved script: the dataset, " + ...
    "the figure's settings written out, every event and spike train, each cut into the preview's epochs as " + ...
    "variables to analyze, then figureCompute and renderFigure in the design chosen. " + ...
    "Run it to load the data and draw the figure in a window of its own; it does not need the app. (" + cmdKey + "+E)");
obj.FigureCodeButton.Layout.Row = 1; obj.FigureCodeButton.Layout.Column = 5;
obj.FigureOpenButton = uibutton(sg, "Text", "Open in window", "Enable", "off", ...
    "Tooltip", "Draw the figure as previewed into a new MATLAB figure window of its own (the right-click editor works there too). " + ...
    "It is independent of this app: later edits do not follow into it. An out-of-date preview is redrawn first. (" + cmdKey + "+W)", ...
    "ButtonPushedFcn", @(~,~) obj.onOpenFigureWindow());
obj.FigureOpenButton.Layout.Row = 1; obj.FigureOpenButton.Layout.Column = 6;
obj.setFigurePreviewState("idle");
end


function onIdEdited(obj, f, evt)
%onIdEdited  A figure id typed: refused when blank or another figure's; else it is the figure's own (auto unticked).
%   The observation picked moves with it (trackFigureIds, in onConfigChanged).
if obj.Applying; return; end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
id = strtrim(string(f.Value));
others = obj.Config.figureIds();
others(k) = [];
if id == "" || any(others == id)
    f.Value = evt.PreviousValue;
    if id == ""
        obj.setStatus("A figure needs an id.");
    else
        obj.setStatus("Config: a figure named " + id + " already exists.");
    end
    return
end
obj.FigureEditor.idAuto.Value = false;   % typed: the id is the user's own from now on
obj.onConfigChanged("figure", "Figure id");
obj.setStatus("The figure's id is " + id + ", your own: it no longer follows its panels (tick auto to go back).");
end


function onIdAutoToggled(obj, b)
%onIdAutoToggled  The Id row's auto box: ticked, the id follows the panels and data again; unticked, the id it shows is kept as the user's own.
if obj.Applying; return; end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
obj.onConfigChanged("figure", "Automatic figure id");
id = obj.Config.Figures(k).id;
if b.Value
    obj.setStatus("The figure's id follows its panels and data again: " + id + ".");
else
    obj.setStatus("The figure's id " + id + " is your own now: it no longer follows its panels.");
end
end


function onSpanEdited(obj, sp, evt, which)
%onSpanEdited  A panel's row or column span: refused past the grid's edge or over another panel.
if obj.Applying; return; end
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
fig = obj.Config.Figures(k);
j = obj.SelectedPanel;
if j < 1 || j > numel(fig.panels); return; end
p = fig.panels(j);
v = round(sp.Value);
if which == "row"
    if p.row + v - 1 > fig.grid.rows
        sp.Value = evt.PreviousValue;
        obj.setStatus(p.id + " cannot span past the grid's last row: add a row below it first.");
        return
    end
    fig.panels(j).rowSpan = v;
else
    if p.col + v - 1 > fig.grid.cols
        sp.Value = evt.PreviousValue;
        obj.setStatus(p.id + " cannot span past the grid's last column: add a column right of it first.");
        return
    end
    fig.panels(j).colSpan = v;
end
[~, over] = EphysAnalysisConfig.figureCells(fig);
if ~isempty(over)
    sp.Value = evt.PreviousValue;
    q = over(1, :);
    q = q(q ~= j);
    obj.setStatus(p.id + " would overlap " + fig.panels(q(1)).id + ".");
    return
end
obj.onConfigChanged("figure", "Panel span");
obj.setStatus(sprintf("%s spans %d row(s) and %d column(s).", p.id, fig.panels(j).rowSpan, fig.panels(j).colSpan));
end


function onGroupByChanged(obj)
%onGroupByChanged  The figure tree's Group by: regroup it (the selected figure stays); Up and Down follow its new group.
obj.refreshFigureList();
obj.syncFigureEditor();
end


function setAddSource(obj, s)
obj.FigureAddSource = string(s);
end


function applyAlignToAll(obj)
%applyAlignToAll  The selected panel's own event, window and trial selection become the figure's; every panel is linked to them again.
%   A part the panel does not have of its own stays the figure's.
k = obj.SelectedFigure;
j = obj.SelectedPanel;
if k < 1 || k > numel(obj.Config.Figures) || j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
p = fig.panels(j);
if ~isstruct(p.ref) && ~isstruct(p.window) && ~isstruct(p.selection); return; end
fig = EphysAnalysisConfig.adoptPanelAlignment(fig, p.id);
cfg.Figures(k) = fig;
commitFigureEdit(obj, cfg, sprintf("%s's event, window and trial selection are now the figure's; all %d panels follow them.", ...
    p.id, numel(fig.panels)), Action="Apply alignment to all panels");
end


function onPanelSelectionToggled(obj)
%onPanelSelectionToggled  "Trial selection as the figure": ticked, the panel uses the figure's again; unticked, a copy of it as its own.
%   Unticking copies the figure's trial selection (its own, else the
%   Defaults') into the panel, so its rows start from it; the panel then
%   computes its own epochs and groups, colored apart with a legend inside
%   it. Ticking drops the panel's own (selection "default").
if obj.Applying; return; end
k = obj.SelectedFigure;
j = obj.SelectedPanel;
if k < 1 || k > numel(obj.Config.Figures) || j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
linked = logical(obj.FigureEditor.panelSameSel.Value);
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
p = fig.panels(j);
if linked
    p.selection = "default";
    msg = p.id + " uses the figure's trial selection again.";
else
    sel = fig.selection;
    if ~isstruct(sel); sel = cfg.Defaults.Selection; end
    p.selection = sel;
    msg = p.id + " has a trial selection of its own now, starting from the figure's: its groups are colored apart, " + ...
        "with a legend inside it.";
end
fig.panels(j) = p;
cfg.Figures(k) = fig;
commitFigureEdit(obj, cfg, msg, Action="Trial selection as the figure");
end


function relinkAll(obj)
%relinkAll  Every panel of the selected figure takes the figure's event, window and trial selection again (relinkPanels).
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
n = 0;
for q = 1:numel(fig.panels)
    n = n + (isstruct(fig.panels(q).ref) || isstruct(fig.panels(q).window) || isstruct(fig.panels(q).selection));
end
if n == 0; return; end
fig = EphysAnalysisConfig.relinkPanels(fig);
cfg.Figures(k) = fig;
commitFigureEdit(obj, cfg, sprintf("Re-linked %d panel(s): every panel follows the figure's event, window and trial " + ...
    "selection again.", n), Action="Re-link all panels");
end


function applyOptionsToAll(obj)
%applyOptionsToAll  adoptPanelOptions: the panel's shared rows go to every panel that has them, its other options to the panels of its type.
%   Its axis sides (xSide, ySide) go to every other panel; its label texts
%   stay its own. The status bar names each panel that changed, with its
%   options and sides, and
%   the panels that kept their baseline, stack or Y limits mode because
%   their type does not take the value (a fixed mode: they have no limits
%   of their own); nothing changes when the others have the values
%   already.
k = obj.SelectedFigure;
j = obj.SelectedPanel;
if k < 1 || k > numel(obj.Config.Figures) || j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
p = fig.panels(j);
[fig, changed] = EphysAnalysisConfig.adoptPanelOptions(fig, p.id);
went = strings(1, 0);
kept = strings(1, 0);
keptStack = strings(1, 0);
keptY = strings(1, 0);
for c = changed
    if ~isempty(c.fields); went(end+1) = c.id + " (" + strjoin(c.fields, ", ") + ")"; end %#ok<AGROW>
    if ismember("baseline", c.kept); kept(end+1) = c.id; end %#ok<AGROW>
    if ismember("stack", c.kept); keptStack(end+1) = c.id; end %#ok<AGROW>
    if ismember("yLimMode", c.kept); keptY(end+1) = c.id; end %#ok<AGROW>
end
msg = p.id + "'s options went to " + strjoin(went, ", ");
if isempty(went); msg = "The other panels have " + p.id + "'s options already"; end
if ~isempty(kept)
    msg = msg + "; " + strjoin(kept, ", ") + " kept their own baseline (their type does not take """ + ...
        p.options.baseline.Mode + """)";
end
if ~isempty(keptStack)
    msg = msg + "; " + strjoin(keptStack, ", ") + " kept their own stack (their type does not take """ + ...
        p.options.stack + """)";
end
if ~isempty(keptY)
    msg = msg + "; " + strjoin(keptY, ", ") + " kept their own Y limits mode (fixed limits are in each type's units: " + ...
        "they have none of their own)";
end
if isempty(went)
    obj.setStatus(msg + ".");
    return
end
cfg.Figures(k) = fig;
commitFigureEdit(obj, cfg, msg + ".", Action="Apply options to all panels");
end


function onBindingEdited(obj, evt)
%onBindingEdited  A layer's binding: a spike layer fixed while it follows an observed unit keeps that unit.
%   From "Follows the observation" to "Fixed", a units / detected layer of a
%   raster, PSTH, waveforms, rate or tuning panel whose unit ids are blank (all) gets the
%   observed unit's id (the picked observation's unitId: a detection's is
%   its channel) -- or, read from the other spike source, the observed
%   unit's channel -- so the panel keeps showing what it showed until the
%   ids are edited. Back to following, the ids stay as they are.
if obj.Applying; return; end
E = obj.FigureEditor;
note = "";
k = obj.SelectedFigure;
j = obj.SelectedPanel;
T = obj.FigureObservations;
i = obj.FigureObservationDropDown.Value;
if string(evt.Value) == "fixed" && string(evt.PreviousValue) == "observation" && k >= 1 && k <= numel(obj.Config.Figures) ...
        && j >= 1 && j <= numel(obj.Config.Figures(k).panels) && istable(T) && isnumeric(i) && i >= 1 && i <= height(T) ...
        && T.kind(i) == "unit"
    fig = obj.Config.Figures(k);
    type = fig.panels(j).type;
    src = string(E.layerSource.Value);
    if ismember(type, ["raster" "psth" "waveforms" "rate" "tuning"]) && ismember(src, EphysAnalysisConfig.SpikeSources) ...
            && strtrim(string(E.layerIds.Value)) == ""
        if src == fig.observe.data && isfinite(T.unitId(i))
            E.layerIds.Value = char(string(T.unitId(i)));
            note = "Fixed to unit " + T.unitId(i) + "; edit Unit ids to change it.";
        elseif isfinite(T.channel(i)) && strtrim(string(E.layerUnitChannels.Value)) == ""
            E.layerUnitChannels.Value = char(string(T.channel(i)));
            note = "Fixed to channel " + T.channel(i) + "'s " + src + "; edit Channels to change it.";
        end
    end
end
obj.onConfigChanged("figure", "Layer binding");
if note ~= ""; obj.setStatus(note); end
end


function onForgetLooks(obj)
%onForgetLooks  Forget the figure's remembered looks, and redraw the preview without them.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures); return; end
id = obj.Config.Figures(k).id;
obj.rememberFigureAesthetics(id, []);
obj.setStatus("Forgot " + id + "'s remembered looks.");
F = obj.FigurePreviewResult;
if obj.FigurePreviewState ~= "drawn" || isempty(F) || F.id ~= id; return; end
try
    spec = obj.Config.figureFor(k);
    renderFigure(F, spec, obj.FigurePreviewPanel, OnRemember=@(rules) obj.rememberFigureAesthetics(spec.id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(spec.id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(spec.id, panel, change));
catch
    obj.autoFigurePreview();
end
end


function b = defaultBox(obj, S, what)
%defaultBox  The "Use default" box in the header of an alignment section.
b = uicheckbox(S.HeaderGrid, "Text", "Use default", "Value", true, ...
    "ValueChangedFcn", @(~,~) obj.onFigureDefaultToggled(), ...
    "Tooltip", "Ticked: the Alignment tab's " + what + " (the config's Defaults). Editing a value below " + ...
    "gives this figure its own; tick again to go back to the default.");
b.Layout.Column = 2;
end


function [S, E] = aurocRows(S, E, p, changed, isPlot)
%aurocRows  The auROC settings' rows in form section S; P prefixes their editor fields.
%   ISPLOT (default false): a PSTH's or heat map's own (baseline Mode
%   "auroc"), with the call window, the
%   test's correction and alpha, the marks and modulated units only.
%   Otherwise the response
%   test's ("auroc"): its own bins; its windows, correction and alpha are
%   the test's. Each row shows by its first field's key (syncFigureEditor).
if nargin < 5; isPlot = false; end
[S, r] = formRow(S, p + "Method", "auROC from:");
g = subgrid(S.Body, r, {'1x', '1x'});
E.(p + "Method") = uidropdown(g, "Items", ["PSTH bins" "each epoch"], "ItemsData", ["psth" "epochs"], ...
    "ValueChangedFcn", changed, "Tooltip", "PSTH bins: the trial-averaged PSTH's bins in each window against those " + ...
    "in the baseline. each epoch: each epoch's spike count in the window against the baseline's.");
E.(p + "Windows") = uidropdown(g, "Items", ["tiled" "sliding"], "ValueChangedFcn", changed, ...
    "Tooltip", "tiled: windows back to back, edged at the event. sliding: a window starts every step.");
widths = {'fit', '1x', 'fit', '1x'};
if ~isPlot; widths = [widths {'fit', '1x'}]; end
[S, r] = formRow(S, p + "WinMs", "auROC (ms):");
g = subgrid(S.Body, r, widths);
uilabel(g, "Text", "window");
E.(p + "WinMs") = uieditfield(g, "numeric", "Value", 100, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "The auROC window, ms: a whole number of bins.");
uilabel(g, "Text", "step");
E.(p + "StepMs") = uieditfield(g, "numeric", "Value", 10, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "Sliding windows: one starts every step, ms.");
if ~isPlot
    uilabel(g, "Text", "bin");
    E.(p + "BinMs") = uieditfield(g, "numeric", "Value", 10, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
        "ValueChangedFcn", changed, "Tooltip", "The bins the test counts spikes in, ms.");
end
if isPlot
    [S, r] = formRow(S, p + "ModFrom", "Call window (s):");
    g = subgrid(S.Body, r, {'1x', 'fit', '1x'});
    E.(p + "ModFrom") = uieditfield(g, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", ...
        "The call window's start, s from the event: the auROC windows wholly inside it decide each unit's call.");
    uilabel(g, "Text", "to");
    E.(p + "ModTo") = uieditfield(g, "numeric", "Value", 0.5, "ValueChangedFcn", changed, "Tooltip", "The call window's end, s.");
end
items = ["95% CI (paper)" "fixed threshold" "per-unit test" "none"];
data = ["ci" "fixed" "test" "none"];
if ~isPlot; items = items(1:3); data = data(1:3); end
[S, r] = formRow(S, p + "Cutoff", "Modulated if:");
g = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.(p + "Cutoff") = uidropdown(g, "Items", items, "ItemsData", data, ...
    "ValueChangedFcn", changed, "Tooltip", "95% CI: beyond 0.5 +/- the 95% CI of the units' mean modulation (it needs " + ...
    "many units). fixed: beyond 0.5 +/- the threshold. per-unit test: the test below, its p adjusted over the units. none: no call.");
uilabel(g, "Text", "+/-");
E.(p + "Threshold") = uieditfield(g, "numeric", "Value", 0.1, "Limits", [0 0.5], "UpperLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "fixed threshold: modulated when |mean auROC - 0.5| is above this.");
widths = {'1x', 'fit', '1x'};
if isPlot; widths = {'2x', 'fit', '1x', '2x', 'fit', '1x'}; end
[S, r] = formRow(S, p + "Test", "Unit test:");
g = subgrid(S.Body, r, widths);
E.(p + "Test") = uidropdown(g, "Items", ["bootstrap" "ranksum" "shuffle"], "ValueChangedFcn", changed, ...
    "Tooltip", "bootstrap: resample the epochs. ranksum: the window's values against the baseline's. shuffle: shift each epoch's spikes circularly.");
uilabel(g, "Text", "n");
E.(p + "Resamples") = uieditfield(g, "numeric", "Value", 1000, "Limits", [1 Inf], "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "Bootstrap resamples, or shuffles.");
if isPlot
    E.(p + "Correction") = uidropdown(g, "Items", ["BH (FDR)" "Holm" "Bonferroni" "none"], ...
        "ItemsData", ["bh" "holm" "bonferroni" "none"], "ValueChangedFcn", changed, ...
        "Tooltip", "How the p values are adjusted over the units and groups (pAdjust).");
    uilabel(g, "Text", "alpha:");
    E.(p + "Alpha") = uieditfield(g, "numeric", "Value", 0.05, "Limits", [0 1], "LowerLimitInclusive", "off", ...
        "ValueChangedFcn", changed, "Tooltip", "Modulated when the adjusted p is at most alpha.");
    [S, r] = formRow(S, p + "Marks", "Calls:");
    g = subgrid(S.Body, r, {'fit', 'fit', '1x'});
    g.ColumnSpacing = 12;
    E.(p + "Marks") = uicheckbox(g, "Text", "Mark them", "Value", true, "ValueChangedFcn", changed, "Tooltip", ...
        "PSTH: the unit's call (up, down, n.s., per group) at its top right, and the call window shaded. Heat map: a " + ...
        "triangle by each modulated row and a bar over the call window.");
    E.(p + "ModOnly") = uicheckbox(g, "Text", "Modulated units only", "ValueChangedFcn", changed, ...
        "Tooltip", "Draw only the units called modulated in at least one group.");
end
end


function [S, E] = waveformSection(eg, E, changed, color)
%waveformSection  The Waveform section: the selected panel's unit waveform (options.waveform), its rows in E.
%   An inset on a raster, PSTH, firing rate or tuning curve panel, the
%   panel itself on a unit waveforms panel. syncFigureEditor shows it for
%   every type whose layers may be spikes, with a note (waveformNote) on
%   what it sets there or why the type draws none, and the rows the type
%   uses: what is shown and how many spikes; the x scale (the time span,
%   ms from the spike) and the y scale (each unit's range, one for the
%   units drawn, or a fixed range); the size of an inset or of a probe
%   layout's glyphs; an inset's place and box; the label; a probe layout's
%   sites and names. It has no key (the search finds its rows).
gray = [0.35 0.35 0.35];
S = formSection(eg, 17, "waveform", "Waveform", Color=color);
[S, r] = formRow(S, "waveNote", "", 46);
E.waveNote = uilabel(S.Body, "Text", "", "FontColor", gray, "WordWrap", "on", "VerticalAlignment", "top");
place(E.waveNote, r, [1 2]);
[S, r] = formRow(S, "waveMode", "Show:");
E.waveMode = uidropdown(S.Body, "Items", ["Off" "Mean" "Individual spikes" "Mean + individual spikes"], ...
    "ItemsData", ["off" "mean" "subsample" "both"], "Value", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The unit's waveform on its peak channel: its mean, its individual spikes (thin, pale), or both. " + ...
    "Off: none. A unit whose spikes cannot be read draws its template as the mean, and says so.");
place(E.waveMode, r, 2);
[S, r] = formRow(S, "waveSpikes", "Spikes drawn:");
E.waveSpikes = uispinner(S.Body, "Limits", [1 2000], "Step", 50, "Value", 100, "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "How many of the unit's spikes are drawn one by one, picked at random " + ...
    "(the same ones each time); a sorted unit's mean is over them.");
place(E.waveSpikes, r, 2);
[S, r] = formRow(S, ["waveFrom" "waveTo"], "Time (x, ms):");
tg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.waveFrom = uieditfield(tg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "start", ...
    "ValueChangedFcn", changed, "Tooltip", "The x scale: where the waveform drawn starts, ms from the spike " + ...
    "(negative: before it). Blank: the start of the cut.");
uilabel(tg, "Text", "to");
E.waveTo = uieditfield(tg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "end", ...
    "ValueChangedFcn", changed, "Tooltip", "Where the waveform drawn ends, ms from the spike. Blank: the end of " + ...
    "the cut. A span that misses the waveform draws all of it.");
[S, r] = formRow(S, ["waveAmp" "waveAmpLo" "waveAmpHi"], "Amplitude (y):");
ag = subgrid(S.Body, r, {'1x', 56, 'fit', 56});
E.waveAmp = uidropdown(ag, "Items", ["Each unit's own range" "Fixed range"], "ItemsData", ["unit" "fixed"], ...
    "Value", "unit", "ValueChangedFcn", changed, "Tooltip", "The y scale. Each unit's own: its waveform fills " + ...
    "the height. One range for the units drawn (a unit waveforms panel): their sizes can be compared, with a " + ...
    "scale bar on the probe. Fixed: the range typed at the right, in the waveform's units (µV), the same for " + ...
    "every observation; what lies beyond it is cut at its edge.");
E.waveAmpLo = uieditfield(ag, "numeric", "Value", -100, "ValueChangedFcn", changed, ...
    "Tooltip", "The fixed range's bottom, in the waveform's units (µV).");
uilabel(ag, "Text", "to");
E.waveAmpHi = uieditfield(ag, "numeric", "Value", 100, "ValueChangedFcn", changed, ...
    "Tooltip", "The fixed range's top, in the waveform's units (µV).");
[S, r] = formRow(S, ["waveWidth" "waveHeight"], "Size:");
zg = subgrid(S.Body, r, {'fit', '1x', 'fit', '1x'});
uilabel(zg, "Text", "width");
E.waveWidth = uispinner(zg, "Limits", [0.25 3], "Step", 0.25, "Value", 1, "ValueDisplayFormat", "%.2gx", ...
    "ValueChangedFcn", changed, "Tooltip", "The inset's width, a factor of its default (a third of the panel's " + ...
    "width); on the probe, each glyph's.");
uilabel(zg, "Text", "height");
E.waveHeight = uispinner(zg, "Limits", [0.25 3], "Step", 0.25, "Value", 1, "ValueDisplayFormat", "%.2gx", ...
    "ValueChangedFcn", changed, "Tooltip", "The inset's height, a factor of its default (a third of the panel's " + ...
    "height); on the probe, each glyph's.");
[S, r] = formRow(S, ["waveLocation" "waveBox"], "Inset location:");
wl = subgrid(S.Body, r, {'1x', 'fit'});
E.waveLocation = uidropdown(wl, "Items", ["North-east" "North" "North-west" "West" "South-west" "South" "South-east" "East"], ...
    "ItemsData", EphysAnalysisConfig.WaveformLocations, "Value", "northeast", "ValueChangedFcn", changed, ...
    "Tooltip", "Where in the panel the inset sits.");
E.waveBox = uicheckbox(wl, "Text", "Axis box", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "The inset's outline and pale ground.");
[S, r] = formRow(S, ["wavePP" "waveCount"], "Label:");
wt = subgrid(S.Body, r, {'fit', 'fit', '1x'});
wt.ColumnSpacing = 12;
E.wavePP = uicheckbox(wt, "Text", "Peak-to-peak", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Say the mean waveform's peak-to-peak amplitude (over the whole cut).");
E.waveCount = uicheckbox(wt, "Text", "Spike count", "ValueChangedFcn", changed, ...
    "Tooltip", "Say how many spikes the unit has in the whole recording.");
[S, r] = formRow(S, ["waveSites" "waveNames"], "On the probe:");
pg = subgrid(S.Body, r, {'fit', 'fit', '1x'});
pg.ColumnSpacing = 12;
E.waveSites = uicheckbox(pg, "Text", "Sites", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "The probe's sites in gray behind the waveforms.");
E.waveNames = uicheckbox(pg, "Text", "Unit names", "ValueChangedFcn", changed, ...
    "Tooltip", "Each unit's name (and its label) beside its waveform.");
end


function b = superHeader(eg)
%superHeader  A supersection's header in the editor's grid: a dark bar that collapses its sections (layoutFigureEditor sets its text and place).
b = uibutton(eg, "Text", "", "HorizontalAlignment", "left", "FontWeight", "bold", "FontSize", 14, ...
    "FontColor", [1 1 1], "BackgroundColor", [0.21 0.26 0.35], "Tag", "formSectionToggle", ...
    "Tooltip", "Show or hide every section under this heading.");
end


function searchPicked(obj, lb, ~)
%searchPicked  A match picked in the search list (a click, or the arrows): the editor shows it; the focus stays in the list.
v = lb.Value;
if ~isnumeric(v) || ~isscalar(v) || v < 1 || isequal(lb.UserData, v); return; end   % (a click went there already)
lb.UserData = [];
obj.FigureSearchState = "list";   % Enter now goes into it (onKeyPress)
obj.gotoFigureRow(v, Focus=false);
end


function searchClicked(obj, lb, evt)
%searchClicked  A click on a match in the search list: go there, the focus on its control.
i = evt.InteractionInformation.Item;
if isempty(i) || ~isnumeric(lb.ItemsData) || i > numel(lb.ItemsData) || lb.ItemsData(i) < 1; return; end
lb.UserData = lb.ItemsData(i);
obj.gotoFigureRow(lb.ItemsData(i));
end


function h = gridHeight(g)
%gridHeight  The height a grid of fixed-height rows takes.
rh = [g.RowHeight{:}];
h = sum(rh) + (numel(rh) - 1) * g.RowSpacing + g.Padding(2) + g.Padding(4);
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


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
