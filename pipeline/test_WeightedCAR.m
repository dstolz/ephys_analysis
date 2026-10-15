function test_WeightedCAR()
%test_WeightedCAR  Adaptive weighted CAR (weightedCAR, Khorasani et al. 2019).
%   Checks:
%     1. weightedCAR equals a Kalman filter written out per channel (the
%        paper's eqs. 6-8, a separate P_i per channel, matrix form) for
%        Order 1 and 3, both estimates, with and without the high-pass
%     2. the posterior residual is the innovation * q / (n' P^- n + q)
%     3. a paper-style simulation (16 channels at 1 kHz, a 1.6 + 3.2 Hz
%        motion artifact, mixing U(-1,1) stepped every 2 s by N(0, 0.2^2),
%        -10 dB): the mean R^2 (eq. 11) of the weighted CAR beats CAR, which
%        beats no reference (relative only, no number from the paper)
%     4. uniform constant mixing: the weights, started at 0, end near 1
%     5. input checks, the HighpassHz path (DC offsets kept) and the output
%        class
%     6. deriveSignals(referenceMethod="weighted") on a universal-binary
%        recording: MUA / SPIKE equal weightedCAR followed by the band
%        filters, the LFP untouched, keepAmpChannels, Reference "none" (the
%        suggestion runs) or "cmr" (still the plain CAR), the automatic Q
%     7. the Signals config fields, their checks, signalOptions and the
%        runSignals log / dry-run text
%     8. an informational timing (seconds per channel-hour at 30 kHz)
%   Needs the Signal Processing and the Statistics and Machine Learning
%   Toolboxes; no Intan files or Python.
%
%   Usage:  test_WeightedCAR

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('WeightedCAR_test_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmssSSS'))));
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
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
        end
    end
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end

fprintf('\n== 1. the shared gain is the per-channel Kalman filter ==\n');
rng(1);
Fs = 1000; nS = 3000;
a = 30 * randn(nS, 1);
Z = 5 * randn(nS, 4) + a .* [0.5 1 1.5 2] + [10 -20 0 40];   % DC offsets too
n = mean(Z, 2);
scale = max(abs(Z), [], 'all');
for M = [1 3]
    for est = ["prior" "posterior"]
        for hpHz = [0 1]
            opt = {'Fs', Fs, 'Q', 25, 'Order', M, 'Alpha1k', 0.99, 'DriftPerSec', 2, ...
                'HighpassHz', hpHz, 'Estimate', est, 'W0', 0.8, 'P0', 2};
            [S, info] = weightedCAR(Z, n, opt{:});
            R = literalKalman(Z, n, M, info.alpha, info.V, 25, 0.8, 2, est, hpHz, Fs);
            check(max(abs(S - R), [], 'all') < 1e-9 * scale, ...
                sprintf('Order %d, %s, high-pass %g Hz: equal to the per-channel Kalman filter', M, est, hpHz));
        end
    end
end
check(abs(info.alpha - 0.99) < 1e-15 && abs(info.V - 2 / Fs) < 1e-15 && isequal(size(info.weights.final), [3 4]), ...
    'alpha = Alpha1k at 1 kHz, V = DriftPerSec / Fs, weights [Order x nCol]');
[~, i2] = weightedCAR(Z, n, Fs=2000, Q=25, Alpha1k=0.99);
check(abs(i2.alpha - 0.99^0.5) < 1e-15, 'at 2 kHz alpha = Alpha1k^(1/2): the decay per second is kept');

fprintf('\n== 2. posterior identity ==\n');
[Sp, ip] = weightedCAR(Z, n, Fs=Fs, Q=25, HighpassHz=0, Estimate="posterior", Alpha1k=0.99);
[~, e, d] = literalKalman(Z, n, 1, ip.alpha, ip.V, 25, 1, 1, "prior", 0, Fs);
check(max(abs(Sp - e .* (25 ./ d)), [], 'all') < 1e-9 * scale, ...
    'the posterior residual is the innovation scaled by q / (n'' P^- n + q)');

