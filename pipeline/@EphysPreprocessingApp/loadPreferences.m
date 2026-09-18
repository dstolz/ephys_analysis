function loadPreferences(obj)
%loadPreferences  Restore app preferences and open the last config.
%   Preferences (group EphysPreprocessingApp) hold only what is not part of
%   a pipeline config: figure geometry, the probe folder, the phy command,
%   the Review folder, the last / recent config files, the script folder,
%   the datasets-table column order, the Trials-table parameter columns and
%   column order, the Trials-plot label parameters, the Visualize
%   display options, the Copy tab settings (subject, roots, pairing and
%   copy options; not the dates), the Run tab's Show the run diagram and
%   Monitor CPU, memory, disk and GPU, and the kinds of file the Clean up
%   tab removes.
%   Everything else lives in the config; the last config file is reopened
%   at launch (defaults otherwise).

g = obj.PrefGroup;

if ispref(g, 'FigurePosition')
    pos = getpref(g, 'FigurePosition');
    if isnumeric(pos) && numel(pos) == 4 && all(pos(3:4) > 100)
        obj.Fig.Position = clampToScreen(pos);
    end
end

if ispref(g, 'ProbeFolder')
    p = getpref(g, 'ProbeFolder');
    if isfolder(p); obj.ProbeFolderField.Value = p; end
end
if obj.ProbeFolderField.Value == ""
    obj.ProbeFolderField.Value = char(obj.defaultProbeFolder());
end
if ispref(g, 'PhyCmd')
    obj.PhyCmdField.Value = char(getpref(g, 'PhyCmd'));
end
if ispref(g, 'ReviewFolder')
    p = getpref(g, 'ReviewFolder');
    if isfolder(p); obj.ReviewFolderField.Value = p; end
end
if ispref(g, 'ScriptFolder')
    obj.ScriptFolder = string(getpref(g, 'ScriptFolder'));
end
if ispref(g, 'RecentConfigs')
    r = getpref(g, 'RecentConfigs');
    obj.RecentConfigs = reshape(string(r), 1, []);
end
obj.refreshRecentMenu();
if ispref(g, 'DatasetsColumnOrder')
    obj.DatasetsColumnOrder = reshape(string(getpref(g, 'DatasetsColumnOrder')), 1, []);
end
if ispref(g, 'TrialsParamColumns')
    obj.TrialsParamColumns = reshape(string(getpref(g, 'TrialsParamColumns')), 1, []);
end
if ispref(g, 'TrialsLabelParams')
    obj.TrialsLabelParams = reshape(string(getpref(g, 'TrialsLabelParams')), 1, []);
end
if ispref(g, 'TrialsColumnOrder')
    obj.TrialsColumnOrder = reshape(string(getpref(g, 'TrialsColumnOrder')), 1, []);
end
if ispref(g, 'ShowRunDiagram')
    obj.RunDiagramCheckBox.Value = isequal(getpref(g, 'ShowRunDiagram'), true);
    obj.onRunDiagramToggled();
end
if ispref(g, 'MonitorResources')
    obj.RunMonitorCheckBox.Value = isequal(getpref(g, 'MonitorResources'), true);
    obj.onResourceMonitorToggled();
end

% --- Visualize display options (one struct) ---
if ispref(g, 'VizOptions')
    v = getpref(g, 'VizOptions');
    if isstruct(v)
        applyIf(v, 'channels',  @(x) set(obj.VizChannelsField, 'Value', char(x)));
        applyIf(v, 'duration',  @(x) set(obj.VizDurField, 'Value', x));
        applyIf(v, 'highpass',  @(x) set(obj.VizHighpassField, 'Value', char(x)));
        applyIf(v, 'lowpass',   @(x) set(obj.VizLowpassField, 'Value', char(x)));
        applyIf(v, 'order',     @(x) set(obj.VizOrderField, 'Value', x));
        applyIf(v, 'reference', @(x) set(obj.VizRefDropDown, 'Value', char(x)));
        applyIf(v, 'detrend',   @(x) set(obj.VizDetrendCheckBox, 'Value', logical(x)));
        applyIf(v, 'spacing',   @(x) set(obj.VizSpacingField, 'Value', x));
    end
end

% --- Copy tab settings (one struct) ---
if ispref(g, 'CopyOptions')
    v = getpref(g, 'CopyOptions');
    if isstruct(v)
        applyIf(v, 'subject',    @(x) set(obj.CopySubjectField, 'Value', char(x)));
        applyIf(v, 'epsychRoot', @(x) set(obj.CopyEpsychRootField, 'Value', char(x)));
        applyIf(v, 'intanRoot',  @(x) set(obj.CopyIntanRootField, 'Value', char(x)));
        applyIf(v, 'destRoot',   @(x) set(obj.CopyDestRootField, 'Value', char(x)));
        applyIf(v, 'maxLeadMin', @(x) set(obj.CopyMaxLeadField, 'Value', x));
        applyIf(v, 'maxLagMin',  @(x) set(obj.CopyMaxLagField, 'Value', x));
        applyIf(v, 'marginSec',  @(x) set(obj.CopyMarginField, 'Value', x));
        applyIf(v, 'minDurationMin', @(x) set(obj.CopyMinDurationField, 'Value', x));
        applyIf(v, 'verify',     @(x) set(obj.CopyVerifyDropDown, 'Value', char(x)));
        applyIf(v, 'ifExists',   @(x) set(obj.CopyIfExistsDropDown, 'Value', char(x)));
        applyIf(v, 'openAfter',  @(x) set(obj.CopyScanAfterCheckBox, 'Value', logical(x)));
    end
end

% --- Clean up tab: the kinds of file to remove (one struct) ---
if ispref(g, 'CleanupOptions')
    v = getpref(g, 'CleanupOptions');
    if isstruct(v)
        applyIf(v, 'raw',        @(x) set(obj.CleanupRawCheckBox, 'Value', logical(x)));
        applyIf(v, 'sorterCopy', @(x) set(obj.CleanupSorterCopyCheckBox, 'Value', logical(x)));
        applyIf(v, 'bin',        @(x) set(obj.CleanupBinCheckBox, 'Value', logical(x)));
        applyIf(v, 'showKept',   @(x) set(obj.CleanupShowKeptCheckBox, 'Value', logical(x)));
    end
end

% --- the config: last file, else defaults ---
opened = false;
if ispref(g, 'LastConfigFile')
    f = string(getpref(g, 'LastConfigFile'));
    if f ~= "" && isfile(f)
        opened = obj.openConfigFile(f);
    end
end
if ~opened
    cfg = EphysPipelineConfig();
    cfg.Sorting.PythonExe = obj.defaultPythonExe();
    obj.applyConfig(cfg, MarkSaved=true);
end
end


function applyIf(s, field, setter)
if isfield(s, field)
    try
        setter(s.(field));
    catch
    end
end
end


function pos = clampToScreen(pos)
%clampToScreen  Keep the figure on-screen if the display layout changed.
try
    r = groot().ScreenSize;   % [x y w h]
    pos(1) = min(max(pos(1), 1), max(1, r(3) - 100));
    pos(2) = min(max(pos(2), 1), max(1, r(4) - 100));
    pos(3) = min(pos(3), r(3));
    pos(4) = min(pos(4), r(4));
catch
end
end
