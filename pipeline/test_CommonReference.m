function test_CommonReference()
%test_CommonReference  Common average / median reference (EphysDataset.applyReference).
%   Builds a universal-binary recording (recording.json + float32 .bin) with
%   a large noise common to every channel, one broken (10x noisier) and one
%   dead (flat) channel, then checks:
%     1. Reference "none" reads the recording as stored
%     2. suggestReferenceExclude flags the broken and the dead channel
%        (Ludwig et al. 2009: noise floor outside 0.3-2x the mean)
%     3. prepareReference takes the suggestion once, saves it in the
%        manifest, and never replaces a list set by hand
%     4. CAR / CMR subtract the mean / median of the good channels, sample
%        by sample (chunk and window reads agree), and remove the common noise
%     5. ExcludeChannels stay out of the reference too; too few channels warn,
%        none is an error
%     6. toBin records the reference in its info and sidecar
%     7. the Artifacts config section carries and validates the settings
%   No Intan files, toolboxes or Python are needed.
%
%   Usage:  test_CommonReference

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('CommonRef_test_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmssSSS'))));
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));

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

% --- fixture ----------------------------------------------------------------
Fs = 20000;
nSamp = 4 * Fs;
nChan = 8;
t = (0:nSamp-1).' / Fs;
rng(11);
common = 200 * sin(2*pi*60*t) + 20 * randn(nSamp, 1);   % line noise + broadband common noise
indep = 5 * randn(nSamp, nChan);
indep(:, 3) = 50 * randn(nSamp, 1);                     % broken site: 10x the independent noise
X = common + indep;
X(:, 6) = 0;                                            % dead site: flat
X = double(single(X));                                  % what the float32 file holds

