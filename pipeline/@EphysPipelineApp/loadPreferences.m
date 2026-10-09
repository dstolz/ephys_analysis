function loadPreferences(obj)
%loadPreferences  Restore app preferences and open the last config.
%   Preferences (group EphysPipelineApp) hold only what is not part of
%   a pipeline config: figure geometry, the probe folder, the phy command,
%   the Review folder, the last / recent config files, the script folder,
%   the datasets-table column order, the sort of each sortable table
%   (TableSorts: Project, Trials, Review units, Clean up and the
%   Artifacts tab's per-channel Selection table), the Artifacts tab's viewer options
%   (context, channels, scale, lanes, color by shank, shading), the Trials-table parameter columns and
%   column order, the Trials-plot label parameters, the Visualize
%   display options, the Copy tab settings (subject, roots and their recent
%   lists, pairing and copy options; not the dates), the Synthetic tab's settings and
%   design, the Diagram tab's view and layout, the Run tab's Queue the
%   waiting runs, and the kinds of file the Clean up tab removes, and the last Python exe set
%   (the Python a new config starts with, see defaultPythonExe).
%   Everything else lives in the config; the last config file is reopened
%   at launch (defaults otherwise). The Kilosort4 runs kept when the app
%   last closed are preferences too, taken back by followKeptKSRuns (the
%   runs going) and offerKeptKSQueue (a queue, once its root is scanned).

g = obj.PrefGroup;

if AppPrefs.ispref(g, 'FigurePosition')
    pos = AppPrefs.getpref(g, 'FigurePosition');
    if isnumeric(pos) && numel(pos) == 4 && all(pos(3:4) > 100)
        obj.Fig.Position = clampToScreen(pos);
    end
end

if AppPrefs.ispref(g, 'ProbeFolder')
    p = AppPrefs.getpref(g, 'ProbeFolder');
    if isfolder(p); obj.ProbeFolderField.Value = p; end
end
if obj.ProbeFolderField.Value == ""
    obj.ProbeFolderField.Value = char(obj.defaultProbeFolder());
end
if AppPrefs.ispref(g, 'PhyCmd')
    obj.PhyCmdField.Value = char(AppPrefs.getpref(g, 'PhyCmd'));
end
if AppPrefs.ispref(g, 'ReviewFolder')
    p = AppPrefs.getpref(g, 'ReviewFolder');
    if isfolder(p); obj.ReviewFolderField.Value = p; end
end
if AppPrefs.ispref(g, 'ScriptFolder')
    obj.ScriptFolder = string(AppPrefs.getpref(g, 'ScriptFolder'));
end
if AppPrefs.ispref(g, 'RecentConfigs')
    r = AppPrefs.getpref(g, 'RecentConfigs');
    obj.RecentConfigs = reshape(string(r), 1, []);
end
obj.refreshRecentMenu();
if AppPrefs.ispref(g, 'DatasetsColumnOrder')
    obj.DatasetsColumnOrder = reshape(string(AppPrefs.getpref(g, 'DatasetsColumnOrder')), 1, []);
end
if AppPrefs.ispref(g, 'TableSorts')   % before the last config fills the tables
    v = AppPrefs.getpref(g, 'TableSorts');
    if isstruct(v) && isscalar(v)
        for f = string(fieldnames(v)).'
            s = TableSort.fromPref(v.(f));
            if TableSort.isSorted(s); obj.TableSorts.(f) = s; end
        end
    end
end
if AppPrefs.ispref(g, 'TrialsParamColumns')
    obj.TrialsParamColumns = reshape(string(AppPrefs.getpref(g, 'TrialsParamColumns')), 1, []);
end
if AppPrefs.ispref(g, 'TrialsLabelParams')
    obj.TrialsLabelParams = reshape(string(AppPrefs.getpref(g, 'TrialsLabelParams')), 1, []);
end
if AppPrefs.ispref(g, 'TrialsColumnOrder')
    obj.TrialsColumnOrder = reshape(string(AppPrefs.getpref(g, 'TrialsColumnOrder')), 1, []);
end
if AppPrefs.ispref(g, 'DiagramView') && ismember(string(AppPrefs.getpref(g, 'DiagramView')), ["detail" "overview"])
    obj.FlowViewDropDown.Value = string(AppPrefs.getpref(g, 'DiagramView'));
end
if AppPrefs.ispref(g, 'DiagramLayout') && ismember(string(AppPrefs.getpref(g, 'DiagramLayout')), ["tree" "steps"])
    obj.FlowLayoutDropDown.Value = string(AppPrefs.getpref(g, 'DiagramLayout'));
end
if AppPrefs.ispref(g, 'DiagramHideUnused')
    obj.FlowHideCheckBox.Value = isequal(AppPrefs.getpref(g, 'DiagramHideUnused'), true);
end
if AppPrefs.ispref(g, 'QueueSortingRuns')
    obj.RunKSQueueCheckBox.Value = isequal(AppPrefs.getpref(g, 'QueueSortingRuns'), true);
end

% --- Visualize display options (one struct) ---
if AppPrefs.ispref(g, 'VizOptions')
    v = AppPrefs.getpref(g, 'VizOptions');
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
        applyIf(v, 'traceColor', @(x) set(obj.VizTraceColorDropDown, 'Value', char(x)));
        applyIf(v, 'shading',   @(x) set(obj.VizShadingCheckBox, 'Value', logical(x)));
        applyIf(v, 'events',    @(x) set(obj.VizEventsDropDown, 'Value', char(x)));
    end
end

% --- Artifacts tab viewer options (one struct; the detection settings are the config's) ---
if AppPrefs.ispref(g, 'ArtifactViewOptions')
    v = AppPrefs.getpref(g, 'ArtifactViewOptions');
    if isstruct(v)
        applyIf(v, 'context',    @(x) set(obj.ArtViewContextField, 'Value', x));
        applyIf(v, 'channels',   @(x) set(obj.ArtViewChannelsField, 'Value', x));
        applyIf(v, 'scale',      @(x) set(obj.ArtViewScaleDropDown, 'Value', char(x)));
        applyIf(v, 'lanes',      @(x) set(obj.ArtViewLanesField, 'Value', x));
        applyIf(v, 'shankColor', @(x) set(obj.ArtViewShankColorCheckBox, 'Value', logical(x)));
        applyIf(v, 'shade',      @(x) set(obj.ArtViewShadeButton, 'Value', logical(x)));
        if obj.ArtViewScaleDropDown.Value == "manual" && obj.ArtViewLanesField.Value <= 0
            obj.ArtViewScaleDropDown.Value = 'artifact';
        end
        if obj.ArtViewShadeButton.Value
            styleButton(obj.ArtViewShadeButton, "active");
        else
            styleButton(obj.ArtViewShadeButton);
        end
    end
end

% --- Copy tab settings (one struct) ---
if AppPrefs.ispref(g, 'CopyOptions')
    v = AppPrefs.getpref(g, 'CopyOptions');
    if isstruct(v)
        applyIf(v, 'subject',    @(x) set(obj.CopySubjectField, 'Value', char(x)));
        % each box's list before its value: a new list moves the value to its first entry
        applyIf(v, 'epsychRootRecent', @(x) set(obj.CopyEpsychRootField, 'Items', cellstr(x)));
        applyIf(v, 'recordingRootsRecent', @(x) set(obj.CopyRecordingRootsField, 'Items', cellstr(x)));
        applyIf(v, 'destRootRecent', @(x) set(obj.CopyDestRootField, 'Items', cellstr(x)));
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
if AppPrefs.ispref(g, 'SynthOptions')
    v = AppPrefs.getpref(g, 'SynthOptions');
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
if AppPrefs.ispref(g, 'CleanupOptions')
    v = AppPrefs.getpref(g, 'CleanupOptions');
    if isstruct(v)
        applyIf(v, 'raw',        @(x) set(obj.CleanupRawCheckBox, 'Value', logical(x)));
        applyIf(v, 'sorterCopy', @(x) set(obj.CleanupSorterCopyCheckBox, 'Value', logical(x)));
        applyIf(v, 'bin',        @(x) set(obj.CleanupBinCheckBox, 'Value', logical(x)));
        applyIf(v, 'envelope',   @(x) set(obj.CleanupEnvelopeCheckBox, 'Value', logical(x)));
        applyIf(v, 'steps',      @(x) arrayfun(@(b) set(b, 'Value', ismember(b.Tag, cellstr(x))), obj.CleanupStepCheckBoxes));
        applyIf(v, 'method',     @(x) set(obj.CleanupMethodDropDown, 'Value', char(x)));
        applyIf(v, 'destination', @(x) set(obj.CleanupDestField, 'Value', char(x)));
        applyIf(v, 'ifExists',   @(x) set(obj.CleanupIfExistsDropDown, 'Value', char(x)));
        applyIf(v, 'showKept',   @(x) set(obj.CleanupShowKeptCheckBox, 'Value', logical(x)));
        obj.onCleanupMethodChanged();
    end
end

% --- the config: last file, else defaults ---
opened = false;
if AppPrefs.ispref(g, 'LastConfigFile')
    f = string(AppPrefs.getpref(g, 'LastConfigFile'));
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