fprintf('\n== 3. paper-style simulation ==\n');
rng(13);
Fs = 1000; nS = 60 * Fs; nC = 16;
t = (0:nS-1).' / Fs;
s = filter(1, [1 -0.9], randn(nS, nC));          % each channel's own signal: AR(1), independent
s = s - mean(s);
art = sin(2*pi*1.6*t + rand*2*pi) + 0.5 * sin(2*pi*3.2*t + rand*2*pi);   % motion artifact
art = art .* (1 + 0.5 * sin(2*pi*0.05*t));
mix = zeros(nS, nC);
m = -1 + 2 * rand(1, nC);                         % U(-1,1)
for b = 0:2*Fs:nS-1                               % stepped every 2 s by N(0, 0.2^2)
    r = b+1:min(nS, b + 2*Fs);
    mix(r, :) = repmat(m, numel(r), 1);
    m = m + 0.2 * randn(1, nC);
end
A = mix .* art;
A = A * sqrt(mean(s(:).^2) / mean(A(:).^2) * 10);   % -10 dB
Z = s + A;
n = mean(Z, 2);
r2 = @(sh) mean(1 - sum((s - sh).^2) ./ sum((s - mean(s)).^2));   % eq. 11, averaged over channels
q = median((1.4826 * mad(hp(Z - n, 0.5, Fs), 1)).^2);
Sw = weightedCAR(Z, n, Fs=Fs, Q=q);
rNone = r2(Z); rCar = r2(Z - n); rW = r2(Sw);
fprintf('    mean R^2: none %.3f, CAR %.3f, weighted CAR %.3f\n', rNone, rCar, rW);
check(rW > rCar && rCar > rNone, 'weighted CAR > CAR > no reference (mean R^2)');

fprintf('\n== 4. uniform constant mixing ==\n');
rng(4);
Fs = 1000; nS = 20 * Fs;
t = (0:nS-1).' / Fs;
common = 100 * sin(2*pi*1.6*t) + 30 * randn(nS, 1);
Z = 5 * randn(nS, 16) + common;
n = mean(Z, 2);
[~, iu] = weightedCAR(Z, n, Fs=Fs, Q=25, W0=0);
check(abs(median(iu.weights.final) - 1) < 0.05, ...
    sprintf('started at 0, the median final weight is %.3f (within 0.05 of 1)', median(iu.weights.final)));
check(all(iu.weights.p5 <= iu.weights.median & iu.weights.median <= iu.weights.p95), 'p5 <= median <= p95');

fprintf('\n== 5. input checks, high-pass and class ==\n');
z1 = randn(100, 2); n1 = mean(z1, 2);
bad = {
    'Fs',          {z1, n1, 'Q', 1}
    'Q',           {z1, n1, 'Fs', 1000}
    'Q',           {z1, n1, 'Fs', 1000, 'Q', -1}
    'Order',       {z1, n1, 'Fs', 1000, 'Q', 1, 'Order', 0}
    'Order',       {z1, n1, 'Fs', 1000, 'Q', 1, 'Order', 1.5}
    'Alpha1k',     {z1, n1, 'Fs', 1000, 'Q', 1, 'Alpha1k', 1.5}
    'Alpha1k',     {z1, n1, 'Fs', 1000, 'Q', 1, 'Alpha1k', 0}
    'DriftPerSec', {z1, n1, 'Fs', 1000, 'Q', 1, 'DriftPerSec', 0}
    'HighpassHz',  {z1, n1, 'Fs', 1000, 'Q', 1, 'HighpassHz', 500}
    'Estimate',    {z1, n1, 'Fs', 1000, 'Q', 1, 'Estimate', "mean"}
    'Initial',     {z1, n1, 'Fs', 1000, 'Q', 1, 'P0', 0}
    'Size',        {z1, n1(1:50), 'Fs', 1000, 'Q', 1}};
allOk = true;
for k = 1:size(bad, 1)
    args = bad{k, 2};
    id = errorId(@() weightedCAR(args{:}));
    if ~strcmp(id, ['weightedCAR:' bad{k, 1}])
        allOk = false;
        fprintf(2, '    %s -> %s\n', bad{k, 1}, id);
    end
end
check(allOk, 'every bad option is refused with its own identifier');
rng(5);
Fs = 1000; nS = 20 * Fs;
offs = [100 -50 0 25];
Z = 5 * randn(nS, 4) + 40 * randn(nS, 1) .* [0.5 1 1.5 2] + offs;
n = mean(Z, 2);
mid = 2*Fs:nS-2*Fs;   % away from the filter's edge transients
Sh = weightedCAR(Z, n, Fs=Fs, Q=25);
check(max(abs(mean(Sh(mid, :)) - offs)) < 2, 'with the high-pass each channel keeps its own DC offset');
S0 = weightedCAR(Z, n, Fs=Fs, Q=25, HighpassHz=0);
check(max(abs(mean(S0(mid, :)) - offs)) > 10, 'HighpassHz = 0: the offsets mix through the weights');
Ss = weightedCAR(single(Z), single(n), Fs=Fs, Q=25);
check(isa(Ss, 'single') && isa(Sh, 'double') && max(abs(double(Ss) - Sh), [], 'all') < 1e-3, ...
    'the output takes the input''s class (single in, single out)');

