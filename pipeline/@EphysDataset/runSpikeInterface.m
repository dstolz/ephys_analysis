function result = runSpikeInterface(obj, opts)
%runSpikeInterface  Sort the recording with a SpikeInterface sorter via system().
%   RESULT = ds.runSpikeInterface(Sorter="spykingcircus2") is runKilosort
%   for the sorters SpikeInterface runs (spikeinterface.run_sorter): it
%   writes the same .bin (toBin: the artifact intervals blanked, the common
%   reference applied once), then a settings.json, the sorter's parameters
%   (si_params.json) and a copy of run_si.py into the run folder, and
%   launches run_si.py with a configurable python/conda executable through
%   SYSTEM (not MATLAB's pyenv). The Python needs spikeinterface (with
%   probeinterface) and the sorter. ds.ProbeFile must point to a Kilosort4
%   probe .json (probeMapProblems; refused with
%   EphysDataset:runSpikeInterface:BadProbe before anything is written):
%   run_si.py attaches it to the .bin, its chanMap indexing .bin rows, its
%   kcoords the shanks (channel groups).
%
%   run_si.py writes phy files straight into the run folder, in the layout
%   Kilosort4 leaves, so phy, readPhyUnits, the Review tab, the QC report
%   and the exports read them as they read a Kilosort4 sort:
%   channel_map.npy holds .bin rows, params.py names the .bin, templates.npy
%   is dense and not whitened (whitening_mat_inv.npy is the identity) with
%   the .bin's scale in settings.json (bin_scale), so templates come out in
%   uV, and spike_positions.npy holds each spike's center of mass. The
%   templates, amplitudes and quality metrics come from a 300 Hz high-pass
%   of the .bin. Each unit is labeled "good" or "mua" by the good-unit
%   criteria (Quality, unitQualityPass's rules, with SpikeInterface's quality
%   metrics) in cluster_SILabel.tsv, copied to cluster_group.tsv with that
%   header (phy's own copy says "group"), as Kilosort4 does with its
%   cluster_KSLabel.tsv. The sorter's working folder (si_work) is deleted
%   once the phy files are written.
%
%   The recording is referenced once: when the .bin carries the common
%   reference (ArtifactConfig.Reference "car" / "cmr"; for a BinFile given,
%   the reference its sidecar records), run_si.py keeps the sorter from
%   adding its own: a do_CAR / car parameter is set false, and the
%   common_reference call of SpikeInterface's internal sorters
%   (spykingcircus2, tridesclous2, lupin, on 32 channels or more) leaves the
%   recording as it is. With Reference "none" the sorter's own is the one.
%
%   RESULT = ds.runSpikeInterface(opts) with name-value options:
%     Sorter         SpikeInterface sorter name (default ds.Sorter);
%                    "kilosort4" is refused: runKilosort runs Kilosort4
%     Params         the sorter's parameters as JSON text, an object
%                    ("" = its defaults). run_si.py merges them over
%                    SpikeInterface's defaults (nested objects key by key)
%                    and drops, with a note in the log, top-level names the
%                    sorter does not have. Written to si_params.json as
%                    given. Text that is not a JSON object is refused with
%                    EphysDataset:runSpikeInterface:BadParams.
%     Quality        good-unit criteria for the labels (default
%                    unitQualityCriteria())
%     NJobs          worker processes SpikeInterface uses (default: the
%                    computer's cores)
%     PythonExe, CondaEnv, ProbeFile, ExcludeChannels, BinFile,
%     ArtifactIntervals, NChanBin, Fs, DryRun, Wait, Device, Launch,
%     Provenance     as for runKilosort; Device is passed on as --device
%                    and not used by the SpikeInterface sorters run here
%     ResultsDir     run folder (default ds.sortRunDir(Sorter):
%                    <output folder>\si_<sorter>)
%
%   run_si.py writes si_status.json (state "done" with num_units and
%   num_good, or "error") in the run folder, its output goes to si_run.log,
%   and a background run is started through si_launch.cmd and leaves
%   EphysDataset.SortExitMarker on exit, so launchSorting, sortRunState,
%   stopSortRun and the app follow it as they follow a Kilosort4 run.
%
%   RESULT has the fields of runKilosort's (sorter is the SpikeInterface
%   sorter; trueProbeFile is probeFile and shankSpacing 0).
%
%   See also EphysDataset.runKilosort, EphysDataset.launchSorting,
%   EphysDataset.spikeInterfaceSorters, EphysDataset.sortRunDir.

arguments
    obj (1,1) EphysDataset
    opts.Sorter (1,1) string = ""
    opts.Params (1,1) string = ""
    opts.Quality (1,1) struct = unitQualityCriteria()
    opts.NJobs (1,1) double = NaN
    opts.PythonExe (1,1) string = ""
    opts.CondaEnv (1,1) string = ""
    opts.ProbeFile (1,1) string = ""
    opts.ExcludeChannels (1,:) double = []
    opts.BinFile (1,1) string = ""
    opts.ResultsDir (1,1) string = ""
    opts.NChanBin (1,1) double = NaN
    opts.Fs (1,1) double = NaN
    opts.ArtifactIntervals double = NaN
    opts.DryRun (1,1) logical = false
    opts.Wait (1,1) logical = true
    opts.Device (1,1) string = ""
    opts.Launch (1,1) logical = true
    opts.Provenance = []   % ephysProvenance() of the run writing it ([] = made here)
end
prov = opts.Provenance;
if isempty(prov); prov = ephysProvenance(); end

sorter = firstNonEmpty(opts.Sorter, obj.Sorter);
if ~EphysDataset.isSpikeInterfaceSorter(sorter)
    error('EphysDataset:runSpikeInterface:BadSorter', ...
        ['"%s" is not a SpikeInterface sorter name (spykingcircus2, tridesclous2, ...); ' ...
         'Kilosort4 runs with runKilosort.'], sorter);
end
what = sorter + " (SpikeInterface)";
problem = EphysDataset.sorterParamsProblem(opts.Params);
if problem ~= ""
    error('EphysDataset:runSpikeInterface:BadParams', 'The %s parameters: %s', sorter, problem);
end

% Resolve config (per-call -> dataset)
pythonExe = firstNonEmpty(opts.PythonExe, obj.PythonExe);
condaEnv  = firstNonEmpty(opts.CondaEnv,  obj.CondaEnv);
probeFile = firstNonEmpty(opts.ProbeFile, obj.ProbeFile);
binGiven  = opts.BinFile ~= "";
binFile   = firstNonEmpty(opts.BinFile,   obj.BinFile);

if pythonExe == ""
    error('EphysDataset:runSpikeInterface:NoPython', ...
        'No python executable configured (set ds.PythonExe or pass PythonExe).');
end
if probeFile == ""
    error('EphysDataset:runSpikeInterface:NoProbe', ...
        'No probe file configured (set ds.ProbeFile or pass ProbeFile).');
end
if ~isfile(probeFile)
    error('EphysDataset:runSpikeInterface:ProbeMissing', 'Probe file not found: %s', probeFile);
end
problems = probeMapProblems(probeFile);
if ~isempty(problems)
    error('EphysDataset:runSpikeInterface:BadProbe', 'The probe %s cannot be read:\n  %s', ...
        probeFile, strjoin(problems, newline + "  "));
end
if ~opts.DryRun && binGiven && ~isfile(binFile)
    error('EphysDataset:runSpikeInterface:BinMissing', '.bin not found: %s', binFile);
end

if opts.ResultsDir ~= ""
    resultsDir = char(opts.ResultsDir);
else
    resultsDir = obj.sortRunDir(sorter);
end
resultsDir = absPath(resultsDir);
runDir = resultsDir;
if opts.DryRun
    runDir = fullfile(resultsDir, 'dryrun');   % keeps a finished run's own record as it is
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
        error('EphysDataset:runSpikeInterface:MostlySilenced', ...
            ['Artifact blanking would erase %.0f%% of the recording (%d period(s), %.4g of %.4g s; ' ...
             'limit %.0f%%). %s would find no spikes. Check the artifact detector settings ' ...
             'or turn off artifact silencing for this dataset.'], 100 * share, size(iv, 1), ...
            covered, obj.NumSamples / obj.Fs, what, 100 * EphysDataset.MaxSilencedFraction);
    end
    obj.toBin(ArtifactIntervals=iv, Provenance=prov);
end

binFile   = absPath(binFile);
probeFile = absPath(probeFile);
[nChanBin, fsVal, binScale, binRef] = resolveBinMeta(binFile, opts, obj, "runSpikeInterface");
if ~binGiven
    binScale = obj.binScale();   % what toBin used above
    binRef = string(EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig).Reference);   % what toBin subtracts
