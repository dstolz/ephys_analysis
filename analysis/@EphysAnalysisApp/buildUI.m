function buildUI(obj)
%buildUI  The figure, menus, toolbar, the five tabs and the status bar; every
%   button styled (styleButtons), the main actions in color; the figure's
%   key presses (onKeyPress) once the tabs are there. The figure is built
%   hidden (the constructor shows it), each tab a step on the startup
%   splash (AppSplash). The tabs but Data have their contents hidden
%   (revealTab), so the window laid out when it shows is the Data tab's
%   alone; each other tab is laid out when first shown (onTabChanged).
obj.Fig = uifigure("Name", "Ephys analysis", "Position", [140 80 1280 820], "Visible", "off");
obj.Fig.CloseRequestFcn = @(~,~) obj.onClose();
obj.buildMenus();
obj.buildToolbar();

outer = uigridlayout(obj.Fig, [2 1]);
outer.RowHeight = {'1x', 30};
outer.Padding = [0 0 0 0];
outer.RowSpacing = 0;
obj.Tabs = uitabgroup(outer);
obj.Tabs.Layout.Row = 1;
obj.Tabs.SelectionChangedFcn = @(~,~) obj.onTabChanged();
obj.TabData   = uitab(obj.Tabs, "Title", "Data");
obj.TabAlign  = uitab(obj.Tabs, "Title", "Alignment");
obj.TabFigures = uitab(obj.Tabs, "Title", "Figures");
obj.TabExport = uitab(obj.Tabs, "Title", "Export");
obj.TabLog    = uitab(obj.Tabs, "Title", "Log");

bar = uipanel(outer, "BorderType", "line", "BackgroundColor", [0.96 0.96 0.98]);
bar.Layout.Row = 2;
bg = uigridlayout(bar, [1 3]);
bg.Padding = [8 2 8 2];
bg.ColumnSpacing = 8;
bg.ColumnWidth = {'1x', 0, 0};   % the status text; a run's progress bar and Cancel, shown while it goes (onRunExport)
obj.StatusBar = uilabel(bg, "Text", "Ready.", "FontColor", [0.15 0.15 0.15]);
track = uipanel(bg, "BorderType", "line", "BackgroundColor", [0.92 0.92 0.94]);
track.Layout.Column = 2;
RS = struct('Host', bg, 'Track', track);
RS.Bar = uigridlayout(track, [1 2], "Padding", [0 0 0 0], "ColumnSpacing", 0, "RowSpacing", 0, ...
    "BackgroundColor", [0.92 0.92 0.94], "RowHeight", {'1x'}, "ColumnWidth", {0, '1x'});
fill = uipanel(RS.Bar, "BorderType", "none", "BackgroundColor", [0.25 0.55 0.85]);
fill.Layout.Row = 1; fill.Layout.Column = 1;
RS.Cancel = uibutton(bg, "Text", "Cancel", "Tooltip", "Stop the run before the next figure observation.", ...
    "ButtonPushedFcn", @(~,~) obj.onCancelRun());
RS.Cancel.Layout.Column = 3;
obj.RunStrip = RS;

obj.Splash.step("Data", "Building the Data tab ..."); obj.buildDataTab();
obj.Splash.step("Alignment", "Building the Alignment tab ..."); obj.buildAlignTab();
obj.Splash.step("Figures", "Building the Figures tab ..."); obj.buildFiguresTab();
obj.Splash.step("Export", "Building the Export tab ..."); obj.buildExportTab();
obj.Splash.step("Log", "Building the Log tab ..."); obj.buildLogTab();
obj.Splash.step("finish", "Laying out the window ...");
styleButtons(obj);
obj.Tabs.SelectedTab = obj.TabData;
for t = [obj.TabAlign obj.TabFigures obj.TabExport obj.TabLog]
    revealTab(obj, t, true);   % laid out when first shown (onTabChanged): the window shows sooner
end
obj.Fig.WindowKeyPressFcn = @(~, evt) obj.onKeyPress(evt);   % Ctrl+1 ... Ctrl+9, Ctrl+0: the figure editor's sections
obj.Fig.WindowKeyReleaseFcn = @(~, evt) obj.onKeyRelease(evt);   % Ctrl let go: an edit applies to its figure only again
obj.refreshDesigns();
PlotDesign.listen(obj.Fig, @() obj.refreshDesigns());   % a design chosen anywhere (a figure's right-click menu too)
end


function styleButtons(obj)
%styleButtons  Every button a size up; the main actions in color (styleButton).
%   The editors' section headers (formSection) keep their header look, and
%   the color fields' swatches (colorSwatch) their color.
b = findall(obj.Fig, "Type", "uibutton", "-or", "Type", "uistatebutton");
styleButton(b(~ismember(string(get(b, "Tag")), ["formSectionToggle" "colorSwatch"])));
styleButton([obj.ScanButton, obj.RunButton, ...
    obj.FigurePreviewButton, obj.FigureRedrawAllButton, obj.FigureApplyLastButton], "primary");
styleButton([findall(obj.Fig, "Type", "uibutton", "Tag", "addFigureCard"), obj.AddFigureButton, obj.FigureEditor.newPanel, obj.FigureEditor.addLayer, obj.FigureTemplateApplyButton], "confirm");
styleButton([obj.CancelButton, obj.RunStrip.Cancel, obj.RemoveFigureButton, obj.FigureEditor.removePanel, ...
    obj.FigureEditor.removeLayer, obj.FigureTemplateRemoveButton], "danger");
end