fprintf('\n== 6. deriveSignals(referenceMethod="weighted") ==\n');
rng(6);
Fs = 20000; nS = 3 * Fs; nC = 8;
t = (0:nS-1).' / Fs;
artifact = 300 * sin(2*pi*1.6*t) .* (t > 1 & t < 2) + 50 * randn(nS, 1);
X = 10 * randn(nS, nC) + artifact .* linspace(0.5, 1.5, nC);
X = double(single(X));                             % what the float32 file holds
dsW = EphysDataset(writeRecording(root, 'wcarrec', X, Fs));
dsW.ReferenceExclude = []; dsW.ReferenceExcludeSource = "manual";   % every channel in the reference
xs = single(X);
Rs = mean(xs, 2);                                  % the plain CAR, as deriveSignals takes it
qAuto = zeros(1, nC);
for c = 1:nC
    x = dsW.filterContinuous(double(xs(:, c)) - double(Rs), Type="highpass", Cutoff=0.5, Fs=Fs);
    qAuto(c) = (1.4826 * mad(x, 1))^2;
end
qAuto = median(qAuto);
Sx = weightedCAR(xs, Rs, Fs=Fs, Q=qAuto);
all3 = {'dataTypeOut', ["LFP" "MUA" "SPIKE"], 'LFP_Fs', Fs, 'SPIKE_Fs', Inf};
[Yw, ~, Iw] = dsW.deriveSignals(all3{:}, referenceMethod="weighted");
dsPre = EphysDataset(writeRecording(root, 'wcarpre', double(Sx), Fs));   % the weighted-CAR'd recording itself
[Yp, ~, ~] = dsPre.deriveSignals(all3{:}, referenceSignals=strings(1, 0));
check(isequal(Yw.MUA, Yp.MUA) && isequal(Yw.SPIKE, Yp.SPIKE), ...
    'MUA and SPIKE equal weightedCAR followed by the band filters');
check(isequal(Yw.LFP, xs) && Iw.LFP.reference == "none" && Iw.MUA.reference == "wcar" && Iw.SPIKE.reference == "wcar", ...
    'the LFP is taken as recorded by default; MUA and SPIKE say "wcar"');
check(Iw.reference.mode == "wcar" && isequal(Iw.reference.channels, 1:nC) && isequal(Iw.reference.signals, ["MUA" "SPIKE"]) ...
    && abs(Iw.reference.wcar.Q - qAuto) < 1e-9 * qAuto && Iw.reference.wcar.QAuto ...
    && Iw.reference.wcar.Order == 1 && Iw.reference.wcar.Estimate == "prior" && isequal(size(Iw.reference.wcar.weights.final), [1 nC]), ...
    'info.reference: mode "wcar", channels, signals and wcar with the automatic Q');
check(dsW.ArtifactConfig.Reference == "none", 'it runs with ArtifactConfig.Reference "none"');
[Yk, ~, ~] = dsW.deriveSignals('dataTypeOut', "SPIKE", 'SPIKE_Fs', Inf, 'keepAmpChannels', [6 2], 'referenceMethod', "weighted");
check(isequal(Yk.SPIKE, Yw.SPIKE(:, [6 2])), 'keepAmpChannels: the kept columns equal the full run''s');
[~, ~, Iq] = dsW.deriveSignals('dataTypeOut', "SPIKE", 'referenceMethod', "weighted", ...
    'wcarOptions', struct('Q', 50, 'Estimate', "posterior", 'Order', 2));
check(Iq.reference.wcar.Q == 50 && ~Iq.reference.wcar.QAuto && Iq.reference.wcar.Estimate == "posterior" ...
    && Iq.reference.wcar.Order == 2, 'wcarOptions reach weightedCAR (a given Q is not automatic)');
aW = dsW.ArtifactConfig; aW.Reference = "cmr"; dsW.ArtifactConfig = aW;
[Yc, ~, Ic] = dsW.deriveSignals('dataTypeOut', "SPIKE", 'SPIKE_Fs', Inf, 'referenceMethod', "weighted");
check(isequal(Yc.SPIKE, Yw.SPIKE) && Ic.reference.mode == "wcar", ...
    'with Reference "cmr" the weighted CAR still weighs the plain CAR');
