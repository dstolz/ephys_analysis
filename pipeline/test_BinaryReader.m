function test_BinaryReader()
%test_BinaryReader  Verification suite for the universal binary reader (BinaryReader).
%   Writes small recording.json + flat binary recordings and checks:
%   readDigitalEvents returns readData's events (dig_in_file with named and
%   unnamed lines, a line high across a read window, the descriptor's
%   events map, a missing dig_in_file) without reading the samples;
%   readData's samples, KeepChannels / Precision and a data file shorter than
%   n_samples; Files lists dig_in_file, so the local clean-up counts it as
%   the recording's own; streamPlan leaves no short last chunk.
%
%   Usage:  test_BinaryReader

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

root = fullfile(tempdir, sprintf('BinaryReader_test_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmssSSS'))));
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

rng(5);
Fs = 30000; nC = 4; n = 12000;
A = int16(randi([-3000 3000], nC, n));
W = zeros(1, n, 'uint16');
W(1:9) = 1; W(500:800) = bitor(W(500:800), 4); W(n - 3:n) = bitor(W(n - 3:n), 4);
W(6000:6001) = bitor(W(6000:6001), 32768);                  % bit 15

%% ---- 1. readDigitalEvents: readData's events, from the digital file alone ----------
fprintf('\n== 1. readDigitalEvents ==\n');
f1 = writeRec(fullfile(root, 'named'), A, W, Fs, 'dig_in_names', {'go', 'x', 'stop', 'y', 'z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'last'}, ...
    'dig_in_file', "digitalin.dat");
f2 = writeRec(fullfile(root, 'unnamed'), A, W, Fs, 'dig_in_file', "digitalin.dat");
f3 = writeRec(fullfile(root, 'eventsmap'), A, [], Fs, 'dig_in_names', {'go', 'stop'}, ...
    'events', struct('go', [0.01 0.02; 0.1 0.2], 'stop', [0.05 0.06]));
names = ["named dig_in_file (16 lines)", "unnamed dig_in_file (din0.. up to the highest bit set)", "the descriptor's events map"];
folders = [f1 f2 f3];
for k = 1:3
    r = BinaryReader(folders(k));
    nProg = 0;
    E = r.readDigitalEvents(ProgressFcn=@(varargin) tick());
    d = r.readData(KeepChannels=1, Precision="single");
    Eref = struct('events', d.events, 'Fs', d.Fs, 'nSamples', size(d.amplifier, 1), ...
        'digInNames', string(d.digInNames), 'digInNativeNames', string(d.digInNativeNames));
    check(isequal(E, Eref) && nProg == 1, names(k) + ": the events readData gives");
end
    function tick()
        nProg = nProg + 1;
    end
E1 = BinaryReader(f1).readDigitalEvents();
E2 = BinaryReader(f2).readDigitalEvents();
check(isequal(E1.events.go, refRuns(bitget(W, 1)) / Fs) && isequal(E1.events.stop, refRuns(bitget(W, 3)) / Fs) ...
    && isequal(E1.events.last, refRuns(bitget(W, 16)) / Fs) && isempty(E1.events.x), 'the named lines as written (bit k = line k+1)');
check(isequal(E2.digInNames, "din" + (0:15)) && isequal(E2.events.din2, E1.events.stop), ...
    'unnamed lines: din0 .. din15 (bit 15 is set), the same intervals');
check(isequal(BinaryReader(f3).readDigitalEvents().events.go, [0.01 0.02; 0.1 0.2]), 'the events map as given');
% a line high across the reads' 2^22-sample windows
nL = 2^22 + 3000;
Wl = zeros(1, nL, 'uint16'); Wl(2^22 - 10 : 2^22 + 20) = 1; Wl(nL - 5 : nL) = 1;
fl = writeRec(fullfile(root, 'long'), zeros(1, nL, 'int16'), Wl, Fs, 'dig_in_names', {'go'}, 'dig_in_file', "digitalin.dat");
El = BinaryReader(fl).readDigitalEvents();
check(isequal(El.events.go, [2^22 - 10, 2^22 + 20; nL - 5, nL] / Fs) && El.nSamples == nL, ...
    'a line high across two read windows is one interval');
fm = writeRec(fullfile(root, 'missing'), A, [], Fs, 'dig_in_names', {'go'}, 'dig_in_file', "nope.dat"); %#ok<NASGU> read by evalc
Em = [];                                                   % set by evalc (it cannot add a variable here)
lastwarn('');
evalc('Em = BinaryReader(fm).readDigitalEvents();');         % the warning text is captured, not shown
[~, id] = lastwarn();
check(strcmp(id, 'BinaryReader:NoDigInFile') && isempty(fieldnames(Em.events)) && Em.nSamples == n, ...
    'a missing dig_in_file warns; no events');

%% ---- 2. readData ----------------------------------------------------------------------
fprintf('\n== 2. readData ==\n');
r1 = BinaryReader(f1);
d = r1.readData();
ds = r1.readData(KeepChannels=[4 2], Precision="single");
X = 0.195 * double(A.');
check(isequal(d.amplifier, X) && isequal(ds.amplifier, single(X(:, [4 2]))) && isequal(ds.channelOrder, [4 2]) ...
    && isequal(d.files, ["recording.json" "rec.bin" "digitalin.dat"]), ...
    'the samples in microvolts; KeepChannels in single; the files read');
fs = writeRec(fullfile(root, 'short'), A, W, Fs, 'dig_in_file', "digitalin.dat", 'n_samples', n + 500);
rs = BinaryReader(fs);
dsh = rs.readData();
Es = rs.readDigitalEvents();
check(isequal(dsh.amplifier, X) && Es.nSamples == n, 'a data file shorter than n_samples: the rows it holds');

%% ---- 3. Files: the recording's own files ---------------------------------------------
fprintf('\n== 3. Files ==\n');
fu = writeRec(fullfile(root, 'u16dig'), A, W, Fs, 'dig_in_names', {'go'}, 'dig_in_file', "lines.u16");
dsu = EphysDataset(fu);
check(isequal(dsu.Files, ["recording.json" "rec.bin" "lines.u16"]) && dsu.NumFiles == 1, ...
    'Files lists recording.json, the data file and dig_in_file');
T = planLocalCleanup(dsu);
row = T(endsWith(T.File, "lines.u16"), :);
check(height(row) == 1 && row.Category == "raw" && row.Action == "keep", ...
    'the local clean-up counts dig_in_file as a raw recording file, whatever its extension');

%% ---- 4. streamPlan -----------------------------------------------------------------------
fprintf('\n== 4. streamPlan ==\n');
p = BinaryReader(f1).streamPlan(MaxChunkSamples=5000);
check(isequal([p.sampleOffset], [0 5000]) && isequal([p.nSamples], [5000 7000]), ...
    'a last window shorter than a second joins the one before it');
p = BinaryReader(f1).streamPlan(MaxChunkSamples=6000);
check(isequal([p.nSamples], [6000 6000]), 'windows that divide the recording are unchanged');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_BinaryReader:Failed', '%d checks failed.', nFail);
end
end


function folder = writeRec(folder, A, W, Fs, varargin)
%writeRec  rec.bin (int16 A, channel-major per sample) + digitalin words W + recording.json.
if ~isfolder(folder); mkdir(folder); end
writeDat(fullfile(folder, 'rec.bin'), A, 'int16');
spec = struct('data_file', "rec.bin", 'dtype', "int16", 'n_chan', size(A, 1), 'fs', Fs, 'gain_to_uV', 0.195);
for k = 1:2:numel(varargin)
    spec.(varargin{k}) = varargin{k + 1};
end
if ~isempty(W)
    writeDat(fullfile(folder, spec.dig_in_file), W, 'uint16');
end
BinaryReader.writeDescriptor(folder, spec);
folder = string(folder);
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
