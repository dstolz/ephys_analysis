function loadPreferences(obj, openLast)
%loadPreferences  Restore the app's preferences; OPENLAST: reopen the last config.
%   Group EphysAnalysisApp: FigurePosition, LastConfigFile, RecentConfigs,
%   ScriptFolder, AutoPreview, PreviewMaxMB, PlotSectionsCollapsed (the
%   plot editor's collapsed sections), PlotGroupBy and PlotGroupsCollapsed
%   (the plot tree's grouping and collapsed groups), ChronuxCacheFolder,
%   ChronuxMaxMB, ChronuxSettings and ChronuxSectionsCollapsed (the
%   Chronux tab's). Everything else is the config.
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
if AppPrefs.ispref(g, 'AutoPreview'); obj.AutoPreviewCheckBox.Value = isequal(AppPrefs.getpref(g, 'AutoPreview'), true); end
if AppPrefs.ispref(g, 'PreviewMaxMB')
    v = AppPrefs.getpref(g, 'PreviewMaxMB');
    if isnumeric(v) && isscalar(v) && v > 0; obj.PreviewMaxMB = v; end
end
if AppPrefs.ispref(g, 'PlotGroupBy')
    by = string(AppPrefs.getpref(g, 'PlotGroupBy'));
    if isscalar(by) && ismember(by, string(obj.PlotGroupDropDown.ItemsData))
        obj.PlotGroupDropDown.Value = by;
    end
end
if AppPrefs.ispref(g, 'PlotGroupsCollapsed')
    obj.PlotGroupsCollapsed = reshape(string(AppPrefs.getpref(g, 'PlotGroupsCollapsed')), 1, []);
end
if AppPrefs.ispref(g, 'PlotSectionsCollapsed')
    shut = string(AppPrefs.getpref(g, 'PlotSectionsCollapsed'));
    for i = 1:numel(obj.PlotSections)
        obj.PlotSections(i).Expanded = ~ismember(obj.PlotSections(i).Name, shut);
    end
    obj.layoutPlotEditor();
end
if AppPrefs.ispref(g, 'ChronuxCacheFolder'); obj.ChronuxCacheFolder = string(AppPrefs.getpref(g, 'ChronuxCacheFolder')); end
if AppPrefs.ispref(g, 'ChronuxMaxMB')
    v = AppPrefs.getpref(g, 'ChronuxMaxMB');
    if isnumeric(v) && isscalar(v) && v > 0; obj.ChronuxMaxMB = v; end
end
if AppPrefs.ispref(g, 'ChronuxSectionsCollapsed')
    shut = string(AppPrefs.getpref(g, 'ChronuxSectionsCollapsed'));
    for i = 1:numel(obj.ChronuxSections)
        obj.ChronuxSections(i).Expanded = ~ismember(obj.ChronuxSections(i).Name, shut);
    end
end
if AppPrefs.ispref(g, 'ChronuxSettings')
    try
        obj.applyChronuxSettings(AppPrefs.getpref(g, 'ChronuxSettings'));
    catch
        % unreadable: the defaults stay
    end
end
obj.syncChronuxControls();
obj.refreshChronuxTab();
obj.refreshRecentMenu();
opened = false;
if openLast && AppPrefs.ispref(g, 'LastConfigFile')
    f = string(AppPrefs.getpref(g, 'LastConfigFile'));
    if f ~= "" && isfile(f)
        opened = obj.openConfigFile(f);
    end
end
if ~opened
    obj.applyConfig(EphysAnalysisConfig(), MarkSaved=true);
end
end