recDir = fullfile(root, 'refrec');
mkdir(recDir);
fid = fopen(fullfile(recDir, 'refrec.bin'), 'w', 'ieee-le');
fwrite(fid, single(X.'), 'single');
fclose(fid);
BinaryReader.writeDescriptor(recDir, struct('data_file', "refrec.bin", 'dtype', "float32", ...
    'n_chan', nChan, 'fs', Fs, 'gain_to_uV', 1, 'offset', 0));

ds = EphysDataset(recDir);
plan = ds.streamPlan();
readAll = @(varargin) cell2mat(arrayfun(@(c) ds.readChunkUV(c, varargin{:}), plan(:), 'UniformOutput', false));

fprintf('\n== 1. no reference ==\n');
check(ds.ArtifactConfig.Reference == "none" && ds.ReferenceExcludeSource == "", 'the default is no reference, no list');
R0 = readAll();
check(isequal(size(R0), [nSamp nChan]) && max(abs(R0(:) - X(:))) < 1e-9, 'Reference "none" reads the recording as stored');
check(~ds.prepareReference() && ds.ReferenceExcludeSource == "", 'prepareReference does nothing without a reference');

fprintf('\n== 2. suggested channels ==\n');
[bad, info] = ds.suggestReferenceExclude();
check(isequal(bad, [3 6]), sprintf('the broken and the dead channel are suggested (got [%s])', num2str(bad)));
good = setdiff(1:nChan, [3 6]);
check(info.ratio(3) > 2 && info.ratio(6) < 0.3 && all(info.ratio(good) > 0.3 & info.ratio(good) < 2), ...
    'ratios: broken above 2x, dead below 0.3x, the rest inside');
check(info.low == 0.3 && info.high == 2 && info.cutoffHz == 300 && contains(info.summary, "2 of 8"), ...
    'bounds and cut-off from the ArtifactConfig defaults; a one-line summary');
b2 = ds.suggestReferenceExclude(High=3);
check(isequal(b2, 6), 'a wider band keeps the broken channel in');
errId = '';
try
    ds.suggestReferenceExclude(Low=2, High=1);
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:suggestReferenceExclude:Bounds'), 'Low >= High is refused');

fprintf('\n== 3. prepareReference and the manifest ==\n');
acfg = ds.ArtifactConfig;
acfg.Reference = "car";
ds.ArtifactConfig = acfg;
check(ds.prepareReference() && isequal(ds.ReferenceExclude, [3 6]) && ds.ReferenceExcludeSource == "suggested", ...
    'the first referenced read takes the suggestion');
m = readJsonFile(ds.manifestFile());
check(isfield(m, 'reference_exclude') && strcmp(m.reference_exclude.channels, '3,6') ...
    && strcmp(m.reference_exclude.source, 'suggested'), 'the suggestion is saved in the manifest');
check(~ds.prepareReference(), 'a list once set is not suggested again');
ds2 = EphysDataset(recDir);
ds2.applyManifest();
check(isequal(ds2.ReferenceExclude, [3 6]) && ds2.ReferenceExcludeSource == "suggested", 'the manifest restores the list');
ds2.ArtifactConfig = acfg;
ds2.ReferenceExclude = 3;
ds2.ReferenceExcludeSource = "manual";
check(~ds2.prepareReference() && isequal(ds2.ReferenceExclude, 3), 'a list set by hand is kept');

fprintf('\n== 4. CAR and CMR ==\n');
check(isequal(ds.referenceChannels(), good), 'the reference is taken over the good channels');
Rc = readAll();
expCar = X - mean(X(:, good), 2);
check(max(abs(Rc(:) - expCar(:))) < 1e-9, 'CAR subtracts the mean of the good channels from every channel');
check(max(abs(Rc(:, 6) + mean(X(:, good), 2))) < 1e-9, 'a channel left out is still referenced');
check(all(std(Rc(:, good)) < 0.35 * std(X(:, good))), 'CAR removes the common noise from the good channels');
check(max(abs(readAll(Reference=false) - X), [], 'all') < 1e-9, 'Reference=false reads the recording as stored');
if ds.supportsRandomAccess()
    W = ds.readWindowUV(1000, 500);
    check(max(abs(W - Rc(1001:1500, :)), [], 'all') < 1e-9, 'a window read is referenced like the chunk (sample by sample)');
end
acfg.Reference = "cmr";
ds.ArtifactConfig = acfg;
Rm = readAll();
expCmr = X - median(X(:, good), 2);
check(max(abs(Rm(:) - expCmr(:))) < 1e-9, 'CMR subtracts the median of the good channels');

fprintf('\n== 5. exclusions and channel counts ==\n');
ds.ExcludeChannels = 1;
check(isequal(ds.referenceChannels(), [2 4 5 7 8]), 'channels excluded from sorting stay out of the reference too');
[~, infoX] = ds.suggestReferenceExclude();
check(isnan(infoX.sigma(1)) && isequal(infoX.excluded, 1) && isequal(infoX.bad, [3 6]), ...
    'an excluded channel is neither counted in the mean nor suggested');
ds.ExcludeChannels = [1 2];
lastwarn('');
ws = warning('off', 'EphysDataset:prepareReference:FewChannels');
ds.prepareReference();
warning(ws);
[~, wid] = lastwarn();
check(strcmp(wid, 'EphysDataset:prepareReference:FewChannels'), 'a reference over fewer than 5 channels warns');
ds.ExcludeChannels = [1 2 4 5 7 8];
errId = '';
try
    ds.readChunkUV(plan(1));
catch ME
    errId = ME.identifier;
end
check(strcmp(errId, 'EphysDataset:applyReference:NoChannels'), 'a reference over no channel is an error');
ds.ExcludeChannels = double.empty(1, 0);

fprintf('\n== 6. toBin ==\n');
acfg.Reference = "car";
ds.ArtifactConfig = acfg;
ds.OutputDir = fullfile(root, 'out');
binInfo = ds.toBin();
check(strcmp(binInfo.reference.mode, 'car') && isequal(binInfo.reference.channels, good), 'toBin reports the reference');
side = readJsonFile(binInfo.metaFile);
check(isfield(side, 'reference') && strcmp(side.reference.mode, 'car') ...
    && isequal(side.reference.channels(:).', good), 'the .bin sidecar records the reference');
fid = fopen(binInfo.filename, 'r', 'ieee-le');
B = fread(fid, [nChan Inf], 'int16').';
fclose(fid);
check(max(abs(B(:) - round(expCar(:) * ds.Scale))) <= 1, 'the .bin holds the common-average-referenced signal');

fprintf('\n== 7. config ==\n');
a = EphysPipelineConfig.defaults("Artifacts");
check(a.Reference == "none" && a.ReferenceBadLow == 0.3 && a.ReferenceBadHigh == 2, 'Artifacts defaults');
a.Reference = "cmr"; a.ReferenceBadLow = 0.2; a.ReferenceBadHigh = 3;
c = EphysPipelineConfig.artifactConfig(a);
check(c.Reference == "cmr" && c.ReferenceBadLow == 0.2 && c.ReferenceBadHigh == 3, 'artifactConfig carries the reference');
cfg = EphysPipelineConfig();
cfg.Project.Root = root;
cfg.Artifacts.Reference = "average";
iss = cfg.validate();
check(any(iss.Step == "artifacts" & iss.Field == "Reference" & iss.Severity == "error"), 'an unknown Reference is an error');
cfg.Artifacts.Reference = "car";
cfg.Artifacts.ReferenceBadLow = 2;
iss = cfg.validate();
check(any(iss.Step == "artifacts" & iss.Field == "ReferenceBadLow" & iss.Severity == "error"), 'Low >= High is an error');
cfg.Artifacts.ReferenceBadLow = 0.3;
iss = cfg.validate();
check(~any(iss.Step == "artifacts" & iss.Severity == "error"), 'a valid reference passes');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_CommonReference:Failures', '%d checks failed.', nFail);
end
end
