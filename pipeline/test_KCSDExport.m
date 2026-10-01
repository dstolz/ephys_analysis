function test_KCSDExport()
%test_KCSDExport  Verification suite for the kCSD-python export.
%   Checks the NumPy archive layer (writeNPY text / shapes, writeNPZ and
%   readNPZ, zip64 records, archives numpy itself wrote), KCSDExport's
%   electrodes (probe order, 1-D / 2-D layouts, the column -> amplifier
%   channel mapping, bad and off-probe channels left out, the kCSD input
%   errors), events (0-based LFP samples on the recording's event clock,
%   with the exact-zero checks) and artifact samples, then
%   EphysDataset.exportKCSD end to end and DatasetOutputs' kcsd kind.
%   When a Python with NumPy is found (KCSD_PYTHON, else the miniconda base
%   install) the file is also read by numpy.load, and when that Python has
%   kcsd, KCSD1D runs on it; otherwise those checks are skipped.
%
%   Usage:  test_KCSDExport

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('KCSDExport_test_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmssSSS'))));
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
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end

fprintf('\n== 1. NumPy archives (writeNPY / writeNPZ / readNPZ) ==\n');
f = fullfile(root, 'a.npz');
A = struct('fs', 1000, 'meta', "{""k"": ""v""}", 'tab', [1 2], 'lab', ["ab" "c" ""], ...
    'P', single([1 2 3; 4 5 6]), 'idx', int64(7), 'none', zeros(0, 2), 'flag', true(1, 3));
info = writeNPZ(f, A, Shapes=struct('fs', "scalar", 'meta', "scalar", 'tab', "full", ...
    'lab', "vector", 'P', "transpose", 'idx', "vector", 'none', "full"));
check(isfile(f) && isequal(info.members, ["fs.npy" "meta.npy" "tab.npy" "lab.npy" "P.npy" "idx.npy" "none.npy" "flag.npy"]), ...
    'writeNPZ writes one .npy member per field, in field order');
R = readNPZ(f);
check(R.fs == 1000 && R.meta == A.meta && isequal(R.tab, [1 2]) && isequal(R.lab, ["ab"; "c"; ""]), ...
    'scalars, a one-row table and text come back');