[Yo, ~, Io] = dsW.deriveSignals('dataTypeOut', "SPIKE", 'SPIKE_Fs', Inf);
check(Io.reference.mode == "cmr" && ~isequal(Yo.SPIKE, Yw.SPIKE), '"common" (the default) keeps the Reference section''s');
aW.Reference = "none"; dsW.ArtifactConfig = aW;
check(strcmp(errorId(@() dsW.deriveSignals('dataTypeOut', "SPIKE", 'referenceMethod', "weighted", ...
    'wcarOptions', struct('Gain', 1))), 'EphysDataset:deriveSignals:wcarOptions'), 'an unknown wcarOptions field is an error');
check(strcmp(errorId(@() dsW.deriveSignals('dataTypeOut', "SPIKE", 'referenceMethod', "weighted", ...
    'wcarOptions', struct('HighpassHz', Fs))), 'weightedCAR:HighpassHz'), 'a bad value is refused (before the read)');
dsS = EphysDataset(writeRecording(root, 'wcarsugg', X, Fs));   % ReferenceExclude never set
[~, ~, Is] = dsS.deriveSignals('dataTypeOut', "SPIKE", 'referenceMethod', "weighted");
check(dsS.ReferenceExcludeSource == "suggested" && Is.reference.mode == "wcar", ...
    'with Reference "none" the ReferenceExclude suggestion still runs (as for "car")');

fprintf('\n== 7. config ==\n');
G = EphysPipelineConfig.defaults("Signals");
check(G.ReferenceMethod == "common" && G.WCAR_Order == 1 && G.WCAR_Alpha1k == 1 && G.WCAR_DriftPerSec == 1 ...
    && isnan(G.WCAR_Q) && G.WCAR_HighpassHz == 0.5 && G.WCAR_Estimate == "prior", 'defaults');
so = EphysPipelineConfig.signalOptions(G);
check(so.referenceMethod == "common" && ~isfield(so, 'wcarOptions'), '"common": no wcarOptions');
G.ReferenceMethod = "weighted"; G.WCAR_Order = 2; G.WCAR_Q = 40; G.WCAR_Estimate = "posterior";
so = EphysPipelineConfig.signalOptions(G);
check(so.referenceMethod == "weighted" && isequal(so.wcarOptions, struct('Order', 2, 'Alpha1k', 1, 'DriftPerSec', 1, ...
    'Q', 40, 'HighpassHz', 0.5, 'Estimate', "posterior")), '"weighted": the WCAR_* fields as wcarOptions');
errs = struct();
G3 = G; G3.ReferenceMethod = "median";   errs.ReferenceMethod  = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.WCAR_Order = 17;              errs.WCAR_Order       = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.WCAR_Alpha1k = 0;             errs.WCAR_Alpha1k     = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.WCAR_DriftPerSec = -1;        errs.WCAR_DriftPerSec = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.WCAR_Q = 0;                   errs.WCAR_Q           = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.WCAR_HighpassHz = -1;         errs.WCAR_HighpassHz  = errorId(@() EphysPipelineConfig.signalOptions(G3));
G3 = G; G3.WCAR_Estimate = "mean";       errs.WCAR_Estimate    = errorId(@() EphysPipelineConfig.signalOptions(G3));
allOk = true;
for fnm = string(fieldnames(errs)).'
    if ~strcmp(errs.(fnm), "EphysPipelineConfig:Signals" + fnm)
        allOk = false;
        fprintf(2, '    %s -> %s\n', fnm, errs.(fnm));
    end
end
check(allOk, 'every WCAR error id is raised');
cfg = EphysPipelineConfig();
cfg.Project.Root = root;
cfg.Signals.Enabled = true;
cfg.Signals.ReferenceMethod = "weighted";
cfg.Signals.WCAR_Order = 0;
iss = cfg.validate(CheckPaths=false);
check(any(iss.Step == "signals" & iss.Field == "WCAR_Order" & iss.Severity == "error"), 'validate: a bad WCAR_Order is an error');
cfg.Signals.WCAR_Order = 1;                       % LFP only, and the LFP takes no reference
iss = cfg.validate(CheckPaths=false);
check(any(iss.Step == "signals" & iss.Field == "ReferenceMethod" & iss.Severity == "warning") ...
    && ~any(iss.Step == "signals" & iss.Severity == "error"), 'validate: "weighted" with no referenced signal warns');
