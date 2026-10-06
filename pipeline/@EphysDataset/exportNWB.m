function out = exportNWB(obj, opts)
%exportNWB  Write this dataset as a Neurodata Without Borders (NWB 2) file, with pynwb.
%   OUT = ds.exportNWB(Name=Value) writes <outputFolder>/<Name>.nwb:
%     electrodes          one row per amplifier channel that the exported
%                         signals or the units use, in recording order: the
%                         electrode group of its probe shank ("shank<k>";
%                         "unmapped" off the probe; "electrodes" without a
%                         probe), its site on the probe (rel_x, rel_y, um;
%                         only with a probe, NaN off it), channel_name (the
%                         native name), recording_channel (1-based) and
%                         interpolated (the Signals step replaced it as a
%                         bad channel); location Metadata.Location, else
%                         "unknown"
%     processing/ecephys  LFP in an LFP container; MUA and SPIKE each in a
%                         FilteredEphys container. Each is an
%                         ElectricalSeries of the extract's samples as they
%                         are (float32 microvolts), with conversion 1e-6 to
%                         volts, the signal's rate and starting_time 0, so
%                         sample i (0-based) is at i / rate s on the
%                         continuous clock. filtering lists the importOptions
%                         that made the signal, exactly
%     acquisition/AUX     the accelerometer inputs, volts, as a TimeSeries
%     units               the sorted units: spike_times (s, the continuous
%                         clock), id (the cluster id), electrodes (the peak
%                         channel's row), class, sort_label (the phy /
%                         Kilosort label), label, channel_name,
%                         peak_channel, shank, x_um / y_um (template centre),
%                         amplitude, contam_pct and, with UnitQuality, the
%                         quality metrics under SpikeInterface's names
%                         (firing_rate, isi_violations_ratio,
%                         isi_violations_count, presence_ratio,
%                         amplitude_cutoff, snr, drift_ptp, drift_std,
%                         drift_mad); resolution 1 / Fs
%     trials              the paired Epsych2 trials of the behavior file:
%                         start_time / stop_time from TrialOnset /
%                         TrialOffset, plus every column with one number,
%                         logical or text per trial (parameters, response
%                         code, PairingFlag, the pairing's sample columns;
%                         the names start_time, stop_time, id, tags and
%                         timeseries get "behavior_" in front). Trials
%                         without a paired interval are left out
%                         (OUT.nTrialsLeftOut); columns of other shapes are
%                         listed in OUT.trialColumnsLeftOut
%     intervals/<line>    each digital line's pulses (TimeIntervals); a
%                         line without one makes no table
%     invalid_times       the artifact periods the Signals step erased
%     general             session_description, session_start_time (the
%                         recording's start in Metadata.TimeZone),
%                         session_id = Name, the subject, experimenter, lab
%                         and institution (Metadata), notes = the provenance
%                         as JSON, source_script = the code version
%
%   One clock. The digital inputs count rows (t = row/Fs) while signals and
%   spikes put row r at (r-1)/Fs. NWB holds one clock, so every trial and
%   pulse time t is moved to the continuous clock: (round(t*Fs) - 1)/Fs,
%   the time of the recording sample that produced it (epochTable's
%   t0Continuous). The artifact periods already are on that clock.
%   Threshold-detected spikes are not exported: NWB has no table for them.
%
%   How. MATLAB writes the data to a staging folder next to the file:
%   stage.json (the structure and every text), stage.npz (every number, as
%   held: writeNPZ) and one <SIG>.npy per signal. nwb_export.py (next to
%   this file) then runs in Python. pynwb builds the file, written as
%   "~<name>.partial.nwb" and renamed when complete, and nwbinspector checks
%   it: pynwb's schema validation and the NWB best practices. The staging
%   folder needs as much disk as the signals and is deleted afterwards
%   (KeepStaging=true keeps it). It needs a Python with pynwb and
%   nwbinspector (pipeline/INSTALL.md); no MATLAB toolbox.
%
%   Options
%     File          target (default <outputFolder>/<Name>.nwb)
%     Extract, Signals, Units, Groups, UnitQuality, Sources, Events
%                   as in exportChronux (Detected is accepted and ignored)
%     Trials        true (default): the paired trials of Behavior
%     Behavior      "" (default: <outputFolder>/<Name>_behavior.mat when it
%                   exists, else no trials), a behavior .mat file, or a
%                   behaviorStruct
%     ProbeFile     "" (the dataset's) or the probe .json that places the
%                   electrodes (EphysPipeline.probeFor)
%     Metadata      struct of NWB metadata, the pipeline config's Export.NWB
%                   fields: SessionDescription, ExperimentDescription,
%                   Experimenter, Lab, Institution, Keywords, Location,
%                   SubjectId, Species, Sex, Age, SubjectDescription,
%                   Strain, Genotype, TimeZone (IANA name; "" = this
%                   computer's) and SessionStartTime ("yyyy-MM-dd
%                   HH:mm:ss"; "" = the recording's start: AcqDate, else
%                   the name pattern's). Fields left "" are not written;
%                   nothing is made up for them
%     PythonExe, CondaEnv   the Python to run ("" = the dataset's
%                   PythonExe / CondaEnv)
%     Inspect       true (default): run nwbinspector
%     KeepStaging   false
%     StageOnly     false: true writes the staging folder and stops there
%                   (no Python; OUT.stage names the folder, which is kept)
%     Overwrite     false: error if File exists
%     Provenance    ephysProvenance() of the run writing it ([] = made here)
%
%   OUT: file, bytes, seconds, signals, nElectrodes, nUnits, nTrials,
%   nTrialsLeftOut, trialColumnsLeftOut, nEventLines, sessionStartTime,
%   inspector (table: importance, check, message, objectType, objectName,
%   location; none without Inspect), inspectorFile, versions (Python's
%   packages), sources, command, stage (the staging folder when kept). The nwbinspector findings are written to
%   <name>_nwbinspector.json next to the file. Those of importance ERROR,
%   PYNWB_VALIDATION or CRITICAL warn (EphysDataset:exportNWB:Inspector).
%   A missing subject's species, sex or age is CRITICAL or a best-practice
%   violation for nwbinspector, so give them in Metadata.
%
%   Errors: EphysDataset:exportNWB:Exists, :NoPython, :ScriptMissing,
%   :NoStartTime, :BadTimeZone, :NoBehavior, :Python (the driver failed:
%   its message), and resolveExportInputs'.
%
%   See also EphysDataset.exportChronux, EphysDataset.exportFieldTrip,
%   EphysDataset.exportKCSD, writeNPZ, ephysProvenance.

arguments
    obj (1,1) EphysDataset
    opts.File (1,1) string = ""
    opts.Extract = ""
    opts.Signals (1,:) string = string.empty(1,0)
    opts.Units = []
    opts.Groups (1,:) string = ["good" "mua"]
    opts.UnitQuality (1,1) logical = true
    opts.Detected = false
    opts.Sources struct = struct()
    opts.Events (1,1) logical = true
    opts.Trials (1,1) logical = true
    opts.Behavior = ""
    opts.ProbeFile (1,1) string = ""
    opts.Metadata (1,1) struct = struct()
    opts.PythonExe (1,1) string = ""
    opts.CondaEnv (1,1) string = ""
    opts.Inspect (1,1) logical = true
    opts.KeepStaging (1,1) logical = false
    opts.StageOnly (1,1) logical = false
    opts.Overwrite (1,1) logical = false
    opts.Provenance = []   % ephysProvenance() of the run writing it ([] = made here)
end
prov = opts.Provenance;
if isempty(prov); prov = ephysProvenance(); end
t0 = tic;

file = opts.File;
if file == ""
    file = string(fullfile(obj.outputFolder(), obj.Name + ".nwb"));
end
if isfile(file) && ~opts.Overwrite
    error('EphysDataset:exportNWB:Exists', '%s already exists (pass Overwrite=true to replace it).', file);
end
py = opts.PythonExe;
if py == ""; py = obj.PythonExe; end
env = opts.CondaEnv;
if env == ""; env = obj.CondaEnv; end
if py == "" && ~opts.StageOnly
    error('EphysDataset:exportNWB:NoPython', ...
        ['No Python to write the NWB file with: pass PythonExe (and CondaEnv), a Python with pynwb and ' ...
         'nwbinspector (pipeline/INSTALL.md).']);
end
script = fullfile(fileparts(mfilename('fullpath')), 'nwb_export.py');
if ~isfile(script)
    error('EphysDataset:exportNWB:ScriptMissing', 'nwb_export.py is not next to exportNWB.m: %s', script);
end
M = opts.Metadata;
startTime = sessionStart(obj, M);

ro = opts;
ro.Detected = false;
in = resolveExportInputs(obj, ro, 'exportNWB');
S = in.S;
eventFs = in.eventFs;

% --- electrodes ----------------------------------------------------------------------------
probeFile = opts.ProbeFile;
if probeFile == ""; probeFile = obj.ProbeFile; end
layout = struct('hasProbe', false);
if probeFile ~= ""; layout = obj.channelLayout(ProbeFile=probeFile); end
elecSigs = in.signals(in.signals ~= "AUX");
sigRec = struct();
recAll = zeros(0, 1);
labelOf = containers.Map('KeyType', 'double', 'ValueType', 'any');
for sig = elecSigs
    nCol = size(S.Y.(sig), 2);
    rec = KCSDExport.recordingChannels(S.info, nCol);
    sigRec.(sig) = rec;
    recAll = [recAll; rec(:)]; %#ok<AGROW>
    lab = "ch" + string(rec);
    if isfield(S.info, 'labels') && numel(S.info.labels) == nCol
        l = reshape(string(S.info.labels), [], 1);
        lab(l ~= "") = l(l ~= "");
    end
    for i = 1:nCol
        if ~isKey(labelOf, rec(i)); labelOf(rec(i)) = lab(i); end
    end
end
U = in.units;
nU = 0;
if ~isempty(U)
    nU = numel(U.unitId);
    uc = double(U.channel(:));
    ok = isfinite(uc) & uc >= 1;
    recAll = [recAll; uc(ok)];
    for i = find(ok).'
        if ~isKey(labelOf, uc(i))
            nm = "ch" + uc(i);
            if isfield(U, 'channelName') && string(U.channelName(i)) ~= ""; nm = string(U.channelName(i)); end
            labelOf(uc(i)) = nm;
        end
    end
end
recAll = unique(recAll);
nE = numel(recAll);
shank = NaN(nE, 1); ex = NaN(nE, 1); ey = NaN(nE, 1);
if layout.hasProbe
    on = recAll >= 1 & recAll <= numel(layout.x);
    shank(on) = layout.shank(recAll(on));
    ex(on) = layout.x(recAll(on));
    ey(on) = layout.y(recAll(on));
end
bad = false(nE, 1);
if isfield(S.info, 'badChannels') && isstruct(S.info.badChannels) && isfield(S.info.badChannels, 'channels')
    bad = ismember(recAll, double(S.info.badChannels.channels(:)));
end
location = field(M, 'Location');
if location == ""; location = "unknown"; end
grp = strings(nE, 1);
groups = struct('name', {}, 'description', {}, 'location', {});
if ~layout.hasProbe
    grp(:) = "electrodes";
    groups(1).name = "electrodes";
    groups(1).description = "The recording's channels (no probe map: positions unknown)";
    groups(1).location = location;
else
    onSite = isfinite(shank) & isfinite(ex) & isfinite(ey);
    for k = unique(shank(onSite)).'
        nm = "shank" + k;
        grp(onSite & shank == k) = nm;
        groups(end+1) = struct('name', nm, 'description', sprintf('Shank %d of the probe %s (kcoords %d)', k, probeFile, k), ...
            'location', location); %#ok<AGROW>
    end
    if any(~onSite)
        grp(~onSite) = "unmapped";
        groups(end+1) = struct('name', "unmapped", 'description', "Channels that are not on the probe " + probeFile, ...
            'location', location);
    end
end
labels = strings(nE, 1);
for i = 1:nE; labels(i) = labelOf(recAll(i)); end
[~, deviceName] = fileparts(probeFile);
if deviceName == ""; deviceName = "probe"; end

A = struct();
shapes = struct();
A.electrodes_recording_channel = int64(recAll);
A.electrodes_interpolated = bad;
shapes.electrodes_recording_channel = "vector";
shapes.electrodes_interpolated = "vector";
if layout.hasProbe
    A.electrodes_rel_x = ex;
    A.electrodes_rel_y = ey;
    shapes.electrodes_rel_x = "vector";
    shapes.electrodes_rel_y = "vector";
end
extra = {struct('name', "channel_name", 'description', "The channel's native name", 'kind', "text", 'values', {cellstr(labels)}), ...
    struct('name', "recording_channel", 'description', "1-based amplifier channel of the recording (the probe's chanMap value + 1)", ...
        'kind', "number", 'key', "electrodes_recording_channel"), ...
    struct('name', "interpolated", 'description', "The Signals step replaced this channel in the derived signals as a bad channel (badChannels)", ...
        'kind', "bool", 'key', "electrodes_interpolated")};
electrodes = struct('count', nE, 'positions', layout.hasProbe, 'group', {cellstr(grp)}, ...
    'location', {cellstr(repmat(location, nE, 1))}, 'extra_columns', {extra});

% --- the staging folder ----------------------------------------------------------------------
[outDir, base] = fileparts(file);
if strlength(outDir) > 0 && ~isfolder(outDir)
    [ok, msg] = mkdir(outDir);
    if ~ok
        error('EphysDataset:exportNWB:MkdirFailed', 'Could not create %s: %s', outDir, msg);
    end
end
stage = fullfile(outDir, "~" + base + ".nwbstage");
if isfolder(stage); rmdir(stage, 's'); end
mkdir(stage);
if ~opts.KeepStaging && ~opts.StageOnly
    cleaner = onCleanup(@() removeFolder(stage)); %#ok<NASGU>
end

% --- signals ---------------------------------------------------------------------------------
signals = {};
for sig = in.signals
    f = sig + ".npy";
    writeNPY(fullfile(stage, f), S.Y.(sig), "", Shape="transpose");   % (channels, samples), C order
    A.(sig + "_rate") = double(S.info.(sig).Fs);
    shapes.(sig + "_rate") = "scalar";
    s = struct('name', sig, 'file', f, 'rate_key', sig + "_rate", 'conversion_key', sig + "_conversion", ...
        'chunk_samples', 65536);
    if sig == "AUX"
        A.AUX_conversion = 1;
        s.kind = "aux";
        s.description = "Auxiliary (accelerometer) inputs, volts, as recorded; sample i (0-based) at i / rate s.";
    else
        A.(sig + "_conversion") = 1e-6;
        [~, rows] = ismember(sigRec.(sig), recAll);
        A.(sig + "_electrodes") = int64(rows(:) - 1);
        shapes.(sig + "_electrodes") = "vector";
        s.electrodes_key = sig + "_electrodes";
        s.kind = "filtered";
        if sig == "LFP"; s.kind = "lfp"; end
        s.filtering = filteringText(S.info, sig);
        s.description = sig + " derived from the wideband recording by the Signals step (deriveSignals); " + ...
            "float32 microvolts x conversion 1e-6 = volts; sample i (0-based) at i / rate s on the continuous clock.";
    end
    shapes.(sig + "_conversion") = "scalar";
    signals{end+1} = s; %#ok<AGROW>
end

% --- units -----------------------------------------------------------------------------------
units = [];
if nU > 0
    t = U.times(:);
    A.units_spike_times = vertcat(zeros(0, 1), t{:});
    A.units_spike_index = int64(cumsum(cellfun(@numel, t)));
    A.units_id = int64(U.unitId(:));
    [~, row] = ismember(double(U.channel(:)), recAll);
    A.units_electrode = int64(row - 1);                   % -1: no channel
    A.units_resolution = 1 / double(U.fs);
    for f = ["units_spike_times" "units_spike_index" "units_id" "units_electrode"]
        shapes.(f) = "vector";
    end
    shapes.units_resolution = "scalar";
    cols = {};
    textCols = ["class" "class"; "group" "sort_label"; "label" "label"; "channelName" "channel_name"];
    for i = 1:size(textCols, 1)
        src = textCols(i, 1);
        if ~isfield(U, src) || numel(U.(src)) ~= nU; continue; end
        sx = string(U.(src)(:));
        sx(ismissing(sx)) = "";
        cols{end+1} = struct('name', textCols(i, 2), 'description', unitColumnDescription(textCols(i, 2)), ...
            'kind', "text", 'values', {cellstr(sx)}); %#ok<AGROW>
    end
    numCols = ["channel" "peak_channel"; "shank" "shank"; "x" "x_um"; "y" "y_um"; "amplitude" "amplitude"; ...
        "contamPct" "contam_pct"; "firingRate" "firing_rate"; "isiViolationsRatio" "isi_violations_ratio"; ...
        "isiViolationsCount" "isi_violations_count"; "presenceRatio" "presence_ratio"; ...
        "amplitudeCutoff" "amplitude_cutoff"; "snr" "snr"; "driftPtp" "drift_ptp"; "driftStd" "drift_std"; ...
        "driftMad" "drift_mad"];
    for i = 1:size(numCols, 1)
        src = numCols(i, 1);
        if ~isfield(U, src) || numel(U.(src)) ~= nU; continue; end
        key = "units_" + numCols(i, 2);
        A.(key) = double(U.(src)(:));
        shapes.(key) = "vector";
        cols{end+1} = struct('name', numCols(i, 2), 'description', unitColumnDescription(numCols(i, 2)), ...
            'kind', "number", 'key', key); %#ok<AGROW>
    end
    desc = "Sorted units";
    if isfield(U, 'resultsDir'); desc = desc + " of " + string(U.resultsDir); end
    sorter = "Kilosort4";
    if isfield(U, 'resultsDir'); sorter = EphysDataset.sorterLabel(EphysDataset.sorterOfRunDir(U.resultsDir)); end
    desc = desc + " (" + sorter + " / phy; labels from " + fieldText(U, 'groupSource') + "). Spike times in seconds on the " + ...
        "continuous clock (sample s, 1-based, at (s-1)/Fs). Quality metrics, when present, follow SpikeInterface's " + ...
        "definitions (ephys_analysis unitQualityMetrics).";
    units = struct('count', nU, 'description', desc, 'columns', {cols});
end

% --- trials ---------------------------------------------------------------------------------
trials = [];
nTrialsLeft = 0;
colsLeftOut = strings(1, 0);
B = [];
if opts.Trials
    B = behaviorFor(obj, opts.Behavior);
end
if ~isempty(B) && isfield(B, 'trials') && istable(B.trials) ...
        && all(ismember(["TrialOnset" "TrialOffset"], string(B.trials.Properties.VariableNames)))
    T = B.trials;
    fsB = eventFs;
    if isfield(B, 'pairing') && isstruct(B.pairing) && isfield(B.pairing, 'Fs') && isfinite(double(B.pairing.Fs))
        fsB = double(B.pairing.Fs);
    end
    if isfield(B, 'pairing') && isstruct(B.pairing) && isfield(B.pairing, 'status') && string(B.pairing.status) ~= "approved"
        warning('EphysDataset:exportNWB:PairingNotApproved', ...
            '%s: the trial pairing is "%s", not approved; its trials are exported as they are.', obj.Name, string(B.pairing.status));
    end
    on = double(T.TrialOnset);
    off = double(T.TrialOffset);
    keep = isfinite(on) & isfinite(off) & off >= on;
    nTrialsLeft = nnz(~keep);
    T = T(keep, :);
    A.trials_start_time = toContinuous(on(keep), fsB);
    A.trials_stop_time = toContinuous(off(keep), fsB);
    shapes.trials_start_time = "vector";
    shapes.trials_stop_time = "vector";
    cols = {};
    k = 0;
    for v = string(T.Properties.VariableNames)
        x = T.(v);
        nm = v;
        if ismember(nm, ["start_time" "stop_time" "id" "tags" "timeseries"]); nm = "behavior_" + nm; end
        desc = trialColumnDescription(v);
        if size(x, 2) ~= 1
            colsLeftOut(end+1) = v; %#ok<AGROW>
        elseif isnumeric(x) || islogical(x)
            k = k + 1;
            key = "trials_c" + k;
            kind = "number";
            if islogical(x); kind = "bool"; end
            A.(key) = double(x);
            if islogical(x); A.(key) = x; end
            shapes.(key) = "vector";
            cols{end+1} = struct('name', nm, 'description', desc, 'kind', kind, 'key', key); %#ok<AGROW>
        elseif isstring(x) || iscategorical(x) || iscellstr(x) || ischar(x)
            sx = string(x);
            sx(ismissing(sx)) = "";
            cols{end+1} = struct('name', nm, 'description', desc, 'kind', "text", 'values', {cellstr(sx)}); %#ok<AGROW>
        else
            colsLeftOut(end+1) = v; %#ok<AGROW>
        end
    end
    trials = struct('count', height(T), 'columns', {cols});
end

% --- digital lines and the periods erased --------------------------------------------------
events = {};
if opts.Events && isstruct(in.events) && isfinite(eventFs)
    names = string(fieldnames(in.events)).';
    for i = 1:numel(names)
        iv = double(in.events.(names(i)));
        if isempty(iv); continue; end
        key = "event_" + i;
        A.(key) = toContinuous(iv, eventFs);
        shapes.(key) = "full";
        nm = names(i);
        if ismember(nm, ["trials" "epochs" "invalid_times"]); nm = "line_" + nm; end
        events{end+1} = struct('name', nm, 'key', key, 'description', ...
            "Pulses of digital input " + names(i) + " (polarity applied), [start stop] on the continuous clock: " + ...
            "an event at recording row r is at (r-1)/Fs."); %#ok<AGROW>
    end
end
A.invalid_times = double(in.artifacts.intervals);
shapes.invalid_times = "full";

% --- session, subject, provenance --------------------------------------------------------------
desc = field(M, 'SessionDescription');
if desc == ""; desc = obj.Name + ": extracellular recording, exported by ephys_analysis"; end
note = struct('tool', "EphysDataset.exportNWB", 'dataset', obj.Name, 'sourceFolder', obj.Folder, ...
    'sources', in.sources, 'probeFile', probeFile, 'provenance', provenanceForJson(prov));
session = struct('description', desc, 'identifier', "", ...
    'start_time', string(startTime, "yyyy-MM-dd'T'HH:mm:ss.SSSxxx"), 'session_id', obj.Name, ...
    'experimenter', {cellstr(fieldList(M, 'Experimenter'))}, 'lab', field(M, 'Lab'), ...
    'institution', field(M, 'Institution'), 'experiment_description', field(M, 'ExperimentDescription'), ...
    'keywords', {cellstr(fieldList(M, 'Keywords'))}, 'notes', string(jsonencode(note)), ...
    'source_script', string(prov.code), 'source_script_file_name', "EphysDataset.exportNWB");
subjectId = field(M, 'SubjectId');
if subjectId == ""
    id = EphysDataset.nameIdentity(obj.Name, obj.NamePattern);
    subjectId = id.subject;
end
if subjectId == "" && isstruct(B) && isfield(B, 'subject'); subjectId = string(B.subject); end
subject = struct('subject_id', subjectId, 'species', field(M, 'Species'), 'sex', field(M, 'Sex'), ...
    'age', field(M, 'Age'), 'description', field(M, 'SubjectDescription'), 'strain', field(M, 'Strain'), ...
    'genotype', field(M, 'Genotype'));
if all(structfun(@(v) string(v) == "", subject)); subject = []; end

st = struct();
st.format = "ephys_analysis-nwb-stage/1";
st.target = string(file);
st.inspect = opts.Inspect;
st.session = session;
st.subject = subject;
st.device = struct('name', string(deviceName), 'description', deviceDescription(probeFile), 'manufacturer', "");
st.electrode_groups = num2cell(groups);   % a cell: a JSON list even with one group
st.electrodes = electrodes;
st.signals = signals;
st.units = units;
st.trials = trials;
st.events = events;
st.invalid_reason = "artifact period erased (filled) before the signals were derived";
writeNPZ(fullfile(stage, "stage.npz"), A, Shapes=shapes);
stageFile = fullfile(stage, "stage.json");
writeJsonFile(stageFile, st);
sigList = in.signals;
sources = in.sources;
clear S in A        % the extract and its copies: Python reads the staging folder
if opts.StageOnly
    out = struct('file', "", 'stage', string(stage), 'seconds', toc(t0), 'signals', sigList, ...
        'nElectrodes', nE, 'nUnits', nU, 'nTrials', 0, 'nTrialsLeftOut', nTrialsLeft, ...
        'trialColumnsLeftOut', colsLeftOut, 'nEventLines', numel(events), ...
        'sessionStartTime', session.start_time, 'sources', sources);
    if ~isempty(trials); out.nTrials = trials.count; end
    return
end

% --- Python -------------------------------------------------------------------------------
if env ~= ""
    command = sprintf('conda run -n %s "%s" "%s" "%s"', env, py, script, stageFile);
else
    command = sprintf('"%s" "%s" "%s"', py, script, stageFile);
end
[status, txt] = system(command);
statusFile = fullfile(stage, "nwb_status.json");
if ~isfile(statusFile)
    error('EphysDataset:exportNWB:Python', 'nwb_export.py wrote no status (exit %d). Its output:\n%s', status, strtrim(txt));
end
R = readJsonFile(statusFile);
if string(R.state) ~= "done"
    tb = "";
    if isfield(R, 'traceback'); tb = string(R.traceback); end
    error('EphysDataset:exportNWB:Python', 'nwb_export.py failed: %s\n%s', string(R.message), tb);
end

% --- the inspector's findings ---------------------------------------------------------------------
I = inspectorTable(R);
inspectorFile = "";
if opts.Inspect
    inspectorFile = string(fullfile(outDir, base + "_nwbinspector.json"));
    rec = struct('file', string(file), 'created', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
        'versions', R.versions, 'messages', {table2struct(I)});
    writeJsonFile(inspectorFile, rec);
    serious = ismember(I.importance, ["ERROR" "PYNWB_VALIDATION" "CRITICAL"]);
    if any(serious)
        list = strjoin(compose("%s %s (%s): %s", I.importance(serious), I.check(serious), I.objectName(serious), ...
            I.message(serious)), newline);
        warning('EphysDataset:exportNWB:Inspector', ...
            'nwbinspector found %d issue(s) of importance CRITICAL or above in %s (all findings: %s):\n%s', ...
            nnz(serious), file, inspectorFile, list);
    end
end

d = dir(file);
out = struct('file', string(file), 'bytes', d.bytes, 'seconds', toc(t0), 'signals', sigList, ...
    'nElectrodes', nE, 'nUnits', nU, 'nTrials', 0, 'nTrialsLeftOut', nTrialsLeft, ...
    'trialColumnsLeftOut', colsLeftOut, 'nEventLines', numel(events), ...
    'sessionStartTime', session.start_time, 'inspector', I, 'inspectorFile', inspectorFile, ...
    'versions', R.versions, 'sources', sources, 'command', string(command), 'stage', "");
if opts.KeepStaging; out.stage = string(stage); end
if ~isempty(trials); out.nTrials = trials.count; end
end


function d = sessionStart(obj, M)
%sessionStart  The session's start, zoned: Metadata.SessionStartTime, else AcqDate, else the name's.
txt = field(M, 'SessionStartTime');
if txt ~= ""
    d = datetime(txt, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
else
    d = obj.AcqDate;
    if isnat(d)
        id = EphysDataset.nameIdentity(obj.Name, obj.NamePattern);
        d = id.recordingStart;
    end
end
if isnat(d)
    error('EphysDataset:exportNWB:NoStartTime', ...
        ['%s: the recording''s start is not known (no AcqDate, and the name does not give it). ' ...
         'Pass Metadata.SessionStartTime ("yyyy-MM-dd HH:mm:ss").'], obj.Name);
end
tz = field(M, 'TimeZone');
if tz == ""; tz = string(datetime('now', 'TimeZone', 'local').TimeZone); end
if isempty(d.TimeZone)
    try
        d.TimeZone = tz;          % the wall-clock time, read in that zone
    catch ME
        error('EphysDataset:exportNWB:BadTimeZone', 'Unknown time zone "%s" (%s).', tz, ME.message);
    end
end
end


function v = field(M, f)
%field  A text field of the metadata struct ("" when missing).
v = "";
if isfield(M, f) && ~isempty(M.(f)); v = strtrim(strjoin(string(M.(f)), ", ")); end
end


function v = fieldList(M, f)
%fieldList  A list field of the metadata struct (a row of strings; none when missing).
v = strings(1, 0);
if isfield(M, f) && ~isempty(M.(f))
    v = reshape(strtrim(string(M.(f))), 1, []);
    v = v(v ~= "");
end
end


function v = fieldText(S, f)
v = "an unknown source";
if isfield(S, f) && ~isempty(S.(f)); v = string(S.(f)); end
end


function t = toContinuous(t, fs)
%toContinuous  Digital-input times (t = row/Fs) on the continuous clock: (row - 1)/Fs.
t = (round(t * fs) - 1) / fs;
end


function B = behaviorFor(obj, b)
%behaviorFor  The behavior struct to take trials from ([] when none).
B = [];
if isstruct(b)
    B = b;
    return
end
if islogical(b) && ~b; return; end
f = string(b);
if f == ""
    f = string(fullfile(obj.outputFolder(), obj.Name + "_behavior.mat"));
    if ~isfile(f); return; end
elseif ~isfile(f)
    error('EphysDataset:exportNWB:NoBehavior', 'No behavior file %s.', f);
end
L = load(f, 'behavior');
if isfield(L, 'behavior'); B = L.behavior; end
end


function t = filteringText(info, sig)
%filteringText  The importOptions that made SIG, exactly, and its common reference.
parts = strings(1, 0);
if isfield(info, 'importOptions') && isstruct(info.importOptions)
    o = info.importOptions;
    for f = string(fieldnames(o)).'
        if ~startsWith(f, sig + "_"); continue; end
        v = o.(f);
        if isnumeric(v) || islogical(v)
            parts(end+1) = f + "=" + string(mat2str(double(v), 17)); %#ok<AGROW>
        elseif isstring(v) || ischar(v)
            parts(end+1) = f + "=" + strjoin(string(v), ","); %#ok<AGROW>
        end
    end
end
if isfield(info, sig) && isstruct(info.(sig)) && isfield(info.(sig), 'reference')
    r = info.(sig).reference;
    if isstring(r) || ischar(r); parts(end+1) = "reference=" + string(r); end
end
t = strjoin(parts, "; ");
end


function d = deviceDescription(probeFile)
if probeFile == ""
    d = "The recording's amplifier channels (no probe map)";
else
    d = "Probe map " + probeFile + " (Kilosort4 probe .json: chanMap, xc, yc, kcoords)";
end
end


function d = unitColumnDescription(nm)
switch nm
    case "class",            d = "Unit class: su (single unit), mua, noise, uns (unsorted) or other";
    case "sort_label",       d = "The phy / Kilosort label (cluster_group.tsv or cluster_KSLabel.tsv)";
    case "label",            d = "ephys_analysis unit label: class, cluster id, subject, recording start";
    case "channel_name",     d = "Native name of the peak channel";
    case "peak_channel",     d = "1-based recording channel with the largest template amplitude";
    case "shank",            d = "Probe shank of the peak channel (kcoords)";
    case "x_um",             d = "Template centre, amplitude-weighted site position x (um)";
    case "y_um",             d = "Template centre, amplitude-weighted site position y (um)";
    case "amplitude",        d = "Kilosort amplitude (cluster_Amplitude.tsv)";
    case "contam_pct",       d = "Kilosort contamination estimate, percent (cluster_ContamPct.tsv)";
    case "firing_rate",      d = "Spikes per second over the sorted span (SpikeInterface firing_rate)";
    case "isi_violations_ratio", d = "ISI violations ratio, 1.5 ms threshold (SpikeInterface isi_violations_ratio, Hill et al. 2011)";
    case "isi_violations_count", d = "ISI violations count (SpikeInterface isi_violations_count)";
    case "presence_ratio",   d = "Share of 60 s bins with spikes (SpikeInterface presence_ratio)";
    case "amplitude_cutoff", d = "Estimated missed share of spikes (SpikeInterface amplitude_cutoff)";
    case "snr",              d = "Peak template amplitude / noise (MAD) of the peak channel (SpikeInterface snr)";
    case "drift_ptp",        d = "Peak-to-peak drift of the spike positions, um (SpikeInterface drift_ptp)";
    case "drift_std",        d = "Standard deviation of the drift, um (SpikeInterface drift_std)";
    case "drift_mad",        d = "Median absolute deviation of the drift, um (SpikeInterface drift_mad)";
    otherwise,               d = nm;
end
end


function d = trialColumnDescription(v)
switch v
    case "TrialOnset",        d = "Trial onset, s on the digital-input clock (t = row/Fs; start_time is it on the continuous clock)";
    case "TrialOffset",       d = "Trial offset, s on the digital-input clock (t = row/Fs; stop_time is it on the continuous clock)";
    case "TrialInterval",     d = "Index of the trial line's interval this trial is paired with";
    case "TrialOnsetSample",  d = "1-based recording row of the trial's first on sample";
    case "TrialOffsetSample", d = "1-based recording row of the trial's last on sample";
    case "PairingFlag",       d = "ok, partial (the interval touches an end of the recording), cut or unpaired";
    otherwise
        d = v + " from the Epsych2 trials table (EphysDataset.behaviorToMat)";
        if startsWith(v, "TrialOnsetSample_") || startsWith(v, "TrialOffsetSample_")
            d = v + ": 1-based row of that derived signal nearest the recording row";
        end
end
end


function I = inspectorTable(R)
%inspectorTable  nwbinspector's messages as a table.
I = table(strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'importance', 'check', 'message', 'objectType', 'objectName', 'location'});
if ~isfield(R, 'inspector') || isempty(R.inspector); return; end
m = R.inspector;
if iscell(m); m = [m{:}]; end
n = numel(m);
col = @(f) reshape(string({m.(f)}), [], 1);
I = table(col('importance'), col('check'), col('message'), col('object_type'), col('object_name'), col('location'), ...
    'VariableNames', {'importance', 'check', 'message', 'objectType', 'objectName', 'location'});
if height(I) ~= n; error('EphysDataset:exportNWB:Python', 'Unreadable nwbinspector messages.'); end
end


function removeFolder(f)
if isfolder(f); rmdir(f, 's'); end
end
