function test_CommonReference()
%test_CommonReference  Common average / median reference (EphysDataset.applyReference).
%   Builds a universal-binary recording (recording.json + float32 .bin) with
%   a large noise common to every channel, one broken (10x noisier) and one
%   dead (flat) channel, then checks:
%     1. Reference "none" reads the recording as stored
%     2. suggestReferenceExclude flags the broken and the dead channel
%        (Ludwig et al. 2009: noise floor outside 0.3-2x the median)
%     3. prepareReference takes the suggestion once, saves it in the
%        manifest, and never replaces a list set by hand
%     4. CAR / CMR subtract the mean / median of the good channels, sample
%        by sample (chunk and window reads agree), and remove the common noise
%     5. ExcludeChannels stay out of the reference too; too few channels warn,
%        none is an error
%     6. toBin records the reference in its info and sidecar
%     7. the Artifacts config section carries and validates the settings
%     8. a few floating channels do not get every channel suggested, and a
%        suggestion that would leave too few channels is not applied
%     9. the common-mode detector still finds artifacts under a common
%        reference, and ExcludeChannels take no part in artifact detection
%    10. deriveSignals subtracts the reference (CAR / CMR over every good
%        channel, keepAmpChannels picked after it, reference=false opts out)
%        and erases the artifact periods after it
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
% A microvolt threshold that is really a robust-SD multiplier flags everything.
cfg.Artifacts.Enabled = true;
cfg.Artifacts.Method = "microvolts";
cfg.Artifacts.Threshold = 9;
iss = cfg.validate();
check(any(iss.Step == "artifacts" & iss.Field == "Threshold" & iss.Severity == "warning") ...
    && ~any(iss.Step == "artifacts" & iss.Severity == "error"), 'a 9 uV microvolts threshold warns');
cfg.Artifacts.Method = "commonmode";
iss = cfg.validate();
check(any(iss.Step == "artifacts" & iss.Field == "Threshold" & iss.Severity == "warning"), ...
    'so does a 9 uV common-mode threshold');
cfg.Artifacts.Threshold = 1500;
iss1 = cfg.validate();
cfg.Artifacts.Method = "rms";
cfg.Artifacts.Threshold = 9;
iss2 = cfg.validate();
check(~any(iss1.Field == "Threshold") && ~any(iss2.Field == "Threshold"), ...
    'a 1500 uV common-mode threshold and a 9 SD rms threshold do not');

fprintf('\n== 8. floating channels and the suggestion ==\n');
% 13 good channels at 8 uV and 3 floating ones at 200 uV: the mean noise
% (~44 uV) would put every good channel below 0.3x; the median does not.
rng(12);
Xf = 8 * randn(2 * Fs, 16);
Xf(:, [4 9 15]) = 200 * randn(2 * Fs, 3);
dsF = EphysDataset(writeRecording(root, 'floatrec', Xf, Fs));
[badF, infoF] = dsF.suggestReferenceExclude();
check(isequal(badF, [4 9 15]) && abs(infoF.medianSigma - 8) < 0.5, ...
    sprintf('only the floating channels are suggested (got [%s])', num2str(badF)));
dsF.ArtifactConfig.Reference = "car";
dsF.prepareReference();
check(isequal(dsF.referenceChannels(), setdiff(1:16, [4 9 15])), 'the reference is taken over the 13 good channels');
% Six channels whose suggestion (the quietest and the loudest) would leave
% four: it is not applied, and not worked out again.
X6 = randn(2 * Fs, 6) .* [2 5 8 8 11 40];
ds6 = EphysDataset(writeRecording(root, 'sixrec', X6, Fs));
check(isequal(ds6.suggestReferenceExclude(), [1 6]), 'the six-channel fixture suggests channels 1 and 6');
ds6.ArtifactConfig.Reference = "car";
lastwarn('');
ws = warning('off', 'EphysDataset:prepareReference:SuggestionNotApplied');
ds6.prepareReference();
warning(ws);
[~, wid] = lastwarn();
check(strcmp(wid, 'EphysDataset:prepareReference:SuggestionNotApplied') && isempty(ds6.ReferenceExclude) ...
    && ds6.ReferenceExcludeSource == "suggested" && isequal(ds6.referenceChannels(), 1:6), ...
    'a suggestion leaving fewer than 5 channels warns and leaves no channel out');
check(~ds6.prepareReference(), 'and is not suggested again');

fprintf('\n== 9. artifact detection, reference and exclusions ==\n');
% Five 3 mV artifacts common to 16 channels with per-channel gains 0.6-1.4:
% under a common reference the referenced channels' mean is ~0, so the
% common-mode detector has to measure the recording as stored.
rng(13);
Xc = 8 * randn(3 * Fs, 16);
at = round([0.4 0.9 1.4 1.9 2.4] * Fs);
for s = at
    Xc(s:s+39, :) = Xc(s:s+39, :) + 3000 * (0.6 + 0.8 * (0:15) / 15);
end
dsC = EphysDataset(writeRecording(root, 'cmrec', Xc, Fs));
dsC.ReferenceExcludeSource = "manual";            % every channel in the reference
dsC.ArtifactConfig.Enabled = true;
dsC.ArtifactConfig.Method = "commonmode";
dsC.ArtifactConfig.Threshold = 1500;
flagged = @(iv) arrayfun(@(s) any(iv(:, 1) <= (s + 19) / Fs & iv(:, 2) > (s + 19) / Fs), at);
for ref = ["none" "car" "cmr"]
    dsC.ArtifactConfig.Reference = ref;
    ivC = dsC.artifactIntervals();
    smC = dsC.analyzeArtifacts();
    check(all(flagged(ivC)) && size(ivC, 1) == 5 && smC.nIntervals == 5, ...
        sprintf('reference "%s": the common-mode detector flags all 5 artifacts', ref));
