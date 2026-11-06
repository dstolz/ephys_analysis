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
AppPrefs.setpref(g, 'FigureAutoRedraw', double(obj.FigureAutoSlider.Value));
AppPrefs.setpref(g, 'FigureGroupBy', char(obj.FigureGroupDropDown.Value));
AppPrefs.setpref(g, 'FigureGroupsCollapsed', cellstr(obj.FigureGroupsCollapsed));
AppPrefs.setpref(g, 'FigureRectUnits', char(obj.FigureRectUnits));
AppPrefs.setpref(g, 'FigureSnap', logical(obj.FigureSnap));
AppPrefs.setpref(g, 'FigureSnapStep', struct('value', double(obj.FigureSnapStep.value), 'units', char(obj.FigureSnapStep.units)));
AppPrefs.setpref(g, 'FigureAlignBy', char(obj.FigureAlignBy));
AppPrefs.setpref(g, 'FigureAlignTo', char(obj.FigureAlignTo));
G = obj.FigureAlignGap;
if isstruct(G); G = struct('value', double(G.value), 'units', char(G.units)); end
AppPrefs.setpref(g, 'FigureAlignGap', G);   % ([]: even gaps)
S = obj.FigureSections;
AppPrefs.setpref(g, 'FigureSectionsCollapsed', cellstr([string.empty(1, 0) S(~[S.Expanded]).Name]));
AppPrefs.setpref(g, 'ApplyTicked', cellstr(obj.ApplyTicked));
AppPrefs.setpref(g, 'ApplySeen', cellstr(obj.ApplySeen));
AppPrefs.setpref(g, 'ApplyReplot', obj.ApplyReplot);
AppPrefs.setpref(g, 'PanelOptions', obj.PanelOptions);
AppPrefs.setpref(g, 'ReportWorkers', obj.WorkersSpinner.Value);
U = obj.FigureSupers;
AppPrefs.setpref(g, 'FigureSupersectionsCollapsed', cellstr([string.empty(1, 0) U(~[U.Expanded]).Name]));
end
