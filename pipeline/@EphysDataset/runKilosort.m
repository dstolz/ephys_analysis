function result = runKilosort(obj, opts)
%runKilosort  Run Kilosort4 on the recording via system().
%   RESULT = ds.runKilosort() writes the recording to ds.BinFile (toBin,
%   blanking the artifact intervals), writes a settings.json and a run_ks4.py
%   into the results dir, then launches Kilosort4 by calling a configurable
%   python/conda executable through SYSTEM (not MATLAB's pyenv).
%   ds.ProbeFile must point to an existing Kilosort4 probe .json that
%   Kilosort4 can read (probeMapProblems; a probe with problems is refused
%   with EphysDataset:runKilosort:BadProbe before anything is written). This
%   class never generates probe maps.
%
%   The probe's chanMap indexes .bin rows (0-based) directly: sites are not
%   matched to channels by their native number, so a recording with a
%   channel disabled at acquisition needs a probe that already accounts for
%   the gap.
%
%   RESULT = ds.runKilosort(opts) with name-value options:
%     PythonExe      python executable path (default ds.PythonExe)
%     CondaEnv       conda env name; when set, uses `conda run -n <env> ...`
%     ProbeFile      KS4 probe .json (default ds.ProbeFile)
%     ExcludeChannels (1,:) double  1-based channels to drop from sorting
%                    (default ds.ExcludeChannels). Excluded channels stay in the
%                    .bin (n_chan_bin is unchanged) but are removed from the
%                    probe's chanMap/xc/yc/kcoords via a derived probe written to
%                    the run folder (result.runDir); the original probe .json
%                    is never modified.
%     BinFile        existing .bin to sort as is (default: write ds.BinFile
%                    from the recording first)
%     ArtifactIntervals [k x 2] seconds to blank when writing the .bin
%                    ([] = none; default NaN = ds.artifactIntervals(): manual
%                    + auto when enabled). Refused when they cover more than
%                    EphysDataset.MaxSilencedFraction of the recording.
%     ResultsDir     KS4 output dir (default OutputDir/kilosort4)
%     NChanBin       n_chan_bin override (default from .bin JSON sidecar or NumChannels)
%     Fs             sample rate override (default ds.Fs)
%     ExtraSettings  scalar struct merged into settings.json. Its
%                    shank_spacing (um, 0 = off) is not passed on as a
%                    Kilosort4 setting: Kilosort4 sorts with a derived probe
%                    <probe>_spaced.json in the run folder whose shanks
%                    (kcoords groups, in order of their mean x) are that much
%                    further apart along x; the probe .json is never
%                    modified. settings.json records shank_spacing and the
%                    unspaced probe as true_probe, and run_ks4.py puts its
%                    positions back in channel_positions.npy and
%                    spike_positions.npy once Kilosort4 finishes, so the
%                    sorted output has the true layout.
%     DryRun         (1,1) logical  write the run files + build the command,
%                    do NOT spawn (default false). The files go to
%                    <ResultsDir>\dryrun (result.runDir), never into ResultsDir
%                    itself, so the settings.json and run_ks4.py of a run
%                    already there (the record of how its results were made)
%                    stay as they are. The dry run's settings.json still
%                    names ResultsDir as results_dir, as the real run's would.
%                    No .bin is written.
%     Wait           (1,1) logical  block until Kilosort4 finishes (default true).
%                    When false, the process is launched detached (background)
%                    with stdout/stderr redirected to the log, and the call
%                    returns immediately; result.status is then the launcher's
%                    status, not the Kilosort4 exit code.
%     Device         (1,1) string  torch device for the run ("cuda:1", "cpu";
%                    default "" = Kilosort4's choice), see launchSorting
%     Launch         (1,1) logical  start Kilosort4 (default true). false
%                    writes every file (the .bin included) and returns;
%                    ds.launchSorting(result) starts the run later
%                    (EphysPipeline.runSorting waits for a free slot in
%                    between).
%
%   Whether blocking or not, the generated run_ks4.py writes a small
%   ks4_status.json (state "done" or "error") in the results dir on completion,
%   and a background run also leaves an empty EphysDataset.SortExitMarker there
%   once its process exits, so a caller can poll for completion of a
%   background run (EphysDataset.sortRunState).
%
%   The recording is referenced once: when the .bin carries the common
%   reference (ArtifactConfig.Reference "car" / "cmr", which toBin
%   subtracts; for a BinFile given, the reference its sidecar records),
%   settings.json sets do_CAR = false, so Kilosort4 does not subtract its own
%   (the median across the probe's channels) on top of it, whatever
%   ExtraSettings says. With Reference "none" Kilosort4's do_CAR is the one
%   reference, as ExtraSettings leaves it (on by default).
%
%   settings.json also records the .bin's scale, its units per uV
%   (bin_scale: ds.Scale when this call writes the .bin, else the .bin's
%   sidecar), which readPhyUnits needs to give the templates in uV.
%   run_ks4.py does not pass it to Kilosort4.
%
%   Python/conda exe and conda env resolve most-specific-first:
%   per-call opts -> dataset property -> (manager default, when pushed down).
%
%   RESULT struct: status, command, driverCommand, stdoutLog, scriptPath,
%   settingsPath, resultsDir (where Kilosort4 writes its output), runDir
%   (the folder holding settings.json and run_ks4.py: resultsDir, or
%   resultsDir\dryrun for a dry run), binFile, probeFile (the probe
%   Kilosort4 sorts with), trueProbeFile (the probe whose positions the
%   output has: probeFile unless the shanks were spaced), shankSpacing (um
%   added between shanks; 0 when none), excludeChannels,
%   nExcludedChannels, dryRun, wait, statusFile, background, device,
%   launched, previousDir (see launchSorting).
%
%   See also EphysDataset.launchSorting, EphysDataset.toBin, EPHYSPROJECT.

arguments
    obj (1,1) EphysDataset
    opts.PythonExe (1,1) string = ""
    opts.CondaEnv (1,1) string = ""
    opts.ProbeFile (1,1) string = ""
    opts.ExcludeChannels (1,:) double = []
    opts.BinFile (1,1) string = ""
    opts.ResultsDir (1,1) string = ""
    opts.NChanBin (1,1) double = NaN
    opts.Fs (1,1) double = NaN
    opts.ExtraSettings (1,1) struct = struct()
    opts.ArtifactIntervals double = NaN
    opts.DryRun (1,1) logical = false
    opts.Wait (1,1) logical = true
    opts.Device (1,1) string = ""
    opts.Launch (1,1) logical = true
    opts.Provenance = []   % ephysProvenance() of the run writing it ([] = made here)
end
prov = opts.Provenance;
if isempty(prov); prov = ephysProvenance(); end

% Resolve config (per-call -> dataset)
pythonExe = firstNonEmpty(opts.PythonExe, obj.PythonExe);
condaEnv  = firstNonEmpty(opts.CondaEnv,  obj.CondaEnv);
probeFile = firstNonEmpty(opts.ProbeFile, obj.ProbeFile);
binGiven  = opts.BinFile ~= "";
binFile   = firstNonEmpty(opts.BinFile,   obj.BinFile);

if pythonExe == ""
    error('EphysDataset:runKilosort:NoPython', ...
        'No python executable configured (set ds.PythonExe or pass PythonExe).');
end
if probeFile == ""
    error('EphysDataset:runKilosort:NoProbe', ...
        'No probe file configured (set ds.ProbeFile or pass ProbeFile).');
end
if ~isfile(probeFile)
    error('EphysDataset:runKilosort:ProbeMissing', 'Probe file not found: %s', probeFile);
end
% Refuse a probe Kilosort4 could not read before the .bin is written: every
% problem here would otherwise only surface inside Kilosort4, minutes later.
problems = probeMapProblems(probeFile);
if ~isempty(problems)
    error('EphysDataset:runKilosort:BadProbe', 'Kilosort4 could not read the probe %s:\n  %s', ...
        probeFile, strjoin(problems, newline + "  "));
end
if ~opts.DryRun && binGiven && ~isfile(binFile)
    error('EphysDataset:runKilosort:BinMissing', '.bin not found: %s', binFile);
end
% shank_spacing is not a Kilosort4 setting: it says how far apart to move
% the shanks in the probe Kilosort4 sorts with.
extra = opts.ExtraSettings;
shankSpacing = 0;
if isfield(extra, 'shank_spacing')
    shankSpacing = double(extra.shank_spacing);
    extra = rmfield(extra, 'shank_spacing');
    if isempty(shankSpacing); shankSpacing = 0; end
    if ~(isscalar(shankSpacing) && isfinite(shankSpacing) && shankSpacing >= 0)
        error('EphysDataset:runKilosort:BadShankSpacing', ...
            'shank_spacing must be a distance of 0 um or more.');
    end
end

% Results dir
if opts.ResultsDir ~= ""
    resultsDir = char(opts.ResultsDir);
else
    resultsDir = obj.kilosortDir();
end
resultsDir = absPath(resultsDir);
% A dry run writes its files to a folder of its own: the settings.json and
% run_ks4.py of a run already in resultsDir record how its results were made.
runDir = resultsDir;
if opts.DryRun
    runDir = fullfile(resultsDir, 'dryrun');
end

% Write the .bin from the recording, blanking the artifact intervals.
if ~binGiven && ~opts.DryRun
    [iv, given] = explicitIntervals(opts.ArtifactIntervals);
    if ~given
        iv = obj.artifactIntervals();
    end
    if isnan(obj.Fs) || isempty(obj.PerFile); obj.refreshMetadata(); end
    [share, covered] = EphysDataset.silencedFraction(iv, obj.NumSamples / obj.Fs);
    if share > EphysDataset.MaxSilencedFraction
        error('EphysDataset:runKilosort:MostlySilenced', ...
            ['Artifact blanking would erase %.0f%% of the recording (%d period(s), %.4g of %.4g s; ' ...
             'limit %.0f%%). Kilosort4 would find no spikes. Check the artifact detector settings ' ...
             'or turn off artifact silencing for this dataset.'], 100 * share, size(iv, 1), ...
            covered, obj.NumSamples / obj.Fs, 100 * EphysDataset.MaxSilencedFraction);
    end
    obj.toBin(ArtifactIntervals=iv, Provenance=prov);
end

% Absolute paths (KS4 + system() want absolute, double-quoted paths)
binFile   = absPath(binFile);
probeFile = absPath(probeFile);

% n_chan_bin and fs: opts -> .bin JSON sidecar -> dataset metadata. The
% .bin's units per uV: ds.Scale when toBin writes it here, else the sidecar.
[nChanBin, fsVal, binScale, binRef] = resolveBinMeta(binFile, opts, obj, "runKilosort");
if ~binGiven
    binScale = obj.binScale();   % what toBin used above
    binRef = string(EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig).Reference);   % what toBin subtracts
elseif ~isfinite(binScale) || binRef == ""
    warning('EphysDataset:runKilosort:BinMetaUnknown', ...
        ['%s has no readable sidecar recording its scale and common reference: settings.json gets no ' ...
         'bin_scale (the templates stay in .bin units) and Kilosort4''s do_CAR is left as configured.'], binFile);
end

if ~isfolder(runDir)
    mkdir(runDir);
end

% Validate probe channel count against n_chan_bin (warn only)
checkProbeChannels(probeFile, nChanBin, "runKilosort");

% Per-recording channel exclusions: drop the listed channels from the probe
% (keeping n_chan == n_chan_bin) so Kilosort4 ignores them. Write the reduced
% map to a derived probe in the run dir; never touch the original .json.
excludeCh = opts.ExcludeChannels;
if isempty(excludeCh); excludeCh = obj.ExcludeChannels; end
excludeCh = EphysDataset.parseChannelList(excludeCh);
nExcluded = 0;
if ~isempty(excludeCh)
    [probeFile, nExcluded] = writeExcludedProbe(probeFile, excludeCh, runDir, nChanBin, "runKilosort");
    if nExcluded > 0
        fprintf('Excluding %d channel(s) from sorting: %s\n', ...
            nExcluded, char(EphysDataset.formatChannelList(excludeCh)));
    end
end

% Shank spacing: Kilosort4 sorts with a copy of the probe whose shanks are
% further apart; run_ks4.py puts this probe's positions back in its output.
trueProbe = string(probeFile);
spaced = false;
if shankSpacing > 0
    [probeFile, spaced] = writeSpacedProbe(probeFile, shankSpacing, runDir);
end

% Build settings.json
settings = struct();
settings.n_chan_bin = nChanBin;
settings.fs         = fsVal;
settings.data_dtype = char(obj.Dtype);
settings.filename   = strrep(binFile, '\', '/');     % forward slashes are JSON-safe
settings.probe      = strrep(probeFile, '\', '/');
settings.results_dir = strrep(resultsDir, '\', '/');
if isfinite(binScale)
    settings.bin_scale = binScale;                   % for readPhyUnits, not Kilosort4
end
if spaced
    settings.shank_spacing = shankSpacing;               % for run_ks4.py, not Kilosort4
    settings.true_probe = strrep(char(trueProbe), '\', '/');
end
% Merge ExtraSettings
extraNames = fieldnames(extra);
for k = 1:numel(extraNames)
    settings.(extraNames{k}) = extra.(extraNames{k});
end
% A .bin that carries the common reference is not referenced again:
% Kilosort4's do_CAR would subtract the median across the probe's channels
% on top of it.
if ismember(binRef, ["car" "cmr"])
    if isfield(settings, 'do_CAR') && ~isequal(settings.do_CAR, false)
        fprintf('do_CAR turned off: the .bin already carries the common %s reference.\n', upper(binRef));
    end
    settings.do_CAR = false;
end
settings.provenance = provenanceForJson(prov);   % for the record; run_ks4.py does not pass it to Kilosort4

settingsPath = fullfile(runDir, 'settings.json');
scriptPath   = fullfile(runDir, 'run_ks4.py');
stdoutLog    = fullfile(resultsDir, 'ks4_run.log');
statusFile   = fullfile(resultsDir, 'ks4_status.json');

writeSettings(settings, settingsPath);
writeRunScript(scriptPath);

% Build command (absolute, double-quoted paths everywhere)
if condaEnv ~= ""
    command = sprintf('conda run -n %s "%s" "%s" "%s"', condaEnv, pythonExe, scriptPath, settingsPath);
else
    command = sprintf('"%s" "%s" "%s"', pythonExe, scriptPath, settingsPath);
end

result = struct();
result.status       = NaN;
result.sorter       = "kilosort4";   % launchSorting: which driver, launcher and curation files
result.command      = command;
result.stdoutLog    = char(stdoutLog);
result.scriptPath   = char(scriptPath);
result.settingsPath = char(settingsPath);
result.resultsDir   = resultsDir;
result.runDir       = runDir;
result.binFile      = binFile;
result.probeFile    = probeFile;
result.trueProbeFile = trueProbe;
result.shankSpacing = shankSpacing * spaced;
result.excludeChannels = excludeCh;
result.nExcludedChannels = nExcluded;
result.dryRun       = opts.DryRun;
result.wait         = opts.Wait;
result.statusFile   = char(statusFile);
result.background   = false;
result.driverCommand = command;   % launchSorting adds --device
result.device       = "";
result.launched     = false;
result.previousDir  = "";      % launchSorting: where an earlier sort's curation went

if opts.DryRun
    fprintf('[DryRun] Wrote %s and %s\n', settingsPath, scriptPath);
    fprintf('[DryRun] Command: %s\n', command);
    return
end
if opts.Launch
    result = obj.launchSorting(result, Wait=opts.Wait, Device=opts.Device);
end
end


%% ---- local helpers ----------------------------------------------------

function v = firstNonEmpty(varargin)
v = "";
for k = 1:nargin
    s = string(varargin{k});
    if s ~= ""
        v = s;
        return
    end
end
end


function [derivedFile, spaced] = writeSpacedProbe(probeFile, spacing, runDir)
%writeSpacedProbe  Write a probe .json with its shanks SPACING um further apart.
%   Shanks are the kcoords groups, ordered by their mean x: the k-th (from
%   0) moves k*SPACING um along x, so each pair of neighbouring shanks gains
%   SPACING um and every shank keeps its own layout. Kilosort4 picks a
%   channel's neighbours by distance alone (whitening_range, drift
%   interpolation, template matching), so wider gaps keep them on one
%   shank. Returns the original file (SPACED false) when the probe has one
%   shank.
derivedFile = string(probeFile);
spaced = false;
probe = readJsonFile(probeFile);
x = double(probe.xc(:)); y = double(probe.yc(:)); k = double(probe.kcoords(:));
shanks = unique(k);
if numel(shanks) < 2
    fprintf('shank_spacing: the probe has one shank, so Kilosort4 sorts it as it is.\n');
    return
end
meanX = arrayfun(@(s) mean(x(k == s)), shanks);
[~, order] = sort(meanX);
rank = zeros(size(k));
for r = 1:numel(shanks)
    rank(k == shanks(order(r))) = r - 1;
end
xs = x + rank * spacing;
probe.xc = reshape(xs, size(probe.xc));

[~, pn] = fileparts(char(probeFile));
derivedFile = string(fullfile(char(runDir), pn + "_spaced.json"));
writeProbeMap(derivedFile, probe);
spaced = true;

% How far apart the shanks now are, next to the size of one shank.
same = k == k.';
d0 = hypot(x - x.', y - y.');
d1 = hypot(xs - xs.', y - y.');
fprintf(['Shanks %g um further apart for sorting: nearest sites on different shanks %.4g -> %.4g um ' ...
    '(farthest sites on one shank %.4g um).\n'], spacing, min(d0(~same)), min(d1(~same)), max(d0(same)));
end


function writeSettings(settings, settingsPath)
try
    txt = jsonencode(settings, 'PrettyPrint', true);
catch
    txt = jsonencode(settings);
end
fid = fopen(settingsPath, 'w');
if fid < 0
    error('EphysDataset:runKilosort:SettingsWriteFailed', ...
        'Could not write %s', settingsPath);
end
fwrite(fid, txt, 'char');
fclose(fid);
end


function writeRunScript(scriptPath)
%writeRunScript  Copy the checked-in run_ks4.py driver to scriptPath.
%   The script itself lives alongside this .m file (fully self-contained: it
%   reads the settings.json path from argv[1]); we just stage a copy next to
%   each run's settings for provenance.
template = fullfile(fileparts(mfilename('fullpath')), 'run_ks4.py');
if ~isfile(template)
    error('EphysDataset:runKilosort:ScriptMissing', ...
        'Could not find %s', template);
end
copyfile(template, scriptPath, 'f');
end
