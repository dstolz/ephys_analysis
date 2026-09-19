function loadPreferences(obj, openLast)
%loadPreferences  Restore the app's preferences; OPENLAST: reopen the last config.
%   Group EphysAnalysisApp: FigurePosition, LastConfigFile, RecentConfigs,
%   ScriptFolder, AutoPreview, PreviewMaxMB. Everything else is the config.
if nargin < 2; openLast = true; end
g = obj.PrefGroup;
if ispref(g, 'FigurePosition')
    pos = getpref(g, 'FigurePosition');
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
if ispref(g, 'RecentConfigs'); obj.RecentConfigs = reshape(string(getpref(g, 'RecentConfigs')), 1, []); end
if ispref(g, 'ScriptFolder'); obj.ScriptFolder = string(getpref(g, 'ScriptFolder')); end
if ispref(g, 'AutoPreview'); obj.AutoPreviewCheckBox.Value = isequal(getpref(g, 'AutoPreview'), true); end
if ispref(g, 'PreviewMaxMB')
    v = getpref(g, 'PreviewMaxMB');
    if isnumeric(v) && isscalar(v) && v > 0; obj.PreviewMaxMB = v; end
end
obj.refreshRecentMenu();
opened = false;
if openLast && ispref(g, 'LastConfigFile')
    f = string(getpref(g, 'LastConfigFile'));
    if f ~= "" && isfile(f)
        opened = obj.openConfigFile(f);
    end
end
if ~opened
    obj.applyConfig(EphysAnalysisConfig(), MarkSaved=true);
end
end
