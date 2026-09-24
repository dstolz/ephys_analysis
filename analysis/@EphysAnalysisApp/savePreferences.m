function savePreferences(obj)
%savePreferences  Persist the app's preferences (not the config; see loadPreferences).
g = obj.PrefGroup;
if ~isempty(obj.Fig) && isvalid(obj.Fig)
    setpref(g, 'FigurePosition', obj.Fig.Position);
end
setpref(g, 'LastConfigFile', char(obj.Config.File));
setpref(g, 'RecentConfigs', cellstr(obj.RecentConfigs));
setpref(g, 'ScriptFolder', char(obj.ScriptFolder));
setpref(g, 'AutoPreview', logical(obj.AutoPreviewCheckBox.Value));
setpref(g, 'PreviewMaxMB', obj.PreviewMaxMB);
S = obj.PlotSections;
setpref(g, 'PlotSectionsCollapsed', cellstr([string.empty(1, 0) S(~[S.Expanded]).Name]));
end
