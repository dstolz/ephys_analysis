function test_IntanReader()
%test_IntanReader  Verification suite for the Intan reader (IntanReader, read_Intan_RHD2000_file_modified).
%   Writes small RHD2000 recordings with the synthetic writers - every data
%   block layout (60 / 128 samples per block, unsigned / signed timestamps,
%   aux, supply, temperature, ADC, digital inputs and outputs, disabled
%   channels, the software notch) and every layout on disk (traditional,
%   one-file-per-signal, one-file-per-channel) - and checks: a whole-file
%   read decodes every signal as written; a truncated last block is ignored
%   and no file is left open, errors included; window reads equal the rows
%   of a whole read at any offset, across files; readDigitalEvents equals
%   readData's events and the written lines, without reading the amplifier
%   data; the run helpers (EphysReader.highRuns / joinRuns / planWindows);
%   the one-file-per-channel digital file names (RHX and RHD2000 Interface)
%   and the warning for a missing one; the recording start (AcqDate) from
%   RHX names and from modification times, and the Epsych2 session it
%   matches; the streamPlan chunks (recording offsets, no short last
%   chunk); readData's KeepChannels / Precision; synthetic recordings
%   stamped as RHX leaves its files.
%
%   Usage:  test_IntanReader

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('IntanReader_test_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmssSSS'))));
mkdir(root);
cleanup = onCleanup(@() rmdirQuiet(root));

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
    function id = lastWarningId(fcn)
        lastwarn('');
        fcn();
        [~, id] = lastwarn();
    end

rng(21);

%% ---- 1. whole-file reads: every block layout -------------------------------------
fprintf('\n== 1. whole-file reads: every block layout ==\n');
base = struct('nAmp', 3, 'nBlocks', 6, 'spb', 128, 'Fs', 20000, 'version', [2 0], 'nAux', 0, ...
    'nSupply', 0, 'nTemp', 0, 'nAdc', 0, 'digOrders', 0, 'doutOrders', [], 'disabled', [], ...
    'boardMode', 0, 'notch', 0, 'firstTs', 0);
specs = { ...
    "v1.0: 60 samples a block, unsigned timestamps past 2^31", ...
        struct('version', [1 0], 'spb', 60, 'nBlocks', 40, 'firstTs', 2^32 - 3000, 'nAux', 2, 'digOrders', [0 1]); ...
    "v1.1: temperature sensors", struct('version', [1 1], 'spb', 60, 'nTemp', 2); ...
    "v1.2: signed timestamps, negative", struct('version', [1 2], 'spb', 60, 'firstTs', -500, 'nTemp', 1); ...
    "v1.3: board ADC in board mode 1", struct('version', [1 3], 'spb', 60, 'nAdc', 2, 'boardMode', 1); ...
    "v2.0: aux, supply, temperature, ADC (mode 13), 16 inputs, 2 outputs, disabled channels", ...
        struct('nAux', 3, 'nSupply', 2, 'nTemp', 1, 'nAdc', 3, 'boardMode', 13, 'digOrders', 0:15, ...
        'doutOrders', [0 3], 'disabled', [2 5]); ...
    "v3.0 (RHX): inputs at bits 1..6, ADC in board mode 0", ...
        struct('version', [3 0], 'nAux', 3, 'nAdc', 1, 'digOrders', 1:6, 'firstTs', 12345); ...
    "no digital inputs", struct('digOrders', []); ...
    "v2.0 with the 60 Hz software notch (applied)", struct('notch', 2, 'nBlocks', 20); ...
    "v3.0 with the notch set (RHX saved it filtered: not applied)", struct('version', [3 0], 'notch', 2)};
