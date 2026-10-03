function savePreferences(obj)
%savePreferences  Persist the app's preferences (not the config; see loadPreferences).
g = obj.PrefGroup;
if ~isempty(obj.Fig) && isvalid(obj.Fig)
    AppPrefs.setpref(g, 'FigurePosition', obj.Fig.Position);
end
AppPrefs.setpref(g, 'LastConfigFile', char(obj.Config.File));
AppPrefs.setpref(g, 'RecentConfigs', cellstr(obj.RecentConfigs));
AppPrefs.setpref(g, 'ScriptFolder', char(obj.ScriptFolder));
AppPrefs.setpref(g, 'AutoPreview', logical(obj.AutoPreviewCheckBox.Value));
AppPrefs.setpref(g, 'PreviewMaxMB', obj.PreviewMaxMB);
S = obj.PlotSections;
AppPrefs.setpref(g, 'PlotSectionsCollapsed', cellstr([string.empty(1, 0) S(~[S.Expanded]).Name]));
end