check(isequal(R.P, A.P.') && isa(R.P, 'single'), 'Shape "transpose" stores DATA.'' as float32');
check(isequal(R.idx, int64(7)) && isequal(size(R.none), [0 2]) && isequal(R.flag, true(3, 1)), ...
    'a one-element vector, an empty [0 x 2] table and bools');
Rm = readNPZ(f, "meta");
check(isequal(fieldnames(Rm), {'meta'}) && Rm.meta == A.meta, 'readNPZ(FILE, VARS) reads only those members');
check(strcmp(errorId(@() readNPZ(f, "nope")), 'readNPZ:NoMember'), 'a member that is not there errors');
f64 = fullfile(root, 'z64.npz');
writeNPZ(f64, A, Shapes=struct('fs', "scalar", 'P', "transpose"), Zip64=true);
R64 = readNPZ(f64);
check(isequal(R64.P, A.P.') && R64.fs == 1000 && isequal(R64.lab, ["ab"; "c"; ""]), 'zip64 records are read back');
check(strcmp(errorId(@() writeNPY(fullfile(root, 'x.npy'), [1 2], Shape="scalar")), 'writeNPY:shape'), ...
    'Shape "scalar" with more than one element errors');
fz = fullfile(root, 'zipped.npz');
tmpNpy = fullfile(root, 'one.npy');
writeNPY(tmpNpy, int32([3 1 2]));
zip(fullfile(root, 'zipped.zip'), 'one.npy', root);   % a deflated member, as numpy.savez_compressed writes
movefile(fullfile(root, 'zipped.zip'), fz);
Rz = readNPZ(fz);
check(isequal(Rz.one, int32([3; 1; 2])), 'a compressed (deflated) member is read');

fprintf('\n== 2. KCSDExport.electrodes ==\n');
N = 1000; nCh = 6; Fs = 1000; origFs = 30000;
X = (1:N).' + 1000 * (1:nCh);                      % column c holds c*1000 + row (uV)
S = struct();
S.Y = struct('LFP', single(X), 'MUA', single([]), 'SPIKE', single([]));
S.info = struct('LFP', struct('Fs', Fs, 'filter', "none"), 'labels', "c" + (1:nCh), 'origFs', origFs, ...
    'badChannels', struct('columns', 3, 'channels', 3), ...
    'artifacts', struct('intervals', [0.2005 0.2105], 'fill', "line", 'nSamples', 12));
S.events = struct('din0', [15001 15100; 101 130] / origFs, 'Stim', zeros(0, 2));
laminar = struct('chanMap', 0:5, 'xc', zeros(1, 6), 'yc', (0:5) * 50, 'kcoords', zeros(1, 6), 'n_chan', 6);
twoCol  = struct('chanMap', 0:5, 'xc', [0 20 0 20 0 20], 'yc', [0 0 50 50 100 100], 'kcoords', zeros(1, 6), 'n_chan', 6);
partial = struct('chanMap', 0:3, 'xc', zeros(1, 4), 'yc', (0:3) * 50, 'kcoords', zeros(1, 4), 'n_chan', 4);
pLam = fullfile(root, 'laminar.json'); writeProbeMap(pLam, laminar);
pTwo = fullfile(root, 'twocol.json');  writeProbeMap(pTwo, twoCol);
pPart = fullfile(root, 'partial.json'); writeProbeMap(pPart, partial);
recFolder = fullfile(root, 'rec_A'); mkdir(recFolder);
fid = fopen(fullfile(recFolder, 'rec.bin'), 'w'); fwrite(fid, zeros(nCh, 100, 'int16'), 'int16'); fclose(fid);
BinaryReader.writeDescriptor(recFolder, struct('data_file', "rec.bin", 'dtype', "int16", 'n_chan', nCh, ...
    'fs', origFs, 'gain_to_uV', 0.195));             % a recording only for the channel count
ds = EphysDataset(recFolder);
ds.OutputDir = fullfile(root, 'out_A');

E = KCSDExport.electrodes(S, ds.channelLayout(ProbeFile=pLam));
check(E.dim == 1 && isequal(size(E.ele_pos), [5 1]), 'one column on one shank: a 1-D layout, [n x 1]');
check(isequal(E.column, [6; 5; 4; 2; 1]) && isequal(E.label, ["c6"; "c5"; "c4"; "c2"; "c1"]), ...
    'electrodes in probe order (top of the shank down), the bad channel left out');
check(max(abs(E.ele_pos - [250; 200; 150; 50; 0] / 1000)) < 1e-12 && isequal(E.y_um, [250; 200; 150; 50; 0]), ...
    'ele_pos is the position along the shank in mm');
check(height(E.excluded) == 1 && E.excluded.recordingChannel == 3 && contains(E.excluded.reason, "bad channel"), ...
    'the interpolated bad channel is listed as excluded');

Sr = S;
Sr.info.importOptions = struct('keepAmpChannels', [], 'channelRemap', 6:-1:1);   % column c = amplifier channel 7-c
Sr.info.badChannels = struct('columns', zeros(1, 0), 'channels', zeros(1, 0));
Er = KCSDExport.electrodes(Sr, ds.channelLayout(ProbeFile=pLam));
check(isequal(Er.column, (1:6).') && isequal(Er.recordingChannel, (6:-1:1).') && isequal(Er.y_um, (250:-50:0).'), ...
    'channelRemap: each column takes its amplifier channel''s site');
Sk = S;
Sk.Y.LFP = S.Y.LFP(:, 1:3);
Sk.info.labels = ["k2" "k4" "k6"];
Sk.info.importOptions = struct('keepAmpChannels', [2 4 6], 'channelRemap', []);
Sk.info.badChannels = struct('columns', zeros(1, 0), 'channels', zeros(1, 0));
Ek = KCSDExport.electrodes(Sk, ds.channelLayout(ProbeFile=pLam));
check(isequal(Ek.recordingChannel, [6; 4; 2]) && isequal(Ek.column, [3; 2; 1]) && isequal(Ek.y_um, [250; 150; 50]), ...
    'keepAmpChannels: the kept columns sit at their amplifier channels'' sites');

E2 = KCSDExport.electrodes(S, ds.channelLayout(ProbeFile=pTwo));
check(E2.dim == 2 && isequal(size(E2.ele_pos), [5 2]) && isequal(E2.ele_pos(1, :), [0 100] / 1000), ...
    'two columns: a 2-D layout of (x, y) in mm');
check(strcmp(errorId(@() KCSDExport.electrodes(S, ds.channelLayout(ProbeFile=pTwo), Dim=1)), 'KCSDExport:Duplicate'), ...
    'Dim=1 on two columns puts electrodes on one depth: KCSDExport:Duplicate');
Ep = KCSDExport.electrodes(S, ds.channelLayout(ProbeFile=pPart));
check(isequal(sort(Ep.column), [1; 2; 4]) && sum(Ep.excluded.reason == "not on the probe") == 2, ...
    'channels off the probe are left out and listed');
check(strcmp(errorId(@() KCSDExport.electrodes(S, ds.channelLayout(ProbeFile=pPart), Dim=2)), 'KCSDExport:TooFew') == false, ...
    'three electrodes in one column still make a 2-D layout (x all 0 is allowed with Dim=2)');
Sfew = S; Sfew.info.badChannels = struct('columns', [1 2], 'channels', [1 2]);
check(strcmp(errorId(@() KCSDExport.electrodes(Sfew, ds.channelLayout(ProbeFile=pPart), Dim=2)), 'KCSDExport:TooFew'), ...
    'under dim + 1 electrodes: KCSDExport:TooFew');
check(strcmp(errorId(@() KCSDExport.electrodes(S, ds.channelLayout(ProbeFile=""))), 'KCSDExport:NoProbe'), ...
    'no probe layout: KCSDExport:NoProbe');

fprintf('\n== 3. events and artifacts ==\n');
ev = KCSDExport.events(S.events, Fs, origFs);
check(isequal(ev.names, ["din0"; "Stim"]) && isequal(ev.line, int64([0; 0])), 'line names, 0-based line index');
check(isequal(ev.onset_sample, int64([3; 500])), ...
    'onset on recording row r lands on LFP sample round((r-1)/origFs*Fs), 0-based, sorted by onset');
check(ev.onset_sample(2) == 500 && abs(ev.onset_s(2) - 15001 / origFs) < 1e-12, ...
    'exact zero: row 15001 at 30 kHz is t = 0.5 s = LFP sample 500');
check(isequal(ev.offset_sample, int64([4; 503])), 'offsets on the same rule');
evSame = KCSDExport.events(struct('din0', [0.101 0.2]), Fs, Fs);
check(evSame.onset_sample == 100, 'at the recording rate the onset is its own row, 0-based');
evNaN = KCSDExport.events(struct('din0', [0.101 0.2]), Fs, NaN);
check(evNaN.onset_sample == 100, 'an unknown event rate takes the LFP rate');
evNone = KCSDExport.events(struct(), Fs, origFs);
check(isempty(evNone.line) && isempty(evNone.names), 'no events: empty arrays');
art = KCSDExport.artifacts(S.info.artifacts.intervals, Fs, N);
check(isequal(art.samples, int64([200 211])) && isequal(art.s, [0.2005 0.2105]), ...
    'an artifact period as 0-based [start stop) samples covering every sample it touches');

fprintf('\n== 4. EphysDataset.exportKCSD ==\n');
out = ds.exportKCSD(Extract=S, ProbeFile=pLam);
expected = string(fullfile(ds.outputFolder(), "rec_A_kcsd.npz"));
check(out.file == expected && isfile(out.file) && out.nElectrodes == 5 && out.dim == 1 && out.nExcluded == 1 ...
    && out.nEvents == 2 && out.probeFile == pLam, 'writes <Name>_kcsd.npz and reports what it holds');
check(isempty(dir(fullfile(ds.outputFolder(), '~*.partial.npz'))), 'no partial file is left');
K = readNPZ(out.file);
check(isequal(K.pots, single(X(:, [6 5 4 2 1]) / 1000).') && isequal(size(K.ele_pos), [5 1]), ...
    'pots is [n_ele x n_time] float32 in mV, rows matching ele_pos');
check(K.fs == Fs && isequal(K.label, ["c6"; "c5"; "c4"; "c2"; "c1"]) && isequal(K.extract_column, int64([6; 5; 4; 2; 1])) ...
    && isequal(K.recording_channel, int64([6; 5; 4; 2; 1])) && isequal(K.shank, int64(zeros(5, 1))), ...
    'fs and the per-electrode label / column / channel / shank');
check(K.excluded_label == "c3" && K.excluded_recording_channel == 3, 'the excluded channel is listed');
check(isequal(K.event_onset_sample, int64([3; 500])) && isequal(K.event_names, ["din0"; "Stim"]) ...
    && isequal(K.artifact_samples, int64([200 211])), 'events and artifacts as written by KCSDExport');
M = jsondecode(K.meta);
check(M.tool == "EphysDataset.exportKCSD" && M.dataset == "rec_A" && M.dim == 1 && M.units.ele_pos == "mm" ...
    && M.units.pots == "mV" && M.eventFs == origFs && string(M.sources.probeFile) == string(pLam) && M.artifactFill == "line", ...
    'meta: tool, dataset, units, eventFs, probe');
check(strcmp(errorId(@() ds.exportKCSD(Extract=S, ProbeFile=pLam)), 'EphysDataset:exportKCSD:Exists'), ...
    'an existing file is not replaced without Overwrite');
outN = ds.exportKCSD(Extract=S, ProbeFile=pLam, Events=false, Overwrite=true);
Kn = readNPZ(outN.file, ["event_line" "event_names"]);
check(outN.nEvents == 0 && isempty(Kn.event_line), 'Events=false writes no events');
check(strcmp(errorId(@() ds.exportKCSD(Extract=S, Overwrite=true)), 'EphysDataset:exportKCSD:NoProbe'), ...
    'a dataset without a probe: EphysDataset:exportKCSD:NoProbe');
ds.ProbeFile = pTwo;
out2 = ds.exportKCSD(Extract=S, File=fullfile(root, 'two.npz'));
check(out2.dim == 2 && out2.probeFile == pTwo, 'ProbeFile "" takes the dataset''s own probe');
ds.ProbeFile = "";
Snolfp = S; Snolfp.Y.LFP = single([]); Snolfp.info = rmfield(Snolfp.info, 'LFP'); Snolfp.Y.MUA = single(X);
Snolfp.info.MUA = struct('Fs', Fs);
check(strcmp(errorId(@() ds.exportKCSD(Extract=Snolfp, ProbeFile=pLam, Overwrite=true)), 'EphysDataset:exportKCSD:SignalMissing'), ...
    'an extract without LFP: EphysDataset:exportKCSD:SignalMissing');

fprintf('\n== 5. DatasetOutputs: the kcsd kind ==\n');
ds.exportKCSD(Extract=S, ProbeFile=pLam, Overwrite=true);
O = DatasetOutputs(ds);
check(O.has("kcsd") && O.KCSDFile == expected && O.pathSource("kcsd") == "discovered", ...
    'the .npz is found by its meta member');
Ko = O.KCSD;
check(isstruct(Ko.meta) && Ko.meta.dim == 1 && isequal(size(Ko.pots), [5 N]), 'KCSD loads the arrays, meta decoded');
Kv = O.load("kcsd", "ele_pos");
check(isequal(fieldnames(Kv), {'ele_pos'}), 'load("kcsd", vars) reads only those');
foreignFile = fullfile(ds.outputFolder(), "rec_A_other_kcsd.npz");
F = struct('ele_pos', [0; 1], 'meta', string(jsonencode(struct('tool', "EphysDataset.exportKCSD", 'dataset', "rec_B"))));
writeNPZ(foreignFile, F, Shapes=struct('meta', "scalar", 'ele_pos', "full"));
O.refresh();
check(any(O.Foreign == foreignFile) && O.KCSDFile == expected, 'a .npz whose meta names another dataset is foreign');
notOurs = fullfile(ds.outputFolder(), "rec_A_misc.npz");
writeNPZ(notOurs, struct('a', 1));
O.refresh();
check(~any(O.Candidates.File == notOurs) && ~any(O.Foreign == notOurs), 'a .npz without our meta is not an output');
T = O.inventory();
check(T.Exists(T.Kind == "kcsd") && T.Property(T.Kind == "kcsd") == "KCSDFile", 'inventory lists the kcsd kind');

fprintf('\n== 6. read by NumPy / kCSD-python (when available) ==\n');
py = findPython();
if py == ""
    fprintf('  (skipped: no Python with NumPy; set KCSD_PYTHON)\n');
else
    script = fullfile(root, 'check_kcsd.py');
    fid = fopen(script, 'w');
    fprintf(fid, '%s\n', ...
        "import json, sys", ...
        "import numpy as np", ...
        "d = np.load(sys.argv[1])", ...
        "assert d['ele_pos'].shape == (5, 1) and d['ele_pos'].dtype == np.float64", ...
        "assert d['pots'].shape == (5, 1000) and d['pots'].dtype == np.float32", ...
        "assert abs(d['pots'][0, 0] - 6.001) < 1e-6 and d['fs'].shape == ()", ...
        "assert list(d['label']) == ['c6', 'c5', 'c4', 'c2', 'c1']", ...
        "assert list(d['event_onset_sample']) == [3, 500] and d['event_onset_sample'].dtype == np.int64", ...
        "assert json.loads(d['meta'].item())['units']['pots'] == 'mV'", ...
        "print('numpy ok')", ...
        "try:", ...
        "    import scipy.integrate", ...
        "    if not hasattr(scipy.integrate, 'simps'): scipy.integrate.simps = scipy.integrate.simpson", ...
        "    from kcsd import KCSD1D", ...
        "except ImportError:", ...
        "    print('no kcsd'); sys.exit(0)", ...
        "k = KCSD1D(d['ele_pos'], d['pots'][:, 400:600], sigma=0.3, n_src_init=100, R_init=0.1, gdx=0.01)", ...
        "csd = k.values('CSD')", ...
        "assert csd.shape[1] == 200 and np.all(np.isfinite(csd))", ...
        "print('kcsd ok', csd.shape)");
    fclose(fid);
    [st, txt] = system(sprintf('"%s" "%s" "%s"', py, script, expected));
    check(st == 0 && contains(txt, "numpy ok"), 'numpy.load reads the arrays, shapes, dtypes and meta');
    if contains(txt, "no kcsd")
        fprintf('  (skipped: %s has no kcsd)\n', py);
    else
        check(st == 0 && contains(txt, "kcsd ok"), 'KCSD1D(ele_pos, pots) runs on the export');
    end
    if st ~= 0; fprintf(2, '%s\n', txt); end
end

fprintf('\n######## %d passed, %d failed ########\n', nPass, nFail);
if nFail > 0
    error('test_KCSDExport:Failures', '%d check(s) failed.', nFail);
end
end


function py = findPython()
%findPython  A Python with NumPy: KCSD_PYTHON, else the miniconda base install ("" for none).
py = "";
candidates = [string(getenv('KCSD_PYTHON')), ...
    string(fullfile(getenv('LOCALAPPDATA'), 'miniconda3', 'python.exe')), ...
    string(fullfile(getenv('USERPROFILE'), 'miniconda3', 'python.exe'))];
for c = candidates(candidates ~= "")
    if ~isfile(c); continue; end
    [st, ~] = system(sprintf('"%s" -c "import numpy"', c));
    if st == 0; py = c; return; end
end
end
