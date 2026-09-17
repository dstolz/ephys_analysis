function test_EphysPipelineScript()
%test_EphysPipelineScript  Verification suite for the script generator.
%   Generates the compact and the standalone script for a config over a
%   synthetic project (spike detection + exports enabled, sorting as a dry
%   run), checks both with checkcode, runs each into its own output root and
%   requires the spikes / chronux / fieldtrip files and si_config.json to
%   match between the two. Also checks that disabled steps are commented out
%   in the compact script, that the standalone script never uses the
%   EphysPipeline runner, and that literal(v) round-trips through eval.
%
%   Usage:  test_EphysPipelineScript

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('PipeScript_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
        end
    end

fprintf('\n== 1. literal round trips ==\n');
vals = {"a", "q""uote", ["a" "b"], string.empty(1,0), 3, [1 2 3], Inf, -Inf, NaN, [], true, false, ...
    [-0.5 1.5], struct('x', 1, 'y', "s", 'z', [1 2]), struct('n', struct('m', Inf)), {1, "a"}};
ok = true;
for k = 1:numel(vals)
    v = vals{k};
    txt = EphysPipelineScript.literal(v);
    w = eval(char(txt));
    if ~isequaln(w, v) || ~strcmp(class(w), class(v))
        ok = false;
        fprintf(2, '    literal #%d: %s -> class %s\n', k, txt, class(w));
    end
end
check(ok, 'eval(literal(v)) reproduces every value and class');
L = EphysPipelineScript.structLiteral("s", struct('a', 1, 'b', struct('c', "x")));
check(numel(L) == 4 && L(1) == "s = struct();" && L(3) == "s.b = struct();" && L(4) == "s.b.c = ""x"";", ...
    'structLiteral emits nested assignments');

% ---- fixtures ---------------------------------------------------------------
rng(3);
Fs = 30000; numAmp = 4; spb = 128; nSamp = 4 * spb;
ampRaw = uint16(randi([0 65535], numAmp, nSamp));
digRaw = zeros(1, nSamp); digRaw(50:70) = 1;
proj = fullfile(root, 'proj');
f1 = fullfile(proj, 'recA'); mkdir(f1);
writeSyntheticRHD(fullfile(f1, 'recA.rhd'), ampRaw, digRaw, Fs, spb);
probeFile = fullfile(root, 'probe.json');
writeJsonFile(probeFile, struct('chanMap', 0:numAmp-1, 'xc', zeros(1, numAmp), 'yc', (0:numAmp-1) * 20, ...
    'kcoords', zeros(1, numAmp), 'n_chan', numAmp));
phyDir = fullfile(root, 'phy');
makePhyFixture(phyDir, Fs, ChannelMap=[0 1 2 3], Legacy=true);
d = EphysDataset(f1);
d.SortingDir = phyDir;
d.ProbeFile = probeFile;
d.writeManifest();

cfg = EphysPipelineConfig();
cfg.Name = "script test";
cfg.Description = "generated-script equivalence";
cfg.Project.Root = proj;
cfg.Sorting.Enabled = true; cfg.Sorting.PythonExe = "C:\envs\ks\python.exe"; cfg.Sorting.DryRun = true;
cfg.Sorting.Execution = "blocking"; cfg.Sorting.KS4.nblocks = 2; cfg.Sorting.KS4ExtraJSON = "{""x_centers"": 2}";
cfg.Spikes.Enabled = true; cfg.Spikes.Source = "both"; cfg.Spikes.Filter = false;
cfg.Spikes.ThresholdMethod = "absolute"; cfg.Spikes.Threshold = 2000;
cfg.Export.Enabled = true; cfg.Export.Formats = ["chronux" "fieldtrip"]; cfg.Export.IncludeDetected = true;
cfg.Artifacts.Enabled = false;
% signals off: an extract is written by hand into each output root instead
cfg.Signals.Enabled = false;

outA = fullfile(root, 'outA'); outB = fullfile(root, 'outB');
src = d.readData();
Sx.Y = struct('LFP', single(src.amplifier(1:256, :)), 'MUA', single([]), 'SPIKE', single([]));
Sx.events = src.events;
Sx.info = struct('LFP', struct('Fs', Fs), 'labels', d.ChannelNames, 'origFs', Fs); %#ok<STRNU>
for o = [string(outA) string(outB)]
    mkdir(fullfile(o, 'recA'));
    save(fullfile(o, 'recA', 'recA_extract_LFP.mat'), '-struct', 'Sx');   % Signals.SeparateFiles (default)
end

fprintf('\n== 2. generate ==\n');
cfgA = cfg; cfgA.Project.OutputRoot = outA;
cfgB = cfg; cfgB.Project.OutputRoot = outB;
cfgFile = fullfile(root, 'pipeline.json');
cfgA = cfgA.save(cfgFile);
compactFile = fullfile(root, 'scripts', 'run_compact.m');
standaloneFile = fullfile(root, 'scripts', 'run_standalone.m');
txtC = EphysPipelineScript.compact(cfgA, File=compactFile);
txtS = EphysPipelineScript.standalone(cfgB, File=standaloneFile);
check(isfile(compactFile) && isfile(standaloneFile), 'both scripts written');
check(contains(txtC, "EphysPipelineConfig.load(") && contains(txtC, "pipe.runSpikeDetection();   % spikes") ...
    && contains(txtC, "% pipe.runSignals();   % signals (disabled") && contains(txtC, "% pipe.checkBehavior();"), ...
    'compact script loads the config and comments out disabled steps');
check(~contains(txtS, "EphysPipeline(") && ~contains(txtS, "EphysPipelineConfig.load(") && ~contains(txtS, "pipe."), ...
    'standalone script never uses the runner or a config file');
check(contains(txtS, "ks4.nblocks = 2;") && contains(txtS, "ks4.x_centers = 2;") && contains(txtS, "detectOptions.Threshold = 2000;") ...
    && contains(txtS, '"schema": "ephys-pipeline-config"'), 'standalone script carries the parameters and the config JSON as a comment');
check(contains(txtS, "if false   % set to true to run this step"), 'standalone disabled steps are wrapped in if false');
check(contains(txtS, "parallelOpts.UseParallel = false;") && contains(txtS, "parallelArgs{:}") ...
    && contains(txtS, "detectOptions.UseParallel = false;"), 'standalone script carries the Parallel section into the chunked steps');
mC = checkcode(compactFile, '-id');
mS = checkcode(standaloneFile, '-id');
isErr = @(m) arrayfun(@(x) startsWith(x.id, 'SYNER') || contains(x.message, 'Parse error'), m);
check(isempty(mC) || ~any(isErr(mC)), 'compact script has no checkcode errors');
check(isempty(mS) || ~any(isErr(mS)), 'standalone script has no checkcode errors');
if ~isempty(mS) && any(isErr(mS)); disp(mS(isErr(mS))); end

fprintf('\n== 3. run both ==\n');
outC = runScript(compactFile);
check(contains(outC, "recA") && isfile(fullfile(outA, 'recA', 'recA_spikes.mat')), 'compact script ran and wrote the spikes file');
outS = runScript(standaloneFile);
check(isfile(fullfile(outB, 'recA', 'recA_spikes.mat')), 'standalone script ran and wrote the spikes file');
check(~contains(outS, "FAILED"), 'standalone script reported no failures');
if contains(outS, "FAILED"); disp(outS); end
for f = ["recA_spikes.mat" "recA_chronux.mat" "recA_fieldtrip.mat"]
    A = load(fullfile(outA, 'recA', f));
    B = load(fullfile(outB, 'recA', f));
    A = stripVolatile(A); B = stripVolatile(B);
    check(isequaln(A, B), "identical " + f + " from both scripts");
end
siA = readJsonFile(fullfile(outA, 'recA', 'kilosort4', 'si_config.json'));
siB = readJsonFile(fullfile(outB, 'recA', 'kilosort4', 'si_config.json'));
check(isequaln(siA.ks4, siB.ks4) && siA.ks4.nblocks == 2 && siA.ks4.x_centers == 2 ...
    && isequaln(siA.preprocessing, siB.preprocessing), 'identical si_config.json (dry run) from both scripts');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysPipelineScript:Failures', '%d checks failed.', nFail);
end
end


function out = runScript(file)
%runScript  Run a script in a plain (non-static) workspace and capture its output.
out = evalc('run(file)');
end


function S = stripVolatile(S)
%stripVolatile  Drop timestamps / paths that legitimately differ between runs.
for f = ["conversion" "export"]
    if isfield(S, f)
        S = rmfield(S, f);
    end
end
if isfield(S, 'units') && isstruct(S.units) && isfield(S.units, 'readAt')
    S.units = rmfield(S.units, 'readAt');
end
if isfield(S, 'detected') && isstruct(S.detected)
    S.detected.detection = rmfield(S.detected.detection, 'options');
end
for f = ["spike" "spikeDetected" "data_LFP"]
    if isfield(S, f) && isstruct(S.(f)) && isfield(S.(f), 'hdr') && isfield(S.(f).hdr, 'orig')
        S.(f).hdr = rmfield(S.(f).hdr, 'orig');
    end
end
end
