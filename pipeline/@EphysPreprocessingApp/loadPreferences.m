function loadPreferences(obj)
%loadPreferences  Restore app preferences and open the last config.
%   Preferences (group EphysPreprocessingApp) hold only what is not part of
%   a pipeline config: figure geometry, the probe folder, the phy command,
%   the Review folder, the last / recent config files, the script folder,
%   the datasets-table column order, the Trials-table parameter columns and
%   column order, the Trials-plot label parameters, the Visualize
%   display options, the Copy tab settings (subject, roots, pairing and
%   copy options; not the dates), the Synthetic tab's settings and
%   design, the Diagram tab's view and layout, the Run tab's Show the run diagram,
%   Monitor CPU, memory, disk and GPU and Queue the waiting runs, and the
%   kinds of file the Clean up tab removes.
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
if ispref(g, 'DiagramView') && ismember(string(getpref(g, 'DiagramView')), ["detail" "overview"])
    obj.FlowViewDropDown.Value = string(getpref(g, 'DiagramView'));
end
if ispref(g, 'DiagramLayout') && ismember(string(getpref(g, 'DiagramLayout')), ["tree" "steps"])
    obj.FlowLayoutDropDown.Value = string(getpref(g, 'DiagramLayout'));
end
if ispref(g, 'ShowRunDiagram')
    obj.RunDiagramCheckBox.Value = isequal(getpref(g, 'ShowRunDiagram'), true);
    obj.onRunDiagramToggled();
end
if ispref(g, 'MonitorResources')
    obj.RunMonitorCheckBox.Value = isequal(getpref(g, 'MonitorResources'), true);
    obj.onResourceMonitorToggled();
end
if ispref(g, 'QueueSortingRuns')
    obj.RunKSQueueCheckBox.Value = isequal(getpref(g, 'QueueSortingRuns'), true);
end

% --- Visualize display options (one struct) ---
if ispref(g, 'VizOptions')
    v = getpref(g, 'VizOptions');
    if isstruct(v)
        applyIf(v, 'source',    @(x) setVizSourceKind(obj, x));   % the app is no SetGet: set() would throw
        applyIf(v, 'channels',  @(x) set(obj.VizChannelsField, 'Value', char(x)));
        applyIf(v, 'lanes',     @(x) set(obj.VizLanesField, 'Value', x));
        applyIf(v, 'duration',  @(x) set(obj.VizDurField, 'Value', x));
        applyIf(v, 'highpass',  @(x) set(obj.VizHighpassField, 'Value', char(x)));
        applyIf(v, 'lowpass',   @(x) set(obj.VizLowpassField, 'Value', char(x)));
        applyIf(v, 'order',     @(x) set(obj.VizOrderField, 'Value', x));
        applyIf(v, 'referenceMode', @(x) set(obj.VizRefDropDown, 'Value', char(x)));
        applyIf(v, 'removeOffset', @(x) set(obj.VizOffsetCheckBox, 'Value', logical(x)));
        applyIf(v, 'units',     @(x) set(obj.VizUnitsCheckBox, 'Value', logical(x)));
        applyIf(v, 'unitStyle', @(x) set(obj.VizUnitStyleDropDown, 'Value', char(x)));
        applyIf(v, 'unitGroups', @(x) set(obj.VizUnitGroupsDropDown, 'Value', char(x)));
        applyIf(v, 'detected',  @(x) set(obj.VizDetectedCheckBox, 'Value', logical(x)));
        applyIf(v, 'detectedStyle', @(x) set(obj.VizDetectedStyleDropDown, 'Value', char(x)));
        applyIf(v, 'placement', @(x) set(obj.VizPlacementDropDown, 'Value', char(x)));
        applyIf(v, 'mode',      @(x) set(obj.VizModeDropDown, 'Value', char(x)));
        applyIf(v, 'colormap',  @(x) set(obj.VizColormapDropDown, 'Value', char(x)));
        applyIf(v, 'probeOrder', @(x) set(obj.VizSortByProbeCheckBox, 'Value', logical(x)));
        applyIf(v, 'shankColor', @(x) set(obj.VizColorByShankCheckBox, 'Value', logical(x)));
        applyIf(v, 'shading',   @(x) set(obj.VizShadingCheckBox, 'Value', logical(x)));
        applyIf(v, 'events',    @(x) set(obj.VizEventsDropDown, 'Value', char(x)));
    end
