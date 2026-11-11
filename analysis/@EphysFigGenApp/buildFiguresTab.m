function buildFiguresTab(obj)
%buildFiguresTab  The Figures tab: the figures, their editor, and the preview of one observation.
%   A figure (the Figures section of the config) is designed for one
%   observation -- a sorted unit, a signal channel, or the dataset -- as
%   panels placed freely on its page (raster, PSTH, continuous signal,
%   heat map, ..., each at its rect), each
%   holding layers of data that follow the observation or name fixed items.
%   Three columns:
%   Left    the figures as a tree (FiguresTree, refreshFigureList: a
%           leaf "<id>  (<n> panels)", with ", per <kind>" unless grouped by
%           it and "(off)" when disabled unless grouped by status) under
%           the groups Group by names (what it observes: unit, channel or
%           dataset, or on the probe; enabled / off; none), each node with a check box that
%           ticks or unticks the figure, or every figure of a group
%           (onFigureTreeClicked), All / None / Invert (onFigureCheck);
%           Add (a blank figure, then the New panel window: onAddFigure),
%           Save as panel type... (the figure shown kept as a panel type
%           of yours: the New panel window lists it, to place its panels,
%           arranged as they are, in any figure; onFigureTemplate "panel"),
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
%           onIdEdited, onIdAutoToggled), Title, Enabled and a summary,
%           always open; then Observations (the data the figure is drawn
%           for; Pages: one page per observation, across datasets or on the
%           probe, the last two showing the Sessions or Probe layout
%           section; Starred only, the Signal channels, the unit filter
%           (with On channels), the response test (folded: Windows, Parameter, Correction and alpha), Per trial group: one
%           figure per observation and group), Alignment (the figure's
%           Event reference, Epoch window and Trial selection, each under a
%           sub-heading with its "Use default" box: the Alignment tab's
%           while it is ticked; Epoch Diagram), Layout (New panel... (the
%           New panel window: its type, name, place and key parameters,
%           onNewPanel); under the sub-heading Page, the Page size (the
%           page it is exported on: a drop-down of suggestions you can type
%           in, the width and height in px, in or cm with a lock for the
%           aspect ratio: onFigureSizeEdited; the preview is shaped like
%           it), Boxes mean (the plot area, its labels kept clear, or the
%           outer box, labels inside) and Padding (the clear space round a
%           panel's labels); under App preferences (not saved in the
%           config), Units (normalized, %, cm, in or px: how the rect, the
%           padding and the snap step are shown and typed: onRectUnitsChanged)
%           and Snap and its step (Arrange's snapping and the arrow keys'
%           nudge: onSnapChanged); a hint on Arrange), Panel (the selected
%           panel: its line, "psth_1 (PSTH): 10.2 x 6.0 cm at 0, 0", type
%           and title; Position (x, y) and Size (w, h) of its rect in the
%           Layout's Units, from the page's bottom-left corner
%           (onPanelRectEdited: one undo step per field); Set corners (two
%           clicks on the preview: onSetCorners), Remove panel, Bring
%           forward and Send back (the drawing order where panels overlap:
%           onPanelOrder)),
%           First-spike latency (the figure's latency block, one for
%           every panel that reads it: the method, the window, the
%           baseline and its rate, the burst's surprise or the count's
%           alpha, the onset's CUSUM bins, duration, threshold and
%           allowance, folded under Response onset; a note names the
%           panels that read it, each with a link to its section; no key),
%           Panel alignment
%           (the panel's own event and window, locked to the figure's while
%           "Same as the figure" is ticked; its own trial selection, locked
%           to the figure's while "Trial selection as the figure" is ticked:
%           onPanelSelectionToggled; Apply to all panels, Re-link all
%           panels), Layers (the panel's layers, Add a source the type
%           draws, Remove, Up, Down, and the rows of the layer picked; a
%           trials layer's Trial measure, and a trial scatter's Trial measure (x), named
%           beside an Edit... button that opens the Trial measure window:
%           trialMeasureDialog), the panel type's settings (all of the
%           panel's own), in three sections by what an edit costs: Analysis
%           (what is computed: bins, smoothing, measure, baseline with the
%           auROC rows under a folded sub-heading, normalization, the mask,
%           the signal, a heat map's rows, the spectral panels' Chronux
%           rows with their tapers under a folded sub-heading, the trial
%           panels' groupings, bins, fit and correlation, and under
%           Statistics a PSTH's, continuous signal's, firing rate or
%           tuning panel's Error with its bootstrap resamples and the trial
%           panels' summary and tests: errorTypeItems), Display (what is
%           only drawn: trace or heat map, fill, stack, the raster's sort
%           and ticks, a raster's First-spike marks and a PSTH's Latency box
%           plot, each a summary beside a button that opens their modal
%           window, the marks' or the box's look: latencyDialog; a raster's
%           or PSTH's Onset line; the Band fill and Band edge of every panel
%           that draws bands; the event traces', trial panels' and legend
%           panels' looks) and Axes (the axes' box, labels, sides and what
%           they show, the trial panels' scales and x limits, the y limits,
%           colormap and color limits); each has Apply to all panels in its
%           header (applyOptionsToAll), its Waveform
%           (the unit's waveform: an inset on a raster, PSTH, firing rate
%           or tuning curve panel, the panel itself on a unit waveforms
%           panel; what it shows, its x and y scales, size, place and
%           label; shown for every type whose layers may be spikes, with
%           a note on what it sets or why the type draws none:
%           waveformSection, waveformNote),
%           the panel's Annotations (for the selected panel: its Text note
%           and its Overlays, each under a sub-heading: onAddFigureOverlay,
%           onFigureOverlayPicked),
%           Style, Design and looks and Sessions (Pages: Across datasets: the figure
%           drawn once over the ticked or picked datasets, its facet, colors,
%           error band, unit matching with the mapping file's Browse... and
%           Edit..., minimum sessions and trial groups; then the picker
%           lists the matched observations and the preview draws them
%           across the sessions, with a "Figure:" drop-down under it for
%           one figure per subject or trial group, and the Dataset
%           drop-down is off) and Probe layout (Pages: On the probe: the figure
%           drawn once per dataset, each unit or channel a tile of its
%           panels at its site; the layout, the overlap strategy and its
%           lanes, the shanks, channels and depth range laid out, the most
%           tiles and units per site, the tiles' size, scale and labels,
%           shared y, the scale tile, the sites and the leaders; a note
%           counts the tiles on the active dataset; then the picker lists
%           one entry, the probe, the preview draws every tile, and Per
%           trial group are off). Each section collapses under its colored
%           header (onFigureSectionToggled); the color says the scope: Figure
%           sections are blue, Panel green and Look violet, each section a
%           shade of its supersection's hue (the scopes table). A long
%           section is cut into groups by sub-headings (formSubheading): a
%           bold gray title over the rows under it, hidden when they all are;
%           a collapsible one ("Response test" in Observations) folds its
%           rows away under a "▸" button, and stays as left
%           (onFigureSubheadingToggled; preference FigureSubheadingsCollapsed).
%           The sections stand under three
%           supersections, each a dark header that collapses them all
%           (onFigureSuperToggled): Figure (Observations, Alignment, Layout,
%           First-spike latency, Sessions, Probe layout), Panel
%           (Panel, Panel alignment, Layers, Analysis, Display, Axes, Waveform, Annotations;
%           its header names the selected panel) and Look (Style,
%           Design and looks), built in that order so Tab follows it (but for
%           First-spike latency, Sessions and Probe layout, built before
%           Layout, which comes before them on the screen). Alt+1 to Alt+3
%           go to a supersection (gotoFigureSuper), Ctrl+1 to Ctrl+9 and
%           Ctrl+0 to the keyed sections, Observations, Alignment and Layout,
%           then the Panel supersection's, Panel to Annotations
%           (gotoFigureSection; onKeyPress); First-spike latency, Sessions,
%           Probe layout, Waveform,
%           Style and Design and looks have no key. Over the editor, a search field
%           (Ctrl+F; onFigureSearch) lists the rows whose label (or
%           tooltip) has the words typed, "Supersection > Section > Row",
%           in a list under it; Enter or a click goes there (gotoFigureRow),
%           "?" lists the tab's keys (onFigureKeys). Every color field
%           (a mark's, a layer's, the ticks', bands', bars' outline,
%           baseline's, text's, ground's, an overlay's line, fill and
%           outline, the group colors, the error band's fill and edge) has
%           a swatch at its right (colorSwatch, E.swatch by field name)
%           that opens the color chooser (uisetcolor: ColorPicker); the
%           color picked is one named edit, as if typed. Every text that
%           labels the figure (its Title; the panel's Title, X axis and Y
%           axis labels; a layer's Name; the Text note) has a "{x}" button
%           at its right (labelVariableButton, E.varButton by field name):
%           a menu of the label variables ({Line}, {Response}, ...:
%           figureLabelVariables, with their values on the figure
%           previewed: labelVariableValues) that adds the one picked to the
%           text as one named edit, and opens their list (onLabelVariables). syncFigureEditor
%           shows the rows the figure, panel and layer use;
%           layoutFigureEditor packs them.
%   Right   a column of buttons at the left -- Preview, Redraw All
%           (every enabled figure's preview drawn again where out of date,
%           the shown figure first: onRedrawAllFigures; the selected
%           figure's files for every observation are the File menu's
%           Generate selected figure, onGenerateFigure), Export preview (the
%           observation picked, written as a run writes it into a preview
%           folder and shown: onExportPreview), Auto (a slider from off
%           to every edit: how slow a redraw an edit may start,
%           autoRedrawLimit, onFigureAutoRedrawChanged), and < and > on a row
%           (Page Up / Page Down) -- beside the dataset, the observation
%           picked (figureObservations' labels) and the Favorites
%           (buildFavorites: a filter and every starred dataset, channel
%           and unit, picked to preview: onFavoritePicked), the first two
%           with their star toggle (starButton, onStarToggled) and note
%           button (noteButton: the NotePad, onNoteButton). The Design
%           drop-down is right of the dataset (the design every figure is
%           drawn in, also in the Design menu: onDesignChosen; the Look
%           section Design and looks has the same list, kept equal to it by
%           refreshDesigns, with Save look as design...: the preview's look
%           as a design of yours, onSaveDesign, and Edit aesthetics...: the aesthetics
%           editor on the preview's selected panel without a right-click,
%           onEditAesthetics). Under them a row: Template: (your figure
%           templates, FigureTemplate: the drop-down, re-listed as it
%           opens, refreshTemplates; Apply... into figures picked or as a
%           new figure, onApplyTemplate; Save as..., Update, Remove,
%           Import..., Export... and Report issue, onFigureTemplate) and,
%           at its right, Arrange (a state button: the panels moved and
%           resized over the preview, onArrangeToggled; its boxes:
%           syncArrangeOverlay). While Arrange is on, its align bar
%           takes the templates' place (buildAlignBar, syncAlignBar):
%           Align (panel boxes, axes, or axes and labels) to (the
%           selection, the first selected, the page), six buttons lining
%           the selected panels' edges or centers up, Space evenly across
%           and up, and its Gap (blank: even; onArrangeAlign,
%           figureAlign). Under it the preview
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
%           line, with Export preview again (as in the column of
%           buttons), Export code (the code
%           that loads the data in the preview's epochs and draws the
%           preview, in the editor: onFigureCode) and Open
%           in window (onOpenFigureWindow: the figure in a figure() of its
%           own) at its right. Every button has a key, named in its tooltip
%           (onKeyPress): Ctrl+P Preview, Ctrl+R Redraw All, Ctrl+T Auto,
%           Page Up / Page Down < and >, Ctrl+K Export preview, Ctrl+E
%           Export code, Ctrl+W Open in window; Ctrl+U presses the Export
%           tab's Test report.
g = uigridlayout(obj.TabFigures, [1 3]);
g.ColumnWidth = {285, 560, '1x'};
g.Padding = [8 8 8 8];
changed = @(src, ~) obj.onConfigChanged("figure", src);   % the control names the edit (undo history)
gray = [0.35 0.35 0.35];
obj.FigureObservation = containers.Map('KeyType', 'char', 'ValueType', 'any');
obj.FigureIdRenames = containers.Map('KeyType', 'char', 'ValueType', 'any');
PT = EphysAnalysisConfig.panelTypes();

% --- left: the figures, a tree under groups ------------------------------------------------------
lg = uigridlayout(g, [10 2]);
lg.RowHeight = {22, 28, 30, '1x', 34, 30, 30, 30, 30, 64};
lg.ColumnWidth = {'1x', '1x'};
lg.Padding = [0 0 0 0];
l = uilabel(lg, "Text", "Figures  (ticked = enabled)", "FontWeight", "bold");
place(l, 1, [1 2]);
l = uilabel(lg, "Text", "Group by:");
place(l, 2, 1);
obj.FigureGroupDropDown = uidropdown(lg, "Items", ["What it observes" "Enabled / off" "None"], ...
    "ItemsData", ["observe" "status" "none"], "Value", "observe", "ValueChangedFcn", @(~,~) onGroupByChanged(obj), ...
    "Tooltip", "How the tree sorts the figures: by what each is drawn for (a unit, a channel or the dataset; a figure " + ...
    "across sessions too; the figures on the probe in a group of their own), enabled or off, or a flat list. Within a group the figures keep the run order; Up / Down " + ...
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
    "Tooltip", "Add a blank figure and pick its first panel in the New panel window (Cancel leaves it blank): a panel " + ...
    "type, or a saved figure such as Raster over PSTH.");
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
    "(observations, alignment, panels, each panel's options, style, looks, across sessions, on the probe). Each figure keeps its " + ...
    "id, title and enabled; one step of Undo; the other figures' previews are marked out of date, not drawn again.");
place(obj.CopyFigureButton, 8, [1 2]);
obj.SavePanelTypeButton = uibutton(lg, "Text", "Save as panel type...", "ButtonPushedFcn", @(~,~) obj.onFigureTemplate("panel"), ...
    "Tooltip", "Keep the figure shown as a panel type of yours: the New panel window then lists it under Saved figures, " + ...
    "to place all its panels, arranged as they are here, next to the selected panel of any figure. The panels are " + ...
    "copied: in that figure they are ordinary panels. It is a figure template too (the Template list above the preview).");
place(obj.SavePanelTypeButton, 9, [1 2]);
l = uilabel(lg, "Text", "A figure is one observation's panels: a unit's, a channel's or the dataset's. " + ...
    "File > Generate selected figure draws it for each observation; Run (Export tab) draws the enabled ones.", ...
    "WordWrap", "on", "FontColor", gray, "VerticalAlignment", "top");
place(l, 10, [1 2]);

% --- middle: Apply last change, the search field, its matches and the editor -------------------------
mc = uigridlayout(g, [4 1], "RowHeight", {34, 30, 0, '1x'}, "Padding", [0 0 0 0], "RowSpacing", 4);
% Apply last change... (Edit > Apply last change to figures...): named after the step by refreshEditMenu
cmdKey = "Ctrl";
if ismac; cmdKey = "Cmd"; end
obj.FigureApplyLastButton = uibutton(mc, "Text", "Apply last change...", "Enable", "off", ...
    "ButtonPushedFcn", @(~,~) obj.onApplyToFigures(), ...
    "Tooltip", "Apply last change to figures (" + cmdKey + "+Shift+A)");
obj.FigureApplyLastButton.Layout.Row = 1;
fg0 = uigridlayout(mc, [1 2], "ColumnWidth", {'1x', 34}, "Padding", [0 0 0 0], "ColumnSpacing", 4);
fg0.Layout.Row = 2;
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
obj.FigureSearchList.Layout.Row = 3;
ep = uipanel(mc, "Title", "Figure");
ep.Layout.Row = 4;
obj.FigureEditorPanel = ep;
eg = uigridlayout(ep, [21 1]);
eg.RowHeight = [repmat({0}, 1, 20) {'1x'}];
eg.RowSpacing = 0;   % (a 6 px row under each section is the gap: layoutFigureEditor)
eg.Padding = [4 4 4 4];
eg.Scrollable = "on";
obj.FigureEditorGrid = eg;
E = struct();

% the supersections, which section belongs to which, and the header colors: the one table that says it. A header
% color says the scope (rule R6 of the settings plan): FIGURE blue, PANEL green, LOOK violet, each section a shade of
% its supersection's hue, lighter along the supersection's section order (formSection pales it further, until black
% text reads on it). Sections lists a supersection's sections in the order they are built and shown; the supersection
% headers (U below), each section's Super and the colors all read it, so to move a section to another supersection
% (or add one) change Sections here and build the section where it belongs in the order. The always-open section
% (Id, Title, ...) is in none and keeps formSection's default color. Hue is an HSV hue (0 to 1).
scopes = struct('Name', {"figure" "panel" "look"}, 'Title', {"Figure" "Panel" "Look"}, 'Key', {"1" "2" "3"}, ...
    'Hue', {0.60, 0.35, 0.75}, ...
    'Sections', {["observations" "align" "arrangement" "latency" "sessions" "probe"], ...
    ["panel" "palign" "layers" "analysis" "display" "axes" "waveform" "annotations"], ["style" "looks"]});
tint = @(name) scopeTint(scopes, name);
% a collapsible sub-heading (formSubheading) calls this with its section's name and its key
subToggle = @(name, key) obj.onFigureSubheadingToggled(name, key);

% the sections with a header and a key or not, in order (built so, so Tab follows it), and the keys 1-9, 0
order = ["observations" "align" "arrangement" "sessions" "probe" "panel" "palign" "layers" "analysis" "display" ...
    "axes" "annotations" "style" "looks"];
keyed = order(~ismember(order, ["sessions" "probe" "style" "looks"]));   % Observations Ctrl+1, Alignment 2, Layout 3, Panel 4, Panel alignment 5, Layers 6, Analysis 7, Display 8, Axes 9, Annotations 0

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
% every text that labels the figure prints TeX character names as their characters (figureLabelSymbols)
symbolsTip = " Special characters: type \mu, \pm, \Delta or ^\circ for µ, ±, Δ or ° (any TeX name, e.g. \alpha, \leq, \rightarrow).";
[S, r] = formRow(S, "title", "Title:");
E.title = uieditfield(S.Body, "text", "Placeholder", "automatic", "ValueChangedFcn", changed, ...
    "Tooltip", "Blank: ""<id>: <observation> — <event> (<n> epochs)"". A title of your own names no " + ...
    "observation, so the top-left panel names it (unless the title has {Unit} or {Observation}). Variables in braces, " + ...
    "such as {Unit} or {Event}, are filled in for each figure: the {x} button lists them." + symbolsTip);
place(E.title, r, 2);
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
[S, r] = formRow(S, "pages", "Pages:");
E.pages = uidropdown(S.Body, "Items", ["One per observation" "Across datasets (one per matched observation)" ...
    "On the probe (one per dataset, a tile per observation)"], "ItemsData", ["each" "sessions" "probe"], ...
    "ValueChangedFcn", changed, "Tooltip", "How the figure is paged. One per observation: a page for each unit, channel " + ...
    "or dataset observed, on the active dataset. Across datasets: draw the figure once across the datasets instead of " + ...
    "once per dataset: each observation (a site, a cell of the mapping, a channel or the dataset) is computed on every " + ...
    "session and each panel's layers are merged, a color per session (or subject); Generate selected figure and Run " + ...
    "then write it to the sessions folder. On the probe: draw the figure once per dataset, every observation (each " + ...
    "unit, or each channel) a small tile of all its panels at its site on the probe, instead of a page per " + ...
    "observation; Generate selected figure and Run then write one page per dataset. The Sessions and Probe layout " + ...
    "sections hold the settings of the last two, and show only for them.");
place(E.pages, r, 2);
[S, r] = formRow(S, "obsStarred", "Favorites:");
E.obsStarred = uicheckbox(S.Body, "Text", "Starred only", "ValueChangedFcn", changed, ...
    "Tooltip", "Observe only what is starred (★): the starred units of the sort in use, the starred channels (a " + ...
    "detection channel by its channel) or, for a figure of the dataset, a starred dataset. Generate selected figure, < > and " + ...
    "Export runs then draw just the favorites (observe.starred in the config); across sessions, an observation " + ...
    "starred on any of its sessions.");
place(E.obsStarred, r, 2);
[S, r] = formRow(S, "obsChannels", "Signal channels:");
E.obsChannels = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "The extract's columns observed, e.g. 1 3 5 (blank = all).");
place(E.obsChannels, r, 2);
[S, ~] = formSubheading(S, "unitFilter", "Unit filter");
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
[S, r] = formRow(S, "obsMaxUnits", "Max units:");
E.obsMaxUnits = uieditfield(S.Body, "text", "Value", "Inf", "ValueChangedFcn", changed, ...
    "Tooltip", "The most units observed (Inf = all), in probe order.");
place(E.obsMaxUnits, r, 2);
[S, r] = formRow(S, "obsShanks", "Shanks:");
E.obsShanks = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed);
place(E.obsShanks, r, 2);
[S, r] = formRow(S, "obsUnitChannels", "On channels:");
E.obsUnitChannels = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "The recording channels whose units are observed, e.g. 1:8.");
place(E.obsUnitChannels, r, 2);
[S, ~] = formSubheading(S, "responseTest", "Response test", Collapsible=true, Callback=subToggle);
[S, r] = formRow(S, ["obsRespBaseFrom" "obsRespBaseTo" "obsRespFrom" "obsRespTo"], "Windows (s):");
wg = subgrid(S.Body, r, {'1x', 'fit', '1x', 'fit', '1x', 'fit', '1x'});
E.obsRespBaseFrom = uieditfield(wg, "numeric", "Value", -0.2, "ValueChangedFcn", changed, "Tooltip", "The test's baseline window start (s from the event).");
uilabel(wg, "Text", "to");
E.obsRespBaseTo = uieditfield(wg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "The test's baseline window end (s).");
uilabel(wg, "Text", "response");
E.obsRespFrom = uieditfield(wg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "The response window start (s from the event).");
uilabel(wg, "Text", "to");
E.obsRespTo = uieditfield(wg, "numeric", "Value", 0.2, "ValueChangedFcn", changed, "Tooltip", "The response window end (s).");
[S, r] = formRow(S, "obsRespParam", "Parameter:");
E.obsRespParam = uidropdown(S.Body, "Editable", "on", "Items", "", "ValueChangedFcn", changed, ...
    "Tooltip", "The trial parameter of the tuning test.");
