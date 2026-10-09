function buildUI(obj)
%buildUI  The figure, menus, toolbar, the five tabs and the status bar; every
%   button styled (styleButtons), the main actions in colour; the figure's
%   key presses (onKeyPress) once the tabs are there.
obj.Fig = uifigure("Name", "Ephys analysis", "Position", [140 80 1280 820]);
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
obj.TabPlots  = uitab(obj.Tabs, "Title", "Plots");
obj.TabExport = uitab(obj.Tabs, "Title", "Export");
obj.TabLog    = uitab(obj.Tabs, "Title", "Log");

bar = uipanel(outer, "BorderType", "line", "BackgroundColor", [0.96 0.96 0.98]);
bar.Layout.Row = 2;
bg = uigridlayout(bar, [1 1]);
bg.Padding = [8 0 8 0];
obj.StatusBar = uilabel(bg, "Text", "Ready.", "FontColor", [0.15 0.15 0.15]);

obj.buildDataTab();
obj.buildAlignTab();
obj.buildPlotsTab();
obj.buildExportTab();
obj.buildLogTab();
styleButtons(obj);
obj.Tabs.SelectedTab = obj.TabData;
obj.Fig.WindowKeyPressFcn = @(~, evt) obj.onKeyPress(evt);   % Ctrl+1 ... Ctrl+9: the plot editor's sections
obj.refreshDesigns();
PlotDesign.listen(obj.Fig, @() obj.refreshDesigns());   % a design chosen anywhere (a plot's right-click menu too)
end


function styleButtons(obj)
%styleButtons  Every button a size up; the main actions in colour (styleButton).
%   The plot editor's section headers (formSection) keep their header look.
b = findall(obj.Fig, "Type", "uibutton", "-or", "Type", "uistatebutton");
styleButton(b(~strcmp(get(b, "Tag"), "formSectionToggle")));
styleButton([obj.ScanButton, obj.PreviewButton, obj.RunButton], "primary");
styleButton(obj.CancelButton, "danger");
end