cfg.Signals.MUA = true;
iss = cfg.validate(CheckPaths=false);
check(~any(iss.Step == "signals"), 'validate: "weighted" for the MUA passes');
cfgFile = fullfile(root, 'wcar_config.json');
cfg.save(cfgFile);
cfg2 = EphysPipelineConfig.load(cfgFile);
check(isequaln(cfg2.Signals, cfg.Signals) && isnan(cfg2.Signals.WCAR_Q), ...
    'the fields survive a JSON save / load round trip (NaN Q included)');

% runSignals: the dry-run text and the log
proj = fullfile(root, 'proj');
recP = fullfile(proj, 'mouse1', 'M1_260101_120000');
mkdir(fileparts(recP));
movefile(writeRecording(root, 'M1_260101_120000', X(1:Fs, :), Fs), recP);
cfg.Project.Root = proj;
cfg.Project.OutputRoot = fullfile(root, 'out');
cfg.Signals.LFP = false; cfg.Signals.SPIKE = true;
pipe = EphysPipeline(cfg);
logs = strings(0, 1);
pipe.LogFcn = @(msg) appendLog(msg);
    function appendLog(msg); logs(end+1, 1) = string(msg); end
pipe.runSignals(DryRun=true);
check(any(contains(pipe.Results.Message, "MUA+SPIKE WCAR referenced")), 'the dry run says "MUA+SPIKE WCAR referenced"');
pipe.reset();
pipe.runSignals();
check(all(pipe.Results.Status == "done") && any(contains(logs, "adaptive weighted CAR (WCAR) over 8 channel(s), subtracted from MUA, SPIKE") ...
    & contains(logs, "automatic")), 'the log names the weighted CAR, its channels, signals and automatic Q');

fprintf('\n== 8. timing (informational) ==\n');
Fs = 30000; nS = 60 * Fs; nC = 4;
Z = single(10 * randn(nS, nC) + 30 * randn(nS, 1));
n = mean(Z, 2);
t0 = tic; weightedCAR(Z, n, Fs=Fs, Q=100); t1 = toc(t0);
t0 = tic; weightedCAR(Z, n, Fs=Fs, Q=100, Order=3); t3 = toc(t0);
fprintf('    %.1f s per channel-hour at 30 kHz (Order 1), %.1f s (Order 3)\n', t1 / nC * 60, t3 / nC * 60);

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_WeightedCAR:Failures', '%d checks failed.', nFail);
end
end


function [S, e, d] = literalKalman(Z, n, M, alpha, v, q, W0, P0, est, hpHz, Fs)
%literalKalman  The paper's eqs. 6-8 per channel, each with its own P_i, in
%   matrix form. The weights are estimated from the high-passed Z and n
%   (hpHz > 0); the output subtracts the high-passed n's term from Z. E and
%   D are the innovation and n' P^- n + q, per sample and channel.
[nS, nC] = size(Z);
Zh = Z; nh = n;
if hpHz > 0
    Zh = hp(Z, hpHz, Fs);
    nh = hp(n, hpHz, Fs);
end
S = zeros(nS, nC); e = zeros(nS, nC); d = zeros(nS, nC);
for i = 1:nC
    w = [W0; zeros(M - 1, 1)];   % the prior at t = 1
    P = P0 * eye(M);
    for t = 1:nS
        nt = zeros(M, 1);
        for mm = 1:M
            if t - mm + 1 >= 1; nt(mm) = nh(t - mm + 1); end
        end
        d(t, i) = nt' * P * nt + q;
        K = P * nt / d(t, i);
        e(t, i) = Zh(t, i) - nt' * w;
        wh = w + K * e(t, i);
        Ph = (eye(M) - K * nt') * P;
        if est == "prior"
            S(t, i) = Z(t, i) - nt' * w;
        else
            S(t, i) = Z(t, i) - nt' * wh;
        end
        w = alpha * wh;
        P = alpha^2 * Ph + v * eye(M);
    end
end
end


function y = hp(x, cutHz, Fs)
%hp  Zero-phase 4th-order Butterworth high-pass as second-order sections.
[z, p, k] = butter(4, cutHz / (Fs / 2), 'high');
[sos, g] = zp2sos(z, p, k);
y = filtfilt(sos, g, x);
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
