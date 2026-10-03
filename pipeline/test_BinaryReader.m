classdef test_BinaryReader < matlab.unittest.TestCase
    %test_BinaryReader  Verification suite for the universal binary reader (BinaryReader).
    %   Writes small recording.json + flat binary recordings and checks:
    %   readDigitalEvents returns readData's events (dig_in_file with named and
    %   unnamed lines, a line high across a read window, the descriptor's
    %   events map, a missing dig_in_file) without reading the samples;
    %   readData's samples, KeepChannels / Precision and a data file shorter than
    %   n_samples; Files lists dig_in_file, so the local clean-up counts it as
    %   the recording's own; streamPlan leaves no short last chunk.
    %
    %   This suite is a matlab.unittest.TestCase, the form for new suites and
    %   for converting a function-style one: the fixtures the checks share
    %   are written once in TestClassSetup (in a TemporaryFolderFixture,
    %   removed afterwards), each section is a test method, and each
    %   check(cond, msg) became tc.verifyTrue(cond, msg) with the same
    %   condition. A parameterized test (Layout) runs one check per layout.
    %
    %   Usage:  runtests("test_BinaryReader")   or   run_all_tests("test_BinaryReader")

    properties (Constant)
        Fs = 30000
        NChan = 4
        NSamples = 12000
    end

    properties (SetAccess = private)
        Root (1,1) string = ""
        A                               % int16 [NChan x NSamples] samples
        W                               % uint16 [1 x NSamples] digital words
        Named (1,1) string = ""         % dig_in_file, 16 named lines
        Unnamed (1,1) string = ""       % the same dig_in_file, no names
        EventsMap (1,1) string = ""     % no dig_in_file: the descriptor's events map
    end

    properties (TestParameter)
        Layout = struct('named', 'Named', 'unnamed', 'Unnamed', 'eventsMap', 'EventsMap')
    end

    methods (TestClassSetup)
        function writeRecordings(tc)
            tc.Root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            rng(5);
            n = tc.NSamples;
            tc.A = int16(randi([-3000 3000], tc.NChan, n));
            W = zeros(1, n, 'uint16');
            W(1:9) = 1; W(500:800) = bitor(W(500:800), 4); W(n - 3:n) = bitor(W(n - 3:n), 4);
            W(6000:6001) = bitor(W(6000:6001), 32768);                  % bit 15
            tc.W = W;
            tc.Named = writeRec(fullfile(tc.Root, 'named'), tc.A, W, tc.Fs, 'dig_in_names', ...
                {'go', 'x', 'stop', 'y', 'z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'last'}, ...
                'dig_in_file', "digitalin.dat");
            tc.Unnamed = writeRec(fullfile(tc.Root, 'unnamed'), tc.A, W, tc.Fs, 'dig_in_file', "digitalin.dat");
            tc.EventsMap = writeRec(fullfile(tc.Root, 'eventsmap'), tc.A, [], tc.Fs, 'dig_in_names', {'go', 'stop'}, ...
                'events', struct('go', [0.01 0.02; 0.1 0.2], 'stop', [0.05 0.06]));
        end
    end

    methods (Test)
        % ---- 1. readDigitalEvents: readData's events, from the digital file alone ----
        function digitalEventsMatchReadData(tc, Layout)
            r = BinaryReader(tc.(Layout));
            calls = containers.Map('KeyType', 'double', 'ValueType', 'logical');
            E = r.readDigitalEvents(ProgressFcn=@(varargin) tick(calls));
            d = r.readData(KeepChannels=1, Precision="single");
            Eref = struct('events', d.events, 'Fs', d.Fs, 'nSamples', size(d.amplifier, 1), ...
                'digInNames', string(d.digInNames), 'digInNativeNames', string(d.digInNativeNames));
            tc.verifyTrue(isequal(E, Eref) && calls.Count == 1, string(Layout) + ": the events readData gives");
        end

        function namedAndUnnamedLines(tc)
            W = tc.W; Fs = tc.Fs;
            E1 = BinaryReader(tc.Named).readDigitalEvents();
            E2 = BinaryReader(tc.Unnamed).readDigitalEvents();
            tc.verifyTrue(isequal(E1.events.go, refRuns(bitget(W, 1)) / Fs) && isequal(E1.events.stop, refRuns(bitget(W, 3)) / Fs) ...
                && isequal(E1.events.last, refRuns(bitget(W, 16)) / Fs) && isempty(E1.events.x), ...
                'the named lines as written (bit k = line k+1)');
            tc.verifyTrue(isequal(E2.digInNames, "din" + (0:15)) && isequal(E2.events.din2, E1.events.stop), ...
                'unnamed lines: din0 .. din15 (bit 15 is set), the same intervals');
            tc.verifyTrue(isequal(BinaryReader(tc.EventsMap).readDigitalEvents().events.go, [0.01 0.02; 0.1 0.2]), ...
                'the events map as given');
        end

        function lineHighAcrossReadWindows(tc)
            % a line high across the reads' 2^22-sample windows
            nL = 2^22 + 3000;
            Wl = zeros(1, nL, 'uint16'); Wl(2^22 - 10 : 2^22 + 20) = 1; Wl(nL - 5 : nL) = 1;
            fl = writeRec(fullfile(tc.Root, 'long'), zeros(1, nL, 'int16'), Wl, tc.Fs, 'dig_in_names', {'go'}, ...
                'dig_in_file', "digitalin.dat");
            El = BinaryReader(fl).readDigitalEvents();
            tc.verifyTrue(isequal(El.events.go, [2^22 - 10, 2^22 + 20; nL - 5, nL] / tc.Fs) && El.nSamples == nL, ...
                'a line high across two read windows is one interval');
        end

        function missingDigInFileWarns(tc)
            fm = writeRec(fullfile(tc.Root, 'missing'), tc.A, [], tc.Fs, 'dig_in_names', {'go'}, 'dig_in_file', "nope.dat");
            Em = tc.verifyWarning(@() BinaryReader(fm).readDigitalEvents(), 'BinaryReader:NoDigInFile', ...
                'a missing dig_in_file warns');
            tc.verifyTrue(isempty(fieldnames(Em.events)) && Em.nSamples == tc.NSamples, 'a missing dig_in_file: no events');
        end

        % ---- 2. readData ------------------------------------------------------------
        function readDataSamples(tc)
            r1 = BinaryReader(tc.Named);
            d = r1.readData();
            ds = r1.readData(KeepChannels=[4 2], Precision="single");
            X = 0.195 * double(tc.A.');
            tc.verifyTrue(isequal(d.amplifier, X) && isequal(ds.amplifier, single(X(:, [4 2]))) && isequal(ds.channelOrder, [4 2]) ...
                && isequal(d.files, ["recording.json" "rec.bin" "digitalin.dat"]), ...
                'the samples in microvolts; KeepChannels in single; the files read');
        end

        function dataFileShorterThanNSamples(tc)
            fs = writeRec(fullfile(tc.Root, 'short'), tc.A, tc.W, tc.Fs, 'dig_in_file', "digitalin.dat", ...
                'n_samples', tc.NSamples + 500);
            rs = BinaryReader(fs);
            dsh = rs.readData();
            Es = rs.readDigitalEvents();
            X = 0.195 * double(tc.A.');
            tc.verifyTrue(isequal(dsh.amplifier, X) && Es.nSamples == tc.NSamples, ...
                'a data file shorter than n_samples: the rows it holds');
        end

        % ---- 3. Files: the recording's own files -------------------------------------
        function filesListDigInFile(tc)
            fu = writeRec(fullfile(tc.Root, 'u16dig'), tc.A, tc.W, tc.Fs, 'dig_in_names', {'go'}, 'dig_in_file', "lines.u16");
            dsu = EphysDataset(fu);
            tc.verifyTrue(isequal(dsu.Files, ["recording.json" "rec.bin" "lines.u16"]) && dsu.NumFiles == 1, ...
                'Files lists recording.json, the data file and dig_in_file');
            T = planLocalCleanup(dsu);
            row = T(endsWith(T.File, "lines.u16"), :);
            tc.verifyTrue(height(row) == 1 && row.Category == "raw" && row.Action == "keep", ...
                'the local clean-up counts dig_in_file as a raw recording file, whatever its extension');
        end

        % ---- 4. streamPlan ----------------------------------------------------------
        function streamPlanJoinsShortLastWindow(tc)
            p = BinaryReader(tc.Named).streamPlan(MaxChunkSamples=5000);
            tc.verifyTrue(isequal([p.sampleOffset], [0 5000]) && isequal([p.nSamples], [5000 7000]), ...
                'a last window shorter than a second joins the one before it');
            p = BinaryReader(tc.Named).streamPlan(MaxChunkSamples=6000);
            tc.verifyTrue(isequal([p.nSamples], [6000 6000]), 'windows that divide the recording are unchanged');
        end
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


function tick(calls)
%tick  Count one ProgressFcn call (CALLS is a containers.Map, a handle).
calls(calls.Count + 1) = true;
end
