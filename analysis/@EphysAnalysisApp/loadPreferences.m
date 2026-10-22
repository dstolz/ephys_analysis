function loadPreferences(obj, openLast)
%loadPreferences  Restore the app's preferences; OPENLAST: reopen the last config.
%   Group EphysAnalysisApp: FigurePosition, LastConfigFile, RecentConfigs,
%   ScriptFolder, PreviewMaxMB (signal previews of larger extracts wait
%   for the Preview button), FigureAutoPreview, FigureSectionsCollapsed and
%   FigureSupersectionsCollapsed (the Figures tab's Auto box, on by
%   default, and its editor's collapsed sections and supersections),
%   FigureGroupBy and FigureGroupsCollapsed (the figure tree's
%   grouping and collapsed groups), ApplyTicked, ApplySeen and ApplyReplot
%   (Apply to figures' ticks and its Replot box: onApplyToFigures).
%   Everything else is the config.
if nargin < 2; openLast = true; end
g = obj.PrefGroup;
if AppPrefs.ispref(g, 'FigurePosition')
    pos = AppPrefs.getpref(g, 'FigurePosition');
    if isnumeric(pos) && numel(pos) == 4 && all(pos(3:4) > 200)
        try
            r = groot().ScreenSize;
            pos(1) = min(max(pos(1), 1), max(1, r(3) - 200));
            pos(2) = min(max(pos(2), 1), max(1, r(4) - 200));
        catch
        end
        obj.Fig.Position = pos;
    end
end
if AppPrefs.ispref(g, 'RecentConfigs'); obj.RecentConfigs = reshape(string(AppPrefs.getpref(g, 'RecentConfigs')), 1, []); end
if AppPrefs.ispref(g, 'ScriptFolder'); obj.ScriptFolder = string(AppPrefs.getpref(g, 'ScriptFolder')); end
if AppPrefs.ispref(g, 'PreviewMaxMB')
    v = AppPrefs.getpref(g, 'PreviewMaxMB');
    if isnumeric(v) && isscalar(v) && v > 0; obj.PreviewMaxMB = v; end
end
if AppPrefs.ispref(g, 'FigureAutoPreview'); obj.FigureAutoCheckBox.Value = isequal(AppPrefs.getpref(g, 'FigureAutoPreview'), true); end
if AppPrefs.ispref(g, 'FigureGroupBy')
    by = string(AppPrefs.getpref(g, 'FigureGroupBy'));
    if isscalar(by) && ismember(by, string(obj.FigureGroupDropDown.ItemsData))
        obj.FigureGroupDropDown.Value = by;
    end
end
if AppPrefs.ispref(g, 'FigureGroupsCollapsed')
    obj.FigureGroupsCollapsed = reshape(string(AppPrefs.getpref(g, 'FigureGroupsCollapsed')), 1, []);
end
if AppPrefs.ispref(g, 'ApplyTicked'); obj.ApplyTicked = reshape(string(AppPrefs.getpref(g, 'ApplyTicked')), 1, []); end
if AppPrefs.ispref(g, 'ApplySeen'); obj.ApplySeen = reshape(string(AppPrefs.getpref(g, 'ApplySeen')), 1, []); end
if AppPrefs.ispref(g, 'ApplyReplot'); obj.ApplyReplot = isequal(AppPrefs.getpref(g, 'ApplyReplot'), true); end
if AppPrefs.ispref(g, 'FigureSectionsCollapsed')
    shut = string(AppPrefs.getpref(g, 'FigureSectionsCollapsed'));
    for i = 1:numel(obj.FigureSections)
        obj.FigureSections(i).Expanded = ~ismember(obj.FigureSections(i).Name, shut);
    end
    obj.layoutFigureEditor();
end
if AppPrefs.ispref(g, 'FigureSupersectionsCollapsed')
    shut = string(AppPrefs.getpref(g, 'FigureSupersectionsCollapsed'));
    for u = 1:numel(obj.FigureSupers)
        obj.FigureSupers(u).Expanded = ~ismember(obj.FigureSupers(u).Name, shut);
    end
    obj.layoutFigureEditor();
end
obj.refreshRecentMenu();
opened = false;
if openLast && AppPrefs.ispref(g, 'LastConfigFile')
    f = string(AppPrefs.getpref(g, 'LastConfigFile'));
    if f ~= "" && isfile(f)
        obj.Splash.step("config", "Opening the config " + f + " ...");
        opened = obj.openConfigFile(f);
    end
end
if ~opened
    obj.applyConfig(EphysAnalysisConfig(), MarkSaved=true);
end
end
