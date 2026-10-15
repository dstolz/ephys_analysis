function savePreferences(obj)
%savePreferences  Persist the app's preferences (not the config; see loadPreferences).
g = obj.PrefGroup;
if ~isempty(obj.Fig) && isvalid(obj.Fig)
    AppPrefs.setpref(g, 'FigurePosition', obj.Fig.Position);
end
AppPrefs.setpref(g, 'LastConfigFile', char(obj.Config.File));
AppPrefs.setpref(g, 'RecentConfigs', cellstr(obj.RecentConfigs));
AppPrefs.setpref(g, 'ScriptFolder', char(obj.ScriptFolder));
AppPrefs.setpref(g, 'PreviewMaxMB', obj.PreviewMaxMB);
AppPrefs.setpref(g, 'FigureAutoPreview', logical(obj.FigureAutoCheckBox.Value));
AppPrefs.setpref(g, 'FigureGroupBy', char(obj.FigureGroupDropDown.Value));
AppPrefs.setpref(g, 'FigureGroupsCollapsed', cellstr(obj.FigureGroupsCollapsed));
S = obj.FigureSections;
AppPrefs.setpref(g, 'FigureSectionsCollapsed', cellstr([string.empty(1, 0) S(~[S.Expanded]).Name]));
AppPrefs.setpref(g, 'ChronuxCacheFolder', char(obj.ChronuxCacheFolder));
AppPrefs.setpref(g, 'ChronuxMaxMB', obj.ChronuxMaxMB);
S = obj.ChronuxSections;
AppPrefs.setpref(g, 'ChronuxSectionsCollapsed', cellstr([string.empty(1, 0) S(~[S.Expanded]).Name]));
try
    AppPrefs.setpref(g, 'ChronuxSettings', obj.gatherChronuxSettings());
catch
    % a value that cannot be used: the last good settings stay
end
end
