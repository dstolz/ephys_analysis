function buildUI(obj)
%buildUI  The figure, menus, the five tabs and the status bar.
obj.Fig = uifigure("Name", "Ephys analysis", "Position", [140 80 1280 820]);
obj.Fig.CloseRequestFcn = @(~,~) obj.onClose();
obj.buildMenus();

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
obj.Tabs.SelectedTab = obj.TabData;
end
