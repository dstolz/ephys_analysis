function loadPreferences(obj, openLast)
%loadPreferences  Restore the app's preferences; OPENLAST: reopen the last config.
%   Group EphysFigGenApp: FigurePosition, LastConfigFile, RecentConfigs,
%   ScriptFolder, PreviewMaxMB (signal previews of larger extracts wait
%   for the Preview button), FigureAutoRedraw, FigureSectionsCollapsed and
%   FigureSupersectionsCollapsed (the Figures tab's Auto slider, 0 to 1,
%   AutoRedrawDefault when not set, and its editor's collapsed sections and supersections),
%   FigureGroupBy and FigureGroupsCollapsed (the figure tree's
%   grouping and collapsed groups), FigureRectUnits, FigureSnap and
%   FigureSnapStep (the Layout section's units, Snap box and step:
%   onRectUnitsChanged, onSnapChanged), FigureAlignBy, FigureAlignTo and
%   FigureAlignGap (Arrange's align bar: syncAlignBar shows them),
%   ApplyTicked, ApplySeen and ApplyReplot
%   (Apply to figures' ticks and its Replot box: onApplyToFigures),
%   PanelOptions (the options last set on a panel of each type, which a
%   new panel starts from: rememberPanelOptions, onNewPanel), ReportWorkers
%   (the Export tab's Workers: the process workers a run draws its pages
%   on; 4 when not set).
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
if AppPrefs.ispref(g, 'FigureAutoRedraw')
    t = AppPrefs.getpref(g, 'FigureAutoRedraw');
    if isnumeric(t) && isscalar(t) && t >= 0 && t <= 1
        obj.FigureAutoSlider.Value = t;
        if t > 0; obj.FigureAutoLast = t; end
        showAutoRedraw(obj);
    end
end
if AppPrefs.ispref(g, 'FigureGroupBy')
    by = string(AppPrefs.getpref(g, 'FigureGroupBy'));
    if isscalar(by) && ismember(by, string(obj.FigureGroupDropDown.ItemsData))
        obj.FigureGroupDropDown.Value = by;
    end
end
if AppPrefs.ispref(g, 'FigureGroupsCollapsed')
    obj.FigureGroupsCollapsed = reshape(string(AppPrefs.getpref(g, 'FigureGroupsCollapsed')), 1, []);
end
if AppPrefs.ispref(g, 'FigureRectUnits')
    u = string(AppPrefs.getpref(g, 'FigureRectUnits'));
    if isscalar(u) && ismember(u, EphysAnalysisConfig.RectUnits); obj.FigureRectUnits = u; end
end
if AppPrefs.ispref(g, 'FigureSnap'); obj.FigureSnap = isequal(AppPrefs.getpref(g, 'FigureSnap'), true); end
if AppPrefs.ispref(g, 'FigureSnapStep')
    v = AppPrefs.getpref(g, 'FigureSnapStep');
    if isstruct(v) && isscalar(v) && isfield(v, 'value') && isfield(v, 'units') && isnumeric(v.value) && isscalar(v.value) ...
            && isfinite(v.value) && v.value > 0 && isscalar(string(v.units)) && ismember(string(v.units), EphysAnalysisConfig.RectUnits)
        obj.FigureSnapStep = struct('value', double(v.value), 'units', string(v.units));   % shown in the units picked (showPanelPlace)
    end
end
if AppPrefs.ispref(g, 'FigureAlignBy')
    v = string(AppPrefs.getpref(g, 'FigureAlignBy'));
    if isscalar(v) && ismember(v, ["box" "axes" "labels"]); obj.FigureAlignBy = v; end
end
if AppPrefs.ispref(g, 'FigureAlignTo')
    v = string(AppPrefs.getpref(g, 'FigureAlignTo'));
    if isscalar(v) && ismember(v, ["selection" "first" "page"]); obj.FigureAlignTo = v; end
end
if AppPrefs.ispref(g, 'FigureAlignGap')
    v = AppPrefs.getpref(g, 'FigureAlignGap');
    if isstruct(v) && isscalar(v) && isfield(v, 'value') && isfield(v, 'units') && isnumeric(v.value) && isscalar(v.value) ...
            && isfinite(v.value) && v.value >= 0 && isscalar(string(v.units)) && ismember(string(v.units), EphysAnalysisConfig.RectUnits)
        obj.FigureAlignGap = struct('value', double(v.value), 'units', string(v.units));   % (shown by syncAlignBar)
    else
        obj.FigureAlignGap = [];
    end
end
if AppPrefs.ispref(g, 'ApplyTicked'); obj.ApplyTicked = reshape(string(AppPrefs.getpref(g, 'ApplyTicked')), 1, []); end
if AppPrefs.ispref(g, 'ApplySeen'); obj.ApplySeen = reshape(string(AppPrefs.getpref(g, 'ApplySeen')), 1, []); end
if AppPrefs.ispref(g, 'ApplyReplot'); obj.ApplyReplot = isequal(AppPrefs.getpref(g, 'ApplyReplot'), true); end
if AppPrefs.ispref(g, 'ReportWorkers')
    v = AppPrefs.getpref(g, 'ReportWorkers');
    if isnumeric(v) && isscalar(v) && isfinite(v)
        obj.WorkersSpinner.Value = min(max(round(v), obj.WorkersSpinner.Limits(1)), obj.WorkersSpinner.Limits(2));
    end
end
if AppPrefs.ispref(g, 'PanelOptions')
    v = AppPrefs.getpref(g, 'PanelOptions');
    if isstruct(v) && isscalar(v); obj.PanelOptions = v; end   % checked against each type when a panel takes them (rememberedPanelOptions)
end
% (the editor is laid out with them by applyConfig below: syncFigureEditor, layoutFigureEditor)
if AppPrefs.ispref(g, 'FigureSectionsCollapsed')
    shut = string(AppPrefs.getpref(g, 'FigureSectionsCollapsed'));
    for i = 1:numel(obj.FigureSections)
        obj.FigureSections(i).Expanded = ~ismember(obj.FigureSections(i).Name, shut);
    end
end
if AppPrefs.ispref(g, 'FigureSubheadingsCollapsed')   % (a name that is no sub-heading now is ignored)
    shut = string(AppPrefs.getpref(g, 'FigureSubheadingsCollapsed'));
    for i = 1:numel(obj.FigureSections)
        S = obj.FigureSections(i);
        obj.FigureSections(i).Collapsed = S.SubCollapsible & ismember(S.Name + "." + S.SubKey, shut);
    end
end
if AppPrefs.ispref(g, 'FigureSupersectionsCollapsed')
    shut = string(AppPrefs.getpref(g, 'FigureSupersectionsCollapsed'));
    for u = 1:numel(obj.FigureSupers)
        obj.FigureSupers(u).Expanded = ~ismember(obj.FigureSupers(u).Name, shut);
    end
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