end
dsC.OutputDir = fullfile(root, 'cm_out');
iC = dsC.toBin(Blank=true, WriteMeta=false);       % reference "cmr" from the loop
check(iC.autoArtifact.nIntervals == 5 && iC.nAutoBlanked == smC.nBlanked, ...
    'toBin''s own common-mode detection flags them under the reference too');
% Ten pops on channels 1 and 2 only, both excluded from sorting: they satisfy
% MinChannels = 2 by themselves, but excluded channels take no part.
rng(14);
Xe = 8 * randn(3 * Fs, 16);
pops = round((0.2:0.25:2.45) * Fs);
for s = pops
    Xe(s:s+19, 1:2) = Xe(s:s+19, 1:2) + 2000;
end
dsE = EphysDataset(writeRecording(root, 'exrec', Xe, Fs));
dsE.ArtifactConfig.Enabled = true;                 % rms, 9 robust SDs, MinChannels 2
check(size(dsE.artifactIntervals(), 1) == numel(pops), 'the pops are flagged while channels 1-2 take part');
dsE.ExcludeChannels = [1 2];
smE = dsE.analyzeArtifacts();
check(isempty(dsE.artifactIntervals()) && smE.nBlanked == 0 && numel(smE.channelCounts) == 16 ...
    && all(smE.channelCounts(1:2) == 0), 'excluded channels flag nothing and count 0 in the summary');
smO = dsE.analyzeArtifacts(ChannelOrder=[2 5 1]);
check(numel(smO.channelCounts) == 3 && smO.channelCounts(1) == 0 && smO.channelCounts(3) == 0, ...
    'with a ChannelOrder the excluded channels are found by their recording number');
dsE.OutputDir = fullfile(root, 'ex_out');
iE = dsE.toBin(Blank=true, WriteMeta=false);
check(iE.nAutoBlanked == 0 && numel(iE.autoArtifact.channelCounts) == 16, ...
    'toBin''s own detection leaves the excluded channels out too');
dsE.ArtifactConfig.Reference = "car";
dsE.ReferenceExcludeSource = "manual";
check(isempty(dsE.artifactIntervals()), 'also under a common reference');

fprintf('\n== 10. the derived signals are referenced ==\n');
if license('test', 'Signal_Toolbox')
    dsS = EphysDataset(writeRecording(root, 'sigref', X, Fs));
    aS = dsS.ArtifactConfig; aS.Reference = "car"; dsS.ArtifactConfig = aS;
    dsS.ReferenceExclude = [3 6]; dsS.ReferenceExcludeSource = "manual";
    lfp = {'dataTypeOut', "LFP", 'LFP_Fs', Fs};   % at the recording rate, unfiltered: the amplifier data itself
    xs = single(X);
    near = @(A, B) max(abs(double(A(:)) - double(B(:)))) < 1e-2;   % single precision, ~200 uV signals
    [Yr, ~, Ir] = dsS.deriveSignals(lfp{:});
    carS = xs - mean(xs(:, good), 2);
    check(near(Yr.LFP, carS) && Ir.reference.mode == "car" && isequal(Ir.reference.channels, good), ...
        'CAR: the derived signal is the recording minus the mean of the good channels; info.reference says so');
    [Yk, ~, Ik] = dsS.deriveSignals(lfp{:}, keepAmpChannels=[6 2]);
    check(near(Yk.LFP, carS(:, [6 2])) && isequal(string(Ik.labels(:)).', ["ch6" "ch2"]), ...
        'keepAmpChannels picks from the referenced recording: the reference is still over every good channel');
    [Yn, ~, In] = dsS.deriveSignals(lfp{:}, reference=false);
    check(isequal(Yn.LFP, xs) && In.reference.mode == "none" && isempty(In.reference.channels), ...
        'reference=false: the recording as stored');
    art = [1.0 1.02];
    [Ya, ~, ~] = dsS.deriveSignals(lfp{:}, artifactIntervals=art);
    rows = (round(art(1) * Fs) + 1):round(art(2) * Fs);
    w = round(1e-3 * Fs);
    fillRef = mean(carS(rows(1)-w:rows(1)-1, :), 1) + (mean(carS(rows(end)+1:rows(end)+w, :), 1) ...
        - mean(carS(rows(1)-w:rows(1)-1, :), 1)) .* ((1:numel(rows)).' / (numel(rows) + 1));
    check(near(Ya.LFP(rows, :), fillRef), 'the artifact periods are erased after the reference, between the referenced levels');
    aS.Reference = "cmr"; dsS.ArtifactConfig = aS;
    [Ym, ~, Im] = dsS.deriveSignals(lfp{:});
    check(near(Ym.LFP, xs - median(xs(:, good), 2)) && Im.reference.mode == "cmr", ...
        'CMR: minus the median of the good channels');
else
    fprintf('  (skipped: no Signal Processing Toolbox)\n');
end

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_CommonReference:Failures', '%d checks failed.', nFail);
end
end


function recDir = writeRecording(root, name, X, Fs)
%writeRecording  A universal-binary recording (float32, microvolts) of X.
recDir = fullfile(root, name);
mkdir(recDir);
fid = fopen(fullfile(recDir, [name '.bin']), 'w', 'ieee-le');
fwrite(fid, single(X.'), 'single');
fclose(fid);
BinaryReader.writeDescriptor(recDir, struct('data_file', string(name) + ".bin", 'dtype', "float32", ...
    'n_chan', size(X, 2), 'fs', Fs, 'gain_to_uV', 1, 'offset', 0));
end