place(E.obsRespParam, r, 2);
[S, r] = formRow(S, ["obsRespCorrection" "obsRespAlpha"], "Correction, alpha:");
og = subgrid(S.Body, r, {'1x', '1x'});
E.obsRespCorrection = uidropdown(og, "Items", ["BH (FDR)" "Holm" "Bonferroni" "none"], "ItemsData", ["bh" "holm" "bonferroni" "none"], ...
    "ValueChangedFcn", changed, "Tooltip", "How the p values are adjusted for the number of units tested (pAdjust).");
E.obsRespAlpha = uieditfield(og, "numeric", "Value", 0.05, "Limits", [0 1], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "Alpha: a unit passes when its adjusted p is at most this.");
[S, E] = aurocRows(S, E, "obsRa", changed);
[S, ~] = formSubheading(S, "", "");   % (closes the group: the rows below belong to none)
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

% the figure's event reference, epoch window and trial selection: the Alignment tab's controls, in one section of three
% sub-headings, each with its Use default box at the right. A body is one row spanning both columns that holds a
% borderless panel for AlignControls to fill (buildAlignControls); its height is the controls' (gridHeight), set once
% they are built. The rows show by their keys refBody, windowBody and selectionBody (syncFigureEditor).
S = formSection(eg, 5, "align", "Alignment", Color=tint("align"));
bodies = gobjects(1, 3);
rows = zeros(1, 3);
parts = ["ref" "window" "selection"];   % (AlignControls' parts)
titles = ["Event reference" "Epoch window" "Trial selection"];
boxes = ["defaultRef" "defaultWindow" "defaultSelection"];
whats = ["event reference" "epoch window" "trial selection"];
for q = 1:3
    [S, ~, hg] = formSubheading(S, parts(q), titles(q), Control=true);
    E.(boxes(q)) = defaultBox(obj, hg, whats(q));
    [S, r] = formRow(S, parts(q) + "Body", "", 100);
    bodies(q) = uipanel(S.Body, "BorderType", "none");
    bodies(q).Layout.Row = r;
    bodies(q).Layout.Column = [1 2];
    rows(q) = numel(S.Heights);
end
C = obj.buildAlignControls(bodies, @(part) obj.onFigureAlignEdited(part));
E.epochs = C.Diagram;
E.epochs.ButtonPushedFcn = @(~,~) obj.onShowEpochs();
E.epochs.Tooltip = "A window, kept above the app, that draws how this figure's event reference, epoch window and " + ...
    "trial selection cut the active dataset into epochs. It follows every edit.";
set([C.RefGrid C.WindowGrid C.SelectionGrid], 'Padding', [4 2 4 2]);
S.Heights(rows) = [gridHeight(C.RefGrid) gridHeight(C.WindowGrid) gridHeight(C.SelectionGrid)];
S.Body.RowHeight = num2cell(reshape([S.Heights; repmat(S.Gap, 1, numel(S.Heights))], 1, []));
obj.FigureAlignControls = C;
sec = [sec S];

% the figure's first-spike latency and response onset: one block for every panel that reads them (figureLatencies); no key
S = formSection(eg, 18, "latency", "First-spike latency", Color=tint("latency"));
[S, r] = formRow(S, "latNote", "", 44);
E.latNote = uilabel(S.Body, "Text", "", "FontColor", gray, "WordWrap", "on", "VerticalAlignment", "top");
place(E.latNote, r, [1 2]);
[S, r] = formRow(S, "latLinks", "");   % a link to each panel that reads the block (syncFigureEditor makes them: latencyLinks)
E.latLinks = uigridlayout(S.Body, [1 1], "ColumnWidth", {'fit'}, "Padding", [0 0 0 0], "ColumnSpacing", 6, ...
    "BackgroundColor", S.Body.BackgroundColor);
place(E.latLinks, r, [1 2]);
[S, r] = formRow(S, "latMethod", "Method:");
E.latMethod = uidropdown(S.Body, "Items", ["First spike in the window" "Poisson surprise (Legendy & Salcman 1985)" ...
    "Baseline Poisson count (Chase & Young 2007)"], "ItemsData", EphysAnalysisConfig.LatencyMethods, "ValueChangedFcn", changed, ...
    "Tooltip", "How each epoch's first-spike latency is found, once per unit for every panel of the figure that reads it " + ...
    "(a raster's marks and latency sort, a PSTH's latency box plot, a heat map of trials sorted by latency). First " + ...
    "spike: the first spike in the window (a spontaneous spike before the response counts). Poisson surprise: the " + ...
    "first spike of the first burst whose surprise against the baseline rate passes a threshold. Baseline Poisson " + ...
    "count: the first spike at which the spikes counted since the window's start are improbable at the baseline rate.");
place(E.latMethod, r, 2);
[S, r] = formRow(S, ["latFrom" "latTo"], "Detect (ms):");
lwg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.latFrom = uieditfield(lwg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", ...
    "The earliest latency (and response onset), ms from the aligned event (included; negative: before it).");
uilabel(lwg, "Text", "to");
E.latTo = uieditfield(lwg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "end", "ValueChangedFcn", changed, ...
    "Tooltip", "The latest, ms from the event (included). Blank: each panel's window's end.");
[S, r] = formRow(S, ["latBaseline" "latBaseFrom" "latBaseTo"], "Baseline:");
lbg2 = subgrid(S.Body, r, {'1x', 60, 'fit', 60});
E.latBaseline = uidropdown(lbg2, "Items", ["Before the event" "Window (ms):"], "ItemsData", EphysAnalysisConfig.LatencyBaselines, ...
    "ValueChangedFcn", changed, "Tooltip", "Where the baseline rate is counted (the Poisson methods' rate, the onset's " + ...
    "mean and SD): the part of each panel's window before the event, or a window of its own (ms from the event).");
E.latBaseFrom = uieditfield(lbg2, "numeric", "Value", -100, "ValueChangedFcn", changed, "Tooltip", ...
    "The baseline window's start, ms from the event.");
uilabel(lbg2, "Text", "to");
E.latBaseTo = uieditfield(lbg2, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "The baseline window's end, ms from the event.");
[S, r] = formRow(S, "latRate", "Baseline rate:");
E.latRate = uidropdown(S.Body, "Items", ["The unit's (every epoch's baseline together)" "Each trial's own"], ...
    "ItemsData", EphysAnalysisConfig.LatencyRates, "ValueChangedFcn", changed, "Tooltip", "The Poisson methods' rate: " + ...
    "every epoch's baseline spikes counted together (steady), or each epoch's own (a trial with no baseline spike " + ...
    "then takes its first spike, or first burst).");
place(E.latRate, r, 2);
[S, r] = formRow(S, ["latSurprise" "latMinSpikes"], "Burst:");
lsg = subgrid(S.Body, r, {'fit', '1x', 'fit', '1x'});
uilabel(lsg, "Text", "surprise at least");
E.latSurprise = uieditfield(lsg, "numeric", "Value", 3, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "The least Poisson surprise of a burst, -log10 P (3: P < 0.001 at the baseline rate).");
uilabel(lsg, "Text", "from spikes");
E.latMinSpikes = uispinner(lsg, "Limits", [2 50], "Step", 1, "Value", 3, "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "The fewest spikes a burst starts with, each interval under half the baseline's mean interval.");
[S, r] = formRow(S, "latAlpha", "Alpha (p below):");
E.latAlpha = uieditfield(S.Body, "numeric", "Value", 0.01, "Limits", [0 1], "LowerLimitInclusive", "off", ...
    "UpperLimitInclusive", "off", "ValueChangedFcn", changed, "Tooltip", "The first spike whose count since the " + ...
    "window's start has P(N >= k) below this at the baseline rate is the latency.");
place(E.latAlpha, r, 2);
[S, ~] = formSubheading(S, "onset", "Response onset", Collapsible=true, Callback=subToggle);
[S, r] = formRow(S, ["latCusum" "latCusumSustain"], "Onset bins (ms):");
lcg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.latCusum = uieditfield(lcg, "numeric", "Value", 2, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The response onset (a raster's or PSTH's Onset line): the PSTH's bins its CUSUM sums, ms.");
uilabel(lcg, "Text", "lasting (ms)");
E.latCusumSustain = uieditfield(lcg, "numeric", "Value", 5, "Limits", [0 Inf], "ValueChangedFcn", changed, ...
    "Tooltip", "How long the CUSUM must stay over its threshold and rising for an onset, ms (0: the crossing alone).");
[S, r] = formRow(S, ["latCusumSD" "latCusumDrift"], "Onset threshold:");
ltg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.latCusumSD = uieditfield(ltg, "numeric", "Value", 5, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The CUSUM's threshold, baseline SDs: the onset is where the cumulative excess over the baseline passes it.");
uilabel(ltg, "Text", "allowance (SD)");
E.latCusumDrift = uieditfield(ltg, "numeric", "Value", 1, "Limits", [0 Inf], "ValueChangedFcn", changed, ...
    "Tooltip", "Taken off each bin's excess, baseline SDs, so the CUSUM stays at 0 on the baseline (0: the plain excess).");
sec(end+1) = S;

% across sessions: the figure drawn once over several datasets, each layer merged (figureSessionCompute); no key
S = formSection(eg, 14, "sessions", "Sessions", Color=tint("sessions"));
[S, ~] = formSubheading(S, "datasets", "Datasets");
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
[S, ~] = formSubheading(S, "drawing", "Drawing");
[S, r] = formRow(S, "sesFacet", "One page per:");
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
[S, ~] = formSubheading(S, "matching", "Matching");
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
[S, ~] = formSubheading(S, "", "");   % (closes the group: the note belongs to none)
[S, r] = formRow(S, "sesNote", "", 44);
E.sesNote = uilabel(S.Body, "Text", "", "FontColor", gray, "WordWrap", "on", "VerticalAlignment", "top");
place(E.sesNote, r, [1 2]);
sec(end+1) = S;

% on the probe: the figure drawn once per dataset, a tile of its panels per unit or channel at its site
% (figureProbeTiles, computeProbeFigure); no key
S = formSection(eg, 19, "probe", "Probe layout", Color=tint("probe"));
[S, r] = formRow(S, "prbLayout", "Layout:");
E.prbLayout = uidropdown(S.Body, "Items", ["Schematic (rows of sites)" "Physical (µm)"], "ItemsData", ["schematic" "physical"], ...
    "ValueChangedFcn", changed, "Tooltip", "Schematic: each shank a column, its sites in rows equally spaced (the " + ...
    "depth written at the rows), so the tiles never overlap. Physical: the tiles where the sites are, in µm, sized " + ...
    "from the site pitch, with an overlap strategy.");
place(E.prbLayout, r, 2);
[S, r] = formRow(S, "prbOverlap", "Overlap:");
E.prbOverlap = uidropdown(S.Body, "Items", ["Slide apart along the shank" "Lanes beside the shank" "Shrink the tiles" "Allow"], ...
    "ItemsData", ["nudge" "lanes" "shrink" "allow"], "ValueChangedFcn", changed, ...
    "Tooltip", "Physical: what is done with tiles that would overlap. Slide apart: they move along the shank, in " + ...
    "order, a leader line to their sites. Lanes: they alternate across lanes beside the shank, then slide apart. " + ...
    "Shrink: every tile shrinks until none overlaps. Allow: drawn where they fall.");
place(E.prbOverlap, r, 2);
[S, r] = formRow(S, "prbLanes", "Lanes:");
E.prbLanes = uispinner(S.Body, "Limits", [1 Inf], "Step", 1, "Value", 2, "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "Overlap: Lanes beside the shank: how many lanes each shank's tiles alternate across.");
place(E.prbLanes, r, 2);
[S, ~] = formSubheading(S, "sites", "Sites laid out");
[S, r] = formRow(S, "prbShanks", "Shanks:");
E.prbShanks = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "The probe shanks (kcoords) whose sites are laid out, e.g. 1 2 (blank = all).");
place(E.prbShanks, r, 2);
[S, r] = formRow(S, "prbChannels", "Channels:");
E.prbChannels = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "The recording channels whose sites are laid out, e.g. 1:16 (blank = all).");
place(E.prbChannels, r, 2);
[S, r] = formRow(S, "prbDepth", "Depth range (µm):");
E.prbDepth = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "The probe y kept, ""lo hi"" in µm, e.g. 0 400 (blank = all; lo below hi).");
place(E.prbDepth, r, 2);
[S, ~] = formSubheading(S, "tiles", "Tiles");
[S, r] = formRow(S, "prbMaxTiles", "Max tiles:");
E.prbMaxTiles = uispinner(S.Body, "Limits", [1 Inf], "Step", 1, "Value", 64, "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "The most tiles on the page: more observations than that keep every k-th in probe order, and the page " + ...
    "says how many were left out.");
place(E.prbMaxTiles, r, 2);
[S, r] = formRow(S, "prbPerSite", "Per site:");
E.prbPerSite = uispinner(S.Body, "Limits", [1 Inf], "Step", 1, "Value", 3, "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "The most units drawn on one recording channel's site (the first in probe order), side by side; the " + ...
    "rest are left out and counted.");
place(E.prbPerSite, r, 2);
[S, r] = formRow(S, "prbTileWidth", "Tile width:");
E.prbTileWidth = uispinner(S.Body, "Limits", [0.1 1], "Step", 0.05, "Value", 0.9, "ValueDisplayFormat", "%.4g", ...
    "ValueChangedFcn", changed, "Tooltip", "A tile's share of its shank's column width.");
place(E.prbTileWidth, r, 2);
[S, r] = formRow(S, "prbTileHeight", "Tile height:");
E.prbTileHeight = uispinner(S.Body, "Limits", [0.1 1], "Step", 0.05, "Value", 0.9, "ValueDisplayFormat", "%.4g", ...
    "ValueChangedFcn", changed, "Tooltip", "Schematic: a tile's share of its row's height. Physical: its share of the " + ...
    "median site pitch (then times the tile scale).");
place(E.prbTileHeight, r, 2);
[S, r] = formRow(S, "prbScale", "Tile scale:");
E.prbScale = uispinner(S.Body, "Limits", [0 Inf], "LowerLimitInclusive", "off", "Step", 0.25, "Value", 1, "ValueDisplayFormat", "%.4gx", ...
    "ValueChangedFcn", changed, "Tooltip", "Physical: multiplies the tiles' size (the overlap strategy then clears them).");
place(E.prbScale, r, 2);
[S, r] = formRow(S, "prbLabels", "Labels:");
E.prbLabels = uidropdown(S.Body, "Items", ["Short" "Full" "None"], "ItemsData", ["short" "full" "none"], "ValueChangedFcn", changed, ...
    "Tooltip", "Each tile's label: the unit's short label (""ch 7"" for a channel), the observation's whole label, or none.");
place(E.prbLabels, r, 2);
[S, r] = formRow(S, "prbSharedY", "");
E.prbSharedY = uicheckbox(S.Body, "Text", "Shared y (each panel on one y range over every tile)", "ValueChangedFcn", changed, ...
    "Tooltip", "Every tile's panel of one id on one y range (the union of the tiles'), so the tiles compare at a " + ...
    "glance and the scale tile's ticks hold for all of them.");
place(E.prbSharedY, r, [1 2]);
[S, r] = formRow(S, "prbScaleTile", "");
E.prbScaleTile = uicheckbox(S.Body, "Text", "Scale tile (the bottom-left tile keeps its ticks and axis labels)", ...
    "ValueChangedFcn", changed, "Tooltip", "The tiles are drawn without tick or axis labels; the bottom-left one keeps " + ...
    "them, as the page's scale.");
place(E.prbScaleTile, r, [1 2]);
[S, r] = formRow(S, "prbShowSites", "");
E.prbShowSites = uicheckbox(S.Body, "Text", "Show sites (the shanks and their sites, pale, behind the tiles)", ...
    "ValueChangedFcn", changed, "Tooltip", "Draw each shank's body and every site of the probe map, pale, behind the " + ...
    "tiles (the sites laid out darker).");
place(E.prbShowSites, r, [1 2]);
[S, r] = formRow(S, "prbLeaders", "");
E.prbLeaders = uicheckbox(S.Body, "Text", "Leaders (a line from a moved tile to its site)", "ValueChangedFcn", changed, ...
    "Tooltip", "Physical: a thin line from each tile the overlap strategy moved to the site it stands for.");
place(E.prbLeaders, r, [1 2]);
[S, ~] = formSubheading(S, "", "");   % (closes the group: the note belongs to none)
[S, r] = formRow(S, "prbNote", "", 44);
E.prbNote = uilabel(S.Body, "Text", "", "FontColor", gray, "WordWrap", "on", "VerticalAlignment", "top");
place(E.prbNote, r, [1 2]);
sec(end+1) = S;

% the figure's page and its panels: adding them (New panel...), the selected panel's place (until the Panel section takes
% it over), the Page (its size, what a box means, the padding), the app preferences (the units everything is shown in,
% snapping) and the Arrange hint. The section's name stays "arrangement"; its key is Ctrl+3.
S = formSection(eg, 3, "arrangement", "Layout", Color=tint("arrangement"));
[S, r] = formRow(S, "newPanel", "", 30);
E.newPanel = uibutton(S.Body, "Text", "New panel...", "ButtonPushedFcn", @(~,~) obj.onNewPanel(), ...
    "Tooltip", "Add a panel: pick its type (each shown as a small plot), its name, where it goes (the largest " + ...
    "empty space of the page, or beside the selected panel, which it halves) and its key parameters. The first " + ...
    "panel fills the page.");
place(E.newPanel, r, [1 2]);
[S, ~] = formSubheading(S, "page", "Page");
[S, r] = formRow(S, "size", "Page size:");
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
[S, r] = formRow(S, "boxesMean", "Boxes mean:");
E.boxesMean = uidropdown(S.Body, "Items", ["plot area (labels kept clear)" "outer box (labels inside)"], ...
    "ItemsData", EphysAnalysisConfig.BoxesMeans, "Value", "plot", "ValueChangedFcn", changed, ...
    "Tooltip", "What a panel's rect is. Plot area: the axes themselves; their tick labels and labels are kept clear of " + ...
    "the neighbors and the page edge, so two panels put flush stay flush (a raster over its PSTH). Outer box: the " + ...
    "rect holds the panel with its labels, as a box on a slide does. For the whole figure.");
place(E.boxesMean, r, 2);
[S, r] = formRow(S, "padding", "Padding:");
pdg = subgrid(S.Body, r, {'1x', 44});
E.padding = uispinner(pdg, "Limits", [0 Inf], "Step", 0.05, "Value", 0.15, "ValueDisplayFormat", "%.10g", ...
    "ValueChangedFcn", changed, "Tooltip", "The clear space kept between a panel's labels and its neighbors or the page " + ...
    "edge (Boxes mean outer box: between the rect's edge and the labels). Two panels put flush stay flush. For the " + ...
    "whole figure, in the Units below (App preferences).");
E.paddingUnits = uilabel(pdg, "Text", "cm", "FontColor", gray);
[S, ~] = formSubheading(S, "prefs", "App preferences (not saved in the config)");
[S, r] = formRow(S, "rectUnits", "Units:");
E.rectUnits = uidropdown(S.Body, "Items", ["normalized (0-1 of the page)" "% of the page" "cm" "in" "px (at the Export dpi)"], ...
    "ItemsData", EphysAnalysisConfig.RectUnits, "Value", "cm", "ValueChangedFcn", @(~,~) obj.onRectUnitsChanged(), ...
    "Tooltip", "The units the panel's position and size, the padding and the snap step are shown and typed in: " + ...
    "0-1 or % of the page, or a length on the exported page (px at the Export tab's dpi). The panels are kept as " + ...
    "0-1 of the page, so they keep their places when the page size changes. A preference, for every figure.");
place(E.rectUnits, r, 2);
[S, r] = formRow(S, "snap", "");
sng = subgrid(S.Body, r, {'fit', 'fit', 70, '1x'});
place(sng, r, [1 2]);
E.snap = uicheckbox(sng, "Text", "Snap", "Value", true, "ValueChangedFcn", @(~,~) obj.onSnapChanged(), ...
    "Tooltip", "Arrange snaps a panel moved or resized to the other panels' edges and centers, the page's edges and " + ...
    "center and the step's grid (Alt held: no snapping). A preference, not part of the figure.");
uilabel(sng, "Text", "every");
E.snapStep = uieditfield(sng, "numeric", "Limits", [0 Inf], "LowerLimitInclusive", "off", "Value", 0.5, ...
    "ValueDisplayFormat", "%.10g", "ValueChangedFcn", @(~,~) obj.onSnapChanged(), ...
    "Tooltip", "The snap step: the grid Arrange snaps to, and how far an arrow key nudges the selected panel (Shift: " + ...
    "ten steps). In the Units above. A preference.");
E.snapUnits = uilabel(sng, "Text", "cm", "FontColor", gray);
[S, ~] = formSubheading(S, "", "");   % (closes the group: the line and the hint below belong to none)
[S, r] = formRow(S, "noPanel", "");
E.noPanel = uilabel(S.Body, "Text", "No panel yet: press New panel... to add one.", "FontColor", gray);
place(E.noPanel, r, [1 2]);
[S, r] = formRow(S, "arrangeHint", "", 34);
E.arrangeHint = uilabel(S.Body, "Text", "Arrange (over the preview) drags and resizes the panels; arrows nudge the " + ...
    "selected one by the snap step, Shift x10.", "FontColor", gray, "WordWrap", "on", "VerticalAlignment", "top");
place(E.arrangeHint, r, [1 2]);
sec(end+1) = S;

hPanel = superHeader(eg);   % the Panel supersection's header

% the selected panel (the section's key stays "panel")
S = formSection(eg, 4, "panel", "Panel", Color=tint("panel"));
[S, r] = formRow(S, "multiNote", "", 64);   % several panels selected (Shift+click): which, and what an edit does
E.multiNote = uilabel(S.Body, "Text", "", "WordWrap", "on", "FontWeight", "bold", "FontColor", [1 1 1], ...
    "BackgroundColor", EphysFigGenApp.SelectionColor, "VerticalAlignment", "center", "Tag", "multiPanelNote", ...
    "Tooltip", "Several panels are selected (Shift+click them in the preview, or their boxes in Arrange). The rows " + ...
    "show the settings every one of them has, with the first one's values; a setting you change goes to all of them. " + ...
    "Ctrl+Click one panel, or press Esc, to select one again.");
place(E.multiNote, r, [1 2]);
[S, r] = formRow(S, "panelType", "Type:");
E.panelType = uidropdown(S.Body, "Items", PT.Label, "ItemsData", PT.Type, "ValueChangedFcn", @(~,~) obj.onPanelTypeChanged(), ...
    "Tooltip", "The panel's type. A change starts its options afresh (keeping what both types share), drops the " + ...
    "layers the new type cannot draw and, when none is left, adds the type's default layer.");
place(E.panelType, r, 2);
[S, r] = formRow(S, "panelTitle", "Title:");
E.panelTitle = uieditfield(S.Body, "text", "Placeholder", "automatic", "ValueChangedFcn", changed, ...
    "Tooltip", "Blank: none (the top-left panel names the observation under a title of the figure's own). " + ...
    "Variables in braces, such as {Response} or {Line}, are filled in for each figure: the {x} button lists them." + symbolsTip);
place(E.panelTitle, r, 2);
% the panel's place on the page, in the Layout section's Units (showPanelPlace), and what to do with it
[S, r] = formRow(S, "selPanel", "Panel:");
E.selPanel = uilabel(S.Body, "Text", "", "FontWeight", "bold", ...
    "Tooltip", "The selected panel: its id, type, size and place (its bottom-left corner, from the page's), in the Units below.");
place(E.selPanel, r, 2);
[S, r] = formRow(S, "rectXY", "Position (x, y):");
xyg = subgrid(S.Body, r, {'1x', '1x', 44});
E.rectX = uieditfield(xyg, "numeric", "ValueDisplayFormat", "%.10g", "ValueChangedFcn", @(~,~) obj.onPanelRectEdited("x"), ...
    "Tooltip", "The selected panel's left edge, from the page's left edge (its plot area's or its outer box's: Boxes mean).");
E.rectY = uieditfield(xyg, "numeric", "ValueDisplayFormat", "%.10g", "ValueChangedFcn", @(~,~) obj.onPanelRectEdited("y"), ...
    "Tooltip", "The selected panel's bottom edge, from the page's bottom edge.");
E.rectXYUnits = uilabel(xyg, "Text", "cm", "FontColor", gray);
[S, r] = formRow(S, "rectWH", "Size (w, h):");
whg = subgrid(S.Body, r, {'1x', '1x', 44});
E.rectW = uieditfield(whg, "numeric", "ValueDisplayFormat", "%.10g", "ValueChangedFcn", @(~,~) obj.onPanelRectEdited("w"), ...
    "Tooltip", "The selected panel's width. Kept on the page: a panel never reaches past its right edge.");
E.rectH = uieditfield(whg, "numeric", "ValueDisplayFormat", "%.10g", "ValueChangedFcn", @(~,~) obj.onPanelRectEdited("h"), ...
    "Tooltip", "The selected panel's height. Kept on the page: a panel never reaches past its top edge.");
E.rectWHUnits = uilabel(whg, "Text", "cm", "FontColor", gray);
[S, r] = formRow(S, "panelButtons", "", 30);
pb = subgrid(S.Body, r, {'1x', '1x', '1x', '1x'});
place(pb, r, [1 2]);
E.setCorners = uibutton(pb, "Text", "Set corners", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onSetCorners(), ...
    "Tooltip", "Place the selected panel by two clicks on the preview: one corner, then the opposite one (snapped as " + ...
    "Arrange snaps). Arrange switches on for it; Esc cancels. On while the preview shows the figure.");
E.removePanel = uibutton(pb, "Text", "Remove panel", "ButtonPushedFcn", @(~,~) obj.onRemovePanel(), ...
    "Tooltip", "Remove the selected panel. The other panels keep their places; the space it held is left free.");
E.bringForward = uibutton(pb, "Text", "Bring forward", "ButtonPushedFcn", @(~,~) obj.onPanelOrder(1), ...
    "Tooltip", "Draw the selected panel after the next one: over it where the two overlap.");
E.sendBack = uibutton(pb, "Text", "Send back", "ButtonPushedFcn", @(~,~) obj.onPanelOrder(-1), ...
    "Tooltip", "Draw the selected panel before the one drawn before it: under it where the two overlap.");
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
    "Tooltip", "The layer's name in the legend and the aesthetics editor (blank: the unit's, channel's or event's label). " + ...
    "Variables in braces, such as ""{Unit} ({Response})"", are filled in for each figure: the {x} button lists them." + symbolsTip);
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
[S, r] = formRow(S, "layerUnitChannels", "On channels:");
E.layerUnitChannels = uieditfield(S.Body, "text", "Placeholder", "all", "ValueChangedFcn", changed, ...
    "Tooltip", "The recording channels whose units the layer keeps.");
place(E.layerUnitChannels, r, 2);
[S, r] = formRow(S, "layerChannels", "Signal channels:");
E.layerChannels = uieditfield(S.Body, "text", "Placeholder", "all, e.g. 3 5 8", "ValueChangedFcn", changed, ...
    "Tooltip", "The extract's columns the layer draws (blank = all).");
place(E.layerChannels, r, 2);
[S, r] = formRow(S, "layerAggregate", "Aggregate:");
E.layerAggregate = uidropdown(S.Body, "Items", ["each one" "their mean"], "ItemsData", ["each" "mean"], "ValueChangedFcn", changed, ...
    "Tooltip", "Several units or channels: a trace or block for each, or their mean with a band across them. On a " + ...
    "spectrum, spectrogram, coherence or phase coherence panel a signal's channels as one: their vector magnitude, sqrt(x² + y² + z²), " + ...
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
AlignControls.setSequenceHolder(E.evSeqText, struct('sequence', repmat(EphysAnalysisConfig.defaults("SequenceStep"), 1, 0), 'alignStep', Inf));
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
    "panel draws its lines its own way (its Display).");
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
% a trials layer's measures (the trial panels): their names, and Edit... opens the Trial measure window (trialMeasureDialog)
[S, r] = formRow(S, ["trMeasure" "trMeasureEdit"], "Trial measure:", 30);
tmg = subgrid(S.Body, r, {'1x', 70});
E.trMeasure = uilabel(tmg, "Text", "", "WordWrap", "on");
E.trMeasureEdit = uibutton(tmg, "Text", "Edit...", "ButtonPushedFcn", @(~,~) trialMeasureDialog(obj, "measure"), ...
    "Tooltip", "The number each trial gives (a scatter's y): the delay from an event to another, an interval's " + ...
    "duration, a count of events, or a trial parameter. Edit... opens the Trial measure window.");
[S, r] = formRow(S, ["trXMeasure" "trXMeasureEdit"], "Trial measure (x):", 30);
txg = subgrid(S.Body, r, {'1x', 70});
E.trXMeasure = uilabel(txg, "Text", "", "WordWrap", "on");
E.trXMeasureEdit = uibutton(txg, "Text", "Edit...", "ButtonPushedFcn", @(~,~) trialMeasureDialog(obj, "xMeasure"), ...
    "Tooltip", "A trial scatter's x: the number each trial gives on the x axis, paired with the Trial measure by trial. " + ...
    "Edit... opens the Trial measure window.");
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

% the panel's settings, in three sections by what an edit costs (rule R3 of the settings plan): Analysis holds what is computed
% (figureCompute reads it: an edit computes the figure again), Display what is only drawn (renderFigure: an edit redraws)
% and Axes what sets an axis (labels, sides, what shows, box, scales, limits, color scale). Every type's rows are built
% here and shown per type (syncFigureEditor); each section has Apply to all panels in its header (applyOptionsToAll).
grouping = ["trial groups" "a trial parameter" "session" "measure (layer)"];   % (the trial panels' Categories and Series)
binsTip = "The parameter's levels: blank = each value a level of its own; one whole number n = n equal-width bins; " + ...
    "two or more ascending values = the bins' edges, e.g. 0 100 200 500.";

% Analysis: bins, smoothing, measure, baseline (with its window and the auROC settings), normalization, the mask, the signal,
% the unit correlation's, the tuning curve's parameters, a heat map's rows, the probe map's color, the spectral panels'
% Chronux rows and the trial panels' groupings, bins, fit and correlation; then the Statistics: error, summary, tests
Sa = formSection(eg, 11, "analysis", "Analysis", Color=tint("analysis"));
E.optApplyAll = applyAllButton(obj, Sa, "analysis", "Copy this panel's Analysis rows (bins, smoothing, measure, baseline with " + ...
    "its window and auROC settings, mask, signal, error and the rest of what is computed) to every other panel that has them " + ...
    "(the baseline only where the type takes its mode), the others to the other panels of its type.");
% the signal panels' (continuous, heat map, spectral) filter: their signal layers' whole recording filtered before the
% epochs are cut (options.filter, kept in filterText's UserData: showPanelFilter; editPanelFilter opens FilterDialog)
[Sa, r] = formRow(Sa, ["filterText" "filterEdit"], "Filter:");
flg = subgrid(Sa.Body, r, {'1x', 70});
E.filterText = uilabel(flg, "Text", "none");
E.filterEdit = uibutton(flg, "Text", "Filter...", "ButtonPushedFcn", @(~,~) obj.editPanelFilter(), ...
    "Tooltip", "Filter the panel's signal layers (LFP, MUA, SPIKE, AUX) before anything is computed: an EEG band " + ...
    "(delta, theta, alpha, beta, low or high gamma), a line-noise notch, your own band or one you saved; zero-phase " + ...
    "or causal. Each channel's whole recording is filtered, then cut into epochs. Spike layers are not filtered.");
showPanelFilter(E, SignalFilter.defaults());
[Sa, r] = formRow(Sa, "binMs", "Bin width (ms):");
E.binMs = uieditfield(Sa.Body, "numeric", "Value", 10, "Limits", [0.001 Inf], "ValueChangedFcn", changed);
place(E.binMs, r, 2);
[Sa, r] = formRow(Sa, "smoothMs", "Smooth SD (ms):");
E.smoothMs = uieditfield(Sa.Body, "numeric", "Value", 10, "Limits", [0 Inf], "ValueChangedFcn", changed, "Tooltip", "Gaussian SD; 0 = none.");
place(E.smoothMs, r, 2);
[Sa, r] = formRow(Sa, "measure", "Measure:");
E.measure = uidropdown(Sa.Body, "Items", ["rate" "count" "probability"], "ValueChangedFcn", changed, ...
    "Tooltip", "rate: spikes/s; count: spikes per bin; probability: the share of epochs with a spike in the bin.");
place(E.measure, r, 2);
[Sa, r] = formRow(Sa, "baselineMode", "Baseline:");
E.baselineMode = uidropdown(Sa.Body, "Items", "none", "ValueChangedFcn", changed, ...
    "Tooltip", "subtract / zscore / percent / ratio: against the baseline window's value, epoch by epoch. auroc (PSTH, " + ...
    "heat map of spikes): each window's auROC against the baseline, 0.5 = no change, above = more firing (Cohen et " + ...
    "al. 2012; Macedo-Lima et al. 2024); its settings below.");
place(E.baselineMode, r, 2);
[Sa, r] = formRow(Sa, ["baseFrom" "baseTo"], "Baseline span (s):");
bg = subgrid(Sa.Body, r, {'1x', 'fit', '1x'});
E.baseFrom = uieditfield(bg, "numeric", "Value", -0.2, "ValueChangedFcn", changed, "Tooltip", "Baseline window start (s from the event).");
uilabel(bg, "Text", "to");
E.baseTo = uieditfield(bg, "numeric", "Value", 0, "ValueChangedFcn", changed, "Tooltip", "Baseline window end (s).");
[Sa, ~] = formSubheading(Sa, "auroc", "auROC", Collapsible=true, Callback=subToggle);
[Sa, E] = aurocRows(Sa, E, "au", changed, true);
[Sa, ~] = formSubheading(Sa, "", "");   % (closes the group: the rows below belong to none)
[Sa, r] = formRow(Sa, "normalize", "Normalize:");
E.normalize = uidropdown(Sa.Body, "Items", ["none" "across groups" "within groups" "across all"], "ItemsData", ["none" "unitPeak" "groupPeak" "allPeak"], ...
    "ValueChangedFcn", changed, "Tooltip", "Divide each unit's PSTHs by their largest peak (across groups), each PSTH " + ...
    "by its own (within groups), or every PSTH by the largest of all.");
place(E.normalize, r, 2);
[Sa, r] = formRow(Sa, "maskAfterStop", "");
E.maskAfterStop = uicheckbox(Sa.Body, "Text", "Mask after the stop event", "ValueChangedFcn", changed, ...
    "Tooltip", "Drop what follows each epoch's stop event (the Epoch window's).");
place(E.maskAfterStop, r, [1 2]);
[Sa, r] = formRow(Sa, ["statistic" "transform"], "Signal:");
tg = subgrid(Sa.Body, r, {'1x', '1x'});
E.statistic = uidropdown(tg, "Items", ["Mean" "Median"], "ItemsData", EphysAnalysisConfig.AuxStatistics, "ValueChangedFcn", changed, ...
    "Tooltip", "What is drawn at each sample, over the epochs of a group.");
E.transform = uidropdown(tg, "Items", ["As recorded" "Rectified |x|" "Vector magnitude"], "ItemsData", EphysAnalysisConfig.AuxTransforms, ...
    "ValueChangedFcn", changed, "Tooltip", "Rectified: each epoch's absolute value, before the mean or median. Vector " + ...
    "magnitude: each layer's channels as one trace, sqrt(x² + y² + z²) at every sample of each epoch, after the baseline " + ...
    "(subtract one to take out each axis's offset, e.g. gravity on an accelerometer), before the mean or median.");
[Sa, r] = formRow(Sa, "metric", "Epoch rate:");
E.metric = uidropdown(Sa.Body, "Items", ["mean" "peak"], "ValueChangedFcn", changed, ...
    "Tooltip", "Each epoch's mean rate over its window, or its peak binned rate.");
place(E.metric, r, 2);
[Sa, r] = formRow(Sa, "correlation", "Correlation:");
E.correlation = uidropdown(Sa.Body, "Items", ["Pearson" "Spearman"], "ItemsData", ["pearson" "spearman"], "ValueChangedFcn", changed);
place(E.correlation, r, 2);
[Sa, r] = formRow(Sa, "fisherZ", "");
E.fisherZ = uicheckbox(Sa.Body, "Text", "Fisher z transform", "ValueChangedFcn", changed, ...
    "Tooltip", "Draw z = atanh(r) instead of r.");
place(E.fisherZ, r, [1 2]);
[Sa, r] = formRow(Sa, "detrend", "");
E.detrend = uicheckbox(Sa.Body, "Text", "Detrend over the session", "ValueChangedFcn", changed, ...
    "Tooltip", "Subtract each unit's moving mean over about a fifth of the group's epochs before correlating, so a " + ...
    "slow drift both units share (anesthesia, adaptation) does not read as a correlation.");
place(E.detrend, r, [1 2]);
[Sa, r] = formRow(Sa, ["param" "seriesParam"], "Parameter:");
pg2 = subgrid(Sa.Body, r, {'1x', 'fit', '1x'});
E.param = uidropdown(pg2, "Editable", "on", "Items", "", "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "The trial parameter on the x axis. Blank: the figure's first group-by parameter, else the first numeric one.");
uilabel(pg2, "Text", "series:");
E.seriesParam = uidropdown(pg2, "Editable", "on", "Items", "", "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "One curve per value of this trial parameter (blank: one curve).");
[Sa, r] = formRow(Sa, "heatRows", "Rows:");
E.heatRows = uidropdown(Sa.Body, "Items", ["the layer's units or channels" "one unit's epochs (trials)"], ...
    "ItemsData", ["items" "trials"], "ValueChangedFcn", changed, "Tooltip", "Units or channels: a row each, one " + ...
    "trial group (Trial group drawn). Trials: a row per epoch of one unit (a layer following the observation, or fixed " + ...
    "to one unit), every group, sorted as a raster's rows (Sort rows by), the groups as a color strip at the left.");
place(E.heatRows, r, 2);
[Sa, r] = formRow(Sa, "order", "Row order:");
E.order = uidropdown(Sa.Body, "Items", ["probe" "peak" "modulation"], "ValueChangedFcn", changed, ...
    "Tooltip", "probe: the rows follow the sort options (Style); peak: by the time of each row's maximum; " + ...
    "modulation (the auROC baseline): by the mean auROC in the call window, highest first.");
place(E.order, r, 2);
[Sa, r] = formRow(Sa, "group", "Trial group drawn:");
E.group = uispinner(Sa.Body, "Limits", [1 100], "Step", 1, "Value", 1, "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "The trial group a heat map or a unit correlation map draws (1 = the first of the figure's groups).");
place(E.group, r, 2);
[Sa, r] = formRow(Sa, "value", "Color by:");
E.value = uidropdown(Sa.Body, "Items", ["rate" "nSpikes" "nUnits"], "ValueChangedFcn", changed, "Tooltip", ...
    "What colors each unit (rate, nSpikes) or each site (nUnits). Units drawn as waveforms (Waveform: Waveform) are " + ...
    "colored only with Color waveforms by value.");
place(E.value, r, 2);
% the spectral panels (spectrum, spectrogram, coherence, itpc): the Chronux tab's rows
[Sa, r] = formRow(Sa, "spTimeBase", "Time base:");
E.spTimeBase = uidropdown(Sa.Body, "Items", ["the panel's epochs" "segments of the recording"], "ItemsData", ["aligned" "range"], ...
    "ValueChangedFcn", changed, "Tooltip", "Epochs: the trials are the panel's epochs around its event, one result per " + ...
    "trial group. Segments: a stretch of the recording (Range) cut into back-to-back segments clear of the artifact " + ...
    "periods, all one group; the figure's event and window are not used.");
place(E.spTimeBase, r, 2);
[Sa, r] = formRow(Sa, ["spRangeFrom" "spRangeTo"], "Range (s):");
rg2 = subgrid(Sa.Body, r, {'1x', 'fit', '1x'});
E.spRangeFrom = uieditfield(rg2, "numeric", "Value", 0, "Limits", [0 Inf], "ValueChangedFcn", changed, ...
    "Tooltip", "Segments: the stretch's start, s on the recording's clock.");
uilabel(rg2, "Text", "to");
E.spRangeTo = uieditfield(rg2, "numeric", "Value", Inf, "Limits", [0 Inf], "ValueChangedFcn", changed, ...
    "Tooltip", "Segments: the stretch's end, s (Inf = the recording's end).");
[Sa, r] = formRow(Sa, "spSegment", "Segment (s):");
E.spSegment = uieditfield(Sa.Body, "numeric", "Value", 2, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "Segments: each one's length, s (a trial of the spectra).");
place(E.spSegment, r, 2);
[Sa, ~] = formSubheading(Sa, "tapers", "Tapers", Collapsible=true, Callback=subToggle);
[Sa, r] = formRow(Sa, "spTaperMode", "Tapers:");
E.spTaperMode = uidropdown(Sa.Body, "Items", ["TW and K" "W (Hz) and p"], "ItemsData", ["TWK" "Wp"], "ValueChangedFcn", changed, ...
    "Tooltip", "TW and K: the time-bandwidth product and the number of tapers as given. W and p: the half bandwidth " + ...
    "W Hz over the trial's (or moving window's) length T: tapers [W*T, 2*W*T - p].");
place(E.spTaperMode, r, 2);
[Sa, r] = formRow(Sa, ["spTW" "spK"], "TW, K:");
tk = subgrid(Sa.Body, r, {'1x', '1x'});
E.spTW = uieditfield(tk, "numeric", "Value", 3, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The time-bandwidth product TW.");
E.spK = uieditfield(tk, "numeric", "Value", 5, "Limits", [1 Inf], "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "The number of tapers K (at most 2TW - 1).");
[Sa, r] = formRow(Sa, ["spW" "spP"], "W (Hz), p:");
wp = subgrid(Sa.Body, r, {'1x', '1x'});
E.spW = uieditfield(wp, "numeric", "Value", 4, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The half bandwidth W, Hz.");
E.spP = uieditfield(wp, "numeric", "Value", 1, "Limits", [0 Inf], "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "p: the tapers are 2*W*T - p.");
[Sa, r] = formRow(Sa, "spPad", "Pad:");
E.spPad = uispinner(Sa.Body, "Limits", [-1 8], "Step", 1, "Value", 0, "RoundFractionalValues", "on", "ValueChangedFcn", changed, ...
    "Tooltip", "FFT padding: -1 none, 0 to the next power of 2, 1 to the one after, ...");
place(E.spPad, r, 2);
[Sa, ~] = formSubheading(Sa, "", "");   % (closes the group: the rows below belong to none)
[Sa, r] = formRow(Sa, ["spFmin" "spFmax"], "Frequency (Hz):");
fr = subgrid(Sa.Body, r, {'1x', 'fit', '1x'});
E.spFmin = uieditfield(fr, "numeric", "Value", 0, "Limits", [0 Inf], "ValueChangedFcn", changed, "Tooltip", "The lowest frequency, Hz.");
uilabel(fr, "Text", "to");
E.spFmax = uieditfield(fr, "numeric", "Value", 100, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The highest frequency, Hz (Inf = the Nyquist frequency).");
[Sa, r] = formRow(Sa, "spDetrend", "Detrend:");
E.spDetrend = uidropdown(Sa.Body, "Items", ["none" "constant (the mean)" "linear"], "ItemsData", ["none" "constant" "linear"], ...
    "ValueChangedFcn", changed, "Tooltip", "Removed from each trial before the spectra.");
place(E.spDetrend, r, 2);
[Sa, r] = formRow(Sa, "spSpikeFs", "Sampling (Hz):");
E.spSpikeFs = uieditfield(Sa.Body, "numeric", "Value", 1000, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "Spike trains: the rate of the time grid their spectra are computed on.");
place(E.spSpikeFs, r, 2);
[Sa, r] = formRow(Sa, "spOverTime", "");
E.spOverTime = uicheckbox(Sa.Body, "Text", "Over time (a coherogram)", "ValueChangedFcn", changed, ...
    "Tooltip", "The coherence over the moving window, an image over time and frequency (on the epochs, on the " + ...
    "figure's time axis), of the first pair and the group shown: signals, spike trains, or one of each. A phase " + ...
    "coherence (ITPC) panel: the first channel's ITPC over time and frequency.");
place(E.spOverTime, r, [1 2]);
[Sa, r] = formRow(Sa, ["spWin" "spStep"], "Moving window (s):");
mw = subgrid(Sa.Body, r, {'1x', 'fit', '1x'});
E.spWin = uieditfield(mw, "numeric", "Value", 0.5, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "Each spectrum's window, s.");
uilabel(mw, "Text", "step:");
E.spStep = uieditfield(mw, "numeric", "Value", 0.05, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The window's step, s.");
% the trial panels (trial distribution, histogram, scatter): one value per trial, grouped (TrialGroupings), summarized,
% tested and drawn; the Error row above is their summary's error
[Sa, r] = formRow(Sa, ["trCategories" "trCategoryParam" "trCategoryBins"], "Categories:");
cag = subgrid(Sa.Body, r, {'1x', '1x', 64});
E.trCategories = uidropdown(cag, "Items", grouping, "ItemsData", EphysAnalysisConfig.TrialGroupings, "Value", "groups", ...
    "ValueChangedFcn", changed, "Tooltip", "The x axis of a trial distribution: a category per trial group (the " + ...
    "figure's trial selection, or the panel's own), per level of a trial parameter (named beside it), per session " + ...
    "(a figure across sessions) or per layer (each layer's measure). The series must group by something else.");
E.trCategoryParam = uidropdown(cag, "Editable", "on", "Items", "", "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "Categories by a trial parameter: the parameter (a trial column of the dataset).");
E.trCategoryBins = uieditfield(cag, "text", "Placeholder", "each", "ValueChangedFcn", changed, "Tooltip", binsTip);
[Sa, r] = formRow(Sa, ["trSeries" "trSeriesParam" "trSeriesBins"], "Series:");
seg2 = subgrid(Sa.Body, r, {'1x', '1x', 64});
E.trSeries = uidropdown(seg2, "Items", grouping, "ItemsData", EphysAnalysisConfig.TrialGroupings, "Value", "layer", ...
    "ValueChangedFcn", changed, "Tooltip", "The colors: a series per trial group, per level of a trial parameter " + ...
    "(named beside it), per session or per layer. A distribution draws the series side by side in each category, a " + ...
    "histogram a histogram per series, a scatter a color (and a fit) per series.");
E.trSeriesParam = uidropdown(seg2, "Editable", "on", "Items", "", "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "Series by a trial parameter: the parameter (a trial column of the dataset).");
E.trSeriesBins = uieditfield(seg2, "text", "Placeholder", "each", "ValueChangedFcn", changed, "Tooltip", binsTip);
[Sa, r] = formRow(Sa, ["trBins" "trBinCount" "trBinWidth"], "Bins:");
tbg = subgrid(Sa.Body, r, {'1x', 60, 'fit', 64});
E.trBins = uidropdown(tbg, "Items", ["automatic" "a count" "a width"], "ItemsData", ["auto" "count" "width"], ...
    "ValueChangedFcn", changed, "Tooltip", "The bins, one set for every series: chosen from the data, this many, or " + ...
    "this wide (in the measure's unit). A log x axis takes log-spaced bins.");
E.trBinCount = uispinner(tbg, "Limits", [1 1000], "Step", 1, "RoundFractionalValues", "on", "Value", 20, ...
    "ValueChangedFcn", changed, "Tooltip", "Bins: a count: how many.");
uilabel(tbg, "Text", "width:");
E.trBinWidth = uieditfield(tbg, "numeric", "Limits", [0 Inf], "LowerLimitInclusive", "off", "Value", 10, ...
    "ValueChangedFcn", changed, "Tooltip", "Bins: a width: the bin width, in the measure's unit.");
[Sa, r] = formRow(Sa, ["trFit" "trFitBand" "trFitWindow"], "Fit:");
tfg = subgrid(Sa.Body, r, {'1x', 'fit', 'fit', 56});
E.trFit = uidropdown(tfg, "Items", ["none" "a line" "a quadratic" "a cubic" "a moving mean" "a moving median"], ...
    "ItemsData", EphysAnalysisConfig.TrialFits, "ValueChangedFcn", changed, "Tooltip", "A fit per series, made in the " + ...
    "scales drawn (a log axis: in log10 units): a polynomial (least squares) or a moving mean or median over the " + ...
    "points in x order.");
E.trFitBand = uicheckbox(tfg, "Text", "95% band", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "A line or polynomial fit: its 95% confidence band.");
uilabel(tfg, "Text", "window:");
E.trFitWindow = uispinner(tfg, "Limits", [2 1e6], "Step", 1, "RoundFractionalValues", "on", "Value", 10, ...
    "ValueChangedFcn", changed, "Tooltip", "A moving mean or median: the window, a number of points (at least 2).");
[Sa, r] = formRow(Sa, "trCorr", "Correlation:");
E.trCorr = uidropdown(Sa.Body, "Items", ["Pearson" "Spearman" "none"], "ItemsData", ["pearson" "spearman" "none"], ...
    "ValueChangedFcn", changed, "Tooltip", "Each series' correlation of y with x, with its p, in the legend and the caption.");
place(E.trCorr, r, 2);
[Sa, ~] = formSubheading(Sa, "statistics", "Statistics");
[Sa, r] = formRow(Sa, "trSummary", "Summary:");
E.trSummary = uidropdown(Sa.Body, "Items", ["mean" "median"], "ValueChangedFcn", changed, "Tooltip", "The summary of each " + ...
    "category's (or series') values, with the error in the Error row: the mark over a swarm, the line display's " + ...
    "points, a histogram's dotted line, and the figure's caption.");
place(E.trSummary, r, 2);
% the panel's own error: a PSTH's or continuous signal's band, a firing rate or tuning panel's error bars (its items
% per type: errorTypeItems), and the bands' look
[Sa, r] = formRow(Sa, ["errorType" "errResamples"], "Error:");
erg = subgrid(Sa.Body, r, {'1x', 'fit', 70});
E.errorType = uidropdown(erg, "Items", ["Off" "mean ± SEM" "mean ± SD" "bootstrap 95% CI" "interquartile range"], ...
    "ItemsData", EphysAnalysisConfig.AuxErrorTypes, "ValueChangedFcn", changed, ...
    "Tooltip", "The error over the epochs: a PSTH's or continuous signal's band around each trace, a firing rate " + ...
    "panel's error bars (Draw as: bars) or a tuning curve's; a trial panel's summary (its mark, its line, the " + ...
    "caption). Off: none. The bootstrap and the interquartile range (a continuous signal's, a trial panel's) need " + ...
    "the Statistics and Machine Learning Toolbox.");
uilabel(erg, "Text", "resamples:");
E.errResamples = uispinner(erg, "Limits", [1 1e6], "Step", 500, "Value", 1000, "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "Bootstrap 95% CI: how many resamples.");
[Sa, r] = formRow(Sa, ["spErr" "spErrP"], "Error:");
er = subgrid(Sa.Body, r, {'1x', 'fit', 60});
E.spErr = uidropdown(er, "Items", ["Off" "theoretical" "jackknife"], "ItemsData", ["none" "theoretical" "jackknife"], "ValueChangedFcn", changed, ...
    "Tooltip", "The error bars: Off; theoretical; jackknife (over the trials). A coherence's confidence level " + ...
    "needs either; its band, jackknife. A phase coherence (ITPC) panel: theoretical draws the level random " + ...
    "phases stay under; jackknife that level and the band.");
uilabel(er, "Text", "p-value:");
E.spErrP = uieditfield(er, "numeric", "Value", 0.05, "Limits", [0 1], "LowerLimitInclusive", "off", "UpperLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "The bars' and the level's p (0.05: 95%).");
[Sa, r] = formRow(Sa, ["trTest" "trPairs"], "Test:");
tsg = subgrid(Sa.Body, r, {'1x', '1x'});
E.trTest = uidropdown(tsg, "Items", ["auto (rank-sum for 2, Kruskal-Wallis for more)" "none" "Wilcoxon rank-sum" ...
    "t-test" "Kruskal-Wallis" "one-way ANOVA"], "ItemsData", EphysAnalysisConfig.TrialTests, "ValueChangedFcn", changed, ...
    "Tooltip", "The group test, across the categories in each series (one category: across the series; a scatter: " + ...
    "y across the series), then each pair compared with the same kind of test. Needs the Statistics and Machine " + ...
    "Learning Toolbox; none: no test.");
E.trPairs = uidropdown(tsg, "Items", ["all pairs" "each against the first"], "ItemsData", ["all" "first"], ...
    "ValueChangedFcn", changed, "Tooltip", "The pairs compared after the group test: every pair, or each category " + ...
    "against the first.");
[Sa, r] = formRow(Sa, ["trAdjust" "trAlpha"], "P adjustment:");
adg = subgrid(Sa.Body, r, {'1x', 'fit', 64});
E.trAdjust = uidropdown(adg, "Items", ["Holm" "Benjamini-Hochberg" "Bonferroni" "none"], "ItemsData", ["holm" "bh" "bonferroni" "none"], ...
    "ValueChangedFcn", changed, "Tooltip", "How the pairs' p values are adjusted for the number of pairs (pAdjust).");
uilabel(adg, "Text", "alpha:");
E.trAlpha = uieditfield(adg, "numeric", "Limits", [0 1], "LowerLimitInclusive", "off", "UpperLimitInclusive", "off", ...
    "Value", 0.05, "ValueChangedFcn", changed, "Tooltip", "The significance level (0.05): a pair whose adjusted p is below it counts as significant (its bracket is drawn; the stars themselves mark 0.05, 0.01 and 0.001).");
sec(end+1) = Sa;

% Display: how the computed data are drawn (trace or heat map, fill, stack, marks, raster ticks, bands, the event traces' and
% trial panels' looks, a legend's entries, the probe map's labels)
Sd = formSection(eg, 20, "display", "Display", Color=tint("display"));
E.dispApplyAll = applyAllButton(obj, Sd, "display", "Copy this panel's Display rows (and the Waveform section's inset) to every " + ...
    "other panel of its type; the stack to every other panel whose type takes it.");
[Sd, r] = formRow(Sd, "psthDisplay", "Draw as:");
E.psthDisplay = uidropdown(Sd.Body, "Items", ["trace (bars or a line per group)" "heat map (a row per group)"], ...
    "ItemsData", ["trace" "heatmap"], "ValueChangedFcn", changed, "Tooltip", "Trace: each trial group's PSTH as bars " + ...
    "or a line (Trace). Heat map: the unit's PSTH as an image, a row per trial group (the first on top), colored by " + ...
    "its rate on this unit's own range (Colormap, Color limits); with several units or layers, the first is drawn.");
place(E.psthDisplay, r, 2);
[Sd, r] = formRow(Sd, "histStyle", "Trace:");
E.histStyle = uidropdown(Sd.Body, "Items", ["bar" "line"], "ValueChangedFcn", changed, "Tooltip", "One bar per bin, or a line through the bin centers.");
place(E.histStyle, r, 2);
[Sd, r] = formRow(Sd, ["fill" "fillAlpha"], "Fill:");
fg = subgrid(Sd.Body, r, {'fit', 'fit', '1x'});
E.fill = uicheckbox(fg, "Text", "Filled", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Fill the bars, or the area under the line.");
uilabel(fg, "Text", "opacity:");
E.fillAlpha = uieditfield(fg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "auto", "Limits", [0 1], ...
    "ValueChangedFcn", changed, "Tooltip", "Fill opacity, 0 to 1 (blank: 0.5 where groups overlap, else 1).");
[Sd, r] = formRow(Sd, ["smoothLine" "smoothLineMs" "smoothLineLegend"], "Smoothed line:");
sg = subgrid(Sd.Body, r, {'fit', 'fit', '1x', 'fit'});
E.smoothLine = uicheckbox(sg, "Text", "Draw", "Value", false, "ValueChangedFcn", changed, "Tooltip", ...
    "A line over each group's PSTH: the PSTH smoothed on its own, by a Gaussian of the SD at the right over the " + ...
    "unsmoothed bins. Smooth SD (ms) smooths the histogram only, so neither changes the other.");
uilabel(sg, "Text", "SD (ms):");
E.smoothLineMs = uieditfield(sg, "numeric", "Value", 25, "Limits", [0 Inf], "ValueChangedFcn", changed, "Tooltip", ...
    "The smoothed line's Gaussian SD, ms (0: the unsmoothed PSTH as a line). A change redraws the plot without " + ...
    "computing it again.");
E.smoothLineLegend = uicheckbox(sg, "Text", "Legend", "Value", true, "ValueChangedFcn", changed, "Tooltip", ...
    "Show the smoothed line in the legend (""Smoothed (SD 25 ms)""), or leave it out.");
[Sd, r] = formRow(Sd, ["stack" "stackSpacing"], "Stack:");
sk = subgrid(Sd.Body, r, {'1x', 'fit', 60});
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
[Sd, r] = formRow(Sd, "onsetLine", "Onset line:");
E.onsetLine = uidropdown(Sd.Body, "Items", ["Off" "One line (every epoch)" "A line per trial group"], ...
    "ItemsData", EphysAnalysisConfig.OnsetLines, "Value", "off", "ValueChangedFcn", changed, "Tooltip", ...
    "The unit's response onset, a dashed line: where its PSTH's CUSUM rises past the threshold and stays up (the " + ...
    "figure's First-spike latency section: window, baseline, onset bins and threshold). One over every epoch, or " + ...
    "each trial group's in its color.");
place(E.onsetLine, r, 2);
[Sd, r] = formRow(Sd, "trialCount", "Trial count:");
E.trialCount = uidropdown(Sd.Body, "Items", ["Off" "Text in the plot (n = 24)" "In the legend entries"], "ItemsData", ["off" "text" "legend"], ...
    "ValueChangedFcn", changed, "Tooltip", "How many trials each group has: written in the group's color in the plot " + ...
    "(top left; stacked and heat map: at the right end of each row), or after the group's name in the legend " + ...
    "(a heat map: in the row's label). A single group has no legend entry: it gets the text.");
place(E.trialCount, r, 2);
[Sd, r] = formRow(Sd, ["firstSpike" "firstSpikeDialog"], "First-spike marks:", 30);
fsg = subgrid(Sd.Body, r, {'1x', 'fit'});
E.firstSpike = uilabel(fsg, "Text", "off", "Tooltip", "The first-spike latency marks: on or off, and the mark. How " + ...
    "the latency is found is the figure's (First-spike latency section).");
E.firstSpikeDialog = uibutton(fsg, "Text", "First-spike marks...", "ButtonPushedFcn", @(~,~) latencyDialog(obj, "firstSpike"), ...
    "Tooltip", "Mark each epoch's first-spike latency (the figure's: its First-spike latency section finds it) on " + ...
    "its row, over the ticks: the marker, its size and color (each group's or one), filled or not.");
[Sd, r] = formRow(Sd, ["latencyBox" "latencyBoxDialog"], "Latency box plot:", 30);
lbg = subgrid(Sd.Body, r, {'1x', 'fit'});
E.latencyBox = uilabel(lbg, "Text", "off", "Tooltip", "The box plot of the first-spike latencies: on or off, and its " + ...
    "color. How the latencies are found is the figure's (First-spike latency section).");
E.latencyBoxDialog = uibutton(lbg, "Text", "Latency box plot...", "ButtonPushedFcn", @(~,~) latencyDialog(obj, "latencyBox"), ...
    "Tooltip", "A box plot of each epoch's first-spike latency (the figure's) per trial group (median, quartiles, " + ...
    "whiskers to 1.5 IQR, outliers) in a band above the traces (stacked: in each row): its color, line, box height, " + ...
    "fill and outliers.");
[Sd, r] = formRow(Sd, ["errFace" "errAlpha"], "Band fill:");
bfg = subgrid(Sd.Body, r, {'1x', 'fit', 60});
E.errFace = uidropdown(bfg, "Editable", "on", "Items", ["auto" "gray" "black" "white" "#d9d9d9"], "Value", "auto", ...
    "ValueChangedFcn", changed, "Tooltip", "The fill of the panel's error bands (a waveform's too): auto, the " + ...
    "trace's color; or one color for every band (a name or #RRGGBB).");
uilabel(bfg, "Text", "opacity");
E.errAlpha = uieditfield(bfg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "opaque", "Limits", [0 1], ...
    "ValueChangedFcn", changed, "Tooltip", "Blank: opaque, paled towards the ground. 0 to 1: that opacity.");
[Sd, r] = formRow(Sd, ["errEdge" "errEdgeStyle"], "Band edge:");
beg = subgrid(Sd.Body, r, {'1x', '1x', 60});
E.errEdge = uidropdown(beg, "Editable", "on", "Items", ["none" "auto" "black" "gray"], "Value", "none", ...
    "ValueChangedFcn", changed, "Tooltip", "none: no outline; auto: the fill's color; or a color.");
E.errEdgeStyle = uidropdown(beg, "Items", ["solid" "dashed" "dotted" "dash-dot"], "ItemsData", EphysAnalysisConfig.OverlayLineStyles, ...
    "Value", "-", "ValueChangedFcn", changed, "Tooltip", "The outline's line style.");
E.errEdgeWidth = uispinner(beg, "Limits", [0.1 6], "Step", 0.25, "Value", 0.5, "ValueChangedFcn", changed, ...
    "Tooltip", "The outline's width, points.");
[Sd, r] = formRow(Sd, ["rasterSort" "rasterSortOrder"], "Sort rows by:");
rsg = subgrid(Sd.Body, r, {'1x', 110});
E.rasterSort = uidropdown(rsg, "Editable", "on", "Items", ["" "stop" "event" "latency"], "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "The order of the raster's epochs: blank = trial (time) order; stop = the stop event's latency; " + ...
    "event = the latency of the sort event below; latency = the first spike's latency (a raster: in the first-spike latency " + ...
    "window, else from the event to the window's end; none in the window = last); or a trial parameter. Missing values go last.");
E.rasterSortOrder = uidropdown(rsg, "Items", ["ascending" "descending"], "ValueChangedFcn", changed, ...
    "Tooltip", "The sort's direction. Missing values stay last.");
[Sd, r] = formRow(Sd, ["sortLine" "sortEdge"], "Sort event:");
seg = subgrid(Sd.Body, r, {'1x', 80});
E.sortLine = uidropdown(seg, "Editable", "on", "Items", "", "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "Sort rows by ""event"": the line whose event orders the rows by its latency from each epoch's event.");
E.sortEdge = uidropdown(seg, "Items", ["onset" "offset"], "ValueChangedFcn", changed, "Tooltip", "The sort event's edge.");
[Sd, r] = formRow(Sd, ["sortSeqText" "sortSeqEdit"], "Sort sequence:");
ssg = subgrid(Sd.Body, r, {'1x', 70});
E.sortSeqText = uilabel(ssg, "Text", "none");
AlignControls.setSequenceHolder(E.sortSeqText, struct('sequence', repmat(EphysAnalysisConfig.defaults("SequenceStep"), 1, 0), 'alignStep', Inf));
E.sortSeqEdit = uibutton(ssg, "Text", "Edit...", "Tooltip", "Events that must follow the sort event's line.");
E.sortSeqEdit.ButtonPushedFcn = @(~,~) obj.editSequence(E.sortSeqText, E.sortLine, E.sortEdge, @() obj.onConfigChanged("figure", "Sort sequence"));
[Sd, r] = formRow(Sd, "rasterByGroup", "");
E.rasterByGroup = uicheckbox(Sd.Body, "Text", "Rows by group first", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Ticked: each group's epochs together. Unticked: every epoch sorted as one block.");
place(E.rasterByGroup, r, [1 2]);
[Sd, r] = formRow(Sd, "yTicks", "");
E.yTicks = uicheckbox(Sd.Body, "Text", "Show y ticks", "ValueChangedFcn", changed, ...
    "Tooltip", "Ticked: the y axis keeps its tick marks and epoch numbers. Unticked (the default): none; the y label stays, " + ...
    "and so do the names of a raster's further blocks.");
place(E.yTicks, r, [1 2]);
[Sd, r] = formRow(Sd, "tickColor", "Tick color:");
E.tickColor = uidropdown(Sd.Body, "Editable", "on", "Items", ["groups" "black" "white" "gray" "red" "blue" "#ff7f0e"], "Value", "groups", ...
    "ValueChangedFcn", changed, "Tooltip", "The color of the ticks: groups = each group's color (as the PSTH's traces); " + ...
    "or a color name or #RRGGBB for every tick. A layer's own Color wins.");
place(E.tickColor, r, 2);
[Sd, r] = formRow(Sd, "backColor", "Row bands:");
E.backColor = uidropdown(Sd.Body, "Editable", "on", "Items", ["none" "groups" "white" "black" "gray" "#f0f0f0" "#fffbe6"], "Value", "none", ...
    "ValueChangedFcn", changed, "Tooltip", "Bands behind the rows: none; groups = each group's pale band; or a color " + ...
    "name or #RRGGBB, the same for every group.");
place(E.backColor, r, 2);
[Sd, r] = formRow(Sd, "tickWidth", "Tick width:");
E.tickWidth = uispinner(Sd.Body, "Limits", [0 12], "Step", 0.25, "Value", 0, "ValueChangedFcn", changed, ...
    "Tooltip", "The ticks' line width in points; 0 = the plot design's width.");
place(E.tickWidth, r, 2);
[Sd, r] = formRow(Sd, ["contTrials" "maxTrials"], "Single trials:");
tg2 = subgrid(Sd.Body, r, {'1x', 'fit', 70});
E.contTrials = uidropdown(tg2, "Items", ["Off" "Faint, behind the mean" "Only the trials"], "ItemsData", ["off" "faint" "only"], ...
    "ValueChangedFcn", changed, "Tooltip", "Each epoch's trace: off; faint (pale and thin, behind the mean and its " + ...
    "band); or only the traces, without the mean.");
uilabel(tg2, "Text", "at most:");
E.maxTrials = uieditfield(tg2, "numeric", "Value", 100, "Limits", [1 Inf], "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "The most epochs drawn, picked evenly over their order (default 100; Inf = every one).");
[Sd, r] = formRow(Sd, "rateDisplay", "Draw as:");
E.rateDisplay = uidropdown(Sd.Body, "Items", ["bars (mean, error bar)" "boxes" "points (each epoch)"], ...
    "ItemsData", ["bar" "box" "points"], "ValueChangedFcn", changed, "Tooltip", "Per trial group along x: the mean " + ...
    "with its error bar, a box of the epochs' rates, or each epoch's rate as a dot over a bar of their mean (a " + ...
    "layer's mean over units: of the units' means).");
place(E.rateDisplay, r, 2);
[Sd, r] = formRow(Sd, "waveLayout", "Layout:");
E.waveLayout = uidropdown(Sd.Body, "Items", ["grid (the unit, or several overlaid)" "probe (every unit at its place)"], ...
    "ItemsData", ["grid" "probe"], "ValueChangedFcn", changed, "Tooltip", "Probe: every unit of the first layer drawn " + ...
    "at its place on the probe (bind that layer to fixed units); a further layer, e.g. one following the observed " + ...
    "unit, is framed in red there.");
place(E.waveLayout, r, 2);
[Sd, r] = formRow(Sd, "spScale", "Power scale:");
E.spScale = uidropdown(Sd.Body, "Items", ["dB (10 log10)" "log axis" "linear"], "ItemsData", ["db" "log" "linear"], ...
    "ValueChangedFcn", changed, "Tooltip", "The power drawn: in dB, on a log axis, or as is (a spectrogram: dB or as is).");
place(E.spScale, r, 2);
[Sd, r] = formRow(Sd, "spShowPhase", "");
E.spShowPhase = uicheckbox(Sd.Body, "Text", "Show phase (under the magnitude)", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "The phase at the frequencies where the coherence is over its confidence level, in a strip under it.");
place(E.spShowPhase, r, [1 2]);
% the event-trace panel: a row per line, its intervals as bars or a logic level
[Sd, r] = formRow(Sd, "etDisplay", "Draw as:");
E.etDisplay = uidropdown(Sd.Body, "Items", ["solid bars (onset to offset)" "a logic level (a line)"], "ItemsData", ["bars" "line"], ...
    "ValueChangedFcn", changed, "Tooltip", "Bars: a solid bar from each onset to its offset. A logic level: a line " + ...
    "that is low, rises at each onset and falls at its offset. Intervals that start before or end after the window " + ...
    "are drawn to its edge.");
place(E.etDisplay, r, 2);
[Sd, r] = formRow(Sd, ["etTrials" "etGroupBands"], "Single trials:");
etg = subgrid(Sd.Body, r, {'1x', 'fit'});
E.etTrials = uidropdown(etg, "Items", ["every epoch overlaid in the line's row" "a sub-row per epoch"], "ItemsData", ["overlay" "rows"], ...
    "ValueChangedFcn", changed, "Tooltip", "Overlaid: every epoch drawn in the line's row, translucent, so the " + ...
    "spread of the timing shows. A sub-row per epoch: each epoch in a sub-row of its own inside the line's row, " + ...
    "sorted as a raster's rows (Sort rows by; by default by trial group and then time).");
E.etGroupBands = uicheckbox(etg, "Text", "group bands", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "A sub-row per epoch: a pale band of each trial group's color behind its sub-rows.");
[Sd, r] = formRow(Sd, "etColorBy", "Color by:");
E.etColorBy = uidropdown(Sd.Body, "Items", ["line (the layer's color, else a palette color)" "trial group"], "ItemsData", ["layer" "group"], ...
    "ValueChangedFcn", changed, "Tooltip", "Line: each line in its layer's Color (Layers), or a color of the " + ...
    "design's palette. Trial group: each epoch in its group's color, the groups in the legend.");
place(E.etColorBy, r, 2);
[Sd, r] = formRow(Sd, ["etHeight" "etAlpha"], "Height:");
ehg = subgrid(Sd.Body, r, {'1x', 'fit', 60});
E.etHeight = uispinner(ehg, "Limits", [0.05 1], "Step", 0.05, "Value", 0.6, "ValueChangedFcn", changed, ...
    "Tooltip", "The bars' (or the level's) height, a share of the line's row (a sub-row per epoch: of the epoch's sub-row).");
uilabel(ehg, "Text", "opacity:");
E.etAlpha = uieditfield(ehg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "auto", "Limits", [0 1], ...
    "ValueChangedFcn", changed, "Tooltip", "The bars' and lines' opacity, 0 to 1 (blank: 0.3 overlaid, 1 in sub-rows).");
[Sd, r] = formRow(Sd, ["etEdge" "etEdgeWidth"], "Bar outline:");
eeg = subgrid(Sd.Body, r, {'1x', 'fit', 60});
E.etEdge = uidropdown(eeg, "Editable", "on", "Items", ["none" "auto" "black" "white" "gray"], "Value", "none", ...
    "ValueChangedFcn", changed, "Tooltip", "none: no outline; auto: the bar's own color; or a name or #RRGGBB.");
uilabel(eeg, "Text", "width");
E.etEdgeWidth = uispinner(eeg, "Limits", [0.25 12], "Step", 0.25, "Value", 0.5, "ValueChangedFcn", changed, ...
    "Tooltip", "The outline's width, points.");
[Sd, r] = formRow(Sd, "etMinWidth", "Narrowest bar:");
E.etMinWidth = uispinner(Sd.Body, "Limits", [0 12], "Step", 0.25, "Value", 1, "ValueChangedFcn", changed, ...
    "Tooltip", "Points. A bar drawn narrower than this (a zero-length interval too) also gets a tick this wide " + ...
    "through its middle, in its color, so a short interval shows at any size and in exported files. 0: no tick.");
place(E.etMinWidth, r, 2);
[Sd, r] = formRow(Sd, ["etLineStyle" "etLineWidth"], "Level line:");
elg = subgrid(Sd.Body, r, {'1x', 'fit', 60});
E.etLineStyle = uidropdown(elg, "Items", ["solid" "dashed" "dotted" "dash-dot"], "ItemsData", EphysAnalysisConfig.OverlayLineStyles, ...
    "Value", "-", "ValueChangedFcn", changed, "Tooltip", "The logic level's style (a layer's own Line style wins).");
uilabel(elg, "Text", "width");
E.etLineWidth = uispinner(elg, "Limits", [0.25 12], "Step", 0.25, "Value", 1.5, "ValueChangedFcn", changed, ...
    "Tooltip", "The logic level's width, points.");
[Sd, r] = formRow(Sd, ["etBaseline" "etBaseColor"], "Row line:");
ebg = subgrid(Sd.Body, r, {'fit', '1x'});
E.etBaseline = uicheckbox(ebg, "Text", "Draw", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "A line along each row: through the middle of the bars, or at the logic level's low (zero) level.");
E.etBaseColor = uidropdown(ebg, "Editable", "on", "Items", ["auto" "gray" "black" "white" "#bbbbbb"], "Value", "auto", ...
    "ValueChangedFcn", changed, "Tooltip", "auto: gray; or a name or #RRGGBB.");
[Sd, r] = formRow(Sd, ["etBaseStyle" "etBaseWidth"], "Row line style:");
ebs = subgrid(Sd.Body, r, {'1x', 'fit', 60});
E.etBaseStyle = uidropdown(ebs, "Items", ["solid" "dashed" "dotted" "dash-dot"], "ItemsData", EphysAnalysisConfig.OverlayLineStyles, ...
    "Value", ":", "ValueChangedFcn", changed, "Tooltip", "The baseline's style.");
uilabel(ebs, "Text", "width");
E.etBaseWidth = uispinner(ebs, "Limits", [0.25 12], "Step", 0.25, "Value", 0.5, "ValueChangedFcn", changed, ...
    "Tooltip", "The baseline's width, points.");
[Sd, r] = formRow(Sd, "etRowSpacing", "Row spacing:");
E.etRowSpacing = uieditfield(Sd.Body, "numeric", "Value", 1.25, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", changed, "Tooltip", "The step from one line's row to the next, in row heights (1: the rows touch; more leaves a gap).");
place(E.etRowSpacing, r, 2);
[Sd, r] = formRow(Sd, ["trDisplay" "trOrdinalX"], "Draw as:");
tdg = subgrid(Sd.Body, r, {'1x', 'fit'});
E.trDisplay = uidropdown(tdg, "Items", ["swarm" "box" "violin" "points (jittered)" "line (the summary per category)"], ...
    "ItemsData", ["swarm" "box" "violin" "points" "line"], "ValueChangedFcn", changed, "Tooltip", "How each category's " + ...
    "values are drawn: a swarm of points, a box plot, a violin (its density), jittered points, or the summary with " + ...
    "its error, a line per series.");
E.trOrdinalX = uicheckbox(tdg, "Text", "x at values", "ValueChangedFcn", changed, "Tooltip", "Points or a line: " + ...
    "numeric categories (a parameter's levels) at their values on the x axis, not evenly spaced.");
[Sd, r] = formRow(Sd, ["trHistDisplay" "trNormalization"], "Draw as:");
thg = subgrid(Sd.Body, r, {'1x', '1x'});
E.trHistDisplay = uidropdown(thg, "Items", ["bars" "an outline" "the cumulative distribution (ECDF)"], ...
    "ItemsData", ["bars" "outline" "ecdf"], "ValueChangedFcn", changed, "Tooltip", "A histogram per series as bars, " + ...
    "as an outline (steps), or the empirical cumulative distribution.");
E.trNormalization = uidropdown(thg, "Items", ["count" "probability" "density (pdf)"], "ItemsData", ["count" "probability" "pdf"], ...
    "ValueChangedFcn", changed, "Tooltip", "Bars or an outline: the trials in each bin, their share of the series, " + ...
    "or the density (the share over the bin's width).");
[Sd, r] = formRow(Sd, ["trMarker" "trJitter"], "Points:");
tpg = subgrid(Sd.Body, r, {'1x', 'fit', 64});
E.trMarker = uispinner(tpg, "Limits", [0.5 60], "Step", 1, "Value", 4, "ValueChangedFcn", changed, ...
    "Tooltip", "The points' size, points.");
uilabel(tpg, "Text", "jitter:");
E.trJitter = uispinner(tpg, "Limits", [0 1], "Step", 0.05, "Value", 0.3, "ValueChangedFcn", changed, ...
    "Tooltip", "Draw as: points: how far the points spread sideways, a share of the category's slot (0 to 1).");
[Sd, r] = formRow(Sd, ["trShowSummary" "trShowN"], "Also show:");
tng = subgrid(Sd.Body, r, {'fit', 'fit'});
tng.ColumnSpacing = 12;
E.trShowSummary = uicheckbox(tng, "Text", "the summary", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "A distribution drawn as a swarm, points or violin: the summary mark with its error over the values. " + ...
    "A histogram: a dotted line at each series' summary.");
E.trShowN = uicheckbox(tng, "Text", "n in the tick labels", "ValueChangedFcn", changed, ...
    "Tooltip", "Each category's trial count in its tick label: ""Hit (n = 12)"".");
[Sd, r] = formRow(Sd, ["trTestShow" "trBracketPairs"], "Show tests:");
twg = subgrid(Sd.Body, r, {'1x', '1x'});
E.trTestShow = uidropdown(twg, "Items", ["brackets, stars and the p" "the p in a corner" "off (the caption only)"], ...
    "ItemsData", ["brackets" "text" "off"], "ValueChangedFcn", changed, "Tooltip", "Brackets (a distribution): each " + ...
    "pair bracketed with its stars, the group test's p in a corner. The p in a corner: the group test only. Off: in " + ...
    "the figure's caption only.");
E.trBracketPairs = uidropdown(twg, "Items", ["the significant pairs" "every pair (n.s. too)"], "ItemsData", ["significant" "all"], ...
    "ValueChangedFcn", changed, "Tooltip", "The pairs bracketed: those below alpha, or every pair.");
[Sd, r] = formRow(Sd, "trOpacity", "Opacity:");
E.trOpacity = uieditfield(Sd.Body, "numeric", "Limits", [0 1], "Value", 0.5, "ValueChangedFcn", changed, ...
    "Tooltip", "The bars' or the points' opacity, 0 (invisible) to 1 (solid).");
place(E.trOpacity, r, 2);
[Sd, r] = formRow(Sd, ["trMarginals" "trMarginalSize"], "Marginals:");
tmg2 = subgrid(Sd.Body, r, {'1x', 'fit', 64});
E.trMarginals = uicheckbox(tmg2, "Text", "histograms beside the plot", "ValueChangedFcn", changed, ...
    "Tooltip", "A histogram of x above the plot and of y at its right, per series, inside the panel's box.");
uilabel(tmg2, "Text", "size:");
E.trMarginalSize = uispinner(tmg2, "Limits", [0.1 0.5], "Step", 0.05, "Value", 0.25, "ValueChangedFcn", changed, ...
    "Tooltip", "The strips' share of the panel's box, 0.1 to 0.5.");
[Sd, r] = formRow(Sd, ["legOrient" "legColumns"], "Entries:");   % a legend panel's
lg2 = subgrid(Sd.Body, r, {'1x', 'fit', 70});
E.legOrient = uidropdown(lg2, "Items", ["auto (by the panel's shape)" "vertical" "horizontal"], ...
    "ItemsData", ["auto" "vertical" "horizontal"], "Value", "auto", "ValueChangedFcn", changed, ...
    "Tooltip", "How the legend's entries line up: auto is a row when the panel is wider than tall, else a column.");
uilabel(lg2, "Text", "columns:");
E.legColumns = uispinner(lg2, "Limits", [0 50], "Step", 1, "Value", 0, "RoundFractionalValues", "on", ...
    "ValueDisplayFormat", "%d", "ValueChangedFcn", changed, ...
    "Tooltip", "How many columns the entries take: 0 = automatic, from the panel's shape.");
[Sd, r] = formRow(Sd, ["legAlign" "legVAlign"], "Place in panel:");
lg3 = subgrid(Sd.Body, r, {'1x', '1x'});
E.legAlign = uidropdown(lg3, "Items", ["left" "center" "right"], "Value", "center", "ValueChangedFcn", changed, ...
    "Tooltip", "Where the legend sits across the panel when narrower than it (it is never stretched to fill it).");
E.legVAlign = uidropdown(lg3, "Items", ["top" "middle" "bottom"], "Value", "middle", "ValueChangedFcn", changed, ...
    "Tooltip", "Where the legend sits up the panel when shorter than it.");
[Sd, r] = formRow(Sd, "unitLabels", "");
E.unitLabels = uicheckbox(Sd.Body, "Text", "Unit labels, with arrows", "ValueChangedFcn", changed, "Tooltip", ...
    "Each unit's name beside its shank, clear of the units, with an arrow to the unit. The channel numbers are " + ...
    "left off then.");
place(E.unitLabels, r, [1 2]);
[Sd, r] = formRow(Sd, "waveColor", "");
E.waveColor = uicheckbox(Sd.Body, "Text", "Color waveforms by value", "ValueChangedFcn", changed, "Tooltip", ...
    "Units drawn as waveforms (Waveform: Waveform) take the color of their value (firing rate or spike count) in the " + ...
    "color scale, with a color bar. Not with Color by: nUnits.");
place(E.waveColor, r, [1 2]);
sec(end+1) = Sd;

% Axes: the axes' box, labels and sides, what each shows, the trial panels' scales and x limits, a spectrogram's frequency
% axis, the y limits and the color scale
Sx = formSection(eg, 21, "axes", "Axes", Color=tint("axes"));
E.axesApplyAll = applyAllButton(obj, Sx, "axes", "Copy this panel's X axis and Y axis sides to every other panel (not their " + ...
    "label texts), and its Y limits mode, Y limits, Colormap, Color limits and Frequency axis to the panels that have them.");
[Sx, r] = formRow(Sx, "panelBox", "Axes box:");
E.panelBox = uidropdown(Sx.Body, "Items", ["auto (the design's)" "on" "off"], "ItemsData", ["auto" "on" "off"], ...
    "ValueChangedFcn", changed, "Tooltip", "The frame around the panel's axes. auto: the design's (and the looks remembered for " + ...
    "the panel's kind); on or off: this panel's own, over them.");
place(E.panelBox, r, 2);
[Sx, r] = formRow(Sx, ["panelXLabel" "panelXSide"], "X axis:");
xg = subgrid(Sx.Body, r, {'1x', 90});
E.panelXLabel = uieditfield(xg, "text", "Placeholder", "automatic", "ValueChangedFcn", changed, ...
    "Tooltip", "The x axis' label. Blank: the panel type's (""Time (s)"" on a time axis). A stack of time panels " + ...
    "is labeled once: this text shows where this panel tells the time. Right-click the label in the preview to edit it there. " + ...
    "Variables in braces are filled in for each figure, e.g. ""Time (s) re {Line} {Edge}"": the {x} button lists them." + symbolsTip);
E.panelXSide = uidropdown(xg, "Items", ["bottom" "top"], "ItemsData", EphysAnalysisConfig.PanelXSides, ...
    "ValueChangedFcn", changed, "Tooltip", "Where the x axis' ticks and label go: below or above the panel. A stack " + ...
    "of time panels with their x axes on top tells the time once, at its top.");
[Sx, r] = formRow(Sx, ["panelYLabel" "panelYSide"], "Y axis:");
yg = subgrid(Sx.Body, r, {'1x', 90});
E.panelYLabel = uieditfield(yg, "text", "Placeholder", "automatic", "ValueChangedFcn", changed, ...
    "Tooltip", "The y axis' label. Blank: the panel type's. Right-click the label in the preview to edit it there. " + ...
    "Variables in braces are filled in for each figure, e.g. ""Rate (spikes/s, {Bin} ms bins)"": the {x} button lists them." + symbolsTip);
E.panelYSide = uidropdown(yg, "Items", ["left" "right"], "ItemsData", EphysAnalysisConfig.PanelYSides, ...
    "ValueChangedFcn", changed, "Tooltip", "Where the y axis' ticks and label go: left or right of the panel " + ...
    "(a color bar beside it moves to the other side).");
[Sx, r] = formRow(Sx, ["panelXShow" "panelYShow"], "Show (x, y):");
shg = subgrid(Sx.Body, r, {'1x', '1x'});
showItems = ["label and ticks" "ticks, no label" "label, no ticks" "neither"];
E.panelXShow = uidropdown(shg, "Items", showItems, "ItemsData", EphysAnalysisConfig.PanelAxisShows, "Value", "all", ...
    "ValueChangedFcn", changed, "Tooltip", "What the x axis shows: its label and ticks, or with its label or its " + ...
    "ticks (marks and numbers) blanked, or neither (the axis line alone). A blank label or ticks leave their room " + ...
    "to the plot.");
E.panelYShow = uidropdown(shg, "Items", showItems, "ItemsData", EphysAnalysisConfig.PanelAxisShows, "Value", "all", ...
    "ValueChangedFcn", changed, "Tooltip", "What the y axis shows: its label and ticks, or with its label or its " + ...
    "ticks (marks and numbers) blanked, or neither (the axis line alone). A stacked line panel's two y axes go alike.");
[Sx, r] = formRow(Sx, ["trXScale" "trYScale"], "Scales (x, y):");
tsc = subgrid(Sx.Body, r, {'1x', '1x'});
E.trXScale = uidropdown(tsc, "Items", ["x linear" "x logarithmic"], "ItemsData", ["linear" "log"], "ValueChangedFcn", changed, ...
    "Tooltip", "The x axis: linear or logarithmic (a histogram's bins then log-spaced; values at or below 0 are left out).");
E.trYScale = uidropdown(tsc, "Items", ["y linear" "y logarithmic"], "ItemsData", ["linear" "log"], "ValueChangedFcn", changed, ...
    "Tooltip", "The y axis: linear or logarithmic (values at or below 0 are left out).");
[Sx, r] = formRow(Sx, "trXLim", "X limits:");
E.trXLim = uieditfield(Sx.Body, "text", "Placeholder", "automatic, or lo hi", "ValueChangedFcn", changed, ...
    "Tooltip", "The x axis: two ascending values, in the measure's unit. Blank: automatic.");
place(E.trXLim, r, 2);
[Sx, r] = formRow(Sx, "spFreqScale", "Frequency axis:");
E.spFreqScale = uidropdown(Sx.Body, "Items", ["linear" "logarithmic"], "ItemsData", ["linear" "log"], ...
    "ValueChangedFcn", changed, "Tooltip", "The frequency axis of a spectrogram (y), a coherence or a phase coherence panel (x; " + ...
    "over time, y). Logarithmic spreads out the low frequencies (ticks at 2, 5, 10, 20, 50 ... Hz) and leaves out " + ...
    "the 0 Hz row. Nothing is computed again.");
place(E.spFreqScale, r, 2);
[Sx, r] = formRow(Sx, ["yLim" "yLimMode"], "Y limits:");
yg = subgrid(Sx.Body, r, {'1x', '1x'});
E.yLimMode = uidropdown(yg, "Items", ["Auto" "Shared by rows" "Shared by batch" "Fixed"], ...
    "ItemsData", EphysAnalysisConfig.YLimModes, "ValueChangedFcn", changed, "Tooltip", "Auto: the axis fits this " + ...
    "panel's data (in a stack each row fits itself, its top on the right axis). Shared by rows: a stack's rows share " + ...
    "one scale (overlaid groups share the one axis already). Shared by batch: every observation of a Generate selected figure or " + ...
    "Export run of this figure on one range, the union over the run's datasets (the preview draws its own range). " + ...
    "Fixed: the limits typed beside it.");
E.yLim = uieditfield(yg, "text", "Placeholder", "lo hi", "ValueChangedFcn", changed, ...
    "Tooltip", "Fixed: the y axis' two ascending values (a stack: every row's range).");
[Sx, r] = formRow(Sx, "panelColormap", "Colormap:");
E.panelColormap = uidropdown(Sx.Body, "Editable", "on", "Items", ["auto" "parula" "turbo" "hot" "gray" "jet" "cool" "blueWhiteRed"], ...
    "Value", "auto", "ValueChangedFcn", changed, "Tooltip", "This panel's colors: auto = Heat colors (Style), else " + ...
    "the design's heat colormap (an auROC: its diverging one); or the name of a colormap function.");
place(E.panelColormap, r, 2);
[Sx, r] = formRow(Sx, "cLim", "Color limits:");
E.cLim = uieditfield(Sx.Body, "text", "Placeholder", "automatic, or lo hi", "ValueChangedFcn", changed, ...
    "Tooltip", "This panel's color scale: two ascending values. Blank: automatic.");
place(E.cLim, r, 2);
sec(end+1) = Sx;

% the selected panel's unit waveform: its own section, for every type whose layers may be spikes (waveformSection)
[S, E] = waveformSection(eg, E, changed, tint("waveform"));
sec(end+1) = S;

% the selected panel's annotations: its descriptive text (its note: drawNote) and the lines and patches drawn on its axes
% (its overlays: drawOverlays), each group under a sub-heading
S = formSection(eg, 15, "annotations", "Annotations", Color=tint("annotations"));
[S, ~] = formSubheading(S, "textNote", "Text note");
[S, r] = formRow(S, "annText", "Text:", 78);
E.annText = uitextarea(S.Body, "Value", "", "ValueChangedFcn", changed, ...
    "Tooltip", "Words to put on the selected panel -- a caption, a condition, a remark. Each new line is a line of " + ...
    "text; blank draws nothing. Where it goes, and how it looks, are set below. Variables in braces are filled in " + ...
    "for each figure, e.g. ""n = {Epochs} {Response} trials"": the {x} button lists them." + symbolsTip);
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
    "ValueChangedFcn", changed, "Tooltip", "Points; blank is the figure's font size (Style).");
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
    "ValueChangedFcn", changed, "Tooltip", "As typed: every character is printed as it is, but for special characters " + ...
    "(\mu is µ, \pm is ±, as in every label). TeX: \mu, \pm, x^2, x_i, \bf{...} set symbols, powers, subscripts and " + ...
    "bold or italic runs (a ""_"" or ""^"" in a variable's value stays as it is).");
place(E.annInterp, r, 2);
[S, ~] = formSubheading(S, "overlays", "Overlays");   % (syncFigureEditor puts the count in its title: "Overlays (2)")
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
[S, r] = formRow(S, "ovKind", "Shape:");
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
[S, r] = formRow(S, "ovLayer", "Stacking:");
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

% style: the figure's style (no tiles or limits: the panels have those), in four groups
S = formSection(eg, 12, "style", "Style", Color=tint("style"));
[S, ~] = formSubheading(S, "textLines", "Text and lines");
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
[S, ~] = formSubheading(S, "colors", "Colors");
[S, r] = formRow(S, "colormap", "Group colors:");
E.colormap = uidropdown(S.Body, "Editable", "on", "Items", ["lines" "parula" "turbo" "jet" "hot" "cool" "gray" "black"], ...
    "Value", "lines", "ValueChangedFcn", changed, "Tooltip", "lines: the trial selection's colors; a colormap function; " + ...
    "or one color for every group (a name or #RRGGBB).");
place(E.colormap, r, 2);
[S, r] = formRow(S, "heatColormap", "Heat colors:");
E.heatColormap = uidropdown(S.Body, "Items", ["auto" "parula" "turbo" "hot" "gray" "jet" "cool" "blueWhiteRed"], ...
    "ValueChangedFcn", changed, "Tooltip", "auto: parula; blueWhiteRed for unit correlation.");
place(E.heatColormap, r, 2);
[S, ~] = formSubheading(S, "legendGroup", "Legend");
[S, r] = formRow(S, ["legend" "legendLoc" "legendOrient" "legendBox"], "Legend:");
lgg = subgrid(S.Body, r, {'fit', '1x', '1x', 'fit'});
E.legend = uicheckbox(lgg, "Text", "Show", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Draw the figure's legend (its place, orientation and box are set at its right).");
E.legendLoc = uidropdown(lgg, "Items", ["Auto" "Inside" "None"], "ItemsData", ["auto" "inside" "none"], ...
    "Value", "auto", "ValueChangedFcn", changed, ...
    "Tooltip", "Auto: the figure's legend panel when it has one, else floating in free space, else inside the first " + ...
    "panel. Drag the floating legend with Arrange on to make it a panel.");
E.legendOrient = uidropdown(lgg, "Items", ["Auto" "Vertical" "Horizontal"], "ItemsData", ["auto" "vertical" "horizontal"], ...
    "Value", "auto", "ValueChangedFcn", changed, "Tooltip", "How the legend's entries line up.");
E.legendBox = uicheckbox(lgg, "Text", "Box", "ValueChangedFcn", changed, "Tooltip", "Draw the legend's outline and background.");
[S, ~] = formSubheading(S, "labelsMarks", "Labels and marks");
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
[S, r] = formRow(S, ["showStop" "showArtifactNote"], "Marks:");
shg = subgrid(S.Body, r, {'fit', 'fit', '1x'});
shg.ColumnSpacing = 12;
E.showStop = uicheckbox(shg, "Text", "Stop marks", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Mark each epoch's stop event (the Epoch window's).");
E.showArtifactNote = uicheckbox(shg, "Text", "Artifact note", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Under the title, say how many of the drawn epochs touch an artifact period (kept when the " + ...
    "trial selection's Artifacts: Exclude epochs is off).");
[S, r] = formRow(S, "grid", "Grid:");
E.grid = uicheckbox(S.Body, "Text", "Grid lines", "Value", true, "ValueChangedFcn", changed, ...
    "Tooltip", "Draw the grid lines of the panels' axes.");
place(E.grid, r, 2);
sec(end+1) = S;

% the design and the looks of the figure: the design list (the preview has the same one; refreshDesigns keeps them equal),
% the two buttons that make a look of the preview, the looks remembered for the figure (the preview's right-click editor),
% and where a part's look comes from
S = formSection(eg, 13, "looks", "Design and looks", Color=tint("looks"));
[S, r] = formRow(S, "design", "Design:");
E.design = uidropdown(S.Body, "Items", PlotDesign.DefaultName, "ItemsData", PlotDesign.DefaultName, ...
    "ValueChangedFcn", @(dd, ~) obj.onDesignChosen(dd.Value), ...
    "Tooltip", "The look of every figure: its ground, colors, fonts, axes, ticks, lines and marks. " + ...
    "Choosing one redraws every figure on screen; runs draw their figures in it too. The preview's Design list is this one.");
place(E.design, r, 2);
[S, r] = formRow(S, ["saveDesign" "editAesthetics"], "", 30);
bg = uigridlayout(S.Body, [1 3], "ColumnWidth", {'fit', 'fit', '1x'}, "ColumnSpacing", 8, "Padding", [0 0 0 0]);
place(bg, r, [1 2]);
obj.SaveDesignButton = uibutton(bg, "Text", "Save look as design...", "ButtonPushedFcn", @(~,~) obj.onSaveDesign(), ...
    "Tooltip", "Keep the preview's look -- every property of every component, its ground and its group " + ...
    "colors -- as a design of your own, to choose for any figure. The axes of heat map, probe map, " + ...
    "correlation map and spectrogram panels are kept for those panel types only. Preview first if the " + ...
    "preview is out of date.");
% the aesthetics editor on the preview without a right-click (the app's EditAestheticsButton is this button)
E.editAesthetics = uibutton(bg, "Text", "Edit aesthetics...", "ButtonPushedFcn", @(~,~) obj.onEditAesthetics(), ...
    "Tooltip", "Change the colors, lines, markers, fonts and labels of the preview: the aesthetics editor a right-click " + ...
    "on a part of the plot opens, here on the selected panel's axes. Every part of the figure is in its list.");
obj.EditAestheticsButton = E.editAesthetics;
[S, r] = formRow(S, ["looksText" "looksForget"], "", 30);
kg = subgrid(S.Body, r, {'1x', 'fit'});
place(kg, r, [1 2]);
E.looksText = uilabel(kg, "Text", "", "WordWrap", "on");
E.looksForget = uibutton(kg, "Text", "Forget", "ButtonPushedFcn", @(~,~) onForgetLooks(obj), ...
    "Tooltip", "Forget the looks remembered for this figure (colors, lines, fonts set in the right-click editor).");
[S, r] = formRow(S, "looksOrder", "", 44);
E.looksOrder = uilabel(S.Body, "Text", "A part's look comes from, in this order: the panel's own rows (Display, Axes), this figure's " + ...
    "remembered looks, your looks for the panel type, the design.", "FontColor", gray, "WordWrap", "on", "VerticalAlignment", "top");
place(E.looksOrder, r, [1 2]);
sec(end+1) = S;

names = [sec.Name];
for i = 2:numel(sec)
    name = sec(i).Name;
    sec(i).Toggle.ButtonPushedFcn = @(~,~) obj.onFigureSectionToggled(name);
    k = find(keyed == name);
    if ~isempty(k); sec(i).Key = string(mod(k, 10)); end   % Ctrl+1 ... Ctrl+9, then Ctrl+0 for the tenth (onKeyPress)
end
for i = find(ismember(names, ["annotations" "style" "sessions" "probe"]))
    sec(i).Expanded = false;   % collapsed until opened (then kept: FigureSectionsCollapsed)
end
% the supersections: each collapses its sections under a dark header, which Alt+1 to Alt+3 go to (onKeyPress)
U = struct('Name', {scopes.Name}, 'Title', {scopes.Title}, 'Sections', {scopes.Sections}, ...
    'Header', {hFigure hPanel hLook}, 'Expanded', true, 'Key', {scopes.Key});
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
% a "{x}" button beside each text that labels the figure: inserts a label variable ({Line}, {Response}, ...), filled in
% for each figure drawn (labelVariableButton, figureLabelVariables); its menu's last item lists them (onLabelVariables)
E.varButton = struct();
for f = ["title" "panelTitle" "panelXLabel" "panelYLabel" "layerName" "annText"]
    E.varButton.(f) = labelVariableButton(E.(f), Values=@() obj.labelVariableValues(), List=@() obj.onLabelVariables());
end
obj.FigureEditor = E;
obj.FigureSections = sec;
obj.FigureSupers = U;
obj.layoutFigureEditor();
obj.FigureSearchIndex = figureSearchIndex(obj.FigureSections, U);   % the rows as built (formLayout found their controls)

% --- right: the observation picker and the preview ----------------------------------------------
% the buttons in a column of their own at the left, beside the Dataset, Observation and Favorites rows (three rows
% tall enough for its five); Design sits at the right of Dataset (Save look as design is in the Look section); the
% template row (and Apply last change) above the preview. Ctrl is Cmd on a Mac (onKeyPress).
pg = uigridlayout(g, [7 5]);
pg.RowHeight = {46, 46, 46, 34, '1x', 30, 20};
pg.ColumnWidth = {110, 'fit', '1x', 'fit', 125};   % (110: Export preview unclipped, room for Auto's slider)
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
obj.FigureExportPreviewColumnButton = uibutton(bg, "Text", "Export preview", "Enable", "off", ...
    "Tooltip", "Spot-check the Export tab's settings: this figure for the observation picked, drawn and written as a " + ...
    "run writes it (size, formats, dpi, file name) into a preview folder -- not the figure folder -- and shown in a " + ...
    "window. (" + cmdKey + "+K)", "ButtonPushedFcn", @(~,~) obj.onExportPreview());
obj.FigureExportPreviewColumnButton.Layout.Row = 3;
% Auto: how slow a redraw an edit may start, 0 (off) to 1 (every edit); the limit in its tooltip (showAutoRedraw)
ag = uigridlayout(bg, [1 2], "ColumnWidth", {'fit', '1x'}, "ColumnSpacing", 4, "Padding", [0 0 0 0]);
ag.Layout.Row = 4;
uilabel(ag, "Text", "Auto");
obj.FigureAutoSlider = uislider(ag, "Limits", [0 1], "Value", obj.AutoRedrawDefault, "MajorTicks", [], "MinorTicks", [], ...
    "ValueChangedFcn", @(~,~) obj.onFigureAutoRedrawChanged(), "ValueChangingFcn", @(~, e) obj.onFigureAutoRedrawChanged(e.Value));
showAutoRedraw(obj);
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
sg.Layout.Row = 2; sg.Layout.Column = [3 5];   % (the cells under Design are free: the Observation row takes the width)
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
% the design every figure is drawn in (PlotDesign; also the Design menu), right of the Dataset drop-down; the Look
% section's Design and looks has the same list
l = uilabel(pg, "Text", "Design:");
l.Layout.Row = 1; l.Layout.Column = 4;
obj.DesignDropDown = uidropdown(pg, "Items", PlotDesign.DefaultName, "ItemsData", PlotDesign.DefaultName, ...
    "ValueChangedFcn", @(dd, ~) obj.onDesignChosen(dd.Value), ...
    "Tooltip", "The look of every figure: its ground, colors, fonts, axes, ticks, lines and marks. " + ...
    "Choosing one redraws every figure on screen; runs draw their figures in it too.");
obj.DesignDropDown.Layout.Row = 1; obj.DesignDropDown.Layout.Column = 5;
% the figure templates of yours (FigureTemplate: a figure's settings, copied into figures when applied), and Apply
% (Apply last change is at the top of the settings column), in the row above the preview; Arrange at its right. While
% Arrange is on, its align bar takes the templates' place (syncAlignBar)
ab = uigridlayout(pg, [1 2], "ColumnWidth", {'1x', 'fit'}, "ColumnSpacing", 4, "Padding", [0 2 0 2]);
ab.Layout.Row = 4; ab.Layout.Column = [1 5];
tg = uigridlayout(ab, [1 9], "ColumnWidth", {'fit', '1x', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'}, ...
    "ColumnSpacing", 4, "Padding", [0 0 0 0]);
tg.Layout.Row = 1; tg.Layout.Column = 1;
obj.FigureTemplateBar = tg;
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
    "options, layers, notes and overlays, their places and padding, style, remembered looks, sessions, probe layout) but its id, title and enabled.");
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
obj.FigureArrangeButton = uibutton(ab, "state", "Text", "Arrange", "Value", false, ...
    "ValueChangedFcn", @(~, ~) obj.onArrangeToggled(), ...
    "Tooltip", "Arrange the panels over the preview: drag a panel to move it, a handle to resize it; it snaps to the " + ...
    "other panels, the page and the snap step (Alt: no snapping), and the arrow keys nudge the selected panel. " + ...
    "The bar beside it lines the selected panels up and spaces them evenly. " + ...
    "Off: the preview as usual (data tips, right-click editors).");
obj.FigureArrangeButton.Layout.Row = 1; obj.FigureArrangeButton.Layout.Column = 2;
obj.FigureAlignBar = buildAlignBar(obj, ab);
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
    "Tooltip", "A figure across sessions makes one figure per subject (One page per: one per subject) or per trial group " + ...
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
obj.FigurePreviewHint = uilabel(pg, "Text", "Right-click the plot to change colors, fonts and labels.", "FontColor", gray);   % (Arrange's hint while on: onArrangeToggled)
obj.FigurePreviewHint.Layout.Row = 7; obj.FigurePreviewHint.Layout.Column = [1 5];
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


function onGroupByChanged(obj)
%onGroupByChanged  The figure tree's Group by: regroup it (the selected figure stays); Up and Down follow its new group.
obj.refreshFigureList();
obj.syncFigureEditor();
end


function B = buildAlignBar(obj, parent)
%buildAlignBar  Arrange's align bar, in the templates' cell of PARENT (hidden until Arrange is on: syncAlignBar).
%   Align [panel boxes | axes | axes and labels] to [the selection | the
%   first selected | the page], six buttons (left edges, centers, right
%   edges; top edges, middles, bottom edges), Space evenly (across, up)
%   and its Gap (blank: even gaps; in the Panels section's units). The
%   buttons call onArrangeAlign; the choices are preferences
%   (FigureAlignBy, FigureAlignTo, FigureAlignGap: onAlignOptions).
%   B: grid, by, to, buttons (a struct of the eight, by onArrangeAlign's
%   names), gap, gapUnits.
iconDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "icons", "arrange");
w = 30;   % an icon button
g = uigridlayout(parent, [1 18], "ColumnWidth", {'fit', 112, 'fit', 104, w, w, w, w, w, w, 2, 'fit', w, w, 'fit', 50, 'fit', '1x'}, ...
    "ColumnSpacing", 3, "Padding", [0 0 0 0], "Visible", "off", "Tag", "arrangeAlignBar");
g.Layout.Row = 1; g.Layout.Column = 1;
B.grid = g;
uilabel(g, "Text", "Align", "FontWeight", "bold", ...
    "Tooltip", "Line the selected panels up, or space them evenly (Shift+click their boxes to select several). One step of Undo each.");
B.by = uidropdown(g, "Items", ["boxes" "axes" "axes + labels"], "ItemsData", ["box" "axes" "labels"], ...
    "Value", obj.FigureAlignBy, "ValueChangedFcn", @(~, ~) onAlignOptions(obj), ...
    "Tooltip", "What is lined up or spaced. Panel boxes: the boxes Arrange shows (the panels' places). Axes: the plot " + ...
    "areas as drawn, which a panel's labels may move in from its box. Axes and labels: the axes with their tick " + ...
    "labels, axis labels, title and note, as drawn: equal white space between them. A preference.");
uilabel(g, "Text", "to");
B.to = uidropdown(g, "Items", ["selection" "first selected" "page"], "ItemsData", ["selection" "first" "page"], ...
    "Value", obj.FigureAlignTo, "ValueChangedFcn", @(~, ~) onAlignOptions(obj), ...
    "Tooltip", "What they are lined up with. The selection: all of them (Left: the leftmost edge; Center: the middle " + ...
    "of all of them). The first selected: the panel selected first (the one the editor shows), which stays put. The " + ...
    "page: its edges or its middle. One panel selected: always the page. Space evenly: the selection keeps the " + ...
    "outermost panels where they are; the page spreads them from edge to edge (with a Gap: centers them on it).");
tips = struct( ...
    'left',   "Line up their left edges.", ...
    'center', "Line up their centers, across: one above the other.", ...
    'right',  "Line up their right edges.", ...
    'top',    "Line up their top edges.", ...
    'middle', "Line up their middles, up the page: side by side.", ...
    'bottom', "Line up their bottom edges.", ...
    'spaceX', "Space them evenly across the page: the same gap between each and the next. A column of panels " + ...
              "(panels one above another) moves as one, so a grid keeps its columns.", ...
    'spaceY', "Space them evenly up the page: the same gap between each and the next. A row of panels moves as " + ...
              "one, so a grid keeps its rows.");
names = string(fieldnames(tips)).';
for i = 1:numel(names)
    nm = names(i);
    if nm == "spaceX"
        uilabel(g, "Text", "");   % (a little room before Space)
        uilabel(g, "Text", "Space", "FontWeight", "bold", ...
            "Tooltip", "Space evenly: equal gaps between the selected panels. Gap blank: even gaps between the outermost; a Gap: that gap.");
    end
    B.buttons.(nm) = uibutton(g, "Text", "", "Icon", fullfile(iconDir, "align" + upper(extractBefore(nm, 2)) + extractAfter(nm, 1) + ".svg"), ...
        "Tooltip", tips.(nm), "Tag", "arrangeAlign:" + nm, "Enable", "off", "ButtonPushedFcn", @(~, ~) obj.onArrangeAlign(nm));
end
uilabel(g, "Text", "Gap", "HorizontalAlignment", "right");
B.gap = uieditfield(g, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "even", "Limits", [0 Inf], ...
    "ValueDisplayFormat", "%.10g", "ValueChangedFcn", @(~, ~) onAlignOptions(obj), ...
    "Tooltip", "The gap Space evenly leaves between the panels, in the Panels section's units. Blank: even gaps, the " + ...
    "outermost panels staying put (or at the page's edges, to the page). A preference.");
B.gapUnits = uilabel(g, "Text", "cm", "FontColor", [0.4 0.4 0.4]);
end


function onAlignOptions(obj)
%onAlignOptions  The align bar's Align, to or Gap changed: kept as preferences (FigureAlignBy, FigureAlignTo, FigureAlignGap); nothing moves.
B = obj.FigureAlignBar;
obj.FigureAlignBy = string(B.by.Value);
obj.FigureAlignTo = string(B.to.Value);
v = B.gap.Value;
if isempty(v)
    obj.FigureAlignGap = [];
    gapText = "even gaps";
else
    obj.FigureAlignGap = struct('value', double(v), 'units', obj.FigureRectUnits);
    gapText = sprintf("a gap of %g %s", v, B.gapUnits.Text);
end
obj.savePreferences();
words = struct('box', "the panel boxes", 'axes', "the axes", 'labels', "the axes with their labels");
to = struct('selection', "the selection", 'first', "the first selected", 'page', "the page");
obj.setStatus("Arrange's bar lines up " + words.(obj.FigureAlignBy) + " to " + to.(obj.FigureAlignTo) + ...
    "; Space evenly leaves " + gapText + ".");
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
[cfg, action, shared] = spreadPanelEdit(obj, cfg, "Trial selection as the figure");   % several panels selected: to all of them
if shared ~= ""; msg = shared; end
commitFigureEdit(obj, cfg, msg, Action=action);
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


function b = applyAllButton(obj, S, section, tip)
%applyAllButton  The Apply to all panels button in the header of the Analysis, Display or Axes section S (applyOptionsToAll).
b = uibutton(S.HeaderGrid, "Text", "Apply to all panels", "FontSize", 11, ...
    "ButtonPushedFcn", @(~,~) applyOptionsToAll(obj, section), "Tooltip", tip);
b.Layout.Column = 2;
end


function applyOptionsToAll(obj, section)
%applyOptionsToAll  adoptPanelOptions for one section's rows: the selected panel's Analysis, Display or Axes rows go to the other panels.
%   SECTION is "analysis", "display" or "axes" (sectionOptionFields lists
%   the options each one's rows write). The shared rows go to every panel
%   that has them, the section's other options to the panels of the
%   panel's type; Axes also gives the axis sides (xSide, ySide) to every
%   other panel (not the label texts). The status bar names each panel that
%   changed, with its options and sides, and the panels that kept their
%   baseline, stack or Y limits mode because their type does not take the
%   value (a fixed mode: they have no limits of their own); nothing changes
%   when the others have the values already. Each is one named edit, "Apply
%   Analysis to all panels", and the three in turn are what the one button
%   did before them.
k = obj.SelectedFigure;
j = obj.SelectedPanel;
if k < 1 || k > numel(obj.Config.Figures) || j < 1 || j > numel(obj.Config.Figures(k).panels); return; end
what = struct('analysis', "Analysis", 'display', "Display", 'axes', "Axes").(section);
cfg = obj.gatherConfig();
fig = cfg.Figures(k);
p = fig.panels(j);
[fig, changed] = EphysAnalysisConfig.adoptPanelOptions(fig, p.id, Fields=sectionOptionFields(section));
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
msg = p.id + "'s " + what + " settings went to " + strjoin(went, ", ");
if isempty(went); msg = "The other panels have " + p.id + "'s " + what + " settings already"; end
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
commitFigureEdit(obj, cfg, msg + ".", Action="Apply " + what + " to all panels");
end


function f = sectionOptionFields(section)
%sectionOptionFields  The option names (the panel's options fields, and the pseudo-names xSide and ySide) that SECTION's rows write: adoptPanelOptions' Fields.
%   One line per row key (the row's controls are E.<key>; gatherOptions
%   moves them to these fields), over every panel type: a type without a
%   field copies nothing for it. A row that writes several fields lists them.
%   The Display section also holds the Waveform section's inset
%   (waveform), the one option whose rows are in a section of their own. The
%   Axes section's sides go to every panel; the box, labels and what the
%   axes show stay each panel's own.
T = {
    "analysis"  "filter"                         % Filter (a signal panel's)
    "analysis"  "group"                          % Trial group drawn
    "analysis"  "bins"                           % Bin width, Smoothing SD
    "analysis"  "measure"
    "analysis"  ["baseline" "auroc"]             % Baseline, its window, the auROC rows
    "analysis"  "maskAfterStop"
    "analysis"  "normalize"
    "analysis"  ["statistic" "transform"]        % Signal
    "analysis"  ["metric" "correlation" "fisherZ" "detrend"]   % unit correlation; the spectral panels' Detrend
    "analysis"  ["param" "seriesParam"]
    "analysis"  "rows"                           % heat map Rows
    "analysis"  "order"
    "analysis"  "value"                          % probe map Color by
    "analysis"  ["timeBase" "range" "segmentSec" "taperMode" "TW" "K" "W" "p" "pad" "fpass" "spikeFs" "movingwin" "overTime"]
    "analysis"  ["categories" "categoryParam" "categoryBins" "series" "seriesBins" "binMode" "binCount" "binWidth"]
    "analysis"  ["fit" "fitBand" "fitWindow" "corr"]
    "analysis"  ["summary" "errorType" "errorResamples" "err" "errP" "test" "testPairs" "adjust" "testAlpha"]   % Statistics
    "display"   ["display" "histStyle" "fill" "fillAlpha" "smoothLine" "stack" "stackSpacing" "onsetLine" "trialCount"]
    "display"   ["firstSpike" "latencyBox" "band"]
    "display"   ["rasterSort" "rasterSortEvent" "rasterSortOrder" "rasterByGroup" "yTicks" "tickColor" "backColor" "tickWidth"]
    "display"   ["trials" "maxTrials" "layout" "scale" "showPhase"]
    "display"   ["groupBands" "colorBy" "height" "alpha" "edgeColor" "edgeWidth" "minWidth" "lineStyle" "lineWidth" "showBaseline" ...
                 "baselineColor" "baselineStyle" "baselineWidth" "rowSpacing"]   % event traces
    "display"   ["bracketPairs" "ordinalX" "markerSize" "jitter" "showSummary" "showN" "normalization" "testShow" "marginals" ...
                 "marginalSize"]   % trial panels
    "display"   ["orientation" "columns" "align" "valign" "unitLabels" "waveColor" "waveform"]
    "axes"      ["xSide" "ySide"]
    "axes"      ["yLim" "yLimMode" "cLim" "colormap" "xLim" "xScale" "yScale" "freqScale"]
    };
f = unique([T{[T{:, 1}] == section, 2}], 'stable');
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
    renderFigure(F, spec, obj.FigurePreviewPanel, Scale=previewScale(obj, spec), ...
        OnRemember=@(rules) obj.rememberFigureAesthetics(spec.id, rules), ...
        OnGoto=@(role, panel) obj.gotoFigureSetting(spec.id, role, panel), ...
        OnAxisEdit=@(panel, change) obj.onFigureAxisEdited(spec.id, panel, change), ...
        OnSelect=@(panel, ctrl, shift) obj.onFigurePanelClicked(spec.id, panel, ctrl, false, shift));
catch
    obj.autoFigurePreview();
end
end


function b = defaultBox(obj, g, what)
%defaultBox  The "Use default" box in the right slot of an alignment sub-heading (formSubheading, Control=true: the grid G).
b = uicheckbox(g, "Text", "Use default", "Value", true, ...
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
items = ["95% CI (paper)" "fixed threshold" "shuffle-calibrated" "per-unit test" "none"];
data = ["ci" "fixed" "shuffle" "test" "none"];
if ~isPlot; items = items(1:4); data = data(1:4); end
[S, r] = formRow(S, p + "Cutoff", "Modulated if:");
g = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.(p + "Cutoff") = uidropdown(g, "Items", items, "ItemsData", data, ...
    "ValueChangedFcn", changed, "Tooltip", "95% CI: beyond 0.5 +/- the 95% CI of the units' mean modulation (it needs " + ...
    "many units). fixed: beyond 0.5 +/- the threshold. shuffle-calibrated: beyond 0.5 +/- the (1 - alpha) quantile " + ...
    "of the units' modulation with each epoch's spikes shifted circularly (n shuffles; far fewer false calls than the " + ...
    "95% CI). per-unit test: the test below, its p adjusted over the units. none: no call.");
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


function c = scopeTint(scopes, name)
%scopeTint  The header color of section NAME: its supersection's hue (scopes, at the top of the editor's builder), lighter the later the section comes in that supersection.
%   Saturation runs from 1 for the supersection's first section down to 0.5 for its last (HSV, full value);
%   formSection pales it for black text.
for u = 1:numel(scopes)
    k = find(scopes(u).Sections == name, 1);
    if ~isempty(k)
        n = numel(scopes(u).Sections);
        c = hsv2rgb([scopes(u).Hue, 1 - 0.5 * (k - 1) / max(n - 1, 1), 1]);
        return
    end
end
error("EphysFigGenApp:noSupersection", "Section %s is in no supersection: add it to scopes in buildFiguresTab.", name);
end


function [S, E] = waveformSection(eg, E, changed, color)
%waveformSection  The Waveform section: the selected panel's unit waveform (options.waveform), its rows in E.
%   An inset on a raster, PSTH, firing rate or tuning curve panel, the
%   panel itself on a unit waveforms panel, the units' glyphs on a probe
%   map. syncFigureEditor shows it for
%   every type whose layers may be spikes, with a note (waveformNote) on
%   what it sets there or why the type draws none, and the rows the type
%   uses: what is shown (and the mean's error band) and how many spikes;
%   the x scale (the time span,
%   ms from the spike) and the y scale (each unit's range, one for the
%   units drawn, or a fixed range); the size of an inset or of a probe
%   layout's glyphs (Inset size or Glyph size, by role); an inset's place and box; the labels; a probe layout's
%   sites and names. It has no key (the search finds its rows).
gray = [0.35 0.35 0.35];
S = formSection(eg, 17, "waveform", "Waveform", Color=color);
[S, r] = formRow(S, "waveNote", "", 46);
E.waveNote = uilabel(S.Body, "Text", "", "FontColor", gray, "WordWrap", "on", "VerticalAlignment", "top");
place(E.waveNote, r, [1 2]);
[S, r] = formRow(S, ["waveMode" "waveBand"], "Waveform:");
mg = subgrid(S.Body, r, {'1x', 'fit'});
E.waveMode = uidropdown(mg, "Items", ["Off" "Mean" "Individual spikes" "Mean + individual spikes" "Template"], ...
    "ItemsData", EphysAnalysisConfig.WaveformModes, "Value", "off", "ValueChangedFcn", changed, ...
    "Tooltip", "The unit's waveform on its peak channel: its mean, its individual spikes (thin, pale), both, or " + ...
    "its template (a sorted unit's: no spikes read). Off: none (a probe map: a circle per unit). A unit whose " + ...
    "spikes cannot be read draws its template as the mean, and says so.");
E.waveBand = uidropdown(mg, "Items", ["No band" "± SD" "± SEM"], "ItemsData", EphysAnalysisConfig.WaveformBands, ...
    "Value", "off", "ValueChangedFcn", changed, "Tooltip", "An error band round the mean: the SD of the spikes " + ...
    "it is over, or its SEM. None on a template.");
[S, r] = formRow(S, "waveSpikes", "Spikes drawn:");
E.waveSpikes = uispinner(S.Body, "Limits", [1 2000], "Step", 50, "Value", 100, "RoundFractionalValues", "on", ...
    "ValueChangedFcn", changed, "Tooltip", "How many of the unit's spikes are drawn one by one, picked at random " + ...
    "(the same ones each time); a sorted unit's mean is over them.");
place(E.waveSpikes, r, 2);
[S, r] = formRow(S, ["waveFrom" "waveTo"], "Time span (ms):");
tg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
E.waveFrom = uieditfield(tg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "start", ...
    "ValueChangedFcn", changed, "Tooltip", "The x scale: where the waveform drawn starts, ms from the spike " + ...
    "(negative: before it). Blank: the start of the cut.");
uilabel(tg, "Text", "to");
E.waveTo = uieditfield(tg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "end", ...
    "ValueChangedFcn", changed, "Tooltip", "Where the waveform drawn ends, ms from the spike. Blank: the end of " + ...
    "the cut. A span that misses the waveform draws all of it.");
[S, r] = formRow(S, ["waveAmp" "waveAmpLo" "waveAmpHi"], "Amplitude range:");
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
[S, r] = formRow(S, ["waveWidth" "waveHeight"], "Inset size:");   % (syncFigureEditor says "Glyph size:" where the glyphs are sized)
E.waveSizeLabel = S.Body.Children(arrayfun(@(c) isa(c, 'matlab.ui.control.Label') && c.Layout.Row == r && c.Layout.Column == 1, S.Body.Children));
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
[S, r] = formRow(S, ["wavePP" "waveCount"], "Labels:");
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