end

% --- Copy tab settings (one struct) ---
if ispref(g, 'CopyOptions')
    v = getpref(g, 'CopyOptions');
    if isstruct(v)
        applyIf(v, 'subject',    @(x) set(obj.CopySubjectField, 'Value', char(x)));
        applyIf(v, 'epsychRoot', @(x) set(obj.CopyEpsychRootField, 'Value', char(x)));
        applyIf(v, 'recordingRoots', @(x) set(obj.CopyRecordingRootsField, 'Value', char(x)));
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

% --- Synthetic tab: its settings and the design (one struct; the design as JSON) ---
if ispref(g, 'SynthOptions')
    v = getpref(g, 'SynthOptions');
    if isstruct(v)
        applyIf(v, 'source',      @(x) set(obj.SynthSourceDropDown, 'Value', char(x)));
        applyIf(v, 'numTrials',   @(x) set(obj.SynthTrialsSpinner, 'Value', x));
        applyIf(v, 'scenario',    @(x) set(obj.SynthScenarioDropDown, 'Value', char(x)));
        applyIf(v, 'trialDuration', @(x) set(obj.SynthTrialDurField, 'Value', char(x)));
        applyIf(v, 'lines',       @(x) set(obj.SynthLinesTable, 'Data', reshape(cellstr(x), [], 3)));
        applyIf(v, 'format',      @(x) set(obj.SynthFormatDropDown, 'Value', char(x)));
        applyIf(v, 'Fs',          @(x) set(obj.SynthFsField, 'Value', x));
        applyIf(v, 'numChannels', @(x) set(obj.SynthChannelsField, 'Value', x));
        applyIf(v, 'fileSeconds', @(x) set(obj.SynthFileSecondsField, 'Value', x));
        applyIf(v, 'maxDuration', @(x) set(obj.SynthMaxDurField, 'Value', x));
        applyIf(v, 'seed',        @(x) set(obj.SynthSeedField, 'Value', x));
        applyIf(v, 'subject',     @(x) set(obj.SynthSubjectField, 'Value', char(x)));
        applyIf(v, 'sorted',      @(x) set(obj.SynthSortedCheckBox, 'Value', logical(x)));
        applyIf(v, 'artifacts',   @(x) set(obj.SynthArtifactsCheckBox, 'Value', logical(x)));
        applyIf(v, 'output',      @(x) set(obj.SynthOutputField, 'Value', char(x)));
        applyIf(v, 'span',        @(x) set(obj.SynthTimelineSpanField, 'Value', x));
        applyIf(v, 'design',      @(x) obj.applySynthDesign(SyntheticDesign.fromStruct(jsondecode(char(x)))));
        obj.syncSynthControls();
    end
end

% --- Clean up tab: the kinds of file to remove and where they go (one struct) ---
if ispref(g, 'CleanupOptions')
    v = getpref(g, 'CleanupOptions');
    if isstruct(v)
        applyIf(v, 'raw',        @(x) set(obj.CleanupRawCheckBox, 'Value', logical(x)));
        applyIf(v, 'sorterCopy', @(x) set(obj.CleanupSorterCopyCheckBox, 'Value', logical(x)));
        applyIf(v, 'bin',        @(x) set(obj.CleanupBinCheckBox, 'Value', logical(x)));
        applyIf(v, 'steps',      @(x) arrayfun(@(b) set(b, 'Value', ismember(b.Tag, cellstr(x))), obj.CleanupStepCheckBoxes));
        applyIf(v, 'method',     @(x) set(obj.CleanupMethodDropDown, 'Value', char(x)));
        applyIf(v, 'destination', @(x) set(obj.CleanupDestField, 'Value', char(x)));
        applyIf(v, 'showKept',   @(x) set(obj.CleanupShowKeptCheckBox, 'Value', logical(x)));
        obj.onCleanupMethodChanged();
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


function setVizSourceKind(obj, x)
obj.VizSourceKind = string(x);
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
