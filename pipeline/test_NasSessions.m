classdef test_NasSessions < matlab.unittest.TestCase
    %test_NasSessions  Tests for findNasSessions and copyNasSessions.
    %   Builds fake NAS trees (ePsych files and Intan folders with small dummy
    %   files) in a temporary folder. Tests that copy need robocopy and are
    %   skipped off Windows.
    %
    %   Usage
    %     runtests("test_NasSessions")
    %     run_all_tests("test_NasSessions")

    properties
        Root      string   % temporary folder
        Epsych    string   % fake ePsych root
        Intan     string   % fake Intan root
        Dest      string   % local destination root (not created)
    end

    properties (Constant)
        Subj = "SUBJ-ID-1255"
    end

    methods (TestMethodSetup)
        function makeTree(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Root = string(f.Folder);
            tc.Epsych = fullfile(tc.Root, "nas", "epsych_files", "Data");
            tc.Intan = fullfile(tc.Root, "nas", "intan_files", "Data");
            tc.Dest = fullfile(tc.Root, "EPHYS");
            mkdir(tc.Epsych);
            mkdir(tc.Intan);
        end
    end

    methods (Test)
        % ---------------------------------------------------------------- pairing
        function singleSessionPaired(tc)
            e = tc.addEpsych(tc.Subj, "260916T110742");
            i = tc.addIntan(tc.Subj, "260916_110907");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(height(T), 1);
            tc.verifyEqual(T.Status, "paired");
            tc.verifyEqual(T.EpsychFile, e);
            tc.verifyEqual(T.IntanDir, i);
            tc.verifyEqual(T.DeltaT, -seconds(85));
            tc.verifyEqual(T.IntanTime, datetime(2026, 9, 16, 11, 9, 7));
            tc.verifyEqual(T.DestDir, string(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916_110907")));
        end

        function threeSessionsPairOneToOneGlobally(tc)
            % I2's nearest ePsych file (E1, 100 s) is even nearer to I1 (10 s):
            % first-come per Intan folder would give it to I2.
            tc.addIntan(tc.Subj, "260916_100000");   % I1
            tc.addIntan(tc.Subj, "260916_100130");   % I2
            tc.addIntan(tc.Subj, "260916_103000");   % I3
            e1 = tc.addEpsych(tc.Subj, "260916T095950");
            e2 = tc.addEpsych(tc.Subj, "260916T095800");
            e3 = tc.addEpsych(tc.Subj, "260916T102820");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(height(T), 3);
            tc.verifyEqual(T.Status, repmat("paired", 3, 1));
            tc.verifyEqual(T.EpsychFile, [e1; e2; e3]);
            tc.verifyEqual(seconds(T.DeltaT), [-10; -210; -100]);
        end

        function unpairedOnEitherSide(tc)
            e = tc.addEpsych(tc.Subj, "260916T090000");   % aborted, no recording
            i = tc.addIntan(tc.Subj, "260916_140000");    % recording without behavior
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(height(T), 2);
            tc.verifyEqual(T.Status, ["epsych_only"; "intan_only"]);
            tc.verifyEqual(T.EpsychFile(1), e);
            tc.verifyEqual(T.IntanDir(2), i);
            tc.verifyEqual(T.EpsychFile(2), "");
            tc.verifyEqual(T.DestDir(1), string(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916T090000")));
        end

        function equidistantIsAmbiguousAndNeverCopied(tc)
            tc.addIntan(tc.Subj, "260916_120000");
            tc.addEpsych(tc.Subj, "260916T115900");
            tc.addEpsych(tc.Subj, "260916T120100");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(height(T), 3);
            tc.verifyEqual(T.Status, repmat("ambiguous", 3, 1));
            tc.verifyTrue(all(T.Note ~= ""));
            tc.verifySubstring(char(T.Note(T.IntanDir ~= "")), 'T115900.mat');

            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, IncludeUnpaired=true, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, repmat("skipped", 3, 1));
            tc.verifyFalse(isfolder(tc.Dest));
        end

        function nearTieWithinMarginIsAmbiguous(tc)
            tc.addIntan(tc.Subj, "260916_120000");
            tc.addEpsych(tc.Subj, "260916T115840");   % -80 s
            tc.addEpsych(tc.Subj, "260916T115900");   % -60 s, 20 s nearer: within 30 s
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, repmat("ambiguous", 3, 1));
            T = tc.find(tc.Subj, "260916", AmbiguityMargin=seconds(10));
            tc.verifyEqual(sort(T.Status), ["epsych_only"; "paired"]);
        end

        function clockSkewWithinMaxLag(tc)
            e = tc.addEpsych(tc.Subj, "260916T120040");   % 40 s after Intan
            tc.addIntan(tc.Subj, "260916_120000");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, "paired");
            tc.verifyEqual(T.EpsychFile, e);
            tc.verifyEqual(T.DeltaT, seconds(40));

            T = tc.find(tc.Subj, "260916", MaxLagTime=seconds(30));
            tc.verifyEqual(sort(T.Status), ["epsych_only"; "intan_only"]);
        end

        function leadBeyondMaxLeadIsNotPaired(tc)
            tc.addEpsych(tc.Subj, "260916T114900");       % 11 min before
            tc.addIntan(tc.Subj, "260916_120000");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(sort(T.Status), ["epsych_only"; "intan_only"]);
        end

        function sessionCrossingMidnight(tc)
            e = tc.addEpsych(tc.Subj, "260916T235830");
            i = tc.addIntan(tc.Subj, "260917_000030");
            for spec = {"260916", "260917", datetime(2026, 9, 16), datetime(2026, 9, 17) + [0 1]}
                T = tc.find(tc.Subj, spec{1});
                tc.verifyEqual(height(T), 1);
                tc.verifyEqual(T.Status, "paired");
                tc.verifyEqual([T.EpsychFile, T.IntanDir], [e, i]);
                tc.verifyEqual(T.DeltaT, -seconds(120));
            end
            tc.verifyEmpty(tc.find(tc.Subj, "260918"));
        end

        function similarSubjectIDsNeverMix(tc)
            own = tc.addEpsych("SUBJ-ID-125", "260916T110742");
            tc.addIntan("SUBJ-ID-125", "260916_110907");
            tc.addEpsych(tc.Subj, "260916T110742");
            tc.addIntan(tc.Subj, "260916_110907");
            % a longer ID's files filed in the shorter ID's folders
            misE = tc.addFile(fullfile(tc.Epsych, "SUBJ-ID-125", "SUBJ-ID-1255_260916T130000.mat"));
            misI = fullfile(tc.Intan, "SUBJ-ID-125", "SUBJ-ID-1255_260916_130100");
            mkdir(misI);

            [T, S] = tc.find("SUBJ-ID-125", "260916");
            tc.verifyEqual(height(T), 1);
            tc.verifyEqual(T.EpsychFile, own);
            tc.verifyEqual(T.Subject, "SUBJ-ID-125");
            tc.verifyTrue(all(ismember([misE; misI], S.Path)));

            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(height(T), 1);
            tc.verifyTrue(contains(T.IntanDir, "SUBJ-ID-1255" + filesep + "SUBJ-ID-1255_"));
        end

        function malformedNamesSkippedAndLogged(tc)
            tc.addEpsych(tc.Subj, "260916T110742");
            tc.addIntan(tc.Subj, "260916_110907");
            ed = fullfile(tc.Epsych, tc.Subj);
            nd = fullfile(tc.Intan, tc.Subj);
            bad = [ ...
                tc.addFile(fullfile(ed, tc.Subj + "_260916T1107.mat"))
                tc.addFile(fullfile(ed, tc.Subj + "_260916T110742 (1).mat"))
                tc.addFile(fullfile(ed, tc.Subj + "_261316T110742.mat"))     % month 13
                tc.addFile(fullfile(ed, "notes.txt"))
                string(fullfile(nd, tc.Subj + "_260916_110907_old"))
                string(fullfile(nd, tc.Subj + "_260931_110907"))             % 31 September
                tc.addFile(fullfile(nd, tc.Subj + "_260916_120000"))];       % a file, not a folder
            mkdir(bad(5)); mkdir(bad(6));

            logged = containers.Map('KeyType', 'double', 'ValueType', 'any');
            [T, S] = findNasSessions(tc.Subj, "260916", EpsychRoot=tc.Epsych, IntanRoot=tc.Intan, ...
                DestRoot=tc.Dest, LogFcn=@(m) appendLog(logged, m));
            tc.verifyEqual(height(T), 1);
            tc.verifyEqual(T.Status, "paired");
            tc.verifyEqual(sort(S.Path), sort(bad));
            lines = string(logged.values);
            for b = bad.'
                tc.verifyTrue(any(startsWith(lines, "Skipped " + b)), "not logged: " + b);
            end
        end

        function missingRootErrors(tc)
            tc.verifyError(@() findNasSessions(tc.Subj, "260916", EpsychRoot=fullfile(tc.Root, "nope"), ...
                IntanRoot=tc.Intan, LogFcn=@(~) []), 'findNasSessions:RootNotFound');
            tc.verifyError(@() findNasSessions(tc.Subj, "261340", EpsychRoot=tc.Epsych, ...
                IntanRoot=tc.Intan, LogFcn=@(~) []), 'findNasSessions:BadDate');
        end

        % ---------------------------------------------------------------- copying
        function dryRunWritesNothing(tc)
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            before = tc.listTree(fullfile(tc.Root, "nas"));
            R = copyNasSessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);   % DryRun defaults to true
            tc.verifyEqual(R.CopyStatus, "planned");
            tc.verifyEqual(R.NumFiles, 5);   % 4 Intan files + the ePsych file
            tc.verifyFalse(isfolder(tc.Dest));
            tc.verifyEqual(tc.listTree(fullfile(tc.Root, "nas")), before);
        end

        function copyVerifiesAndWritesManifest(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            [e, i] = tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            before = tc.listTree(fullfile(tc.Root, "nas"));
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            dest = fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916_110907");
            tc.verifyEqual(R.DestDir, string(dest));
            tc.verifyTrue(isfile(fullfile(dest, tc.Subj + "_260916T110742.mat")));   % original ePsych name
            tc.verifyTrue(isfile(fullfile(dest, "amplifier.dat")));
            tc.verifyTrue(isfile(fullfile(dest, "sub", "nested.bin")));
            tc.verifyTrue(isfolder(fullfile(dest, "empty_sub")));
            tc.verifyEqual(tc.listTree(fullfile(tc.Root, "nas")), before);   % source untouched

            m = jsondecode(fileread(R.ManifestFile));
            tc.verifyEqual(string(m.copy.status), "copied");
            tc.verifyEqual(string(m.intan.sourceDir), i);
            tc.verifyEqual(string(m.epsych.sourceFile), e);
            tc.verifyEqual(m.deltaT_s, -85);
            tc.verifyEqual(string(m.pairingStatus), "paired");
            tc.verifyNotEmpty(m.copy.host);
            abc = m.intan.files(strcmp({m.intan.files.relativePath}, 'abc.txt'));
            tc.verifyEqual(string(abc.sha256Source), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
            tc.verifyEqual(abc.sha256Destination, abc.sha256Source);
            tc.verifyEqual(numel(m.epsych.files), 1);
        end

        function destinationExists(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);

            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "already_present", R.Message);
            R = copyNasSessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "already_present", "dry run");

            amp = fullfile(R.DestDir, "amplifier.dat");
            tc.writeBytes(amp, uint8(1:10));
            info = dir(amp);
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.verifySubstring(char(R.Message), 'amplifier.dat');
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, IfExists="error", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "failed");
            after = dir(amp);
            tc.verifyEqual([after.bytes, after.datenum], [info.bytes, info.datenum], "nothing overwritten");
        end

        function verificationFailureIsReported(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            truncate = @(dest) tc.writeBytes(fullfile(dest, "amplifier.dat"), uint8(1:3));
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, BeforeVerifyFcn=truncate, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "failed");
            tc.verifySubstring(char(R.Message), 'VERIFICATION FAILED');
            tc.verifySubstring(char(R.Message), 'amplifier.dat');
            tc.verifyTrue(isfile(fullfile(R.DestDir, "info.rhd")), "partial copy kept");
            m = jsondecode(fileread(R.ManifestFile));
            tc.verifyEqual(string(m.copy.status), "failed");
        end

        function oneFailureDoesNotStopTheBatch(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            tc.addPair("260916T140000", "260916_140130");
            T = tc.find(tc.Subj, "260916");
            rmdir(T.IntanDir(1), 's');   % NAS folder vanished after the search
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, ["failed"; "copied"]);
            tc.verifySubstring(char(R.Message(1)), 'not found');
        end

        function unpairedCopiedOnlyWhenIncluded(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            e = tc.addEpsych(tc.Subj, "260916T090000");
            T = tc.find(tc.Subj, "260916");
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.verifyFalse(isfolder(tc.Dest));
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, IncludeUnpaired=true, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            [~, n, x] = fileparts(e);
            tc.verifyTrue(isfile(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916T090000", n + x)));
        end

        function appFindPreviewCopy(tc)
            % The NAS tab end to end: find, ambiguous rows refuse a tick,
            % dry run writes nothing, copy writes the ticked session.
            g = EphysPreprocessingApp.PrefGroup;
            saved = [];
            if ispref(g); saved = getpref(g); end
            tc.addTeardown(@() restorePrefs(g, saved));
            if ispref(g, 'LastConfigFile'); setpref(g, 'LastConfigFile', ''); end

            tc.addPair("260916T110742", "260916_110907");
            tc.addIntan(tc.Subj, "260916_150000");        % ambiguous: two ePsych files 60 s either side
            tc.addEpsych(tc.Subj, "260916T145900");
            tc.addEpsych(tc.Subj, "260916T150100");
            tc.addEpsych(tc.Subj, "260916T170000");       % ePsych only

            app = EphysPreprocessingApp;
            tc.addTeardown(@() delete(app.Fig));
            tc.verifyEqual(app.Tabs.SelectedTab, app.TabProject);
            app.selectTab(app.TabNas);
            app.NasSubjectField.Value = char(tc.Subj);
            app.NasFromDatePicker.Value = datetime(2026, 9, 16);
            app.NasToDatePicker.Value = NaT;
            app.NasEpsychRootField.Value = char(tc.Epsych);
            app.NasIntanRootField.Value = char(tc.Intan);
            app.NasDestRootField.Value = char(tc.Dest);
            app.NasScanAfterCheckBox.Value = false;

            app.onNasFind();
            T = app.NasSessions;
            tc.verifyEqual(T.Status, ["paired"; "ambiguous"; "ambiguous"; "ambiguous"; "epsych_only"]);
            tc.verifyEqual(app.NasTicked, T.Status == "paired", "only paired rows ticked");
            tc.verifyEqual(height(app.NasTable.Data), 5);
            tc.verifyTrue(contains(string(app.NasLogArea.Value{end}), "1 paired"));

            amb = find(T.Status == "ambiguous", 1);
            app.onNasTableEdited(struct('Indices', [amb 1], 'NewData', true));
            tc.verifyFalse(app.NasTicked(amb), "an ambiguous row cannot be ticked");
            app.onNasTableEdited(struct('Indices', [5 1], 'NewData', true));
            tc.verifyTrue(app.NasTicked(5), "an unpaired row can be ticked by hand");
            app.onNasTableEdited(struct('Indices', [5 1], 'NewData', false));

            app.onNasCopy(true);
            tc.verifyEqual(app.NasCopyStatus(1), "planned");
            tc.verifyEqual(app.NasCopyStatus(2:end), strings(4, 1));
            tc.verifyFalse(isfolder(tc.Dest), "preview writes nothing");

            tc.assumeTrue(ispc, "robocopy needs Windows");
            app.onNasCopy(false);
            tc.verifyEqual(app.NasCopyStatus(1), "copied", app.NasMessage(1));
            tc.verifyTrue(isfile(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916_110907", "session_manifest.json")));
            tc.verifyEqual(app.NasTable.Data.Result(1), "copied");
            p = getpref(g, 'NasOptions');
            tc.verifyEqual(string(p.destRoot), tc.Dest, "the NAS settings are preferences");
        end

        function cancelStopsBeforeCopying(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, CancelFcn=@() true, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "cancelled");
            tc.verifyFalse(isfolder(R.DestDir));
        end
    end

    methods
        function [T, S] = find(tc, subj, spec, varargin)
            [T, S] = findNasSessions(subj, spec, 'EpsychRoot', tc.Epsych, 'IntanRoot', tc.Intan, ...
                'DestRoot', tc.Dest, 'LogFcn', @(~) [], varargin{:});
        end

        function f = addEpsych(tc, subj, stamp)
            f = tc.addFile(fullfile(tc.Epsych, subj, subj + "_" + stamp + ".mat"));
        end

        function d = addIntan(tc, subj, stamp)
            d = string(fullfile(tc.Intan, subj, subj + "_" + stamp));
            mkdir(d);
            tc.writeBytes(fullfile(d, "info.rhd"), uint8(1:100));
        end

        function [e, i] = addPair(tc, epsychStamp, intanStamp)
            %addPair  A session with a few Intan files, a subfolder and an empty subfolder.
            e = tc.addEpsych(tc.Subj, epsychStamp);
            i = tc.addIntan(tc.Subj, intanStamp);
            tc.writeBytes(fullfile(i, "amplifier.dat"), uint8(mod(0:300000, 256)));
            tc.writeBytes(fullfile(i, "abc.txt"), uint8('abc'));
            mkdir(fullfile(i, "sub"));
            tc.writeBytes(fullfile(i, "sub", "nested.bin"), uint8(7:77));
            mkdir(fullfile(i, "empty_sub"));
        end

        function f = addFile(tc, f)
            f = string(f);
            if ~isfolder(fileparts(f)); mkdir(fileparts(f)); end
            tc.writeBytes(f, uint8('dummy ePsych'));
        end

        function writeBytes(~, f, bytes)
            fid = fopen(f, 'w');
            fwrite(fid, bytes, 'uint8');
            fclose(fid);
        end

        function L = listTree(~, root)
            D = dir(fullfile(root, '**', '*'));
            D = D(~ismember({D.name}, {'.', '..'}));
            L = sort(string(fullfile({D.folder}, {D.name})) + " " + string([D.bytes]) + " " + string([D.datenum]));
        end
    end
end


function restorePrefs(g, saved)
if ispref(g); rmpref(g); end
if isstruct(saved)
    for f = string(fieldnames(saved)).'
        setpref(g, char(f), saved.(f));
    end
end
end


function appendLog(map, msg)
map(map.Count + 1) = string(msg); %#ok<NASGU> containers.Map is a handle
end