layoutFiles = strings(1, 0);
for k = 1:size(specs, 1)
    s = base;
    for f = string(fieldnames(specs{k, 2})).'
        s.(f) = specs{k, 2}.(f);
    end
    folder = fullfile(root, sprintf('layout%d', k));
    mkdir(folder);
    file = fullfile(folder, sprintf('lay%d.rhd', k));
    F = writeLayout(file, s);
    D = read_Intan_RHD2000_file_modified(file, Verbosity="silent");
    bad = decodedAsWritten(D, F);
    check(isempty(bad), specs{k, 1} + ": every signal as written" + failed(bad));
    r = IntanReader(folder);
    r.refreshMetadata();
    n = s.nBlocks * s.spb;
    a = randi([0 n - 70]); m = randi([1 70]);
    plan = r.streamPlan();
    check(r.supportsRandomAccess() && isequal(r.readChunkUV(plan(1)), D.amplifier_data.') ...
        && isequal(r.readWindowUV(a, m), D.amplifier_data(:, a + (1:m)).'), ...
        specs{k, 1} + ": chunk and window reads equal the whole read");
    layoutFiles(end+1) = file; %#ok<AGROW>
end
D = read_Intan_RHD2000_file_modified(layoutFiles(5), Verbosity="silent");
check(numel(D.amplifier_channels) == 3 && isequal(string({D.amplifier_channels.native_channel_name}), ["A-000" "A-001" "A-002"]), ...
    'disabled channels are skipped (their records carry no samples)');

%% ---- 2. truncated last block, bad file, no file left open ---------------------------
fprintf('\n== 2. truncated last block, bad file, open files ==\n');
open0 = openedFiles();
tf = fullfile(root, 'trunc'); mkdir(tf);
copyfile(layoutFiles(5), fullfile(tf, 'cut.rhd'));
fid = fopen(fullfile(tf, 'cut.rhd'), 'a'); fwrite(fid, uint8(1:100)); fclose(fid);
Dw = read_Intan_RHD2000_file_modified(layoutFiles(5), Verbosity="silent");
Dt = read_Intan_RHD2000_file_modified(fullfile(tf, 'cut.rhd'), Verbosity="silent");
check(isequal(Dt.amplifier_data, Dw.amplifier_data) && isequal(Dt.board_dig_in_data, Dw.board_dig_in_data) ...
    && isequal(Dt.t_amplifier, Dw.t_amplifier), 'a truncated last block is ignored: the whole blocks read as before');
rt = IntanReader(tf);
lastwarn('');
evalc('rt.refreshMetadata();');                             % the warning text is captured, not shown
[~, id] = lastwarn();
check(strcmp(id, 'IntanReader:refreshMetadata:PartialBlock') && rt.PerFile.numDataBlocks == 6, ...
    'refreshMetadata warns and counts the whole blocks');
ws = warning('off', 'IntanReader:refreshMetadata:PartialBlock');
Et = rt.readDigitalEvents();
warning(ws);
check(isequal(rt.readWindowUV(0, 768), Dw.amplifier_data.') && Et.nSamples == 768, ...
    'window reads and readDigitalEvents work on the truncated file');
bf = fullfile(root, 'bad.rhd');
fid = fopen(bf, 'w'); fwrite(fid, uint32(12345), 'uint32'); fwrite(fid, zeros(1, 64)); fclose(fid);
check(strcmp(errorId(@() read_Intan_RHD2000_file_modified(bf, Verbosity="silent")), ...
    'read_Intan_RHD2000_file_modified:BadMagic'), 'a file that is not RHD2000 is refused with an identifier');
check(isequal(sort(openedFiles()), sort(open0)), 'no file is left open, after a read or an error');
movefile(fullfile(tf, 'cut.rhd'), fullfile(tf, 'cut2.rhd'));
check(isfile(fullfile(tf, 'cut2.rhd')), 'the files read can be renamed (not locked)');

%% ---- 3. window reads over a multi-file recording ----------------------------------------
fprintf('\n== 3. window reads across files ==\n');
Fs = 20000;
fa = fullfile(root, 'multi');
names = ["rec_260101_100000.rhd" "rec_260101_100001.rhd" "rec_260101_100002.rhd" "rec_260101_100003.rhd"];
blocks = [5 0 7 3];                                          % the second file holds no data block
N = sum(blocks) * 128;
W = zeros(1, N, 'uint16');
W(600:700) = 1;                                              % bit 0 across the file 1 | file 3 boundary (640)
W(1530:1540) = bitor(W(1530:1540), 8);                       % bit 3 across the file 3 | file 4 boundary (1536)
W(end - 2:end) = bitor(W(end - 2:end), 8);
R = writeTraditional(fa, names, blocks, 128, Fs, W, 'DigInNames', ["p" "q"], 'DigInOrders', [0 3], ...
    'AuxRaw', 3, 'Version', [3 0]);
ra = IntanReader(fa);
ra.refreshMetadata();
ws = warning('off', 'IntanReader:readData:NoData');
full = ra.readData();
warning(ws);
X = 0.195 * (double(R.amp.') - 32768);
check(isequal(full.amplifier, X), 'readData: the recording as written (the empty file adds nothing)');
wins = [0 1; 0 N; 635 10; 1530 12; N - 5 10; N 3; 100 0; 639 1; 640 1];
wins = [wins; [randi([0 N - 1], 20, 1), randi([1 400], 20, 1)]];
ok = true;
for k = 1:size(wins, 1)
    a = wins(k, 1); m = wins(k, 2);
    ok = ok && isequal(ra.readWindowUV(a, m), X(a + 1 : min(a + m, N), :));
end
check(ra.supportsRandomAccess() && ok, sprintf('%d windows equal the rows of the whole read (across files, clipped at the end, empty)', size(wins, 1)));
plan = ra.streamPlan();
check(isequal([plan.sampleOffset], [0 640 640 1536]) && isequal([plan.nSamples], [640 0 896 384]), ...
    'rhd chunks carry their recording offsets');
check(isequal(ra.readChunkUV(plan(3)), X(641:1536, :)) && isempty(ra.readChunkUV(plan(2))), ...
    'readChunkUV reads one file (empty for a file without data)');
ps = ra.streamPlan(Files=[names(4) names(1) "nope.rhd"]);
check(isequaln([ps.sampleOffset], [1536 0 NaN]), ...
    'a Files subset keeps each file''s recording offset (NaN for a file not in the recording)');
% pre-v3 files with the software notch: the notch runs from each file's first sample
fb = fullfile(root, 'notch');
Wb = uint16(randi([0 1], 1, 70 * 60));
writeTraditional(fb, ["n_a.rhd" "n_b.rhd"], [40 30], 60, 25000, Wb, 'Version', [1 0], 'NotchMode', 1);
rb = IntanReader(fb);
rb.refreshMetadata();
fb1 = read_Intan_RHD2000_file_modified(fullfile(fb, 'n_a.rhd'), Verbosity="silent");
fb2 = read_Intan_RHD2000_file_modified(fullfile(fb, 'n_b.rhd'), Verbosity="silent");
Xb = [fb1.amplifier_data, fb2.amplifier_data].';
check(isequal(rb.readWindowUV(2350, 200), Xb(2351:2550, :)) && isequal(rb.readWindowUV(17, 5), Xb(18:22, :)) ...
    && isequal(rb.readData().amplifier, Xb), 'notch-filtered (pre-3.0) files: windows equal the rows of the whole read');

%% ---- 4. readDigitalEvents: the events readData gives, without the amplifier data ------
fprintf('\n== 4. readDigitalEvents ==\n');
% one-file-per-signal: lines at bits 0, 7 and 15
fs = fullfile(root, 'signal_rec');
mkdir(fs);
ns = 9000;
writeInfoRHD(fullfile(fs, 'info.rhd'), 3, Fs, 0, DigInNames=["x" "y" "z"], DigInOrders=[0 7 15], ...
    DigInNative=["DIGITAL-IN-01" "DIGITAL-IN-08" "DIGITAL-IN-16"], Version=[3 0]);
As = int16(randi([-3000 3000], 3, ns));
writeDat(fullfile(fs, 'amplifier.dat'), As, 'int16');
Ws = zeros(1, ns, 'uint16'); Ws(1:10) = 1; Ws(4000:4100) = 128; Ws(ns - 20:ns) = bitor(Ws(ns - 20:ns), 32768);
writeDat(fullfile(fs, 'digitalin.dat'), Ws, 'uint16');
% one-file-per-channel, RHX file names
fc = fullfile(root, 'channel_rhx');
mkdir(fc);
writeInfoRHD(fullfile(fc, 'info.rhd'), 2, Fs, 0, DigInNames=["p" "q"], DigInOrders=[0 3], ...
    DigInNative=["DIGITAL-IN-01" "DIGITAL-IN-04"], Version=[3 0]);
Ac = int16(randi([-3000 3000], 2, ns));
for c = 1:2; writeDat(fullfile(fc, sprintf('amp-A-%03d.dat', c - 1)), Ac(c, :), 'int16'); end
p = zeros(1, ns, 'uint16'); p(50:60) = 1; p(ns) = 1;
q = zeros(1, ns, 'uint16'); q(1:3) = 1; q(5000:5999) = 1;
writeDat(fullfile(fc, 'board-DIGITAL-IN-01.dat'), p, 'uint16');
writeDat(fullfile(fc, 'board-DIGITAL-IN-04.dat'), q, 'uint16');
cases = { ...
    "traditional, 4 files (one empty), lines across file boundaries", fa, {W, [0 3]}; ...
    "traditional, v1.0 files with the notch", fb, {Wb, 0}; ...
    "one-file-per-signal, lines at bits 0 / 7 / 15", fs, {Ws, [0 7 15]}; ...
    "one-file-per-channel, RHX file names", fc, {[p; q], []}};
for k = 1:size(cases, 1)
    r = IntanReader(cases{k, 2});
    r.refreshMetadata();
    nProg = 0;
    E = r.readDigitalEvents(ProgressFcn=@(varargin) progress());
    ws = warning('off', 'IntanReader:readData:NoData');
    d = r.readData(KeepChannels=1, Precision="single");
    warning(ws);
    Eref = struct('events', d.events, 'Fs', d.Fs, 'nSamples', size(d.amplifier, 1), ...
        'digInNames', string(d.digInNames), 'digInNativeNames', string(d.digInNativeNames));
    words = cases{k, 3}{1}; bits = cases{k, 3}{2};
    truth = true;
    keys = string(fieldnames(E.events)).';
    for j = 1:numel(keys)
        if isempty(bits)
            x = words(j, :) > 0;
        else
            x = bitget(words, bits(j) + 1) > 0;
        end
        truth = truth && isequal(E.events.(keys(j)), refRuns(x) / r.Fs);
    end
    check(isequal(E, Eref) && truth && numel(keys) == numel(r.DigInNames) && nProg == max(1, r.NumFiles * (k <= 2)), ...
        cases{k, 1} + ": the events readData gives, and the lines as written");
end
    function progress()
        nProg = nProg + 1;
    end

%% ---- 5. the run helpers ------------------------------------------------------------------
fprintf('\n== 5. run helpers ==\n');
x = rand(1, 20000) > 0.97;
x(1:3) = true; x(end) = true;
x(5000:5100) = true;                                         % a run the block cuts go through
cuts = unique([0, sort(randi(19999, 1, 30)), 5000, 5050, 5101, 20000]);
parts = cell(1, numel(cuts) - 1);
for k = 1:numel(cuts) - 1
    parts{k} = EphysReader.highRuns(x(cuts(k) + 1 : cuts(k + 1)), cuts(k));
end
ref = refRuns(x);
check(isequal(EphysReader.highRuns(x), ref) && isequal(EphysReader.joinRuns(parts), ref) ...
    && isequal(EphysReader.highSegments(x, 1000), ref / 1000), ...
    'highRuns of blocks joined == highRuns of the whole == a diff-based reference');
check(isequal(EphysReader.highRuns(false(0, 1)), zeros(0, 2)) && isequal(EphysReader.highRuns(true(5, 1)), [1 5]) ...
    && isequal(EphysReader.joinRuns({}), zeros(0, 2)) && isequal(EphysReader.highSegments(zeros(4, 1), 10), zeros(0, 2)) ...
    && isequal(EphysReader.highRuns([0 2 0 1], 10), [12 12; 14 14]), 'edge cases: empty, all high, offsets, numeric input');
if license('test', 'Image_Toolbox') && exist('bwlabel', 'file')
    lab = bwlabel(x(:));
    u = unique(lab(lab > 0));
    old = [arrayfun(@(a) find(lab == a, 1, 'first'), u), arrayfun(@(a) find(lab == a, 1, 'last'), u)];
    check(isequal(old, ref), 'the same runs as the bwlabel code the readers used before');
end
w = uint16([0 1 2 32768 65535]);
check(isequal(EphysReader.wordBit(w, 0), logical([0 1 0 0 1])) && isequal(EphysReader.wordBit(w, 15), logical([0 0 0 1 1])) ...
    && ~any(EphysReader.wordBit(w, 16)), 'wordBit: bits 0..15; a bit a 16-bit word has not is never set');
[o1, l1] = EphysReader.planWindows(100, 30, 5);
[o2, l2] = EphysReader.planWindows(100, 30, 20);
[o3, l3] = EphysReader.planWindows(90, 30, 20);
[o4, l4] = EphysReader.planWindows(0, 30, 20);
[o5, l5] = EphysReader.planWindows(10, 30, 20);
[o6, l6] = EphysReader.planWindows(90, 30, 100);
check(isequal([o1; l1], [0 30 60 90; 30 30 30 10]) && isequal([o2; l2], [0 30 60; 30 30 40]) ...
    && isequal([o3; l3], [0 30 60; 30 30 30]) && isequal([o4; l4], [0; 0]) && isequal([o5; l5], [0; 10]) ...
    && isequal([o6; l6], [0 30 60; 30 30 30]), ...
    'planWindows: a leftover shorter than the minimum joins the window before it; full windows stay');

%% ---- 6. one-file-per-channel digital files ------------------------------------------------
fprintf('\n== 6. one-file-per-channel digital file names ==\n');
fo = fullfile(root, 'channel_din');                          % RHD2000 Interface names, by native_order
copyfile(fc, fo);
movefile(fullfile(fo, 'board-DIGITAL-IN-01.dat'), fullfile(fo, 'board-DIN-00.dat'));
movefile(fullfile(fo, 'board-DIGITAL-IN-04.dat'), fullfile(fo, 'board-DIN-03.dat'));
Ec = IntanReader(fc).readDigitalEvents();
Eo = IntanReader(fo).readDigitalEvents();
check(isequal(Eo, Ec) && isequal(Ec.digInNativeNames, ["DIGITAL-IN-01" "DIGITAL-IN-04"]), ...
    'board-<native name>.dat (RHX) and board-DIN-<order>.dat (RHD2000 Interface) read alike');
fm = fullfile(root, 'channel_missing');
copyfile(fc, fm);
delete(fullfile(fm, 'board-DIGITAL-IN-04.dat'));
rm = IntanReader(fm);
Em = [];                                                    % set by evalc (it cannot add a variable here)
lastwarn('');
evalc('Em = rm.readDigitalEvents();');                      % the warning text is captured, not shown
[~, id] = lastwarn();
check(strcmp(id, 'IntanReader:splitDigitalEvents:NoDigitalFile') && isequal(Em.digInNativeNames, "DIGITAL-IN-01") ...
    && isequal(string(fieldnames(Em.events)), "DIGITAL_IN_01") && isequal(Em.events.DIGITAL_IN_01, Ec.events.DIGITAL_IN_01), ...
    'a line without its file is left out, with a warning; the others are read');
ws = warning('off', 'IntanReader:splitDigitalEvents:NoDigitalFile');
dm = rm.readData(KeepChannels=1);
warning(ws);
check(isequal(dm.digInNativeNames, "DIGITAL-IN-01") && isfield(dm.events, 'DIGITAL_IN_01'), 'readData leaves it out too');
fn = fullfile(root, 'signal_nodig');
copyfile(fs, fn);
delete(fullfile(fn, 'digitalin.dat'));
rn = IntanReader(fn); %#ok<NASGU> read by evalc
En = [];
lastwarn('');
evalc('En = rn.readDigitalEvents();');
[~, id] = lastwarn();
check(strcmp(id, 'IntanReader:splitDigitalEvents:NoDigitalFile') && isempty(En.digInNames) && isempty(fieldnames(En.events)), ...
    'one-file-per-signal without digitalin.dat: no lines, with a warning');

%% ---- 7. the recording start (AcqDate) -----------------------------------------------------
fprintf('\n== 7. recording start ==\n');
check(IntanReader.nameTime("rat01_260922_100000") == datetime(2026, 9, 22, 10, 0, 0) ...
    && IntanReader.nameTime("subjA_260101T120000_260101_120004") == datetime(2026, 1, 1, 12, 0, 4) ...
    && isnat(IntanReader.nameTime("rec_001")) && isnat(IntanReader.nameTime("x_261399_250000")), ...
    'nameTime reads the trailing _yyMMdd_HHmmss RHX adds (NaT without a valid one)');
t0 = datetime(2026, 9, 22, 10, 0, 0);
f1 = fullfile(root, 'acq_rhx');
writeTraditional(f1, ["m1_260922_100000.rhd" "m1_260922_100001.rhd"], [2 2], 128, Fs, zeros(1, 512, 'uint16'));
setFileModifiedTime(fullfile(f1, "m1_260922_100000.rhd"), t0 + minutes(1));   % closed later than the name says
setFileModifiedTime(fullfile(f1, "m1_260922_100001.rhd"), t0 + minutes(2));
d1 = EphysDataset(f1);
check(d1.AcqDate == t0 && EphysReader.forFolder(string(f1)).AcqDate == t0, ...
    'traditional: the time in the first file''s RHX name (after a refresh and from discovery alone)');
f2 = fullfile(root, 'acq_plain');                             % dir gives file times to the second:
tA = datetime(2026, 9, 22, 9, 30, 0);                         % a start from them is good to 1 s
writeTraditional(f2, ["a.rhd" "b.rhd"], [100 50], 128, Fs, zeros(1, 150 * 128, 'uint16'));
setFileModifiedTime(fullfile(f2, "a.rhd"), tA + seconds(100 * 128 / Fs));            % RHX: stamped when closed
setFileModifiedTime(fullfile(f2, "b.rhd"), tA + seconds(150 * 128 / Fs));
d2 = EphysDataset(f2);
check(abs(seconds(d2.AcqDate - tA)) < 1 && abs(seconds(EphysReader.forFolder(string(f2)).AcqDate - tA)) < 1, ...
    'traditional without RHX names: the first file''s modification time less its duration');
f3 = fullfile(root, 'm2_260922_110000');
mkdir(f3);
writeInfoRHD(fullfile(f3, 'info.rhd'), 1, Fs);
writeDat(fullfile(f3, 'amplifier.dat'), int16(zeros(1, 2000)), 'int16');
setFileModifiedTime(fullfile(f3, 'amplifier.dat'), datetime(2026, 9, 22, 12, 0, 0));
check(EphysDataset(f3).AcqDate == datetime(2026, 9, 22, 11, 0, 0), 'split layout: the time in the folder''s RHX name');
% a one-hour split recording whose folder has no RHX name: amplifier.dat was
% closed at 11:00, so the recording started at 10:00 - its own Epsych2 session
% (09:59) matches, not the next animal's (11:05)
f4 = fullfile(root, 'splitrec');
mkdir(f4);
Fs4 = 100;
writeInfoRHD(fullfile(f4, 'info.rhd'), 1, Fs4);
writeDat(fullfile(f4, 'amplifier.dat'), int16(zeros(1, 3600 * Fs4)), 'int16');
t1 = datetime(2026, 9, 22, 10, 0, 0);
setFileModifiedTime(fullfile(f4, 'amplifier.dat'), t1 + hours(1));
d4 = EphysDataset(f4);
T = table(["own.mat"; "next.mat"], ["own"; "next"], [t1 - minutes(1); t1 + minutes(65)], ...
    'VariableNames', {'File', 'Stem', 'StartTime'});
m = matchEpsychSession(T, d4);
check(abs(seconds(d4.AcqDate - t1)) < 1 && m.file == "own.mat" && m.method == "time", ...
    'split layout without an RHX name: amplifier.dat''s time less the duration; the recording''s own session matches');

%% ---- 8. streamPlan: no short last chunk ---------------------------------------------------
fprintf('\n== 8. streamPlan chunks ==\n');
f5 = fullfile(root, 'plan_rec');
mkdir(f5);
writeInfoRHD(fullfile(f5, 'info.rhd'), 2, Fs);
A5 = int16(round(randn(2, 3 * Fs + 12) * 200));
writeDat(fullfile(f5, 'amplifier.dat'), A5, 'int16');
writeDat(fullfile(f5, 'digitalin.dat'), zeros(1, 3 * Fs + 12, 'uint16'), 'uint16');
d5 = EphysDataset(f5);
p5 = d5.streamPlan(MaxChunkSamples=Fs);
check(isequal([p5.sampleOffset], [0 Fs 2 * Fs]) && isequal([p5.nSamples], [Fs Fs Fs + 12]), ...
    'a 12-sample leftover joins the last chunk');
p6 = d5.streamPlan(MaxChunkSamples=Fs / 4);
check(numel(p6) == 12 && p6(end).nSamples == Fs / 4 + 12 && sum([p6.nSamples]) == 3 * Fs + 12, ...
    'chunk boundaries are otherwise unchanged');
if license('test', 'Signal_Toolbox')
    nl = [];
    id = '';
    try
        nl = d5.noiseLevels(Filter=true, MaxChunkSamples=Fs);
    catch ME
        id = ME.identifier;
    end
    check(isempty(id) && nl.nChunks == 3 && nl.nSamples == 3 * Fs + 12, ...
        'a filtered streaming pass (noiseLevels) runs where a 12-sample chunk made filtfilt fail');
end

%% ---- 9. readData: KeepChannels and Precision -----------------------------------------------
fprintf('\n== 9. readData KeepChannels / Precision ==\n');
ws = warning('off', 'IntanReader:readData:NoData');
k1 = ra.readData(KeepChannels=[3 1], Precision="single");
warning(ws);
check(isa(k1.amplifier, 'single') && isequal(k1.amplifier, single(X(:, [3 1]))) && isequal(k1.channelOrder, [3 1]) ...
    && isequal(k1.nativeNames, ["A-002" "A-000"]), 'traditional: the kept channels, in single');
rs = IntanReader(fs);
k2 = rs.readData(KeepChannels=[2 3], Precision="single");
k3 = rs.readData();
check(isequal(k2.amplifier, single(0.195 * double(As([2 3], :).'))) && isequal(k3.amplifier, 0.195 * double(As.')) ...
    && isequal(k2.events, k3.events), 'split: the kept channels, in single; the whole recording in double');

%% ---- 10. synthetic recordings are stamped as RHX leaves them -------------------------------
fprintf('\n== 10. synthetic recordings ==\n');
ws = warning('off', 'all');
g1 = fullfile(root, 'synth_trad');
S1 = makeSyntheticRecording(g1, Fs=5000, NumChannels=2, NumTrials=4, FileSeconds=4, SortedOutput=false, ...
    WriteManifest=false, Artifacts=false);
g2 = fullfile(root, 'synth_signal');
S2 = makeSyntheticRecording(g2, Format="one-file-per-signal", Fs=5000, NumChannels=2, NumTrials=4, ...
    SortedOutput=false, WriteManifest=false, Artifacts=false);
warning(ws);
if S1.fileTimesSet && S2.fileTimesSet
    mtime = @(p) datetime(getfield(dir(p), 'datenum'), 'ConvertFrom', 'datenum');
    ds1 = EphysDataset(g1);
    ends = arrayfun(@(f) mtime(fullfile(g1, f)), S1.files);
    starts = arrayfun(@(f) IntanReader.nameTime(extractBefore(f, ".rhd")), S1.files);
    dur = [ds1.PerFile.recordTime];
    check(all(abs(seconds(ends - starts - seconds(dur))) < 1.01) && ds1.AcqDate == S1.acqTime, ...
        'traditional: each file stamped at its end (its name has its start); AcqDate is the start');
    ds2 = EphysDataset(g2);
    tAmp = mtime(fullfile(g2, 'amplifier.dat'));
    check(abs(seconds(tAmp - S2.acqTime - seconds(S2.duration))) < 1 && abs(seconds(ds2.AcqDate - S2.acqTime)) < 1, ...
        'one-file-per-signal: amplifier.dat stamped at the end; AcqDate is the start');
else
    fprintf('  (stamping checks skipped: file times could not be set)\n');
end

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_IntanReader:Failed', '%d checks failed.', nFail);
end
end


function F = writeLayout(file, s)
%writeLayout  Write one RHD2000 file with random codes in every signal S asks for; F = S + the codes.
n = s.nBlocks * s.spb;
F = s;
F.amp    = uint16(randi([0 65535], s.nAmp, n));
F.aux    = uint16(randi([0 65535], s.nAux, n / 4));
F.supply = uint16(randi([0 65535], s.nSupply, s.nBlocks));
F.temp   = int16(randi([-5000 5000], s.nTemp, s.nBlocks));
F.adc    = uint16(randi([0 65535], s.nAdc, n));
F.dig    = uint16(randi([0 65535], 1, n));
F.dout   = uint16(randi([0 65535], 1, n));
args = {'Version', s.version, 'FirstTimestamp', s.firstTs, 'BoardMode', s.boardMode, 'NotchMode', s.notch, ...
    'AuxRaw', F.aux, 'SupplyRaw', F.supply, 'TempRaw', F.temp, 'AdcRaw', F.adc, 'DisabledAmp', s.disabled};
if isempty(s.digOrders)
    args = [args, {'DigInNames', string.empty(1, 0)}];
else
    args = [args, {'DigInNames', "d" + (1:numel(s.digOrders)), 'DigInOrders', s.digOrders}];
end
if ~isempty(s.doutOrders)
    args = [args, {'DigOutRaw', F.dout, 'DigOutOrders', s.doutOrders}];
end
writeSyntheticRHD(file, F.amp, F.dig, s.Fs, s.spb, args{:});
end


function bad = decodedAsWritten(D, F)
%decodedAsWritten  The read_Intan fields that do not hold what writeLayout wrote.
bad = strings(1, 0);
n = F.nBlocks * F.spb;
v = F.version;
if (v(1) == 1 && v(2) >= 2) || v(1) > 1
    ts = double(int32(F.firstTs + (0:n-1)));
else
    ts = double(uint32(F.firstTs + (0:n-1)));
end
if ~isequal(D.t_amplifier, ts / F.Fs); bad(end+1) = "t_amplifier"; end
amp = 0.195 * (double(F.amp) - 32768);
if F.notch == 0 || v(1) >= 3
    if ~isequal(D.amplifier_data, amp); bad(end+1) = "amplifier_data"; end
elseif ~isequal(size(D.amplifier_data), size(amp)) || isequal(D.amplifier_data, amp)
    bad(end+1) = "amplifier_data (notch not applied)";
end
if F.nAux > 0 && ~isequal(D.aux_input_data, 37.4e-6 * double(F.aux)); bad(end+1) = "aux_input_data"; end
if F.nSupply > 0 && ~isequal(D.supply_voltage_data, 74.8e-6 * double(F.supply)); bad(end+1) = "supply_voltage_data"; end
if F.nTemp > 0 && ~isequal(D.temp_sensor_data, double(F.temp) / 100); bad(end+1) = "temp_sensor_data"; end
if F.nAdc > 0
    switch F.boardMode
        case 1,    adc = 152.59e-6 * (double(F.adc) - 32768);
        case 13,   adc = 312.5e-6 * (double(F.adc) - 32768);
        otherwise, adc = 50.354e-6 * double(F.adc);
    end
    if ~isequal(D.board_adc_data, adc); bad(end+1) = "board_adc_data"; end
end
if ~isempty(F.digOrders)
    ref = double(cell2mat(arrayfun(@(o) bitget(F.dig, o + 1), F.digOrders(:), 'UniformOutput', false)));
    if ~isequal(D.board_dig_in_data, ref); bad(end+1) = "board_dig_in_data"; end
elseif isfield(D, 'board_dig_in_data') && ~isempty(D.board_dig_in_data)
    bad(end+1) = "board_dig_in_data (none written)";
end
if ~isempty(F.doutOrders)
    ref = double(cell2mat(arrayfun(@(o) bitget(F.dout, o + 1), F.doutOrders(:), 'UniformOutput', false)));
    if ~isequal(D.board_dig_out_data, ref); bad(end+1) = "board_dig_out_data"; end
end
if numel(D.amplifier_channels) ~= F.nAmp; bad(end+1) = "amplifier_channels"; end
end


function s = failed(bad)
s = "";
if ~isempty(bad); s = " (wrong: " + strjoin(bad, ", ") + ")"; end
end


function R = writeTraditional(folder, names, nBlocks, spb, Fs, W, varargin)
%writeTraditional  Files NAMES of NBLOCKS(k) blocks each holding one continuous recording.
%   W: [1 x total] digital words; VARARGIN: writeSyntheticRHD options for every
%   file ('AuxRaw', nAux asks for random aux codes). Files are stamped as RHX
%   leaves them: at the end of their data.
if ~isfolder(folder); mkdir(folder); end
n = nBlocks * spb; total = sum(n);
R.amp = uint16(randi([0 65535], 3, total));
opts = varargin;
nAux = 0;
k = find(strcmp(opts(1:2:end), 'AuxRaw'), 1);
if ~isempty(k); nAux = opts{2 * k}; opts(2 * k - 1:2 * k) = []; end
aux = uint16(randi([0 65535], nAux, total / 4));
t0 = datetime(2026, 1, 1, 10, 0, 0);
s = 0;
for k = 1:numel(names)
    idx = s + (1:n(k));
    writeSyntheticRHD(fullfile(folder, names(k)), R.amp(:, idx), W(idx), Fs, spb, opts{:}, ...
        'AuxRaw', aux(:, s / 4 + (1:n(k) / 4)), 'FirstTimestamp', s);
    setFileModifiedTime(fullfile(folder, names(k)), t0 + seconds((s + n(k)) / Fs + k));
    s = s + n(k);
end
end


function R = refRuns(x)
%refRuns  [first last] rows of the high runs of x (the diff-based reference).
x = double(x(:) > 0);
d = diff([0; x; 0]);
R = [find(d == 1), find(d == -1) - 1];
end


function rmdirQuiet(p)
try
    if isfolder(p); rmdir(p, 's'); end
catch
end
end