elseif ~isfinite(binScale) || binRef == ""
    warning('EphysDataset:runSpikeInterface:BinMetaUnknown', ...
        ['%s has no readable sidecar recording its scale and common reference: settings.json gets no ' ...
         'bin_scale (the templates stay in .bin units) and %s references the data as it would anyway.'], ...
        binFile, sorter);
end

if ~isfolder(runDir)
    mkdir(runDir);
end
checkProbeChannels(probeFile, nChanBin, "runSpikeInterface");

excludeCh = opts.ExcludeChannels;
if isempty(excludeCh); excludeCh = obj.ExcludeChannels; end
excludeCh = EphysDataset.parseChannelList(excludeCh);
nExcluded = 0;
if ~isempty(excludeCh)
    [probeFile, nExcluded] = writeExcludedProbe(probeFile, excludeCh, runDir, nChanBin, "runSpikeInterface");
    if nExcluded > 0
        fprintf('Excluding %d channel(s) from sorting: %s\n', ...
            nExcluded, char(EphysDataset.formatChannelList(excludeCh)));
    end
end

nJobs = opts.NJobs;
if ~(isfinite(nJobs) && nJobs >= 1)
    nJobs = feature('numcores');
end

paramsFile = 'si_params.json';
settings = struct();
settings.sorter      = char(sorter);
settings.n_chan_bin  = nChanBin;
settings.fs          = fsVal;
settings.data_dtype  = char(obj.Dtype);
settings.filename    = strrep(binFile, '\', '/');
settings.probe       = strrep(char(probeFile), '\', '/');
settings.results_dir = strrep(resultsDir, '\', '/');
settings.sorter_params = paramsFile;           % next to settings.json
if isfinite(binScale)
    settings.bin_scale = binScale;             % for readPhyUnits
end
if binRef == ""; binRef = "none"; end
settings.reference = char(binRef);            % "car" / "cmr": the sorter's own reference stays out
settings.quality   = opts.Quality;             % good-unit criteria for cluster_SILabel.tsv
settings.n_jobs    = round(nJobs);
settings.provenance = provenanceForJson(prov);

settingsPath = fullfile(runDir, 'settings.json');
scriptPath   = fullfile(runDir, 'run_si.py');
stdoutLog    = fullfile(resultsDir, 'si_run.log');
statusFile   = fullfile(resultsDir, 'si_status.json');

writeJsonFile(settingsPath, settings, NonFinite="string");
paramsText = opts.Params;
if strtrim(paramsText) == ""; paramsText = "{}"; end
writelines(paramsText, fullfile(runDir, paramsFile), Encoding="UTF-8");
template = fullfile(fileparts(mfilename('fullpath')), 'run_si.py');
if ~isfile(template)
    error('EphysDataset:runSpikeInterface:ScriptMissing', 'Could not find %s', template);
end
copyfile(template, scriptPath, 'f');

if condaEnv ~= ""
    command = sprintf('conda run -n %s "%s" "%s" "%s"', condaEnv, pythonExe, scriptPath, settingsPath);
else
    command = sprintf('"%s" "%s" "%s"', pythonExe, scriptPath, settingsPath);
end

result = struct();
result.status       = NaN;
result.sorter       = sorter;
result.command      = command;
result.stdoutLog    = char(stdoutLog);
result.scriptPath   = char(scriptPath);
result.settingsPath = char(settingsPath);
result.resultsDir   = resultsDir;
result.runDir       = runDir;
result.binFile      = binFile;
result.probeFile    = probeFile;
result.trueProbeFile = string(probeFile);
result.shankSpacing = 0;
result.excludeChannels = excludeCh;
result.nExcludedChannels = nExcluded;
result.dryRun       = opts.DryRun;
result.wait         = opts.Wait;
result.statusFile   = char(statusFile);
result.background   = false;
result.driverCommand = command;   % launchSorting adds --device
result.device       = "";
result.launched     = false;
result.previousDir  = "";

if opts.DryRun
    fprintf('[DryRun] Wrote %s, %s and %s\n', settingsPath, paramsFile, scriptPath);
    fprintf('[DryRun] Command: %s\n', command);
    return
end
if opts.Launch
    result = obj.launchSorting(result, Wait=opts.Wait, Device=opts.Device);
end
end


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
