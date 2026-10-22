function buildUI(obj)
%buildUI  The figure, menus, toolbar, the six tabs and the status bar; every
%   button styled (styleButtons), the main actions in color; the figure's
%   key presses (onKeyPress) once the tabs are there. The figure is built
%   hidden (the constructor shows it), each tab a step on the startup
%   splash (AppSplash).
obj.Fig = uifigure("Name", "Ephys analysis", "Position", [140 80 1280 820], "Visible", "off");
obj.Fig.CloseRequestFcn = @(~,~) obj.onClose();
obj.buildMenus();
obj.buildToolbar();

outer = uigridlayout(obj.Fig, [2 1]);
outer.RowHeight = {'1x', 24};
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
bg = uigridlayout(bar, [1 1]);
bg.Padding = [8 0 8 0];
obj.StatusBar = uilabel(bg, "Text", "Ready.", "FontColor", [0.15 0.15 0.15]);

obj.Splash.step("Data", "Building the Data tab ..."); obj.buildDataTab();
obj.Splash.step("Alignment", "Building the Alignment tab ..."); obj.buildAlignTab();
obj.Splash.step("Figures", "Building the Figures tab ..."); obj.buildFiguresTab();
obj.Splash.step("Export", "Building the Export tab ..."); obj.buildExportTab();
obj.Splash.step("Log", "Building the Log tab ..."); obj.buildLogTab();
obj.Splash.step("finish", "Laying out the window ...");
styleButtons(obj);
obj.Tabs.SelectedTab = obj.TabData;
obj.Fig.WindowKeyPressFcn = @(~, evt) obj.onKeyPress(evt);   % Ctrl+1 ... Ctrl+9, Ctrl+0: the figure editor's sections
obj.Fig.WindowKeyReleaseFcn = @(~, evt) obj.onKeyRelease(evt);   % Ctrl let go: an edit applies to its figure only again
obj.refreshDesigns();
PlotDesign.listen(obj.Fig, @() obj.refreshDesigns());   % a design chosen anywhere (a figure's right-click menu too)
end


function styleButtons(obj)
%styleButtons  Every button a size up; the main actions in color (styleButton).
%   The editors' section headers (formSection) keep their header look.
b = findall(obj.Fig, "Type", "uibutton", "-or", "Type", "uistatebutton");
styleButton(b(~strcmp(get(b, "Tag"), "formSectionToggle")));
styleButton([obj.ScanButton, obj.RunButton, ...
    obj.FigurePreviewButton, obj.FigureRedrawAllButton], "primary");
styleButton([obj.AddFigureButton, obj.FigureEditor.newPanel, obj.FigureEditor.addLayer], "confirm");
styleButton([obj.CancelButton, obj.RemoveFigureButton, obj.FigureEditor.removePanel, ...
    obj.FigureEditor.removeLayer], "danger");
end
