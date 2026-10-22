function savePreferences(obj)
%savePreferences  Persist the app's preferences (not the config; see loadPreferences).
%   LastConfigFile is written only for a config with a file: after File >
%   New the last one saved or opened stays the one the next launch reopens.
g = obj.PrefGroup;
if ~isempty(obj.Fig) && isvalid(obj.Fig)
    AppPrefs.setpref(g, 'FigurePosition', obj.Fig.Position);
end
if obj.Config.File ~= ""
    AppPrefs.setpref(g, 'LastConfigFile', char(obj.Config.File));
end
AppPrefs.setpref(g, 'RecentConfigs', cellstr(obj.RecentConfigs));
AppPrefs.setpref(g, 'ScriptFolder', char(obj.ScriptFolder));
AppPrefs.setpref(g, 'PreviewMaxMB', obj.PreviewMaxMB);
AppPrefs.setpref(g, 'FigureAutoPreview', logical(obj.FigureAutoCheckBox.Value));
AppPrefs.setpref(g, 'FigureGroupBy', char(obj.FigureGroupDropDown.Value));
AppPrefs.setpref(g, 'FigureGroupsCollapsed', cellstr(obj.FigureGroupsCollapsed));
S = obj.FigureSections;
AppPrefs.setpref(g, 'FigureSectionsCollapsed', cellstr([string.empty(1, 0) S(~[S.Expanded]).Name]));
AppPrefs.setpref(g, 'ApplyTicked', cellstr(obj.ApplyTicked));
AppPrefs.setpref(g, 'ApplySeen', cellstr(obj.ApplySeen));
AppPrefs.setpref(g, 'ApplyReplot', obj.ApplyReplot);
U = obj.FigureSupers;
AppPrefs.setpref(g, 'FigureSupersectionsCollapsed', cellstr([string.empty(1, 0) U(~[U.Expanded]).Name]));
end
