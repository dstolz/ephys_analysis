function test_SpikeInterfaceSorting()
%test_SpikeInterfaceSorting  The SpikeInterface sorters beside Kilosort4 (Sorting.Sorter).
%   Checks the config (Sorting.Sorter / SIParams: defaults, the parameter
%   text kept through normalizeSection and a save / load, validation that
%   checks a SpikeInterface sorter's parameters and not Kilosort4's), the
%   dataset helpers (sortRunDir, sortingResultsDir following Sorter, the
%   manifest's sorter, isSpikeInterfaceSorter, sorterParamsProblem),
%   runSpikeInterface's dry run (settings.json, si_params.json verbatim,
%   run_si.py, runKilosort's result fields, the refusals), a background
%   launch through si_launch.cmd with a stand-in python that sets the
%   earlier sort's curation aside but keeps the sorter's own label tables
%   (Windows), the pipeline step (dry run rows, output path, plan, a
%   Kilosort4 run of the dataset holding a SpikeInterface sort back),
%   readPhyUnits on a SpikeInterface-shaped phy folder (labels from
%   cluster_SILabel.tsv, templates in uV, .bin rows as channels), and
%   run_si.py's good / mua labels against unitQualityPass. When the
%   "kilosort" conda env (or the miniconda base) has spikeinterface, it
%   also sorts a 32-channel synthetic recording with tridesclous2 end to
%   end (a few minutes) and reads the sort back.
%
%   Usage:  test_SpikeInterfaceSorting

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
        end
    end

root = fullfile(tempdir, sprintf('SI_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
tab = sprintf('\t');

% ---- fixtures: one recording, one probe ------------------------------------------
rng(5);
Fs = 30000; numAmp = 4; spb = 128; nSamp = 8 * spb;
proj = fullfile(root, 'proj');
rec = fullfile(proj, 'M1_260101_120000');
mkdir(rec);
writeSyntheticRHD(fullfile(rec, 'M1_260101_120000.rhd'), uint16(32768 + randi([-200 200], numAmp, nSamp)), ...
    zeros(1, nSamp), Fs, spb);
probeFile = fullfile(root, 'probe.json');
writeJsonFile(probeFile, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), 'yc', (0:numAmp-1) * 20, ...
    'kcoords', zeros(1, numAmp), 'n_chan', numAmp));
outRoot = fullfile(root, 'out');

fprintf('\n== 1. config: Sorting.Sorter and Sorting.SIParams ==\n');
c = EphysPipelineConfig();
check(c.Sorting.Sorter == "kilosort4" && isstruct(c.Sorting.SIParams) && isempty(fieldnames(c.Sorting.SIParams)), ...
    'by default Kilosort4 sorts, and no SpikeInterface sorter has parameters');
params = string(sprintf('{\n  "general": {"radius_um": 75},\n  "seed": null\n}'));
S = c.Sorting;
S.Sorter = "spykingcircus2";
S.SIParams = struct('spykingcircus2', params, 'tridesclous2', struct('detect_threshold', 6));
S = EphysPipelineConfig.normalizeSection("Sorting", S);
check(S.SIParams.spykingcircus2 == params && S.SIParams.tridesclous2 == "{""detect_threshold"":6}", ...
    'normalizeSection keeps each sorter''s parameters as text (an object written in place becomes its JSON)');
check(EphysPipelineConfig.siParams(S) == params && EphysPipelineConfig.siParams(S, "lupin") == "", ...
    'siParams: the parameters of the config''s sorter, "" for a sorter without any');
c.Sorting = S;
cfgFile = fullfile(root, 'si.json');
c.save(cfgFile);
c2 = EphysPipelineConfig.load(cfgFile);
check(c2.Sorting.Sorter == "spykingcircus2" && c2.Sorting.SIParams.spykingcircus2 == params ...
    && isempty(c2.LoadWarnings), 'a save / load keeps the sorter and its parameters as written (null and all)');

cv = EphysPipelineConfig();
cv.Sorting.Enabled = true;
cv.Sorting.PythonExe = "C:\envs\ks\python.exe";
cv.Sorting.Sorter = "spykingcircus2";
cv.Sorting.KS4.nt = 60;   % even: an error for Kilosort4
cv.Sorting.SIParams.spykingcircus2 = "{ ""general"": ";
has = @(I, field, sev) any(I.Step == "sorting" & I.Field == field & I.Severity == sev);
I = cv.validate(CheckPaths=false);
check(has(I, "SIParams", "error") && ~has(I, "KS4.nt", "error"), ...
    'a SpikeInterface sorter: its parameters are checked, Kilosort4''s are not');
cv.Sorting.SIParams.spykingcircus2 = "[1, 2]";
I = cv.validate(CheckPaths=false);
check(has(I, "SIParams", "error") && contains(strjoin(I.Message, " "), "JSON object"), ...
    'parameters that are not a JSON object are refused');
cv.Sorting.SIParams.spykingcircus2 = "{""a"": NaN, ""b"": -Infinity, ""c"": null}";
I = cv.validate(CheckPaths=false);
check(~has(I, "SIParams", "error") && ~has(I, "Sorter", "error"), 'NaN, Infinity and null (Python''s json reads them) pass');
cv.Sorting.Devices = "cuda:0";
I = cv.validate(CheckPaths=false);
check(has(I, "Devices", "warning"), 'Devices with a SpikeInterface sorter: a warning that it does not use them');
cv.Sorting.Sorter = "9lives";
I = cv.validate(CheckPaths=false);
check(has(I, "Sorter", "error"), 'a sorter name that is no identifier is refused');
cv.Sorting.Sorter = "kilosort4";
cv.Sorting.Devices = string.empty(1, 0);
I = cv.validate(CheckPaths=false);
check(has(I, "KS4.nt", "error") && ~has(I, "SIParams", "error"), ...
    'Kilosort4: its settings are checked as before, the SpikeInterface parameters are not');

fprintf('\n== 2. dataset helpers ==\n');
check(isequal(EphysDataset.isSpikeInterfaceSorter(["spykingcircus2" "kilosort4" "KiloSort4" "" "9x" "mountainsort5"]), ...
    [true false false false false true]), 'isSpikeInterfaceSorter: identifiers but kilosort4');
check(EphysDataset.sorterLabel("kilosort4") == "Kilosort4" && EphysDataset.sorterLabel("") == "Kilosort4" ...
    && EphysDataset.sorterLabel("tridesclous2") == "tridesclous2 (SpikeInterface)", 'sorterLabel');
check(EphysDataset.sorterOfRunDir(fullfile(root, 'si_lupin')) == "lupin" ...
    && EphysDataset.sorterOfRunDir(fullfile(root, 'kilosort4')) == "kilosort4" ...
    && EphysDataset.sorterOfRunDir(fullfile(root, 'variant_1')) == "kilosort4", 'sorterOfRunDir');
check(EphysDataset.sorterParamsProblem("") == "" && EphysDataset.sorterParamsProblem(" {} ") == "" ...
    && EphysDataset.sorterParamsProblem("{""a"": {""b"": [1, 2]}}") == "" ...
    && contains(EphysDataset.sorterParamsProblem("[1]"), "JSON object") ...
    && contains(EphysDataset.sorterParamsProblem("{"), "not valid JSON"), 'sorterParamsProblem');

d = EphysDataset(rec);
d.OutputDir = fullfile(outRoot, d.Name);
check(d.Sorter == "kilosort4" && strcmp(d.sortingResultsDir(), d.kilosortDir()) && strcmp(d.sortRunDir(), d.kilosortDir()), ...
    'a dataset''s sorted output is its kilosort4 folder by default');
check(strcmp(d.sortRunDir("tridesclous2"), fullfile(d.outputFolder(), 'si_tridesclous2')), ...
    'a SpikeInterface sorter''s run folder is <output folder>\si_<sorter>');
d.Sorter = "tridesclous2";
check(strcmp(d.sortingResultsDir(), d.sortRunDir("tridesclous2")), 'sortingResultsDir follows the dataset''s Sorter');
d.SortingDir = fullfile(root, 'elsewhere');
check(strcmp(d.sortingResultsDir(), fullfile(root, 'elsewhere')), 'a folder associated by hand still wins');
d.SortingDir = "";
d.writeManifest();
m = readJsonFile(d.manifestFile());
d2 = EphysDataset(rec);
d2.applyManifest();
check(m.kilosort.sorter == "tridesclous2" && d2.Sorter == "kilosort4", ...
    'the manifest records the sorter (kilosort.sorter); the config, not the manifest, sets it');

P = EphysProject(proj, OutputRoot=outRoot);
cp = EphysPipelineConfig();
cp.Project.Root = proj; cp.Project.OutputRoot = outRoot;
cp.Sorting.Sorter = "lupin";
EphysPipeline.applyConfigToDatasets(cp, P);
check(P.NumDatasets == 1 && P.Datasets(1).Sorter == "lupin" ...
    && strcmp(P.Datasets(1).sortingResultsDir(), fullfile(outRoot, d.Name, 'si_lupin')), ...
    'applyConfigToDatasets gives every dataset the config''s sorter');

fprintf('\n== 3. runSpikeInterface(DryRun=true) ==\n');
d.Sorter = "kilosort4";
d.ProbeFile = probeFile;
d.PythonExe = "C:\envs\ks\python.exe";
d.ArtifactConfig.Reference = "cmr";
params = string(sprintf('{\n  "detect_threshold": 6,\n  "seed": null\n}'));
res = d.runSpikeInterface(Sorter="tridesclous2", Params=params, DryRun=true, NJobs=3);
runDir = fullfile(d.sortRunDir("tridesclous2"), 'dryrun');
check(strcmp(res.runDir, runDir) && all(isfile(fullfile(runDir, ["settings.json" "si_params.json" "run_si.py"]))), ...
    'a dry run writes settings.json, si_params.json and run_si.py into si_tridesclous2\dryrun');
s = readJsonFile(fullfile(runDir, 'settings.json'));
check(s.sorter == "tridesclous2" && s.sorter_params == "si_params.json" && s.n_jobs == 3 && s.n_chan_bin == numAmp ...
    && s.fs == Fs && s.reference == "cmr" && s.quality.isiViolationsRatioMax == 0.5 && s.quality.unknown == "pass" ...
    && isfield(s, 'bin_scale') && strcmp(strrep(s.results_dir, '/', '\'), d.sortRunDir("tridesclous2")), ...
    'settings.json: the sorter, its parameter file, the .bin''s reference and scale, the criteria, n_jobs');
check(strtrim(string(fileread(fullfile(runDir, 'si_params.json')))) == params, ...
    'si_params.json holds the parameters exactly as given (null kept)');
check(contains(res.command, '"C:\envs\ks\python.exe"') && contains(res.command, 'run_si.py') ...
    && contains(res.command, 'settings.json'), 'the command runs run_si.py on settings.json');
rk = d.runKilosort(DryRun=true);
check(isempty(setxor(fieldnames(rk), fieldnames(res))) && res.sorter == "tridesclous2" && rk.sorter == "kilosort4" ...
    && strcmp(res.statusFile, fullfile(d.sortRunDir("tridesclous2"), 'si_status.json')) ...
    && strcmp(res.stdoutLog, fullfile(d.sortRunDir("tridesclous2"), 'si_run.log')), ...
    'runSpikeInterface returns runKilosort''s fields; its status and log are si_status.json / si_run.log');
d.ArtifactConfig.Reference = "none";
res0 = d.runSpikeInterface(Sorter="tridesclous2", DryRun=true);
s0 = readJsonFile(res0.settingsPath);
check(s0.reference == "none" && strtrim(string(fileread(fullfile(res0.runDir, 'si_params.json')))) == "{}", ...
    'no common reference: settings.json says so; no parameters: si_params.json is {} (the defaults)');
resX = d.runSpikeInterface(Sorter="tridesclous2", DryRun=true, ExcludeChannels=2);
px = readJsonFile(resX.probeFile);
check(resX.nExcludedChannels == 1 && isequal(px.chanMap(:).', [0 2 3]) && endsWith(string(resX.probeFile), "probe_excluded.json"), ...
    'excluded channels go into a derived probe in the run folder');
check(strcmp(errorId(@() d.runSpikeInterface(Sorter="kilosort4", DryRun=true)), 'EphysDataset:runSpikeInterface:BadSorter') ...
    && strcmp(errorId(@() d.runSpikeInterface(DryRun=true)), 'EphysDataset:runSpikeInterface:BadSorter'), ...
    'Kilosort4 (by name, or as the dataset''s sorter) is refused: runKilosort runs it');
check(strcmp(errorId(@() d.runSpikeInterface(Sorter="lupin", Params="[1]", DryRun=true)), ...
    'EphysDataset:runSpikeInterface:BadParams'), 'parameters that are not a JSON object are refused');
noShank = fullfile(root, 'noshank.json');
writeJsonFile(noShank, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), 'yc', (0:numAmp-1) * 20, 'n_chan', numAmp));
check(strcmp(errorId(@() d.runSpikeInterface(Sorter="lupin", ProbeFile=noShank, DryRun=true)), ...
    'EphysDataset:runSpikeInterface:BadProbe'), 'a probe that cannot be read is refused before anything is written');
check(strcmp(errorId(@() d.runSpikeInterface(Sorter="lupin", ArtifactIntervals=[0 nSamp / Fs])), ...
    'EphysDataset:runSpikeInterface:MostlySilenced'), 'blanking most of the recording is refused');

fprintf('\n== 4. a background launch (stand-in python) ==\n');
if ~ispc
    fprintf('  (skipped: the stand-in executable is a Windows batch file)\n');
else
    d.PythonExe = makeFake(root, 'fakesi.cmd');
    ws = warning('off', 'EphysDataset:toBin:Clipping');
    res = d.runSpikeInterface(Sorter="tridesclous2", ArtifactIntervals=[], Launch=false);
    warning(ws);
    siDir = d.sortRunDir("tridesclous2");
    writelines(["cluster_id" + tab + "SILabel"; "0" + tab + "good"], fullfile(siDir, 'cluster_SILabel.tsv'));
    writelines(["cluster_id" + tab + "si_unit_id"; "0" + tab + "7"], fullfile(siDir, 'cluster_si_unit_ids.tsv'));
    writelines(["cluster_id" + tab + "group"; "0" + tab + "noise"], fullfile(siDir, 'cluster_group.tsv'));   % phy's
    EphysDataset.writeUnitNotes(siDir, 0, "noisy");
    res = d.launchSorting(res, Wait=false);
    t0 = tic;
    while EphysDataset.sortRunState(res.statusFile) == "running" && toc(t0) < 60
        pause(0.5);
    end
    launcher = fullfile(siDir, 'si_launch.cmd');
    check(isfile(launcher) && ~isfile(fullfile(siDir, 'ks4_launch.cmd')) ...
        && contains(string(fileread(launcher)), "tridesclous2 (SpikeInterface)"), ...
        'a background run starts through si_launch.cmd, named for its sorter');
    check(EphysDataset.sortRunState(res.statusFile) == "done", 'its si_status.json says when it is done');
    check(all(isfile(fullfile(res.previousDir, ["cluster_group.tsv" "cluster_notes.tsv"]))) ...
        && all(isfile(fullfile(siDir, ["cluster_SILabel.tsv" "cluster_si_unit_ids.tsv"]))), ...
        'phy''s labels and the notes of the earlier sort go aside; the sorter''s own label tables stay');
    r = DatasetTracker.kilosortRunAt(string(siDir));
    check(~isempty(r) && r.State == "done" && endsWith(r.ScriptPath, "run_si.py") && endsWith(r.StatusPath, "si_status.json") ...
        && endsWith(r.LogPath, "si_run.log"), 'DatasetTracker reads a SpikeInterface run folder');
end

fprintf('\n== 5. the pipeline''s Sorting step ==\n');
cfg = EphysPipelineConfig();
cfg.Project.Root = proj;
cfg.Project.OutputRoot = outRoot;
cfg.Probe.DefaultProbeFile = probeFile;
cfg.Sorting.Enabled = true;
cfg.Sorting.PythonExe = "C:\envs\ks\python.exe";
cfg.Sorting.Sorter = "spykingcircus2";
cfg.Sorting.SIParams.spykingcircus2 = "{""general"": {""radius_um"": 60}}";
cfg.Sorting.DryRun = true;
cfg.Sorting.Execution = "blocking";
pipe = EphysPipeline(cfg);
dp = pipe.Project.Datasets(1);
check(dp.Sorter == "spykingcircus2" && strcmp(pipe.outputPathFor("sorting", dp), dp.sortRunDir("spykingcircus2")), ...
    'the pipeline gives the datasets its sorter; the step''s output is si_spykingcircus2');
pipe.runSorting();
R = pipe.Results;
dryParams = fullfile(dp.sortRunDir("spykingcircus2"), 'dryrun', 'si_params.json');
check(height(R) == 1 && R.Status(1) == "dry run" && contains(R.Message(1), "si_params.json") ...
    && isfile(dryParams) && contains(string(fileread(dryParams)), """radius_um"": 60"), ...
    'a dry run writes the SpikeInterface run files with the config''s parameters');
cfgB = cfg;
cfgB.Sorting.SIParams.spykingcircus2 = "{ broken";
pipe.Config = cfgB;
pipe.reset();
check(strcmp(errorId(@() pipe.runSorting()), 'EphysPipeline:SIParams'), 'parameters that do not parse stop the step');
pipe.Config = cfg;
pipe.reset();
resK = dp.runKilosort(Launch=false, ArtifactIntervals=[], ProbeFile=probeFile);   % a Kilosort4 run of this dataset, queued
pipe.PriorRuns = EphysPipeline.sortRun(dp.Name, resK, Queued=true);
cfgL = cfg; cfgL.Sorting.DryRun = false;
pipe.Config = cfgL;
Tk = pipe.plan(Steps="sorting");
pipe.runSorting();
R = pipe.Results;
check(R.Status(1) == "skipped" && contains(R.Message(1), "Kilosort4 is already queued") && Tk.Status(1) == "skip: Kilosort4 queued", ...
    'a Kilosort4 run of the dataset holds a SpikeInterface sort back (they share the .bin)');
pipe.PriorRuns = EphysPipeline.emptyRuns();
cfgS = cfg;
cfgS.Sorting.DryRun = false; cfgS.Sorting.Execution = "background"; cfgS.Sorting.MaxConcurrent = 2;
cfgS.Sorting.SIParams.spykingcircus2 = string(sprintf('{\n  "general": {"radius_um": 60},\n  "note": "it''s \\"quoted\\""\n}'));
txt = string(EphysPipelineScript.standalone(cfgS));
check(contains(txt, "d.Sorter = ""spykingcircus2"";") && contains(txt, "sorter = ""spykingcircus2"";") ...
    && contains(txt, "nJobs = max(1, floor(feature('numcores') / 2));") ...
    && contains(txt, "res = d.runSpikeInterface(Sorter=sorter, Params=siParams, Quality=quality, NJobs=nJobs, " + ...
        "ProbeFile=probe, ArtifactIntervals=iv, Launch=false);") && ~contains(txt, "d.runKilosort("), ...
    'the standalone script runs the SpikeInterface sorter, its runs sharing the cores');
lines = splitlines(txt);
i0 = find(startsWith(strtrim(lines), "siParams = strjoin(["), 1);
i1 = i0 - 1 + find(strtrim(lines(i0:end)) == "], newline);", 1);
siParams = ""; %#ok<NASGU>
eval(char(strjoin(lines(i0:i1), newline)));
check(siParams == cfgS.Sorting.SIParams.spykingcircus2, 'its parameter text evaluates back to the config''s, quotes and all');

fprintf('\n== 6. readPhyUnits on a SpikeInterface sort ==\n');
phy = fullfile(root, 'si_fixture');
mkdir(phy);
writeSIFixture(phy, Fs);
[U, info] = EphysDataset.readPhyUnits(phy, IncludeNoise=true, FullTemplates=true);
check(U.groupSource == "spikeinterface" && ~U.curated && isequal(U.group(:).', ["good" "mua"]) ...
    && isequal(U.class(:).', ["su" "mua"]), 'labels from cluster_SILabel.tsv (and its copy), not phy-curated');
check(U.templateUnits == "uV" && abs(max(abs(U.templateWaveform{1})) - 50) < 1e-9 ...
    && abs(U.templateTimeMs(31)) < 1e-12, ...
    'templates (not whitened, identity whitening_mat_inv.npy) come out in uV with bin_scale; nt0min aligns them');
check(isequal(U.channelMap(:).', [1 2 4]) && U.channel(1) == 2 && U.channel(2) == 4 ...
    && U.channelMapSource == "channel_map.npy", 'channel_map.npy holds .bin rows: recording channels 1, 2, 4');
check(isequal(U.nSpikes(:).', [3 2]) && numel(info.spikeSamples) == 5, 'spike times and clusters as written');
writelines(["cluster_id" + tab + "group"; "0" + tab + "noise"; "1" + tab + "good"], fullfile(phy, 'cluster_group.tsv'));
U = EphysDataset.readPhyUnits(phy, IncludeNoise=true);
check(U.groupSource == "phy" && U.curated && isequal(U.group(:).', ["noise" "good"]), 'curated in phy: phy''s labels win');

fprintf('\n== 7. run_si.py''s labels against unitQualityPass ==\n');
py = findSIPython(false);
if py == ""
    fprintf('  (skipped: no Python with numpy and pandas found)\n');
else
    Q = table((0:7).', [0 0.6 0.2 NaN 0.1 0 0 0].', [0.95 0.95 0.5 0.95 NaN 1 0.92 0.99].', ...
        [0.01 0.01 0.01 0.01 0.01 0.2 NaN 0.05].', [8 8 8 8 8 8 8 2].', [0 0 0 0 0 0 0 0].', [5 5 5 5 5 5 5 5].', ...
        'VariableNames', ["unitId" "isiViolationsRatio" "presenceRatio" "amplitudeCutoff" "snr" "driftPtp" "firingRate"]);
    crit = {unitQualityCriteria(), setfield(setfield(unitQualityCriteria(), 'snrMin', 4), 'unknown', "fail")}; %#ok<SFLD>
    for k = 1:numel(crit)
        mine = pythonLabels(py, here, root, Q, crit{k});
        expect = repmat("mua", height(Q), 1);
        expect(unitQualityPass(Q, crit{k})) = "good";
        check(isequal(mine(:), expect(:)), sprintf('criteria set %d: run_si.py labels as unitQualityPass judges', k));
    end
end

fprintf('\n== 8. a real sort: tridesclous2 on a synthetic recording ==\n');
py = findSIPython(true);
if py == ""
    fprintf('  (skipped: no Python with spikeinterface found)\n');
else
    syn = fullfile(root, 'syn', 'SYN-01_260101_120000');
    T = makeSyntheticRecording(syn, Format="binary", NumChannels=32, NumTrials=4, SortedOutput=false, ...
        WriteProbe=true, Artifacts=false);
    ds = EphysDataset(syn, ProbeFile=string(fullfile(syn, 'SYN-01_260101_120000_probe.json')));
    ds.PythonExe = py;
    ds.ArtifactConfig.Reference = "cmr";
    ds.Sorter = "tridesclous2";
    t0 = tic;
    res = ds.runSpikeInterface(ExcludeChannels=5, ArtifactIntervals=[], NJobs=4);
    fprintf('  (sorted in %.0f s)\n', toc(t0));
    st = readJsonFile(res.statusFile, ErrorOnFail=false);
    logText = "";
    if isfile(res.stdoutLog); logText = string(fileread(res.stdoutLog)); end
    check(res.status == 0 && isstruct(st) && st.state == "done" && st.num_units > 0, ...
        sprintf('tridesclous2 ran and found units (log ends: %s)', tailOf(logText, 200)));
    check(contains(logText, "referenced once") && contains(logText, "common_reference skipped"), ...
        'the .bin carries the CMR: the sorter''s own common reference was kept out');
    check(~isfolder(fullfile(res.resultsDir, 'si_work')) && ~isfolder(fullfile(res.resultsDir, 'si_export')) ...
        && ~isfile(fullfile(res.resultsDir, 'template_ind.npy')), 'the working folders are gone; templates are dense');
    [U, info] = ds.readSortedUnits(IncludeNoise=true);
    check(numel(U.unitId) == st.num_units && U.groupSource == "spikeinterface" && U.templateUnits == "uV" ...
        && all(ismember(U.group, ["good" "mua"])) && nnz(U.group == "good") == st.num_good, ...
        'readSortedUnits reads the sort: every unit labeled good or mua, templates in uV');
    check(numel(U.channelMap) == 31 && ~any(U.channelMap == 5) && all(ismember(U.channel, U.channelMap)), ...
        'the excluded channel is not sorted; the units'' channels are recording channels');
    check(numel(U.unitId) >= numel(T.units) / 2, sprintf('%d units found for %d in the recording', ...
        numel(U.unitId), numel(T.units)));
    [~, Qr] = ds.unitQuality(U, info);
    pass = unitQualityPass(Qr);
    check(isequal(pass(:), U.group(:) == "good"), 'its labels agree with unitQualityPass on the MATLAB metrics');
    W = EphysDataset.readPhyWaveforms(res.resultsDir, U.samples{1}(1:min(5, end)));
    check(~isempty(W) && all(isfinite(W(:))), 'readPhyWaveforms cuts spikes from the .bin params.py names');
    ds.writeManifest();
    o = DatasetOutputs(syn);   % no dataset, no config: the manifest says where the sort is
    check(strcmp(o.SortingDir, res.resultsDir) && o.pathSource("sorting") == "manifest", ...
        'a reader without the config finds the SpikeInterface sort through the manifest');
end

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_SpikeInterfaceSorting:Failures', '%d checks failed.', nFail);
end
end


% =========================================================================
function t = tailOf(txt, n)
%tailOf  The last N characters of TXT, on one line.
t = regexprep(string(txt), '\s+', ' ');
if strlength(t) > n; t = extractAfter(t, strlength(t) - n); end
end


function id = errorId(f)
id = '';
try
    f();
catch ME
    id = ME.identifier;
end
end


function fake = makeFake(folder, name)
%makeFake  A stand-in python.exe: called as <fake> <run_si.py> <settings.json>,
%   it writes a "done" si_status.json in the run folder (%~dp1).
fake = string(fullfile(folder, name));
L = ["@echo off"
    "ping -n 2 127.0.0.1 > nul"
    "echo {""state"": ""done"", ""num_units"": 0}> ""%~dp1si_status.json"""];
writelines(L, fake);
end


function writeSIFixture(phy, Fs)
%writeSIFixture  A phy folder as run_si.py leaves it: 2 units on 3 of 4 .bin
%   rows (2 excluded), dense templates of 90 samples, identity whitening,
%   bin_scale 2 and nt0min 30 in settings.json, cluster_SILabel.tsv and its
%   copy as cluster_group.tsv.
tab = sprintf('\t');
fid = fopen(fullfile(phy, 'params.py'), 'w');
fprintf(fid, 'dat_path = r''%s''\nn_channels_dat = 4\ndtype = ''int16''\noffset = 0\nsample_rate = %g\nhp_filtered = False\n', ...
    fullfile(phy, 'rec.bin'), Fs);
fclose(fid);
writeNPY(fullfile(phy, 'spike_times.npy'), int64([100; 200; 300; 400; 500]));
writeNPY(fullfile(phy, 'spike_clusters.npy'), int32([0; 1; 0; 1; 0]));
writeNPY(fullfile(phy, 'spike_templates.npy'), int32([0; 1; 0; 1; 0]));
tm = zeros(2, 90, 3);
tm(1, 31, 2) = -100;   % unit 0 peaks on sorted channel 2 (.bin row 1), 100 .bin units
tm(2, 31, 3) = -60;    % unit 1 on sorted channel 3 (.bin row 3)
writeNPY(fullfile(phy, 'templates.npy'), single(tm));
writeNPY(fullfile(phy, 'whitening_mat_inv.npy'), single(eye(3)));
writeNPY(fullfile(phy, 'channel_map.npy'), int32([0 1 3]));
writeNPY(fullfile(phy, 'channel_positions.npy'), single([0 0; 0 20; 0 60]));
writeNPY(fullfile(phy, 'amplitudes.npy'), single([100; 60; 100; 60; 100]));
writeJsonFile(fullfile(phy, 'settings.json'), struct('sorter', "tridesclous2", 'bin_scale', 2, 'nt0min', 30));
lab = ["cluster_id" + tab + "SILabel"; "0" + tab + "good"; "1" + tab + "mua"];
writelines(lab, fullfile(phy, 'cluster_SILabel.tsv'));
writelines(lab, fullfile(phy, 'cluster_group.tsv'));
end


function py = findSIPython(needSI)
%findSIPython  The kilosort env's python, else the miniconda base's, that has
%   numpy and pandas (and spikeinterface when NEEDSI); "" for none.
py = "";
mods = "import numpy, pandas";
if needSI; mods = mods + ", spikeinterface, probeinterface"; end
for base = [string(getenv('LOCALAPPDATA')), string(getenv('USERPROFILE'))]
    for c = [fullfile(base, 'miniconda3', 'envs', 'kilosort', 'python.exe'), fullfile(base, 'miniconda3', 'python.exe')]
        if ~isfile(c); continue; end
        [st, ~] = system(sprintf('"%s" -c "%s"', c, mods));
        if st == 0; py = c; return; end
    end
end
end


function labels = pythonLabels(py, here, root, Q, criteria)
%pythonLabels  run_si.unit_labels on the metrics of Q, SpikeInterface's names.
csv = fullfile(root, 'metrics.csv');
Tq = table(Q.isiViolationsRatio, Q.presenceRatio, Q.amplitudeCutoff, Q.snr, Q.driftPtp, Q.firingRate, ...
    'VariableNames', ["isi_violations_ratio" "presence_ratio" "amplitude_cutoff" "snr" "drift_ptp" "firing_rate"]);
writetable(Tq, csv);
crit = fullfile(root, 'criteria.json');
writeJsonFile(crit, criteria, NonFinite="string");
out = fullfile(root, 'labels.json');
script = fullfile(root, 'labels.py');
writelines(["import sys, json"
    "import pandas as pd"
    "sys.path.insert(0, sys.argv[1])"
    "import run_si"
    "m = pd.read_csv(sys.argv[2])"
    "c = json.load(open(sys.argv[3]))"
    "json.dump(run_si.unit_labels(m, c), open(sys.argv[4], 'w'))"], script);
[st, txt] = system(sprintf('"%s" "%s" "%s" "%s" "%s" "%s"', py, script, fullfile(here, '@EphysDataset'), csv, crit, out));
if st ~= 0
    error('test_SpikeInterfaceSorting:Python', 'run_si.unit_labels failed: %s', txt);
end
labels = string(jsondecode(fileread(out)));
end
